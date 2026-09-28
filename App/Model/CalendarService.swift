import EventKit
import Foundation

/// Reads today's events from every calendar on the phone (Tesla, Google, iCloud…).
final class CalendarService {
    static let shared = CalendarService()

    let store = EKEventStore()

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var needsPrompt: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func events(on day: Date) -> [Block] {
        guard hasAccess else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.availability != .free }
            .map { event in
                Block(
                    // Recurring events share an identifier, so the start time keeps ids unique per occurrence.
                    id: "cal-\(event.calendarItemIdentifier)-\(Int(event.startDate.timeIntervalSince1970))",
                    title: event.title ?? "Event",
                    start: event.startDate,
                    end: event.endDate,
                    source: .calendar
                )
            }
    }
}
