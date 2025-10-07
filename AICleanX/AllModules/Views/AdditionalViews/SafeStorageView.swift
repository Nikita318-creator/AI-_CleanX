import SwiftUI

struct SafeStorageView: View {
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
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
                // Использование CMColor.accent (например, вместо Color.purple)
                color: CMColor.accent
            ),
            SafeStorageCategory(
                title: "Photos",
                count: photosCount == 0 ? "No files" : "\(photosCount) \(photosCount == 1 ? "file" : "files")",
                icon: "photo.fill",
                // Использование CMColor.primaryLight (например, вместо Color.pink)
                color: CMColor.primaryLight
            ),
            SafeStorageCategory(
                title: "Videos",
                count: videosCount == 0 ? "No files" : "\(videosCount) \(videosCount == 1 ? "file" : "files")",
                icon: "video.fill",
                // Использование CMColor.secondary (например, вместо Color.blue)
                color: CMColor.secondary
            ),
            SafeStorageCategory(
                title: "Contacts",
                count: contactsCount == 0 ? "No items" : "\(contactsCount) \(contactsCount == 1 ? "item" : "items")",
                icon: "person.fill",
                // Использование CMColor.success (например, вместо Color.green)
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
            // Использование CMColor.backgroundGradient вместо [Color.gray.opacity(0.1), Color.white]
            CMColor.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    headerView()
                    
                    // Search bar
                    searchBar()
                    
                    // Category cards
                    categoryCardsView()
                    
                    // Last added section
                    lastAddedSection()
                    
                    // Dynamic bottom spacing based on search state
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        // Задний фон, который виден, если ScrollView не полностью занимает экран
        // Использование CMColor.background вместо Color(UIColor.systemGray6)
        .background(CMColor.background)
        .navigationBarHidden(true)
        .onTapGesture {
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showPhotosView) {
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
                    // Здесь вы, вероятно, должны вызвать метод сохранения кода
                },
                onBackButtonTapped: {
                    showChangePasscodeView = false
                },
                shouldAutoDismiss: true,
                isChangingPasscode: true // Флаг, указывающий, что это режим смены
            )
        }
    }
    
    // MARK: - Subviews
    
    private func headerView() -> some View {
        HStack {
            Text("Safe Storage")
                .font(.largeTitle.bold())
                // Использование CMColor.primaryText вместо .black
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
    
    // ... (остальные subviews без изменений)
    
    private func searchBar() -> some View {
        // ... (код без изменений)
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                // Использование CMColor.iconSecondary вместо .gray
                .foregroundColor(CMColor.iconSecondary)
                
            TextField("Search your files...", text: $searchText)
                // Использование CMColor.primaryText вместо .black
                .foregroundColor(CMColor.primaryText)
                // Использование CMColor.accent для акцентного цвета (каретки) вместо .gray
                .accentColor(CMColor.accent)
                .font(.body)
                .focused($isSearchFocused)
                
            if isSearchFocused && !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        // Использование CMColor.iconSecondary вместо .gray
                        .foregroundColor(CMColor.iconSecondary)
                }
            }
        }
        .padding(12)
        // Использование CMColor.surface вместо Color.white
        .background(CMColor.surface)
        .cornerRadius(12)
        // Тень остается, используя CMColor.black для лучшего контроля, если бы он был
        .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
    }
    
    private func categoryCardsView() -> some View {
        // ... (код без изменений)
        VStack(spacing: 16) {
            ForEach(categories) { category in
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(category.color) // Использование кастомного цвета категории
                        .frame(width: 48, height: 48)
                        // Использование CMColor.backgroundSecondary вместо category.color.opacity(0.1)
                        .background(CMColor.backgroundSecondary)
                        .cornerRadius(12)
                        
                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.title)
                            .font(.headline.bold())
                            // Использование CMColor.primaryText вместо .black
                            .foregroundColor(CMColor.primaryText)
                            
                        Text(category.count)
                            .font(.subheadline)
                            // Использование CMColor.secondaryText вместо .gray
                            .foregroundColor(CMColor.secondaryText)
                    }
                        
                    Spacer() // Pushes the content to the left
                        
                    // Chevron icon
                    Image(systemName: "chevron.right")
                        // Использование CMColor.iconSecondary вместо .gray
                        .foregroundColor(CMColor.iconSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Использование CMColor.surface вместо Color.white
                .background(CMColor.surface)
                .cornerRadius(16)
                // Тень остается
                .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
                .onTapGesture {
                    if category.title == "Docs" {
                        showDocumentsView = true
                    } else if category.title == "Photos" {
                        showPhotosView = true
                    } else if category.title == "Videos" {
                        showVideosView = true
                    } else if category.title == "Contacts" {
                        showContactsView = true
                    }
                }
            }
        }
    }
    
    private func lastAddedSection() -> some View {
        // ... (код без изменений)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Last Added")
                    .font(.title2.bold())
                    // Использование CMColor.primaryText вместо .black
                    .foregroundColor(CMColor.primaryText)
                Spacer()
            }
                
            if recentFiles.isEmpty {
                Text("No recent files added.")
                    // Использование CMColor.secondaryText вместо .gray
                    .foregroundColor(CMColor.secondaryText)
                    .padding(.vertical, 30)
                    .frame(maxWidth: .infinity)
                    // Использование CMColor.surface вместо Color.white
                    .background(CMColor.surface)
                    .cornerRadius(16)
                    // Тень остается
                    .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentFiles.enumerated()), id: \.offset) { index, file in
                        fileRow(file: file)
                            
                        if index < recentFiles.count - 1 {
                            // Divider, по умолчанию серый, но можно не менять, если он устраивает
                            Divider()
                        }
                    }
                }
                // Использование CMColor.surface вместо Color.white
                .background(CMColor.surface)
                .cornerRadius(16)
                // Тень остается
                .shadow(color: CMColor.black.opacity(0.05), radius: 5, x: 0, y: 5)
            }
        }
    }
    
    private func fileRow(file: SafeStorageFile) -> some View {
        // ... (код без изменений)
        HStack(spacing: 16) {
            Image(systemName: file.icon)
                .font(.system(size: 20, weight: .medium))
                // Использование CMColor.iconSecondary вместо .gray
                .foregroundColor(CMColor.iconSecondary)
                .frame(width: 36, height: 36)
                // Использование CMColor.backgroundSecondary вместо Color(UIColor.systemGray6)
                .background(CMColor.backgroundSecondary)
                .cornerRadius(10)
                
            Text(file.name)
                .font(.body)
                // Использование CMColor.primaryText вместо .black
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                
            Spacer()
                
            Image(systemName: "chevron.right")
                // Использование CMColor.iconSecondary вместо .gray
                .foregroundColor(CMColor.iconSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
    }
}
