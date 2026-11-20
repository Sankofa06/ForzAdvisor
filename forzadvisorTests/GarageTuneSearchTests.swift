import XCTest
@testable import forzadvisor

final class GarageTuneSearchTests: XCTestCase {
    func testSearchCombinesCarDisciplineAndNotes() {
        let fields = ["1997 Mazda Miata", "Road", "A 750", "RWD", "Wet weather"]
        XCTAssertTrue(GarageTuneSearch.matches("mazda wet rwd", fields: fields))
        XCTAssertFalse(GarageTuneSearch.matches("mazda drift", fields: fields))
    }

    func testSearchIgnoresExtraWhitespaceCaseAndDiacritics() {
        XCTAssertTrue(GarageTuneSearch.matches("  citroen\nRALLY  ", fields: ["Citroën", "Rally"]))
        XCTAssertTrue(GarageTuneSearch.matches(" \n ", fields: ["Any car"]))
    }

    func testClassAndPerformanceIndexRemainSearchable() {
        let fields = ["Mazda Miata", "A 750"]
        XCTAssertTrue(GarageTuneSearch.matches("A 750", fields: fields))
        XCTAssertFalse(GarageTuneSearch.matches("S1 900", fields: fields))
    }
}
