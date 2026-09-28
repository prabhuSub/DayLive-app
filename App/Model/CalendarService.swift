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

    /// Today's events for the Live Activity (declined invites left out).
    func events(on day: Date) -> [Block] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return events(from: start, to: end)
    }

    /// Events from every calendar on the phone in a date range (Calendar tab).
    func events(from start: Date, to end: Date, includeDeclined: Bool = false) -> [Block] {
        guard hasAccess, end > start else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.availability != .free }
            .compactMap { event -> Block? in
                let declined = event.attendees?.first(where: { $0.isCurrentUser })?.participantStatus == .declined
                if declined && !includeDeclined { return nil }
                return Block(
                    // Recurring events share an identifier, so the start time keeps ids unique per occurrence.
                    id: "cal-\(event.calendarItemIdentifier)-\(Int(event.startDate.timeIntervalSince1970))",
                    title: event.title ?? "Event",
                    start: event.startDate,
                    end: event.endDate,
                    source: .calendar,
                    calendarName: event.calendar?.title,
                    declined: declined
                )
            }
    }
}
