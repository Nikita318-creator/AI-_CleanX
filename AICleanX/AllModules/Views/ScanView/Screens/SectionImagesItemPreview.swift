import SwiftUI
import Photos

struct SectionImagesItemPreview: View {
    let section: AICleanServiceSection
    @State private var selectedIndex: Int
    @ObservedObject var viewModel: SimilaritySectionsViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(section: AICleanServiceSection, initialIndex: Int, viewModel: SimilaritySectionsViewModel) {
        self.section = section
        self._selectedIndex = State(initialValue: initialIndex)
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Bar
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
                    .foregroundColor(CMColor.primary)
                }
                
                Spacer()
                
                Text("\(section.models.count) photos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CMColor.primaryText)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(CMColor.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(CMColor.backgroundSecondary)
            
            // MARK: - Main Content Area
            HStack(spacing: 0) {
                // MARK: - Main Image and Checkbox
                if selectedIndex < section.models.count {
                    let selectedModel = section.models[selectedIndex]
                    
                    ZStack {
                        selectedModel.imageView(size: CGSize(width: 400, height: 400))
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(CMColor.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .clipped()
                        
                        // Checkbox in top-right corner
                        VStack {
                            HStack {
                                Spacer()
                                CheckboxView(isSelected: viewModel.isSelected(selectedModel))
                                    .scaleEffect(1.2)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            viewModel.toggleSelection(for: selectedModel)
                                            if !viewModel.isSelectionMode {
                                                viewModel.isSelectionMode = true
                                            }
                                        }
                                    }
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .background(CMColor.background)
                    .frame(maxWidth: .infinity)
                    .id(selectedModel.asset.localIdentifier)
                }
                
                // MARK: - Vertical Thumbnails ScrollView
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: false) {
                        ScrollViewReader { proxy in
                            VStack(spacing: 8) {
                                ForEach(section.models.indices, id: \.self) { index in
                                    let model = section.models[index]
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedIndex = index
                                        }
                                    } label: {
                                        ZStack {
                                            model.imageView(size: CGSize(width: 70, height: 70))
                                                .frame(width: 70, height: 70)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            if viewModel.isSelected(model) {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        CheckboxView(isSelected: true)
                                                            .scaleEffect(0.8)
                                                    }
                                                    Spacer()
                                                }
                                                .padding(6)
                                            }
                                        }
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    selectedIndex == index ? CMColor.primary : CMColor.clear,
                                                    lineWidth: 3
                                                )
                                        )
                                        .scaleEffect(selectedIndex == index ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: selectedIndex)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .id(index)
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                            .onAppear {
                                proxy.scrollTo(selectedIndex, anchor: .center)
                            }
                            .onChange(of: selectedIndex) { newIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .background(CMColor.backgroundSecondary)
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .background(CMColor.backgroundSecondary)
        .navigationBarHidden(true)
    }
}
