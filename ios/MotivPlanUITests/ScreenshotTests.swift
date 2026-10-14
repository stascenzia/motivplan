import XCTest

/// Parcourt les écrans avec des données d'exemple et garde une capture de chacun.
/// La CI les exporte en artefact : c'est ainsi qu'on voit l'interface sans Mac.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testDayScreens() throws {
        let app = launch()

        XCTAssertTrue(element(app, "Finir le rapport trimestriel").waitForExistence(timeout: 10))
        snapshot(app, "01-jour")

        app.buttons["drawer-handle"].tap()
        XCTAssertTrue(element(app, "Appeler le plombier").waitForExistence(timeout: 5))
        snapshot(app, "02-jour-tiroir")
        app.buttons["drawer-handle"].tap()

        element(app, "Point d'équipe").tap()
        XCTAssertTrue(app.navigationBars["Tâche"].waitForExistence(timeout: 5))
        snapshot(app, "03-detail-ancre")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))
        snapshot(app, "04-reglages")
        app.buttons["OK"].tap()
    }

    @MainActor
    func testInboxScreens() throws {
        let app = launch()
        app.tabBars.buttons["Boîte"].tap()

        let plumber = element(app, "Appeler le plombier")
        XCTAssertTrue(plumber.waitForExistence(timeout: 10))
        snapshot(app, "11-boite-de-reception")

        plumber.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Planifier"].waitForExistence(timeout: 5))
        snapshot(app, "12-menu-contextuel")
        app.buttons["Planifier"].tap()
        snapshot(app, "13-sous-menu-planifier")
        app.buttons["Planifier le…"].tap()
        XCTAssertTrue(app.buttons["Valider"].waitForExistence(timeout: 5))
        snapshot(app, "14-planifier-le")
        app.buttons["Annuler"].tap()

        element(app, "Renouveler le passeport").tap()
        XCTAssertTrue(app.navigationBars["Tâche"].waitForExistence(timeout: 5))
        snapshot(app, "15-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let field = app.textFields["capture-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Racheter du café\n")
        XCTAssertTrue(element(app, "Racheter du café").waitForExistence(timeout: 5))
        snapshot(app, "16-apres-capture")
    }

    /// Sections et seconde mémoire (ADR-014).
    @MainActor
    func testSectionScreens() throws {
        let app = launch()
        app.tabBars.buttons["Boîte"].tap()

        let films = element(app, "Films et séries")
        XCTAssertTrue(films.waitForExistence(timeout: 10))
        scrollIntoView(app, films)
        snapshot(app, "31-sections")
        films.tap()
        XCTAssertTrue(element(app, "The Bear").waitForExistence(timeout: 5))
        snapshot(app, "32-section-a-voir")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mémoire")).firstMatch.tap()
        XCTAssertTrue(element(app, "Past Lives").waitForExistence(timeout: 5))
        snapshot(app, "33-section-memoire")

        app.buttons["Modifier"].tap()
        XCTAssertTrue(app.navigationBars["Section"].waitForExistence(timeout: 5))
        snapshot(app, "34-editeur-section")
        app.buttons["Annuler"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let recurring = element(app, "Récurrentes")
        scrollIntoView(app, recurring)
        recurring.tap()
        XCTAssertTrue(element(app, "Faire une lessive").waitForExistence(timeout: 5))
        snapshot(app, "35-section-recurrentes")
    }

    /// Le widget ouvre `motivplan://capture` : boîte de réception, clavier levé, source « widget ».
    @MainActor
    func testWidgetDeepLink() throws {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Jour"].waitForExistence(timeout: 10))
        app.open(URL(string: "motivplan://capture")!)

        let field = app.textFields["capture-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "21-capture-depuis-widget")
        field.typeText("Idée captée par le widget\n")
        XCTAssertTrue(element(app, "Idée captée par le widget").waitForExistence(timeout: 5))
    }

    /// La barre d'onglets flottante d'iOS 26 recouvre le bas de l'écran : on fait défiler
    /// doucement jusqu'à ce que l'élément soit au-dessus.
    @MainActor
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) {
        let limit = app.frame.height * 0.7
        for _ in 0..<6 where element.frame.maxY > limit {
            app.collectionViews.firstMatch.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    /// Une ligne de liste regroupe ses textes dans un seul libellé : on cherche par début de libellé.
    @MainActor
    private func element(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", title))
            .firstMatch
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
