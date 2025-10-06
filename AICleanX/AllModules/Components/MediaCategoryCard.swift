import SwiftUI

struct MediaCategoryCard: View {
    let title: String
    let itemCount: String
    let backgroundColor: Color
    let isFullWidth: Bool
    let isScanning: Bool
    let onTap: () -> Void // Новое свойство для действия по тапу

    init(title: String, itemCount: String, backgroundColor: Color, isFullWidth: Bool = false, isScanning: Bool = false, onTap: @escaping () -> Void) {
        self.title = title
        self.itemCount = itemCount
        self.backgroundColor = backgroundColor
        self.isFullWidth = isFullWidth
        self.isScanning = isScanning
        self.onTap = onTap
    }
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24 * scalingFactor)
                    .fill(backgroundColor)
                    .frame(
                        width: isFullWidth ? nil : 168 * scalingFactor,
                        height: isFullWidth ? 220 * scalingFactor : 168 * scalingFactor
                    )
                
                // Background pattern for empty categories
                if itemCount.contains("No items") {
                    backgroundPattern
                }
                
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8 * scalingFactor) {
                        // Item count badge
                        HStack {
                            Text(itemCount)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                                .padding(.horizontal, 12 * scalingFactor)
                                .padding(.vertical, 8 * scalingFactor)
                                .background(CMColor.white)
                                .clipShape(RoundedRectangle(cornerRadius: 24 * scalingFactor))
                            
                            Spacer()
                        }
                        
                        // Title badge
                        HStack {
                            Text(title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(CMColor.white)
                                .padding(.horizontal, 8 * scalingFactor)
                                .padding(.vertical, 4 * scalingFactor)
                                .background(CMColor.secondaryText.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 24 * scalingFactor))
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 10 * scalingFactor)
                    .padding(.bottom, isFullWidth ? 12 * scalingFactor : 10 * scalingFactor)
                }
                
                // Scanning overlay
                if isScanning {
                    scanningOverlay
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isScanning ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isScanning)
    }
    
    // MARK: - Background Pattern
    private var backgroundPattern: some View {
        ZStack {
            // Pattern elements for empty state
            VStack {
                HStack {
                    Circle()
                        .fill(CMColor.primaryLight.opacity(0.4))
                        .frame(width: 20 * scalingFactor, height: 20 * scalingFactor)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 4 * scalingFactor)
                        .fill(CMColor.primaryLight.opacity(0.4))
                        .frame(width: 30 * scalingFactor, height: 15 * scalingFactor)
                }
                
                Spacer()
                
                HStack {
                    RoundedRectangle(cornerRadius: 6 * scalingFactor)
                        .fill(CMColor.primaryLight.opacity(0.4))
                        .frame(width: 40 * scalingFactor, height: 25 * scalingFactor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(CMColor.primaryLight.opacity(0.4))
                        .frame(width: 15 * scalingFactor, height: 15 * scalingFactor)
                }
            }
            .padding(20 * scalingFactor)
        }
    }
    
    // MARK: - Scanning Overlay
    private var scanningOverlay: some View {
        ZStack {
            // Semi-transparent overlay
            RoundedRectangle(cornerRadius: 24 * scalingFactor)
                .fill(CMColor.white.opacity(0.1))
            
            // Animated dots or scanning indicator
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Simple scanning animation
                    HStack(spacing: 4 * scalingFactor) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(CMColor.primary)
                                .frame(width: 6 * scalingFactor, height: 6 * scalingFactor)
                                .scaleEffect(isScanning ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: isScanning
                                )
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
}

struct ServiceCategoryCard: View {
    let title: String
    let subtitle: String
    let itemCount: String
    let isScanning: Bool
    let onTap: () -> Void // Новое свойство для действия по тапу

    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24 * scalingFactor)
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 168 * scalingFactor, height: 168 * scalingFactor)
                
                VStack(alignment: .leading, spacing: 8 * scalingFactor) {
                    // Item count badge
                    HStack {
                        Text(itemCount)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                            .padding(.horizontal, 12 * scalingFactor)
                            .padding(.vertical, 8 * scalingFactor)
                            .background(CMColor.white)
                            .clipShape(RoundedRectangle(cornerRadius: 24 * scalingFactor))
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8 * scalingFactor) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text(subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CMColor.secondaryText)
                    }
                    
                    HStack {
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(hex: "#D5D8DD"))
                    }
                }
                .padding(.horizontal, 10 * scalingFactor)
                .padding(.vertical, 17 * scalingFactor)
                
                // Scanning overlay
                if isScanning {
                    scanningOverlay
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isScanning ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isScanning)
    }
    
    // MARK: - Scanning Overlay
    private var scanningOverlay: some View {
        ZStack {
            // Semi-transparent overlay
            RoundedRectangle(cornerRadius: 24 * scalingFactor)
                .fill(CMColor.white.opacity(0.1))
            
            // Simple scanning animation
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    HStack(spacing: 4 * scalingFactor) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(CMColor.primary)
                                .frame(width: 6 * scalingFactor, height: 6 * scalingFactor)
                                .scaleEffect(isScanning ? 1.0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                    value: isScanning
                                )
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            MediaCategoryCard(
                title: "Similar",
                itemCount: "14 photos • 34 Mb",
                backgroundColor: CMColor.surface,
                isScanning: true,
                onTap: { }
            )
            
            ServiceCategoryCard(
                title: "Contacts",
                subtitle: "Delete & merge contacts",
                itemCount: "142 items",
                isScanning: false,
                onTap: { }
            )
        }
        
        MediaCategoryCard(
            title: "Videos",
            itemCount: "67 Items • 1.3 Gb",
            backgroundColor: CMColor.surface,
            isFullWidth: true,
            isScanning: false,
            onTap: { }
        )
    }
    .padding()
    .background(CMColor.background)
}
