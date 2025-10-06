import SwiftUI
import Photos

struct SimilarityPhotoDetailView: View {
    let section: AICleanServiceSection
    let initialIndex: Int
    @ObservedObject var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedIndex: Int
    @State private var dragOffset: CGFloat = 0
    
    init(section: AICleanServiceSection, initialIndex: Int, viewModel: SimilaritySectionsViewModel) {
        self.section = section
        self.initialIndex = initialIndex
        self.viewModel = viewModel
        self._selectedIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Back")
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("\(section.models.count) photos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                Spacer()
                
                Button {
                    // Done action - можно добавить логику сохранения
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CMColor.backgroundSecondary)
            
            // Main Image Display
            GeometryReader { geometry in
                TabView(selection: $selectedIndex) {
                    ForEach(section.models.indices, id: \.self) { index in
                        let model = section.models[index]
                        
                        ZStack {
                            // Main image
                            model.imageView(size: CGSize(width: geometry.size.width, height: geometry.size.height * 0.8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                            
                            // Checkbox overlay
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.toggleSelection(for: model)
                                            if !viewModel.isSelectionMode {
                                                viewModel.isSelectionMode = true
                                            }
                                        }
                                    } label: {
                                        CheckboxView(isSelected: viewModel.isSelected(model))
                                            .scaleEffect(1.2) // Larger for easier tapping
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                Spacer()
                            }
                            .padding(20)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .background(Color.black)
            }
            
            // Bottom Thumbnail Slider
            VStack(spacing: 12) {
                // Thumbnail ScrollView
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(section.models.indices, id: \.self) { index in
                                let model = section.models[index]
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        selectedIndex = index
                                    }
                                } label: {
                                    ZStack {
                                        // Thumbnail image
                                        model.imageView(size: CGSize(width: 60, height: 60))
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        selectedIndex == index ? Color.blue : Color.clear,
                                                        lineWidth: 3
                                                    )
                                            )
                                        
                                        // Checkbox for thumbnail
                                        VStack {
                                            HStack {
                                                Spacer()
                                                
                                                Button {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        viewModel.toggleSelection(for: model)
                                                        if !viewModel.isSelectionMode {
                                                            viewModel.isSelectionMode = true
                                                        }
                                                    }
                                                } label: {
                                                    CheckboxView(isSelected: viewModel.isSelected(model))
                                                        .scaleEffect(0.7)
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                            Spacer()
                                        }
                                        .padding(2)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .onChange(of: selectedIndex) { newIndex in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .frame(height: 80)
                
                // Delete Button (if items selected)
                if viewModel.hasSelectedItems {
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            viewModel.deleteSelected()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                            Text("Delete \(viewModel.selectedCount) item\(viewModel.selectedCount == 1 ? "" : "s")")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
                }
            }
            .padding(.bottom, 34) // Safe area bottom
            .background(CMColor.backgroundSecondary)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.hasSelectedItems)
        }
        .background(Color.black)
        .navigationBarHidden(true)
    }
}

// MARK: - Preview
#if DEBUG
struct SimilarityPhotoDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview would need mock data
        Text("SimilarityPhotoDetailView Preview")
    }
}
#endif
