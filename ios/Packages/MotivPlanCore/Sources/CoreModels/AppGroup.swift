import Foundation

/// Identifiants partagés entre l'app et le widget (ADR-002).
public enum AppGroup {
    public static let identifier = "group.fr.ascenzia.motivplan"
    public static let urlScheme = "motivplan"
    public static let captureURL = URL(string: "motivplan://capture")!
    public static let captureWidgetKind = "CaptureWidget"

    /// Faux quand l'app a été signée sans le droit d'App Group (installation SideStore ou AltStore).
    public static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    public static var defaults: UserDefaults {
        (isAvailable ? UserDefaults(suiteName: identifier) : nil) ?? .standard
    }
}
