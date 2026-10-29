import CryptoKit
import Foundation

/// FR-4.6: identifies an item within its feed by GUID, then link, then a hash of title and date.
/// Keys are scoped per feed; merging across feeds is backlog BL-05.
public enum DedupeKey {
    public static func make(feedID: UUID, item: ParsedItem) -> String {
        let prefix = feedID.uuidString + "|"
        if let guid = item.guid?.trimmingCharacters(in: .whitespacesAndNewlines), !guid.isEmpty {
            return prefix + "g:" + guid
        }
        if let link = item.link {
            return prefix + "l:" + link.absoluteString
        }
        let date = item.publishedAt.map { String($0.timeIntervalSince1970) } ?? ""
        let digest = SHA256.hash(data: Data((item.title + "|" + date).utf8))
        return prefix + "h:" + digest.map { String(format: "%02x", $0) }.joined()
    }
}
