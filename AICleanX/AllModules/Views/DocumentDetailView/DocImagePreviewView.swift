import SwiftUI

struct DocImagePreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: String?
    
    // Zoom and pan states (same as PhotoDetailView)
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
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
                
                // Image content
                imageContentView(geometry: geometry)
                
                // Navigation bar overlay
                VStack {
                    navigationBarView(safeAreaTop: geometry.safeAreaInsets.top)
                    Spacer()
                }
                .padding(.top, geometry.safeAreaInsets.top)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .onAppear {
            loadImageFromDocument()
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [document.documentURL])
        }
        .alert("Delete Image", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteDocument()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(document.fileName)\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Navigation Bar
    private func navigationBarView(safeAreaTop: CGFloat) -> some View {
        HStack {
            // Back button
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                }
                .foregroundColor(.white)
            }
            
            Spacer()
            
            // Document title
            Text(document.fileName)
                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 16 * scalingFactor) {
                // Share button
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                }
                
                // Delete button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18 * scalingFactor, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [CMColor.black.opacity(0.7), Color.clear]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Image Content
    private func imageContentView(geometry: GeometryProxy) -> some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = loadError {
                errorView(error: error)
            } else if let image = loadedImage {
                ZoomableImageView(
                    image: image,
                    scale: $scale,
                    offset: $offset,
                    lastScale: $lastScale,
                    lastOffset: $lastOffset,
                    imageSize: $imageSize,
                    containerSize: geometry.size
                )
            } else {
                emptyStateView
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16 * scalingFactor) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)
            
            Text("Loading image...")
                .font(.system(size: 16 * scalingFactor))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Error View
    private func errorView(error: String) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48 * scalingFactor))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8 * scalingFactor) {
                Text("Cannot Load Image")
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(error)
                    .font(.system(size: 14 * scalingFactor))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16 * scalingFactor) {
            Image(systemName: "photo")
                .font(.system(size: 64 * scalingFactor))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Image not available")
                .font(.system(size: 16 * scalingFactor))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    // MARK: - Helper Methods
    private func loadImageFromDocument() {
        isLoading = true
        loadError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Check if file exists
                guard FileManager.default.fileExists(atPath: document.documentURL.path) else {
                    DispatchQueue.main.async {
                        self.loadError = "Image file not found"
                        self.isLoading = false
                    }
                    return
                }
                
                // Load image data
                let imageData = try Data(contentsOf: document.documentURL)
                
                // Create UIImage
                guard let uiImage = UIImage(data: imageData) else {
                    DispatchQueue.main.async {
                        self.loadError = "Invalid image format"
                        self.isLoading = false
                    }
                    return
                }
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.loadedImage = uiImage
                    self.isLoading = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.loadError = "Error loading image: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func deleteDocument() {
        isDeleting = true
        safeStorageManager.deleteDocuments([document])
        dismiss()
    }
}
