import SwiftUI
import Photos

struct AIFeatureSwipeDetailView: View {
    let sections: [AICleanServiceSection]
    @State private var photoIndex: Int
    @ObservedObject var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    let mode: SwipeAIFeatureDetailMode
    var onShowResults: (() -> Void)?
    
    private let cacheDataService = AICleanCacheService.shared
    
    @State private var dragMovement: CGFloat = 0
    @State private var currentAction: AIFeatureSwipeDecision = .none
    @State private var assetDecisions: [String: AIFeatureSwipeDecision] = [:]
    
    @State private var showActionIndicator = false
    @State private var isCardAnimating = false
    @State private var animatingCardOffset: CGFloat = 0
    @State private var animatingCardId: String? = nil
    @State private var showExitAlert = false
    
    private let swipeDistanceThreshold: CGFloat = 120
    
    private var allImageModels: [AICleanServiceModel] {
        return sections.flatMap { $0.models }
    }
    
    private var deletionCount: Int {
        return cacheDataService.getTotalSwipeDecisionsForDeletion()
    }
    
    private var progressPercentage: Double {
        let decided = assetDecisions.count
        let total = allImageModels.count
        return total > 0 ? Double(decided) / Double(total) : 0
    }
    
    var onFinish: ([String: AIFeatureSwipeDecision]) -> Void
    var onSwipeDecisionChanged: (() -> Void)?
    
    init(sections: [AICleanServiceSection], initialIndex: Int, viewModel: SimilaritySectionsViewModel, mode: SwipeAIFeatureDetailMode = .swipeMode, onFinish: @escaping ([String: AIFeatureSwipeDecision]) -> Void, onShowResults: (() -> Void)? = nil, onSwipeDecisionChanged: (() -> Void)? = nil) {
        self.sections = sections
        self._photoIndex = State(initialValue: initialIndex)
        self.viewModel = viewModel
        self.mode = mode
        self.onFinish = onFinish
        self.onShowResults = onShowResults
        self.onSwipeDecisionChanged = onSwipeDecisionChanged
    }
    
    private func convertDecisionToCacheValue(_ decision: AIFeatureSwipeDecision) -> Bool? {
        switch decision {
        case .keep:
            return true
        case .delete:
            return false
        case .none:
            return nil
        }
    }
    
    private func convertCacheValueToDecision(_ cacheValue: Bool?) -> AIFeatureSwipeDecision {
        guard let cacheValue = cacheValue else { return .none }
        return cacheValue ? .keep : .delete
    }
    
    private func retrieveSavedDecisions() {
        for model in allImageModels {
            let assetId = model.asset.localIdentifier
            let savedDecision = cacheDataService.getSwipeDecision(id: assetId)
            let photoDecision = convertCacheValueToDecision(savedDecision)
            
            if photoDecision != .none {
                assetDecisions[assetId] = photoDecision
            }
        }
    }
    
    // Оптимизированная функция:
    private func storeDecision(for assetId: String, decision: AIFeatureSwipeDecision) {
        // 1. Быстрое изменение в памяти (если нужно) или просто отправка в фон
        
        // 2. Использование Task для выполнения операции с диском в фоновом режиме
        Task.detached {
            if let cacheValue = await self.convertDecisionToCacheValue(decision) {
                self.cacheDataService.setSwipeDecision(id: assetId, ignored: cacheValue)
            } else {
                self.cacheDataService.deleteSwipeDecision(id: assetId)
            }
            
            // 3. Возврат на главный поток для UI-коллбэка, если он нужен
            await MainActor.run {
                if let callback = self.onSwipeDecisionChanged {
                    callback()
                }
            }
        }
    }
    
    // Оптимизированная функция:
    private func removeDecision(for assetId: String) {
        let _ = withAnimation(.easeInOut(duration: 0.3)) {
            assetDecisions.removeValue(forKey: assetId)
        }
        
        // Использование Task для выполнения операции с диском в фоновом режиме
        Task.detached {
            self.cacheDataService.deleteSwipeDecision(id: assetId)
            
            // Возврат на главный поток для UI-коллбэка и вибрации
            await MainActor.run {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                if let callback = self.onSwipeDecisionChanged {
                    callback()
                }
            }
        }
    }
    
    private func processBackAction() {
        switch mode {
        case .swipeMode:
            if deletionCount > 0 {
                showExitAlert = true
            } else {
                dismiss()
            }
        case .resultsView:
            dismiss()
        }
    }
    
    private func processFinishAction() {
        switch mode {
        case .swipeMode:
            if deletionCount > 0 {
                showExitAlert = true
            } else {
                onFinish(assetDecisions)
                dismiss()
            }
        case .resultsView:
            onFinish(assetDecisions)
            dismiss()
        }
    }
    
    var body: some View {
        ZStack {
            // Gradient Background - Используем градиент из CMColor
            CMColor.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                modernNavigationBar()
                
                Spacer()
                
                VStack(spacing: 24) {
                    modernMainImageView()
                    modernActionButtons()
                    modernThumbnailCarousel()
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarHidden(true)
        .overlay {
            if showExitAlert {
                ResultsAIFeatureSwipePopup(
                    deleteCount: deletionCount,
                    isPresented: $showExitAlert,
                    onViewResults: {
                        onShowResults?()
                        dismiss()
                    },
                    onContinueSwiping: {
//                        dismiss()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func modernNavigationBar() -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                Button {
                    processBackAction()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Exit")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(
                        // Градиент для текста "Exit" - используем secondaryGradient
                        CMColor.secondaryGradient
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(CMColor.white.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(CMColor.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                // Градиент для иконки "Sparkles"
                                LinearGradient(
                                    colors: [CMColor.accent, CMColor.primary], // Использование accent и primary
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Smart Cleanup")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(CMColor.primaryText)
                    }
                    
                    Text("\(min(photoIndex + 1, allImageModels.count)) of \(allImageModels.count)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(CMColor.primaryText.opacity(0.5))
                }
                
                Spacer()
                
                Button {
                    processFinishAction()
                } label: {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        // Хардкод "0A0E27" заменен на CMColor.primaryDark или CMColor.background
                        .foregroundColor(CMColor.primaryDark)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    // Градиент для кнопки "Done" - используем secondaryGradient
                                    CMColor.border
                                )
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CMColor.primaryText.opacity(0.1))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(
                            // Градиент прогресс-бара
                            LinearGradient(
                                colors: [CMColor.accent, CMColor.primary, CMColor.secondary], // Использование accent, primary, secondary
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progressPercentage)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 12)
    }
    
    // ... в AIFeatureSwipeDetailView
    @ViewBuilder
    private func modernMainImageView() -> some View {
        ZStack {
            let currentIndex = photoIndex
            let safeCurrentIndex = min(currentIndex, allImageModels.count - 1)
            
            // ВАЖНОЕ ИЗМЕНЕНИЕ: Использование LazyVStack для оптимизации рендеринга
            // Используем ForEach только для тех карточек, которые видны или скоро будут видны (Current + Next 2)
            ForEach(allImageModels.indices.filter { $0 >= safeCurrentIndex && $0 < min(safeCurrentIndex + 3, allImageModels.count) }, id: \.self) { modelIndex in
                let isTopCard = modelIndex == safeCurrentIndex
                let model = allImageModels[modelIndex]
                
                ZStack {
                    // Card Container (оставлен без изменений)
                    RoundedRectangle(cornerRadius: 32)
                        .fill(CMColor.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(
                                    LinearGradient(
                                        colors: [CMColor.white.opacity(0.2), CMColor.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: CMColor.black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    // >>> ОПТИМИЗАЦИЯ ЗДЕСЬ: Используем AssetImageView для асинхронной загрузки
                    AssetImageView(asset: model.asset, targetSize: CGSize(width: 400, height: 400))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 32))
                        .padding(8)
                    // <<< КОНЕЦ ОПТИМИЗАЦИИ

                    if isTopCard && !isCardAnimating {
                        modernActionIndicators()
                    }
                    
                    if let decision = assetDecisions[model.asset.localIdentifier], isTopCard && !isCardAnimating {
                        modernDecisionBadge(decision: decision)
                    }
                }
                .scaleEffect({
                    if isTopCard {
                        return 1.0 - abs(dragMovement) / 1000
                    } else {
                        return 0.92 - CGFloat(modelIndex - safeCurrentIndex) * 0.04
                    }
                }())
                .offset(x: isTopCard ? dragMovement : 0, y: CGFloat(modelIndex - safeCurrentIndex) * 12)
                .rotationEffect(.degrees(isTopCard ? Double(dragMovement / 30) : 0))
                .opacity(isTopCard ? 1.0 : (0.7 - CGFloat(modelIndex - safeCurrentIndex) * 0.2))
                .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.8), value: dragMovement)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: photoIndex)
                .zIndex(Double(100 - (modelIndex - safeCurrentIndex)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: UIScreen.main.bounds.height * 0.5)
        .padding(.horizontal, 24)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isCardAnimating else { return }
                    dragMovement = value.translation.width
                    
                    if dragMovement > swipeDistanceThreshold {
                        currentAction = .keep
                    } else if dragMovement < -swipeDistanceThreshold {
                        currentAction = .delete
                    } else {
                        currentAction = .none
                    }
                    
                    showActionIndicator = abs(dragMovement) > 20
                    
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    if abs(dragMovement) > swipeDistanceThreshold && currentAction != .none {
                        impact.impactOccurred()
                    }
                }
                .onEnded { value in
                    guard !isCardAnimating else { return }
                    
                    let finalDecision: AIFeatureSwipeDecision
                    if dragMovement > swipeDistanceThreshold {
                        finalDecision = .keep
                    } else if dragMovement < -swipeDistanceThreshold {
                        finalDecision = .delete
                    } else {
                        finalDecision = .none
                    }
                    
                    if finalDecision != .none {
                        let safeIndex = min(photoIndex, allImageModels.count - 1)
                        let currentModel = allImageModels[safeIndex]
                        let assetId = currentModel.asset.localIdentifier
                        assetDecisions[assetId] = finalDecision
                        storeDecision(for: assetId, decision: finalDecision)
                        
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        
                        isCardAnimating = true
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            dragMovement = finalDecision == .keep ? 1200 : -1200
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            photoIndex += 1
                            isCardAnimating = false
                            dragMovement = 0
                            currentAction = .none
                            showActionIndicator = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            dragMovement = 0
                            currentAction = .none
                            showActionIndicator = false
                        }
                    }
                }
        )
    }
    
    @ViewBuilder
    private func modernActionIndicators() -> some View {
        ZStack {
            // Delete Indicator (Left)
            if dragMovement < -30 {
                HStack {
                    Spacer()
                    VStack {
                        modernSwipeIndicator(
                            icon: "xmark",
                            // Хардкод "EF4444" заменен на CMColor.error
                            color: CMColor.error,
                            isActive: currentAction == .delete,
                            progress: min(abs(dragMovement) / swipeDistanceThreshold, 1.0)
                        )
                        Spacer()
                    }
                    .padding(.trailing, 40)
                    .padding(.top, 40)
                }
            }
            
            // Keep Indicator (Right)
            if dragMovement > 30 {
                HStack {
                    VStack {
                        modernSwipeIndicator(
                            icon: "checkmark",
                            // Хардкод "10B981" заменен на CMColor.success
                            color: CMColor.success,
                            isActive: currentAction == .keep,
                            progress: min(abs(dragMovement) / swipeDistanceThreshold, 1.0)
                        )
                        Spacer()
                    }
                    .padding(.leading, 40)
                    .padding(.top, 40)
                    Spacer()
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func modernSwipeIndicator(icon: String, color: Color, isActive: Bool, progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 90, height: 90)
                .blur(radius: 20)
            
            Circle()
                .fill(color)
                .frame(width: 70, height: 70)
                .opacity(progress)
            
            Image(systemName: icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(CMColor.white)
        }
        .scaleEffect(isActive ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
    
    @ViewBuilder
    private func modernDecisionBadge(decision: AIFeatureSwipeDecision) -> some View {
        VStack {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(decision.color.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                
                Circle()
                    .fill(decision.color)
                    .frame(width: 70, height: 70)
                
                Image(systemName: decision.iconName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(CMColor.white)
            }
            .padding(.bottom, 40)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    @ViewBuilder
    private func modernActionButtons() -> some View {
        HStack(spacing: 24) {
            // Delete Button
            Button {
                guard !isCardAnimating else { return }
                let safeIndex = min(photoIndex, allImageModels.count - 1)
                let currentModel = allImageModels[safeIndex]
                let assetId = currentModel.asset.localIdentifier
                assetDecisions[assetId] = .delete
                storeDecision(for: assetId, decision: .delete)
                
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                isCardAnimating = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    dragMovement = -1200
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    photoIndex += 1
                    isCardAnimating = false
                    dragMovement = 0
                }
            } label: {
                ZStack {
                    Circle()
                        // Хардкод "EF4444" заменен на CMColor.error
                        .fill(CMColor.error.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        // Хардкод "EF4444" заменен на CMColor.error
                        .stroke(CMColor.error, lineWidth: 2)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .bold))
                        // Хардкод "EF4444" заменен на CMColor.error
                        .foregroundColor(CMColor.error)
                }
            }
            
            // Undo Button
            Button {
                if photoIndex > 0 {
                    photoIndex -= 1
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(CMColor.white.opacity(0.1))
                        .frame(width: 56, height: 56)
                    
                    Circle()
                        .stroke(CMColor.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            // Градиент для кнопки Undo - используем secondaryGradient
                            CMColor.secondaryGradient
                        )
                }
            }
            .opacity(photoIndex > 0 ? 1.0 : 0.3)
            .disabled(photoIndex == 0)
            
            // Keep Button
            Button {
                guard !isCardAnimating else { return }
                let safeIndex = min(photoIndex, allImageModels.count - 1)
                let currentModel = allImageModels[safeIndex]
                let assetId = currentModel.asset.localIdentifier
                assetDecisions[assetId] = .keep
                storeDecision(for: assetId, decision: .keep)
                
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                isCardAnimating = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    dragMovement = 1200
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    photoIndex += 1
                    isCardAnimating = false
                    dragMovement = 0
                }
            } label: {
                ZStack {
                    Circle()
                        // Хардкод "10B981" заменен на CMColor.success
                        .fill(CMColor.success.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        // Хардкод "10B981" заменен на CMColor.success
                        .stroke(CMColor.success, lineWidth: 2)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .bold))
                        // Хардкод "10B981" заменен на CMColor.success
                        .foregroundColor(CMColor.success)
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    @ViewBuilder
    private func modernThumbnailCarousel() -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "photo.stack")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText.opacity(0.5))
                
                Text("Swipe or tap to review")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(CMColor.primaryText.opacity(0.5))
                
                Spacer()
                
                Text("\(assetDecisions.count) reviewed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        // Градиент для текста "reviewed" - используем secondaryGradient
                        CMColor.secondaryGradient
                    )
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 10) {
                        ForEach(allImageModels.indices, id: \.self) { index in
                            let model = allImageModels[index]
                            let decision = assetDecisions[model.asset.localIdentifier] ?? .none
                            let isSelected = min(photoIndex, allImageModels.count - 1) == index
                            
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    photoIndex = index
                                }
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(CMColor.white.opacity(0.05))
                                        .frame(width: 64, height: 64)
                                    
                                    model.imageView(size: CGSize(width: 64, height: 64))
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            isSelected
                                            // Градиент для выбранного элемента - используем secondaryGradient
                                            ? CMColor.secondaryGradient
                                            : LinearGradient(
                                                colors: [decision.color.opacity(decision != .none ? 0.8 : 0), CMColor.clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: isSelected ? 3 : 2
                                        )
                                        .frame(width: 64, height: 64)
                                    
                                    if decision != .none {
                                        VStack {
                                            HStack {
                                                Spacer()
                                                ZStack {
                                                    Circle()
                                                        .fill(decision.color)
                                                        .frame(width: 22, height: 22)
                                                    
                                                    Image(systemName: decision.iconName)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(CMColor.white)
                                                }
                                                .offset(x: 4, y: -4)
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onLongPressGesture {
                                removeDecision(for: model.asset.localIdentifier)
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 24)
                    .onAppear {
                        let safeIndex = min(photoIndex, allImageModels.count - 1)
                        proxy.scrollTo(safeIndex, anchor: .center)
                    }
                    .onChange(of: photoIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            let safeIndex = min(newIndex, allImageModels.count - 1)
                            proxy.scrollTo(safeIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

struct AssetImageView: View {
    let asset: PHAsset
    let targetSize: CGSize
    @State private var image: UIImage? = nil
    
    // PHImageManager для запроса изображений
    private static let imageManager = PHCachingImageManager()

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Плейсхолдер во время загрузки
                ProgressView()
                    .frame(width: targetSize.width, height: targetSize.height)
                    .background(Color.white.opacity(0.1))
            }
        }
        .onAppear {
            loadImage()
        }
        // Обязательно сбросить изображение, если Asset меняется (необходимо для ForEach)
        .onChange(of: asset) { _ in
            image = nil
            loadImage()
        }
    }
    
    private func loadImage() {
        // Опции для запроса изображения
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        
        // Запрос изображения
        AssetImageView.imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { loadedImage, info in
            // Убеждаемся, что мы не обрабатываем отмененный запрос
            guard let loadedImage = loadedImage else { return }
            
            // Если мы уже загрузили изображение или это не целевое изображение, ничего не делаем
            let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
            if !isDegraded || self.image == nil {
                self.image = loadedImage
            }
        }
    }
}
