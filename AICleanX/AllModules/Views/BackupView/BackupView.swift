import SwiftUI
import CloudKit

struct BackupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var backupSettings = BackupService.shared
    @StateObject private var iCloudService = iCloudBackupService()
    @State private var isBackingUp: Bool = false
    @State private var showBackupAlert: Bool = false
    @State private var backupMessage: String = ""
    @State private var showShareSheet: Bool = false
    @State private var backupFileURL: URL?
    @State private var selectedBackup: BackupItem?
    @State private var showBackupDetail: Bool = false
    @State private var showICloudBackupDetail: Bool = false
    @State private var selectedICloudBackup: iCloudBackupItem?
    @State private var realBackups: [BackupItem] = []
    
    private var scalingFactor: CGFloat {
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        ZStack {
            CMColor.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                navigationBar
                
                ScrollView {
                    VStack(spacing: 24 * scalingFactor) {
                        autoBackupCard
                        
                        if !realBackups.isEmpty {
                            existingBackupsSection
                        } else {
                            noBackupsIllustration
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16 * scalingFactor)
                    .padding(.top, 16 * scalingFactor)
                }
                
                backupButtonsSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            Task {
                await iCloudService.fetchBackupHistory()
            }
            realBackups = BackupToCloudService.shared.loadBackups()
        }
        .alert("Backup Contacts", isPresented: $showBackupAlert) {
            if backupFileURL != nil {
                Button("Share") {
                    showShareSheet = true
                    backupMessage = ""
                }
                Button("OK") {
                    backupMessage = ""
                }
            } else {
                Button("OK") {
                    backupMessage = ""
                }
            }
        } message: {
            Text(backupMessage)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = backupFileURL {
                ShareSheet(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $showBackupDetail) {
            BackupDetailView(backup: selectedBackup ?? BackupItem(date: Date(), contactsCount: 0, size: "0 MB"))
        }
        .onChange(of: showBackupDetail) { _ in
            realBackups = BackupToCloudService.shared.loadBackups()
            Task {
                await iCloudService.fetchBackupHistory()
            }
        }
    }
    
    // MARK: - Навигационная панель
    private var navigationBar: some View {
        HStack {
//            Button(action: {
//                dismiss()
//            }) {
//                Image(systemName: "chevron.left")
//                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
//                    .foregroundColor(CMColor.primary)
//                    .padding(.vertical, 8)
//            }
            
            Spacer()
            
            Text("Backup")
                .font(.system(size: 24 * scalingFactor, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Color.clear
                .frame(width: 24, height: 24)
                .padding(.vertical, 8)
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 8 * scalingFactor)
        .padding(.bottom, 16 * scalingFactor)
    }
    
    // MARK: - Карточка автоматического бэкапа
    private var autoBackupCard: some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            HStack {
                Text("Auto Backup")
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                Toggle("", isOn: $backupSettings.isAutoBackupEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: CMColor.primary))
                    .scaleEffect(0.9)
            }
            
            Text("Automatically create a safety copy of your contacts on iCloud before any major changes.")
                .font(.system(size: 14 * scalingFactor, weight: .regular))
                .foregroundColor(CMColor.secondaryText)
                .lineLimit(nil)
            
            if backupSettings.isAutoBackupEnabled {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "icloud.circle.fill")
                        .foregroundColor(CMColor.primary)
                    Text("Last backup: \(backupSettings.lastBackupDisplayText)")
                        .font(.system(size: 13 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primaryText)
                    Spacer()
                    Text("Total: \(backupSettings.totalBackupsCount)")
                        .font(.system(size: 13 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.secondaryText)
                }
            }
        }
        .padding(20 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(16 * scalingFactor)
        .shadow(color: CMColor.primary.opacity(0.08), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Секция с существующими бэкапами
    private var existingBackupsSection: some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            HStack {
                Text("Existing Backups")
                    .font(.system(size: 20 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Spacer()
                
                Text("Total: \(realBackups.count)")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            LazyVStack(spacing: 12 * scalingFactor) {
                ForEach(realBackups) { backup in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(CMColor.primary)
                            Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 15 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            Spacer()
                            Text("\(backup.contactsCount) contacts")
                                .font(.system(size: 14 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                        }
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(CMColor.primary)
                            Text("File size: \(backup.size)")
                                .font(.system(size: 14 * scalingFactor, weight: .regular))
                                .foregroundColor(CMColor.secondaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(CMColor.primary.opacity(0.6))
                        }
                    }
                    .padding()
                    .background(CMColor.surface)
                    .cornerRadius(12 * scalingFactor)
                    .onTapGesture {
                        selectedBackup = backup
                        showBackupDetail = true
                    }
                }
            }
        }
        .padding(.horizontal, 4 * scalingFactor)
    }
    
    // MARK: - Секция, когда нет бэкапов
    private var noBackupsIllustration: some View {
        VStack(spacing: 32 * scalingFactor) {
            Image(systemName: "icloud.and.arrow.up.fill")
                .font(.system(size: 80 * scalingFactor))
                .foregroundColor(CMColor.primary.opacity(0.3))
            
            VStack(spacing: 16 * scalingFactor) {
                Text("No Backups Yet")
                    .font(.system(size: 24 * scalingFactor, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Create your first backup to safely store your contacts on iCloud. You can restore them anytime you need.")
                    .font(.system(size: 15 * scalingFactor, weight: .regular))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40 * scalingFactor)
    }
    
    // MARK: - Нижние кнопки
    private var backupButtonsSection: some View {
        VStack(spacing: 12 * scalingFactor) {
            Button(action: {
                performICloudBackup()
            }) {
                HStack(spacing: 10) {
                    if isBackingUp || iCloudService.isBackingUp {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text("Backing up...")
                    } else {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Backup to iCloud")
                    }
                }
                .frame(height: 56 * scalingFactor)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .background((isBackingUp || iCloudService.isBackingUp) ? CMColor.primary.opacity(0.7) : CMColor.primary)
                .cornerRadius(16 * scalingFactor)
            }
            .disabled(isBackingUp || iCloudService.isBackingUp)
            
            Button(action: {
                performLocalBackup()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14 * scalingFactor, weight: .medium))
                    Text("Export Local Backup")
                        .font(.system(size: 15 * scalingFactor, weight: .medium))
                }
                .frame(height: 44 * scalingFactor)
                .foregroundColor(CMColor.primary)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                        .stroke(CMColor.primary, lineWidth: 1)
                )
            }
            .disabled(isBackingUp || iCloudService.isBackingUp)
        }
        .padding(.horizontal, 20 * scalingFactor)
        .padding(.top, 16 * scalingFactor)
        .padding(.bottom, 34 * scalingFactor)
        .background(CMColor.background.ignoresSafeArea())
    }
    
    // MARK: - Логика бэкапа (НЕ ИЗМЕНЯЛАСЬ)
    private func performICloudBackup() {
        let contactsManager = ContactsPersistenceManager.shared
        let contacts = contactsManager.loadContacts()
        
        guard !contacts.isEmpty else {
            backupMessage = "No contacts found to backup."
            showBackupAlert = true
            return
        }
        
        var backupSizeString: String = "0 MB"
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(contacts)
            
            let byteCountFormatter = ByteCountFormatter()
            byteCountFormatter.allowedUnits = [.useAll]
            byteCountFormatter.countStyle = .file
            backupSizeString = byteCountFormatter.string(fromByteCount: Int64(encodedData.count))
            
        } catch {
            print("❌ Failed to encode contacts to determine size: \(error.localizedDescription)")
        }
        
        Task {
            let success = await iCloudService.backupContacts(contacts)
            
            await MainActor.run {
                if success {
                    let newBackupItem = BackupItem(date: Date(), contactsCount: contacts.count, size: backupSizeString)
                    realBackups.insert(newBackupItem, at: 0)
                    BackupToCloudService.shared.saveBackups(realBackups)
                    backupMessage = "Successfully backed up \(contacts.count) contacts to iCloud! ☁️"
                } else {
                    let errorMessage = iCloudService.lastError?.localizedDescription ?? "Unknown error"
                    backupMessage = "Failed to backup contacts to iCloud: \(errorMessage)"
                }
                showBackupAlert = true
            }
        }
    }
    
    private func performLocalBackup() {
        guard !isBackingUp else { return }
        
        isBackingUp = true
        
        Task {
            do {
                let contactsManager = ContactsPersistenceManager.shared
                let contacts = contactsManager.loadContacts()
                
                guard !contacts.isEmpty else {
                    await MainActor.run {
                        isBackingUp = false
                        backupMessage = "No contacts found to backup."
                        showBackupAlert = true
                    }
                    return
                }
                
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                let backupData = try encoder.encode(contacts)
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let dateString = dateFormatter.string(from: Date())
                let backupURL = documentsPath.appendingPathComponent("contacts_backup_\(dateString).json")
                
                try backupData.write(to: backupURL)
                
                await MainActor.run {
                    isBackingUp = false
                    backupFileURL = backupURL
                    backupMessage = "Successfully backed up \(contacts.count) contacts!\n\nWould you like to share the backup file?"
                    showBackupAlert = true
                }
                
            } catch {
                await MainActor.run {
                    isBackingUp = false
                    backupMessage = "Failed to backup contacts: \(error.localizedDescription)"
                    showBackupAlert = true
                }
            }
        }
    }
}
