import SwiftUI
import Combine

struct AIFeatureView: View {
    @StateObject private var viewModel = AIFeatureViewModel()
    @Binding var isPaywallPresented: Bool
    
    @State private var presentedSwipeView: SwipedPhotoModel?
    @State private var presentedResultsView: AICleanResultSwipeData?
    @State private var showSwipeOnboarding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    
                    swipeModeSection()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    
                    categoriesGrid()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                }
            }
            .background(CMColor.background)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(item: $presentedSwipeView) { swipeData in
            AIFeatureSwipeDetailView(
                sections: swipeData.sections,
                initialIndex: 0,
                viewModel: SimilaritySectionsViewModel(
                    sections: swipeData.sections,
                    type: swipeData.type
                ),
                mode: .swipeMode,
                onFinish: { decisions in
                    viewModel.processSwipeDecisions(decisions)
                },
                onShowResults: {
                    presentedSwipeView = nil
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                },
                onSwipeDecisionChanged: {
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(item: $presentedResultsView) { _ in
            AICleanResultSwipeView(
                viewModel: viewModel,
                onFinish: { photosToDelete in
                    viewModel.finalizePhotoDeletion(photosToDelete)
                },
                onSwipeDecisionChanged: {
                    viewModel.updateTotalSwipeDecisionsCount()
                }
            )
        }
        .fullScreenCover(isPresented: $showSwipeOnboarding) {
            SwipeOnboardingView {
                let allSections = [
                    viewModel.getSections(for: .image(.similar)),
                    viewModel.getSections(for: .image(.blurred)),
                    viewModel.getSections(for: .image(.duplicates)),
                    viewModel.getSections(for: .image(.screenshots))
                ].flatMap { $0 }
                
                if !allSections.isEmpty {
                    presentedSwipeView = SwipedPhotoModel(sections: allSections, type: .similar)
                }
            }
        }
    }
    
    // MARK: - Header
        
    @ViewBuilder
    private func headerView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AI-Powered Smart Scan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                // todo PRO
//                Button(action: {
//                    isPaywallPresented = true
//                }) {
//                    HStack(spacing: 8) {
//                        Image(systemName: "star.fill")
//                            .font(.system(size: 16))
//                            .foregroundColor(CMColor.primaryLight)
//                            
//                        Text("Pro")
//                            .fontWeight(.semibold)
//                            .foregroundColor(CMColor.primaryLight)
//                    }
//                    .padding(.horizontal, 16)
//                    .padding(.vertical, 10)
//                    .background(CMColor.backgroundSecondary)
//                    .clipShape(Capsule())
//                }
            }
            
            // **Изменение: Описание Header**
            Text("Our AI algorithms analyze your gallery using advanced technology to find low-quality media and clutter.")
                .font(.subheadline)
                .foregroundColor(CMColor.secondaryText)
        }
        .padding(.top, 12)
    }
        
    @ViewBuilder
    private func swipeModeSection() -> some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(CMColor.backgroundSecondary)
                        .frame(width: 80, height: 80)
                        
                    Image("smartScan")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 70, maxHeight: 70)
                }
                    
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Smart Review")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(CMColor.primaryText)
                        
                    // **Изменение: Описание секции**
                    Text("AI Mode lets you quickly review and confirm selections based on our intelligent scanning recommendations.")
                        .font(.subheadline)
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.leading)
                }
                    
                Spacer()
            }
                
            Button(action: {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    showSwipeOnboarding = true
                }
            }) {
                HStack {
                    Text("Launch AI Review")
                        .fontWeight(.semibold)
                        
                    Spacer()
                        
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(CMColor.primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(CMColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
                
            if viewModel.hasSwipeResults {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                        
                    let resultsData = viewModel.getSwipeResultsData()
                    presentedResultsView = resultsData
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(CMColor.backgroundGradient.opacity(0.2))
                                .frame(width: 50, height: 50)
                                
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(CMColor.backgroundGradient)
                        }
                            
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Your AI Report is Ready")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(CMColor.white)
                                        
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(CMColor.accent.opacity(0.8))
                            }
                                
                            Text("\(viewModel.swipeResultsSummary)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(CMColor.white.opacity(0.9))
                        }
                            
                        Spacer()
                            
                        ZStack {
                            Circle()
                                .fill(CMColor.white.opacity(0.2))
                                .frame(width: 32, height: 32)
                                
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CMColor.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .background(
                        CMColor.primaryGradient
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: CMColor.primaryDark.opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    .shadow(
                        color: CMColor.accent.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
        
    @ViewBuilder
    private func categoriesGrid() -> some View {
        let cardSize = UIScreen.main.bounds.width - 40
            
        VStack(spacing: 16) {
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.similar))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .similar)
                    }
                }
            } label: {
                getItem(
                    for: .similar,
                    // **Изменение: Заголовок секции**
                    title: "AI-Identified Similar Photos",
                    image: viewModel.similarPreview,
                    count: viewModel.similarCount,
                    sizeStr: formatMegabytes(viewModel.similarMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
                
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.blurred))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .blurred)
                    }
                }
            } label: {
                getItem(
                    for: .blurred,
                    // **Изменение: Заголовок секции**
                    title: "AI-Sorted Low-Quality Images",
                    image: viewModel.blurredPreview,
                    count: viewModel.blurredCount,
                    sizeStr: formatMegabytes(viewModel.blurredMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
                
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.duplicates))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .duplicates)
                    }
                }
            } label: {
                getItem(
                    for: .duplicates,
                    // **Изменение: Заголовок секции**
                    title: "AI-Detected Exact Duplicate Files",
                    image: viewModel.duplicatesPreview,
                    count: viewModel.duplicatesCount,
                    sizeStr: formatMegabytes(viewModel.duplicatesMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
                
            Button {
                if !viewModel.hasActiveSubscription {
                    isPaywallPresented = true
                } else {
                    let sections = viewModel.getSections(for: .image(.screenshots))
                    if !sections.isEmpty {
                        presentedSwipeView = SwipedPhotoModel(sections: sections, type: .screenshots)
                    }
                }
            } label: {
                getItem(
                    for: .screenshots,
                    // **Заголовок секции оставлен без изменений**
                    title: "AI-Detected Screenshots",
                    image: viewModel.screenshotsPreview,
                    count: viewModel.screenshotsCount,
                    sizeStr: formatMegabytes(viewModel.screenshotsMegabytes),
                    size: cardSize
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func getItem(
        for type: ScanItemType,
        title: String,
        image: UIImage?,
        count: Int,
        sizeStr: String,
        size: CGFloat
    ) -> some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            } else {
                RoundedRectangle(cornerRadius: 24)
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: size, height: size)
            }
            
            VStack {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(CMColor.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CMColor.surface.opacity(0.8))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    Spacer()
                }
                
                Spacer()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(getItemCountText(count: count))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text(formatMegabytes(viewModel.similarMegabytes))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(CMColor.surface.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Spacer()
                }
            }
            .padding(20)
        }
        .frame(width: size, height: size)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(CMColor.backgroundSecondary)
        )
        .clipped()
        .shadow(color: CMColor.primaryDark.opacity(0.3), radius: 10, x: 0, y: 5)
    }
    
    private func getItemCountText(count: Int) -> String {
        if count == 0 {
            return "No items"
        } else {
            return "\(count) items found"
        }
    }
    
    private func formatMegabytes(_ megabytes: Double) -> String {
        if megabytes < 1 {
            return String(format: "%.1f KB", megabytes * 1024)
        } else if megabytes < 1024 {
            return String(format: "%.0f MB", megabytes)
        } else {
            return String(format: "%.1f GB", megabytes / 1024)
        }
    }
}
