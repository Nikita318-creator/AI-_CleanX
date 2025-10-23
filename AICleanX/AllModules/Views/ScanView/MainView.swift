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

// =================================================================
// MARK: - MAIN VIEW
// =================================================================
struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedView: CategoryViewType?
    @State private var showSwipeModeView = false
    @State private var showPromotionAnimation: Bool = false

    init(isPaywallPresented: Binding<Bool>) {
        self._isPaywallPresented = isPaywallPresented
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
            CMColor.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Compact Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("IceClean AI")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if viewModel.progress < 1 {
                                HStack(spacing: 6) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Scanning \(Int(viewModel.progress * 100))%")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(CMColor.secondaryText)
                                }
                            } else {
                                Text(viewModel.subtitle)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                        
                        Spacer()
                        
                        // --- БЛОК С КНОПКОЙ И ТЕКСТОМ ПОДСВЕТКИ ---
                        HStack(spacing: 8) {
                            
                            // Текст "AI-smart-clean"
                            if showPromotionAnimation {
                                Text("AI-smart-clean")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(
                                        Capsule()
                                            .fill(CMColor.primary.opacity(0.1))
                                    )
                                    .transition(.opacity.combined(with: .slide))
                            }
                            
                            // Кнопка
                            Button(action: {
                                // 1. Сбрасываем анимацию перед открытием оверлея
                                showPromotionAnimation = false
                                // 2. Открываем оверлей
                                showSwipeModeView = true
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(CMColor.surface)
                                        .frame(width: 44, height: 44)
                                        .shadow(color: CMColor.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                    
                                    // АНИМИРОВАННЫЙ БОРДЕР (Пульсация)
                                    Circle()
                                        .stroke(CMColor.primary, lineWidth: 2)
                                        .frame(width: 50, height: 50)
                                        .opacity(showPromotionAnimation ? 1 : 0)
                                        .scaleEffect(showPromotionAnimation ? 1.2 : 1.0)
                                    // ВАЖНО: Анимация не повторяется бесконечно (нет .repeatForever)
                                        .animation(
                                            .easeInOut(duration: 1.5),
                                            value: showPromotionAnimation
                                        )
                                    
                                    Image(systemName: "star.square.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(CMColor.iconSecondary)
                                }
                            }
                        }
                        // --- КОНЕЦ БЛОКА С КНОПКОЙ И ТЕКСТОМ ПОДСВЕТКИ ---
                    }
                    .padding(.top, 12).padding(.horizontal, 20)
                    
                    // Media Section
                    CategoryGroupView(title: "Photos", icon: "photo.stack", categories: photoCategories, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                    CategoryGroupView(title: "Videos", icon: "video.circle", categories: videoCategory, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                    CategoryGroupView(title: "System", icon: "slider.horizontal.3", categories: utilityCategories, viewModel: viewModel, handleTap: handleTap, generateEmptyStateImage: generateEmptyStateImage)
                }
                .padding(.bottom, 100)
            }
            .onAppear {
                viewModel.onAppear()
                viewModel.scanContacts()
                viewModel.scanCalendar()
                
                // Запуск при появлении экрана (при запуске приложения)
                startPromotion()
            }

            .fullScreenCover(item: $presentedView) { viewType in
                switch viewType {
                case .contacts:
                    AICleanerContactsView()
                case .calendar:
                    AICalendarView()
                case .similarPhotos:
                    SimilaritySectionsView(viewModel: SimilaritySectionsViewModel(sections: viewModel.getSections(for: .image(.similar)), type: .similar))
                case .duplicates:
                    SimilaritySectionsView(viewModel: SimilaritySectionsViewModel(sections: viewModel.getSections(for: .image(.duplicates)), type: .duplicates))
                case .blurryPhotos:
                    SimilaritySectionsView(viewModel: SimilaritySectionsViewModel(sections: viewModel.getSections(for: .image(.blurred)), type: .blurred))
                case .screenshots:
                    SimilaritySectionsView(viewModel: SimilaritySectionsViewModel(sections: viewModel.getSections(for: .image(.screenshots)), type: .screenshots))
                case .videos:
                    SimilaritySectionsView(viewModel: SimilaritySectionsViewModel(sections: viewModel.getSections(for: .video), type: .videos))
                }
            }
            // ВАЖНОЕ ИСПРАВЛЕНИЕ БАГА: onDisappear для повторного запуска
            .fullScreenCover(isPresented: $showSwipeModeView) {
                AIFeatureView(isPaywallPresented: $isPaywallPresented, isSwipeModePresented: $showSwipeModeView )
                // При закрытии оверлея, принудительно запускаем анимацию снова.
                    .onDisappear {
                        startPromotion()
                    }
            }
        }
    }
    
    private func startPromotion() {
        // Запускаем только если она не активна, чтобы избежать конфликтов таймеров
        guard !showPromotionAnimation else { return }
        
        withAnimation {
            showPromotionAnimation = true
        }
        
        // Скрываем текст через 5 секунд, останавливая и пульсацию
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                showPromotionAnimation = false
            }
        }
    }
    
    private func generateEmptyStateImage(systemName: String, color: UIColor) -> UIImage? {
        // 1. Создаем базовую конфигурацию символа
        let config = UIImage.SymbolConfiguration(pointSize: 32, weight: .bold, scale: .large)
        
        // 2. Создаем конфигурацию цвета: Hierarchical
        let colorConfig = UIImage.SymbolConfiguration.preferringMulticolor()
        
        // 3. Объединяем конфигурации
        let finalConfig = config.applying(colorConfig)
        
        // 4. Создаем изображение с объединенной конфигурацией
        let image = UIImage(systemName: systemName, withConfiguration: finalConfig)
        
        // 5. Применяем цвет
        return image?.withTintColor(color)
    }
    
    private func handleTap(for type: ScanItemType) {
        // todo не нужен пейвол тут
//        if !viewModel.hasActiveSubscription {
//            AnalyticService.shared.logEvent(name: "present paywall from scanView", properties: ["":""])
//            isPaywallPresented = true
//            return
//        }
        
        AnalyticService.shared.logEvent(name: "handleTap on scanView", properties: ["type":"\(type.title)"])

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

// =================================================================
// MARK: - CATEGORY GROUP VIEW (Не изменялась, но включена для полноты контекста)
// =================================================================
struct CategoryGroupView: View {
    let title: String
    let icon: String
    let categories: [ScanItemType]
    @ObservedObject var viewModel: MainViewModel
    let handleTap: (ScanItemType) -> Void
    let generateEmptyStateImage: (String, UIColor) -> UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CMColor.primary)
                
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 10) {
                ForEach(categories, id: \.self) { type in
                    Button(action: {
                        handleTap(type)
                    }) {
                        // Использование обновленной CategoryCardView
                        CategoryCardView(
                            type: type,
                            viewModel: viewModel,
                            generateEmptyStateImage: generateEmptyStateImage
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// =================================================================
// MARK: - CATEGORY CARD VIEW (ОБНОВЛЕННЫЙ ВЕРТИКАЛЬНЫЙ ДИЗАЙН)
// =================================================================
struct CategoryCardView: View {
    let type: ScanItemType
    @ObservedObject var viewModel: MainViewModel
    let generateEmptyStateImage: (String, UIColor) -> UIImage?
    
    var body: some View {
        VStack(spacing: 12) { // Используем VStack для вертикального расположения элементов
            
            // 1. Preview Image Block (Top, Center Aligned)
            ZStack {
                RoundedRectangle(cornerRadius: 16) // Увеличенный CornerRadius
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                CMColor.primary.opacity(0.12),
                                CMColor.primary.opacity(0.06)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120) // Большая высота для вертикального дизайна
                
                // Content (Image or Icon)
                if let image = getPreviewImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit) // .fit для лучшего отображения иконок/заглушек
                        .frame(width: 80, height: 80) // Более крупное превью
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: getIconName())
                        .font(.system(size: 40, weight: .medium)) // Более крупная иконка
                        .foregroundColor(CMColor.primary.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            
            // 2. Content (Text)
            VStack(alignment: .center, spacing: 4) { // Центрируем текстовки
                Text(type.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(getCompactCountText())
                    .font(.system(size: 15))
                    .foregroundColor(CMColor.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity) // Растягиваем для центрирования
            .padding(.horizontal, 14)
            
            // 3. Chevron (Bottom Right)
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CMColor.iconSecondary)
                    .padding(.trailing, 14)
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity) // Занимаем всю ширину
        .padding(.top, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CMColor.surface)
                .shadow(color: CMColor.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(CMColor.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // --- Приватные функции, использующие внешние типы ---
    
    private func getIconName() -> String {
        switch type {
        case .contacts: return "person.2.fill"
        case .calendar: return "calendar"
        case .similar: return "photo.on.rectangle.angled"
        case .duplicates: return "square.on.square"
        case .blurred: return "camera.filters"
        case .screenshots: return "camera.viewfinder"
        case .videos: return "video.fill"
        }
    }
    
    private func getPreviewImage() -> UIImage? {
        // Мы предполагаем, что CMColor, UIImage, .primaryUIColor и .warningUIColor существуют
        // в вашем проекте, так как они используются в оригинальной функции generateEmptyStateImage.
        switch type {
        case .contacts:
            return viewModel.contactsPermissionStatus == .authorized ?
                generateEmptyStateImage("person.1.fill", .primary) :
                generateEmptyStateImage("lock.fill", .warning)
        case .calendar:
            return viewModel.calendarPermissionStatus == .authorized ?
                generateEmptyStateImage("calendar.fill", .primary) :
                generateEmptyStateImage("lock.fill", .warning)
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
    
    private func getCompactCountText() -> String {
        // Мы предполагаем, что extension Double.formatAsFileSize() существует в вашем проекте.
        switch type {
        case .contacts:
            switch viewModel.contactsPermissionStatus {
            case .authorized:
                return viewModel.isContactsLoading ? "Scanning..." :
                    (viewModel.contactsCount == 0 ? "All clean" : "\(viewModel.contactsCount) items")
            case .notDetermined: return "Tap to grant access"
            case .denied: return "Access denied"
            case .loading: return "Checking..."
            }
        case .calendar:
            switch viewModel.calendarPermissionStatus {
            case .authorized:
                return viewModel.isCalendarLoading ? "Scanning..." :
                    (viewModel.calendarEventsCount == 0 ? "All clean" : "\(viewModel.calendarEventsCount) events")
            case .notDetermined: return "Tap to grant access"
            case .denied: return "Access denied"
            case .loading: return "Checking..."
            }
        case .similar:
            return "\(viewModel.counts.similar) items • \(viewModel.megabytes.similar.formatAsFileSize())"
        case .duplicates:
            return "\(viewModel.counts.duplicates) items • \(viewModel.megabytes.duplicates.formatAsFileSize())"
        case .blurred:
            return "\(viewModel.counts.blurred) items • \(viewModel.megabytes.blurred.formatAsFileSize())"
        case .screenshots:
            return "\(viewModel.counts.screenshots) items • \(viewModel.megabytes.screenshots.formatAsFileSize())"
        case .videos:
            return "\(viewModel.counts.videos) items • \(viewModel.megabytes.videos.formatAsFileSize())"
        }
    }
}

// =================================================================
// MARK: - SCALE BUTTON STYLE (НОВАЯ/ВОССТАНОВЛЕННАЯ СТРУКТУРА)
// =================================================================
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
