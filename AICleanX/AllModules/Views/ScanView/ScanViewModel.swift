import SwiftUI
import Combine
import Contacts

@MainActor
final class MainViewModel: ObservableObject {
    enum ContactPermissionStatus {
        case notDetermined
        case denied
        case authorized
        case loading
    }
    
    enum CalendarPermissionStatus {
        case notDetermined
        case denied
        case authorized
        case loading
    }
    
    @Published var subtitle = ""
    @Published var progress = Double.zero
    @Published var counts = AICleanServiceCounts<Int>()
    @Published var megabytes = AICleanServiceCounts<Double>()
    @Published var contactsCount: Int = 0
    @Published var calendarEventsCount: Int = 0
    @Published var isContactsLoading: Bool = false
    @Published var isCalendarLoading: Bool = false
    @Published var contactsPermissionStatus: ContactPermissionStatus = .notDetermined
    @Published var calendarPermissionStatus: CalendarPermissionStatus = .notDetermined
    @Published var previews = AICleanServicePreviews(
        _similar: nil,
        _duplicates: nil,
        _blurred: nil,
        _screenshots: nil,
        _videos: nil
    )
    
    private let mediaCleanerService = AIMainCleanService.shared
    private let contactsViewModel: AICleanerContactsViewModel
    private let calendarService: AICalendarAgent

    private var cancellables = Set<AnyCancellable>()

    private let purchaseService = ApphudPurchaseService()

    var hasActiveSubscription: Bool {
        purchaseService.hasActiveSubscription
    }
    
    init() {
        self.contactsViewModel = AICleanerContactsViewModel()
        self.calendarService = AICalendarAgent()
        setupBindings()
        checkInitialPermissions()
    }
    
    private func checkInitialPermissions() {
        let calendarStatus = calendarService.authorizationStatus
        switch calendarStatus {
        case .fullAccess:
            calendarPermissionStatus = .authorized
        case .denied, .restricted:
            calendarPermissionStatus = .denied
        case .notDetermined:
            calendarPermissionStatus = .notDetermined
        case .writeOnly:
            calendarPermissionStatus = .denied
        @unknown default:
            calendarPermissionStatus = .notDetermined
        }
        
        let contactsStatus = CNContactStore.authorizationStatus(for: .contacts)
        switch contactsStatus {
        case .authorized, .limited:
            contactsPermissionStatus = .authorized
        case .denied, .restricted:
            contactsPermissionStatus = .denied
        case .notDetermined:
            contactsPermissionStatus = .notDetermined
        @unknown default:
            contactsPermissionStatus = .notDetermined
        }
    }

    func onAppear() {
        requestAllPermissions()
    }
    
    private func requestAllPermissions() {
        Task { @MainActor in
            async let photoPermission = requestPhotoLibraryPermission()
            async let contactsPermission = requestContactsPermissionAsync()
            async let calendarPermission = requestCalendarPermissionAsync()
            
            let (photoGranted, contactsGranted, calendarGranted) = await (photoPermission, contactsPermission, calendarPermission)
            startDataLoading(photoGranted: photoGranted, contactsGranted: contactsGranted, calendarGranted: calendarGranted)
        }
    }
    
    private func requestPhotoLibraryPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            mediaCleanerService.requestAuthorization { status in
                let granted = status == .authorized || status == .limited
                continuation.resume(returning: granted)
            }
        }
    }
    
    private func requestContactsPermissionAsync() async -> Bool {
        await withCheckedContinuation { continuation in
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self.contactsPermissionStatus = .authorized
                    } else {
                        self.contactsPermissionStatus = .denied
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func requestCalendarPermissionAsync() async -> Bool {
        return await withCheckedContinuation { continuation in
            Task {
                await self.calendarService.requestCalendarAccess()
                await MainActor.run {
                    let newStatus = self.calendarService.authorizationStatus
                    var granted = false
                        switch newStatus {
                        case .fullAccess:
                            self.calendarPermissionStatus = .authorized
                            granted = true
                        case .denied, .restricted:
                            self.calendarPermissionStatus = .denied
                            granted = false
                        case .writeOnly:
                            self.calendarPermissionStatus = .denied
                            granted = false
                        case .notDetermined:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                        @unknown default:
                            self.calendarPermissionStatus = .notDetermined
                            granted = false
                        }
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    private func startDataLoading(photoGranted: Bool, contactsGranted: Bool, calendarGranted: Bool) {
        if photoGranted {
            mediaCleanerService.resetData()
            mediaCleanerService.scanAllImages()
            mediaCleanerService.scanVideos()
        }
        
        if contactsGranted {
            scanContacts()
        }
        
        if calendarGranted {
            scanCalendar()
        }
    }
    
    func scanContacts() {
        // Сначала загружаем локальные контакты
        let localContactsCount = contactsViewModel.getContactsCount()
        
        if contactsPermissionStatus == .authorized {
            isContactsLoading = true
            Task {
                let systemContactsCount = await loadSystemContactsCount()
                contactsCount = localContactsCount + systemContactsCount
                isContactsLoading = false
            }
        } else {
            contactsCount = localContactsCount
        }
    }
    
    private func loadSystemContactsCount() async -> Int {
        let store = CNContactStore()
        let keysToFetch = [CNContactIdentifierKey] as [CNKeyDescriptor]
        
        return await Task.detached {
            do {
                let request = CNContactFetchRequest(keysToFetch: keysToFetch)
                var count = 0
                try store.enumerateContacts(with: request) { _, _ in
                    count += 1
                }
                return count
            } catch {
                return 0
            }
        }.value
    }
    
    func scanCalendar() {
        if calendarPermissionStatus == .authorized {
            isCalendarLoading = true
            Task {
                await calendarService.loadEvents()
                calendarEventsCount = calendarService.events.count
                isCalendarLoading = false
            }
        } else {
            calendarEventsCount = 0
        }
    }
    
    func requestContactsPermission() {
        contactsPermissionStatus = .loading
        
        let store = CNContactStore()
        Task {
            do {
                _ = try await store.requestAccess(for: .contacts)
                let newStatus = CNContactStore.authorizationStatus(for: .contacts)
                
                switch newStatus {
                case .authorized:
                    contactsPermissionStatus = .authorized
                    scanContacts()
                case .denied, .restricted:
                    contactsPermissionStatus = .denied
                default:
                    contactsPermissionStatus = .notDetermined
                }
            } catch {
                contactsPermissionStatus = .denied
            }
        }
    }
    
    func requestCalendarPermission() {
        calendarPermissionStatus = .loading
        
        Task {
            await calendarService.requestCalendarAccess()
            let newStatus = calendarService.authorizationStatus
            
            if #available(iOS 17.0, *) {
                switch newStatus {
                case .fullAccess:
                    calendarPermissionStatus = .authorized
                    scanCalendar()
                case .denied, .restricted:
                    calendarPermissionStatus = .denied
                case .notDetermined:
                    calendarPermissionStatus = .notDetermined
                case .writeOnly:
                    calendarPermissionStatus = .denied
                @unknown default:
                    calendarPermissionStatus = .notDetermined
                }
            } else {
                switch newStatus {
                case .authorized, .fullAccess, .writeOnly:
                    calendarPermissionStatus = .authorized
                    scanCalendar()
                case .denied, .restricted:
                    calendarPermissionStatus = .denied
                case .notDetermined:
                    calendarPermissionStatus = .notDetermined
                @unknown default:
                    calendarPermissionStatus = .notDetermined
                }
            }
        }
    }
    
    func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl) { _ in }
        }
    }
    
    func getSections(for type: AICleanServiceType) -> [AICleanServiceSection] {
        return mediaCleanerService.getMedia(type)
    }

    private func setupBindings() {
        mediaCleanerService.progressPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                if progress.value >= 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.progress = progress.value
                    }
                } else {
                    self?.progress = progress.value
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(mediaCleanerService.megabytesPublisher, mediaCleanerService.countsPublisher)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .sink { [weak self] megabytes, counts in
                self?.counts = counts
                self?.megabytes = megabytes
                self?.subtitle = "AI analysis shows \(counts.total) items (a total of \(megabytes.total.formatAsFileSize())) that can be cleaned for optimization."
            }
            .store(in: &cancellables)

        mediaCleanerService.previewsPublisher
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.global())
            .receive(on: RunLoop.main)
            .sink { [weak self] previews in
                self?.previews = previews
            }
            .store(in: &cancellables)
        
        contactsViewModel.$contacts
            .receive(on: RunLoop.main)
            .sink { [weak self] contacts in
                self?.contactsCount = contacts.count
            }
            .store(in: &cancellables)
        
        calendarService.$events
            .receive(on: RunLoop.main)
            .sink { [weak self] events in
                self?.calendarEventsCount = events.count
            }
            .store(in: &cancellables)
    }
}
