import Foundation

/// Identifiants partagés entre l'app et le widget (ADR-002).
public enum AppGroup {
    public static let identifier = "group.fr.ascenzia.motivplan"
    public static let urlScheme = "motivplan"
    /// Capture d'une tâche, vers « À trier » de la boîte de réception.
    public static let captureURL = URL(string: "motivplan://capture")!
    /// Capture d'un élément de mémoire, vers « À trier » de la Mémoire (ADR-016).
    public static let memoryCaptureURL = URL(string: "motivplan://capture?space=memory")!
    /// Ouvre la journée d'aujourd'hui (widget de l'écran verrouillé).
    public static let todayURL = URL(string: "motivplan://today")!
    /// Ouvre le calendrier (grand widget).
    public static let calendarURL = URL(string: "motivplan://calendar")!
    public static let captureWidgetKind = "CaptureWidget"
    public static let memoryCaptureWidgetKind = "MemoryCaptureWidget"
    public static let todayWidgetKind = "TodayWidget"
    public static let weekWidgetKind = "WeekWidget"

    /// Faux quand l'app a été signée sans le droit d'App Group (installation SideStore ou AltStore).
    public static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    public static var defaults: UserDefaults {
        (isAvailable ? UserDefaults(suiteName: identifier) : nil) ?? .standard
    }
}
