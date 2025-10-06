import SwiftUI
import UniformTypeIdentifiers

struct DocListView: View {
    @State private var searchInput: String = ""
    @Environment(\.dismiss) private var viewDismiss
    @EnvironmentObject private var storageHandler: SafeStorageManager
    @FocusState private var isSearchFocused: Bool
    @State private var isSelectModeActive: Bool = false
    @State private var currentSelection: Set<UUID> = []
    
    @State private var showImportDialog = false
    @State private var isImportingFiles = false
    
    @State private var showConfirmDelete = false
    @State private var showRemoveDeviceAlert = false
    @State private var filesToProcess: [PickerDocResult] = []
    
    @State private var previewTarget: SafeDocumentData?
    @State private var showPreviewScreen = false
    
    private var allStoredDocuments: [SafeDocumentData] {
        storageHandler.loadAllDocuments()
    }
    
    private var filteredDocumentList: [SafeDocumentData] {
        if searchInput.isEmpty {
            return allStoredDocuments
        } else {
            return allStoredDocuments.filter { document in
                document.fileName.lowercased().contains(searchInput.lowercased())
            }
        }
    }
    
    var body: some View {
        viewContent
            .fileImporter(
                isPresented: $showImportDialog,
                allowedContentTypes: validFileTypes,
                allowsMultipleSelection: true
            ) { result in
                handleImportResult(result)
            }
            .alert("Delete documents from device?", isPresented: $showRemoveDeviceAlert) {
                deviceRemovalButtons
            } message: {
                deviceRemovalMessage
            }
            .confirmationDialog("Delete Documents", isPresented: $showConfirmDelete) {
                deletionConfirmButtons
            } message: {
                deletionConfirmMessage
            }
            .fullScreenCover(isPresented: $showPreviewScreen) {
                documentPreviewHolder
            }
    }
    
    private var viewContent: some View {
        GeometryReader { geometry in
            let scaleValue = geometry.size.height / 844
            
            VStack(spacing: 0) {
                generateHeaderView(scaleFactor: scaleValue)
                
                if allStoredDocuments.isEmpty {
                    generateEmptyState(scaleFactor: scaleValue)
                } else {
                    generateDocumentList(scaleFactor: scaleValue)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            isSearchFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private var validFileTypes: [UTType] {
        [
            .pdf, .plainText, .rtf,
            .commaSeparatedText, .tabSeparatedText,
            .zip, .data,
            UTType(filenameExtension: "doc") ?? .data,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "xls") ?? .data,
            UTType(filenameExtension: "xlsx") ?? .data,
            UTType(filenameExtension: "ppt") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data
        ]
    }
    
    private var deviceRemovalButtons: some View {
        Group {
            Button("Yes") {
                Task {
                    await saveAndCleanupDeviceFiles()
                }
            }
            Button("No", role: .cancel) {
                Task {
                    await saveOnlyImportedFiles()
                }
            }
        }
    }
    
    private var deviceRemovalMessage: some View {
        Text("Do you want to delete these documents from your device? Note: Documents from iCloud Drive and other cloud providers cannot be deleted, but will still be securely stored in this app.")
    }
    
    private var deletionConfirmButtons: some View {
        Group {
            Button("Delete \(currentSelection.count) Documents", role: .destructive) {
                performDeletion()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private var deletionConfirmMessage: some View {
        Text("Are you sure you want to delete \(currentSelection.count) selected documents? This action cannot be undone.")
    }
    
    @ViewBuilder
    private var documentPreviewHolder: some View {
        if let document = previewTarget {
            EnhancedDocumentPreviewView(document: document)
                .environmentObject(storageHandler)
        } else {
            VStack {
                Text("Error")
                    .font(.title)
                Text("Document not found")
                    .foregroundColor(.secondary)
                Button("Close") {
                    showPreviewScreen = false
                }
                .padding()
            }
        }
    }
    
    private func generateHeaderView(scaleFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                viewDismiss()
            }) {
                HStack(spacing: 4 * scaleFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16 * scaleFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text("Docs")
                .font(.system(size: 17 * scaleFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !allStoredDocuments.isEmpty {
                Button(action: {
                    isSelectModeActive.toggle()
                    if !isSelectModeActive {
                        currentSelection.removeAll()
                    }
                }) {
                    HStack(spacing: 4 * scaleFactor) {
                        Circle()
                            .fill(CMColor.primary)
                            .frame(width: 6 * scaleFactor, height: 6 * scaleFactor)
                        Text("Select")
                            .font(.system(size: 16 * scaleFactor))
                            .foregroundColor(CMColor.primary)
                    }
                }
            } else {
                Spacer().frame(width: 60 * scaleFactor)
            }
        }
        .padding(.horizontal, 16 * scaleFactor)
        .padding(.vertical, 12 * scaleFactor)
    }
    
    private func generateEmptyState(scaleFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scaleFactor) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 120 * scaleFactor, height: 120 * scaleFactor)
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 48 * scaleFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scaleFactor) {
                Text("No documents yet")
                    .font(.system(size: 20 * scaleFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Add your first document to get started")
                    .font(.system(size: 16 * scaleFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showImportDialog = true
            }) {
                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: "plus")
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                    
                    Text("Add document")
                        .font(.system(size: 16 * scaleFactor, weight: .semibold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scaleFactor)
                .background(CMColor.primaryGradient)
                .cornerRadius(25 * scaleFactor)
            }
            .padding(.horizontal, 40 * scaleFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func generateDocumentList(scaleFactor: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 24 * scaleFactor) {
                createSearchBar(scaleFactor: scaleFactor)
                
                if !isSearchFocused || !searchInput.isEmpty {
                    createDocumentSections(scaleFactor: scaleFactor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    createBottomActionButton(scaleFactor: scaleFactor)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer(minLength: isSearchFocused ? 200 * scaleFactor : 100 * scaleFactor)
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.top, 20 * scaleFactor)
            .animation(.easeInOut(duration: 0.3), value: isSearchFocused)
        }
    }
    
    private func createSearchBar(scaleFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            HStack(spacing: 8 * scaleFactor) {
                TextField("Search", text: $searchInput)
                    .font(.system(size: 16 * scaleFactor))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFocused = false
                    }
                
                Spacer()
                
                if isSearchFocused && !searchInput.isEmpty {
                    Button(action: {
                        searchInput = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(CMColor.secondaryText)
                            .font(.system(size: 16 * scaleFactor))
                    }
                } else {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(CMColor.secondaryText)
                        .font(.system(size: 16 * scaleFactor))
                }
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.vertical, 12 * scaleFactor)
            .background(CMColor.surface)
            .cornerRadius(12 * scaleFactor)
            .overlay(
                RoundedRectangle(cornerRadius: 12 * scaleFactor)
                    .stroke(isSearchFocused ? CMColor.primary.opacity(0.3) : CMColor.border, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
        }
    }
    
    private func createDocumentSections(scaleFactor: CGFloat) -> some View {
        let sections = Dictionary(grouping: filteredDocumentList) { document in
            formatDocumentDate(document.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 16 * scaleFactor) {
            ForEach(sections.keys.sorted(by: { first, second in
                if first == "Today" { return true }
                if second == "Today" { return false }
                return first < second
            }), id: \.self) { dateKey in
                VStack(alignment: .leading, spacing: 12 * scaleFactor) {
                    Text(dateKey)
                        .font(.system(size: 18 * scaleFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    VStack(spacing: 0) {
                        ForEach(Array((sections[dateKey] ?? []).enumerated()), id: \.element.id) { index, document in
                            createDocumentRow(document: document, scaleFactor: scaleFactor)
                            
                            if index < (sections[dateKey]?.count ?? 0) - 1 {
                                Divider()
                                    .background(CMColor.secondaryText.opacity(0.1))
                                    .padding(.leading, 48 * scaleFactor)
                            }
                        }
                    }
                    .background(CMColor.surface)
                    .cornerRadius(16 * scaleFactor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * scaleFactor)
                            .stroke(CMColor.secondaryText.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: CMColor.black.opacity(0.02), radius: 8 * scaleFactor, x: 0, y: 2 * scaleFactor)
                }
            }
        }
    }
    
    private func createDocumentRow(document: SafeDocumentData, scaleFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scaleFactor) {
            generateDocumentIcon(document: document, scaleFactor: scaleFactor)
            
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(document.displayName)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                Text(document.fileSizeFormatted)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            Spacer()
            
            if !isSelectModeActive {
                Button(action: {
                    previewTarget = document
                    showPreviewScreen = true
                }) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16 * scaleFactor))
                        .foregroundColor(CMColor.primary)
                        .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)
                        .background(CMColor.primary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            if isSelectModeActive {
                Button(action: {
                    if currentSelection.contains(document.id) {
                        currentSelection.remove(document.id)
                    } else {
                        currentSelection.insert(document.id)
                    }
                }) {
                    Image(systemName: currentSelection.contains(document.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20 * scaleFactor))
                        .foregroundColor(currentSelection.contains(document.id) ? CMColor.primary : CMColor.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16 * scaleFactor)
        .padding(.vertical, 12 * scaleFactor)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectModeActive {
                if currentSelection.contains(document.id) {
                    currentSelection.remove(document.id)
                } else {
                    currentSelection.insert(document.id)
                }
            } else {
                previewTarget = document
                showPreviewScreen = true
            }
        }
    }
    
    private func generateDocumentIcon(document: SafeDocumentData, scaleFactor: CGFloat) -> some View {
        let isImage = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif"].contains(document.fileExtension?.lowercased() ?? "")
        
        return ZStack {
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(isImage ? Color.clear : CMColor.primary.opacity(0.1))
                .frame(width: 32 * scaleFactor, height: 32 * scaleFactor)
            
            if isImage {
                ImageThumbnailView(documentURL: document.documentURL, scalingFactor: scaleFactor)
            } else {
                Image(systemName: document.iconName)
                    .font(.system(size: 16 * scaleFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
        }
    }
    
    private func createBottomActionButton(scaleFactor: CGFloat) -> some View {
        VStack(spacing: 12 * scaleFactor) {
            if isImportingFiles {
                HStack(spacing: 8 * scaleFactor) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Adding documents...")
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scaleFactor)
                .background(CMColor.primary.opacity(0.7))
                .cornerRadius(16 * scaleFactor)
            } else {
                Button(action: {
                    showImportDialog = true
                }) {
                    Text("Add document")
                        .font(.system(size: 16 * scaleFactor, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52 * scaleFactor)
                        .background(CMColor.primary)
                        .cornerRadius(16 * scaleFactor)
                }
                .disabled(isImportingFiles)
            }
            
            if isSelectModeActive && !currentSelection.isEmpty {
                Button(action: {
                    showConfirmDelete = true
                }) {
                    HStack(spacing: 8 * scaleFactor) {
                        Image(systemName: "trash")
                            .font(.system(size: 16 * scaleFactor, weight: .medium))
                        
                        Text("Delete Selected (\(currentSelection.count))")
                            .font(.system(size: 16 * scaleFactor, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scaleFactor)
                    .background(Color.red)
                    .cornerRadius(16 * scaleFactor)
                }
                .disabled(isImportingFiles)
            }
        }
        .padding(.top, 20 * scaleFactor)
        .animation(.easeInOut(duration: 0.2), value: isImportingFiles)
    }
    
    private func formatDocumentDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var documentsReady: [PickerDocResult] = []
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    continue
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let fileName = url.lastPathComponent
                    let fileExtension = url.pathExtension.isEmpty ? nil : url.pathExtension
                    
                    let documentResult = PickerDocResult(
                        data: data,
                        fileName: fileName,
                        fileExtension: fileExtension,
                        originalURL: url
                    )
                    
                    documentsReady.append(documentResult)
                } catch {
                }
            }
            
            if !documentsReady.isEmpty {
                filesToProcess = documentsReady
                showRemoveDeviceAlert = true
            }
            
        case .failure(_):
            break
        }
    }
    
    private func saveAndCleanupDeviceFiles() async {
        isImportingFiles = true
        
        for fileItem in filesToProcess {
            await saveSingleFile(fileItem)
            
            let url = fileItem.originalURL
            
            do {
                let hasAccess = url.startAccessingSecurityScopedResource()
                
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let fileManager = FileManager.default
                let fileExists = fileManager.fileExists(atPath: url.path)
                let isDeletable = fileManager.isDeletableFile(atPath: url.path)
                
                if fileExists && isDeletable {
                    try fileManager.removeItem(at: url)
                } else if url.path.contains("/Inbox/") {
                    try fileManager.removeItem(at: url)
                }
            } catch {
            }
        }
        
        await MainActor.run {
            filesToProcess.removeAll()
            isImportingFiles = false
            storageHandler.objectWillChange.send()
        }
    }
    
    private func saveOnlyImportedFiles() async {
        isImportingFiles = true
        
        for fileItem in filesToProcess {
            await saveSingleFile(fileItem)
        }
        
        await MainActor.run {
            filesToProcess.removeAll()
            isImportingFiles = false
            storageHandler.objectWillChange.send()
        }
    }
    
    private func saveSingleFile(_ fileItem: PickerDocResult) async {
        _ = await storageHandler.saveDocumentAsync(
            documentData: fileItem.data,
            fileName: fileItem.fileName,
            fileExtension: fileItem.fileExtension
        )
    }
    
    private func performDeletion() {
        let itemsToDelete = allStoredDocuments.filter { document in
            currentSelection.contains(document.id)
        }
        
        storageHandler.deleteDocuments(itemsToDelete)
        currentSelection.removeAll()
        isSelectModeActive = false
    }
}
