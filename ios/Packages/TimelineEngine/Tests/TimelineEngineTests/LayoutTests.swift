import Testing
@testable import TimelineEngine

@Suite("Calcul des heures du jour (T1–T5)")
struct LayoutTests {
    @Test func emptyDay() {
        let layout = Day([]).layout()
        #expect(layout.placements.isEmpty)
        #expect(layout.totalPushedMinutes == 0)
        #expect(layout.endOfDay == nil)
    }

    @Test("T1 cascade : rallonger B décale C, jamais A")
    func cascade() {
        var day = Day([.float("A", 30), .float("B", 60), .float("C", 15)])
        #expect(day.starts() == ["A": "09:00", "B": "09:30", "C": "10:30"])

        day.setDuration("B", 90)
        #expect(day.starts() == ["A": "09:00", "B": "09:30", "C": "11:00"])
    }

    @Test("T2 poussée entière après une ancre")
    func pushedWhole() {
        let day = Day([.float("A", 90), .anchor("M", "10:00", 60), .float("B", 30)])
        #expect(day.starts() == ["A": "11:00", "M": "10:00", "B": "12:30"])
        #expect(day.placement("A").end == hm("12:30"))
        #expect(day.placement("A").pushedPastAnchor == day.ids["M"])
        #expect(day.sequence() == ["M", "A", "B"])
        #expect(day.layout().totalPushedMinutes == 120)
    }

    @Test("T3 trou autorisé avant une ancre")
    func gapAllowed() {
        let afterAnchor = Day([.anchor("M", "14:00", 60), .float("A", 30)])
        #expect(afterAnchor.starts() == ["M": "14:00", "A": "15:00"])

        let around = Day([.float("A", 30), .anchor("M", "14:00", 60), .float("B", 30)])
        #expect(around.starts() == ["A": "09:00", "M": "14:00", "B": "15:00"])
        #expect(around.placement("M").gapBefore == 270)
        #expect(around.placement("B").gapBefore == 0)
        #expect(around.layout().totalPushedMinutes == 0)
    }

    @Test("T4 double enjambement et ancre avant le début du jour")
    func doubleSkip() {
        let day = Day([
            .anchor("M0", "07:00", 60), .float("A", 120),
            .anchor("M1", "09:30", 30), .anchor("M2", "10:15", 30),
        ])
        #expect(day.placement("A").start == hm("10:45"))
        #expect(day.placement("A").end == hm("12:45"))
        #expect(day.placement("A").pushedPastAnchor == day.ids["M2"])
        #expect(day.placement("M0").start == hm("07:00"))
        #expect(day.sequence() == ["M0", "M1", "M2", "A"])
    }

    @Test("T5 ancres chevauchantes stockées dans le désordre")
    func overlappingAnchors() {
        let day = Day([.anchor("M2", "10:30", 60), .anchor("M1", "10:00", 60), .float("A", 30)])
        #expect(day.sequence() == ["M1", "M2", "A"])
        #expect(day.placement("M1").overlapsAnchor)
        #expect(day.placement("M2").overlapsAnchor)
        #expect(day.placement("A").start == hm("11:30"))
        #expect(!day.placement("A").overlapsAnchor)
    }

    @Test func customDayStart() {
        let day = Day([.float("A", 30), .float("B", 30)])
        #expect(day.starts(dayStart: hm("07:30")) == ["A": "07:30", "B": "08:00"])
    }

    @Test func doneTasksKeepTheirSlot() {
        // Cocher ne change ni durée ni ordre (cahier §4.4) : le moteur ne voit aucune différence.
        let day = Day([.float("A", 30), .float("B", 45), .float("C", 15)])
        #expect(day.starts() == ["A": "09:00", "B": "09:30", "C": "10:15"])
    }
}
