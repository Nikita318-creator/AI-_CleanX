
import SwiftUI
import Photos

// MARK: - Photo Asset Item View

struct PhotoAssetItemView: View {
    let photo: PhotoAssetModel
    let isSelected: Bool
    let onToggle: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            // Background square
            Rectangle()
                .fill(CMColor.backgroundSecondary)
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
            
            // Image or placeholder
            Group {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(CMColor.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(8)
            .clipped()
            .onAppear {
                loadImage()
            }

            // Overlay elements
            VStack {
                HStack {
                    Spacer()
                    // Checkbox Button
                    Button(action: onToggle) {
                        ZStack {
                            Circle()
                                .stroke(isSelected ? CMColor.clear : CMColor.white, lineWidth: 2)
                                .background(isSelected ? CMColor.primary : CMColor.clear)
                                .clipShape(Circle())
                                .frame(width: 24, height: 24)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(CMColor.primary)
                                    .background(CMColor.white)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(8)
                }
                
                Spacer()
                
                HStack {
                    // "Best" label for the best photo
                    if photo.isBest {
                        Text("Best")
                            .font(.caption2)
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(CMColor.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Similarity score for similar photos
                    if photo.similarityScore > 0 {
                        Text("\(Int(photo.similarityScore * 100))%")
                            .font(.caption2)
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CMColor.primary.opacity(0.8))
                            .cornerRadius(6)
                    }
                }
                .padding(8)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func loadImage() {
        // Если изображение уже есть в модели, используем его
        if let existingImage = photo.image {
            self.image = existingImage
            self.isLoading = false
            return
        }
        
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let targetSize = CGSize(width: 150, height: 150) // Уменьшенный размер для UI
        
        imageManager.requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            DispatchQueue.main.async {
                self.image = result
                self.isLoading = false
            }
        }
    }
}

// MARK: - Legacy Photo Item View (for backward compatibility)

struct PhotoItemView: View {
    let photo: SimilarView.Photo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Placeholder for the image
            CMColor.backgroundSecondary
                .aspectRatio(1, contentMode: .fit)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(CMColor.secondaryText)
                )

            // Checkbox Button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? CMColor.clear : CMColor.white, lineWidth: 2)
                        .background(isSelected ? CMColor.primary : CMColor.clear)
                        .clipShape(Circle())
                        .frame(width: 24, height: 24)
                        .padding(4)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(CMColor.primary)
                            .background(CMColor.white)
                            .clipShape(Circle())
                            .padding(4)
                    }
                }
            }

            // "Best" label for the best photo
            if photo.isBest {
                Text("Best")
                    .font(.caption2)
                    .foregroundColor(CMColor.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(CMColor.black.opacity(0.5))
                    .cornerRadius(8)
                    .padding([.leading, .bottom], 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
    }
}

// MARK: - Legacy Photo struct for backward compatibility
extension SimilarView {
    struct Photo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        var isBest: Bool = false
    }
}
