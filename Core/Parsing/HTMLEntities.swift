/// Named HTML entities that feeds commonly use but XML doesn't define.
enum HTMLEntities {
    static let xmlPredefined: Set<String> = ["amp", "lt", "gt", "quot", "apos"]

    static let named: [String: Unicode.Scalar] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{A0}", "copy": "\u{A9}", "reg": "\u{AE}", "trade": "\u{2122}",
        "hellip": "\u{2026}", "mdash": "\u{2014}", "ndash": "\u{2013}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "sbquo": "\u{201A}",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "bdquo": "\u{201E}",
        "laquo": "\u{AB}", "raquo": "\u{BB}", "bull": "\u{2022}", "middot": "\u{B7}",
        "euro": "\u{20AC}", "pound": "\u{A3}", "yen": "\u{A5}", "cent": "\u{A2}", "deg": "\u{B0}",
        "times": "\u{D7}", "divide": "\u{F7}", "plusmn": "\u{B1}", "frac12": "\u{BD}",
        "aacute": "\u{E1}", "agrave": "\u{E0}", "acirc": "\u{E2}", "auml": "\u{E4}", "aring": "\u{E5}",
        "eacute": "\u{E9}", "egrave": "\u{E8}", "ecirc": "\u{EA}", "euml": "\u{EB}",
        "iacute": "\u{ED}", "igrave": "\u{EC}", "icirc": "\u{EE}", "iuml": "\u{EF}",
        "oacute": "\u{F3}", "ograve": "\u{F2}", "ocirc": "\u{F4}", "ouml": "\u{F6}", "oslash": "\u{F8}",
        "uacute": "\u{FA}", "ugrave": "\u{F9}", "ucirc": "\u{FB}", "uuml": "\u{FC}",
        "ccedil": "\u{E7}", "ntilde": "\u{F1}", "szlig": "\u{DF}",
        "Aacute": "\u{C1}", "Auml": "\u{C4}", "Eacute": "\u{C9}", "Ouml": "\u{D6}", "Uuml": "\u{DC}",
    ]

    /// XML 1.0 allows tab, newline, carriage return and most scalars from U+0020 up.
    static func isValidXMLScalar(_ value: UInt32) -> Bool {
        switch value {
        case 0x9, 0xA, 0xD, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
        default: false
        }
    }
}
