import SwiftUI
import Photos

struct SimilaritySectionsView: View {
    @StateObject private var viewState: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var viewDismiss
    @State private var chosenSection: AICleanServiceSection?
    @State private var chosenImageIndex: Int = 0
    
    // ВРЕМЕННОЕ РЕШЕНИЕ: В идеале isSelectionMode должен быть @Published в SimilaritySectionsViewModel
    // Если ViewModel уже имеет isSelectionMode, удалите эту строку и замените viewState.isSelectionMode на isSelectionMode.
    @State private var isLocalSelectionMode: Bool = false
    
    private let galleryColumns: [GridItem] = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    init(viewModel: SimilaritySectionsViewModel) {
        _viewState = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // MARK: - Navigation Bar
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Кнопка Dismiss / Cancel
                    Button {
                        // Если в режиме выбора, то это Cancel
                        if isLocalSelectionMode { // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode, если оно есть в ViewModel
                            withAnimation(.easeInOut) {
                                viewState.deselectAll()
                                isLocalSelectionMode = false // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode, если оно есть в ViewModel
                            }
                        } else {
                            // Иначе - закрываем View
                            viewDismiss()
                        }
                    } label: {
                        let imageName = isLocalSelectionMode ? "xmark" : "xmark.circle.fill" // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                        Image(systemName: imageName)
                            .font(.system(size: isLocalSelectionMode ? 18 : 28, weight: isLocalSelectionMode ? .semibold : .regular)) // Уменьшаем размер иконки "Cancel"
                            .foregroundColor(CMColor.secondaryText)
                            .animation(.easeInOut, value: isLocalSelectionMode) // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                    }

                    Spacer()

                    Text(viewState.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(CMColor.white)
                    
                    Spacer()

                    // Кнопка Select / Done
                    Button {
                        if isLocalSelectionMode { // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                            // Если уже в режиме выбора и есть выделенные элементы, то это "Done" или просто неактивная кнопка.
                            // Для простоты, оставим ее для входа в режим выбора / или выхода
                            withAnimation(.easeInOut) {
                                viewState.deselectAll()
                                isLocalSelectionMode = false // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                            }
                        } else {
                            // Вход в режим выбора
                            withAnimation(.easeInOut) {
                                isLocalSelectionMode = true // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                            }
                        }
                    } label: {
                        Text(isLocalSelectionMode ? "Cancel" : "Select") // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(CMColor.primary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(CMColor.backgroundSecondary)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            
                // MARK: - Scrollable Content
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        ForEach(viewState.sections.indices, id: \.self) { index in
                            createSectionView(for: viewState.sections[index])
                        }
                    }
                    .padding(12)
                    .padding(.bottom, viewState.hasSelectedItems ? 120 : 0)
                }
                .background(CMColor.background)
            }
            .background(CMColor.background)
            .ignoresSafeArea(.all, edges: .bottom)

            // MARK: - Floating Delete Button
            VStack {
                Spacer()
                if viewState.hasSelectedItems {
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewState.deleteSelected()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text("Delete \(viewState.selectedCount) item\(viewState.selectedCount == 1 ? "" : "s")")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(CMColor.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [CMColor.error.opacity(0.8), CMColor.error]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: CMColor.error.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 32)
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewState.hasSelectedItems)
        }
        .fullScreenCover(item: $chosenSection) { section in
            if viewState.type == .videos {
                SectionVideosItemPreview(
                    section: section,
                    initialIndex: chosenImageIndex,
                    viewModel: viewState
                )
            } else {
                SectionImagesItemPreview(
                    section: section,
                    initialIndex: chosenImageIndex,
                    viewModel: viewState
                )
            }
        }
    }
    
    // ---
    // MARK: - Section View
    // ---

    private func createSectionView(for section: AICleanServiceSection) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header
            HStack {
                switch section.kind {
                case .count:
                    Text("\(section.models.count) items")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                case .date(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                case .united(let date):
                    Text(date?.formatAsShortDate() ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(CMColor.secondaryText)
                }

                Spacer()
                
                // Кнопка Select all / Deselect all внутри секции
                if isLocalSelectionMode { // << Активируем кнопку только в режиме выбора
                    Button {
                        withAnimation(.easeInOut) {
                            if viewState.isAllSelectedInSection(section) {
                                viewState.deselectAllInSection(section)
                            } else {
                                viewState.selectAllInSection(section)
                            }
                        }
                    } label: {
                        Text(viewState.isAllSelectedInSection(section) ? "Deselect all" : "Select all")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(viewState.isAllSelectedInSection(section) ? CMColor.error : CMColor.primary)
                    }
                }
            }
            
            // Grid layout
            VStack(alignment: .leading, spacing: 8) {
                if viewState.type == .duplicates || viewState.type == .similar {
                    if let firstModel = section.models.first {
                        createPrimaryItemView(for: firstModel, section: section, index: 0)
                            .padding(.top, 24)
                    }
                }

                let remainingModels = viewState.type == .duplicates || viewState.type == .similar ? Array(section.models.suffix(from: 1)) : section.models
                
                LazyVGrid(columns: galleryColumns, spacing: 8) {
                    ForEach(remainingModels.indices, id: \.self) { index in
                        let model = remainingModels[index]
                        let actualIndex = (viewState.type == .duplicates || viewState.type == .similar) ? index + 1 : index
                        createGalleryItemView(for: model, section: section, index: actualIndex)
                    }
                }
            }
        }
        .padding(16)
        .background(CMColor.surface)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    // ---
    // MARK: - Primary Item View
    // ---
    
    private func createPrimaryItemView(for model: AICleanServiceModel, section: AICleanServiceSection, index: Int) -> some View {
        let isSelected = viewState.isSelected(model)
        let cornerRadius: CGFloat = 16
        let itemSize: CGFloat = 176
        
        return ZStack(alignment: .topLeading) {
            model.imageView(size: CGSize(width: itemSize, height: itemSize))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CMColor.primary, lineWidth: isSelected ? 3 : 0)
                )
            
            // "Best" icon
            if viewState.type == .duplicates || viewState.type == .similar {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(CMColor.primary)
                    .font(.system(size: 24))
                    .shadow(radius: 2)
                    .padding(8)
            }

            if viewState.type == .videos {
                VStack {
                    Spacer()
                    HStack {
                        Text(model.formattedDuration)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(CMColor.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                    }
                }
                .padding(8)
            }
            
            // Selection overlay and Checkbox
            Group {
                if isSelected {
                    Color.black.opacity(0.6)
                        .cornerRadius(cornerRadius)
                }
                
                CheckboxView(isSelected: isSelected)
                    .padding(8)
            }
            .frame(width: itemSize, height: itemSize, alignment: .topTrailing)
            // ИЗМЕНЕНИЕ: Теперь показываем чекбокс только если isSelected ИЛИ в режиме выбора
            .opacity(isSelected || isLocalSelectionMode ? 1.0 : 0.0) // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isLocalSelectionMode) // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
        }
        .frame(width: itemSize, height: itemSize)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onTapGesture {
            // ИЗМЕНЕНИЕ: Одиночный тап в режиме выбора включает/выключает выделение
            if isLocalSelectionMode { // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                viewState.toggleSelection(for: model)
            } else {
                chosenImageIndex = index
                chosenSection = section
            }
        }
        .onLongPressGesture {
            // ИЗМЕНЕНИЕ: Долгое нажатие активирует режим выбора И выделяет элемент
            withAnimation(.easeInOut(duration: 0.2)) {
                isLocalSelectionMode = true // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                viewState.toggleSelection(for: model)
            }
        }
    }

    // ---
    // MARK: - Gallery Item View
    // ---

    private func createGalleryItemView(for model: AICleanServiceModel, section: AICleanServiceSection, index: Int) -> some View {
        let isSelected = viewState.isSelected(model)
        let cornerRadius: CGFloat = 8
        let itemSize: CGFloat = 80
        
        return ZStack {
            model.imageView(size: CGSize(width: itemSize, height: itemSize))
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(CMColor.primary, lineWidth: isSelected ? 3 : 0)
                )
            
            if viewState.type == .videos {
                VStack {
                    Spacer()
                    HStack {
                        Text(model.formattedDuration)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(CMColor.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(CMColor.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Spacer()
                    }
                }
                .padding(4)
            }
            
            // Selection overlay and Checkbox
            Group {
                if isSelected {
                    Color.black.opacity(0.6)
                        .cornerRadius(cornerRadius)
                }
                
                CheckboxView(isSelected: isSelected)
                    .padding(4)
            }
            .frame(width: itemSize, height: itemSize, alignment: .topTrailing)
            // ИЗМЕНЕНИЕ: Теперь показываем чекбокс только если isSelected ИЛИ в режиме выбора
            .opacity(isSelected || isLocalSelectionMode ? 1.0 : 0.0) // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
            .animation(.easeInOut(duration: 0.2), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isLocalSelectionMode) // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
        }
        .frame(width: itemSize, height: itemSize)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .clipped()
        .onTapGesture {
            // ИЗМЕНЕНИЕ: Одиночный тап в режиме выбора включает/выключает выделение
            if isLocalSelectionMode { // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                viewState.toggleSelection(for: model)
            } else {
                chosenImageIndex = index
                chosenSection = section
            }
        }
        .onLongPressGesture {
            // ИЗМЕНЕНИЕ: Долгое нажатие активирует режим выбора И выделяет элемент
            withAnimation(.easeInOut(duration: 0.2)) {
                isLocalSelectionMode = true // << ИСПОЛЬЗУЙТЕ viewState.isSelectionMode
                viewState.toggleSelection(for: model)
            }
        }
    }
}

// MARK: - Checkbox View (Остается без изменений)
struct CheckboxView: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? CMColor.primary : CMColor.clear)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(isSelected ? CMColor.primary : CMColor.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(CMColor.white)
                    .scaleEffect(isSelected ? 1.0 : 0.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
