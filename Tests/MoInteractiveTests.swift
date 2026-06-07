//
//  MoInteractiveTests.swift
//  BurrowTests
//
//  The safety-critical core of driving Mole's selection TUI: parsing a
//  rendered frame and planning the toggle keystrokes. Both are pure. The
//  fixture is a real captured frame from `mo installer` (cursor on the
//  last row, two items checked).
//

import XCTest
@testable import Burrow

final class MoInteractiveTests: XCTestCase {
    // A real `mo installer` frame: row 0 unchecked, rows 1 & 2 checked,
    // cursor (➤) on row 2, header reports "2 selected".
    private let frame = """
    Select Installers to Remove , 1.26GB, 2 selected
      \u{25CB} Inkling-0.0.1.dmg                           771KB | Desktop
      \u{25CF} Inkling-0.1.0.dmg                           760KB | Desktop
    \u{27A4} \u{25CF} marvis_1.0.10034_arm64_4000000002.dmg      1.26GB | Desktop
    \u{2191}\u{2193}  |  Space Select  |  Enter Confirm  |  A All  |  I Invert  |  Q Quit
    """

    func testParse_extractsItemsSelectionCursorAndCount() {
        let screen = MoTUI.parse(frame)
        XCTAssertEqual(screen.items.count, 3)
        XCTAssertEqual(screen.items.map { $0.name },
                       ["Inkling-0.0.1.dmg", "Inkling-0.1.0.dmg", "marvis_1.0.10034_arm64_4000000002.dmg"])
        XCTAssertEqual(screen.items.map { $0.selected }, [false, true, true])
        XCTAssertEqual(screen.items[2].size, "1.26GB")
        XCTAssertEqual(screen.items[0].location, "Desktop")
        XCTAssertEqual(screen.cursor, 2, "the ➤ row")
        XCTAssertEqual(screen.selectedCount, 2)
        XCTAssertEqual(MoTUI.selectedIndices(screen), [1, 2])
    }

    func testParse_keepsOnlyTheLastFrame() {
        // Two frames concatenated (as the PTY accumulates redraws). The
        // second frame (1 selected) must win.
        let twoFrames = """
        Select Installers to Remove , 0B, 0 selected
        \u{27A4} \u{25CB} a.dmg   1KB | Downloads
          \u{25CB} b.pkg   2KB | Downloads
        Select Installers to Remove , 1KB, 1 selected
          \u{25CB} a.dmg   1KB | Downloads
        \u{27A4} \u{25CF} b.pkg   2KB | Downloads
        """
        let screen = MoTUI.parse(twoFrames)
        XCTAssertEqual(screen.items.count, 2)
        XCTAssertEqual(MoTUI.selectedIndices(screen), [1])
        XCTAssertEqual(screen.cursor, 1)
        XCTAssertEqual(screen.selectedCount, 1)
    }

    func testKeystrokes_walkOnceTogglingWantedThenEnter() {
        // Select only index 1 of 3, then confirm. From a fresh list the
        // cursor is at 0, so: Down (→1), Space (toggle 1), Down (→2), Enter.
        let down: [UInt8] = [0x1b, 0x5b, 0x42]
        let expected = down + [0x20] + down + [0x0d]
        XCTAssertEqual(MoTUI.keystrokesToSelect([1], count: 3, confirm: true), expected)
    }

    func testKeystrokes_emptySelectionNeverConfirms() {
        // No items wanted → never press Enter (don't let Mole act on nothing).
        let keys = MoTUI.keystrokesToSelect([], count: 3, confirm: true)
        XCTAssertFalse(keys.contains(0x0d), "must not send Enter for an empty selection")
    }

    func testKeystrokes_selectAll() {
        let down: [UInt8] = [0x1b, 0x5b, 0x42]
        let expected = [UInt8](arrayLiteral: 0x20) + down + [0x20] + down + [0x20] + [0x0d]
        XCTAssertEqual(MoTUI.keystrokesToSelect([0, 1, 2], count: 3, confirm: true), expected)
    }
}
