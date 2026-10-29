import AppKit
import NotchFeedCore
import SwiftUI

/// FR-5.1: the icon, with the unread count when that setting is on.
struct MenuBarLabel: View {
    private static let maxCount = 999

    let model: AppModel?
    @AppStorage(AppSettings.Key.showUnreadCount) private var showUnreadCount = AppDefaults.showUnreadCount

    var body: some View {
        if let count = model?.unreadCount, showUnreadCount, count > 0 {
            Label {
                Text(count > Self.maxCount ? String(localized: "\(Self.maxCount)+") : String(count))
            } icon: {
                Image(systemName: "newspaper")
            }
            .labelStyle(.titleAndIcon)
            .accessibilityLabel(String(localized: "NotchFeed, \(count) unread"))
        } else {
            Image(systemName: "newspaper")
                .accessibilityLabel("NotchFeed")
        }
    }
}

/// FR-5.2 (basic): recent items, Refresh now, Pause ticker, Settings and Quit. Snooze follows in V0.3.
struct MenuBarContent: View {
    private static let titleLength = 80

    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let recent = model.headlines.prefix(AppDefaults.menuItemLimit)
        if recent.isEmpty {
            Text(model.hasFeeds ? "Waiting for headlines…" : "No feeds yet")
        } else {
            ForEach(recent) { entry in
                Button {
                    model.open(entry)
                } label: {
                    if let icon = entry.favicon.map(MenuIcon.make) {
                        Image(nsImage: icon)
                    }
                    Text(label(for: entry))
                }
            }
        }

        Divider()

        Button("Refresh Now") { model.refreshNow() }
            .keyboardShortcut("r")
        Button(model.isTickerPaused ? "Resume Ticker" : "Pause Ticker") {
            model.isTickerPaused.toggle()
        }
        .keyboardShortcut("p")

        Divider()

        Button("Settings…") {
            // An accessory app must activate itself, or the window opens behind other apps.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
        Button("Quit NotchFeed") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Unread items get a dot, since menus can't dim read ones.
    private func label(for entry: HeadlineEntry) -> String {
        let title = entry.title.count > Self.titleLength
            ? entry.title.prefix(Self.titleLength).trimmingCharacters(in: .whitespaces) + "\u{2026}"
            : entry.title
        let age = RelativeAge(of: entry.date, now: model.now).shortText
        let marker = entry.isRead ? "" : "\u{2022} "
        return entry.feedTitle.isEmpty
            ? "\(marker)\(title)  \(age)"
            : "\(marker)\(title)  \u{2014} \(entry.feedTitle), \(age)"
    }
}

enum MenuIcon {
    static let size = NSSize(width: 16, height: 16)

    /// Menu items show images at their own size, so scale favicons down first.
    static func make(_ image: NSImage) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            image.draw(in: rect)
            return true
        }
    }
}

struct QuitButton: View {
    var body: some View {
        Button("Quit NotchFeed") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
