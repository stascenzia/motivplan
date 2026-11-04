import Testing
@testable import MemoryImport

@Suite("Découpage d'une recette")
struct RecipeParserTests {
    @Test("Recette classique avec titres, puces et étapes numérotées")
    func classic() {
        let recipe = RecipeParser.parse("""
            Tarte aux pommes
            Ingrédients (6 personnes) :
            - 1 pâte brisée
            - 4 pommes
            - 50 g de sucre
            - 1 sachet de sucre vanillé
            - 30 g de beurre
            Préparation :
            1. Préchauffer le four à 180 °C.
            2. Étaler la pâte dans un moule et la piquer
            à la fourchette.
            3. Éplucher les pommes, les couper en lamelles et les disposer sur la pâte.
            4. Saupoudrer de sucre, parsemer de beurre et enfourner 35 minutes.
            """)
        #expect(recipe.title == "Tarte aux pommes")
        #expect(recipe.servings == 6)
        #expect(recipe.ingredients == ["1 pâte brisée", "4 pommes", "50 g de sucre", "1 sachet de sucre vanillé", "30 g de beurre"])
        #expect(recipe.steps == [
            "Préchauffer le four à 180 °C.",
            "Étaler la pâte dans un moule et la piquer à la fourchette.",
            "Éplucher les pommes, les couper en lamelles et les disposer sur la pâte.",
            "Saupoudrer de sucre, parsemer de beurre et enfourner 35 minutes.",
        ])
    }

    @Test("Capture d'écran de Picnic : quantités en colonne, numéros seuls, bruit de l'app")
    func picnicScreenshot() {
        let recipe = RecipeParser.parse(lines: [
            "Curry de lentilles corail",
            "30 min",
            "Facile",
            "4,6 (128 avis)",
            "Ingrédients",
            "2 personnes",
            "Lentilles corail",
            "200 g",
            "Lait de coco",
            "1 boîte",
            "Oignon",
            "1 pièce",
            "Dans votre placard",
            "Huile d'olive",
            "Sel et poivre",
            "Préparation",
            "1",
            "Émincez l'oignon et faites-le revenir 5 min dans",
            "l'huile d'olive.",
            "2",
            "Ajoutez les lentilles rincées et le lait de coco.",
            "3",
            "Laissez mijoter 20 min. Salez, poivrez.",
            "Ajouter au panier",
        ])
        #expect(recipe.title == "Curry de lentilles corail")
        #expect(recipe.duration == "30 min")
        #expect(recipe.servings == 2)
        #expect(recipe.ingredients == [
            "Lentilles corail (200 g)", "Lait de coco (1 boîte)", "Oignon (1 pièce)", "Huile d'olive", "Sel et poivre",
        ])
        #expect(recipe.steps == [
            "Émincez l'oignon et faites-le revenir 5 min dans l'huile d'olive.",
            "Ajoutez les lentilles rincées et le lait de coco.",
            "Laissez mijoter 20 min. Salez, poivrez.",
        ])
    }

    @Test("Site de recettes : « Étape 1 », temps de préparation et de cuisson")
    func etapes() {
        let recipe = RecipeParser.parse("""
            Gratin de courgettes
            Temps total : 45 min
            Ingrédients
            4 personnes
            3 courgettes
            20 cl de crème fraîche
            100 g de gruyère râpé
            Préparation
            Préparation : 15 min
            Cuisson : 30 min
            Étape 1
            Préchauffez le four à 200 °C.
            Étape 2
            Coupez les courgettes en rondelles et disposez-les dans un plat.
            Étape 3 : Nappez de crème, parsemez de gruyère et enfournez.
            """)
        #expect(recipe.title == "Gratin de courgettes")
        #expect(recipe.duration == "45 min")
        #expect(recipe.servings == 4)
        #expect(recipe.ingredients == ["3 courgettes", "20 cl de crème fraîche", "100 g de gruyère râpé"])
        #expect(recipe.steps == [
            "Préchauffez le four à 200 °C.",
            "Coupez les courgettes en rondelles et disposez-les dans un plat.",
            "Nappez de crème, parsemez de gruyère et enfournez.",
        ])
    }

    @Test("Texte collé sans titres : quantités puis phrases")
    func freeText() {
        let recipe = RecipeParser.parse("""
            Pâtes carbonara
            200 g de spaghetti
            2 jaunes d'œufs
            100 g de guanciale
            Pecorino
            Faire cuire les pâtes dans une grande casserole d'eau salée.
            Faire dorer le guanciale à sec dans une poêle.
            Mélanger les jaunes et le pecorino, puis tout assembler hors du feu.
            """)
        #expect(recipe.title == "Pâtes carbonara")
        #expect(recipe.ingredients == ["200 g de spaghetti", "2 jaunes d'œufs", "100 g de guanciale", "Pecorino"])
        #expect(recipe.steps.count == 3)
    }

    @Test("Étapes sans numéros, une par ligne, sans point final")
    func unnumberedSteps() {
        let recipe = RecipeParser.parse("""
            Ingrédients
            200 g de lentilles corail
            1 oignon
            Étapes
            Faire revenir l'oignon
            Ajouter les épices
            Cuire les lentilles 20 min dans le lait de coco
            """)
        #expect(recipe.title == nil)
        #expect(recipe.steps == ["Faire revenir l'oignon", "Ajouter les épices", "Cuire les lentilles 20 min dans le lait de coco"])
    }

    @Test("Quantité seule avant le nom, ligne d'ingrédient coupée")
    func quantityBeforeName() {
        let recipe = RecipeParser.parse(lines: ["Ingrédients", "250 g", "Farine", "1 pincée de", "sel", "½ citron"])
        #expect(recipe.ingredients == ["250 g Farine", "1 pincée de sel", "½ citron"])
    }

    @Test("Les ustensiles ne sont pas des ingrédients")
    func ignoredSection() {
        let recipe = RecipeParser.parse("""
            Ingrédients
            2 œufs
            Ustensiles
            Un fouet
            Préparation
            Battre les œufs en omelette dans un grand bol.
            """)
        #expect(recipe.ingredients == ["2 œufs"])
        #expect(recipe.steps == ["Battre les œufs en omelette dans un grand bol."])
    }

    @Test("Couverts : « pour 4 personnes », « 4 couverts »")
    func servings() {
        #expect(RecipeParser.parse("Pour 4 personnes\nIngrédients\n2 œufs").servings == 4)
        #expect(RecipeParser.parse("Ingrédients\n3 couverts\n2 œufs").servings == 3)
        #expect(RecipeParser.parse("Ingrédients pour 8 personnes\n2 œufs").servings == 8)
    }

    @Test("Plusieurs photos : pages mises bout à bout")
    func severalPages() {
        let page1 = ["Clafoutis", "Ingrédients", "500 g de cerises", "3 œufs"]
        let page2 = ["Préparation", "1. Beurrer un moule et y répartir les cerises.", "2. Battre les œufs avec le sucre, verser."]
        let recipe = RecipeParser.parse(lines: page1 + page2)
        #expect(recipe.ingredients == ["500 g de cerises", "3 œufs"])
        #expect(recipe.steps.count == 2)
    }

    @Test("Un texte sans recette ne donne rien")
    func empty() {
        #expect(RecipeParser.parse("").isEmpty)
        #expect(RecipeParser.parse("   \n  ").title == nil)
    }
}
