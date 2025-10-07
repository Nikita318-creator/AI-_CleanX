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
                            Text("IceClean")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(CMColor.primaryText)
                            
                            if viewModel.progress < 1 {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.8)
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
                        
                        Button(action: { showSettingsView = true }) {
                            ZStack {
                                Circle()
                                    .fill(CMColor.surface)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: CMColor.black.opacity(0.08), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(CMColor.iconSecondary)
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
                    
                    // Media Section
                    CategoryGroupView(
                        title: "Photos",
                        icon: "photo.stack",
                        categories: photoCategories,
                        viewModel: viewModel,
                        handleTap: handleTap,
                        generateEmptyStateImage: generateEmptyStateImage
                    )
                    
                    // Videos Section
                    CategoryGroupView(
                        title: "Videos",
                        icon: "video.circle",
                        categories: videoCategory,
                        viewModel: viewModel,
                        handleTap: handleTap,
                        generateEmptyStateImage: generateEmptyStateImage
                    )
                    
                    // System Section
                    CategoryGroupView(
                        title: "System",
                        icon: "slider.horizontal.3",
                        categories: utilityCategories,
                        viewModel: viewModel,
                        handleTap: handleTap,
                        generateEmptyStateImage: generateEmptyStateImage
                    )
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
    
    private func generateEmptyStateImage(systemName: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 52, weight: .regular, scale: .large)
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

// MARK: - Category Card View
struct CategoryCardView: View {
    let type: ScanItemType
    @ObservedObject var viewModel: MainViewModel
    let generateEmptyStateImage: (String, UIColor) -> UIImage?
    
    var body: some View {
        HStack(spacing: 14) {
            // Preview Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
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
                    .frame(width: 56, height: 56)
                
                if let image = getPreviewImage() {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: getIconName())
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(CMColor.primary.opacity(0.7))
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(type.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(getCompactCountText())
                    .font(.system(size: 14))
                    .foregroundColor(CMColor.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(CMColor.iconSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(CMColor.surface)
                .shadow(color: CMColor.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(CMColor.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
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
        switch type {
        case .contacts:
            return viewModel.contactsPermissionStatus == .authorized ?
                generateEmptyStateImage("person.2.fill", .primary) :
                generateEmptyStateImage("lock.fill", .warning)
        case .calendar:
            return viewModel.calendarPermissionStatus == .authorized ?
                generateEmptyStateImage("calendar", .secondary) :
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

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
