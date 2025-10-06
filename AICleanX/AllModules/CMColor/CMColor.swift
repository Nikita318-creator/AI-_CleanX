import SwiftUI

struct CMColor {
    
    // MARK: - Dynamic Color Creation
    private static func dynamicColor(_ name: String) -> Color {
        Color(name)
    }
    
    // MARK: - Primary Colors
    static var primary: Color { dynamicColor("Primary") }
    static var primaryLight: Color { dynamicColor("PrimaryLight") }
    static var primaryDark: Color { dynamicColor("PrimaryDark") }
    static var secondary: Color { dynamicColor("Secondary") }
    static var accent: Color { dynamicColor("Accent") }
    
    // MARK: - Background Colors
    static var background: Color { dynamicColor("Background") }
    static var backgroundSecondary: Color { dynamicColor("BackgroundSecondary") }
    static var surface: Color { dynamicColor("Surface") }
    
    // MARK: - Text Colors
    static var primaryText: Color { dynamicColor("TextPrimary") }
    static var secondaryText: Color { dynamicColor("TextSecondary") }
    static var tertiaryText: Color { dynamicColor("TextTertiary") }
    
    // MARK: - System Colors
    static let white = Color.white
    static let black = Color.black
    static let clear = Color.clear
    
    // MARK: - Status Colors
    static var success: Color { dynamicColor("Success") }
    static var warning: Color { dynamicColor("Warning") }
    static var error: Color { dynamicColor("Error") }

    // MARK: - Icon Colors
    static var iconPrimary: Color { dynamicColor("IconPrimary") }
    static var iconSecondary: Color { dynamicColor("IconSecondary") }
    
    // MARK: - Border Colors
    static var border: Color { dynamicColor("Border") }
    
    // MARK: - Gradients
    static var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [primaryLight, primary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    static var secondaryGradient: LinearGradient {
        LinearGradient(
            colors: [accent, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [background, backgroundSecondary],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Theme-Aware Color Helper
extension View {
    func adaptiveColor(_ color: Color) -> some View {
        self.foregroundColor(color)
    }
    
    func adaptiveBackground(_ color: Color) -> some View {
        self.background(color)
    }
}

private struct ColorPaletteDemo: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("AI-Clean-Space Color Palette")
                    .font(.title.bold())
                    .foregroundColor(CMColor.primaryText)
                
                // Primary Colors
                colorSection("Primary Colors", colors: [
                    ("Primary", CMColor.primary),
                    ("Primary Light", CMColor.primaryLight),
                    ("Primary Dark", CMColor.primaryDark),
                    ("Secondary", CMColor.secondary),
                    ("Accent", CMColor.accent)
                ])
                
                // Background Colors
                colorSection("Background Colors", colors: [
                    ("Background", CMColor.background),
                    ("Background Secondary", CMColor.backgroundSecondary),
                    ("Surface", CMColor.surface)
                ])
                
                // Text Colors
                colorSection("Text Colors", colors: [
                    ("Primary Text", CMColor.primaryText),
                    ("Secondary Text", CMColor.secondaryText),
                    ("Tertiary Text", CMColor.tertiaryText)
                ])
                
                // Status Colors
                colorSection("Status Colors", colors: [
                    ("Success", CMColor.success),
                    ("Warning", CMColor.warning),
                    ("Error", CMColor.error)
                ])
            }
            .padding()
        }
        .background(CMColor.background)
    }
    
    private func colorSection(_ title: String, colors: [(String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(CMColor.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(colors, id: \.0) { name, color in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color)
                            .frame(height: 40)
                        
                        Text(name)
                            .font(.caption)
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
        }
        .padding()
        .background(CMColor.surface)
        .cornerRadius(12)
    }
}
