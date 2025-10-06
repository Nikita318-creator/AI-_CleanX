import SwiftUI
import PhotosUI

struct PhotosViewLegacy: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var safeStorageManager: SafeStorageManager
    @State private var searchText: String = ""
    @State private var isSelectionMode: Bool = false
    @State private var selectedPhotos: Set<UUID> = []
    @FocusState private var isSearchFocused: Bool
    @State private var showImagePicker = false
    
    private var photos: [SafePhotoData] {
        safeStorageManager.loadAllPhotos()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            VStack(spacing: 0) {
                // Header (same as iOS 16+ version)
                headerView(scalingFactor: scalingFactor)
                
                if photos.isEmpty {
                    emptyStateView(scalingFactor: scalingFactor)
                } else {
                    photosContentView(scalingFactor: scalingFactor)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
    }
    
    // Similar implementation methods as iOS 16+ version but without PhotosPicker
    private func headerView(scalingFactor: CGFloat) -> some View {
        // Same implementation as iOS 16+ version
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 4 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Media")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Photos")
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !photos.isEmpty {
                Button(action: {
                    isSelectionMode.toggle()
                    if !isSelectionMode {
                        selectedPhotos.removeAll()
                    }
                }) {
                    HStack(spacing: 4 * scalingFactor) {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 6 * scalingFactor, height: 6 * scalingFactor)
                        Text("Select")
                            .font(.system(size: 16 * scalingFactor))
                            .foregroundColor(CMColor.primary)
                    }
                }
            } else {
                Spacer().frame(width: 60 * scalingFactor)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
    }
    
    private func emptyStateView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            // Empty state icon
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scalingFactor, height: 120 * scalingFactor)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("No photos yet")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first photo to get started")
                    .font(.system(size: 16 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Add photo button (using legacy approach)
            Button(action: {
                showImagePicker = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Add photo")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scalingFactor)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scalingFactor)
            }
            .padding(.horizontal, 40 * scalingFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func photosContentView(scalingFactor: CGFloat) -> some View {
        // Simplified content view for iOS 15
        Text("Photos view for iOS 15")
            .font(.system(size: 16 * scalingFactor))
            .foregroundColor(CMColor.primaryText)
    }
}

