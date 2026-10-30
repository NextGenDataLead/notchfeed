import AppKit
import NotchFeedCore

/// FR-5.1: the newspaper icon with the unread count as a small badge in its bottom-right corner,
/// instead of text beside it, so the item stays narrow enough to fit beside the notch.
/// It's a template image: the menu bar tints it, and the digits are cut out of the badge.
enum MenuBarIcon {
    private static let symbolName = "newspaper"
    private static let pointSize: CGFloat = 15
    private static let canvasHeight: CGFloat = 18
    private static let badgeHeight: CGFloat = 10
    private static let badgePadding: CGFloat = 2.5
    /// Clear ring between icon and badge, so the badge reads as separate.
    private static let badgeGap: CGFloat = 1
    private static var badgeFont: NSFont { .systemFont(ofSize: 8, weight: .bold) }

    static func text(for badge: UnreadBadge) -> String {
        switch badge {
        case .count(let count): String(count)
        case .overflow(let max): String(localized: "\(max)+", comment: "Unread badge for more than 99 items")
        }
    }

    static func image(badge: UnreadBadge) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }

        let label = NSAttributedString(string: text(for: badge), attributes: [.font: badgeFont, .foregroundColor: NSColor.black])
        let labelSize = label.size()
        let badgeWidth = max(badgeHeight, ceil(labelSize.width) + 2 * badgePadding)
        let symbolSize = symbol.size
        // The badge overlaps the icon's corner and sticks out by half its width at most.
        let canvas = NSSize(width: ceil(symbolSize.width + badgeWidth / 2), height: canvasHeight)
        let symbolRect = NSRect(
            x: 0,
            y: ((canvas.height - symbolSize.height) / 2).rounded(),
            width: symbolSize.width,
            height: symbolSize.height
        )
        let badgeRect = NSRect(x: canvas.width - badgeWidth, y: 0, width: badgeWidth, height: badgeHeight)

        let image = NSImage(size: canvas, flipped: false) { _ in
            guard let context = NSGraphicsContext.current else { return false }
            symbol.draw(in: symbolRect)

            context.compositingOperation = .destinationOut
            let gapRect = badgeRect.insetBy(dx: -badgeGap, dy: -badgeGap)
            NSBezierPath(roundedRect: gapRect, xRadius: gapRect.height / 2, yRadius: gapRect.height / 2).fill()

            context.compositingOperation = .sourceOver
            NSColor.black.setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: badgeRect.height / 2, yRadius: badgeRect.height / 2).fill()

            context.compositingOperation = .destinationOut
            label.draw(at: NSPoint(
                x: badgeRect.midX - labelSize.width / 2,
                y: badgeRect.midY - labelSize.height / 2
            ))
            return true
        }
        image.isTemplate = true
        return image
    }
}
