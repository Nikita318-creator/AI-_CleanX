import SwiftUI
import AVKit
import AVFoundation

struct VideosView: View {
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @FocusState private var isSearchFocused: Bool
    @State private var selectedVideo: SafeVideoData?
    @State private var showingVideoPicker = false
    @State private var isSelectionMode = false
    @State private var selectedVideos: Set<UUID> = []
    @State private var videoPreviewStates: [UUID: Bool] = [:]
    
    // Group videos by date
    private var groupedVideos: [VideoDateGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        
        let groups = Dictionary(grouping: safeStorageManager.loadAllVideos()) { video in
            formatter.string(from: video.dateAdded)
        }
        
        return groups.map { key, videos in
            VideoDateGroup(
                dateString: key,
                date: videos.first?.dateAdded ?? Date(),
                videos: videos.sorted { $0.dateAdded > $1.dateAdded }
            )
        }.sorted { $0.date > $1.date }
    }
    
    private var filteredGroups: [VideoDateGroup] {
        if searchText.isEmpty {
            return groupedVideos
        } else {
            return groupedVideos.compactMap { group in
                let filteredVideos = group.videos.filter { video in
                    video.fileName.lowercased().contains(searchText.lowercased())
                }
                return filteredVideos.isEmpty ? nil : VideoDateGroup(
                    dateString: group.dateString,
                    date: group.date,
                    videos: filteredVideos
                )
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            VStack(spacing: 0) {
                // Header
                headerView(scalingFactor: scalingFactor)
                
                if safeStorageManager.videos.isEmpty {
                    // Empty state
                    emptyStateView(scalingFactor: scalingFactor)
                } else {
                    // Video content
                    videoContentView(scalingFactor: scalingFactor)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            isSearchFocused = false
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
    
    // MARK: - Header
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Media")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            Text("Video")
                .font(.system(size: 22 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                if isSelectionMode {
                    // Exit selection mode
                    isSelectionMode = false
                    selectedVideos.removeAll()
                } else {
                    // Enter selection mode
                    isSelectionMode = true
                }
            }) {
                Text(isSelectionMode ? "Cancel" : "Select")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 10 * scalingFactor)
        .padding(.bottom, 10 * scalingFactor)
        .background(CMColor.background)
    }
    
    // MARK: - Empty State
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            // Empty state icon
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scalingFactor, height: 120 * scalingFactor)
                
                Image(systemName: "video.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No videos yet")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first video to get started")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Add video button
            Button(action: {
                showingVideoPicker = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Add video")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scalingFactor)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scalingFactor)
            }
            .padding(.horizontal, 40 * scalingFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Video Content
    private func videoContentView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar(scalingFactor: scalingFactor)
                .padding(.horizontal, 20 * scalingFactor)
                .padding(.top, 20 * scalingFactor)
            
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 24 * scalingFactor) {
                    ForEach(filteredGroups, id: \.dateString) { group in
                        videoDateSection(group: group, scalingFactor: scalingFactor)
                    }
                    
                    // Bottom spacing for fixed button
                    Spacer(minLength: 80 * scalingFactor)
                }
                .padding(.horizontal, 20 * scalingFactor)
                .padding(.top, 20 * scalingFactor)
            }
            
            // Fixed bottom Add Video Button
            if !isSearchFocused {
                VStack(spacing: 0) {
                    Divider()
                        .background(CMColor.border)
                    
                    Button(action: {
                        showingVideoPicker = true
                    }) {
                        HStack(spacing: 8 * scalingFactor) {
                            Image(systemName: "plus")
                                .font(.system(size: 16 * scalingFactor, weight: .medium))
                            
                            Text("Add video")
                                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        }
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50 * scalingFactor)
                        .background(CMColor.primaryGradient)
                        .cornerRadius(25 * scalingFactor)
                    }
                    .padding(.horizontal, 20 * scalingFactor)
                    .padding(.top, 16 * scalingFactor)
                    .padding(.bottom, 16 * scalingFactor)
                    .background(CMColor.background)
                }
                .transition(.move(edge: .bottom))
            }
        }
    }
    
    // MARK: - Search Bar
    private func searchBar(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            HStack(spacing: 8 * scalingFactor) {
                TextField("Search", text: $searchText)
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                    }
                
                Spacer()
                
                if isSearchFocused && !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                            .font(.system(size: 16 * scalingFactor))
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.secondaryText)
                        .font(.system(size: 16 * scalingFactor))
                }
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 12 * scalingFactor)
            .background(CMColor.surface)
            .cornerRadius(12 * scalingFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scalingFactor)
                    .stroke(isSearchFocused ? CMColor.primary.opacity(0.3) : CMColor.secondaryText.opacity(0.1), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    // MARK: - Video Date Section
    private func videoDateSection(group: VideoDateGroup, scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            // Date header
            Text(group.dateString)
                .font(.system(size: 18 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            // Video grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12 * scalingFactor),
                GridItem(.flexible(), spacing: 12 * scalingFactor)
            ], spacing: 12 * scalingFactor) {
                ForEach(group.videos) { video in
                    videoThumbnailCard(video: video, scalingFactor: scalingFactor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Video Thumbnail Card
    private func videoThumbnailCard(video: SafeVideoData, scalingFactor: CGFloat) -> some View {
        Button(action: {
            if isSelectionMode {
                if selectedVideos.contains(video.id) {
                    selectedVideos.remove(video.id)
                } else {
                    selectedVideos.insert(video.id)
                }
            } else {
                selectedVideo = video
            }
        }) {
            VStack(spacing: 0) {
                // Video preview
                ZStack {
                    // Video preview player
                    VideoPreviewView(
                        videoURL: video.videoURL,
                        scalingFactor: scalingFactor,
                        isPlaying: !isSelectionMode && !isSearchFocused,
                        videoId: video.id
                    )
                    .frame(height: 120 * scalingFactor)
                    .clipped()
                    .onAppear {
                        // Initialize preview state
                        videoPreviewStates[video.id] = true
                    }
                    .onDisappear {
                        // Clean up preview state
                        videoPreviewStates[video.id] = false
                    }
                    
                    // Play button overlay (only in selection mode or when tapped)
                    if isSelectionMode {
                        Rectangle()
                            .fill(CMColor.black.opacity(0.3))
                            .frame(height: 120 * scalingFactor)
                            .overlay(
                                Circle()
                                    .fill(CMColor.black.opacity(0.6))
                                    .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                                    .overlay(
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 16 * scalingFactor))
                                            .foregroundColor(CMColor.white)
                                            .offset(x: 2 * scalingFactor) // Slight offset for visual balance
                                    )
                            )
                    }
                    
                    // Duration overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(video.durationFormatted)
                                .font(.system(size: 12 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.white)
                                .padding(.horizontal, 6 * scalingFactor)
                                .padding(.vertical, 2 * scalingFactor)
                                .background(CMColor.black.opacity(0.7))
                                .cornerRadius(4 * scalingFactor)
                                .padding(.trailing, 8 * scalingFactor)
                                .padding(.bottom, 8 * scalingFactor)
                        }
                    }
                    
                    // Selection indicator
                    if isSelectionMode {
                        VStack {
                            HStack {
                                Circle()
                                    .stroke(CMColor.white, lineWidth: 2)
                                    .frame(width: 24 * scalingFactor, height: 24 * scalingFactor)
                                    .background(
                                        Circle()
                                            .fill(selectedVideos.contains(video.id) ? CMColor.primary : CMColor.clear)
                                    )
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12 * scalingFactor, weight: .bold))
                                            .foregroundColor(CMColor.white)
                                            .opacity(selectedVideos.contains(video.id) ? 1 : 0)
                                    )
                                    .padding(.leading, 8 * scalingFactor)
                                    .padding(.top, 8 * scalingFactor)
                                
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
                
                // Video info
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    HStack {
                        Text(video.fileSizeFormatted)
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.primaryText)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 8 * scalingFactor)
                .padding(.vertical, 8 * scalingFactor)
                .background(CMColor.surface)
            }
        }
        .cornerRadius(12 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                .stroke(isSelectionMode && selectedVideos.contains(video.id) ? CMColor.primary : CMColor.secondaryText.opacity(0.1), lineWidth: isSelectionMode && selectedVideos.contains(video.id) ? 2 : 1)
        )
        .shadow(color: CMColor.black.opacity(0.05), radius: 4 * scalingFactor, x: 0, y: 2 * scalingFactor)
        .scaleEffect(isSelectionMode && selectedVideos.contains(video.id) ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: selectedVideos.contains(video.id))
    }
}

// MARK: - Supporting Data Models
struct VideoDateGroup: Identifiable {
    let id = UUID()
    let dateString: String
    let date: Date
    let videos: [SafeVideoData]
}

// MARK: - Video Picker (Placeholder)
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
                    
                    // Get video duration
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

// MARK: - Video Preview View
struct VideoPreviewView: UIViewRepresentable {
    let videoURL: URL
    let scalingFactor: CGFloat
    let isPlaying: Bool
    let videoId: UUID
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray5
        
        let player = AVPlayer(url: videoURL)
        let playerLayer = AVPlayerLayer(player: player)
        
        // Configure player for preview performance
        player.isMuted = true // Mute for better performance in grid
        player.automaticallyWaitsToMinimizeStalling = true
        
        playerLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer)
        
        // Store player in context for control
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer
        
        // Set up looping with delay to prevent excessive CPU usage
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
        
        // Control playback based on isPlaying state
        if isPlaying {
            // Add small delay before starting to prevent too many simultaneous players
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.1...0.3)) {
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
            // Loop the video with a small delay to reduce performance impact
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
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

// MARK: - Video Player View
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
                        Button("Done") {
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

// MARK: - Preview
#Preview {
    VideosView()
        .environmentObject(SafeStorageManager())
}
