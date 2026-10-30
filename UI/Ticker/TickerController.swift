import AppKit
import NotchFeedCore
import Observation
import SwiftUI

/// Owns the ticker panel: places it (FR-1.2), renders the headlines and reacts to settings,
/// display changes, Reduce Motion and the pause toggle.
@MainActor
final class TickerController {
    private static let horizontalInset: CGFloat = 10

    private struct RenderKey: Hashable {
        let entry: HeadlineEntry
        let age: String
        let showFeedName: Bool
        let scale: CGFloat
    }

    private let model: AppModel
    private let panel = TickerPanel()
    private let scrollView = TickerScrollView()
    private let visibility = VisibilityController()
    private var observers: [any NSObjectProtocol] = []
    private var renderCache: [RenderKey: TickerSegment] = [:]
    private var placement: (position: TickerPosition, displayID: UInt32?, showFeedName: Bool)?

    init(model: AppModel) {
        self.model = model

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = TickerStyle.background.cgColor
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.horizontalInset),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.horizontalInset),
            scrollView.topAnchor.constraint(equalTo: content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        panel.contentView = content
        scrollView.setAccessibilityLabel(String(localized: "Headlines"))
        scrollView.onActivate = { [weak model] entry in model?.open(entry) }
    }

    func start() {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updatePlacement(force: true) }
            },
            center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updatePlacement(force: false) }
            },
            center.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.render() }
            },
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.scrollView.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
            },
        ]
        scrollView.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        visibility.onChange = { [weak self] in self?.updateVisibility() }
        visibility.start()
        updatePlacement(force: true)
        observeModel()
    }

    // MARK: Placement

    private func updatePlacement(force: Bool) {
        let current = (
            position: AppSettings.tickerPosition(),
            displayID: AppSettings.tickerDisplayID(),
            showFeedName: UserDefaults.standard.bool(forKey: AppSettings.Key.showFeedName)
        )
        if !force, let placement, placement == current { return }
        let feedNameChanged = placement?.showFeedName != current.showFeedName
        placement = current

        guard let screen = NSScreen.tickerScreen(preferredDisplayID: current.displayID), let geometry = screen.geometry else {
            panel.orderOut(nil)
            return
        }
        panel.setFrame(TickerPositioner.frame(on: geometry, position: current.position), display: true)
        updateVisibility()
        // A setting the user just changed shows at once (FR-9.1); a screen change has to anyway.
        if feedNameChanged || force { render(immediately: true) }
    }

    /// FR-1.1: hidden while a full-screen app is in front on the ticker's display.
    private func updateVisibility() {
        guard let screen = NSScreen.tickerScreen(preferredDisplayID: placement?.displayID) else {
            panel.orderOut(nil)
            return
        }
        if visibility.isFullScreenAppShowing(on: screen) {
            if panel.isVisible { panel.orderOut(nil) }
        } else if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    // MARK: Rendering

    private func observeModel() {
        withObservationTracking {
            _ = model.headlines
            _ = model.now
            _ = model.hasFeeds
            _ = model.isTickerPaused
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render()
                self?.observeModel()
            }
        }
    }

    private func render(immediately: Bool = false) {
        let scale = panel.backingScaleFactor
        let showFeedName = placement?.showFeedName ?? AppDefaults.showFeedName
        let now = model.now

        var used: [RenderKey: TickerSegment] = [:]
        var segments: [TickerSegment] = []
        for entry in model.headlines {
            let age = RelativeAge(of: entry.date, now: now).shortText
            let key = RenderKey(entry: entry, age: age, showFeedName: showFeedName, scale: scale)
            guard let segment = renderCache[key] ?? segment(for: entry, age: age, showFeedName: showFeedName, scale: scale, now: now) else { continue }
            used[key] = segment
            segments.append(segment)
        }
        renderCache = used

        if segments.isEmpty, let message = messageSegment(scale: scale) {
            segments = [message]
        }
        // Pause state first: a resume must not look like "not scrolling" and apply content mid-loop.
        scrollView.isPaused = model.isTickerPaused
        scrollView.show(segments, immediately: immediately)
    }

    private func segment(for entry: HeadlineEntry, age: String, showFeedName: Bool, scale: CGFloat, now: Date) -> TickerSegment? {
        let renderer = ImageRenderer(content: TickerItemView(entry: entry, age: age, showFeedName: showFeedName))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        let spokenAge = SpokenAge.text(for: entry.date, now: now)
        let label = entry.isRead
            ? String(localized: "\(entry.feedTitle): \(entry.title), \(spokenAge), read", comment: "VoiceOver label of a read ticker item")
            : String(localized: "\(entry.feedTitle): \(entry.title), \(spokenAge)", comment: "VoiceOver label of a ticker item")
        return TickerSegment(entry: entry, image: image, scale: scale, accessibilityLabel: label)
    }

    private func messageSegment(scale: CGFloat) -> TickerSegment? {
        let text = model.hasFeeds
            ? String(localized: "Waiting for headlines…")
            : String(localized: "No feeds yet. Add some in NotchFeed Settings.")
        let renderer = ImageRenderer(content:
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TickerStyle.secondaryText)
                .frame(height: TickerPositioner.height)
                .fixedSize()
        )
        renderer.scale = scale
        return renderer.cgImage.map { TickerSegment(entry: nil, image: $0, scale: scale, accessibilityLabel: text) }
    }
}
