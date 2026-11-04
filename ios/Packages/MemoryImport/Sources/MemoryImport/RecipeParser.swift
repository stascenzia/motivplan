import Foundation

/// Recette découpée depuis un texte : celui d'une photo lue sur l'iPhone, d'une capture d'écran
/// (Picnic, un site de recettes) ou d'un texte collé.
public struct ParsedRecipe: Sendable, Equatable {
    public var title: String?
    public var ingredients: [String]
    public var steps: [String]
    /// Nombre de couverts : « pour 4 personnes », « 4 couverts ».
    public var servings: Int?
    /// « 30 min ».
    public var duration: String?

    public init(title: String? = nil, ingredients: [String] = [], steps: [String] = [],
                servings: Int? = nil, duration: String? = nil) {
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.duration = duration
    }

    /// Rien de reconnu : ni ingrédient ni étape.
    public var isEmpty: Bool { ingredients.isEmpty && steps.isEmpty }
}

/// Découpage par règles, sans IA (ADR-017) : l'iPhone 14 n'a pas l'IA d'Apple, et l'import doit
/// rester gratuit. Les titres « Ingrédients » et « Préparation » délimitent les parties ; sans
/// titres, une ligne avec une quantité est un ingrédient et une phrase est une étape.
/// Le résultat est toujours relu par l'utilisateur avant d'être enregistré.
public enum RecipeParser {
    public static func parse(_ text: String) -> ParsedRecipe {
        parse(lines: text.components(separatedBy: .newlines))
    }

    public static func parse(lines rawLines: [String]) -> ParsedRecipe {
        var recipe = ParsedRecipe()
        var lines: [Line] = []
        for raw in rawLines {
            let text = clean(raw)
            guard !text.isEmpty else { continue }
            let line = Line(text: text)
            if Rules.isNoise(line) { continue }
            if let servings = Rules.servingsLine(line) {
                if recipe.servings == nil { recipe.servings = servings }
                continue
            }
            if let duration = Rules.durationLine(line) {
                if recipe.duration == nil || line.folded.contains("total") { recipe.duration = duration }
                continue
            }
            lines.append(line)
        }

        let hasHeaders = lines.contains { Rules.header(of: $0) != nil }
        var ingredients = IngredientBuilder()
        var steps = StepBuilder()
        var part: Part = hasHeaders ? .preamble : .free
        var preamble: [Line] = []
        // Les étapes d'une partie sont-elles numérotées ? Décide du rattachement des lignes coupées.
        var numbered = false

        if !hasHeaders, let index = lines.firstIndex(where: Rules.isTitleCandidate) {
            recipe.title = lines[index].text
            lines.remove(at: index)
        }

        for (index, line) in lines.enumerated() {
            if let header = Rules.header(of: line) {
                if header == .ingredients, recipe.servings == nil { recipe.servings = Rules.servings(in: line) }
                part = header
                if header == .steps {
                    numbered = lines[(index + 1)...].prefix { Rules.header(of: $0) == nil }.contains { Rules.stepMarker(in: $0) != nil }
                    steps.startNew()
                }
                continue
            }
            switch part {
            case .preamble:
                preamble.append(line)
            case .ignored:
                continue
            case .ingredients:
                // Une phrase ou une étape numérotée sans titre « Préparation » : les étapes commencent.
                if !lines.contains(where: { Rules.header(of: $0) == .steps }), Rules.isSentence(line) {
                    part = .steps
                    numbered = Rules.stepMarker(in: line) != nil
                    steps.add(line, numbered: numbered)
                } else {
                    ingredients.add(line)
                }
            case .steps:
                steps.add(line, numbered: numbered)
            case .free:
                if Rules.stepMarker(in: line) != nil || Rules.isSentence(line) {
                    numbered = numbered || Rules.stepMarker(in: line) != nil
                    steps.add(line, numbered: numbered)
                } else if steps.isOpen, !Rules.hasQuantity(line.text), line.startsLowercase {
                    // Ligne coupée d'une étape.
                    steps.add(line, numbered: true)
                } else {
                    steps.close()
                    ingredients.add(line)
                }
            }
        }

        if hasHeaders {
            recipe.title = preamble.first(where: Rules.isTitleCandidate)?.text
        }
        recipe.ingredients = ingredients.result
        recipe.steps = steps.result
        return recipe
    }

    // MARK: Nettoyage

    private static let bullets: Set<Character> = ["•", "·", "-", "–", "—", "*", "▪", "◦", "✓", "✔", "☐", "□", "○", "●", "+", ">"]

    /// Espaces resserrés, puce de liste retirée.
    static func clean(_ raw: String) -> String {
        var text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while let first = text.first, bullets.contains(first) {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespaces)
        }
        return text
    }
}

// MARK: - Lignes

enum Part {
    case preamble, ingredients, steps, ignored, free
}

struct Line {
    let text: String
    /// Minuscules sans accents, ponctuation finale retirée : pour les comparaisons.
    let folded: String
    let wordCount: Int

    init(text: String) {
        self.text = text
        let lowered = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()
        folded = lowered.trimmingCharacters(in: CharacterSet(charactersIn: " :.-–—"))
        wordCount = text.split(separator: " ").count
    }

    var startsLowercase: Bool {
        text.first.map { $0.isLowercase } ?? false
    }

    var endsSentence: Bool {
        text.last.map { ".!?…".contains($0) } ?? false
    }
}

enum Rules {
    // MARK: Expressions

    private static let number = #"(?:\d+/\d+|\d+(?:[.,]\d+)?\s?[½¼¾⅓⅔]?|[½¼¾⅓⅔])"#
    private static let unit = #"(?:kg|mg|g|gr|grammes?|ml|cl|dl|l|litres?|c\.?\s?a\.?\s?s\.?|c\.?\s?a\.?\s?c\.?|cs|cc|cuill[a-z.]*|tasses?|pincees?|gousses?|bottes?|tranches?|boites?|sachets?|pots?|brins?|feuilles?|filets?|morceaux?|pieces?|pcs?|verres?|noix|zestes?|bouquets?|branches?|tiges?|poignees?|cubes?|briques?|paquets?|barquettes?|x)"#
    private static let wordNumber = #"(?:un|une|deux|trois|quatre|cinq|six|sept|huit|dix|douze|quelques|demi|1/2)"#

    // Les Regex ne sont pas Sendable, mais ces motifs ne changent jamais.
    nonisolated(unsafe) private static let quantityStart = regex(#"^(?:\#(number)(?=\s|$|[a-z])|\#(wordNumber)(?=\s|$))"#)
    nonisolated(unsafe) private static let quantityOnly = regex(#"^(?:x\s?)?\#(number)\s*(?:\#(unit))?\.?$|^\#(number)\s*x$"#)
    nonisolated(unsafe) private static let trailingQuantity = regex(#"\s\#(number)\s*(?:\#(unit))?$"#)
    nonisolated(unsafe) private static let duration = regex(#"^(?:(?:temps total|temps de [a-z]+|temps|preparation|cuisson|repos|total|duree)\s*:?\s*)?(?:\d+\s*(?:h|heures?|min|mn|minutes?)\s*\d*\s*)+$"#)
    nonisolated(unsafe) private static let durationValue = regex(#"\d+\s*(?:h|heures?|min|mn|minutes?)(?:\s*\d+)?"#)
    nonisolated(unsafe) private static let servingsFull = regex(#"^(?:pour\s*)?(\d+)\s*(?:personnes?|pers|portions?|parts?|couverts?)$"#)
    nonisolated(unsafe) private static let servingsAnywhere = regex(#"(\d+)\s*(?:personnes?|pers|portions?|parts?|couverts?)"#)
    nonisolated(unsafe) private static let etape = regex(#"^[EÉeé]tape\s*(\d+)\s*[:.\-–)]?\s*(.*)$"#, ignoreCase: true)
    nonisolated(unsafe) private static let loneNumber = regex(#"^(\d{1,2})\s*[.)]?$"#)
    nonisolated(unsafe) private static let numberedPunctuated = regex(#"^(\d{1,2})\s*[.)\-–]\s+(.+)$"#)
    nonisolated(unsafe) private static let numberedCapital = regex(#"^(\d{1,2})\s+(\p{Lu}.+)$"#)

    private static func regex(_ pattern: String, ignoreCase: Bool = false) -> Regex<AnyRegexOutput> {
        // Motifs fixes : une erreur est un bug du code, vue aux tests.
        let compiled = try! Regex(pattern)
        return ignoreCase ? compiled.ignoresCase() : compiled
    }

    // MARK: Titres de partie

    private static let ingredientHeaders = [
        "ingredient", "ce dont vous avez besoin", "ce qu'il vous faut", "ce qu il vous faut", "il vous faut",
        "liste des courses", "dans votre placard", "dans ton placard", "dans votre cuisine", "a avoir chez soi",
        "du placard", "vous aurez besoin",
    ]
    private static let stepHeaders = [
        "preparation", "etapes", "les etapes", "instructions", "directions", "method", "steps", "methode",
        "deroule", "realisation", "comment faire", "marche a suivre", "mode operatoire", "progression",
        "a vos fourneaux",
    ]
    private static let ignoredHeaders = [
        "ustensile", "materiel", "valeurs nutritionnelles", "nutrition", "astuce", "conseil", "le petit plus",
        "allergene", "notes",
    ]

    static func header(of line: Line) -> Part? {
        guard line.wordCount <= 7, !isDuration(line) else { return nil }
        if ingredientHeaders.contains(where: line.folded.hasPrefix) { return .ingredients }
        if line.wordCount <= 6, stepHeaders.contains(where: line.folded.hasPrefix) { return .steps }
        if line.wordCount <= 4, ignoredHeaders.contains(where: line.folded.hasPrefix) { return .ignored }
        return nil
    }

    // MARK: Métadonnées

    private static let noise: Set<String> = [
        "facile", "tres facile", "moyen", "moyenne", "difficile", "bon marche", "cout moyen", "assez cher",
        "economique", "ajouter au panier", "ajouter", "partager", "imprimer", "favoris", "voir plus",
        "voir la recette", "j'aime", "sponsorise", "publicite", "recette", "la recette", "commentaires",
        "enregistrer", "ajouter a ma liste", "ajouter a la liste de courses",
    ]

    static func isNoise(_ line: Line) -> Bool {
        if noise.contains(line.folded) { return true }
        if line.folded.contains("kcal") || line.folded.contains(" avis") { return true }
        // Note ou compteur : « 4,8 », « (230) ». Un nombre seul reste : quantité ou numéro d'étape.
        return line.folded.allSatisfy { $0.isNumber || ",.() ".contains($0) }
            && line.folded.contains { ",.()".contains($0) }
    }

    static func servingsLine(_ line: Line) -> Int? {
        guard line.wordCount <= 4, let match = line.folded.wholeMatch(of: servingsFull) else { return nil }
        return match.output[1].substring.flatMap { Int($0) }
    }

    static func servings(in line: Line) -> Int? {
        guard let match = line.folded.firstMatch(of: servingsAnywhere) else { return nil }
        return match.output[1].substring.flatMap { Int($0) }
    }

    static func isDuration(_ line: Line) -> Bool {
        line.folded.wholeMatch(of: duration) != nil
    }

    static func durationLine(_ line: Line) -> String? {
        guard isDuration(line), let value = line.folded.firstMatch(of: durationValue) else { return nil }
        return String(value.output[0].substring ?? "")
    }

    // MARK: Ingrédients et étapes

    static func isQuantityOnly(_ text: String) -> Bool {
        Line(text: text).folded.wholeMatch(of: quantityOnly) != nil
    }

    static func hasQuantity(_ text: String) -> Bool {
        let folded = Line(text: text).folded
        return folded.firstMatch(of: quantityStart) != nil || folded.firstMatch(of: trailingQuantity) != nil
    }

    /// Une phrase : une étape plutôt qu'un ingrédient.
    static func isSentence(_ line: Line) -> Bool {
        line.wordCount >= 8 || (line.wordCount >= 4 && line.endsSentence && !hasQuantity(line.text))
    }

    /// Début d'étape : « Étape 2 », « 2 », « 2. Ajouter… », « 2 Ajouter… ». `text` : la suite, peut-être vide.
    static func stepMarker(in line: Line) -> (number: Int, text: String)? {
        if let match = line.text.wholeMatch(of: etape) {
            return (Int(match.output[1].substring ?? "") ?? 0, String(match.output[2].substring ?? ""))
        }
        if let match = line.text.wholeMatch(of: loneNumber) {
            return (Int(match.output[1].substring ?? "") ?? 0, "")
        }
        // « 2 oignons », « 4 Pommes Golden » ne sont pas des étapes : il faut une phrase.
        for (pattern, minimumWords) in [(numberedPunctuated, 3), (numberedCapital, 5)] {
            if let match = line.text.wholeMatch(of: pattern) {
                let rest = String(match.output[2].substring ?? "")
                guard Line(text: rest).wordCount >= minimumWords, !isQuantityOnly(rest) else { continue }
                return (Int(match.output[1].substring ?? "") ?? 0, rest)
            }
        }
        return nil
    }

    /// Titre plausible : ni quantité, ni phrase, ni numéro.
    static func isTitleCandidate(_ line: Line) -> Bool {
        line.wordCount <= 14 && !line.endsSentence && !hasQuantity(line.text) && stepMarker(in: line) == nil
            && header(of: line) == nil && line.text.contains { $0.isLetter }
    }
}

// MARK: - Assemblage

struct IngredientBuilder {
    private(set) var result: [String] = []
    private var pendingQuantity: String?
    /// Le dernier ingrédient n'a qu'un nom : une quantité seule qui suit lui revient (colonnes de Picnic).
    private var lastIsBareName = false

    mutating func add(_ line: Line) {
        let text = line.text
        if Rules.isQuantityOnly(text) {
            if lastIsBareName, let last = result.popLast() {
                result.append("\(last) (\(text))")
                lastIsBareName = false
            } else {
                pendingQuantity = text
            }
            return
        }
        if let quantity = pendingQuantity {
            pendingQuantity = nil
            append("\(quantity) \(text)", bare: false)
            return
        }
        // Ligne coupée : « 200 g de » puis « farine ».
        if let last = result.last, last.hasSuffix(" de") || last.hasSuffix(" d'") || last.hasSuffix(",") {
            result[result.count - 1] = "\(last) \(text)"
            return
        }
        append(text, bare: !Rules.hasQuantity(text))
    }

    private mutating func append(_ text: String, bare: Bool) {
        lastIsBareName = bare
        guard !result.contains(text) else { return }
        result.append(text)
    }
}

struct StepBuilder {
    private var steps: [String] = []
    private var current = ""
    private var forceNew = false

    var isOpen: Bool { !current.isEmpty }

    var result: [String] {
        (steps + [current]).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// La prochaine ligne ouvre une étape.
    mutating func startNew() {
        close()
        forceNew = true
    }

    mutating func close() {
        if !current.isEmpty { steps.append(current) }
        current = ""
    }

    /// `numbered` : les étapes ont des numéros, une ligne sans numéro prolonge donc l'étape en cours.
    mutating func add(_ line: Line, numbered: Bool) {
        if let marker = Rules.stepMarker(in: line) {
            close()
            if marker.text.isEmpty {
                forceNew = true
            } else {
                current = marker.text
                forceNew = false
            }
            return
        }
        let text = line.text
        if forceNew || current.isEmpty {
            close()
            current = text
            forceNew = false
            return
        }
        // Sans numéros, une étape finit par un point, ou la suivante commence par une majuscule.
        let continues = numbered || (!Line(text: current).endsSentence && line.startsLowercase)
        if continues {
            if current.hasSuffix("-"), line.startsLowercase {
                current.removeLast()
                current += text
            } else {
                current += " " + text
            }
        } else {
            close()
            current = text
        }
    }
}
