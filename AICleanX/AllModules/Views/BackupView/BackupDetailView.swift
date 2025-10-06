import SwiftUI
import CloudKit

struct BackupDetailView: View {
    let backup: BackupItem
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var backupFileURL: URL?
    @State private var isSharePressed: Bool = false
    @State private var isRestorePressed: Bool = false
    @StateObject private var iCloudService = iCloudBackupService()

    // 1. Создаем @State для реальных контактов
    @State private var contacts: [ContactData] = []
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    // 2. Группируем реальные контакты по первой букве имени
    private var groupedContacts: [(String, [ContactData])] {
        let grouped = Dictionary(grouping: contacts) { contact in
            String(contact.firstName.prefix(1).uppercased())
        }
        return grouped.sorted { $0.key < $1.key }
    }
    
    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                navigationBar
                
                // Content
                ScrollView {
                    VStack(spacing: 24 * scalingFactor) {
                        // Backup Header Section
                        backupHeaderSection
                        
                        // Contacts List Section
                        contactsListSection
                        
                        Spacer(minLength: 100 * scalingFactor)
                    }
                    .padding(.horizontal, 20 * scalingFactor)
                    .padding(.top, 24 * scalingFactor)
                }
                
                // Bottom Action Buttons
                bottomActionButtons
            }
        }
        .navigationBarHidden(true)
        .alert("Delete Backup", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: Реализовать удаление из iCloud
                BackupToCloudService.shared.deleteBackup(withId: backup.id.uuidString)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this backup?")
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = backupFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        // 3. Загружаем данные при появлении View
        .onAppear {
            Task {
                await loadBackupContacts()
            }
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Back")
                        .font(.system(size: 17 * scalingFactor, weight: .regular))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text(backup.dayOfWeek)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                showDeleteAlert = true
            }) {
                Text("Delete")
                    .font(.system(size: 17 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.error)
            }
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 16 * scalingFactor)
    }
    
    // MARK: - Backup Header Section
    private var backupHeaderSection: some View {
        VStack(spacing: 16 * scalingFactor) {
            // Date and Time
            VStack(spacing: 4 * scalingFactor) {
                Text(backup.dayOfWeek)
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
            }
            
            // Stats Row
            HStack(spacing: 32 * scalingFactor) {
                StatItemView(
                    title: "Contacts",
                    value: "\(contacts.count)",
                    scalingFactor: scalingFactor
                )
                
                StatItemView(
                    title: "Size",
                    value: backup.size,
                    scalingFactor: scalingFactor
                )
            }
            .padding(.horizontal, 20 * scalingFactor)
        }
        .padding(.vertical, 24 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(16 * scalingFactor)
        .shadow(color: CMColor.border.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Contacts List Section
    private var contactsListSection: some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            // Section Header
            HStack {
                Text("Contacts")
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                Text("\(contacts.count) contacts")
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
            .padding(.horizontal, 4 * scalingFactor)
            
            // Contacts grouped by alphabet
            VStack(spacing: 0) {
                ForEach(Array(groupedContacts.enumerated()), id: \.element.0) { sectionIndex, section in
                    let (letter, contacts) = section
                    
                    VStack(spacing: 0) {
                        // Section Header
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(CMColor.primary.opacity(0.1))
                                    .frame(width: 28 * scalingFactor, height: 28 * scalingFactor)
                                
                                Text(letter)
                                    .font(.system(size: 14 * scalingFactor, weight: .semibold))
                                    .foregroundColor(CMColor.primary)
                            }
                            
                            Rectangle()
                                .fill(CMColor.border.opacity(0.2))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.vertical, 10 * scalingFactor)
                        .background(CMColor.background.opacity(0.3))
                        
                        // Contacts in this section
                        ForEach(Array(contacts.enumerated()), id: \.element.id) { contactIndex, contact in
                            BackupContactRowView(
                                contact: contact,
                                isLast: contactIndex == contacts.count - 1 && sectionIndex == groupedContacts.count - 1,
                                scalingFactor: scalingFactor
                            )
                        }
                    }
                }
            }
            .background(CMColor.surface)
            .cornerRadius(12 * scalingFactor)
            .shadow(color: CMColor.border.opacity(0.1), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Bottom Action Buttons
    private var bottomActionButtons: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CMColor.border.opacity(0.2))
                .frame(height: 1)
            
            HStack(spacing: 12 * scalingFactor) {
                Button(action: {
                    Task {
                        await shareBackupFile()
                    }
                }) {
                    HStack(spacing: 8 * scalingFactor) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                        Text("Share")
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                    }
                    .foregroundColor(CMColor.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50 * scalingFactor)
                    .background(CMColor.primary.opacity(0.1))
                    .cornerRadius(12 * scalingFactor)
                }
                
                Button(action: {
                    print("Restore backup: \(backup.formattedDate)")
                    dismiss()
                    // TODO: Реализовать восстановление контактов
                }) {
                    Text("Restore")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50 * scalingFactor)
                        .background(CMColor.primary)
                        .cornerRadius(12 * scalingFactor)
                }
            }
            .padding(.horizontal, 20 * scalingFactor)
            .padding(.top, 16 * scalingFactor)
            .padding(.bottom, max(34 * scalingFactor, 16 * scalingFactor))
            .background(CMColor.background)
        }
    }
    
    // MARK: - Private Methods

    private func loadBackupContacts() async {
        let contactsManager = ContactsPersistenceManager.shared
        self.contacts = contactsManager.loadContacts()
    }

    private func shareBackupFile() async {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.contacts)
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "Contacts_Backup_\(backup.dateString).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            
            await MainActor.run {
                self.backupFileURL = fileURL
                self.showShareSheet = true
            }
        } catch {
            print("❌ Failed to create shareable backup file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Stat Item View
    struct StatItemView: View {
        let title: String
        let value: String
        let scalingFactor: CGFloat
        
        var body: some View {
            VStack(spacing: 4 * scalingFactor) {
                Text(value)
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(title)
                    .font(.system(size: 12 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
        }
    }

    // MARK: - Backup Contact Row View
    struct BackupContactRowView: View {
        let contact: ContactData
        let isLast: Bool
        let scalingFactor: CGFloat
        
        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 12 * scalingFactor) {
                    // Contact Avatar
                    ZStack {
                        Circle()
                            .fill(CMColor.primary.opacity(0.1))
                            .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                        
                        Text(contact.initials)
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.primary)
                    }
                    
                    // Contact Info
                    VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                        Text(contact.fullName)
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text(contact.phoneNumber)
                            .font(.system(size: 14 * scalingFactor, weight: .regular))
                            .foregroundColor(CMColor.secondaryText)
                        
                        if let email = contact.email {
                            Text(email)
                                .font(.system(size: 14 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.vertical, 12 * scalingFactor)
                
                // Divider (except for last item)
                if !isLast {
                    Rectangle()
                        .fill(CMColor.border.opacity(0.2))
                        .frame(height: 1)
                        .padding(.leading, 68 * scalingFactor)
                }
            }
        }
    }
}
