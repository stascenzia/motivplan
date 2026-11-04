import Foundation

/// Quantités d'une recette ramenées à un autre nombre de couverts : « 200 g de riz » pour 4
/// devient « 300 g de riz » pour 6. Seule la première quantité de la ligne change ; une ligne sans
/// nombre (« Sel et poivre », « une pincée de sel ») reste telle quelle.
public enum IngredientScaler {
    private static let fractions: [Character: Double] = ["½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3]
    private static let quantity = #"(\d+/\d+|\d+(?:[.,]\d+)?(?:\s?[½¼¾⅓⅔])?|[½¼¾⅓⅔])"#

    public static func scale(_ line: String, from base: Int, to target: Int) -> String {
        guard base > 0, target > 0, base != target else { return line }
        let factor = Double(target) / Double(base)
        // En tête (« 200 g de riz ») ou entre parenthèses (« Lentilles corail (200 g) »).
        for pattern in [#"^\#(quantity)"#, #"\(\#(quantity)"#] {
            let regex = try! Regex(pattern)
            guard let match = line.firstMatch(of: regex), let range = match.output[1].range,
                  let value = value(of: String(line[range])) else { continue }
            var scaled = line
            scaled.replaceSubrange(range, with: format(value * factor))
            return scaled
        }
        return line
    }

    /// « 1,5 » → 1.5, « 1/2 » → 0.5, « 1 ½ » → 1.5, « ¾ » → 0.75.
    static func value(of text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if let last = trimmed.last, let fraction = fractions[last] {
            let whole = trimmed.dropLast().trimmingCharacters(in: .whitespaces)
            return (whole.isEmpty ? 0 : Double(whole) ?? 0) + fraction
        }
        if trimmed.contains("/") {
            let parts = trimmed.split(separator: "/").compactMap { Double($0) }
            guard parts.count == 2, parts[1] != 0 else { return nil }
            return parts[0] / parts[1]
        }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    /// Arrondi de cuisine : entier dès 10, sinon demi et quarts en fractions, ou une décimale.
    static func format(_ value: Double) -> String {
        if value >= 10 { return String(Int(value.rounded())) }
        let whole = Int(value)
        let rest = value - Double(whole)
        let symbols: [(Double, String)] = [(0, ""), (0.25, "¼"), (0.5, "½"), (0.75, "¾"), (1, "")]
        if let near = symbols.first(where: { abs($0.0 - rest) < 0.04 }) {
            let base = near.0 == 1 ? whole + 1 : whole
            if near.1.isEmpty { return String(base) }
            return base == 0 ? near.1 : "\(base) \(near.1)"
        }
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
    }
}
