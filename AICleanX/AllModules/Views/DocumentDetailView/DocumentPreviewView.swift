import SwiftUI
import QuickLook

struct DocumentPreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismiss
    @State private var documentURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showShareSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerView(scalingFactor: scalingFactor)
                    
                    // Content
                    if isLoading {
                        loadingView(scalingFactor: scalingFactor)
                    } else if let errorMessage = errorMessage {
                        errorView(errorMessage: errorMessage, scalingFactor: scalingFactor)
                    } else if let documentURL = documentURL {
                        documentContentView(url: documentURL, scalingFactor: scalingFactor)
                    } else {
                        // Fallback view
                        VStack(spacing: 16 * scalingFactor) {
                            Text("Document Preview")
                                .font(.system(size: 18 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            
                            Text("Loading document: \(document.fileName)")
                                .font(.system(size: 14 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onAppear {
            print("🚀 DocumentPreviewView appeared for: \(document.fileName)")
            loadDocument()
        }
        .sheet(isPresented: $showShareSheet) {
            if let documentURL = documentURL {
                ActivityView(activityItems: [documentURL])
            }
        }
    }
    
    // MARK: - Header
    private func headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                    
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.primary)
                }
            }
            
            Spacer()
            
            Text(document.displayName)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
            
            Spacer()
            
            // Share button
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            .opacity(documentURL != nil ? 1 : 0.5)
            .disabled(documentURL == nil)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.background)
    }
    
    // MARK: - Loading View
    private func loadingView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading document...")
                .font(.system(size: 16 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    private func errorView(errorMessage: String, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 24 * scalingFactor) {
            Spacer()
            
            // Error icon
            ZStack {
                Circle()
                    .fill(CMColor.backgroundSecondary)
                    .frame(width: 80 * scalingFactor, height: 80 * scalingFactor)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
            }
            
            VStack(spacing: 8 * scalingFactor) {
                Text("Cannot preview document")
                    .font(.system(size: 18 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                
                Text(errorMessage)
                    .font(.system(size: 14 * scalingFactor))
                    .foregroundColor(CMColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32 * scalingFactor)
            }
            
            // Document info card
            documentInfoCard(scalingFactor: scalingFactor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Document Content View
    private func documentContentView(url: URL, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Document info bar
            documentInfoBar(scalingFactor: scalingFactor)
            
            // Document preview content
            ScrollView {
                VStack(spacing: 16 * scalingFactor) {
                    // Document info card
                    documentInfoCard(scalingFactor: scalingFactor)
                    
                    // File details
                    documentDetailsView(scalingFactor: scalingFactor)
                    
                    // QuickLook preview (if supported)
                    if QLPreviewController.canPreview(url as QLPreviewItem) {
                        VStack(spacing: 12 * scalingFactor) {
                            Text("Document Preview")
                                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                                .foregroundColor(CMColor.primaryText)
                            
                            DocumentQuickLookView(url: url)
                                .frame(height: 400 * scalingFactor)
                                .clipShape(RoundedRectangle(cornerRadius: 12 * scalingFactor))
                                .onAppear {
                                    print("📱 QuickLook view appeared for: \(url.lastPathComponent)")
                                }
                        }
                    } else {
                        // Not previewable - show file info
                        VStack(spacing: 12 * scalingFactor) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                            
                            Text("Preview not available")
                                .font(.system(size: 16 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.primaryText)
                            
                            Text("This document type cannot be previewed, but you can still share it.")
                                .font(.system(size: 14 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32 * scalingFactor)
                        }
                        .padding(.vertical, 32 * scalingFactor)
                    }
                }
                .padding(.horizontal, 16 * scalingFactor)
                .padding(.bottom, 32 * scalingFactor)
            }
        }
    }
    
    // MARK: - Document Info Bar
    private func documentInfoBar(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            // Document icon
            ZStack {
                RoundedRectangle(cornerRadius: 8 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 40 * scalingFactor, height: 40 * scalingFactor)
                
                Image(systemName: document.iconName)
                    .font(.system(size: 20 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            // Document details
            VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                Text(document.fileName)
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 8 * scalingFactor) {
                    Text(document.fileSizeFormatted)
                        .font(.system(size: 12 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                    
                    if let fileExtension = document.fileExtension {
                        Text("•")
                            .font(.system(size: 12 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text(fileExtension.uppercased())
                            .font(.system(size: 12 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(CMColor.border)
            , alignment: .bottom
        )
    }
    
    // MARK: - Document Details View
    private func documentDetailsView(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scalingFactor) {
            Text("Document Details")
                .font(.system(size: 16 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            VStack(spacing: 8 * scalingFactor) {
                detailRow(title: "File Name", value: document.fileName, scalingFactor: scalingFactor)
                detailRow(title: "File Size", value: document.fileSizeFormatted, scalingFactor: scalingFactor)
                
                if let fileExtension = document.fileExtension {
                    detailRow(title: "File Type", value: fileExtension.uppercased(), scalingFactor: scalingFactor)
                }
                
                detailRow(title: "Date Added", value: formatDate(document.dateAdded), scalingFactor: scalingFactor)
                detailRow(title: "File Path", value: document.documentURL.lastPathComponent, scalingFactor: scalingFactor)
            }
        }
        .padding(16 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(12 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
    }
    
    private func detailRow(title: String, value: String, scalingFactor: CGFloat) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14 * scalingFactor))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
        }
    }
    
    // MARK: - Document Info Card
    private func documentInfoCard(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scalingFactor) {
            HStack(spacing: 12 * scalingFactor) {
                // Document icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 48 * scalingFactor, height: 48 * scalingFactor)
                    
                    Image(systemName: document.iconName)
                        .font(.system(size: 24 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
                // Document details
                VStack(alignment: .leading, spacing: 4 * scalingFactor) {
                    Text(document.fileName)
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                        .lineLimit(2)
                    
                    HStack(spacing: 8 * scalingFactor) {
                        Text(document.fileSizeFormatted)
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        if let fileExtension = document.fileExtension {
                            Text("•")
                                .font(.system(size: 14 * scalingFactor))
                                .foregroundColor(CMColor.secondaryText)
                            
                            Text(fileExtension.uppercased())
                                .font(.system(size: 14 * scalingFactor, weight: .medium))
                                .foregroundColor(CMColor.secondaryText)
                        }
                    }
                    
                    Text("Added \(formatDate(document.dateAdded))")
                        .font(.system(size: 12 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
            }
        }
        .padding(16 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(12 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
        .padding(.horizontal, 32 * scalingFactor)
    }
    
    // MARK: - Helper Methods
    private func loadDocument() {
        isLoading = true
        errorMessage = nil
        
        print("🔍 Loading document: \(document.fileName)")
        print("📁 Document path: \(document.documentURL.path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Check if file exists
            let fileExists = FileManager.default.fileExists(atPath: document.documentURL.path)
            print("📄 File exists: \(fileExists)")
            
            if !fileExists {
                DispatchQueue.main.async {
                    self.errorMessage = "Document file not found at path: \(self.document.documentURL.path)"
                    self.isLoading = false
                    print("❌ Document file not found")
                }
                return
            }
            
            // Check if file is readable
            let isReadable = FileManager.default.isReadableFile(atPath: document.documentURL.path)
            print("📖 File is readable: \(isReadable)")
            
            if !isReadable {
                DispatchQueue.main.async {
                    self.errorMessage = "Document file is not readable"
                    self.isLoading = false
                    print("❌ Document file is not readable")
                }
                return
            }
            
            // Get file size for debugging
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: document.documentURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                print("📊 File size: \(fileSize) bytes")
            } catch {
                print("⚠️ Could not get file attributes: \(error)")
            }
            
            // File exists and is readable, set the URL for preview
            DispatchQueue.main.async {
                self.documentURL = self.document.documentURL
                self.isLoading = false
                print("✅ Document loaded successfully for preview")
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return "today at \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}
