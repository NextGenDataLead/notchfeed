import NotchFeedCore
import SwiftUI

/// FR-1.8: favicon, optional feed name, headline and relative age. Rendered to an image for the strip.
struct TickerItemView: View {
    static let titleMaxWidth: CGFloat = 640

    let entry: HeadlineEntry
    let age: String
    let showFeedName: Bool

    var body: some View {
        HStack(spacing: 6) {
            FaviconView(image: entry.favicon, fallbackLetter: entry.feedTitle.first)
            if showFeedName, !entry.feedTitle.isEmpty {
                Text(entry.feedTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TickerStyle.secondaryText)
                    .lineLimit(1)
            }
            Text(entry.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TickerStyle.primaryText)
                .lineLimit(1)
                .frame(maxWidth: Self.titleMaxWidth, alignment: .leading)
            Text(age)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(TickerStyle.tertiaryText)
        }
        .opacity(entry.isRead ? TickerStyle.readOpacity : 1)
        .frame(height: TickerPositioner.height)
        .fixedSize()
        .environment(\.colorScheme, .dark)
    }
}

struct FaviconView: View {
    static let size: CGFloat = 14

    let image: NSImage?
    let fallbackLetter: Character?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Text(fallbackLetter.map { String($0).uppercased() } ?? "•")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TickerStyle.primaryText)
                    .frame(width: Self.size, height: Self.size)
                    .background(TickerStyle.placeholder, in: RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(width: Self.size, height: Self.size)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

/// V0.1 has one look: a near-black bar that blends with the menu bar and the notch.
/// Themes are FR-1.7 (V0.2).
enum TickerStyle {
    static let background = NSColor(white: 0.06, alpha: 0.92)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.42)
    static let placeholder = Color.white.opacity(0.18)
    static let readOpacity = 0.45
}
