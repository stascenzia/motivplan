import Foundation

/// Identifiants partagés entre l'app et le widget (ADR-002).
public enum AppGroup {
    public static let identifier = "group.fr.ascenzia.motivplan"
    public static let urlScheme = "motivplan"
    public static let captureURL = URL(string: "motivplan://capture")!

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
