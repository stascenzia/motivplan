import CoreModels
import SwiftUI
import TimelineEngine

/// Vue Jour : navigation jour par jour, frise, tiroir en bas.
struct DayScreen: View {
    /// Partagé avec la vue Semaine, qui ouvre un jour en le touchant.
    @Binding var day: DayKey
    @State private var detent: DrawerDetent = .peek
    @State private var selected: TaskItem?
    @State private var showSettings = false
    @State private var settingsVersion = 0
    @State private var knownToday = DayKeys.key(for: .now)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let today = DayKeys.key(for: .now)
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header(today: today)
                    DayTimeline(day: day, drawerDetent: $detent) { selected = $0 }
                        .id("\(day)-\(settingsVersion)")
                }
                DrawerOverlay(detent: $detent) {
                    DrawerContent(day: day) { selected = $0 }
                }
            }
            .navigationTitle(DayLabel.text(for: day, today: today))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if day != today {
                        Button("Aujourd'hui") { withAnimation { day = today } }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Réglages", systemImage: "gearshape") { showSettings = true }
                }
            }
            .navigationDestination(item: $selected) { task in
                TaskDetailView(task: task)
            }
            .sheet(isPresented: $showSettings, onDismiss: { settingsVersion += 1 }) {
                SettingsView()
            }
            // Après minuit, l'app rouverte affiche le nouveau jour si l'on regardait « aujourd'hui ».
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let now = DayKeys.key(for: .now)
                if now != knownToday {
                    if day == knownToday { day = now }
                    knownToday = now
                }
            }
        }
    }

    private func header(today: DayKey) -> some View {
        HStack {
            Button("Jour précédent", systemImage: "chevron.left") { shift(-1) }
                .labelStyle(.iconOnly)
            Spacer()
            if let date = DayKeys.date(from: day) {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(day == today ? Color.accentColor : .primary)
            }
            Spacer()
            Button("Jour suivant", systemImage: "chevron.right") { shift(1) }
                .labelStyle(.iconOnly)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        // Balayage horizontal sur l'en-tête : la frise garde ses gestes verticaux.
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -40 { shift(1) }
                    if value.translation.width > 40 { shift(-1) }
                }
        )
    }

    private func shift(_ days: Int) {
        guard let next = DayKeys.adding(days, to: day) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { day = next }
    }
}
