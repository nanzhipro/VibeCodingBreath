import XCTest

@testable import VibeCodingBreath

final class LocalizationTests: XCTestCase {
  func testStringsResolveInBundle() {
    let keys = [
      "status.menu.open",
      "status.menu.quit",
      "breath.phase.inhale",
      "breath.phase.hold",
      "breath.phase.exhale",
    ]
    for key in keys {
      let resolved = String(localized: String.LocalizationValue(key), bundle: .module)
      XCTAssertNotEqual(resolved, key, "Key '\(key)' did not resolve to a localized string")
      XCTAssertFalse(resolved.isEmpty, "Key '\(key)' resolved to empty string")
    }
  }
}
