import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

/// Vue Jour (maquette « Planning — vue Jour ») : date en grand, bandeau des 7 jours, frise,
/// tiroir replié au-dessus de la barre d'onglets.
struct DayScreen: View {
    /// Partagé avec le calendrier, qui ouvre un jour en le touchant.
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
                    WeekStrip(day: $day, today: today)
                    DayTimeline(day: day, isToday: day == today, drawerDetent: $detent) { selected = $0 }
                        .id("\(day)-\(settingsVersion)")
                }
                // Journée atténuée derrière le tiroir ouvert.
                .opacity(detent == .peek ? 1 : 0.5)

                DrawerOverlay(detent: $detent) {
                    DrawerPeek(day: day, today: today)
                } content: {
                    DrawerContent(day: day, onSelect: { selected = $0 }, onClose: { detent = .peek })
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .hidesTabBar(detent != .peek)
            .navigationDestination(item: $selected) { task in
                TaskDetailView(task: task)
                    .hidesTabBar()
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
        let date = DayKeys.date(from: day) ?? .now
        return ScreenHeader(title: date.formatted(.dateTime.day().month(.wide)),
                            overline: date.formatted(.dateTime.weekday(.wide)).capitalized) {
            HStack(spacing: 8) {
                if day != today {
                    Button("Aujourd'hui") { withAnimation { day = today } }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
                RoundIconButton(label: "Réglages", systemImage: "gearshape") { showSettings = true }
            }
        }
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
        .accessibilityAction(named: "Jour suivant") { shift(1) }
        .accessibilityAction(named: "Jour précédent") { shift(-1) }
    }

    private func shift(_ days: Int) {
        guard let next = DayKeys.adding(days, to: day) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { day = next }
    }
}

/// Bandeau des 7 jours de la semaine affichée : lettre, numéro, petite barre de charge.
/// Balayer le bandeau change de semaine.
private struct WeekStrip: View {
    @Binding var day: DayKey
    let today: DayKey

    @Query(filter: #Predicate<TaskItem> { $0.deletedAt == nil && $0.scheduledDate != nil })
    private var scheduled: [TaskItem]

    var body: some View {
        let start = DayKeys.startOfWeek(containing: day) ?? day
        let days = (0..<7).compactMap { DayKeys.adding($0, to: start) }
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { key in
                pill(key, load: scheduled.filter { $0.scheduledDate == key && $0.isOnDay }.count)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let weeks = value.translation.width < -40 ? 1 : value.translation.width > 40 ? -1 : 0
                    guard weeks != 0, let next = DayKeys.adding(7 * weeks, to: day) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) { day = next }
                }
        )
    }

    private func pill(_ key: DayKey, load: Int) -> some View {
        let date = DayKeys.date(from: key) ?? .now
        let selected = key == day
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { day = key }
        } label: {
            VStack(spacing: 3) {
                Text(date.formatted(.dateTime.weekday(.narrow)).uppercased())
                    .font(.manrope(11, .semibold, relativeTo: .caption2))
                    .opacity(0.75)
                Text(date.formatted(.dateTime.day()))
                    .font(.manrope(17, .extrabold, relativeTo: .body).monospacedDigit())
                Capsule()
                    .fill(selected ? Palette.onAccent : Palette.ring)
                    .frame(width: CGFloat(min(load, 5) * 4), height: 3)
                    .frame(height: 3)
            }
            .foregroundStyle(selected ? Palette.onAccent : key == today ? Palette.accentSoft : Palette.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(selected ? Palette.accent : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide))
                            + (load > 0 ? ", \(load) tâche\(load > 1 ? "s" : "")" : ""))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
