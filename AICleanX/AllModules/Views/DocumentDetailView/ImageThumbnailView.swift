import SwiftUI

struct ImageThumbnailView: View {
    let documentURL: URL
    let scalingFactor: CGFloat
    
    @State private var thumbnailImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scalingFactor))
            } else {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: CMColor.primary))
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 12 * scalingFactor, weight: .medium))
                                    .foregroundColor(CMColor.primary)
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .utility).async {
            guard FileManager.default.fileExists(atPath: documentURL.path) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let imageData = try Data(contentsOf: documentURL)
                guard let fullImage = UIImage(data: imageData) else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // Create thumbnail
                let thumbnailSize = CGSize(width: 64 * scalingFactor, height: 64 * scalingFactor)
                let thumbnail = fullImage.preparingThumbnail(of: thumbnailSize)
                
                DispatchQueue.main.async {
                    self.thumbnailImage = thumbnail
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}
