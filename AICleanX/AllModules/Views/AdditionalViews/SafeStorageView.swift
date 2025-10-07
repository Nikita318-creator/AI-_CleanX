import SwiftUI

// =================================================================
// MARK: - SafeStorageCategoryCardView (НОВЫЙ ВЕРТИКАЛЬНЫЙ ДИЗАЙН)
// =================================================================
// Используем SafeStorageCategory вместо ScanItemType
struct SafeStorageCategoryCardView: View {
    let category: SafeStorageCategory
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. Preview/Icon Block (Top, Center Aligned)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            // Используем цвет категории с прозрачностью для фона
                            gradient: Gradient(colors: [
                                category.color.opacity(0.12),
                                category.color.opacity(0.06)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                
                // Content (Icon)
                Image(systemName: category.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(category.color.opacity(0.8)) // Иконка с цветом категории
            }
            .padding(.horizontal, 14)
            
            // 2. Content (Text)
            VStack(alignment: .center, spacing: 4) {
                Text(category.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(category.count)
                    .font(.system(size: 15))
                    .foregroundColor(CMColor.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
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
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(CMColor.surface)
                // Используем ту же тень, что и на MainView
                .shadow(color: CMColor.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
        .overlay(
            // Добавляем тонкий бордер
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(category.color.opacity(0.1), lineWidth: 1)
        )
    }
}


// =================================================================
// MARK: - SafeStorageView (ИЗМЕНЕННАЯ ВЕРСИЯ)
// =================================================================
struct SafeStorageView: View {
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    // Ожидаем, что эти объекты существуют в вашем проекте
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @FocusState private var isSearchFocused: Bool
    @State private var showPhotosView: Bool = false
    @State private var showVideosView: Bool = false
    @State private var showContactsView: Bool = false
    @State private var showDocumentsView: Bool = false
    @Binding var isPaywallPresented: Bool

    // НОВОЕ СОСТОЯНИЕ для отображения экрана смены пароля
    @State private var showChangePasscodeView: Bool = false

    // Simplified recent files logic
    private var recentFiles: [SafeStorageFile] {
        var files: [SafeStorageFile] = []
        
        // Add recent photos
        let recentPhotos = safeStorageManager.getRecentPhotos(limit: 2)
        files.append(contentsOf: recentPhotos.map { photo in
            SafeStorageFile(
                name: photo.fileName,
                icon: "photo.fill"
            )
        })
        
        return Array(files.prefix(5)) // Limit to 5 items max
    }
    
    // Dynamic categories based on storage counts
    private var categories: [SafeStorageCategory] {
        let photosCount = safeStorageManager.getPhotosCount()
        let documentsCount = safeStorageManager.getDocumentsCount()
        let videosCount = safeStorageManager.getVideosCount()
        let contactsCount = safeStorageManager.getContactsCount()
        
        return [
            SafeStorageCategory(
                title: "Docs",
                count: documentsCount == 0 ? "No files" : "\(documentsCount) \(documentsCount == 1 ? "file" : "files")",
                icon: "folder.fill",
                color: CMColor.accent
            ),
            SafeStorageCategory(
                title: "Photos",
                count: photosCount == 0 ? "No files" : "\(photosCount) \(photosCount == 1 ? "file" : "files")",
                icon: "photo.fill",
                color: CMColor.primaryLight
            ),
            SafeStorageCategory(
                title: "Videos",
                count: videosCount == 0 ? "No files" : "\(videosCount) \(videosCount == 1 ? "file" : "files")",
                icon: "video.fill",
                color: CMColor.secondary
            ),
            SafeStorageCategory(
                title: "Contacts",
                count: contactsCount == 0 ? "No items" : "\(contactsCount) \(contactsCount == 1 ? "item" : "items")",
                icon: "person.fill",
                color: CMColor.success
            )
        ]
    }
    
    private func getDocumentIcon(for fileExtension: String?) -> String {
        guard let ext = fileExtension?.lowercased() else { return "doc.fill" }
        
        switch ext {
        case "pdf":
            return "doc.fill"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx":
            return "tablecells.fill"
        case "ppt", "pptx":
            return "rectangle.fill.on.rectangle.fill"
        default:
            return "doc.fill"
        }
    }
    
    var body: some View {
        ZStack {
            // Gradient Background - New Design
            CMColor.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    headerView()
                    
                    // Search bar
                    searchBar()
                    
                    // Category cards
                    categoryCardsView() // ИЗМЕНЕННЫЙ ВЫЗОВ
                    
                    // Last added section
                    lastAddedSection()
                    
                    // Dynamic bottom spacing based on search state
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
        }
        .background(CMColor.background)
        .navigationBarHidden(true)
        .onTapGesture {
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Full screen covers... (оставляем без изменений)
        .fullScreenCover(isPresented: $showPhotosView) {
             // Предполагаем, что MainPhotosView, VideosView, AICleanerSafeContactsView, DocListView, PINView существуют
            MainPhotosView()
        }
        .fullScreenCover(isPresented: $showVideosView) {
            VideosView()
                .environmentObject(safeStorageManager)
        }
        .fullScreenCover(isPresented: $showContactsView) {
            AICleanerSafeContactsView()
        }
        .fullScreenCover(isPresented: $showDocumentsView) {
            DocListView()
                .environmentObject(safeStorageManager)
        }
        // НОВЫЙ fullScreenCover для смены пароля
        .fullScreenCover(isPresented: $showChangePasscodeView) {
            PINView(
                onTabBarVisibilityChange: { _ in },
                onCodeEntered: { code in
                    print("New passcode saved: \(code)")
                },
                onBackButtonTapped: {
                    showChangePasscodeView = false
                },
                shouldAutoDismiss: true,
                isChangingPasscode: true
            )
        }
    }
    
    // MARK: - Subviews
    
    private func headerView() -> some View {
        HStack {
            Text("Safe Storage")
                .font(.largeTitle.bold())
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            // НОВАЯ КНОПКА
            Button {
                showChangePasscodeView = true
            } label: {
                Text("Change\nPasscode")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CMColor.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CMColor.primary, lineWidth: 1.5)
                    )
            }
        }
    }
    
    private func searchBar() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CMColor.iconSecondary)
                
            TextField("Search your files...", text: $searchText)
                .foregroundColor(CMColor.primaryText)
                .accentColor(CMColor.accent)
                .font(.body)
                .focused($isSearchFocused)
                
            if isSearchFocused && !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(CMColor.iconSecondary)
                }
            }
        }
        .padding(12)
        .background(CMColor.surface)
        .cornerRadius(12)
        .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
    }
    
    // ИЗМЕНЕННЫЙ categoryCardsView
    private func categoryCardsView() -> some View {
        // Используем LazyVGrid для двух колонок с вертикальными карточками
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(categories) { category in
                Button(action: {
                    // Обработка нажатия
                    if category.title == "Docs" {
                        showDocumentsView = true
                    } else if category.title == "Photos" {
                        showPhotosView = true
                    } else if category.title == "Videos" {
                        showVideosView = true
                    } else if category.title == "Contacts" {
                        showContactsView = true
                    }
                }) {
                    SafeStorageCategoryCardView(category: category)
                }
                .buttonStyle(ScaleButtonStyle()) // Применяем ScaleButtonStyle
            }
        }
    }
    
    private func lastAddedSection() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recently Added")
                    .font(.title2.bold())
                    .foregroundColor(CMColor.primaryText)
                Spacer()
            }
                
            if recentFiles.isEmpty {
                Text("No recent files")
                    .foregroundColor(CMColor.secondaryText)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    .background(CMColor.surface)
                    .cornerRadius(16)
                    .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentFiles.enumerated()), id: \.offset) { index, file in
                        fileRow(file: file)
                            
                        if index < recentFiles.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(CMColor.surface)
                .cornerRadius(16)
                .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
            }
        }
    }
    
    private func fileRow(file: SafeStorageFile) -> some View {
        HStack(spacing: 16) {
            Image(systemName: file.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(CMColor.iconSecondary)
                .frame(width: 36, height: 36)
                .background(CMColor.backgroundSecondary)
                .cornerRadius(10)
                
            Text(file.name)
                .font(.body)
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                
            Spacer()
                
            Image(systemName: "chevron.right")
                .foregroundColor(CMColor.iconSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
}
