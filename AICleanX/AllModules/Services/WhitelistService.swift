import Foundation
import CoreData
import Combine

@MainActor
final class SafelistCalendarService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var safelistedEvents: [AICalendarSystemEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let safelistKey = " safelistedEvents"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadSafelisteedEvents()
    }
    
    // MARK: - Public Methods
    
    func addToSafeliste(_ event: AICalendarSystemEvent) {
        if isEventSafelisteed(event) {
            return
        }
        
        var eventToAdd = event
        eventToAdd.isWhiteListed = true
        safelistedEvents.append(eventToAdd)
        saveSafelisteedEvents()
    }
    
    func removeFromSafeliste(_ event: AICalendarSystemEvent) {
         safelistedEvents.removeAll { $0.eventIdentifier == event.eventIdentifier }
        saveSafelisteedEvents()
    }
    
    func isEventSafelisteed(_ event: AICalendarSystemEvent) -> Bool {
        return safelistedEvents.contains { $0.eventIdentifier == event.eventIdentifier }
    }
    
    func getSafelisteedEventIdentifiers() -> Set<String> {
        let identifiers = Set(safelistedEvents.map { $0.eventIdentifier })
        return identifiers
    }
    
    func clearSafeliste() {
        safelistedEvents = []
        saveSafelisteedEvents()
    }
    
    // MARK: - Private Methods
    
    private func saveSafelisteedEvents() {
        do {
            let encodedData = try JSONEncoder().encode(safelistedEvents)
            userDefaults.set(encodedData, forKey:  safelistKey)
        } catch {
            errorMessage = "Failed to save  safelist: \(error.localizedDescription)"
        }
    }
    
    private func loadSafelisteedEvents() {
        isLoading = true
        errorMessage = nil
        
        if let savedData = userDefaults.data(forKey:  safelistKey) {
            do {
                safelistedEvents = try JSONDecoder().decode([AICalendarSystemEvent].self, from: savedData)
            } catch {
                errorMessage = "Failed to load  safelist: \(error.localizedDescription)"
                safelistedEvents = []
            }
        } else {
            safelistedEvents = []
        }
        
        isLoading = false
    }
}
