import MemoryImport
import PhotosUI
import SwiftUI
import Vision

/// Lecture du texte d'une image sur l'iPhone (Vision), sans réseau ni coût (ADR-017).
nonisolated enum TextRecognition {
    /// Lignes de haut en bas ; sur une même ligne, de gauche à droite (colonnes nom et quantité de Picnic).
    static func lines(in imageData: Data) async throws -> [String] {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr-FR", "en-US"]
            request.usesLanguageCorrection = true
            // L'orientation de la photo est lue dans ses métadonnées.
            try VNImageRequestHandler(data: imageData).perform([request])
            let observations = (request.results ?? []).compactMap { observation -> (CGRect, String)? in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                return (observation.boundingBox, text)
            }
            return ordered(observations)
        }.value
    }

    /// Vision place l'origine en bas à gauche : tri par hauteur, puis regroupement en lignes.
    private static func ordered(_ boxes: [(CGRect, String)]) -> [String] {
        var rows: [[(CGRect, String)]] = []
        for box in boxes.sorted(by: { $0.0.midY > $1.0.midY }) {
            if let last = rows.last?.first, abs(last.0.midY - box.0.midY) < max(last.0.height, box.0.height) * 0.5 {
                rows[rows.count - 1].append(box)
            } else {
                rows.append([box])
            }
        }
        return rows.flatMap { row in row.sorted { $0.0.minX < $1.0.minX }.map(\.1) }
    }
}

/// Import d'une recette dans sa fiche : une ou plusieurs photos (les pages d'une recette, des captures
/// de Picnic), ou un texte collé. Le découpage est toujours relu avant d'être enregistré.
struct RecipeImportCard: View {
    let apply: (ParsedRecipe) -> Void

    @State private var picked: [PhotosPickerItem] = []
    @State private var reading = false
    @State private var request: RecipeImportRequest?
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Importer une recette")
            Text("Depuis des photos ou des captures (plusieurs pages possibles), ou un texte collé. Tu relis avant d'enregistrer.")
                .font(.meta)
                .foregroundStyle(Palette.textTertiary)
            HStack(spacing: 8) {
                PhotosPicker(selection: $picked, maxSelectionCount: 10, selectionBehavior: .ordered, matching: .images) {
                    Label("Photos", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PillButtonStyle())
                .disabled(reading)
                .accessibilityIdentifier("recipe-import-photos")
                Button("Coller un texte", systemImage: "doc.on.clipboard") {
                    request = RecipeImportRequest(recipe: nil)
                }
                .buttonStyle(PillButtonStyle())
                .disabled(reading)
                .accessibilityIdentifier("recipe-import-text")
            }
            if reading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Lecture des photos…").font(.meta).foregroundStyle(Palette.textSecondary)
                }
            }
            if let message {
                Text(message).font(.meta).foregroundStyle(Color.gentleWarning)
            }
        }
        .card()
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            read(items)
        }
        .sheet(item: $request) { request in
            RecipeImportSheet(initial: request.recipe, apply: apply)
        }
    }

    /// Les pages sont lues dans l'ordre choisi, puis découpées ensemble.
    private func read(_ items: [PhotosPickerItem]) {
        reading = true
        message = nil
        Task {
            var lines: [String] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                lines += (try? await TextRecognition.lines(in: data)) ?? []
            }
            picked = []
            reading = false
            let recipe = RecipeParser.parse(lines: lines)
            if lines.isEmpty {
                message = "Aucun texte lisible sur ces photos."
            } else {
                request = RecipeImportRequest(recipe: recipe)
            }
        }
    }
}

struct RecipeImportRequest: Identifiable {
    let id = UUID()
    /// `nil` : commencer par coller le texte.
    let recipe: ParsedRecipe?
}

/// Texte à coller, puis relecture du découpage : titre, couverts, ingrédients et étapes, une ligne
/// par élément.
struct RecipeImportSheet: View {
    let initial: ParsedRecipe?
    let apply: (ParsedRecipe) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""
    @State private var parsed = false
    @State private var title = ""
    @State private var servings: Int?
    @State private var ingredients = ""
    @State private var steps = ""

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    if parsed {
                        reviewSections
                    } else {
                        Section {
                            TextField("Colle ici la recette : ingrédients et étapes", text: $pasted, axis: .vertical)
                                .lineLimit(8...30)
                                .accessibilityIdentifier("recipe-paste")
                        } footer: {
                            Text("Un texte long passe aussi : MotivPlan repère les ingrédients et les étapes.")
                        }
                    }
                }
                .formRow()
            }
            .themedForm()
            .navigationTitle(parsed ? "Relire la recette" : "Coller une recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if parsed {
                        Button("Utiliser", action: use)
                            .accessibilityIdentifier("recipe-use")
                    } else {
                        Button("Découper") { load(RecipeParser.parse(pasted)) }
                            .disabled(pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("recipe-split")
                    }
                }
            }
            .onAppear {
                if let initial { load(initial) }
            }
        }
    }

    @ViewBuilder
    private var reviewSections: some View {
        Section("Titre") {
            TextField("Titre de la recette", text: $title)
        }
        Section("Couverts") {
            Stepper(value: Binding(get: { servings ?? 0 }, set: { servings = $0 > 0 ? $0 : nil }), in: 0...24) {
                Text(servings.map { "Pour \($0)" } ?? "Non précisé")
            }
        }
        Section {
            TextField("Un ingrédient par ligne", text: $ingredients, axis: .vertical)
                .lineLimit(3...30)
                .accessibilityIdentifier("recipe-review-ingredients")
        } header: {
            Text("Ingrédients")
        } footer: {
            Text(count(ingredients, "ingrédient"))
        }
        Section {
            TextField("Une étape par ligne", text: $steps, axis: .vertical)
                .lineLimit(3...40)
        } header: {
            Text("Étapes")
        } footer: {
            Text(count(steps, "étape"))
        }
    }

    private func count(_ text: String, _ word: String) -> String {
        let n = lines(text).count
        return n == 0 ? "Aucun \(word) reconnu : complète à la main si besoin." : "\(n) \(word)\(n > 1 ? "s" : "")"
    }

    private func lines(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func load(_ recipe: ParsedRecipe) {
        title = recipe.title ?? ""
        servings = recipe.servings
        ingredients = recipe.ingredients.joined(separator: "\n")
        steps = recipe.steps.joined(separator: "\n")
        parsed = true
    }

    private func use() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        apply(ParsedRecipe(title: trimmed.isEmpty ? nil : trimmed, ingredients: lines(ingredients),
                           steps: lines(steps), servings: servings))
        dismiss()
    }
}

/// Champs d'une recette importée (clés de `fieldsRaw`, ADR-016 et ADR-017).
enum RecipeFields {
    static let ingredients = "ingredients"
    static let steps = "steps"
    static let servings = "servings"
    static let source = "source"

    /// Champs à poser ; un champ vide laisse la valeur existante.
    static func values(of recipe: ParsedRecipe) -> [String: String] {
        var fields: [String: String] = [:]
        if !recipe.ingredients.isEmpty { fields[ingredients] = recipe.ingredients.joined(separator: "\n") }
        if !recipe.steps.isEmpty { fields[steps] = recipe.steps.joined(separator: "\n") }
        if let count = recipe.servings { fields[servings] = String(count) }
        return fields
    }
}

/// Ingrédients recalculés pour un autre nombre de couverts. La recette enregistrée ne change pas.
struct ScaledIngredientsCard: View {
    let ingredients: [String]
    let servings: Int

    @State private var target: Int?

    var body: some View {
        let target = target ?? servings
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                CardTitle(text: "Pour combien ?")
                Spacer()
                StepButton(text: "−", label: "Un couvert de moins") { self.target = max(target - 1, 1) }
                    .disabled(target <= 1)
                Text("\(target) couvert\(target > 1 ? "s" : "")")
                    .font(.manrope(16, .extrabold, relativeTo: .headline).monospacedDigit())
                    .foregroundStyle(Palette.text)
                    .frame(minWidth: 96)
                StepButton(text: "+", label: "Un couvert de plus") { self.target = min(target + 1, 48) }
            }
            if target != servings {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { _, line in
                        Text("• " + IngredientScaler.scale(line, from: servings, to: target))
                            .font(.manrope(15, .medium, relativeTo: .body))
                            .foregroundStyle(Palette.text)
                    }
                }
                Text("Recette prévue pour \(servings). Quantités arrondies.")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .card()
    }
}
