import XCTest
@testable import VibeCodingBreath

final class ConstantsTests: XCTestCase {
    func testValues() {
        XCTAssertEqual(Constants.idleThreshold, 5.0)
        XCTAssertEqual(Constants.pollInterval, 0.5)
        XCTAssertEqual(Constants.minDiameter, 120)
        XCTAssertEqual(Constants.maxDiameter, 320)
        XCTAssertEqual(Constants.overlayPadding, 64)
        XCTAssertEqual(Constants.fadeIn, 0.4)
        XCTAssertEqual(Constants.fadeOut, 0.2)
        XCTAssertEqual(Constants.primaryHex, "#7FB3D5")
        XCTAssertEqual(Constants.bundleIdentifier, "pro.nanzhi.VibeCodingBreath")
    }
}
