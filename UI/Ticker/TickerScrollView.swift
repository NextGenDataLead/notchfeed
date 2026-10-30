import AppKit
import QuartzCore

/// One rendered item in the strip. `entry` is nil for a plain message such as "No feeds yet".
struct TickerSegment {
    let entry: HeadlineEntry?
    let image: CGImage
    let scale: CGFloat
    let accessibilityLabel: String

    var size: CGSize { CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale) }
    var opacity: Float { entry?.isRead == true ? TickerStyle.readOpacity : 1 }
}

/// Continuous scroll on the compositor: the strip is a layer of pre-rendered items, moved by one
/// linear Core Animation per loop. Clicks are hit-tested against the presentation layer.
/// Read state is layer opacity and applies at once. Changes that keep order and widths are
/// swapped in place; others wait for the loop end.
final class TickerScrollView: NSView {
    /// Points per second; FR-1.4 makes speed a setting in V0.2.
    static let speed: CGFloat = 40
    static let gap: CGFloat = 28
    private static let animationKey = "scroll"

    var onActivate: ((HeadlineEntry) -> Void)?
    var isPaused = false {
        didSet { if isPaused != oldValue { applyPause() } }
    }
    var reduceMotion = false {
        didSet { if reduceMotion != oldValue { apply(pending ?? segments) } }
    }

    private let stripLayer = CALayer()
    private var segments: [TickerSegment] = []
    private var offsets: [CGFloat] = []
    private var cycleWidth: CGFloat = 0
    private var itemLayers: [[CALayer]] = []
    private var pending: [TickerSegment]?
    private var isScrolling = false
    private var laidOutSize = CGSize.zero

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        stripLayer.anchorPoint = .zero
        layer?.addSublayer(stripLayer)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// While scrolling (paused or not), anything that would move items waits for the loop end,
    /// so the strip never jumps under the reader. `immediately` is for changes the user just made
    /// in Settings: they apply at once, and the item at the left edge stays where it is.
    func show(_ newSegments: [TickerSegment], immediately: Bool = false) {
        dimReadItems(in: newSegments)
        if pending == nil, !segments.isEmpty, newSegments.count == segments.count,
           zip(newSegments, segments).allSatisfy({ $0.entry?.id == $1.entry?.id && $0.size == $1.size }) {
            updateInPlace(newSegments)
        } else if isScrolling, !immediately {
            pending = newSegments
        } else {
            apply(newSegments, keeping: leadingItem())
        }
    }

    override func layout() {
        super.layout()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        apply(pending ?? segments)
    }

    // MARK: Content

    /// - Parameter anchor: an item and the distance of its left edge from the view's left edge;
    ///   the loop resumes with that item at the same spot. Without it the loop starts over.
    private func apply(_ newSegments: [TickerSegment], keeping anchor: (id: String, x: CGFloat)? = nil) {
        pending = nil
        segments = newSegments
        var x: CGFloat = 0
        offsets = newSegments.map { segment in
            defer { x += segment.size.width + Self.gap }
            return x
        }
        cycleWidth = x

        var phase: CGFloat = 0
        if let anchor, cycleWidth > 0, let index = newSegments.firstIndex(where: { $0.entry?.id == anchor.id }) {
            phase = (offsets[index] - anchor.x).truncatingRemainder(dividingBy: cycleWidth)
            if phase < 0 { phase += cycleWidth }
        }
        rebuildLayers(phase: phase)
    }

    /// The first item whose right edge is in view, while scrolling.
    private func leadingItem() -> (id: String, x: CGFloat)? {
        guard isScrolling, cycleWidth > 0 else { return nil }
        var start = (-currentTranslation).truncatingRemainder(dividingBy: cycleWidth)
        if start < 0 { start += cycleWidth }
        guard let index = offsets.indices.first(where: { offsets[$0] + segments[$0].size.width > start }),
              let id = segments[index].entry?.id else { return nil }
        return (id, offsets[index] - start)
    }

    private func updateInPlace(_ newSegments: [TickerSegment]) {
        segments = newSegments
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for copy in itemLayers {
            for (layer, segment) in zip(copy, newSegments) {
                layer.contents = segment.image
                layer.opacity = segment.opacity
            }
        }
        CATransaction.commit()
    }

    /// FR-1.9: a clicked headline dims within the 250 ms reload, not at the end of a loop that
    /// can take minutes. Items only become read in V0.1, so this never brightens anything.
    private func dimReadItems(in newSegments: [TickerSegment]) {
        let readIDs = Set(newSegments.compactMap { $0.entry?.isRead == true ? $0.entry?.id : nil })
        for copy in itemLayers {
            for (layer, segment) in zip(copy, segments) {
                guard let id = segment.entry?.id, readIDs.contains(id) else { continue }
                layer.opacity = TickerStyle.readOpacity
            }
        }
    }

    private func rebuildLayers(phase: CGFloat = 0) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stripLayer.removeAnimation(forKey: Self.animationKey)
        stripLayer.speed = 1
        stripLayer.timeOffset = 0
        stripLayer.beginTime = 0
        stripLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        isScrolling = !reduceMotion && cycleWidth - Self.gap > bounds.width
        let copies = isScrolling ? 2 : 1
        itemLayers = (0..<copies).map { copy in
            zip(segments, offsets).map { segment, offset in
                let layer = CALayer()
                layer.contents = segment.image
                layer.contentsScale = segment.scale
                layer.opacity = segment.opacity
                layer.frame = CGRect(
                    x: CGFloat(copy) * cycleWidth + offset,
                    y: ((bounds.height - segment.size.height) / 2).rounded(),
                    width: segment.size.width,
                    height: segment.size.height
                )
                stripLayer.addSublayer(layer)
                return layer
            }
        }
        stripLayer.frame = CGRect(x: 0, y: 0, width: max(cycleWidth * CGFloat(copies), bounds.width), height: bounds.height)
        // In the same transaction, so a resumed loop never shows a frame at the start position.
        if isScrolling { startCycle(from: phase) }
        if isPaused { applyPause() }
        CATransaction.commit()

        NSAccessibility.post(element: self, notification: .layoutChanged)
    }

    // MARK: Animation

    /// One loop, or the rest of one when `phase` (points already scrolled) is above zero.
    private func startCycle(from phase: CGFloat = 0) {
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -phase
        animation.toValue = -cycleWidth
        animation.duration = CFTimeInterval((cycleWidth - phase) / Self.speed)
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.delegate = self
        stripLayer.add(animation, forKey: Self.animationKey)
    }

    private func applyPause() {
        if isPaused {
            let now = stripLayer.convertTime(CACurrentMediaTime(), from: nil)
            stripLayer.speed = 0
            stripLayer.timeOffset = now
        } else {
            let pausedAt = stripLayer.timeOffset
            stripLayer.speed = 1
            stripLayer.timeOffset = 0
            stripLayer.beginTime = 0
            stripLayer.beginTime = stripLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        }
    }

    private var currentTranslation: CGFloat {
        (stripLayer.presentation()?.value(forKeyPath: "transform.translation.x") as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
    }

    // MARK: Clicks

    override func mouseDown(with event: NSEvent) {
        guard let index = segmentIndex(at: convert(event.locationInWindow, from: nil)),
              let entry = segments[index].entry else { return }
        onActivate?(entry)
    }

    private func segmentIndex(at point: CGPoint) -> Int? {
        var x = point.x - currentTranslation
        if isScrolling, cycleWidth > 0 {
            x = x.truncatingRemainder(dividingBy: cycleWidth)
            if x < 0 { x += cycleWidth }
        }
        return offsets.indices.first { x >= offsets[$0] && x < offsets[$0] + segments[$0].size.width }
    }

    // MARK: Accessibility (NFR-6)

    override func accessibilityChildren() -> [Any]? {
        let translation = currentTranslation
        return segments.indices.map { index in
            let segment = segments[index]
            var x = offsets[index] + translation
            if isScrolling, x < -segment.size.width { x += cycleWidth }
            let frame = CGRect(x: x, y: 0, width: segment.size.width, height: bounds.height)
            let element = TickerAccessibilityElement(label: segment.accessibilityLabel, frame: frame, parent: self) { [weak self] in
                guard let entry = segment.entry else { return false }
                self?.onActivate?(entry)
                return true
            }
            return element
        }
    }
}

extension TickerScrollView: @preconcurrency CAAnimationDelegate {
    func animationDidStop(_ animation: CAAnimation, finished: Bool) {
        // `finished` is false when the animation was removed for a rebuild.
        guard finished, isScrolling else { return }
        if let pending {
            apply(pending)
        } else {
            startCycle()
        }
    }
}

private final class TickerAccessibilityElement: NSAccessibilityElement {
    private let press: () -> Bool

    init(label: String, frame: CGRect, parent: NSView, press: @escaping () -> Bool) {
        self.press = press
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        setAccessibilityParent(parent)
        setAccessibilityFrameInParentSpace(frame)
    }

    override func accessibilityPerformPress() -> Bool { press() }
}
