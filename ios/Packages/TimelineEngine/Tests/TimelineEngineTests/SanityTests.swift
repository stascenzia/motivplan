import Testing
@testable import TimelineEngine

@Test func defaultDayStartIsNineAM() {
    #expect(TimelineEngine.defaultDayStart == 540)
}
