import AppKit
import XCTest
@testable import Menyradio

final class MenuTextTests: XCTestCase {
    @MainActor func testLongLabelsFitRenderedWidthAndPreserveShortTitles() {
        XCTAssertEqual(menuText("P1", width: 300), "P1")
        for text in [String(repeating: "W", count: 100), String(repeating: "i", count: 100), String(repeating: "🎙️ Sveriges Radio ", count: 30)] {
            let result = menuText(text, width: 300)
            XCTAssertTrue(result.hasSuffix("…"))
            XCTAssertLessThanOrEqual((result as NSString).size(withAttributes: [.font: NSFont.menuFont(ofSize: 0)]).width, 300)
        }
        XCTAssertEqual(menuText("Long title", width: 0), "")
    }
}
