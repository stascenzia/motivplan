import CoreModels
import SwiftUI
import WidgetKit

// ADR-004 : les widgets de capture ne font qu'ouvrir l'app sur le champ de capture. Aucun
// Button(intent:). Deux chemins (ADR-016) : une tâche vers la boîte, une envie vers la Mémoire.

struct CaptureEntry: TimelineEntry {
    let date: Date
}

struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry {
        CaptureEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) {
        completion(CaptureEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        completion(Timeline(entries: [CaptureEntry(date: .now)], policy: .never))
    }
}

/// Zone d'un widget de capture : grande icône et libellé.
private struct CaptureZone: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Capturer", systemImage: "plus.circle")
        case .accessoryCircular:
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        case .systemMedium:
            // Deux zones : chacune ouvre sa capture.
            HStack(spacing: 0) {
                Link(destination: AppGroup.captureURL) {
                    CaptureZone(title: "Tâche", systemImage: "plus.circle.fill", tint: .teal)
                }
                Divider()
                Link(destination: AppGroup.memoryCaptureURL) {
                    CaptureZone(title: "Mémoire", systemImage: "sparkles", tint: .purple)
                }
            }
        default:
            CaptureZone(title: "Capturer", systemImage: "plus.circle.fill", tint: .teal)
        }
    }
}

struct MemoryCaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Garder en mémoire", systemImage: "sparkles")
        case .accessoryCircular:
            Image(systemName: "sparkles")
                .font(.title2.weight(.semibold))
        default:
            CaptureZone(title: "Mémoire", systemImage: "sparkles", tint: .purple)
        }
    }
}

struct CaptureWidget: Widget {
    let kind = AppGroup.captureWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { _ in
            CaptureWidgetView()
                .widgetURL(AppGroup.captureURL)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Capturer")
        .description("Ouvre MotivPlan sur la capture. En moyen : une tâche ou une envie pour la Mémoire.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline])
    }
}

struct MemoryCaptureWidget: Widget {
    let kind = AppGroup.memoryCaptureWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaptureProvider()) { _ in
            MemoryCaptureWidgetView()
                .widgetURL(AppGroup.memoryCaptureURL)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Garder en mémoire")
        .description("Ouvre MotivPlan pour noter un film, une recette ou une envie.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

@main
struct MotivPlanWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaptureWidget()
        MemoryCaptureWidget()
        TodayWidget()
        WeekWidget()
    }
}
