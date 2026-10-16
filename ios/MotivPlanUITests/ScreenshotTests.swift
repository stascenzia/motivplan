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

        XCTAssertTrue(element(app, "Finir le rapport trimestriel").waitForExistence(timeout: 30))
        snapshot(app, "01-jour")

        app.buttons["drawer-handle"].tap()
        XCTAssertTrue(element(app, "Appeler le plombier").waitForExistence(timeout: 15))
        snapshot(app, "02-jour-tiroir")
        app.buttons["drawer-handle"].tap()

        element(app, "Point d'équipe").tap()
        XCTAssertTrue(app.navigationBars["Tâche"].waitForExistence(timeout: 15))
        snapshot(app, "03-detail-ancre")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Réglages"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 15))
        snapshot(app, "04-reglages")
        app.buttons["OK"].tap()
    }

    @MainActor
    func testInboxScreens() throws {
        let app = launch()
        app.buttons["tab-Boîte"].tap()

        let plumber = element(app, "Appeler le plombier")
        XCTAssertTrue(plumber.waitForExistence(timeout: 30))
        snapshot(app, "11-boite-de-reception")

        // Toucher une tâche la déplie et montre les actions rapides.
        plumber.tap()
        let pick = app.buttons["Planifier le…"]
        XCTAssertTrue(pick.waitForExistence(timeout: 15))
        snapshot(app, "12-actions-rapides")
        pick.tap()
        XCTAssertTrue(app.buttons["Valider"].waitForExistence(timeout: 15))
        snapshot(app, "14-planifier-le")
        app.buttons["Annuler"].tap()

        element(app, "Renouveler le passeport").tap()
        let detail = app.buttons["Détail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 15))
        snapshot(app, "15-actions-passeport")
        detail.tap()
        XCTAssertTrue(app.navigationBars["Tâche"].waitForExistence(timeout: 15))
        snapshot(app, "16-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let field = app.textFields["inbox-capture-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Racheter du café\n")
        XCTAssertTrue(element(app, "Racheter du café").waitForExistence(timeout: 15))
        snapshot(app, "17-apres-capture")
    }

    /// Calendrier, mode Semaine : une carte par jour, toucher un jour ouvre sa frise.
    @MainActor
    func testWeekScreen() throws {
        let app = launch()
        app.buttons["tab-Calendrier"].tap()
        XCTAssertTrue(element(app, "Dîner chez Paul").waitForExistence(timeout: 30))
        snapshot(app, "41-semaine")

        app.buttons["Semaine suivante"].tap()
        snapshot(app, "42-semaine-suivante")
        app.buttons["Cette semaine"].tap()

        let today = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "aujourd'hui")).firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 15))
        today.tap()
        XCTAssertTrue(element(app, "Finir le rapport trimestriel").waitForExistence(timeout: 15))
    }

    /// Sections et seconde mémoire (ADR-014) : tuiles de la boîte, puis écran de section.
    @MainActor
    func testSectionScreens() throws {
        let app = launch()
        app.buttons["tab-Boîte"].tap()

        XCTAssertTrue(element(app, "Quotidiennes").waitForExistence(timeout: 30))
        let films = element(app, "Films et séries")
        scrollIntoView(app, films)
        films.tap()
        XCTAssertTrue(element(app, "The Bear").waitForExistence(timeout: 15))
        snapshot(app, "31-boite-tuile-films")

        let open = app.buttons["Section et mémoire"]
        scrollIntoView(app, open)
        open.tap()
        XCTAssertTrue(app.buttons["Modifier"].waitForExistence(timeout: 15))
        snapshot(app, "32-section-a-voir")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mémoire")).firstMatch.tap()
        XCTAssertTrue(element(app, "Past Lives").waitForExistence(timeout: 15))
        snapshot(app, "33-section-memoire")

        app.buttons["Modifier"].tap()
        XCTAssertTrue(app.navigationBars["Section"].waitForExistence(timeout: 15))
        snapshot(app, "34-editeur-section")
        app.buttons["Annuler"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let recurring = element(app, "Récurrentes")
        XCTAssertTrue(recurring.waitForExistence(timeout: 15))
        recurring.tap()
        let laundry = element(app, "Faire une lessive")
        scrollIntoView(app, laundry)
        XCTAssertTrue(laundry.waitForExistence(timeout: 15))
        snapshot(app, "35-boite-tuile-recurrentes")
    }

    /// Le bouton « + » ouvre la capture plein écran ; on enchaîne deux captures.
    @MainActor
    func testCaptureButton() throws {
        let app = launch()
        let plus = app.buttons["tab-capture"]
        XCTAssertTrue(plus.waitForExistence(timeout: 30))
        plus.tap()

        let field = app.textFields["capture-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15))
        // Sur la CI, le champ peut perdre les premières frappes pendant l'animation d'ouverture.
        field.tap()
        field.typeText("Rappeler le garage\n")
        XCTAssertTrue(element(app, "Rappeler le garage").waitForExistence(timeout: 15))
        field.typeText("Sortir les poubelles")
        snapshot(app, "05-capture")
        app.buttons["Fermer"].tap()
    }

    /// Le widget ouvre `motivplan://capture` : capture plein écran, clavier levé, source « widget ».
    @MainActor
    func testWidgetDeepLink() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["tab-Planning"].waitForExistence(timeout: 30))
        app.open(URL(string: "motivplan://capture")!)

        let field = app.textFields["capture-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 15))
        snapshot(app, "21-capture-depuis-widget")
        field.tap()
        field.typeText("Idée captée par le widget\n")
        XCTAssertTrue(element(app, "Idée captée par le widget").waitForExistence(timeout: 15))
    }

    /// La barre d'onglets flottante recouvre le bas de l'écran : on fait défiler doucement
    /// jusqu'à ce que l'élément soit au-dessus.
    @MainActor
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) {
        let limit = app.frame.height * 0.7
        // Une pile paresseuse ne crée ses lignes qu'à l'approche de l'écran : on défile tant qu'elle manque.
        for _ in 0..<6 where !element.exists || element.frame.maxY > limit {
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        }
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
        return app
    }

    /// Une ligne regroupe ses textes dans un seul libellé : on cherche par début de libellé.
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
