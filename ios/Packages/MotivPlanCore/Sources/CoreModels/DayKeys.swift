import Foundation
import TimelineEngine

/// Conversion entre `Date` et clés-jour `yyyy-MM-dd` (ADR-005). Le calendrier fixe le fuseau ;
/// le moteur et le stockage ne voient que des chaînes, comparables dans l'ordre lexicographique.
public enum DayKeys {
    public static func key(for date: Date, calendar: Calendar = .current) -> DayKey {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Minuit du jour, dans le fuseau du calendrier.
    public static func date(from key: DayKey, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public static func adding(_ days: Int, to key: DayKey, calendar: Calendar = .current) -> DayKey? {
        guard let start = date(from: key, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: start) else { return nil }
        return self.key(for: moved, calendar: calendar)
    }

    /// Lundi de la semaine qui contient `key`.
    public static func startOfWeek(containing key: DayKey, calendar: Calendar = .current) -> DayKey? {
        guard let interval = weekInterval(containing: key, calendar: calendar) else { return nil }
        return self.key(for: interval.start, calendar: calendar)
    }

    /// Dimanche de la semaine qui contient `key` : l'échéance « cette semaine ».
    public static func endOfWeek(containing key: DayKey, calendar: Calendar = .current) -> DayKey? {
        guard let interval = weekInterval(containing: key, calendar: calendar) else { return nil }
        return self.key(for: interval.end.addingTimeInterval(-1), calendar: calendar)
    }

    private static func weekInterval(containing key: DayKey, calendar: Calendar) -> DateInterval? {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        guard let day = date(from: key, calendar: mondayFirst) else { return nil }
        return mondayFirst.dateInterval(of: .weekOfYear, for: day)
    }
}
