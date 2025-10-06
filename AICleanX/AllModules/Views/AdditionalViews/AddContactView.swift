import SwiftUI
import CoreData

// MARK: - Contact View Model Protocol
@MainActor
protocol ContactViewModelProtocol: ObservableObject {
    func addContact(_ contact: ContactData)
    func updateContact(_ contact: ContactData)
}

// MARK: - Type-erased Contact View Model
@MainActor
class AnyContactViewModel: ObservableObject, ContactViewModelProtocol {
    private let _addContact: (ContactData) -> Void
    private let _updateContact: (ContactData) -> Void
    
    init<T: ContactViewModelProtocol>(_ viewModel: T) {
        self._addContact = viewModel.addContact
        self._updateContact = viewModel.updateContact
    }
    
    func addContact(_ contact: ContactData) {
        _addContact(contact)
    }
    
    func updateContact(_ contact: ContactData) {
        _updateContact(contact)
    }
}

struct AddContactView: View {
    @ObservedObject var viewModel: AnyContactViewModel
    let contactToEdit: ContactData?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case firstName, lastName, phoneNumber
    }
    
    private var isEditing: Bool {
        contactToEdit != nil
    }
    
    private var isValidForm: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Contact Avatar
                        contactAvatarView
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            formField(
                                title: "First Name *",
                                text: $firstName,
                                placeholder: "Enter first name",
                                field: .firstName
                            )
                            
                            formField(
                                title: "Last Name *",
                                text: $lastName,
                                placeholder: "Enter last name",
                                field: .lastName
                            )
                            
                            formField(
                                title: "Phone Number *",
                                text: $phoneNumber,
                                placeholder: "Enter phone number",
                                field: .phoneNumber,
                                keyboardType: .phonePad
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
                
                // Save Button
                VStack {
                    Spacer()
                    
                    Button(action: saveContact) {
                        Text(isEditing ? "Update Contact" : "Save Contact")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isValidForm ? CMColor.primary : CMColor.secondaryText)
                            .cornerRadius(12)
                    }
                    .disabled(!isValidForm)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isEditing ? "Edit Contact" : "Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(CMColor.primary)
                }
            }
        }
        .onAppear {
            loadContactData()
        }
    }
    
    // MARK: - Contact Avatar View
    private var contactAvatarView: some View {
        ZStack {
            Circle()
                .fill(CMColor.primary.opacity(0.1))
                .frame(width: 100, height: 100)
            
            if !firstName.isEmpty || !lastName.isEmpty {
                Text(getInitials())
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(CMColor.primary)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(CMColor.primary.opacity(0.5))
            }
        }
    }
    
    // MARK: - Form Field
    private func formField(
        title: String,
        text: Binding<String>,
        placeholder: String,
        field: Field,
        keyboardType: UIKeyboardType = .default,
        isMultiline: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(CMColor.primaryText)
            
            if isMultiline {
                if #available(iOS 16.0, *) {
                    TextField(placeholder, text: text, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(CMColor.primaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(CMColor.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == field ? CMColor.primary : CMColor.border, lineWidth: 1)
                        )
                        .focused($focusedField, equals: field)
                } else {
                    // iOS 15 fallback using TextEditor
                    TextEditor(text: text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(CMColor.primaryText)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(CMColor.surface)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(focusedField == field ? CMColor.primary : CMColor.border, lineWidth: 1)
                        )
                        .focused($focusedField, equals: field)
                }
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(CMColor.primaryText)
                    .keyboardType(keyboardType)
                    .autocapitalization(field == .firstName || field == .lastName ? .words : .none)
                    .autocorrectionDisabled(field == .phoneNumber)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(CMColor.surface)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == field ? CMColor.primary : CMColor.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: field)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadContactData() {
        guard let contact = contactToEdit else { return }
        
        firstName = contact.firstName
        lastName = contact.lastName
        phoneNumber = contact.phoneNumber
    }
    
    private func getInitials() -> String {
        let firstInitial = firstName.first?.uppercased() ?? ""
        let lastInitial = lastName.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
    
    private func saveContact() {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLastName = lastName.trimmingCharacters(in: .whitespaces)
        let trimmedPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        
        if isEditing, let existingContact = contactToEdit {
            // Update existing contact
            let updatedContact = ContactData(
                id: existingContact.id,
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                phoneNumber: trimmedPhoneNumber,
                email: nil,
                notes: nil,
                dateAdded: existingContact.dateAdded,
                createdAt: existingContact.createdAt,
                modifiedAt: Date()
            )
            viewModel.updateContact(updatedContact)
        } else {
            // Create new contact
            let newContact = ContactData(
                firstName: trimmedFirstName,
                lastName: trimmedLastName,
                phoneNumber: trimmedPhoneNumber,
                email: nil,
                notes: nil
            )
            viewModel.addContact(newContact)
        }
        
        dismiss()
    }
}

// MARK: - Preview
#Preview {
    AddContactView(
        viewModel: AnyContactViewModel(AICleanerContactsViewModel()),
        contactToEdit: nil
    )
}
