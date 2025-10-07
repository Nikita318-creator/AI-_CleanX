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
        formatter.dateFormat = "MMM d" // Упрощаем для чипа
        return formatter.string(from: aiScanStartDate)
    }

    var formattedEndDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // Упрощаем для чипа
        return formatter.string(from: aiScanEndDate)
    }

    enum CalendarOptimizationFilter: String, CaseIterable {
        case aiScanEvents = "To Review"
        case aiSafeList = "Trusted"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                controlPanelContainer()
                    .padding(.horizontal)
                    .padding(.bottom, 15)
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
                        .padding(.vertical, 15)
                        .background(CMColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(CMColor.background.ignoresSafeArea())
            .navigationTitle("Smart Calendar\nCleanup")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: toggleSelectAll) {
                        Text(selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty ? "Clear All" : "Select All")
                            .font(.subheadline)
                            .foregroundColor(CMColor.primary)
                    }
                    .opacity(intelligentFilteredEvents.isEmpty && queryText.isEmpty ? 0 : 1)
                }
            }
        }
        .navigationViewStyle(.stack)
        
        .sheet(isPresented: $showingAIScanStartDatePicker) {
            if #available(iOS 16.0, *) {
                SystemDatePickerView(selectedDate: $aiScanStartDate)
                    .presentationDetents([.medium, .large])
                    .onDisappear { Task { await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate) } }
            } else {
                SystemDatePickerView(selectedDate: $aiScanStartDate)
                    .onDisappear { Task { await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate) } }
            }
        }
        .sheet(isPresented: $showingAIScanEndDatePicker) {
            if #available(iOS 16.0, *) {
                SystemDatePickerView(selectedDate: $aiScanEndDate)
                    .presentationDetents([.medium, .large])
                    .onDisappear { Task { await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate) } }
            } else {
                SystemDatePickerView(selectedDate: $aiScanEndDate)
                    .onDisappear { Task { await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate) } }
            }
        }
        .onAppear {
            if aiCalendarAgent.authorizationStatus == .notDetermined {
                Task { await aiCalendarAgent.requestCalendarAccess() }
            } else {
                Task { await aiCalendarAgent.loadEvents(from: aiScanStartDate, to: aiScanEndDate) }
            }
        }
        .alert("Permission Required", isPresented: $showingAIPermissionPrompt) {
             Button("Open Settings") {
                 if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                     UIApplication.shared.open(settingsUrl)
                 }
             }
             Button("Not Now", role: .cancel) { }
         } message: { Text("Calendar access is needed to analyze and manage your events. Enable it in Settings.") }
         .alert("Confirm Removal", isPresented: $showingAIOptimizationConfirmation) {
             Button("Remove \(selectedEventIdentifiers.count)", role: .destructive) { performAIOptimization() }
             Button("Cancel", role: .cancel) { }
         } message: { Text("Selected events will be permanently removed. This cannot be undone.") }
         .overlay {
             if showingOptimizationFailedAlert {
                 CannotDeleteEventView(
                     eventTitle: failedOptimizationEvents.first?.0.calendar ?? "Unknown Calendar",
                     message: optimizationFailureMessage,
                     onGuide: { showingOptimizationFailedAlert = false; showingAIGuide = true },
                     onCancel: { showingOptimizationFailedAlert = false }
                 )
                 .animation(.easeInOut(duration: 0.3), value: showingOptimizationFailedAlert)
             }
         }
         .sheet(isPresented: $showingAIGuide) {
             CalendarInstructionsView()
         }
    }
    
    // MARK: - Контейнер Управления (Clean & Grouped)
    private func controlPanelContainer() -> some View {
        VStack(spacing: 15) {
            // 1. Поиск
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(CMColor.secondaryText)
                
                TextField("Search event title or source...", text: $queryText)
                    .foregroundColor(CMColor.primaryText)
                    .font(.body)
                
                if !queryText.isEmpty {
                    Button(action: { queryText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // 2. Выбор Даты и Фильтров - ИСПРАВЛЕНО
            HStack {
                // Две отдельные кнопки для выбора диапазона
                dateRangeSelectionView() // Внутри теперь две кнопки
                
                Spacer()
                
                // Нативный сегментированный Picker для фильтров
                Picker("Filter", selection: $currentFilterTab) {
                    ForEach(CalendarOptimizationFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .onChange(of: currentFilterTab) { _ in selectedEventIdentifiers.removeAll() }
            }
        }
        .padding(.top, 10)
    }

    private func dateRangeSelectionView() -> some View {
        // ИСПРАВЛЕНО: Вертикальный стек из двух кнопок заменён на горизонтальный стек чипов
        HStack(spacing: 8) {
            
            // 1. Кнопка Начальной Даты
            Button(action: { showingAIScanStartDatePicker = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline)
                    Text(formattedStartDate)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(CMColor.primary.opacity(0.15))
                .foregroundColor(CMColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
            // 2. Разделитель
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(CMColor.secondaryText.opacity(0.7))
            
            // 3. Кнопка Конечной Даты
            Button(action: { showingAIScanEndDatePicker = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.subheadline)
                    Text(formattedEndDate)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(CMColor.primary.opacity(0.15))
                .foregroundColor(CMColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    
    private func eventsScrollView() -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(intelligentFilteredEvents) { event in
                    eventRowStyled(event: event)
                }
            }
            .padding(.horizontal)
            .padding(.top, 5)
            .padding(.bottom, 50)
        }
    }

    private func eventRowStyled(event: CalendarEvent) -> some View {
        HStack(alignment: .top, spacing: 15) {
            Button(action: { toggleSelection(for: event) }) {
                Image(systemName: selectedEventIdentifiers.contains(event.eventIdentifier) ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(selectedEventIdentifiers.contains(event.eventIdentifier) ? CMColor.primary : CMColor.secondaryText.opacity(0.4))
                    .frame(width: 25, height: 25)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: selectedEventIdentifiers.contains(event.eventIdentifier))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(event.source)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Text(event.date, style: .date)
                        .font(.caption)
                }
                .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
        }
        .padding(15)
        .background(CMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
    }

    private func bottomActionBar() -> some View {
        HStack(spacing: 12) {
            if currentFilterTab == .aiSafeList {
                ActionButton(
                    title: "Unmark Safe",
                    icon: "shield.lefthalf.filled.slash",
                    color: CMColor.secondary,
                    action: removeEventsFromAISafeList
                )
            } else {
                ActionButton(
                    title: "Mark Safe (\(selectedEventIdentifiers.count))",
                    icon: "shield.lefthalf.filled",
                    color: CMColor.secondary,
                    action: addEventsToAISafeList
                )
                
                ActionButton(
                    title: "Remove (\(selectedEventIdentifiers.count))",
                    icon: "trash.fill",
                    color: CMColor.error,
                    action: { showingAIOptimizationConfirmation = true }
                )
            }
        }
    }

    private func ActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func requestAccessView() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60, weight: .regular))
                .foregroundColor(CMColor.primary)
            
            Text("Calendar Access Required")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(CMColor.primaryText)
            
            Text("To start cleaning, please grant access to your calendar events.")
                .font(.subheadline)
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { Task { await aiCalendarAgent.requestCalendarAccess() } }) {
                Text("Grant Access")
                    .frame(maxWidth: 250)
                    .padding(.vertical, 12)
                    .background(CMColor.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accessDeniedView() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60, weight: .regular))
                .foregroundColor(CMColor.error)
            
            Text("Access Denied")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(CMColor.primaryText)
            
            Text("Please enable Calendar access in the device settings to use this feature.")
                .font(.subheadline)
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { showingAIPermissionPrompt = true }) {
                Text("Open Settings")
                    .frame(maxWidth: 250)
                    .padding(.vertical, 12)
                    .background(CMColor.error.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func allClearView() -> some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(CMColor.secondary)
            
            Text("All Clear!")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(CMColor.primaryText)
            
            Text("No suspicious events found in the current date range. Your calendar is clean.")
                .font(.subheadline)
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func searchEmptyView() -> some View {
        VStack(spacing: 15) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(CMColor.secondaryText.opacity(0.6))
            
            Text("No Matches Found")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(CMColor.primaryText)
            
            Text("Try different keywords or check the selected date range above.")
                .font(.subheadline)
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func processingView() -> some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(CMColor.primary)
            
            Text("Analyzing Events...")
                .font(.headline)
                .foregroundColor(CMColor.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods

    private func toggleSelection(for event: CalendarEvent) {
        withAnimation(.spring(response: 0.3)) {
            if selectedEventIdentifiers.contains(event.eventIdentifier) {
                selectedEventIdentifiers.remove(event.eventIdentifier)
            } else {
                selectedEventIdentifiers.insert(event.eventIdentifier)
            }
        }
    }
    
    private func toggleSelectAll() {
        withAnimation(.spring(response: 0.3)) {
            if selectedEventIdentifiers.count == intelligentFilteredEvents.count && !intelligentFilteredEvents.isEmpty {
                selectedEventIdentifiers.removeAll()
            } else {
                selectedEventIdentifiers = Set(intelligentFilteredEvents.map { $0.eventIdentifier })
            }
        }
    }
    
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
                withAnimation { selectedEventIdentifiers.removeAll() }
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
                withAnimation { selectedEventIdentifiers.removeAll() }
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
        return intelligentFilteredEvents.filter { selectedEventIdentifiers.contains($0.eventIdentifier) }
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
                
                // Action buttons row (ФИНАЛЬНЫЙ ФИКС)
                HStack(spacing: 0) {
                    // View instructions
                    Button(action: onGuide) {
                        Text("View Instructions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(CMColor.primary)
                            .frame(maxWidth: .infinity) // <-- Удалили maxHeight: .infinity
                    }
                    .frame(height: 60) // Фиксированная высота кнопки
                    
                    Rectangle()
                        .fill(CMColor.border.opacity(0.5))
                        .frame(width: 0.5)
                    
                    // Dismiss
                    Button(action: onCancel) {
                        Text("Dismiss")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                            .frame(maxWidth: .infinity) // <-- Удалили maxHeight: .infinity
                    }
                    .frame(height: 60) // Фиксированная высота кнопки
                }
            }
            .background(CMColor.surface)
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 8)
            .padding(.horizontal, 32)
            // <-- КЛЮЧЕВОЕ ИЗМЕНЕНИЕ: Заставляем Vstack использовать минимальную высоту.
            .fixedSize(horizontal: false, vertical: true)
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
