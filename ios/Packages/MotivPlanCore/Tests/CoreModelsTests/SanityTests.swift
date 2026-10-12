import Testing
@testable import CoreModels

@Test func captureURLUsesAppScheme() {
    #expect(AppGroup.captureURL.scheme == AppGroup.urlScheme)
    #expect(AppGroup.captureURL.host() == "capture")
}
