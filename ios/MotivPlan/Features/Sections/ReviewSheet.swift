import CoreModels
import SwiftUI

/// Avis rapide en terminant un élément de mémoire (ADR-014). Tout est facultatif. Un voyage ou
/// une recette accepte des photos (ADR-016), gardées sur l'iPhone.
struct ReviewSheet: View {
    let task: TaskItem
    var takesPhotos = false
    let onSave: (Review?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var review: Review?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        HStack(spacing: 10) {
                            ForEach(Review.allCases, id: \.self) { choice in
                                Button {
                                    review = review == choice ? nil : choice
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: choice.symbol).font(.title2)
                                        Text(choice.label).font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(review == choice ? Color.accentColor.opacity(0.18) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(review == choice ? .isSelected : [])
                            }
                        }
                    } header: {
                        Text(task.title)
                    }
                    Section("Un mot ?") {
                        TextField("Ce que tu en as pensé", text: $note, axis: .vertical)
                            .lineLimit(2...6)
                    }
                    if takesPhotos {
                        Section("Photos") {
                            PhotoStrip(taskId: task.id)
                        }
                    }
                }
                .formRow()
            }
            .themedForm()
            .navigationTitle("C'est fait")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Garder") {
                        onSave(review, note)
                        dismiss()
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: review)
        }
        .presentationDetents(takesPhotos ? [.large] : [.medium])
        .onAppear {
            review = task.review
            note = task.reviewNote ?? ""
        }
    }
}
