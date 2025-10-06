import SwiftUI
import Photos

/// SwiftUI View для отображения изображений из PHAsset
struct PHAssetImageView: View {
    let model: AICleanServiceModel
    let size: CGSize
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: model.asset.localIdentifier) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        image = nil
        
        model.getImage(size: size) { loadedImage in
            DispatchQueue.main.async {
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }
}

/// Более продвинутая версия с кэшированием и дополнительными опциями
struct AdvancedPHAssetImageView<PlaceholderView: View, ErrorView: View>: View {
    let model: AICleanServiceModel
    let size: CGSize
    let contentMode: ContentMode
    let placeholder: PlaceholderView
    let errorView: ErrorView
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var hasError = false
    
    init(
        model: AICleanServiceModel,
        size: CGSize,
        contentMode: ContentMode = .fill,
        @ViewBuilder placeholder: () -> PlaceholderView,
        @ViewBuilder errorView: () -> ErrorView
    ) {
        self.model = model
        self.size = size
        self.contentMode = contentMode
        self.placeholder = placeholder()
        self.errorView = errorView()
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if hasError {
                errorView
            } else if isLoading {
                placeholder
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: model.asset.localIdentifier) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        isLoading = true
        hasError = false
        image = nil
        
        model.getImage(size: size) { loadedImage in
            DispatchQueue.main.async {
                if let loadedImage = loadedImage {
                    self.image = loadedImage
                    self.hasError = false
                } else {
                    self.hasError = true
                }
                self.isLoading = false
            }
        }
    }
}

/// Упрощенная версия с минимальным кодом
struct SimplePHAssetImageView: View {
    let model: AICleanServiceModel
    let size: CGSize
    
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color.gray.opacity(0.3)
            }
        }
        .onAppear {
            model.getImage(size: size) { loadedImage in
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct PHAssetImageView_Previews: PreviewProvider {
    static var previews: some View {
        // Для превью нужно будет создать mock объект
        VStack {
            Text("PHAssetImageView Preview")
            // PHAssetImageView(model: mockModel, size: CGSize(width: 100, height: 100))
            //     .frame(width: 100, height: 100)
            //     .cornerRadius(8)
        }
    }
}
#endif
