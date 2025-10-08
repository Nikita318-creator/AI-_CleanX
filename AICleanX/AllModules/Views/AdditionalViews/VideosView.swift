import SwiftUI
import AVKit
import AVFoundation

struct VideosView: View {
    @State private var searchQuery: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @FocusState private var isSearchActive: Bool
    @State private var selectedVideo: SafeVideoData?
    @State private var showingVideoPicker = false
    @State private var isMultiSelectEnabled = false
    @State private var selectedItems: Set<UUID> = []
    @State private var previewCache: [UUID: Bool] = [:]
    
    // Organize videos by date
    private var organizedVideos: [VideoCollection] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        
        let collections = Dictionary(grouping: safeStorageManager.loadAllVideos()) { video in
            formatter.string(from: video.dateAdded)
        }
        
        return collections.map { key, items in
            VideoCollection(
                displayDate: key,
                originalDate: items.first?.dateAdded ?? Date(),
                items: items.sorted { $0.dateAdded > $1.dateAdded }
            )
        }.sorted { $0.originalDate > $1.originalDate }
    }
    
    private var searchResults: [VideoCollection] {
        if searchQuery.isEmpty {
            return organizedVideos
        } else {
            return organizedVideos.compactMap { collection in
                let matches = collection.items.filter { item in
                    item.fileName.lowercased().contains(searchQuery.lowercased())
                }
                return matches.isEmpty ? nil : VideoCollection(
                    displayDate: collection.displayDate,
                    originalDate: collection.originalDate,
                    items: matches
                )
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.height / 844
            
            VStack(spacing: 0) {
                // Navigation bar
                navigationBar(scale: scale)
                
                if safeStorageManager.videos.isEmpty {
                    // No content state
                    noContentView(scale: scale)
                } else {
                    // Main content
                    mainContent(scale: scale)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchActive = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(isPresented: $showingVideoPicker) {
            VideoPickerView { videoData, fileName, duration in
                let _ = safeStorageManager.saveVideo(videoData: videoData, fileName: fileName, duration: duration)
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerView(video: video)
        }
    }
    
    // MARK: - Navigation Bar
    private func navigationBar(scale: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18 * scale, weight: .semibold))
                        .foregroundColor(CMColor.accent)
                    
                    Text("Library")
                        .font(.system(size: 17 * scale, weight: .medium))
                        .foregroundColor(CMColor.accent)
                }
            }
            
            Spacer()
            
            Text("My Clips")
                .font(.system(size: 24 * scale, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                if isMultiSelectEnabled {
                    isMultiSelectEnabled = false
                    selectedItems.removeAll()
                } else {
                    isMultiSelectEnabled = true
                }
            }) {
                Text(isMultiSelectEnabled ? "Done" : "Manage")
                    .font(.system(size: 17 * scale, weight: .medium))
                    .foregroundColor(CMColor.secondary)
            }
        }
        .padding(.horizontal, 24 * scale)
        .padding(.top, 12 * scale)
        .padding(.bottom, 14 * scale)
        .background(CMColor.background)
    }
    
    // MARK: - No Content View
    private func noContentView(scale: CGFloat) -> some View {
        VStack(spacing: 28 * scale) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(CMColor.surface)
                    .frame(width: 140 * scale, height: 140 * scale)
                
                Image(systemName: "film.stack")
                    .font(.system(size: 56 * scale, weight: .light))
                    .foregroundColor(CMColor.iconSecondary)
            }
            
            VStack(spacing: 12 * scale) {
                Text("Your collection is empty")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Start building your video library")
                    .font(.system(size: 17 * scale))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scale)
            }
            
            Button(action: {
                showingVideoPicker = true
            }) {
                HStack(spacing: 10 * scale) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18 * scale, weight: .semibold))
                    
                    Text("Import Clip")
                        .font(.system(size: 18 * scale, weight: .bold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56 * scale)
                .background(
                    LinearGradient(
                        colors: [CMColor.secondary, CMColor.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(28 * scale)
                .shadow(color: CMColor.secondary.opacity(0.4), radius: 12 * scale, y: 6 * scale)
            }
            .padding(.horizontal, 48 * scale)
            .padding(.top, 8 * scale)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Main Content
    private func mainContent(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Search field
            searchField(scale: scale)
                .padding(.horizontal, 24 * scale)
                .padding(.top, 16 * scale)
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 32 * scale) {
                    ForEach(searchResults, id: \.displayDate) { collection in
                        collectionSection(collection: collection, scale: scale)
                    }
                    
                    Spacer(minLength: 100 * scale)
                }
                .padding(.horizontal, 24 * scale)
                .padding(.top, 24 * scale)
            }
            
            // Import button (fixed at bottom)
            if !isSearchActive {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(CMColor.border.opacity(0.5))
                        .frame(height: 1)
                    
                    Button(action: {
                        showingVideoPicker = true
                    }) {
                        HStack(spacing: 10 * scale) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18 * scale, weight: .semibold))
                            
                            Text("Import Clip")
                                .font(.system(size: 18 * scale, weight: .bold))
                        }
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56 * scale)
                        .background(
                            LinearGradient(
                                colors: [CMColor.secondary, CMColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28 * scale)
                        .shadow(color: CMColor.secondary.opacity(0.3), radius: 8 * scale, y: 4 * scale)
                    }
                    .padding(.horizontal, 24 * scale)
                    .padding(.vertical, 20 * scale)
                    .background(CMColor.background)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    // MARK: - Search Field
    private func searchField(scale: CGFloat) -> some View {
        HStack(spacing: 14 * scale) {
            HStack(spacing: 10 * scale) {
                TextField("Find clips...", text: $searchQuery)
                    .font(.system(size: 17 * scale))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isSearchActive)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchActive = false
                    }
                
                Spacer()
                
                if isSearchActive && !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.tertiaryText)
                            .font(.system(size: 18 * scale))
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.iconSecondary)
                        .font(.system(size: 18 * scale))
                }
            }
            .padding(.horizontal, 18 * scale)
            .padding(.vertical, 14 * scale)
            .background(CMColor.surface)
            .cornerRadius(16 * scale)
            .overlay(
                RoundedRectangle(cornerRadius: 16 * scale)
                    .stroke(isSearchActive ? CMColor.accent.opacity(0.5) : CMColor.border.opacity(0.3), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.25), value: isSearchActive)
        }
    }
    
    // MARK: - Collection Section
    private func collectionSection(collection: VideoCollection, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18 * scale) {
            Text(collection.displayDate)
                .font(.system(size: 19 * scale, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16 * scale),
                GridItem(.flexible(), spacing: 16 * scale)
            ], spacing: 16 * scale) {
                ForEach(collection.items) { item in
                    clipCard(item: item, scale: scale)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Clip Card
    private func clipCard(item: SafeVideoData, scale: CGFloat) -> some View {
        Button(action: {
            if isMultiSelectEnabled {
                if selectedItems.contains(item.id) {
                    selectedItems.remove(item.id)
                } else {
                    selectedItems.insert(item.id)
                }
            } else {
                selectedVideo = item
            }
        }) {
            VStack(spacing: 0) {
                ZStack {
                    VideoPreviewView(
                        videoURL: item.videoURL,
                        scalingFactor: scale,
                        isPlaying: !isMultiSelectEnabled && !isSearchActive,
                        videoId: item.id
                    )
                    .frame(height: 140 * scale)
                    .clipped()
                    .onAppear {
                        previewCache[item.id] = true
                    }
                    .onDisappear {
                        previewCache[item.id] = false
                    }
                    
                    if isMultiSelectEnabled {
                        Rectangle()
                            .fill(CMColor.black.opacity(0.4))
                            .frame(height: 140 * scale)
                            .overlay(
                                Circle()
                                    .fill(CMColor.black.opacity(0.7))
                                    .frame(width: 48 * scale, height: 48 * scale)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 20 * scale, weight: .semibold))
                                            .foregroundColor(CMColor.white)
                                            .offset(x: 2 * scale)
                                    )
                            )
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(item.durationFormatted)
                                .font(.system(size: 13 * scale, weight: .bold))
                                .foregroundColor(CMColor.white)
                                .padding(.horizontal, 8 * scale)
                                .padding(.vertical, 4 * scale)
                                .background(
                                    Capsule()
                                        .fill(CMColor.black.opacity(0.75))
                                )
                                .padding(.trailing, 10 * scale)
                                .padding(.bottom, 10 * scale)
                        }
                    }
                    
                    if isMultiSelectEnabled {
                        VStack {
                            HStack {
                                ZStack {
                                    Circle()
                                        .stroke(CMColor.white, lineWidth: 2.5)
                                        .frame(width: 28 * scale, height: 28 * scale)
                                        .background(
                                            Circle()
                                                .fill(selectedItems.contains(item.id) ? CMColor.accent : CMColor.clear)
                                        )
                                    
                                    if selectedItems.contains(item.id) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14 * scale, weight: .heavy))
                                            .foregroundColor(CMColor.white)
                                    }
                                }
                                .padding(.leading, 10 * scale)
                                .padding(.top, 10 * scale)
                                
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6 * scale) {
                    HStack {
                        Text(item.fileSizeFormatted)
                            .font(.system(size: 13 * scale, weight: .semibold))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 12 * scale)
                .padding(.vertical, 10 * scale)
                .background(CMColor.surface)
            }
        }
        .cornerRadius(14 * scale)
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale)
                .stroke(
                    isMultiSelectEnabled && selectedItems.contains(item.id) ? CMColor.accent : CMColor.border.opacity(0.2),
                    lineWidth: isMultiSelectEnabled && selectedItems.contains(item.id) ? 2.5 : 1
                )
        )
        .shadow(color: CMColor.black.opacity(0.08), radius: 8 * scale, x: 0, y: 4 * scale)
        .scaleEffect(isMultiSelectEnabled && selectedItems.contains(item.id) ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedItems.contains(item.id))
    }
}

// MARK: - Data Models
struct VideoCollection: Identifiable {
    let id = UUID()
    let displayDate: String
    let originalDate: Date
    let items: [SafeVideoData]
}

// MARK: - Video Picker
struct VideoPickerView: UIViewControllerRepresentable {
    let onVideoSelected: (Data, String, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoPickerView
        
        init(_ parent: VideoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    
                    let asset = AVAsset(url: url)
                    let duration = asset.duration.seconds
                    
                    parent.onVideoSelected(data, fileName, duration)
                } catch {
                    print("Error loading video data: \(error)")
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Video Preview
struct VideoPreviewView: UIViewRepresentable {
    let videoURL: URL
    let scalingFactor: CGFloat
    let isPlaying: Bool
    let videoId: UUID
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        
        player.isMuted = true
        player.automaticallyWaitsToMinimizeStalling = true
        
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem
        )
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
        
        if isPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.15...0.35)) {
                context.coordinator.player?.play()
            }
        } else {
            context.coordinator.player?.pause()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        
        @objc func playerDidFinishPlaying() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.player?.seek(to: .zero)
                if self?.player?.timeControlStatus != .playing {
                    self?.player?.play()
                }
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            player?.pause()
            player = nil
        }
    }
}

// MARK: - Video Player
struct VideoPlayerView: View {
    let video: SafeVideoData
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VideoPlayer(player: AVPlayer(url: video.videoURL))
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .principal) {
                        Text(video.fileName)
                            .font(.headline)
                    }
                }
        }
    }
}
