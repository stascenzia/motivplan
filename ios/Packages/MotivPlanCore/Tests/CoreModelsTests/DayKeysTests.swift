import Foundation
import Testing
@testable import CoreModels

@Suite("Clés-jour")
struct DayKeysTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    @Test func roundTrip() throws {
        let date = try #require(DayKeys.date(from: "2026-03-29", calendar: calendar))
        #expect(DayKeys.key(for: date, calendar: calendar) == "2026-03-29")
    }

    @Test("Passage de mois, d'année et changement d'heure")
    func adding() {
        #expect(DayKeys.adding(1, to: "2026-10-31", calendar: calendar) == "2026-11-01")
        #expect(DayKeys.adding(1, to: "2026-12-31", calendar: calendar) == "2027-01-01")
        #expect(DayKeys.adding(1, to: "2026-10-24", calendar: calendar) == "2026-10-25")
        #expect(DayKeys.adding(1, to: "2026-10-25", calendar: calendar) == "2026-10-26")
    }

    @Test("Semaine du lundi au dimanche")
    func week() {
        #expect(DayKeys.startOfWeek(containing: "2026-10-14", calendar: calendar) == "2026-10-12")
        #expect(DayKeys.endOfWeek(containing: "2026-10-14", calendar: calendar) == "2026-10-18")
        #expect(DayKeys.endOfWeek(containing: "2026-10-18", calendar: calendar) == "2026-10-18")
        #expect(DayKeys.startOfWeek(containing: "2026-10-12", calendar: calendar) == "2026-10-12")
    }
}
