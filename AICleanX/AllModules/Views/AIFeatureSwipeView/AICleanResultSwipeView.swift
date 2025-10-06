import SwiftUI

struct AICleanResultSwipeView: View {
    @ObservedObject var viewModel: AIFeatureViewModel
    @Environment(\.dismiss) private var dismissView
    
    private var swipeResultsData: AICleanResultSwipeData {
        let data = viewModel.getSwipeResultsData()
        return data
    }
    
    @State private var showingRemovedPhotos = false
    @State private var showingKeptPhotos = false
    
    var onFinish: ([String]) -> Void
    var onSwipeDecisionChanged: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            setupNavigationBar()
            
            ScrollView {
                VStack(spacing: 24) {
                    keptSectionView()
                    removedSectionView()
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            
            Spacer()
            
            bottomActionButtonsView()
        }
        .background(CMColor.backgroundSecondary)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingRemovedPhotos) {
            let removeSections = viewModel.getSectionsForAssetIdentifiers(swipeResultsData.deletedPhotos)
            AIFeatureSwipeDetailView(
                sections: removeSections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: removeSections,
                    type: .similar
                ),
                mode: .resultsView,
                onFinish: { _ in },
                onSwipeDecisionChanged: onSwipeDecisionChanged
            )
        }
        .fullScreenCover(isPresented: $showingKeptPhotos) {
            let savedSections = viewModel.getSectionsForAssetIdentifiers(swipeResultsData.keptPhotos)
            AIFeatureSwipeDetailView(
                sections: savedSections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: savedSections,
                    type: .similar
                ),
                mode: .resultsView,
                onFinish: { _ in  },
                onSwipeDecisionChanged: onSwipeDecisionChanged
            )
        }
    }
    
    // --- setupNavigationBar() ---
    @ViewBuilder
    private func setupNavigationBar() -> some View {
        HStack {
            Button {
                dismissView()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                    Text("Back") // Left as standard
                        .font(.system(size: 17, weight: .regular))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            // **Изменение: Заголовок**
            Text("AI Cleanup Report")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button {
                dismissView()
            } label: {
                // **Изменение: Кнопка "Готово"**
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CMColor.background)
    }
    
    // --- keptSectionView() ---
    @ViewBuilder
    private func keptSectionView() -> some View {
        Button {
            if swipeResultsData.keptCount > 0 {
                showingKeptPhotos = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // **Изменение: Заголовок секции**
                    Text("AI-Kept Photos")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(CMColor.primaryText)
                    
                    // **Изменение: Описание секции**
                    Text("Intelligently preserved by AI scan")
                        .font(.subheadline)
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
                // ... остальная часть кода без изменений
            }
            // ... остальная часть кода без изменений
        }
        .buttonStyle(.plain)
        .disabled(swipeResultsData.keptCount == 0)
    }
    
    // --- removedSectionView() ---
    @ViewBuilder
    private func removedSectionView() -> some View {
        Button {
            if swipeResultsData.deletedCount > 0 {
                showingRemovedPhotos = true
            }
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    // **Изменение: Заголовок секции**
                    Text("AI-Marked for Deletion")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(CMColor.primaryText)
                    
                    // **Изменение: Описание секции**
                    Text("Duplicates & Clutter identified by AI")
                        .font(.subheadline)
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
                // ... остальная часть кода без изменений
            }
            // ... остальная часть кода без изменений
        }
        .buttonStyle(.plain)
        .disabled(swipeResultsData.deletedCount == 0)
    }
    
    // --- bottomActionButtonsView() ---
    @ViewBuilder
    private func bottomActionButtonsView() -> some View {
        VStack(spacing: 16) {
            if swipeResultsData.deletedCount > 0 {
                Button {
                    onFinish(swipeResultsData.deletedPhotos)
                    
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    dismissView()
                } label: {
                    // **Изменение: Кнопка действия**
                    Text("Confirm AI Cleanup (\(swipeResultsData.deletedCount) Items)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [CMColor.primary, CMColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                }
            } else {
                Button {
                    dismissView()
                } label: {
                    // **Изменение: Кнопка, когда нет файлов для удаления**
                    Text("AI Scan Found No Clutter")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(CMColor.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(CMColor.secondaryText.opacity(0.5))
                        .clipShape(Capsule())
                }
                .disabled(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(CMColor.background)
    }
}
