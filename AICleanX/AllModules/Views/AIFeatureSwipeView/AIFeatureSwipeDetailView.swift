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
    
    private let swipeDistanceThreshold: CGFloat = 100
    
    private var allImageModels: [AICleanServiceModel] {
        return sections.flatMap { $0.models }
    }
    
    private var deletionCount: Int {
        return cacheDataService.getTotalSwipeDecisionsForDeletion()
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
    
    private func storeDecision(for assetId: String, decision: AIFeatureSwipeDecision) {
        if let cacheValue = convertDecisionToCacheValue(decision) {
            cacheDataService.setSwipeDecision(id: assetId, ignored: cacheValue)
        } else {
            cacheDataService.deleteSwipeDecision(id: assetId)
        }
        if let callback = onSwipeDecisionChanged {
            callback()
        }
    }
    
    private func removeDecision(for assetId: String) {
        let _ = withAnimation(.easeInOut(duration: 0.3)) {
            assetDecisions.removeValue(forKey: assetId)
        }
        cacheDataService.deleteSwipeDecision(id: assetId)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        if let callback = onSwipeDecisionChanged {
            callback()
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
        VStack(spacing: 0) {
            navigationBarView()
            Spacer()
            VStack(spacing: 0) {
                mainImageView()
                thumbnailCarouselView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CMColor.backgroundSecondary)
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
                        // Закрываем весь экран SwipePhotoDetailView
                        dismiss()
                    }
                )
            }
        }
    }
    
    @ViewBuilder
    private func navigationBarView() -> some View {
        HStack {
            Button {
                processBackAction()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("AI Review")
                // Option 2: AI-Enhanced Cleanup (фокусировка на результате)
                // Text("AI-Enhanced Cleanup")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                // Подсказка, связанная с AI-выбором
                // Option 1: Refine AI Selection
                Text("Refine AI Selection")
                // Option 2: Tap to Adjust AI Scan
                // Text("Tap to Adjust AI Scan")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(CMColor.primaryText.opacity(0.6))
            }
            
            Spacer()
            
            // Кнопка "Готово"
            Button {
                processFinishAction()
            } label: {
                // Option 1: Complete AI Cleanup
                // Option 2: Finalize
                Text("Finalize")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CMColor.backgroundSecondary)
    }
    
    @ViewBuilder
    private func mainImageView() -> some View {
        ZStack {
            let currentIndex = photoIndex
            let safeCurrentIndex = min(currentIndex, allImageModels.count - 1)
            ForEach(allImageModels.indices.filter { $0 >= safeCurrentIndex && $0 < min(safeCurrentIndex + 3, allImageModels.count) }, id: \.self) { modelIndex in
                let isTopCard = modelIndex == safeCurrentIndex
                let model = allImageModels[modelIndex]

                ZStack {
                    model.imageView(size: CGSize(width: 400, height: 400))
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(CMColor.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .clipped()
                    
                    if isTopCard && !isCardAnimating {
                        actionIndicatorsView()
                    }
                
                    if let decision = assetDecisions[model.asset.localIdentifier], isTopCard && !isCardAnimating {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(decision.color.opacity(0.8))
                                        .frame(width: 80, height: 80)
                                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                    Image(systemName: decision.iconName)
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(CMColor.secondaryText)
                                }
                                Spacer()
                            }
                            Spacer()
                        }
                        .transition(.opacity.animation(.easeIn))
                    }
                }
                .scaleEffect({
                    if isTopCard {
                        return 1.0 - abs(dragMovement) / 500
                    } else {
                        return 1.0 - CGFloat(modelIndex - safeCurrentIndex) * 0.05
                    }
                }())
                .offset(x: {
                    if isTopCard {
                        return dragMovement
                    } else {
                        return 0
                    }
                }(), y: CGFloat(modelIndex - safeCurrentIndex) * 8)
                .rotationEffect(.degrees(0)) // Убрали наклон
                .opacity(isTopCard ? 1.0 : (1.0 - CGFloat(modelIndex - safeCurrentIndex) * 0.25))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: dragMovement)
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: photoIndex)
                .zIndex(Double(10 - (modelIndex - safeCurrentIndex)))
            }
        }
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
                        
                        isCardAnimating = true
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            dragMovement = finalDecision == .keep ? 1000 : -1000
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            photoIndex += 1
                            isCardAnimating = false
                            dragMovement = 0
                            currentAction = .none
                            showActionIndicator = false
                        }
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragMovement = 0
                            currentAction = .none
                            showActionIndicator = false
                        }
                    }
                }
        )
    }
    
    @ViewBuilder
    private func actionIndicatorsView() -> some View {
        if dragMovement < -30 {
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(CMColor.error)
                            .frame(width: 80, height: 80)
                            .opacity(min(abs(dragMovement) / swipeDistanceThreshold, 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    .scaleEffect(currentAction == .delete ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: currentAction)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMovement)
                }
                .padding(.top, 32)
                .padding(.trailing, 32)
                
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
        
        if dragMovement > 30 {
            VStack {
                HStack {
                    ZStack {
                        Circle()
                            .fill(CMColor.success)
                            .frame(width: 80, height: 80)
                            .opacity(min(abs(dragMovement) / swipeDistanceThreshold, 1.0))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    .scaleEffect(currentAction == .keep ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: currentAction)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: dragMovement)
                    
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.leading, 32)
                
                Spacer()
            }
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }
    
    @ViewBuilder
    private func thumbnailCarouselView() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CMColor.primaryText.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
                
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 8) {
                        ForEach(allImageModels.indices, id: \.self) { index in
                            let model = allImageModels[index]
                            let decision = assetDecisions[model.asset.localIdentifier] ?? .none
                                        
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    photoIndex = index
                                }
                            } label: {
                                model.imageView(size: CGSize(width: 70, height: 70))
                                    .frame(width: 70, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                min(photoIndex, allImageModels.count - 1) == index ? CMColor.primary : decision.color,
                                                lineWidth: min(photoIndex, allImageModels.count - 1) == index ? 3 : (decision != .none ? 2 : 0)
                                            )
                                    )
                                    .scaleEffect(min(photoIndex, allImageModels.count - 1) == index ? 1.05 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: photoIndex)
                                    .overlay(
                                        Group {
                                            if decision != .none {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                            
                                                        ZStack {
                                                            Circle()
                                                                .fill(decision.color)
                                                                .frame(width: 20, height: 20)
                                                            
                                                            Image(systemName: decision.iconName)
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundColor(CMColor.secondaryText)
                                                        }
                                                    }
                                                        
                                                    Spacer()
                                                }
                                                .padding(4)
                                            }
                                        }
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onLongPressGesture {
                                removeDecision(for: model.asset.localIdentifier)
                            }
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
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
            .frame(height: 102)
        }
        .background(CMColor.backgroundSecondary)
        .onAppear {
            retrieveSavedDecisions()
        }
    }
}
