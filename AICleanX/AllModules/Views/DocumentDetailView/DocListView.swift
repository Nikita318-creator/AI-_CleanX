import SwiftUI
import UniformTypeIdentifiers

struct RefactoredDocListView: View {
    @State private var filterQuery: String = ""
    @Environment(\.dismiss) private var dismissView
    @EnvironmentObject private var storageHandler: SafeStorageManager
    @FocusState private var isFilterActive: Bool
    @State private var multiSelectEnabled: Bool = false
    @State private var selectedItems: Set<UUID> = []
    
    @State private var showFilePicker = false
    @State private var processingFiles = false
    
    @State private var showDeleteWarning = false
    @State private var showCleanupPrompt = false
    @State private var pendingFiles: [PickerDocResult] = []
    
    @State private var itemToView: SafeDocumentData?
    @State private var displayViewer = false
    
    private var storedFiles: [SafeDocumentData] {
        storageHandler.loadAllDocuments()
    }
    
    private var displayedFiles: [SafeDocumentData] {
        if filterQuery.isEmpty {
            return storedFiles
        } else {
            return storedFiles.filter { file in
                file.fileName.lowercased().contains(filterQuery.lowercased())
            }
        }
    }
    
    var body: some View {
        mainContent
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                processPickerResult(result)
            }
            .alert("Remove from device storage?", isPresented: $showCleanupPrompt) {
                cleanupButtons
            } message: {
                cleanupMessage
            }
            .confirmationDialog("Remove Files", isPresented: $showDeleteWarning) {
                removalButtons
            } message: {
                removalMessage
            }
            .fullScreenCover(isPresented: $displayViewer) {
                viewerContent
            }
    }
    
    private var mainContent: some View {
        GeometryReader { geo in
            let scale = geo.size.height / 844
            
            VStack(spacing: 0) {
                buildTopBar(scale: scale)
                
                if storedFiles.isEmpty {
                    buildEmptyView(scale: scale)
                } else {
                    buildFileGrid(scale: scale)
                }
            }
        }
        .background(CMColor.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture {
            isFilterActive = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private var supportedTypes: [UTType] {
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
    
    private var cleanupButtons: some View {
        Group {
            Button("Remove Files") {
                Task {
                    await storeAndCleanup()
                }
            }
            Button("Keep Original", role: .cancel) {
                Task {
                    await storeWithoutCleanup()
                }
            }
        }
    }
    
    private var cleanupMessage: some View {
        Text("Would you like to remove these files from device storage after importing? Files from cloud services cannot be removed but will remain accessible within the app.")
    }
    
    private var removalButtons: some View {
        Group {
            Button("Remove \(selectedItems.count) Items", role: .destructive) {
                executeRemoval()
            }
            Button("Keep Files", role: .cancel) { }
        }
    }
    
    private var removalMessage: some View {
        Text("This will permanently remove \(selectedItems.count) selected items. This operation cannot be reversed.")
    }
    
    @ViewBuilder
    private var viewerContent: some View {
        if let file = itemToView {
            EnhancedDocumentPreviewView(document: file)
                .environmentObject(storageHandler)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(CMColor.warning)
                
                Text("Unable to Load")
                    .font(.title2.bold())
                    .foregroundColor(CMColor.primaryText)
                
                Text("The requested file could not be found")
                    .font(.subheadline)
                    .foregroundColor(CMColor.secondaryText)
                
                Button("Dismiss") {
                    displayViewer = false
                }
                .font(.headline)
                .foregroundColor(CMColor.white)
                .frame(width: 120, height: 44)
                .background(CMColor.accent)
                .cornerRadius(22)
            }
            .padding()
        }
    }
    
    private func buildTopBar(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            Button(action: {
                dismissView()
            }) {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15 * scale, weight: .semibold))
                    Text("Return")
                        .font(.system(size: 15 * scale, weight: .medium))
                }
                .foregroundColor(CMColor.accent)
            }
            
            Spacer()
            
            Text("My Files")
                .font(.system(size: 18 * scale, weight: .bold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            if !storedFiles.isEmpty {
                Button(action: {
                    multiSelectEnabled.toggle()
                    if !multiSelectEnabled {
                        selectedItems.removeAll()
                    }
                }) {
                    HStack(spacing: 5 * scale) {
                        Image(systemName: multiSelectEnabled ? "checkmark.square" : "square")
                            .font(.system(size: 15 * scale, weight: .medium))
                        Text(multiSelectEnabled ? "Done" : "Edit")
                            .font(.system(size: 15 * scale, weight: .medium))
                    }
                    .foregroundColor(CMColor.accent)
                }
            } else {
                Spacer().frame(width: 70 * scale)
            }
        }
        .padding(.horizontal, 20 * scale)
        .padding(.vertical, 14 * scale)
        .background(CMColor.surface)
    }
    
    private func buildEmptyView(scale: CGFloat) -> some View {
        VStack(spacing: 28 * scale) {
            Spacer()
            
            ZStack {
                RoundedRectangle(cornerRadius: 28 * scale)
                    .fill(CMColor.backgroundGradient)
                    .frame(width: 140 * scale, height: 140 * scale)
                
                Image(systemName: "tray.fill")
                    .font(.system(size: 54 * scale, weight: .light))
                    .foregroundColor(CMColor.iconSecondary)
            }
            
            VStack(spacing: 10 * scale) {
                Text("Nothing Here Yet")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundColor(CMColor.primaryText)
                
                Text("Import files to begin organizing")
                    .font(.system(size: 15 * scale))
                    .foregroundColor(CMColor.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scale)
            }
            
            Button(action: {
                showFilePicker = true
            }) {
                HStack(spacing: 10 * scale) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17 * scale, weight: .semibold))
                    
                    Text("Import Files")
                        .font(.system(size: 17 * scale, weight: .bold))
                }
                .foregroundColor(CMColor.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56 * scale)
                .background(
                    RoundedRectangle(cornerRadius: 16 * scale)
                        .fill(CMColor.secondaryGradient)
                )
            }
            .padding(.horizontal, 50 * scale)
            .padding(.top, 12 * scale)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func buildFileGrid(scale: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 20 * scale) {
                buildFilterBar(scale: scale)
                
                if !isFilterActive || !filterQuery.isEmpty {
                    buildGroupedContent(scale: scale)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    buildActionControls(scale: scale)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                Spacer(minLength: isFilterActive ? 240 * scale : 120 * scale)
            }
            .padding(.horizontal, 20 * scale)
            .padding(.top, 16 * scale)
            .animation(.easeInOut(duration: 0.25), value: isFilterActive)
        }
    }
    
    private func buildFilterBar(scale: CGFloat) -> some View {
        HStack(spacing: 10 * scale) {
            HStack(spacing: 10 * scale) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(CMColor.iconSecondary)
                    .font(.system(size: 18 * scale))
                
                TextField("Filter by name", text: $filterQuery)
                    .font(.system(size: 15 * scale))
                    .foregroundColor(CMColor.primaryText)
                    .focused($isFilterActive)
                    .submitLabel(.done)
                    .onSubmit {
                        isFilterActive = false
                    }
                
                Spacer()
                
                if isFilterActive && !filterQuery.isEmpty {
                    Button(action: {
                        filterQuery = ""
                    }) {
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(CMColor.tertiaryText)
                            .font(.system(size: 17 * scale))
                    }
                }
            }
            .padding(.horizontal, 18 * scale)
            .padding(.vertical, 14 * scale)
            .background(
                RoundedRectangle(cornerRadius: 14 * scale)
                    .fill(CMColor.backgroundSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14 * scale)
                    .stroke(isFilterActive ? CMColor.accent.opacity(0.4) : CMColor.border.opacity(0.3), lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isFilterActive)
        }
    }
    
    private func buildGroupedContent(scale: CGFloat) -> some View {
        let grouped = Dictionary(grouping: displayedFiles) { file in
            formatFileDate(file.dateAdded)
        }
        
        return LazyVStack(alignment: .leading, spacing: 18 * scale) {
            ForEach(grouped.keys.sorted(by: { a, b in
                if a == "Recent" { return true }
                if b == "Recent" { return false }
                return a < b
            }), id: \.self) { group in
                VStack(alignment: .leading, spacing: 14 * scale) {
                    HStack {
                        Text(group)
                            .font(.system(size: 16 * scale, weight: .bold))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Rectangle()
                            .fill(CMColor.border.opacity(0.3))
                            .frame(height: 1)
                    }
                    
                    VStack(spacing: 0) {
                        ForEach(Array((grouped[group] ?? []).enumerated()), id: \.element.id) { idx, file in
                            buildFileCard(file: file, scale: scale)
                            
                            if idx < (grouped[group]?.count ?? 0) - 1 {
                                Divider()
                                    .background(CMColor.border.opacity(0.15))
                                    .padding(.leading, 56 * scale)
                            }
                        }
                    }
                    .background(CMColor.surface)
                    .cornerRadius(18 * scale)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18 * scale)
                            .stroke(CMColor.border.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: CMColor.black.opacity(0.04), radius: 12 * scale, x: 0, y: 4 * scale)
                }
            }
        }
    }
    
    private func buildFileCard(file: SafeDocumentData, scale: CGFloat) -> some View {
        HStack(spacing: 14 * scale) {
            buildFileIcon(file: file, scale: scale)
            
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(file.displayName)
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                Text(file.fileSizeFormatted)
                    .font(.system(size: 13 * scale))
                    .foregroundColor(CMColor.tertiaryText)
            }
            
            Spacer()
            
            if !multiSelectEnabled {
                Button(action: {
                    itemToView = file
                    displayViewer = true
                }) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 18 * scale))
                        .foregroundColor(CMColor.accent)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(CMColor.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
                }
            }
            
            if multiSelectEnabled {
                Button(action: {
                    if selectedItems.contains(file.id) {
                        selectedItems.remove(file.id)
                    } else {
                        selectedItems.insert(file.id)
                    }
                }) {
                    Image(systemName: selectedItems.contains(file.id) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22 * scale))
                        .foregroundColor(selectedItems.contains(file.id) ? CMColor.success : CMColor.iconSecondary)
                }
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 14 * scale)
        .contentShape(Rectangle())
        .onTapGesture {
            if multiSelectEnabled {
                if selectedItems.contains(file.id) {
                    selectedItems.remove(file.id)
                } else {
                    selectedItems.insert(file.id)
                }
            } else {
                itemToView = file
                displayViewer = true
            }
        }
    }
    
    private func buildFileIcon(file: SafeDocumentData, scale: CGFloat) -> some View {
        let isImg = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif"].contains(file.fileExtension?.lowercased() ?? "")
        
        return ZStack {
            RoundedRectangle(cornerRadius: 10 * scale)
                .fill(isImg ? Color.clear : CMColor.accent.opacity(0.15))
                .frame(width: 40 * scale, height: 40 * scale)
            
            if isImg {
                ImageThumbnailView(documentURL: file.documentURL, scalingFactor: scale)
            } else {
                Image(systemName: file.iconName)
                    .font(.system(size: 20 * scale, weight: .semibold))
                    .foregroundColor(CMColor.accent)
            }
        }
    }
    
    private func buildActionControls(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            if processingFiles {
                HStack(spacing: 12 * scale) {
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text("Processing imports...")
                        .font(.system(size: 15 * scale, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54 * scale)
                .background(CMColor.accent.opacity(0.6))
                .cornerRadius(14 * scale)
            } else {
                Button(action: {
                    showFilePicker = true
                }) {
                    HStack(spacing: 8 * scale) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18 * scale))
                        
                        Text("Import More")
                            .font(.system(size: 15 * scale, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54 * scale)
                    .background(
                        RoundedRectangle(cornerRadius: 14 * scale)
                            .fill(CMColor.primaryGradient)
                    )
                }
                .disabled(processingFiles)
            }
            
            if multiSelectEnabled && !selectedItems.isEmpty {
                Button(action: {
                    showDeleteWarning = true
                }) {
                    HStack(spacing: 10 * scale) {
                        Image(systemName: "xmark.bin")
                            .font(.system(size: 17 * scale, weight: .semibold))
                        
                        Text("Remove (\(selectedItems.count))")
                            .font(.system(size: 15 * scale, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54 * scale)
                    .background(CMColor.error)
                    .cornerRadius(14 * scale)
                }
                .disabled(processingFiles)
            }
        }
        .padding(.top, 24 * scale)
        .animation(.easeInOut(duration: 0.25), value: processingFiles)
    }
    
    private func formatFileDate(_ date: Date) -> String {
        let cal = Calendar.current
        
        if cal.isDateInToday(date) {
            return "Recent"
        } else if cal.isDateInYesterday(date) {
            return "Previous Day"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "d MMM yyyy"
            return fmt.string(from: date)
        }
    }
    
    private func processPickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var readyFiles: [PickerDocResult] = []
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    continue
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let fileData = try Data(contentsOf: url)
                    let name = url.lastPathComponent
                    let ext = url.pathExtension.isEmpty ? nil : url.pathExtension
                    
                    let item = PickerDocResult(
                        data: fileData,
                        fileName: name,
                        fileExtension: ext,
                        originalURL: url
                    )
                    
                    readyFiles.append(item)
                } catch {
                }
            }
            
            if !readyFiles.isEmpty {
                pendingFiles = readyFiles
                showCleanupPrompt = true
            }
            
        case .failure(_):
            break
        }
    }
    
    private func storeAndCleanup() async {
        processingFiles = true
        
        for item in pendingFiles {
            await storeSingleItem(item)
            
            let url = item.originalURL
            
            do {
                let access = url.startAccessingSecurityScopedResource()
                
                defer {
                    if access {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                let fm = FileManager.default
                let exists = fm.fileExists(atPath: url.path)
                let canDelete = fm.isDeletableFile(atPath: url.path)
                
                if exists && canDelete {
                    try fm.removeItem(at: url)
                } else if url.path.contains("/Inbox/") {
                    try fm.removeItem(at: url)
                }
            } catch {
            }
        }
        
        await MainActor.run {
            pendingFiles.removeAll()
            processingFiles = false
            storageHandler.objectWillChange.send()
        }
    }
    
    private func storeWithoutCleanup() async {
        processingFiles = true
        
        for item in pendingFiles {
            await storeSingleItem(item)
        }
        
        await MainActor.run {
            pendingFiles.removeAll()
            processingFiles = false
            storageHandler.objectWillChange.send()
        }
    }
    
    private func storeSingleItem(_ item: PickerDocResult) async {
        _ = await storageHandler.saveDocumentAsync(
            documentData: item.data,
            fileName: item.fileName,
            fileExtension: item.fileExtension
        )
    }
    
    private func executeRemoval() {
        let toRemove = storedFiles.filter { file in
            selectedItems.contains(file.id)
        }
        
        storageHandler.deleteDocuments(toRemove)
        selectedItems.removeAll()
        multiSelectEnabled = false
    }
}
