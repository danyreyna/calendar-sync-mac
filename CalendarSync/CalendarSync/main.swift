#!/usr/bin/swift

// Usage: ./CalendarSync "source_account_name→source_calendar_name" "target_account_name→target_calendar_name" [--dry-run]

import EventKit
import Foundation

let syncedMarker = "[synced]"

let dateFormatter = ISO8601DateFormatter()

struct StandardErrorStream: TextOutputStream {
    func write(_ string: String) {
        fputs(string, stderr)
    }
}
var standardError = StandardErrorStream()

enum CalendarSyncError: Error {
    case invalidArguments
    case calendarNotFound
    case eventCreationFailed(Error)
    case eventDeletionFailed(Error)
}

func parseArguments(_ args: [String]) -> Result<
    (source: String, target: String, isDryRun: Bool),
    CalendarSyncError
> {
    // Remove the program name from arguments
    let args = Array(CommandLine.arguments.dropFirst())
    let isDryRun = args.contains("--dry-run")
    let regularArgs = args.filter { $0 != "--dry-run" }

    // Check if we have the required number of arguments
    guard regularArgs.count >= 2 else {
        return .failure(.invalidArguments)
    }

    return .success(
        (
            source: regularArgs[0],
            target: regularArgs[1],
            isDryRun: isDryRun
        )
    )
}

func getCalendar(named name: String, in store: EKEventStore) -> Result<
    EKCalendar,
    CalendarSyncError
> {
    let nameParts = name.split(separator: "→")
    guard nameParts.count == 2 else {
        return .failure(.calendarNotFound)
    }

    let accountName = String(nameParts[0])
    let calendarName = String(nameParts[1])

    return store.calendars(for: .event)
        .first { calendar in
            calendar.source.title == accountName
                && calendar.title == calendarName
        }
        .map(Result.success)
        ?? .failure(.calendarNotFound)
}

func getDateRange() -> (start: Date, end: Date) {
    let startOfDay = Calendar.current.startOfDay(for: Date())
    let thirtyDaysFromNow = Calendar.current.date(
        byAdding: .day, value: 30, to: startOfDay
    )!
    return (startOfDay, thirtyDaysFromNow)
}

func getEvents(
    from calendar: EKCalendar,
    in store: EKEventStore,
    dateRange: (start: Date, end: Date)
) -> [EKEvent] {
    let predicate = store.predicateForEvents(
        withStart: dateRange.start,
        end: dateRange.end,
        calendars: [calendar]
    )
    return store.events(matching: predicate)
}

func getEventKey(_ event: EKEvent) -> String {
    [
        event.title ?? "Untitled",
        event.startDate?.description ?? "No start date",
        event.endDate?.description ?? "No end date",
    ].joined(separator: "|")
}

func printEventDetails(prefix: String, event: EKEvent) {
    print(
        """
        -----[\(dateFormatter.string(from: Date()))] \(prefix)-----
        Title: \(event.title ?? "Untitled")
        Start: \(event.startDate?.description ?? "No start date")
        End: \(event.endDate?.description ?? "No end date")
        """
    )
}

func createEvent(
    from sourceEvent: EKEvent,
    in targetCalendar: EKCalendar,
    store: EKEventStore
) -> Result<EKEvent, CalendarSyncError> {
    let newEvent = EKEvent(eventStore: store)
    newEvent.calendar = targetCalendar
    newEvent.title = sourceEvent.title
    newEvent.startDate = sourceEvent.startDate
    newEvent.endDate = sourceEvent.endDate
    newEvent.notes = syncedMarker

    do {
        try store.save(newEvent, span: .thisEvent)
        return .success(newEvent)
    } catch {
        return .failure(.eventCreationFailed(error))
    }
}

func deleteEvent(
    _ event: EKEvent,
    from store: EKEventStore
) -> Result<Void, CalendarSyncError> {
    do {
        try store.remove(event, span: .thisEvent)
        return .success(())
    } catch {
        return .failure(.eventDeletionFailed(error))
    }
}

func syncCalendars(source: String, target: String, isDryRun: Bool) {
    let semaphore = DispatchSemaphore(value: 0)

    let eventStore = EKEventStore()

    eventStore.requestFullAccessToEvents { granted, _ in
        defer {
            semaphore.signal()
        }

        guard granted else {
            print(
                "[\(dateFormatter.string(from: Date()))] Access to calendar was denied.",
                to: &standardError
            )
            exit(1)
        }

        guard
            case .success(let sourceCalendar) = getCalendar(
                named: source,
                in: eventStore
            )
        else {
            print(
                "[\(dateFormatter.string(from: Date()))] Source calendar \"\(source)\" not found.",
                to: &standardError
            )
            exit(1)
        }
        guard
            case .success(let targetCalendar) = getCalendar(
                named: target,
                in: eventStore
            )
        else {
            print(
                "[\(dateFormatter.string(from: Date()))] Target calendar \"\(target)\" not found.",
                to: &standardError
            )
            exit(1)
        }

        let dateRange = getDateRange()
        let sourceEvents = getEvents(
            from: sourceCalendar,
            in: eventStore,
            dateRange: dateRange
        )
        let targetEvents = getEvents(
            from: targetCalendar,
            in: eventStore,
            dateRange: dateRange
        )

        let targetEventsKeys = targetEvents.map(getEventKey)
        let sourceEventsNotInTarget =
            sourceEvents
            .filter { !targetEventsKeys.contains(getEventKey($0)) }
        for eventToCreate in sourceEventsNotInTarget {
            if isDryRun {
                printEventDetails(
                    prefix: "Would create event",
                    event: eventToCreate
                )
            } else {
                switch createEvent(
                    from: eventToCreate,
                    in: targetCalendar,
                    store: eventStore
                ) {
                case .success(let createdEvent):
                    printEventDetails(
                        prefix: "Created event",
                        event: createdEvent
                    )
                case .failure(let error):
                    print(
                        "[\(dateFormatter.string(from: Date()))] Failed to create event: \(error)",
                        to: &standardError
                    )
                }
            }
        }

        let sourceEventsKeys = sourceEvents.map(getEventKey)
        let syncedEventsRemovedFromSource =
            targetEvents
            .filter { event in
                (event.notes?.contains(syncedMarker) == true)
                    && !sourceEventsKeys.contains(getEventKey(event))
            }
        for event in syncedEventsRemovedFromSource {
            if isDryRun {
                printEventDetails(
                    prefix: "Would delete event",
                    event: event
                )
            } else {
                switch deleteEvent(event, from: eventStore) {
                case .success:
                    printEventDetails(
                        prefix: "Deleted event",
                        event: event
                    )
                case .failure(let error):
                    print(
                        "[\(dateFormatter.string(from: Date()))] Failed to delete event: \(error)",
                        to: &standardError
                    )
                }
            }
        }
    }

    semaphore.wait()
}

guard case .success(let args) = parseArguments(CommandLine.arguments)
else {
    print(
        "[\(dateFormatter.string(from: Date()))] Usage: ./CalendarSync \"source_account_name→source_calendar_name\" \"target_account_name→target_calendar_name\" [--dry-run]",
        to: &standardError
    )
    exit(1)
}

syncCalendars(
    source: args.source,
    target: args.target,
    isDryRun: args.isDryRun
)
