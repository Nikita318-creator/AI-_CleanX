
import SwiftUI
import Photos

struct SimilarView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var picsAnalyserService = PicsAnalyserService()
    
    let mode: SimilarPhotosMode
    
    @State private var selectedPhotos = Set<UUID>()
    @State private var isLoading = true
    @State private var hasRequestedPermission = false
    
    init(mode: SimilarPhotosMode = .similar) {
        self.mode = mode
    }
    
    private var photoGroups: [PhotoGroupModel] {
        switch mode {
        case .duplicates:
            return picsAnalyserService.duplicateGroups
        case .similar:
            return picsAnalyserService.similarGroups
        }
    }

    var totalSelectedCount: Int {
        selectedPhotos.count
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                if isLoading {
                    loadingView
                } else if photoGroups.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
                
                if totalSelectedCount > 0 {
                    Button(action: {
                        mergeSelectedPhotos()
                    }) {
                        Text("Merge \(totalSelectedCount) items")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(CMColor.primary)
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .shadow(color: .black.opacity(0.2), radius: 5)
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .foregroundColor(CMColor.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !photoGroups.isEmpty {
                        Button("Select All") {
                            if totalSelectedCount == allPhotosCount() {
                                selectedPhotos.removeAll()
                            } else {
                                selectAllPhotos()
                            }
                        }
                        .foregroundColor(CMColor.primary)
                    }
                }
            }
        }
        .onAppear {
            requestPhotoPermissionAndLoadPhotos()
        }
    }

    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(picsAnalyserService.isAnalyzing ? "Analyzing photos..." : "Loading photos...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
            
            if picsAnalyserService.isAnalyzing {
                ProgressView(value: picsAnalyserService.analysisProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CMColor.background)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: mode == .duplicates ? "doc.on.doc" : "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(CMColor.secondaryText)
            
            Text(mode == .duplicates ? "No duplicates found" : "No similar photos found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Text(mode == .duplicates ? 
                 "Great! Your photo library doesn't contain any duplicate images." :
                 "Your photos are all unique with no similar images detected.")
                .font(.system(size: 16))
                .foregroundColor(CMColor.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CMColor.background)
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(photoGroups) { group in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(CMColor.primaryText)
                                
                                Text(group.displaySize)
                                    .font(.system(size: 14))
                                    .foregroundColor(CMColor.secondaryText)
                            }
                            
                            Spacer()
                            
                            Button("Select all") {
                                selectAllPhotos(in: group)
                            }
                            .foregroundColor(CMColor.primary)
                        }

                        let bestPhoto = group.photos.first(where: { $0.isBest })
                        let otherPhotos = group.photos.filter { !$0.isBest }

                        HStack(alignment: .top, spacing: 8) {
                            if let bestPhoto = bestPhoto {
                                PhotoAssetItemView(
                                    photo: bestPhoto,
                                    isSelected: selectedPhotos.contains(bestPhoto.id)
                                ) {
                                    toggleSelection(for: bestPhoto)
                                }
                                .frame(width: 160, height: 160)
                            }

                            if !otherPhotos.isEmpty {
                                VStack(spacing: 8) {
                                    let rows = otherPhotos.chunked(into: 2)
                                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowPhotos in
                                        HStack(spacing: 8) {
                                            ForEach(rowPhotos) { photo in
                                                PhotoAssetItemView(
                                                    photo: photo,
                                                    isSelected: selectedPhotos.contains(photo.id)
                                                ) {
                                                    toggleSelection(for: photo)
                                                }
                                                .frame(width: 76, height: 76)
                                            }
                                            
                                            if rowPhotos.count == 1 {
                                                Spacer()
                                                    .frame(width: 76, height: 76)
                                            }
                                        }
                                    }
                                    
                                    let maxRows = 2
                                    let currentRows = rows.count
                                    if currentRows < maxRows {
                                        ForEach(currentRows..<maxRows, id: \.self) { _ in
                                            HStack(spacing: 8) {
                                                Spacer()
                                                    .frame(width: 76, height: 76)
                                                Spacer()
                                                    .frame(width: 76, height: 76)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
        .background(CMColor.background)
    }
    
    private func requestPhotoPermissionAndLoadPhotos() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.loadPhotos()
                case .denied, .restricted:
                    self.isLoading = false
                case .notDetermined:
                    break
                @unknown default:
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadPhotos() {
        Task {
            switch mode {
            case .duplicates:
                await picsAnalyserService.findDuplicatePhotos()
            case .similar:
                await picsAnalyserService.findSimilarPhotos()
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func toggleSelection(for photo: PhotoAssetModel) {
        if selectedPhotos.contains(photo.id) {
            selectedPhotos.remove(photo.id)
        } else {
            selectedPhotos.insert(photo.id)
        }
    }

    private func selectAllPhotos(in group: PhotoGroupModel) {
        let groupPhotoIDs = Set(group.photos.map { $0.id })
        if selectedPhotos.intersection(groupPhotoIDs).count == groupPhotoIDs.count {
            selectedPhotos.subtract(groupPhotoIDs)
        } else {
            selectedPhotos.formUnion(groupPhotoIDs)
        }
    }

    private func selectAllPhotos() {
        var allIDs = Set<UUID>()
        for group in photoGroups {
            allIDs.formUnion(group.photos.map { $0.id })
        }
        selectedPhotos = allIDs
    }

    private func allPhotosCount() -> Int {
        photoGroups.reduce(0) { $0 + $1.photos.count }
    }
    
    private func mergeSelectedPhotos() {
        let selectedAssets = photoGroups.flatMap { $0.photos }
            .filter { selectedPhotos.contains($0.id) && !$0.isBest }
            .map { $0.asset }
        
        guard !selectedAssets.isEmpty else {
            selectedPhotos.removeAll()
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(selectedAssets as NSArray)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.selectedPhotos.removeAll()
                    self.loadPhotos()
                } else if let error = error {
                    print("Error merging photos: \(error)")
                }
            }
        }
    }
}


