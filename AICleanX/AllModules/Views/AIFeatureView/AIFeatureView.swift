import SwiftUI
import Combine

struct AIFeatureView: View {
    @StateObject private var viewModel = AIFeatureViewModel()
    @Binding var isPaywallPresented: Bool
    
    // 👈 НОВЫЙ БИНДИНГ ДЛЯ ЗАКРЫТИЯ ТЕКУЩЕГО ЭКРАНА
    @Binding var isSwipeModePresented: Bool
    
    @Environment(\.dismiss) var dismiss

    @State private var presentedSwipeView: SwipedPhotoModel?
    @State private var presentedResultsView: AICleanResultSwipeData?
    @State private var showSwipeOnboarding = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    headerView()
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    
                    smartReviewCard()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                    
                    if viewModel.hasSwipeResults {
                        resultsReadyCard()
                            .padding(.horizontal, 24)
                            .padding(.bottom, 28)
                    }
                    
                    categoriesSection()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 140)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        CMColor.background,
                        CMColor.background.opacity(0.98),
                        CMColor.backgroundSecondary.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
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
        // ... (код headerView остается прежним)
        VStack(alignment: .leading, spacing: 16) {
            
            // MARK: - Header with Back Button (Стилизовано по вашему примеру)
            HStack {
                Button(action: {
                    // Действие: закрывает текущий экран
                    dismiss()
                }) {
                    HStack(spacing: 6) { // Используем 6 для spacing
                        Image(systemName: "chevron.left") // Стрелка "назад"
                            .font(.system(size: 17, weight: .semibold)) // Размер 17, жирный
                            .foregroundColor(CMColor.primary) // Цвет CMColor.primary
                            
                        Text("Go Back") // Текст "Go Back" (как в вашем примере)
                            .font(.system(size: 17, weight: .regular)) // Размер 17, обычный
                            .foregroundColor(CMColor.primary) // Цвет CMColor.primary
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer() // Отправляет кнопку влево
            }
            .padding(.top, 0) // Отступ сверху для отступа от края Safe Area
            .padding(.bottom, 6) // Отступ между кнопкой и заголовком
            
            // Оригинальный блок заголовка (начинается под кнопкой)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CMColor.primary, CMColor.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            
                        Text("AI Gallery Intelligence")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(CMColor.primaryText)
                    }
                }
            }
            
            // Оригинальный блок описания
            Text("AI analyze your photos to detect clutter, duplicates, and low-quality content instantly")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(CMColor.secondaryText.opacity(0.85))
                .lineSpacing(4)
        }
    }
        
    @ViewBuilder
    private func smartReviewCard() -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    CMColor.primary.opacity(0.15),
                                    CMColor.accent.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Image("AIScanImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                }
                    
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Review")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(CMColor.primaryText)
                        
                    Text("Swipe through AI suggestions and confirm what to keep or remove")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                        .lineSpacing(2)
                }
                    
                Spacer(minLength: 0)
            }
            .padding(20)
            
            Divider()
                .background(CMColor.secondaryText.opacity(0.1))
            
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
//                if !viewModel.hasActiveSubscription {
//                    // 👇 НОВОЕ ИСПРАВЛЕНИЕ: Закрываем текущий экран перед открытием Paywall
//                    isSwipeModePresented = false
//                    
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                        isPaywallPresented = true
//                    }
//                } else {
                    showSwipeOnboarding = true
//                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CMColor.primary, CMColor.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Start AI Review")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                        
                    Spacer()
                        
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CMColor.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .background(CMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: CMColor.primaryDark.opacity(0.08), radius: 20, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(CMColor.secondaryText.opacity(0.06), lineWidth: 1)
        )
    }
    
    // ... (код resultsReadyCard остается прежним)
    @ViewBuilder
    private func resultsReadyCard() -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
                
            let resultsData = viewModel.getSwipeResultsData()
            presentedResultsView = resultsData
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(CMColor.white.opacity(0.25))
                        .frame(width: 56, height: 56)
                        
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.white)
                }
                    
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Review Complete")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(CMColor.white)
                            
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CMColor.white.opacity(0.9))
                    }
                        
                    Text(viewModel.swipeResultsSummary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CMColor.white.opacity(0.85))
                }
                    
                Spacer()
                    
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(CMColor.white.opacity(0.9))
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        CMColor.primary,
                        CMColor.primaryDark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: CMColor.primary.opacity(0.35), radius: 20, x: 0, y: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [CMColor.white.opacity(0.3), CMColor.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
        
    @ViewBuilder
    private func categoriesSection() -> some View {
        // ... (код categoriesSection остается прежним)
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Detection Categories")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 14) {
                categoryCard(
                    icon: "photo.stack.fill",
                    iconGradient: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                    title: "Similar Photos",
                    subtitle: "AI-grouped visual matches",
                    image: viewModel.similarPreview,
                    count: viewModel.similarCount,
                    size: formatMegabytes(viewModel.similarMegabytes),
                    type: .similar
                )
                
                categoryCard(
                    icon: "eye.slash.fill",
                    iconGradient: [Color(hex: "F093FB"), Color(hex: "F5576C")],
                    title: "Blurry & Low Quality",
                    subtitle: "Neural clarity detection",
                    image: viewModel.blurredPreview,
                    count: viewModel.blurredCount,
                    size: formatMegabytes(viewModel.blurredMegabytes),
                    type: .blurred
                )
                
                categoryCard(
                    icon: "doc.on.doc.fill",
                    iconGradient: [Color(hex: "4FACFE"), Color(hex: "00F2FE")],
                    title: "Exact Duplicates",
                    subtitle: "Byte-level comparison",
                    image: viewModel.duplicatesPreview,
                    count: viewModel.duplicatesCount,
                    size: formatMegabytes(viewModel.duplicatesMegabytes),
                    type: .duplicates
                )
                
                categoryCard(
                    icon: "rectangle.on.rectangle.fill",
                    iconGradient: [Color(hex: "FA709A"), Color(hex: "FEE140")],
                    title: "Screenshots",
                    subtitle: "UI pattern recognition",
                    image: viewModel.screenshotsPreview,
                    count: viewModel.screenshotsCount,
                    size: formatMegabytes(viewModel.screenshotsMegabytes),
                    type: .screenshots
                )
            }
        }
    }
    
    @ViewBuilder
    private func categoryCard(
        icon: String,
        iconGradient: [Color],
        title: String,
        subtitle: String,
        image: UIImage?,
        count: Int,
        size: String,
        type: ScanItemType
    ) -> some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            
            // todo не нужен пейвол тут
//            if !viewModel.hasActiveSubscription {
//                isSwipeModePresented = false
//                
////                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    isPaywallPresented = true
////                }
//                return
//            } else {
                let actualType: AICleanServiceType.ImageType
                if type == .blurred {
                    actualType = .blurred
                } else if type == .duplicates {
                    actualType = .duplicates
                } else if type == .similar {
                    actualType = .similar
                } else if type == .screenshots {
                    actualType = .screenshots
                } else {
                    actualType = .similar
                }
                    
                let sections = viewModel.getSections(for: .image(actualType))
                if !sections.isEmpty {
                    presentedSwipeView = SwipedPhotoModel(sections: sections, type: type)
                }
//            }
        } label: {
            // ... (остальной код categoryCard остается прежним)
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradient.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: iconGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                    
                    HStack(spacing: 12) {
                        Label {
                            Text("\(count)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CMColor.secondaryText)
                        } icon: {
                            Image(systemName: "photo")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CMColor.secondaryText.opacity(0.7))
                        }
                        
                        Label {
                            Text(size)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(CMColor.secondaryText)
                        } icon: {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(CMColor.secondaryText.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                // Thumbnail or Arrow
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(CMColor.secondaryText.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CMColor.secondaryText.opacity(0.4))
                }
            }
            .padding(18)
            .background(CMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: CMColor.primaryDark.opacity(0.06), radius: 12, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(CMColor.secondaryText.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // ... (formatMegabytes остается прежним)
    private func formatMegabytes(_ megabytes: Double) -> String {
        if megabytes < 1 {
            return String(format: "%.0f KB", megabytes * 1024)
        } else if megabytes < 1024 {
            return String(format: "%.0f MB", megabytes)
        } else {
            return String(format: "%.1f GB", megabytes / 1024)
        }
    }
}
