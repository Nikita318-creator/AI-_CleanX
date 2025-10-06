import SwiftUI

struct SwipeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            navigationBarView()
            
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 40)
                    
                    imageView()
                    
                    textContent()
                    
                    Spacer()
                        .frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
            
            Spacer()
            
            startButton()
        }
        .background(CMColor.backgroundSecondary)
        .navigationBarHidden(true)
    }
        
    @ViewBuilder
    private func navigationBarView() -> some View {
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
            
            Text("Swipe Mode")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("Back")
                    .font(.system(size: 17, weight: .regular))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CMColor.background)
    }
        
    @ViewBuilder
    private func imageView() -> some View {
        ZStack {
            Circle()
                .fill(CMColor.backgroundSecondary.opacity(0.3))
                .frame(width: 320, height: 320)
                .blur(radius: 20)
            
            Image("smartScan")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 280, height: 280)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(CMColor.background)
                        .shadow(color: CMColor.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }
        
    @ViewBuilder
    private func textContent() -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("Swipe the photo to decide their fate:")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(CMColor.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("right - keep, left - delete.")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Text("Organize your gallery in seconds.")
                .font(.body)
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
        
    @ViewBuilder
    private func startButton() -> some View {
        VStack(spacing: 0) {
            Button {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                onStart()
                dismiss()
            } label: {
                Text("Start")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(CMColor.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [CMColor.primary, CMColor.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: CMColor.primary.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .background(
            Rectangle()
                .fill(CMColor.surface)
                .ignoresSafeArea()
        )
    }
}
