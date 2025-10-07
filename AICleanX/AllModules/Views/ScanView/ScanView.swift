import SwiftUI

enum CategoryViewType: Identifiable, Hashable {
    case contacts
    case calendar
    case similarPhotos
    case duplicates
    case blurryPhotos
    case screenshots
    case videos
    
    var id: String {
        switch self {
        case .contacts: return "contacts"
        case .calendar: return "calendar"
        case .similarPhotos: return "similarPhotos"
        case .duplicates: return "duplicates"
        case .blurryPhotos: return "blurryPhotos"
        case .screenshots: return "screenshots"
        case .videos: return "videos"
        }
    }
}

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedView: CategoryViewType?
    @State private var showSettingsView = false

    init(isPaywallPresented: Binding<Bool>) {
        self._isPaywallPresented = isPaywallPresented
    }
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    private var photoCategories: [ScanItemType] {
        [.similar, .duplicates, .blurred, .screenshots]
    }
    
    private var videoCategory: [ScanItemType] {
        [.videos]
    }
    
    private var utilityCategories: [ScanItemType] {
        [.contacts, .calendar]
    }
    
    var body: some View {
        ZStack {
            // Фон: Снежно-голубой (#F0F8FF)
            CMColor.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Header Section
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            // НОВЫЙ ТЕКСТ: Заголовок
                            Text("IceClean Optimization") // Технологичный, нейтральный заголовок
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if viewModel.progress < 1 {
                                // НОВЫЙ ТЕКСТ: Сканирование
                                Text("Analyzing Storage: \(Int(viewModel.progress * 100))%")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CMColor.secondaryText)
                            } else {
                                // НОВЫЙ ТЕКСТ: Готовность
                                Text("Deep Scan Complete. Optimization Insights:")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(CMColor.tertiaryText)
                                Text(viewModel.subtitle)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CMColor.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        // Settings Button
                        Button(action: {
                            showSettingsView = true
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(CMColor.iconSecondary)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    // --- НОВЫЙ ТЕКСТ: Заголовок группы 1 ---
                    CategoryGroupView(title: "Media Diagnostics (Images)", categories: photoCategories, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                    
                    // --- НОВЫЙ ТЕКСТ: Заголовок группы 2 ---
                    CategoryGroupView(title: "Large Files Cleanup (Videos)", categories: videoCategory, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                    
                    // --- НОВЫЙ ТЕКСТ: Заголовок группы 3 ---
                    CategoryGroupView(title: "System Data Optimization", categories: utilityCategories, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                viewModel.onAppear()
                viewModel.scanContacts()
                viewModel.scanCalendar()
            }
            .fullScreenCover(item: $presentedView) { viewType in
                switch viewType {
                case .contacts:
                    AICleanerContactsView()
                case .calendar:
                    AICalendarView()
                case .similarPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.similar)),
                            type: .similar
                        )
                    )
                case .duplicates:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.duplicates)),
                            type: .duplicates
                        )
                    )
                case .blurryPhotos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.blurred)),
                            type: .blurred
                        )
                    )
                case .screenshots:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .image(.screenshots)),
                            type: .screenshots
                        )
                    )
                case .videos:
                    SimilaritySectionsView(
                        viewModel: SimilaritySectionsViewModel(
                            sections: viewModel.getSections(for: .video),
                            type: .videos
                        )
                    )
                }
            }
            .fullScreenCover(isPresented: $showSettingsView) {
                SettingsView(isPaywallPresented: $isPaywallPresented)
            }
        }
    }
    
    // ... (generateEmptyStateImage и handleTap остаются без изменений)
    private func generateEmptyStateImage(systemName: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .regular, scale: .large)
        let image = UIImage(systemName: systemName, withConfiguration: config)
        return image?.withTintColor(color, renderingMode: .alwaysOriginal)
    }
    
    private func handleTap(for type: ScanItemType) {
        if !viewModel.hasActiveSubscription {
            isPaywallPresented = true
            return
        }
        
        switch type {
        case .contacts:
            if viewModel.contactsPermissionStatus == .authorized {
                presentedView = .contacts
            } else if viewModel.contactsPermissionStatus == .denied {
                viewModel.openAppSettings()
            }
        case .calendar:
            if viewModel.calendarPermissionStatus == .authorized {
                presentedView = .calendar
            } else if viewModel.calendarPermissionStatus == .denied {
                viewModel.openAppSettings()
            }
        case .similar:
            presentedView = .similarPhotos
        case .duplicates:
            presentedView = .duplicates
        case .blurred:
            presentedView = .blurryPhotos
        case .screenshots:
            presentedView = .screenshots
        case .videos:
            presentedView = .videos
        }
    }
}

// MARK: - Category Group View
struct CategoryGroupView: View {
    let title: String // Принимает новый заголовок
    let categories: [ScanItemType]
    @ObservedObject var viewModel: MainViewModel
    let handleTap: (ScanItemType) -> Void
    let generateEmptyStateImage: (String, UIColor) -> UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CMColor.primaryText)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(categories, id: \.self) { type in
                    Button(action: {
                        handleTap(type)
                    }) {
                        CategoryCardView(
                            type: type,
                            viewModel: viewModel,
                            generateEmptyStateImage: generateEmptyStateImage
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Category Card View (Новый Стиль)
struct CategoryCardView: View {
    let type: ScanItemType
    @ObservedObject var viewModel: MainViewModel
    let generateEmptyStateImage: (String, UIColor) -> UIImage?
    
    var body: some View {
        HStack(spacing: 16) {
            // ... (Визуальная часть остается без изменений)
            ZStack {
                if let image = getPreviewImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(CMColor.backgroundSecondary)
                        .frame(width: 56, height: 56)
                }
            }
            .shadow(color: CMColor.black.opacity(0.15), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                // НОВЫЙ ТЕКСТ: Заголовок категории (из enum - не меняется здесь)
                Text(type.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                // НОВЫЙ ТЕКСТ: Счетчики / Статусы
                Text(getItemCountText())
                    .font(.callout)
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.title3)
                .foregroundColor(CMColor.primary)
        }
        .padding(.vertical, 14)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .background(CMColor.surface)
        .cornerRadius(8)
        .shadow(color: CMColor.black.opacity(0.1), radius: 10, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(CMColor.primary, lineWidth: 2)
        )
    }
    
    // ... (getPreviewImage остается без изменений)
    private func getPreviewImage() -> UIImage? {
        switch type {
        case .contacts:
            // Используем .primary для успеха, .warning для ошибки
            return viewModel.contactsPermissionStatus == .authorized ?
            generateEmptyStateImage("person.circle.fill", .primary) :
            generateEmptyStateImage("person.fill.questionmark", .warning)
        case .calendar:
            // Используем .secondary для успеха, .warning для ошибки
            return viewModel.calendarPermissionStatus == .authorized ?
            generateEmptyStateImage("calendar.badge.clock", .secondary) :
            generateEmptyStateImage("calendar.badge.exclamationmark", .warning)
        case .similar:
            return viewModel.previews.similar
        case .duplicates:
            return viewModel.previews.duplicates
        case .blurred:
            return viewModel.previews.blurred
        case .screenshots:
            return viewModel.previews.screenshots
        case .videos:
            return viewModel.previews.videos
        }
    }
    
    // НОВЫЙ МЕТОД: getItemCountText с измененными строками
    private func getItemCountText() -> String {
        switch type {
        case .contacts:
            switch viewModel.contactsPermissionStatus {
            // НОВЫЙ ТЕКСТ: Загрузка/Количество
            case .authorized:
                return viewModel.isContactsLoading ? "Indexing contact entries..." :
                (viewModel.contactsCount == 0 ? "No redundant contacts found" : "\(viewModel.contactsCount) contact entries")
            // НОВЫЙ ТЕКСТ: Статусы разрешений
            case .notDetermined: return "Awaiting access request..."
            case .denied: return "Permission required. Tap to adjust."
            case .loading: return "Verifying access..."
            }
        case .calendar:
            switch viewModel.calendarPermissionStatus {
            // НОВЫЙ ТЕКСТ: Загрузка/Количество
            case .authorized:
                return viewModel.isCalendarLoading ? "Indexing calendar entries..." :
                (viewModel.calendarEventsCount == 0 ? "No old events detected" : "\(viewModel.calendarEventsCount) calendar entries")
            // НОВЫЙ ТЕКСТ: Статусы разрешений
            case .notDetermined: return "Awaiting access request..."
            case .denied: return "Permission required. Tap to adjust."
            case .loading: return "Verifying access..."
            }
        // НОВЫЙ ТЕКСТ: Формат счетчиков
        case .similar:
            return "\(viewModel.counts.similar) files • \(viewModel.megabytes.similar.formatAsFileSize()) potential savings"
        case .duplicates:
            return "\(viewModel.counts.duplicates) files • \(viewModel.megabytes.duplicates.formatAsFileSize()) redundant space"
        case .blurred:
            return "\(viewModel.counts.blurred) files • \(viewModel.megabytes.blurred.formatAsFileSize()) low-quality media"
        case .screenshots:
            return "\(viewModel.counts.screenshots) files • \(viewModel.megabytes.screenshots.formatAsFileSize()) temporary captures"
        case .videos:
            return "\(viewModel.counts.videos) files • \(viewModel.megabytes.videos.formatAsFileSize()) large media"
        }
    }
}
