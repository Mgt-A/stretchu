import XCTest
@testable import Stretchu

final class BarTimerTests: XCTestCase {
    func testTwoMinuteDigitsAbove10Minutes() {
        XCTAssertEqual(Format.barTimer(25 * 60), "25:00")
        XCTAssertEqual(Format.barTimer(10 * 60), "10:00")
        XCTAssertEqual(Format.barTimer(12 * 60 + 5), "12:05")
    }

    func testOneDigitBelow10Minutes() {
        XCTAssertEqual(Format.barTimer(9 * 60 + 59), "9:59")
        XCTAssertEqual(Format.barTimer(59), "0:59")
        XCTAssertEqual(Format.barTimer(0), "0:00")
    }
}

final class FixedPillTests: XCTestCase {
    func testAllDigitsHaveTheSameCell() {
        let cells = (0...9).map { TimerWidth.cellWidth(Character("\($0)")) }
        XCTAssertEqual(Set(cells).count, 1, "a digit never shifts the next one")
    }

    func testAllTimerStringsHaveTheSameWidth() {
        let reference = TimerWidth.textWidth("00:00")
        for text in ["25:00", "24:59", "11:11", "10:08", "20:20", "19:47"] {
            XCTAssertEqual(TimerWidth.textWidth(text), reference, accuracy: 0.001, text)
        }
        let short = TimerWidth.textWidth("0:00")
        for text in ["9:59", "1:11", "0:08"] {
            XCTAssertEqual(TimerWidth.textWidth(text), short, accuracy: 0.001, text)
        }
        XCTAssertLessThan(short, reference)
    }

    func testThePillDoesNotMoveBetweenTheTimerAndBreak() {
        // Clicking "Take a break now" at 21:00: "Break" takes the same slot as "21:00".
        for language in ["en", "fr"] {
            let pause = tr("pill.pause", language: language)
            let timer = TimerWidth.slot(.timer(minuteDigits: 2), pauseText: pause)
            XCTAssertEqual(TimerWidth.slot(.pause, pauseText: pause), timer, accuracy: 0.001)
            XCTAssertEqual(TimerWidth.slot(.waiting, pauseText: pause), timer, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(timer, TimerWidth.textWidth("00:00"))
            XCTAssertGreaterThanOrEqual(timer, TimerWidth.textWidth(pause))
        }
    }

    func testUnderTenMinutesTheSlotNarrows() {
        XCTAssertLessThan(TimerWidth.slot(.timer(minuteDigits: 1)), TimerWidth.slot(.timer(minuteDigits: 2)))
    }
}

final class PillSizeTests: XCTestCase {
    func testTheTimerSlotIsNotRoundedUpToTheNextPoint() {
        // Four digits plus a colon: the exact width, not 4 cells each rounded.
        let exact = 4 * TimerWidth.cellWidth("0") + TimerWidth.cellWidth(":")
        XCTAssertEqual(TimerWidth.textWidth("00:00"), exact, accuracy: 0.001)
        XCTAssertLessThanOrEqual(TimerWidth.textWidth("00:00"), 38, "the timer stays compact")
    }

    func testTheWholePillStaysUnderACompactIconsWidth() {
        // sprite 17 (20 pt tall) + gap 3 + slot + 2 × 4 margin, without Debug.
        let total = 17 + 3 + TimerWidth.slot(.timer(minuteDigits: 2)) + 8
        XCTAssertLessThanOrEqual(total, 66)
    }
}
