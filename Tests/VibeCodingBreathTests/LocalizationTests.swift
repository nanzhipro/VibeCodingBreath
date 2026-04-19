import XCTest
@testable import VibeCodingBreath

final class LocalizationTests: XCTestCase {
    private let keys: [String] = [
        "status.menu.open",
        "status.menu.quit",
        "phase.inhale",
        "phase.hold.afterInhale",
        "phase.exhale",
        "phase.hold.afterExhale"
    ]

    func testEnglishKeysResolve() throws {
        try assertAllKeysResolve(in: "en")
    }

    func testSimplifiedChineseKeysResolve() throws {
        try assertAllKeysResolve(in: "zh-Hans")
    }

    private func assertAllKeysResolve(in language: String) throws {
        let module = AppResources.bundle
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: module.bundlePath)) ?? []
        let wanted = language.lowercased() + ".lproj"
        guard let match = contents.first(where: { $0.lowercased() == wanted }),
              let lproj = Bundle(path: (module.bundlePath as NSString).appendingPathComponent(match)) else {
            XCTFail("Missing \(language).lproj in module bundle (have: \(contents))")
            return
        }
        for key in keys {
            let value = lproj.localizedString(forKey: key, value: "__MISSING__", table: nil)
            XCTAssertNotEqual(
                value, "__MISSING__",
                "Localization key '\(key)' missing in \(language)"
            )
            XCTAssertFalse(value.isEmpty, "Empty localization for '\(key)' in \(language)")
        }
    }
}
