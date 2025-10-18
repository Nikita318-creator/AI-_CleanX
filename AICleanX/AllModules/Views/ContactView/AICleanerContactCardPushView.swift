import SwiftUI
import CoreData
import Contacts
import ContactsUI

struct AICleanerContactCardPushView: View {
    let contact: CNContact // Контакт, который может не иметь полных ключей
    @State private var fullContact: CNContact? // Контакт, который будет иметь полные ключи
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Loading contact...")
                        .foregroundColor(.secondary)
                }
            } else if let error = loadError {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                    Text("Failed to load contact")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if let fullContact = fullContact {
                // 🚨 Используем обертку с загруженным, полным контактом
                CNContactViewWrapper(contact: fullContact)
            } else {
                Text("Contact not found")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadFullContact()
        }
    }
    
    private func loadFullContact() async {
        do {
            let store = CNContactStore()
            // 🚨 КЛЮЧЕВОЙ МОМЕНТ: Запрашиваем ВСЕ ключи, включая ключи для CNContactViewController
            var keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactJobTitleKey as CNKeyDescriptor,
                CNContactPostalAddressesKey as CNKeyDescriptor,
                CNContactImageDataKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            
            // 🚨 ОБЯЗАТЕЛЬНО ДОБАВЛЯЕМ АГРЕГАТНЫЙ КЛЮЧ:
            keysToFetch.append(CNContactViewController.descriptorForRequiredKeys())
            
            let loadedContact = try store.unifiedContact(
                withIdentifier: contact.identifier,
                keysToFetch: keysToFetch
            )
            
            await MainActor.run {
                self.fullContact = loadedContact
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
        }
    }
}

struct CNContactViewWrapper: UIViewControllerRepresentable {
    // Получаем dismiss из окружения SwiftUI
    @Environment(\.dismiss) var dismiss
    let contact: CNContact

    // MARK: - makeUIViewController
    func makeUIViewController(context: Context) -> UINavigationController {
        
        // 1. Создаем системный контроллер контактов
        let contactVC = CNContactViewController(for: contact)
        contactVC.allowsEditing = true // Оставляем редактирование включенным
        contactVC.allowsActions = true // Оставляем стандартные действия (позвонить, отправить email)
        
        // 🚨 ИСПРАВЛЕНИЕ КОНФЛИКТА:
        // Убедимся, что CNContactViewController не пытается показать свою кнопку "Edit",
        // если мы хотим полностью контролировать навигационную панель.
        contactVC.navigationItem.rightBarButtonItem = nil // Очищаем на всякий случай
        
        // 2. Оборачиваем его в Navigation Controller
        let navController = UINavigationController(rootViewController: contactVC)
        
        // 3. Устанавливаем делегат для возврата поведения закрытия свайпом
        navController.presentationController?.delegate = context.coordinator
        
        // 4. Добавляем нашу кнопку "Done" (Готово) в ЛЕВЫЙ ВЕРХНИЙ угол.
        // Это стандартное место для кнопки "Закрыть/Готово" в модальных представлениях UIKit.
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: context.coordinator,
            action: #selector(Coordinator.dismissModal)
        )
        // 🚨 Ключевое изменение: Используем navigationItem.leftBarButtonItem
        contactVC.navigationItem.leftBarButtonItem = doneButton
        
        return navController
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    
    // MARK: - Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        private let dismissAction: DismissAction
        
        init(dismiss: DismissAction) {
            self.dismissAction = dismiss
        }
        
        // Обработчик кнопки "Done"
        @objc func dismissModal() {
            dismissAction()
        }
        
        // Обработчик свайпа вниз
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            dismissAction()
        }
    }
}
