import Foundation
import EventKit
import Combine

@MainActor
final class AICalendarAgent: ObservableObject {
    
    enum Constants {
        static let spamMarker = "[MARKED_AS_SPAM]"
        static let backupIdentifierSeparator = "_"
    }
    
    @Published var events: [AICalendarSystemEvent] = []
    @Published var isLoading = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let calendarEventStore = EKEventStore()
    private var subscriptionCancellables = Set<AnyCancellable>()
    private let safelistedCalendarService = SafelistCalendarService()
    
    init() {
        checkCurrentAuthorizationStatus()
        setupSafelistEventObserver()
    }
    
    func requestCalendarAccess() async {
        let accessType = EKEntityType.event
        let isAccessGranted: Bool
        
        do {
            if #available(iOS 17.0, *) {
                isAccessGranted = try await calendarEventStore.requestFullAccessToEvents()
            } else {
                isAccessGranted = try await calendarEventStore.requestAccess(to: accessType)
            }
            
            await handleAccessRequestResult(granted: isAccessGranted)
        } catch {
            await handleAccessRequestError(error)
        }
    }
    
    func loadEvents(from startDate: Date? = nil, to endDate: Date? = nil) async {
        guard canAccessCalendar else {
            return await requestCalendarAccess()
        }
        
        isLoading = true
        errorMessage = nil
        
        let start = startDate ?? Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let end = endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = calendarEventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents = calendarEventStore.events(matching: predicate)
        
        let whitelistedIdentifiers = safelistedCalendarService.getSafelisteedEventIdentifiers()
        
        let systemEvents = ekEvents.map {
            let compositeId = "\($0.eventIdentifier ?? "")_\($0.startDate.timeIntervalSince1970)"
            let isSafelisted = whitelistedIdentifiers.contains(compositeId)
            return AICalendarSystemEvent(from: $0, isWhitelisted: isSafelisted)
        }.sorted(by: { $0.startDate > $1.startDate })
        
        events = systemEvents
        isLoading = false
        updateEventsSafelistStatus()
    }
    
    func deleteEvent(_ event: AICalendarSystemEvent) async -> AICalendarEventDeletionResult {
        guard canAccessCalendar else { return .failed(.noPermission) }
        
        guard let ekEvent = calendarEventStore.event(withIdentifier: event.eventIdentifier) else {
            return .failed(.eventNotFound)
        }
        
        guard ekEvent.isDeletable() else {
            return .failed(.cannotDelete(reason: ekEvent.deletionRestrictionReason()))
        }
        
        do {
            try calendarEventStore.remove(ekEvent, span: .thisEvent)
            events.removeAll { $0.id == event.id }
            return .success
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            return .failed(.systemError(error))
        }
    }
    
    func deleteEvents(_ eventsToDelete: [AICalendarSystemEvent]) async -> AICalendarDeletionResult {
        var deletedCount = 0
        var failedEvents: [(AICalendarSystemEvent, AICalendarDeletionError)] = []
        
        for event in eventsToDelete {
            let result = await deleteEvent(event)
            if case let .failed(error) = result {
                failedEvents.append((event, error))
            } else {
                deletedCount += 1
            }
        }
        
        return AICalendarDeletionResult(
            deletedCount: deletedCount,
            totalCount: eventsToDelete.count,
            failedEvents: failedEvents
        )
    }
    
    func markAsSpam(_ event: AICalendarSystemEvent) async -> Bool {
        guard canAccessCalendar, let ekEvent = calendarEventStore.event(withIdentifier: event.eventIdentifier) else {
            return false
        }
        
        do {
            ekEvent.notes = (ekEvent.notes ?? "") + "\n\(Constants.spamMarker)"
            try calendarEventStore.save(ekEvent, span: .thisEvent)
            
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index].isMarkedAsSpam = true
            }
            return true
        } catch {
            errorMessage = "Failed to mark event as spam: \(error.localizedDescription)"
            return false
        }
    }
    
    func addToWhiteList(_ event: AICalendarSystemEvent) {
        safelistedCalendarService.addToSafeliste(event)
        updateEventsSafelistStatus()
    }
    
    func removeFromWhiteList(_ event: AICalendarSystemEvent) {
        safelistedCalendarService.removeFromSafeliste(event)
        updateEventsSafelistStatus()
    }
    
    func getEventsStatistics() -> EventsAICalendarStatistics {
        let spamCount = events.filter { $0.isMarkedAsSpam }.count
        let whitelistedCount = events.filter { $0.isWhiteListed }.count
        
        return EventsAICalendarStatistics(
            total: events.count,
            spam: spamCount,
            whitelisted: whitelistedCount,
            regular: events.count - spamCount - whitelistedCount
        )
    }
    
    // Переименованные приватные функции и переменная
    private var canAccessCalendar: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    private func checkCurrentAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if canAccessCalendar {
            Task { await loadEvents() }
        }
    }
    
    private func setupSafelistEventObserver() {
        safelistedCalendarService.$safelistedEvents
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateEventsSafelistStatus()
                }
            }
            .store(in: &subscriptionCancellables)
    }
    
    private func updateEventsSafelistStatus() {
        let safelistedIdentifiers = safelistedCalendarService.getSafelisteedEventIdentifiers()
        
        for index in events.indices {
            let compositeIdentifier = events[index].eventIdentifier
            let isSafelisted = safelistedIdentifiers.contains(compositeIdentifier)
            
            guard events[index].isWhiteListed != isSafelisted else { continue }
            
            events[index].isWhiteListed = isSafelisted
            
            if isSafelisted {
                events[index].isMarkedAsSpam = false
            }
        }
    }
    
    private func handleAccessRequestResult(granted: Bool) async {
        if #available(iOS 17.0, *) {
            authorizationStatus = granted ? .fullAccess : .denied
            if granted {
                await loadEvents()
            }
        }
    }
    
    private func handleAccessRequestError(_ error: Error) async {
        errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
        authorizationStatus = .denied
    }
}
