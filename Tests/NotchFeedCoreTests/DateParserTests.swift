import Foundation
import Testing
@testable import NotchFeedCore

struct DateParserTests {
    /// 2026-10-27 09:30:00 UTC
    private static let reference = Date(timeIntervalSince1970: 1_793_093_400)

    @Test(arguments: [
        "Tue, 27 Oct 2026 09:30:00 +0000",
        "Tue, 27 Oct 2026 09:30:00 GMT",
        "Tue, 27 Oct 2026 09:30:00 UT",
        "Tue, 27 Oct 2026 09:30:00 Z",
        "Tue, 27 Oct 2026 10:30:00 +0100",
        "Tue, 27 Oct 2026 11:30:00 +02:00",
        "Tue, 27 Oct 2026 05:30:00 EDT",
        "Tue, 27 Oct 2026 04:30:00 EST",
        "Tue, 27 Oct 2026 02:30:00 PDT",
        "Tue, 27 Oct 2026 09:30 +0000",
        "Tue, 27 Oct 2026 09:30:00",
        "27 Oct 2026 09:30:00 +0000",
        "Tue,27 Oct 2026 09:30:00 +0000",
        "Tue, 27 Oct 26 09:30:00 +0000",
        "Tue, 27 October 2026 09:30:00 GMT",
        "  Tue,  27   Oct 2026  9:30:00 GMT  ",
        "Tuesday, 27 Oct 2026 09:30:00 GMT",
    ])
    func parsesRFC822Variants(_ string: String) {
        #expect(DateParser().date(from: string) == Self.reference)
    }

    @Test(arguments: [
        "2026-10-27T09:30:00Z",
        "2026-10-27T09:30:00+00:00",
        "2026-10-27T10:30:00+01:00",
        "2026-10-27T10:30:00+0100",
        "2026-10-27T09:30:00.000Z",
        "2026-10-27T09:30:00.123456Z",
        "2026-10-27T09:30:00",
        "2026-10-27 09:30:00",
        "2026-10-27T09:30Z",
    ])
    func parsesISO8601Variants(_ string: String) throws {
        let date = try #require(DateParser().date(from: string))
        // Fractional seconds are dropped on purpose.
        #expect(abs(date.timeIntervalSince(Self.reference)) < 1)
    }

    @Test func parsesDateOnlyAsMidnightUTC() {
        #expect(DateParser().date(from: "2026-10-27") == Date(timeIntervalSince1970: 1_793_059_200))
    }

    @Test(arguments: ["", "yesterday-ish", "32 Foo 2026 99:99:99", "Tue, 27 Oct", "2026-13-45T00:00:00Z"])
    func rejectsGarbage(_ string: String) {
        #expect(DateParser().date(from: string) == nil)
    }
}
