import Foundation

/// Repairs common feed breakage so a second parse attempt can succeed:
/// junk or a BOM before the first tag, bare `&`, HTML-only entities and invalid control characters.
/// The result is always UTF-8.
enum XMLSanitizer {
    static func sanitize(_ data: Data) -> Data {
        var text = decode(data)
        if let firstTag = text.firstIndex(of: "<") {
            text = String(text[firstTag...])
        }
        text = text.replacing(/^(<\?xml[^>]*?)encoding\s*=\s*["'][^"']*["']/, with: { "\($0.output.1)encoding=\"UTF-8\"" })
        text = removeInvalidScalars(text)
        text = repairEntities(text)
        return Data(text.utf8)
    }

    /// Decodes with the declared encoding, then UTF-8, then Latin-1 (which never fails).
    private static func decode(_ data: Data) -> String {
        if let declared = declaredEncoding(data), let text = String(data: data, encoding: declared) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
    }

    private static func declaredEncoding(_ data: Data) -> String.Encoding? {
        let head = String(decoding: data.prefix(200), as: UTF8.self)
        guard let match = head.firstMatch(of: /encoding\s*=\s*["']([A-Za-z0-9._-]+)["']/) else { return nil }
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(String(match.output.1) as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
    }

    private static func removeInvalidScalars(_ text: String) -> String {
        guard text.unicodeScalars.contains(where: { !HTMLEntities.isValidXMLScalar($0.value) }) else { return text }
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: text.unicodeScalars.filter { HTMLEntities.isValidXMLScalar($0.value) })
        return String(scalars)
    }

    private static func repairEntities(_ text: String) -> String {
        text.replacing(/&(?:(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{0,31});)?/) { match in
            guard let name = match.output.1 else { return "&amp;" }
            if name.hasPrefix("#") {
                let scalar = TextCleaner.scalar(forEntity: name)
                return scalar.map { HTMLEntities.isValidXMLScalar($0.value) } == true ? String(match.output.0) : ""
            }
            if HTMLEntities.xmlPredefined.contains(String(name)) { return String(match.output.0) }
            if let scalar = HTMLEntities.named[String(name)] { return "&#\(scalar.value);" }
            return "&amp;\(name);"
        }
    }
}
