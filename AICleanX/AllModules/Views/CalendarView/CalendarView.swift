import SwiftUI
import EventKit

struct AICalendarView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiCalendarAgent = AICalendarAgent()

    @State private var currentFilterTab: CalendarOptimizationFilter = .aiScanEvents
    @State private var queryText: String = ""
    @State private var selectedEventIdentifiers = Set<String>()
    @State private var showingAIPermissionPrompt = false
    @State private var showingAIOptimizationConfirmation = false
    @State private var showingOptimizationFailedAlert = false
    @State private var optimizationFailureMessage = ""
    @State private var failedOptimizationEvents: [(AICalendarSystemEvent, AICalendarDeletionError)] = []
    @State private var showingAIGuide = false

    @State private var aiScanStartDate: Date = {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var aiScanEndDate = Date()

    @State private var showingAIScanStartDatePicker = false
    @State private var showingAIScanEndDatePicker = false

    var intelligentFilteredEvents: [CalendarEvent] {
        let aiCalendarEvents = aiCalendarAgent.events.map { CalendarEvent(from: $0) }
        
        let start = min(aiScanStartDate, aiScanEndDate)
        let end = max(aiScanStartDate, aiScanEndDate)
        
        let filteredByDate = aiCalendarEvents.filter { event in
            return event.date >= start && event.date <= end
        }
        
        let filteredBySearch = filteredByDate.filter { event in
            return queryText.isEmpty || event.title.localizedCaseInsensitiveContains(queryText) || event.source.localizedCaseInsensitiveContains(queryText)
        }
        
        switch currentFilterTab {
        case .aiScanEvents:
            let result = filteredBySearch.filter { !$0.isWhiteListed }
            return result
        case .aiSafeList:
            let result = filteredBySearch.filter { $0.isWhiteListed }
            return result
        }
    }

    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: aiScanStartDate)
    }

    var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: aiScanEndDate)
    }

    enum CalendarOptimizationFilter {
        case aiScanEvents
        case aiSafeList
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 24) {
                    aiHeaderView()
                    aiDateAndSearchStack()
                    aiFilterButtonsView()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 24)

                if aiCalendarAgent.authorizationStatus == .denied {
                    aiPermissionDeniedView()
                } else if aiCalendarAgent.authorizationStatus == .notDetermined {
                    aiRequestPermissionView()
                } else if aiCalendarAgent.isLoading {
                    aiLoadingView()
                } else if intelligentFilteredEvents.isEmpty && !queryText.isEmpty {
                    aiEmptyStateView()
                } else if intelligentFilteredEvents.isEmpty {
                    aiNoEventsView()
                } else {
                    aiEventsListView()
                }

                Spacer()
                
                if !selectedEventIdentifiers.isEmpty {
                    aiActionButtonsView()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(CMColor.background.ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingAIScanStartDatePicker) {
            SystemDatePickerView(selectedDate: $aiScanStartDate)
                .onDisappear {
                    Task {
                        await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate)
                    }
                }
        }
        .sheet(isPresented: $showingAIScanEndDatePicker) {
            SystemDatePickerView(selectedDate: $aiScanEndDate)
                .onDisappear {
                    Task {
                        await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate)
                    }
                }
        }
        .onAppear {
            if aiCalendarAgent.authorizationStatus == .notDetermined {
                Task {
                    await aiCalendarAgent.requestCalendarAccess()
                }
            } else {
                Task {
                    await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate)
                }
            }
        }
        .alert("AI Calendar Access Required", isPresented: $showingAIPermissionPrompt) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable calendar access in Settings to allow the AI to optimize your schedule.")
        }
        .alert("AI-Powered Cleanup", isPresented: $showingAIOptimizationConfirmation) {
            Button("Optimize", role: .destructive) {
                performAIOptimization()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The AI will permanently remove \(selectedEventIdentifiers.count) selected event(s) from your calendar. This action is irreversible.")
        }
        .overlay {
            if showingOptimizationFailedAlert {
                CannotDeleteEventView(
                    eventTitle: failedOptimizationEvents.first?.0.calendar ?? "Unknown Calendar",
                    message: optimizationFailureMessage,
                    onGuide: {
                        showingOptimizationFailedAlert = false
                        showingAIGuide = true
                    },
                    onCancel: {
                        showingOptimizationFailedAlert = false
                    }
                )
                .animation(.easeInOut(duration: 0.3), value: showingOptimizationFailedAlert)
            }
        }
        .sheet(isPresented: $showingAIGuide) {
            CalendarInstructionsView()
        }
    }
    
    // MARK: - Subviews
    
    private func aiHeaderView() -> some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
            }
            .frame(width: 44, height: 44)
            .background(CMColor.backgroundSecondary)
            .clipShape(Circle())
            
            Spacer()
            
            Text("AI Calendar Scan")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    if selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty {
                        selectedEventIdentifiers.removeAll()
                    } else {
                        selectedEventIdentifiers = Set(intelligentFilteredEvents.map { $0.eventIdentifier })
                    }
                }
            }) {
                Text(selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty ? "Deselect All" : "Select All")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(CMColor.primary)
            }
        }
    }
    
    private func aiDateAndSearchStack() -> some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { showingAIScanStartDatePicker = true }) {
                    Text(formattedStartDate)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(CMColor.backgroundSecondary)
                        .cornerRadius(12)
                        .foregroundColor(CMColor.primary)
                }
                .frame(maxWidth: .infinity)
                
                Image(systemName: "arrow.right")
                    .foregroundColor(CMColor.secondaryText)
                
                Button(action: { showingAIScanEndDatePicker = true }) {
                    Text(formattedEndDate)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(CMColor.backgroundSecondary)
                        .cornerRadius(12)
                        .foregroundColor(CMColor.primary)
                }
                .frame(maxWidth: .infinity)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CMColor.secondaryText)
                
                TextField("Search AI-Scanned Events", text: $queryText)
                    .foregroundColor(CMColor.primaryText)
                    .submitLabel(.search)
                
                if !queryText.isEmpty {
                    Button(action: { queryText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(CMColor.backgroundSecondary)
            .cornerRadius(12)
        }
    }
    
    private func aiFilterButtonsView() -> some View {
        HStack(spacing: 8) {
            ForEach([CalendarOptimizationFilter.aiScanEvents, .aiSafeList], id: \.self) { filter in
                Button(action: {
                    withAnimation {
                        currentFilterTab = filter
                        selectedEventIdentifiers.removeAll()
                    }
                }) {
                    Text(aiFilterName(for: filter))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(currentFilterTab == filter ? .white : CMColor.secondaryText)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(
                            currentFilterTab == filter ? CMColor.primary : .clear
                        )
                        .cornerRadius(16)
                }
            }
        }
        .padding(4)
        .background(CMColor.backgroundSecondary)
        .cornerRadius(20)
    }
    
    private func aiEventsListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(intelligentFilteredEvents) { event in
                    EventRowView(
                        event: event,
                        isSelected: selectedEventIdentifiers.contains(event.eventIdentifier),
                        onSelect: {
                            if selectedEventIdentifiers.contains(event.eventIdentifier) {
                                selectedEventIdentifiers.remove(event.eventIdentifier)
                            } else {
                                selectedEventIdentifiers.insert(event.eventIdentifier)
                            }
                        }
                    )
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    
                    Divider()
                        .background(CMColor.border)
                        .padding(.horizontal, 24)
                }
            }
        }
    }
    
    private func aiEmptyStateView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(CMColor.secondaryText)
            
            Text("No Matching Events Found")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Try adjusting your search query or the date range to find events for AI analysis.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func aiActionButtonsView() -> some View {
        HStack(spacing: 16) {
            if currentFilterTab == .aiSafeList {
                Button(action: { removeEventsFromAISafeList() }) {
                    Text("Remove from Safe list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.secondary)
                        .cornerRadius(16)
                }
            } else {
                Button(action: { addEventsToAISafeList() }) {
                    Text("Add to Safe list")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.secondary)
                        .cornerRadius(16)
                }
                
                Button(action: { showingAIOptimizationConfirmation = true }) {
                    Text("AI Optimize")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.error)
                        .cornerRadius(16)
                }
            }
        }
    }
    
    // MARK: - Permission Views
    
    private func aiRequestPermissionView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(CMColor.primary)
            
            Text("AI Requires Access")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Our AI needs access to your calendar events to intelligently identify and remove clutter. Your data is processed securely and locally.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await aiCalendarAgent.requestCalendarAccess()
                }
            }) {
                Text("Grant AI Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func aiPermissionDeniedView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(CMColor.error)
            
            Text("Access Denied")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Please enable calendar access in your iPhone Settings to allow the AI to optimize your schedule.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAIPermissionPrompt = true }) {
                Text("Open Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.primary)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func aiLoadingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(CMColor.primary)
            
            Text("AI is analyzing your calendar...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func aiNoEventsView() -> some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 80))
                .foregroundColor(CMColor.secondaryText)
            
            Text("No Events to Optimize")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Our AI has scanned the selected period and found no events that require cleanup.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Action Methods
    
    private func addEventsToAISafeList() {
        Task {
            let selectedEvents = getSelectedEvents()
            
            for event in selectedEvents {
                let matchingEvent = aiCalendarAgent.events.first(where: { systemEvent in
                    let idMatches = systemEvent.eventIdentifier == event.originalEventIdentifier
                    let dateMatches = Calendar.current.isDate(systemEvent.startDate, inSameDayAs: event.date)
                    return idMatches && dateMatches
                })
                
                if let systemEvent = matchingEvent {
                    aiCalendarAgent.addToWhiteList(systemEvent)
                }
            }
            
            await MainActor.run {
                selectedEventIdentifiers.removeAll()
            }
        }
    }
    
    private func removeEventsFromAISafeList() {
        Task {
            let selectedEvents = getSelectedEvents()
            for event in selectedEvents {
                if let systemEvent = aiCalendarAgent.events.first(where: {
                    $0.eventIdentifier == event.originalEventIdentifier &&
                    Calendar.current.isDate($0.startDate, inSameDayAs: event.date)
                }) {
                    aiCalendarAgent.removeFromWhiteList(systemEvent)
                }
            }
            
            await MainActor.run {
                selectedEventIdentifiers.removeAll()
            }
        }
    }
    
    private func performAIOptimization() {
        Task {
            let selectedEvents = getSelectedEvents()
            var systemEventsToOptimize: [AICalendarSystemEvent] = []
            var notFoundEvents: [CalendarEvent] = []
            
            for event in selectedEvents {
                if let systemEvent = aiCalendarAgent.events.first(where: {
                    $0.eventIdentifier == event.originalEventIdentifier &&
                    Calendar.current.isDate($0.startDate, inSameDayAs: event.date)
                }) {
                    systemEventsToOptimize.append(systemEvent)
                } else {
                    notFoundEvents.append(event)
                }
            }
            
            let result = await aiCalendarAgent.deleteEvents(systemEventsToOptimize)
            
            await MainActor.run {
                selectedEventIdentifiers.removeAll()
                
                var allFailedEvents: [(AICalendarSystemEvent, AICalendarDeletionError)] = result.failedEvents
                
                for notFoundEvent in notFoundEvents {
                    let tempSystemEvent = AICalendarSystemEvent(
                        eventIdentifier: notFoundEvent.originalEventIdentifier,
                        title: notFoundEvent.title,
                        startDate: notFoundEvent.date,
                        endDate: notFoundEvent.date,
                        isAllDay: false,
                        calendar: notFoundEvent.source,
                        isMarkedAsSpam: false,
                        isWhiteListed: false
                    )
                    allFailedEvents.append((tempSystemEvent, .eventNotFound))
                }
                
                if !allFailedEvents.isEmpty {
                    failedOptimizationEvents = allFailedEvents
                    
                    if let firstCannotDelete = allFailedEvents.first {
                        optimizationFailureMessage = firstCannotDelete.1.localizedDescription
                    }
                    
                    showingOptimizationFailedAlert = true
                }
            }
        }
    }
    
    private func getSelectedEvents() -> [CalendarEvent] {
        return intelligentFilteredEvents.filter { event in
            selectedEventIdentifiers.contains(event.eventIdentifier)
        }
    }
    
    private func aiFilterName(for filter: CalendarOptimizationFilter) -> String {
        switch filter {
        case .aiScanEvents: return "All events"
        case .aiSafeList: return "AI Safe List"
        }
    }
}
