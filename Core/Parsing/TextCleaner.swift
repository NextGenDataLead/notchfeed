import Foundation

/// Turns feed text (which often carries HTML) into a single plain line for the ticker.
enum TextCleaner {
    static func plainText(_ text: String) -> String {
        let withoutInlineTags = text.replacing(/<\/?(?i:a|abbr|b|cite|code|em|i|mark|q|s|small|span|strong|sub|sup|u)\b[^>]*>/, with: "")
        let withoutTags = withoutInlineTags.replacing(/<[^>]*>/, with: " ")
        return collapseWhitespace(decodeEntities(withoutTags))
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        return text.replacing(/&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,15});/) { match in
            let name = match.output.1
            guard let scalar = scalar(forEntity: name) else { return String(match.output.0) }
            return String(Character(scalar))
        }
    }

    static func collapseWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Resolves "#233", "#xE9" or "eacute" to a scalar.
    static func scalar(forEntity name: Substring) -> Unicode.Scalar? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            return UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init)
        }
        if name.hasPrefix("#") {
            return UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init)
        }
        return HTMLEntities.named[String(name)]
    }
}
