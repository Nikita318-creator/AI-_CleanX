import SwiftUI

/// A horizontal stack that wraps its content to multiple lines when needed
/// Compatible with iOS 15+
public struct WrappingHStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: Content
    
    public init(
        alignment: HorizontalAlignment = .leading,
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }
    
    public var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            content
                .alignmentGuide(.leading, computeValue: { d in
                    if (abs(width - d.width) > geometry.size.width) {
                        width = 0
                        height -= d.height + verticalSpacing
                    }
                    let result = width
                    if width == 0 {
                        width = -horizontalSpacing
                    }
                    width -= d.width + horizontalSpacing
                    return result
                })
                .alignmentGuide(.top, computeValue: { d in
                    let result = height
                    if width == -horizontalSpacing {
                        height -= d.height + verticalSpacing
                    }
                    return result
                })
        }
    }
}

/// A more advanced wrapping stack with better layout control
public struct FlexibleWrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let alignment: HorizontalAlignment
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: (Data.Element) -> Content
    
    public init(
        _ data: Data,
        alignment: HorizontalAlignment = .leading,
        horizontalSpacing: CGFloat = 8,
        verticalSpacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: verticalSpacing) {
            // Простая реализация: показываем элементы в строках по 4 штуки
            let chunkedData = Array(data).chunked(into: 4)
            
            ForEach(chunkedData.indices, id: \.self) { chunkIndex in
                HStack(alignment: .center, spacing: horizontalSpacing) {
                    ForEach(chunkedData[chunkIndex], id: \.self) { item in
                        content(item)
                    }
                    
                    // Добавляем Spacer если нужно выравнивание по левому краю
                    if alignment == .leading {
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// Метод chunked(into:) уже определён в PhotoAnalysisService.swift

/// A simple tag-style wrapping view
public struct TagsWrappingView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    
    public init(
        _ data: Data,
        alignment: HorizontalAlignment = .leading,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                content(item)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > UIScreen.main.bounds.width - 32) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == data.count - 1 {
                            width = 0
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if index == data.count - 1 {
                            height = 0
                        }
                        return result
                    })
            }
        }
    }
}

// MARK: - Convenience Extensions
extension WrappingHStack {
    /// Creates a wrapping stack with default spacing
    public init(
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            alignment: alignment,
            horizontalSpacing: 8,
            verticalSpacing: 8,
            content: content
        )
    }
}

// MARK: - Preview Helpers
#if DEBUG
struct WrappingHStack_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Basic WrappingHStack
            WrappingHStack {
                ForEach(["Short", "Medium Text", "Very Long Text Item", "A", "Another"], id: \.self) { text in
                    Text(text)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .frame(height: 100)
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // FlexibleWrappingHStack with array
            FlexibleWrappingHStack(["Tag 1", "Long Tag Name", "Short", "Medium Length", "A"]) { tag in
                Text(tag)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(16)
            }
            .frame(height: 80)
            .padding()
            .background(Color.gray.opacity(0.1))
            
            // TagsWrappingView
            TagsWrappingView(1...10) { number in
                Text("Item \(number)")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
            }
            .frame(height: 120)
            .padding()
            .background(Color.gray.opacity(0.1))
        }
        .padding()
    }
}
#endif
