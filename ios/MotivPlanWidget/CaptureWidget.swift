import CoreModels
import SwiftUI
import WidgetKit

// ADR-004 : le widget ne fait qu'ouvrir l'app sur le champ de capture. Aucun Button(intent:).

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

struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("Capturer", systemImage: "plus.circle")
        case .accessoryCircular:
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        default:
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.largeTitle)
                Text("Capturer")
                    .font(.headline)
            }
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
        .configurationDisplayName("Capturer une tâche")
        .description("Ouvre MotivPlan sur le champ de capture.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

@main
struct MotivPlanWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaptureWidget()
    }
}
