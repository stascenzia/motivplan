import Foundation

/// Recette lue dans une page web partagée (lien Safari, Picnic, site de recettes).
public struct WebRecipe: Sendable, Equatable {
    public var title: String?
    public var recipe: ParsedRecipe?
    public var imageURL: URL?

    public init(title: String? = nil, recipe: ParsedRecipe? = nil, imageURL: URL? = nil) {
        self.title = title
        self.recipe = recipe
        self.imageURL = imageURL
    }
}

/// La plupart des sites de recettes décrivent la recette pour les moteurs de recherche
/// (balise `application/ld+json`, type schema.org `Recipe`) : ingrédients et étapes déjà séparés,
/// sans IA ni service payant (ADR-017). Sans cette description, seul le titre de la page reste.
public enum WebRecipeExtractor {
    public static func extract(html: String) -> WebRecipe {
        var result = WebRecipe(title: pageTitle(in: html))
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
                  let node = findRecipe(in: json) else { continue }
            let recipe = ParsedRecipe(
                title: (node["name"] as? String).map(decodeEntities),
                ingredients: strings(node["recipeIngredient"] ?? node["ingredients"]).map(decodeEntities),
                steps: instructions(node["recipeInstructions"]).map(decodeEntities),
                servings: servings(node["recipeYield"]),
                duration: (node["totalTime"] as? String).flatMap(isoDuration)
                    ?? (node["cookTime"] as? String).flatMap(isoDuration))
            result.recipe = recipe
            if let title = recipe.title { result.title = title }
            result.imageURL = imageURL(node["image"])
            break
        }
        return result
    }

    // MARK: Page

    static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = try! Regex(#"<script[^>]*application/ld\+json[^>]*>(.*?)</script>"#)
            .ignoresCase().dotMatchesNewlines()
        return html.matches(of: pattern).compactMap { $0.output[1].substring.map(String.init) }
    }

    static func pageTitle(in html: String) -> String? {
        let og = try! Regex(#"<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']"#).ignoresCase()
        let title = try! Regex(#"<title[^>]*>(.*?)</title>"#).ignoresCase().dotMatchesNewlines()
        let raw = html.firstMatch(of: og)?.output[1].substring ?? html.firstMatch(of: title)?.output[1].substring
        let cleaned = raw.map { decodeEntities(String($0)).trimmingCharacters(in: .whitespacesAndNewlines) }
        return cleaned?.isEmpty == false ? cleaned : nil
    }

    // MARK: schema.org

    /// Le nœud `Recipe`, seul, dans une liste ou dans un `@graph`.
    static func findRecipe(in json: Any) -> [String: Any]? {
        if let list = json as? [Any] {
            return list.lazy.compactMap(findRecipe).first
        }
        guard let node = json as? [String: Any] else { return nil }
        if isRecipe(node["@type"]) { return node }
        if let graph = node["@graph"] { return findRecipe(in: graph) }
        return nil
    }

    private static func isRecipe(_ type: Any?) -> Bool {
        if let type = type as? String { return type == "Recipe" }
        if let types = type as? [String] { return types.contains("Recipe") }
        return false
    }

    private static func strings(_ value: Any?) -> [String] {
        if let list = value as? [String] { return list.map(clean).filter { !$0.isEmpty } }
        if let text = value as? String { return text.components(separatedBy: .newlines).map(clean).filter { !$0.isEmpty } }
        return []
    }

    /// Texte, liste de textes, liste d'étapes `HowToStep`, ou sections `HowToSection`.
    static func instructions(_ value: Any?) -> [String] {
        if let text = value as? String {
            return RecipeParser.parse("Préparation\n" + stripTags(text)).steps
        }
        guard let list = value as? [Any] else {
            if let node = value as? [String: Any] { return instructions([node]) }
            return []
        }
        return list.flatMap { item -> [String] in
            if let text = item as? String { return [clean(stripTags(text))] }
            guard let node = item as? [String: Any] else { return [] }
            if let children = node["itemListElement"] { return instructions(children) }
            if let text = node["text"] as? String { return [clean(stripTags(text))] }
            if let name = node["name"] as? String { return [clean(name)] }
            return []
        }.filter { !$0.isEmpty }
    }

    /// « 4 », « 4 portions », `[4, "4 portions"]` → 4.
    private static func servings(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue > 0 ? number.intValue : nil }
        if let list = value as? [Any] { return list.lazy.compactMap(servings).first }
        guard let text = value as? String else { return nil }
        return Int(text.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber })
    }

    private static func imageURL(_ value: Any?) -> URL? {
        if let text = value as? String { return URL(string: text) }
        if let list = value as? [Any] { return list.lazy.compactMap(imageURL).first }
        if let node = value as? [String: Any] { return (node["url"] as? String).flatMap(URL.init(string:)) }
        return nil
    }

    /// « PT1H15M » → « 1 h 15 min », « PT30M » → « 30 min ».
    static func isoDuration(_ text: String) -> String? {
        let pattern = try! Regex(#"^P(?:\d+D)?T?(?:(\d+)H)?(?:(\d+)M)?"#)
        guard let match = text.firstMatch(of: pattern) else { return nil }
        let hours = match.output[1].substring.flatMap { Int($0) } ?? 0
        let minutes = match.output[2].substring.flatMap { Int($0) } ?? 0
        switch (hours, minutes) {
        case (0, 0): return nil
        case (0, _): return "\(minutes) min"
        case (_, 0): return "\(hours) h"
        default: return "\(hours) h \(minutes) min"
        }
    }

    // MARK: Texte

    private static func clean(_ text: String) -> String {
        decodeEntities(text).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func stripTags(_ text: String) -> String {
        let tags = try! Regex(#"<br\s*/?>|</p>|</li>"#).ignoresCase()
        let other = try! Regex(#"<[^>]+>"#)
        return text.replacing(tags, with: "\n").replacing(other, with: "")
    }

    private static let entities: [String: String] = [
        "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&rsquo;": "’", "&lt;": "<", "&gt;": ">",
        "&nbsp;": " ", "&eacute;": "é", "&egrave;": "è", "&ecirc;": "ê", "&agrave;": "à", "&acirc;": "â",
        "&ccedil;": "ç", "&ocirc;": "ô", "&icirc;": "î", "&ugrave;": "ù", "&ucirc;": "û", "&oelig;": "œ",
        "&deg;": "°",
    ]

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, value) in entities { result = result.replacingOccurrences(of: entity, with: value) }
        let numeric = try! Regex(#"&#(x?)([0-9a-fA-F]+);"#)
        return result.replacing(numeric) { match in
            let hex = match.output[1].substring == "x"
            let digits = String(match.output[2].substring ?? "")
            guard let code = UInt32(digits, radix: hex ? 16 : 10), let scalar = Unicode.Scalar(code) else { return "" }
            return String(Character(scalar))
        }
    }
}
