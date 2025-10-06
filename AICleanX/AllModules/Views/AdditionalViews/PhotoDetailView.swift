import SwiftUI

struct PhotoDetailView: View {
    let photo: SafePhotoData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    
    // Zoom and pan states
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    
    // UI states
    @State private var showDeleteAlert = false
    @State private var imageSize: CGSize = .zero
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                CMColor.black
                    .ignoresSafeArea()
                
                // Photo content
                photoContentView(geometry: geometry)
                
                // Navigation bar overlay
                VStack {
                    navigationBarView()
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .alert("Delete Photo", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this photo? This action cannot be undone.")
        }
    }
    
    // MARK: - Navigation Bar
    private func navigationBarView() -> some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // Photo filename
            Text(photo.fileName)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Delete button
            Button(action: {
                showDeleteAlert = true
            }) {
                Text("Delete")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 12 * scalingFactor)
        .background(
            LinearGradient(
                colors: [
                    CMColor.black.opacity(0.7),
                    CMColor.black.opacity(0.3),
                    CMColor.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Photo Content
    private func photoContentView(geometry: GeometryProxy) -> some View {
        Group {
            if let uiImage = photo.fullImage {
                ZoomableImageView(
                    image: uiImage,
                    scale: $scale,
                    offset: $offset,
                    lastScale: $lastScale,
                    lastOffset: $lastOffset,
                    imageSize: $imageSize,
                    containerSize: geometry.size
                )
            } else {
                // Fallback for missing image
                VStack(spacing: 16 * scalingFactor) {
                    Image(systemName: "photo")
                        .font(.system(size: 64 * scalingFactor))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Image not available")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Actions
    private func deletePhoto() {
        safeStorageManager.deletePhoto(photo)
        dismiss()
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let image: UIImage
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastScale: CGFloat
    @Binding var lastOffset: CGSize
    @Binding var imageSize: CGSize
    let containerSize: CGSize
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .background(
                    GeometryReader { imageGeometry in
                        Color.clear
                            .onAppear {
                                // Calculate the actual image display size
                                let imageAspectRatio = image.size.width / image.size.height
                                let containerAspectRatio = geometry.size.width / geometry.size.height
                                
                                if imageAspectRatio > containerAspectRatio {
                                    // Image is wider - fit to width
                                    imageSize = CGSize(
                                        width: geometry.size.width,
                                        height: geometry.size.width / imageAspectRatio
                                    )
                                } else {
                                    // Image is taller - fit to height
                                    imageSize = CGSize(
                                        width: geometry.size.height * imageAspectRatio,
                                        height: geometry.size.height
                                    )
                                }
                            }
                    }
                )
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        // Magnification gesture for zooming
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, minScale), maxScale)
                            }
                            .onEnded { value in
                                lastScale = scale
                                
                                // Snap back to bounds if needed
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    snapToBounds()
                                }
                            },
                        
                        // Drag gesture for panning
                        DragGesture()
                            .onChanged { value in
                                let newOffset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = constrainOffset(newOffset)
                            }
                            .onEnded { value in
                                lastOffset = offset
                                
                                // Smooth animation when gesture ends
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                    offset = constrainOffset(offset)
                                }
                            }
                    )
                )
                // Double tap to zoom
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if scale > minScale {
                            // Zoom out to fit
                            scale = minScale
                            offset = .zero
                            lastScale = minScale
                            lastOffset = .zero
                        } else {
                            // Zoom in to 2x
                            scale = 2.0
                            lastScale = 2.0
                            // Center the zoom
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
    
    // MARK: - Helper Methods
    private func constrainOffset(_ proposedOffset: CGSize) -> CGSize {
        guard scale > minScale, imageSize.width > 0, imageSize.height > 0 else {
            return .zero
        }
        
        // Calculate the scaled image dimensions
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        // Calculate maximum allowed offset to keep image within bounds
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)
        
        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }
    
    private func snapToBounds() {
        if scale <= minScale {
            scale = minScale
            offset = .zero
            lastScale = minScale
            lastOffset = .zero
        } else {
            offset = constrainOffset(offset)
            lastOffset = offset
        }
    }
}

// MARK: - Preview
#Preview {
    let samplePhoto = SafePhotoData(
        imageURL: URL(fileURLWithPath: "/tmp/sample.jpg"),
        thumbnailURL: nil,
        fileName: "IMG_93647284.jpg",
        fileSize: 1024000
    )
    
    NavigationView {
        PhotoDetailView(photo: samplePhoto)
            .environmentObject(SafeStorageManager())
    }
}
