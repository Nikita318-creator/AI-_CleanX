import SwiftUI
import Photos
import Combine
import AVKit

extension AICleanServiceModel {
    
    /// Асинхронно загружает изображение и возвращает Publisher для SwiftUI
    func imagePublisher(size: CGSize) -> AnyPublisher<UIImage?, Never> {
        Future<UIImage?, Never> { promise in
            self.getImage(size: size) { image in
                promise(.success(image))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Создает SwiftUI Image View с автоматической загрузкой
    func imageView(size: CGSize) -> some View {
        PHAssetImageView(model: self, size: size)
    }
    
    /// Создает продвинутый SwiftUI Image View с кастомизацией
    func advancedImageView<PlaceholderView: View, ErrorView: View>(
        size: CGSize,
        contentMode: ContentMode = .fit,
        @ViewBuilder placeholder: @escaping () -> PlaceholderView,
        @ViewBuilder errorView: @escaping () -> ErrorView
    ) -> some View {
        AdvancedPHAssetImageView(
            model: self,
            size: size,
            contentMode: contentMode,
            placeholder: placeholder,
            errorView: errorView
        )
    }
    
    /// Получает изображение асинхронно с использованием async/await
    @MainActor
    func getImageAsync(size: CGSize) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            getImage(size: size) { image in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// Создает thumbnail изображение стандартного размера
    func thumbnailView() -> some View {
        imageView(size: CGSize(width: 80, height: 80))
    }
    
    /// Создает preview изображение среднего размера
    func previewView() -> some View {
        imageView(size: CGSize(width: 200, height: 200))
    }
    
    /// Создает полноразмерное изображение для детального просмотра
    func fullSizeView() -> some View {
        imageView(size: CGSize(width: 1024, height: 1024))
    }
    
    // MARK: - Video Support
    
    /// Создает VideoPlayer для воспроизведения видео
    func videoPlayerView() -> some View {
        PHAssetVideoPlayerView(model: self)
    }
    
    /// Получает AVPlayerItem для видео
    func getAVPlayerItem() -> AnyPublisher<AVPlayerItem?, Never> {
        Future<AVPlayerItem?, Never> { promise in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .automatic
            
            PHImageManager.default().requestPlayerItem(forVideo: self.asset, options: options) { playerItem, _ in
                promise(.success(playerItem))
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// Проверяет, является ли ассет видео
    var isVideo: Bool {
        return asset.mediaType == .video
    }
    
    /// Получает длительность видео
    var videoDuration: TimeInterval {
        return asset.duration
    }
    
    /// Форматирует длительность видео в строку
    var formattedDuration: String {
        let duration = Int(videoDuration)
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// ObservableObject wrapper для использования в SwiftUI
@MainActor
class PHAssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    @Published var hasError = false
    
    private let model: AICleanServiceModel
    private let size: CGSize
    
    init(model: AICleanServiceModel, size: CGSize) {
        self.model = model
        self.size = size
    }
    
    func loadImage() {
        guard !isLoading else { return }
        
        isLoading = true
        hasError = false
        
        model.getImage(size: size) { [weak self] loadedImage in
            DispatchQueue.main.async {
                self?.image = loadedImage
                self?.hasError = loadedImage == nil
                self?.isLoading = false
            }
        }
    }
    
    func reload() {
        image = nil
        loadImage()
    }
}

// MARK: - Video Player Component

struct PHAssetVideoPlayerView: View {
    let model: AICleanServiceModel
    @StateObject private var playerLoader = VideoPlayerLoader()
    
    var body: some View {
        ZStack {
            // Фоновое изображение (thumbnail) всегда показываем
            model.imageView(size: CGSize(width: 400, height: 400))
                .opacity(playerLoader.player != nil ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: playerLoader.player != nil)
            
            // Видео плеер поверх thumbnail
            if let player = playerLoader.player {
                VideoPlayer(player: player)
                    .opacity(1.0)
                    .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                    .onAppear {
                        // Небольшая задержка перед воспроизведением для плавности
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            player.seek(to: .zero)
                        }
                    }
            }
            
            // Индикатор загрузки с прогрессом
            if playerLoader.isLoading {
                VStack(spacing: 16) {
                    // Анимированный индикатор загрузки
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: playerLoader.loadingProgress)
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.3), value: playerLoader.loadingProgress)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    Text("Loading video...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Индикатор ошибки
            if playerLoader.hasError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.yellow)
                    
                    Text("Failed to load video")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Button("Retry") {
                        playerLoader.loadVideo(for: model)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            // Запускаем загрузку асинхронно
            Task {
                await Task.yield() // Даем UI время на отрисовку
                playerLoader.loadVideo(for: model)
            }
        }
        .onDisappear {
            playerLoader.cleanup()
        }
        .onChange(of: model.asset.localIdentifier) { _ in
            // Перезагружаем видео при смене модели
            Task {
                await Task.yield() // Даем UI время на обновление
                playerLoader.cleanup()
                playerLoader.loadVideo(for: model)
            }
        }
    }
}

@MainActor
class VideoPlayerLoader: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isLoading = false
    @Published var hasError = false
    @Published var loadingProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    
    func loadVideo(for model: AICleanServiceModel) {
        // Отменяем предыдущую загрузку
        currentTask?.cancel()
        cleanup()
        
        isLoading = true
        hasError = false
        loadingProgress = 0.0
        
        // Создаем асинхронную задачу для загрузки
        currentTask = Task { @MainActor in
            do {
                // Симулируем прогресс загрузки
                await updateProgress(0.1)
                
                // Асинхронно получаем AVPlayerItem
                let playerItem = await withCheckedContinuation { continuation in
                    model.getAVPlayerItem()
                        .receive(on: DispatchQueue.global(qos: .userInitiated))
                        .sink { playerItem in
                            continuation.resume(returning: playerItem)
                        }
                        .store(in: &cancellables)
                }
                
                // Проверяем, не была ли задача отменена
                guard !Task.isCancelled else { return }
                
                await updateProgress(0.7)
                
                if let playerItem = playerItem {
                    // Создаем плеер на фоновом потоке
                    let player = await withCheckedContinuation { continuation in
                        DispatchQueue.global(qos: .userInitiated).async {
                            let newPlayer = AVPlayer(playerItem: playerItem)
                            continuation.resume(returning: newPlayer)
                        }
                    }
                    
                    // Проверяем, не была ли задача отменена
                    guard !Task.isCancelled else { return }
                    
                    await updateProgress(1.0)
                    
                    // Обновляем UI на главном потоке
                    self.player = player
                    self.isLoading = false
                    self.hasError = false
                } else {
                    self.isLoading = false
                    self.hasError = true
                }
            }
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double) async {
        loadingProgress = progress
        // Небольшая задержка для плавности анимации
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 секунды
    }
    
    func cleanup() {
        currentTask?.cancel()
        currentTask = nil
        player?.pause()
        player = nil
        isLoading = false
        hasError = false
        loadingProgress = 0.0
        cancellables.removeAll()
    }
}
