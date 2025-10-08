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
        .background(Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: itemsToImport) { newItems in
            startImageImportProcess(from: newItems)
        }
        .confirmationDialog("Remove Images", isPresented: $isShowingDeleteDialog) {
            Button("Remove \(currentSelectionIDs.count) Items", role: .destructive) {
                executeDeletion()
            }
            Button("Keep Them", role: .cancel) { }
        } message: {
            Text("You're about to remove \(currentSelectionIDs.count) images from your gallery. This can't be reversed.")
        }
    }
    
    // MARK: - Navigation Bar
    private func buildNavigationView(scaleRatio: CGFloat) -> some View {
        ZStack {
            HStack {
                Button(action: {
                    flowDismissal()
                }) {
                    HStack(spacing: 6 * scaleRatio) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                        Text("Gallery")
                            .font(.system(size: 15 * scaleRatio, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.2, green: 0.47, blue: 0.95))
                }
                
                Spacer()
            }
            
            HStack {
                Spacer()
                Text("Image Library")
                    .font(.system(size: 18 * scaleRatio, weight: .bold))
                    .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                Spacer()
            }
            
            HStack {
                Spacer()
                
                if !fetchedMediaData.isEmpty {
                    Button(action: {
                        isSelectionActive.toggle()
                        if !isSelectionActive {
                            currentSelectionIDs.removeAll()
                        }
                    }) {
                        Text(isSelectionActive ? "Done" : "Edit")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.47, blue: 0.95))
                            .padding(.horizontal, 14 * scaleRatio)
                            .padding(.vertical, 7 * scaleRatio)
                            .background(
                                RoundedRectangle(cornerRadius: 8 * scaleRatio)
                                    .fill(Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.1))
                            )
                    }
                }
            }
        }
        .padding(.horizontal, 18 * scaleRatio)
        .padding(.vertical, 14 * scaleRatio)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }
    
    // MARK: - Empty State
    private func buildEmptyStateView(scaleRatio: CGFloat) -> some View {
        VStack(spacing: 28 * scaleRatio) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 32 * scaleRatio)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.15),
                                Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140 * scaleRatio, height: 140 * scaleRatio)
                
                Image(systemName: "photo.stack")
                    .font(.system(size: 52 * scaleRatio, weight: .light))
                    .foregroundColor(Color(red: 0.3, green: 0.5, blue: 0.9))
            }
            
            VStack(spacing: 10 * scaleRatio) {
                Text("Your gallery is empty")
                    .font(.system(size: 22 * scaleRatio, weight: .bold))
                    .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                
                Text("Start building your collection by importing your first image")
                    .font(.system(size: 15 * scaleRatio))
                    .foregroundColor(Color(red: 0.46, green: 0.47, blue: 0.49))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20 * scaleRatio)
            }
            
            PhotosPicker(selection: $itemsToImport, maxSelectionCount: 10, matching: .images) {
                HStack(spacing: 10 * scaleRatio) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15 * scaleRatio, weight: .semibold))
                    
                    Text("Import Images")
                        .font(.system(size: 16 * scaleRatio, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 220 * scaleRatio, height: 54 * scaleRatio)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.47, blue: 0.95),
                            Color(red: 0.15, green: 0.38, blue: 0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(27 * scaleRatio)
                .shadow(color: Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.3), radius: 8, y: 4)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func buildContentDisplay(scaleRatio: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20 * scaleRatio) {
                createSearchInput(scaleRatio: scaleRatio)
                
                if !isSearchFieldFocused || !inputSearchText.isEmpty {
                    generatePhotoSections(scaleRatio: scaleRatio)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    generateActionButtons(scaleRatio: scaleRatio)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer(minLength: isSearchFieldFocused ? 180 * scaleRatio : 80 * scaleRatio)
            }
            .padding(.horizontal, 18 * scaleRatio)
            .padding(.top, 16 * scaleRatio)
            .animation(.easeInOut(duration: 0.3), value: isSearchFieldFocused)
        }
    }
    
    private func createSearchInput(scaleRatio: CGFloat) -> some View {
        HStack(spacing: 10 * scaleRatio) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(red: 0.58, green: 0.59, blue: 0.61))
                .font(.system(size: 15 * scaleRatio))
            
            TextField("Find in library", text: $inputSearchText)
                .font(.system(size: 15 * scaleRatio))
                .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .onSubmit {
                    isSearchFieldFocused = false
                }
            
            if isSearchFieldFocused && !inputSearchText.isEmpty {
                Button(action: {
                    inputSearchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(red: 0.58, green: 0.59, blue: 0.61))
                        .font(.system(size: 15 * scaleRatio))
                }
            }
        }
        .padding(.horizontal, 14 * scaleRatio)
        .padding(.vertical, 11 * scaleRatio)
        .background(Color.white)
        .cornerRadius(10 * scaleRatio)
        .overlay(
            RoundedRectangle(cornerRadius: 10 * scaleRatio)
                .stroke(
                    isSearchFieldFocused ?
                    Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.4) :
                    Color(red: 0.89, green: 0.89, blue: 0.91),
                    lineWidth: 1.5
                )
        )
        .shadow(color: isSearchFieldFocused ? Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.1) : Color.clear, radius: 4)
        .animation(.easeInOut(duration: 0.2), value: isSearchFieldFocused)
    }
    
    private func generatePhotoSections(scaleRatio: CGFloat) -> some View {
        let groupedPhotos = Dictionary(grouping: fetchedMediaData) { photo in
            formatPhotoTimestamp(photo.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 20 * scaleRatio) {
            ForEach(groupedPhotos.keys.sorted(by: { first, second in
                if first == "Today" { return true }
                if second == "Today" { return false }
                return first < second
            }), id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 14 * scaleRatio) {
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.2, green: 0.47, blue: 0.95))
                            .frame(width: 3 * scaleRatio, height: 18 * scaleRatio)
                        
                        Text(dateKey)
                            .font(.system(size: 17 * scaleRatio, weight: .bold))
                            .foregroundColor(Color(red: 0.11, green: 0.11, blue: 0.12))
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10 * scaleRatio), count: 3), spacing: 10 * scaleRatio) {
                        ForEach(groupedPhotos[dateKey] ?? []) { photo in
                            createPhotoCell(photo: photo, scaleRatio: scaleRatio)
                        }
                    }
                }
            }
        }
    }
    
    private func createPhotoCell(photo: SafePhotoData, scaleRatio: CGFloat) -> some View {
        let cellDimension = (UIScreen.main.bounds.width - 56 * scaleRatio) / 3

        return NavigationLink(destination: PhotoDetailView(photo: photo)) {
            ZStack {
                if let uiImage = photo.fullImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: cellDimension, height: cellDimension)
                        .clipped()
                        .cornerRadius(10 * scaleRatio)
                } else {
                    RoundedRectangle(cornerRadius: 10 * scaleRatio)
                        .fill(Color(red: 0.94, green: 0.94, blue: 0.96))
                        .frame(width: cellDimension, height: cellDimension)
                        .overlay(
                            Image(systemName: "photo.fill")
                                .font(.system(size: 26 * scaleRatio))
                                .foregroundColor(Color(red: 0.78, green: 0.78, blue: 0.8))
                        )
                }
                
                if isSelectionActive {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                if currentSelectionIDs.contains(photo.id) {
                                    currentSelectionIDs.remove(photo.id)
                                } else {
                                    currentSelectionIDs.insert(photo.id)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            currentSelectionIDs.contains(photo.id) ?
                                            Color(red: 0.2, green: 0.47, blue: 0.95) :
                                            Color.white.opacity(0.9)
                                        )
                                        .frame(width: 26 * scaleRatio, height: 26 * scaleRatio)
                                        .shadow(color: Color.black.opacity(0.15), radius: 2)
                                    
                                    if currentSelectionIDs.contains(photo.id) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12 * scaleRatio, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .contentShape(Circle())
                            .padding(6 * scaleRatio)
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
                HStack(spacing: 10 * scaleRatio) {
                    ProgressView()
                        .scaleEffect(0.85)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Processing...")
                        .font(.system(size: 15 * scaleRatio, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54 * scaleRatio)
                .background(Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.6))
                .cornerRadius(12 * scaleRatio)
            } else {
                PhotosPicker(selection: $itemsToImport, maxSelectionCount: 10, matching: .images) {
                    HStack(spacing: 8 * scaleRatio) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                        
                        Text("Import More")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54 * scaleRatio)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.47, blue: 0.95),
                                Color(red: 0.15, green: 0.38, blue: 0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12 * scaleRatio)
                    .shadow(color: Color(red: 0.2, green: 0.47, blue: 0.95).opacity(0.25), radius: 6, y: 3)
                }
                .disabled(isProcessingImages)
            }
            
            if isSelectionActive && !currentSelectionIDs.isEmpty {
                Button(action: {
                    isShowingDeleteDialog = true
                }) {
                    HStack(spacing: 8 * scaleRatio) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                        
                        Text("Remove (\(currentSelectionIDs.count))")
                            .font(.system(size: 15 * scaleRatio, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54 * scaleRatio)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.27, blue: 0.29),
                                Color(red: 0.85, green: 0.2, blue: 0.22)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12 * scaleRatio)
                    .shadow(color: Color(red: 0.95, green: 0.27, blue: 0.29).opacity(0.25), radius: 6, y: 3)
                }
                .disabled(isProcessingImages)
            }
        }
        .padding(.top, 16 * scaleRatio)
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
