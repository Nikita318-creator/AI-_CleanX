import SwiftUI
import Photos
import Combine

final class SimilaritySectionsViewModel: ObservableObject {
    @Published var sections: [AICleanServiceSection] // Главный источник данных для View
    @Published var selectedItems: Set<String> = []
    @Published var isSelectionMode: Bool = false // Используем это, а не локальное @State в View

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
    
    // MARK: - ЛОГИКА ВЫДЕЛЕНИЯ
    
    func toggleSelection(for model: AICleanServiceModel) {
        let itemId = model.asset.localIdentifier
        if selectedItems.contains(itemId) {
            selectedItems.remove(itemId)
        } else {
            selectedItems.insert(itemId)
        }
        
        // Управляем режимом выделения из ViewModel
        if selectedItems.isEmpty {
            isSelectionMode = false
        } else if !isSelectionMode {
            isSelectionMode = true // Входим в режим, если что-то выбрано
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
    
    // MARK: - ФУНКЦИЯ УДАЛЕНИЯ И ОБНОВЛЕНИЯ
    
    /// Удаляет выбранные ассеты из Photos Library и обновляет список в ViewModel.
    /// - Parameter completion: Замыкание, вызываемое после попытки удаления (true = успех, false = ошибка).
    func deleteSelected(completion: @escaping (Bool) -> Void) {
        guard !selectedItems.isEmpty else {
            completion(false)
            return
        }
        
        // 1. Находим объекты PHAsset по их ID
        let identifiersToDelete = Array(selectedItems)
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: identifiersToDelete, options: nil)
        
        // 2. Выполняем асинхронное удаление в системной библиотеке
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
            
        }) { [weak self] success, error in
            // Возвращаемся в главный поток для обновления UI
            DispatchQueue.main.async {
                guard let self = self else {
                    completion(success)
                    return
                }
                
                if success {
                    // 3. Успех: Обновляем локальную модель, чтобы View обновилось мгновенно
                    self.removeDeletedItemsFromViewModel()
                } else if let error = error {
                    print("Error deleting assets: \(error.localizedDescription)")
                }
                
                // 4. Очистка состояния и вызов completion
                self.selectedItems.removeAll()
                self.isSelectionMode = false // Выходим из режима выделения
                completion(success) // Передаем результат обратно во View
            }
        }
    }
    
    // МЕХАНИЗМ МГНОВЕННОГО ОБНОВЛЕНИЯ
    private func removeDeletedItemsFromViewModel() {
        let deletedIdentifiers = selectedItems
        var newSections: [AICleanServiceSection] = []
        
        // Итерируем по старым секциям и удаляем из них помеченные ассеты
        for section in self.sections {
            var newSection = section
            
            // Удаляем все модели, чьи идентификаторы есть в selectedItems
            newSection.models.removeAll { deletedIdentifiers.contains($0.asset.localIdentifier) }
            
            // Если в секции остались модели, добавляем ее в новый список
            if !newSection.models.isEmpty {
                newSections.append(newSection)
            }
        }
        
        // Присваиваем новый массив. Это автоматически обновит View.
        self.sections = newSections
    }
}
