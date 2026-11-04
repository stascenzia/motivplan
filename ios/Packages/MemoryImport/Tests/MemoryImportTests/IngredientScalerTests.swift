import Testing
@testable import MemoryImport

@Suite("Quantités selon les couverts")
struct IngredientScalerTests {
    @Test("Quantité en tête, entière, décimale ou fraction")
    func leading() {
        #expect(IngredientScaler.scale("200 g de riz", from: 4, to: 6) == "300 g de riz")
        #expect(IngredientScaler.scale("1 oignon", from: 2, to: 4) == "2 oignon")
        #expect(IngredientScaler.scale("1,5 l de bouillon", from: 4, to: 2) == "¾ l de bouillon")
        #expect(IngredientScaler.scale("½ citron", from: 2, to: 6) == "1 ½ citron")
        #expect(IngredientScaler.scale("1/2 botte de persil", from: 1, to: 3) == "1 ½ botte de persil")
        #expect(IngredientScaler.scale("3 œufs", from: 4, to: 3) == "2 ¼ œufs")
    }

    @Test("Quantité entre parenthèses (colonnes de Picnic)")
    func parenthesized() {
        #expect(IngredientScaler.scale("Lentilles corail (200 g)", from: 2, to: 3) == "Lentilles corail (300 g)")
    }

    @Test("Sans nombre, ou mêmes couverts : ligne inchangée")
    func unchanged() {
        #expect(IngredientScaler.scale("Sel et poivre", from: 4, to: 2) == "Sel et poivre")
        #expect(IngredientScaler.scale("une pincée de sel", from: 4, to: 8) == "une pincée de sel")
        #expect(IngredientScaler.scale("200 g de riz", from: 4, to: 4) == "200 g de riz")
        #expect(IngredientScaler.scale("200 g de riz", from: 0, to: 4) == "200 g de riz")
    }

    @Test("Arrondis de cuisine")
    func rounding() {
        #expect(IngredientScaler.format(12.4) == "12")
        #expect(IngredientScaler.format(2) == "2")
        #expect(IngredientScaler.format(0.5) == "½")
        #expect(IngredientScaler.format(1.33) == "1,3")
        #expect(IngredientScaler.format(1.98) == "2")
    }
}
