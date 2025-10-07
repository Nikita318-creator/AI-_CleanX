import EventKit
import SwiftUI


// MARK: - AI Calendar View (Redesigned)

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
                // Top section with controls
                VStack(spacing: 20) {
                    intelligentHeaderView()
                    dateRangeAndSearchView()
                    filterSegmentView()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
                .background(CMColor.background)

                if aiCalendarAgent.authorizationStatus == .denied {
                    accessDeniedView()
                } else if aiCalendarAgent.authorizationStatus == .notDetermined {
                    requestAccessView()
                } else if aiCalendarAgent.isLoading {
                    processingView()
                } else if intelligentFilteredEvents.isEmpty && !queryText.isEmpty {
                    searchEmptyView()
                } else if intelligentFilteredEvents.isEmpty {
                    allClearView()
                } else {
                    eventsScrollView()
                }

                Spacer()
                
                if !selectedEventIdentifiers.isEmpty {
                    bottomActionBar()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
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
        .alert("Permission Required", isPresented: $showingAIPermissionPrompt) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Calendar access is needed to analyze and manage your events. Enable it in Settings.")
        }
        .alert("Confirm Removal", isPresented: $showingAIOptimizationConfirmation) {
            Button("Remove \(selectedEventIdentifiers.count)", role: .destructive) {
                performAIOptimization()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Selected events will be permanently removed. This cannot be undone.")
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
    
    // MARK: - Header Components
    
    private func intelligentHeaderView() -> some View {
        HStack(spacing: 16) {
            // Close button
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(CMColor.surface)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
            }
            
            Spacer()
            
            // Title with icon
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(CMColor.primary)
                
                Text("Smart Cleanup")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            Spacer()
            
            // Select toggle
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    if selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty {
                        selectedEventIdentifiers.removeAll()
                    } else {
                        selectedEventIdentifiers = Set(intelligentFilteredEvents.map { $0.eventIdentifier })
                    }
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text(selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty ? "Clear" : "All")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(CMColor.primary)
            }
        }
    }
    
    private func dateRangeAndSearchView() -> some View {
        VStack(spacing: 14) {
            // Date range selector
            HStack(spacing: 10) {
                Button(action: { showingAIScanStartDatePicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        
                        Text(formattedStartDate)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(CMColor.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(CMColor.surface)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CMColor.secondaryText)
                
                Button(action: { showingAIScanEndDatePicker = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                        
                        Text(formattedEndDate)
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(CMColor.primary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(CMColor.surface)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                
                TextField("Find events...", text: $queryText)
                    .foregroundColor(CMColor.primaryText)
                    .font(.system(size: 16))
                    .submitLabel(.search)
                
                if !queryText.isEmpty {
                    Button(action: {
                        withAnimation {
                            queryText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(CMColor.surface)
            .cornerRadius(10)
        }
    }
    
    private func filterSegmentView() -> some View {
        HStack(spacing: 6) {
            ForEach([CalendarOptimizationFilter.aiScanEvents, .aiSafeList], id: \.self) { filter in
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        currentFilterTab = filter
                        selectedEventIdentifiers.removeAll()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: filter == .aiScanEvents ? "list.bullet" : "checkmark.shield")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text(intelligentFilterName(for: filter))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(currentFilterTab == filter ? .white : CMColor.secondaryText)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(
                        currentFilterTab == filter ? CMColor.primary : CMColor.surface
                    )
                    .cornerRadius(10)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Content Views
    
    private func eventsScrollView() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(intelligentFilteredEvents) { event in
                    EventRowView(
                        event: event,
                        isSelected: selectedEventIdentifiers.contains(event.eventIdentifier),
                        onSelect: {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedEventIdentifiers.contains(event.eventIdentifier) {
                                    selectedEventIdentifiers.remove(event.eventIdentifier)
                                } else {
                                    selectedEventIdentifiers.insert(event.eventIdentifier)
                                }
                            }
                        }
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private func searchEmptyView() -> some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(CMColor.secondaryText.opacity(0.6))
            
            VStack(spacing: 10) {
                Text("Nothing Found")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("No events match your search criteria. Try different keywords or adjust the date range.")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func bottomActionBar() -> some View {
        HStack(spacing: 12) {
            if currentFilterTab == .aiSafeList {
                Button(action: { removeEventsFromAISafeList() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Unmark")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.secondary)
                    .cornerRadius(14)
                }
            } else {
                Button(action: { addEventsToAISafeList() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Mark Safe")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.secondary)
                    .cornerRadius(14)
                }
                
                Button(action: { showingAIOptimizationConfirmation = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                        
                        Text("Remove")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(CMColor.error)
                    .cornerRadius(14)
                }
            }
        }
    }
    
    // MARK: - State Views
    
    private func requestAccessView() -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.open")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(spacing: 14) {
                Text("Access Needed")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("To help you manage calendar events, we need permission to access your calendars. Your information stays private and secure on your device.")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Button(action: {
                Task {
                    await aiCalendarAgent.requestCalendarAccess()
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Grant Access")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(CMColor.primary)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func accessDeniedView() -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(CMColor.error.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.lock")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(CMColor.error)
            }
            
            VStack(spacing: 14) {
                Text("Access Blocked")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Calendar access is currently disabled. To use this feature, please enable it in your device Settings under Privacy & Security.")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
            
            Button(action: { showingAIPermissionPrompt = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(CMColor.primary)
                .cornerRadius(14)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func processingView() -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.8)
                .tint(CMColor.primary)
            
            VStack(spacing: 8) {
                Text("Analyzing Events")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Please wait while we scan your calendar")
                    .font(.system(size: 15))
                    .foregroundColor(CMColor.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func allClearView() -> some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(spacing: 14) {
                Text("All Clean!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("No events found in the selected date range that need attention. Your calendar looks good!")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
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
                withAnimation {
                    selectedEventIdentifiers.removeAll()
                }
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
                withAnimation {
                    selectedEventIdentifiers.removeAll()
                }
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
    
    private func intelligentFilterName(for filter: CalendarOptimizationFilter) -> String {
        switch filter {
        case .aiScanEvents: return "To Review"
        case .aiSafeList: return "Trusted"
        }
    }
}

// MARK: - Event Row View (Redesigned)

struct EventRowView: View {
    let event: CalendarEvent
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                // Selection indicator (left side)
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? CMColor.primary : CMColor.backgroundSecondary)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Circle()
                                .strokeBorder(CMColor.border, lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                        }
                    }
                
                // Event content container
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        // Event name
                        Text(event.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(CMColor.primaryText)
                            .lineLimit(2)
                        
                        Spacer(minLength: 8)
                        
                        // Compact date badge
                        Text(event.formattedDate)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(CMColor.backgroundSecondary)
                            .cornerRadius(8)
                    }
                    
                    // Calendar source with icon
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundColor(CMColor.secondaryText.opacity(0.7))
                        
                        Text(event.source)
                            .font(.system(size: 14))
                            .foregroundColor(CMColor.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? CMColor.primary.opacity(0.06) : CMColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? CMColor.primary.opacity(0.3) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Deletion Alert View (Redesigned)

struct CannotDeleteEventView: View {
    let eventTitle: String
    let message: String
    let onGuide: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Alert card
            VStack(spacing: 0) {
                // Icon header
                VStack(spacing: 18) {
                    // Status icon
                    ZStack {
                        Circle()
                            .fill(CMColor.secondary.opacity(0.12))
                            .frame(width: 72, height: 72)
                        
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(CMColor.secondary)
                    }
                    .padding(.top, 28)
                    
                    // Calendar identifier
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.circle")
                            .font(.system(size: 20))
                            .foregroundColor(CMColor.primary)
                        
                        Text(eventTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CMColor.backgroundSecondary)
                    .cornerRadius(10)
                }
                
                // Message section
                VStack(spacing: 14) {
                    Text("Removal Not Possible")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("This calendar is linked to an account on your device. To remove it completely, you'll need to manage the associated account settings. Our step-by-step instructions can help you with this process.")
                        .font(.system(size: 15))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 24)
                
                // Separator
                Rectangle()
                    .fill(CMColor.border.opacity(0.5))
                    .frame(height: 0.5)
                
                // Action buttons row
                HStack(spacing: 0) {
                    // View instructions
                    Button(action: onGuide) {
                        Text("View Instructions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(CMColor.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    
                    Rectangle()
                        .fill(CMColor.border.opacity(0.5))
                        .frame(width: 0.5)
                    
                    // Dismiss
                    Button(action: onCancel) {
                        Text("Dismiss")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
            }
            .background(CMColor.surface)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Date Picker View (Redesigned)

struct SystemDatePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    
    var body: some View {
        NavigationView {
            ZStack {
                CMColor.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Date picker
                    DatePicker(
                        "Choose Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .tint(CMColor.primary)
                    
                    Spacer()
                    
                    // Confirm button
                    Button(action: { dismiss() }) {
                        Text("Confirm Selection")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(CMColor.primary)
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
        }
    }
}

// MARK: - Instructions View (Redesigned)

struct CalendarInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingAlternativeMethods = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Hero section
                    VStack(spacing: 20) {
                        // Icon
                        ZStack {
                            Circle()
                                .fill(CMColor.primary.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(CMColor.primary)
                        }
                        .padding(.top, 24)
                        
                        Text("Manage Calendar Subscriptions")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(CMColor.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Visual guide card
                    instructionCardView()
                        .padding(.horizontal, 20)
                    
                    // Steps section
                    stepsListView()
                        .padding(.horizontal, 20)
                    
                    // Action buttons
                    actionButtonsStack()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(CMColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(CMColor.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Help & Support")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
            }
        }
        .sheet(isPresented: $showingAlternativeMethods) {
            OtherSolutionsView()
        }
    }
    
    // Instruction visual card
    private func instructionCardView() -> some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            CMColor.primary.opacity(0.08),
                            CMColor.primary.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    VStack(spacing: 20) {
                        // Mock calendar tabs
                        HStack(spacing: 40) {
                            calendarNavItem("Today", icon: "calendar", isHighlighted: false)
                            calendarNavItem("Calendars", icon: "calendar.badge.clock", isHighlighted: true)
                            calendarNavItem("Search", icon: "magnifyingglass", isHighlighted: false)
                        }
                        .padding(.top, 32)
                        
                        Spacer()
                        
                        // Hint text
                        Text("Tap 'Calendars' to manage subscriptions")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                            .padding(.bottom, 20)
                    }
                }
                .frame(height: 360)
        }
    }
    
    private func calendarNavItem(_ title: String, icon: String, isHighlighted: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(isHighlighted ? CMColor.primary : CMColor.secondaryText)
            
            Text(title)
                .font(.system(size: 11, weight: isHighlighted ? .semibold : .regular))
                .foregroundColor(isHighlighted ? CMColor.primary : CMColor.secondaryText)
        }
    }
    
    // Steps list
    private func stepsListView() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Quick Steps")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .padding(.bottom, 4)
            
            stepRow(
                number: 1,
                icon: "1.circle.fill",
                title: "Navigate to unwanted event or tap 'Calendars'"
            )
            
            stepRow(
                number: 2,
                icon: "2.circle.fill",
                title: "Locate the subscription you wish to remove"
            )
            
            stepRow(
                number: 3,
                icon: "3.circle.fill",
                title: "Select 'Unsubscribe' to remove the calendar"
            )
        }
        .padding(20)
        .background(CMColor.surface)
        .cornerRadius(16)
    }
    
    private func stepRow(number: Int, icon: String, title: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(CMColor.primary)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(CMColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
    
    // Action buttons
    private func actionButtonsStack() -> some View {
        VStack(spacing: 14) {
            Button(action: openCalendarApp) {
                HStack {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text("Open Calendar App")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(CMColor.primary)
                .cornerRadius(14)
            }
            
            Button(action: { showingAlternativeMethods = true }) {
                HStack {
                    Image(systemName: "list.bullet.circle")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Alternative Methods")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(CMColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(CMColor.backgroundSecondary)
                .cornerRadius(14)
            }
        }
    }
    
    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "x-apple-calevent://") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}

// MARK: - Other Solutions View (Redesigned)

struct OtherSolutionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 36) {
                    // Header section
                    headerSectionView()
                        .padding(.top, 24)
                    
                    // Method 1
                    methodOneView()
                    
                    // Divider
                    dividerView()
                    
                    // Method 2
                    methodTwoView()
                    
                    // Footer note
                    footerNoteView()
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }
            .background(CMColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 17))
                        }
                        .foregroundColor(CMColor.primary)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Additional Options")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                }
            }
        }
    }
    
    // Header
    private func headerSectionView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(CMColor.primary)
            
            Text("Additional Removal Methods")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.center)
            
            Text("Try these alternative approaches if the standard method doesn't work")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }
    
    // Method 1
    private func methodOneView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Method header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CMColor.primary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Text("A")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(CMColor.primary)
                }
                
                Text("Direct Calendar Method")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 14) {
                methodStepView(
                    step: "1",
                    description: "Launch your device's native Calendar application"
                )
                
                methodStepView(
                    step: "2",
                    description: "Access 'Calendars' from the bottom navigation"
                )
                
                methodStepView(
                    step: "3",
                    description: "Find the subscription and choose 'Unsubscribe' or removal option"
                )
            }
            .padding(16)
            .background(CMColor.surface)
            .cornerRadius(12)
            
            // Action button
            Button(action: openCalendarApp) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Launch Calendar")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(CMColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CMColor.primary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // Method 2
    private func methodTwoView() -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Method header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(CMColor.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    
                    Text("B")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(CMColor.secondary)
                }
                
                Text("System Settings Method")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            // Steps
            VStack(alignment: .leading, spacing: 14) {
                methodStepView(
                    step: "1",
                    description: "Navigate to your device Settings"
                )
                
                methodStepView(
                    step: "2",
                    description: "Locate and select 'Calendar' from the list"
                )
                
                methodStepView(
                    step: "3",
                    description: "Tap 'Accounts' to view all sources"
                )
                
                methodStepView(
                    step: "4",
                    description: "Remove the unwanted account completely"
                )
            }
            .padding(16)
            .background(CMColor.surface)
            .cornerRadius(12)
            
            // Action button
            Button(action: openSettingsApp) {
                HStack {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Open Settings")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundColor(CMColor.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(CMColor.secondary.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // Step view for methods
    private func methodStepView(step: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 28, height: 28)
                
                Text(step)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CMColor.primary)
            }
            
            Text(description)
                .font(.system(size: 16))
                .foregroundColor(CMColor.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // Divider
    private func dividerView() -> some View {
        HStack {
            Rectangle()
                .fill(CMColor.border)
                .frame(height: 1)
            
            Text("OR")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CMColor.secondaryText)
                .padding(.horizontal, 12)
            
            Rectangle()
                .fill(CMColor.border)
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }
    
    // Footer
    private func footerNoteView() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(CMColor.secondaryText)
                
                Text("Official Apple Guidelines")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Capsule()
                .fill(CMColor.border)
                .frame(width: 120, height: 5)
        }
    }
    
    // Actions
    private func openCalendarApp() {
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "x-apple-calevent://") {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
    
    private func openSettingsApp() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        dismiss()
    }
}
