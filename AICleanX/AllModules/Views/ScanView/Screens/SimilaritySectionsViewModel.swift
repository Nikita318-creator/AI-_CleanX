import SwiftUI
import Photos
import Combine

final class SimilaritySectionsViewModel: ObservableObject {
    @Published var sections: [AICleanServiceSection]
    @Published var selectedItems: Set<String> = []
    @Published var isSelectionMode: Bool = false

    let type: ScanItemType
    
    var title: String {
        return type.title
    }
    
    var hasSelectedItems: Bool {
        return !selectedItems.isEmpty
    }
    
    var selectedCount: Int {
        return selectedItems.count
    }

    init(sections: [AICleanServiceSection], type: ScanItemType) {
        self.sections = sections
        self.type = type
    }
    
    func toggleSelection(for model: AICleanServiceModel) {
        let itemId = model.asset.localIdentifier
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
        
        if selectedItems.isEmpty {
            isSelectionMode = false
        }
    }
    
    func isSelected(_ model: AICleanServiceModel) -> Bool {
        return selectedItems.contains(model.asset.localIdentifier)
    }
    
    func selectAll() {
        selectedItems.removeAll()
        for section in sections {
            for model in section.models {
                selectedItems.insert(model.asset.localIdentifier)
            }
        }
        isSelectionMode = true
    }
    
    func deselectAll() {
        selectedItems.removeAll()
        isSelectionMode = false
    }
    
    func selectAllInSection(_ section: AICleanServiceSection) {
        for model in section.models {
            selectedItems.insert(model.asset.localIdentifier)
        }
        isSelectionMode = true
    }
    
    func deselectAllInSection(_ section: AICleanServiceSection) {
        for model in section.models {
            selectedItems.remove(model.asset.localIdentifier)
        }
        
        if selectedItems.isEmpty {
            isSelectionMode = false
        }
    }
    
    func isAllSelectedInSection(_ section: AICleanServiceSection) -> Bool {
        return section.models.allSatisfy { model in
            selectedItems.contains(model.asset.localIdentifier)
        }
    }
    
    func deleteSelected() {
           guard !selectedItems.isEmpty else { return }
           
           let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: Array(selectedItems), options: nil)
           
           PHPhotoLibrary.shared().performChanges({
               PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
           }) { [weak self] success, error in
               DispatchQueue.main.async {
                   if success {
                       self?.removeDeletedItemsFromViewModel()
                   }
                   
                   self?.selectedItems.removeAll()
                   self?.isSelectionMode = false
               }
           }
       }
       
       private func removeDeletedItemsFromViewModel() {
           for localIdentifier in selectedItems {
               for i in sections.indices {
                   sections[i].models.removeAll { $0.asset.localIdentifier == localIdentifier }
               }
           }
           
           sections.removeAll { $0.models.isEmpty }
       }
}
