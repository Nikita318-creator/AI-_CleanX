import SwiftUI
import PhotosUI

@available(iOS 16.0, *)
struct PhotosView: View {
    @Environment(\.dismiss) private var flowDismissal
    @EnvironmentObject private var dataVaultManager: SafeStorageManager
    
    @State private var inputSearchText: String = ""
    @State private var isSelectionActive: Bool = false
    @State private var currentSelectionIDs: Set<UUID> = []
    @FocusState private var isSearchFieldFocused: Bool
    @State private var itemsToImport: [PhotosPickerItem] = []
    @State private var isProcessingImages: Bool = false
    @State private var isShowingDeleteDialog: Bool = false
    
    private var fetchedMediaData: [SafePhotoData] {
        dataVaultManager.loadAllPhotos()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scaleRatio = geometry.size.height / 844
            
            VStack(spacing: 0) {
                buildNavigationView(scaleRatio: scaleRatio)
                
                if fetchedMediaData.isEmpty {
                    buildEmptyStateView(scaleRatio: scaleRatio)
                } else {
                    buildContentDisplay(scaleRatio: scaleRatio)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isSearchFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: itemsToImport) { newItems in
            startImageImportProcess(from: newItems)
        }
        .confirmationDialog("Delete Photos", isPresented: $isShowingDeleteDialog) {
            Button("Delete \(currentSelectionIDs.count) Photos", role: .destructive) {
                executeDeletion()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(currentSelectionIDs.count) selected photos? This action cannot be undone.")
        }
    }
    
    // MARK: - Navigation Bar
    private func buildNavigationView(scaleRatio: CGFloat) -> some View {
        HStack {
            Button(action: {
                flowDismissal()
            }) {
                HStack(spacing: 4 * scaleRatio) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scaleRatio, weight: .medium))
                    Text("Media")
                        .font(.system(size: 16 * scaleRatio))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Photos")
                .font(.system(size: 17 * scaleRatio, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !fetchedMediaData.isEmpty {
                Button(action: {
                    isSelectionActive.toggle()
                    if !isSelectionActive {
                        currentSelectionIDs.removeAll()
                    }
                }) {
                    HStack(spacing: 4 * scaleRatio) {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 6 * scaleRatio, height: 6 * scaleRatio)
                        Text(isSelectionActive ? "Cancel" : "Select")
                            .font(.system(size: 16 * scaleRatio))
                            .foregroundColor(CMColor.primary)
                    }
                }
            } else {
                Spacer().frame(width: 60 * scaleRatio)
            }
        }
        .padding(.horizontal, 16 * scaleRatio)
        .padding(.vertical, 12 * scaleRatio)
    }
    
    // MARK: - Empty State
    private func buildEmptyStateView(scaleRatio: CGFloat) -> some View {
        VStack(spacing: 24 * scaleRatio) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scaleRatio, height: 120 * scaleRatio)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 48 * scaleRatio))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scaleRatio) {
                Text("No photos yet")
                    .font(.system(size: 20 * scaleRatio, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first photo to get started")
                    .font(.system(size: 16 * scaleRatio))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            PhotosPicker(selection: $itemsToImport, maxSelectionCount: 10, matching: .images) {
                HStack(spacing: 8 * scaleRatio) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scaleRatio, weight: .medium))
                    
                    Text("Add photo")
                        .font(.system(size: 16 * scaleRatio, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scaleRatio)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scaleRatio)
            }
            .padding(.horizontal, 40 * scaleRatio)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func buildContentDisplay(scaleRatio: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24 * scaleRatio) {
                // В оригинале здесь был searchBar, оставляем его, но убираем фильтрацию
                createSearchInput(scaleRatio: scaleRatio)
                
                if !isSearchFieldFocused || !inputSearchText.isEmpty {
                    // Используем исходную логику (без фильтрации, как в оригинале)
                    generatePhotoSections(scaleRatio: scaleRatio)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    generateActionButtons(scaleRatio: scaleRatio)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer(minLength: isSearchFieldFocused ? 200 * scaleRatio : 100 * scaleRatio)
            }
            .padding(.horizontal, 16 * scaleRatio)
            .padding(.top, 20 * scaleRatio)
            .animation(.easeInOut(duration: 0.3), value: isSearchFieldFocused)
        }
    }
    
    private func createSearchInput(scaleRatio: CGFloat) -> some View {
        HStack(spacing: 12 * scaleRatio) {
            HStack(spacing: 8 * scaleRatio) {
                TextField("Search", text: $inputSearchText)
                    .font(.system(size: 16 * scaleRatio))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFieldFocused = false
                    }
                
                Spacer()
                
                if isSearchFieldFocused && !inputSearchText.isEmpty {
                    Button(action: {
                        inputSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                            .font(.system(size: 16 * scaleRatio))
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.secondaryText)
                        .font(.system(size: 16 * scaleRatio))
                }
            }
            .padding(.horizontal, 16 * scaleRatio)
            .padding(.vertical, 12 * scaleRatio)
            .background(CMColor.surface)
            .cornerRadius(12 * scaleRatio)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scaleRatio)
                    .stroke(isSearchFieldFocused ? CMColor.primary.opacity(0.3) : CMColor.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
        }
    }
    
    private func generatePhotoSections(scaleRatio: CGFloat) -> some View {
        let groupedPhotos = Dictionary(grouping: fetchedMediaData) { photo in
            formatPhotoTimestamp(photo.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 16 * scaleRatio) {
            ForEach(groupedPhotos.keys.sorted(by: { first, second in
                if first == "Today" { return true }
                if second == "Today" { return false }
                return first < second
            }), id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 12 * scaleRatio) {
                    Text(dateKey)
                        .font(.system(size: 18 * scaleRatio, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8 * scaleRatio), count: 3), spacing: 8 * scaleRatio) {
                        ForEach(groupedPhotos[dateKey] ?? []) { photo in
                            createPhotoCell(photo: photo, scaleRatio: scaleRatio)
                        }
                    }
                }
            }
        }
    }
    
    private func createPhotoCell(photo: SafePhotoData, scaleRatio: CGFloat) -> some View {
        let cellDimension = (UIScreen.main.bounds.width - 48 * scaleRatio) / 3

        return NavigationLink(destination: PhotoDetailView(photo: photo)) {
            ZStack {
                // Photo Content
                if let uiImage = photo.fullImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cellDimension, height: cellDimension)
                        .clipped()
                        .cornerRadius(12 * scaleRatio)
                } else {
                    Rectangle()
                        .fill(CMColor.secondaryText.opacity(0.3))
                        .frame(width: cellDimension, height: cellDimension)
                        .cornerRadius(12 * scaleRatio)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24 * scaleRatio))
                                .foregroundColor(CMColor.secondaryText)
                        )
                }
                
                // Selection Overlay (Кнопка выделения)
                if isSelectionActive {
                    VStack {
                        HStack {
                            Spacer()
                            // ВАЖНО: Мы используем Button, чтобы перехватить тап
                            Button(action: {
                                // Логика выделения
                                if currentSelectionIDs.contains(photo.id) {
                                    currentSelectionIDs.remove(photo.id)
                                } else {
                                    currentSelectionIDs.insert(photo.id)
                                }
                            }) {
                                Image(systemName: currentSelectionIDs.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20 * scaleRatio))
                                    .foregroundColor(currentSelectionIDs.contains(photo.id) ? .white : .white.opacity(0.7))
                                    .background(
                                        Circle()
                                            .fill(currentSelectionIDs.contains(photo.id) ? CMColor.primary : Color.black.opacity(0.3))
                                            .frame(width: 24 * scaleRatio, height: 24 * scaleRatio)
                                    )
                            }
                            // Модификатор, который не позволит NavigationLink сработать от тапа по кнопке
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Circle())
                            .padding(8 * scaleRatio)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func generateActionButtons(scaleRatio: CGFloat) -> some View {
        VStack(spacing: 12 * scaleRatio) {
            if isProcessingImages {
                HStack(spacing: 8 * scaleRatio) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Adding images...")
                        .font(.system(size: 16 * scaleRatio, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scaleRatio)
                .background(CMColor.primary.opacity(0.7))
                .cornerRadius(16 * scaleRatio)
            } else {
                PhotosPicker(selection: $itemsToImport, maxSelectionCount: 10, matching: .images) {
                    Text("Add image")
                        .font(.system(size: 16 * scaleRatio, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52 * scaleRatio)
                        .background(CMColor.primary)
                        .cornerRadius(16 * scaleRatio)
                }
                .disabled(isProcessingImages)
            }
            
            if isSelectionActive && !currentSelectionIDs.isEmpty {
                Button(action: {
                    isShowingDeleteDialog = true
                }) {
                    HStack(spacing: 8 * scaleRatio) {
                        Image(systemName: "trash")
                            .font(.system(size: 16 * scaleRatio, weight: .medium))
                        
                        Text("Delete Selected (\(currentSelectionIDs.count))")
                            .font(.system(size: 16 * scaleRatio, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scaleRatio)
                    .background(Color.red)
                    .cornerRadius(16 * scaleRatio)
                }
                .disabled(isProcessingImages)
            }
        }
        .padding(.top, 20 * scaleRatio)
        .animation(.easeInOut(duration: 0.2), value: isProcessingImages)
    }
        
    private func formatPhotoTimestamp(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            dateFormatter.dateFormat = "d MMM yyyy"
            return dateFormatter.string(from: date)
        }
    }
    
    private func startImageImportProcess(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        isProcessingImages = true
        
        Task {
            defer {
                DispatchQueue.main.async {
                    self.isProcessingImages = false
                    self.itemsToImport.removeAll()
                }
            }
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let _ = await self.dataVaultManager.savePhotoAsync(imageData: data)
                    
                    await MainActor.run {
                        self.dataVaultManager.objectWillChange.send()
                    }
                }
            }
        }
    }
    
    private func executeDeletion() {
        let itemsForDeletion = fetchedMediaData.filter { photo in
            currentSelectionIDs.contains(photo.id)
        }
        
        dataVaultManager.deletePhotos(itemsForDeletion)
        currentSelectionIDs.removeAll()
        isSelectionActive = false
    }
}
