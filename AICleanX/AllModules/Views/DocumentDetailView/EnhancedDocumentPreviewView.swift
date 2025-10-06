import SwiftUI
import QuickLook
import PDFKit
import WebKit
import Foundation

struct EnhancedDocumentPreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var p_dismiss
    @EnvironmentObject private var p_storageManager: SafeStorageManager
    
    @State private var p_documentContent: PreviewContent = .loading
    @State private var p_showShareSheet = false
    @State private var p_showDeleteAlert = false
    @State private var p_isDeletionActive = false
    
    private enum PreviewContent {
        case loading
        case text(String)
        case pdf(PDFDocument)
        case image(UIImage)
        case web(String)
        case unsupported
        case error(String)
    }
    
    var body: some View {
        Group {
            if let fileExtension = document.fileExtension?.lowercased() {
                switch fileExtension {
                case "doc", "docx":
                    DocumentDetailView(document: document)
                        .environmentObject(p_storageManager)
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "heif":
                    DocImagePreviewView(document: document)
                        .environmentObject(p_storageManager)
                default:
                    p_originalPreview
                }
            } else {
                p_originalPreview
            }
        }
    }
    
    // MARK: - Core Preview
    private var p_originalPreview: some View {
        GeometryReader { geometry in
            let scalingFactor = geometry.size.height / 844
            
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    p_headerView(scalingFactor: scalingFactor)
                    p_contentView(scalingFactor: scalingFactor)
                }
            }
        }
        .onAppear {
            p_loadContent()
        }
        .sheet(isPresented: $p_showShareSheet) {
            ActivityView(activityItems: [document.documentURL])
        }
        .alert("Delete Document", isPresented: $p_showDeleteAlert) {
            Button("Delete", role: .destructive) {
                p_deleteContent()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(document.fileName)\"? This action cannot be undone.")
        }
    }
    
    // MARK: - Header
    private func p_headerView(scalingFactor: CGFloat) -> some View {
        HStack {
            Button(action: {
                p_dismiss()
            }) {
                HStack(spacing: 6 * scalingFactor) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    Text("Back")
                        .font(.system(size: 16 * scalingFactor))
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text(document.displayName)
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button(action: {
                p_showDeleteAlert = true
            }) {
                if p_isDeletionActive {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: CMColor.error))
                } else {
                    Text("Delete")
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.error)
                }
            }
            .disabled(p_isDeletionActive)
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.background)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(CMColor.border)
            , alignment: .bottom
        )
    }
    
    // MARK: - Content View
    @ViewBuilder
    private func p_contentView(scalingFactor: CGFloat) -> some View {
        switch p_documentContent {
        case .loading:
            p_loadingScreen(scalingFactor: scalingFactor)
            
        case .text(let content):
            p_textPreview(content: content, scalingFactor: scalingFactor)
            
        case .pdf(let pdfDocument):
            p_pdfPreview(pdfDocument: pdfDocument, scalingFactor: scalingFactor)
            
        case .image(let image):
            p_imagePreview(image: image, scalingFactor: scalingFactor)
            
        case .web(let htmlContent):
            p_webPreview(htmlContent: htmlContent, scalingFactor: scalingFactor)
            
        case .unsupported:
            p_unsupportedScreen(scalingFactor: scalingFactor)
            
        case .error(let errorMessage):
            p_errorScreen(errorMessage: errorMessage, scalingFactor: scalingFactor)
        }
    }
    
    // MARK: - Content Screens
    private func p_loadingScreen(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading document...")
                .font(.system(size: 16 * scalingFactor))
                .foregroundColor(CMColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func p_textPreview(content: String, scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16 * scalingFactor) {
                p_infoCard(scalingFactor: scalingFactor)
                
                VStack(alignment: .leading, spacing: 12 * scalingFactor) {
                    Text("Document Content")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(content)
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.primaryText)
                        .lineSpacing(4 * scalingFactor)
                        .textSelection(.enabled)
                        .padding(16 * scalingFactor)
                        .background(CMColor.white)
                        .cornerRadius(12 * scalingFactor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12 * scalingFactor)
                                .stroke(CMColor.border, lineWidth: 1)
                        )
                }
                
                p_actionButtons(scalingFactor: scalingFactor)
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    private func p_pdfPreview(pdfDocument: PDFDocument, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            p_infoBar(scalingFactor: scalingFactor)
            
            DocPDFPresentView(pdfDocument: pdfDocument)
                .background(CMColor.white)
        }
    }
    
    private func p_imagePreview(image: UIImage, scalingFactor: CGFloat) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 16 * scalingFactor) {
                p_infoCard(scalingFactor: scalingFactor)
                    .padding(.horizontal, 16 * scalingFactor)
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(CMColor.white)
                    .cornerRadius(12 * scalingFactor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12 * scalingFactor)
                            .stroke(CMColor.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 16 * scalingFactor)
                
                p_actionButtons(scalingFactor: scalingFactor)
                    .padding(.horizontal, 16 * scalingFactor)
            }
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    private func p_webPreview(htmlContent: String, scalingFactor: CGFloat) -> some View {
        VStack(spacing: 0) {
            p_infoBar(scalingFactor: scalingFactor)
            
            WebViewRepresentable(htmlContent: htmlContent)
                .background(CMColor.white)
        }
    }
    
    private func p_unsupportedScreen(scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                Spacer()
                
                p_infoCard(scalingFactor: scalingFactor)
                
                if let fileExtension = document.fileExtension?.lowercased(),
                   ["doc", "docx"].contains(fileExtension) {
                    
                    VStack(spacing: 16 * scalingFactor) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 48 * scalingFactor))
                            .foregroundColor(CMColor.primary)
                        
                        Text("Word Document")
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text("Text extraction unavailable, but you can view the document using the system preview.")
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32 * scalingFactor)
                        
                        if QLPreviewController.canPreview(document.documentURL as QLPreviewItem) {
                            DocumentQuickLookView(url: document.documentURL)
                                .frame(height: 400 * scalingFactor)
                                .clipShape(RoundedRectangle(cornerRadius: 12 * scalingFactor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12 * scalingFactor)
                                        .stroke(CMColor.border, lineWidth: 1)
                                )
                        }
                    }
                } else {
                    VStack(spacing: 16 * scalingFactor) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text("Preview not available")
                            .font(.system(size: 18 * scalingFactor, weight: .semibold))
                            .foregroundColor(CMColor.primaryText)
                        
                        Text("This document type cannot be previewed, but you can still share or export it.")
                            .font(.system(size: 14 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32 * scalingFactor)
                    }
                }
                
                p_actionButtons(scalingFactor: scalingFactor)
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    private func p_errorScreen(errorMessage: String, scalingFactor: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 24 * scalingFactor) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48 * scalingFactor))
                    .foregroundColor(CMColor.error)
                
                VStack(spacing: 8 * scalingFactor) {
                    Text("Cannot load document")
                        .font(.system(size: 18 * scalingFactor, weight: .semibold))
                        .foregroundColor(CMColor.primaryText)
                    
                    Text(errorMessage)
                        .font(.system(size: 14 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * scalingFactor)
                }
                
                p_infoCard(scalingFactor: scalingFactor)
                
                Spacer()
            }
            .padding(.horizontal, 16 * scalingFactor)
            .padding(.vertical, 20 * scalingFactor)
        }
    }
    
    // MARK: - Reusable Components
    private func p_infoCard(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scalingFactor) {
            HStack(spacing: 12 * scalingFactor) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8 * scalingFactor)
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 48 * scalingFactor, height: 48 * scalingFactor)
                    
                    Image(systemName: document.iconName)
                        .font(.system(size: 24 * scalingFactor, weight: .medium))
                        .foregroundColor(CMColor.primary)
                }
                
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
    }
    
    private func p_infoBar(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            ZStack {
                RoundedRectangle(cornerRadius: 6 * scalingFactor)
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 32 * scalingFactor, height: 32 * scalingFactor)
                
                Image(systemName: document.iconName)
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            VStack(alignment: .leading, spacing: 2 * scalingFactor) {
                Text(document.fileName)
                    .font(.system(size: 14 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 6 * scalingFactor) {
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
            
            Button(action: {
                p_showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.surface)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(CMColor.border)
            , alignment: .bottom
        )
    }
    
    private func p_actionButtons(scalingFactor: CGFloat) -> some View {
        HStack(spacing: 12 * scalingFactor) {
            Button(action: {
                p_showShareSheet = true
            }) {
                HStack(spacing: 8 * scalingFactor) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16 * scalingFactor, weight: .medium))
                    
                    Text("Share")
                        .font(.system(size: 16 * scalingFactor, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48 * scalingFactor)
                .background(CMColor.primary)
                .cornerRadius(12 * scalingFactor)
            }
        }
    }
    
    // MARK: - Data Operations
    private func p_loadContent() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = document.documentURL
                
                guard FileManager.default.fileExists(atPath: url.path) else {
                    DispatchQueue.main.async {
                        self.p_documentContent = .error("Document file not found")
                    }
                    return
                }
                
                let fileExtension = document.fileExtension?.lowercased() ?? ""
                
                switch fileExtension {
                case "pdf":
                    if let pdfDocument = PDFDocument(url: url) {
                        DispatchQueue.main.async {
                            self.p_documentContent = .pdf(pdfDocument)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.p_documentContent = .error("Cannot load PDF document")
                        }
                    }
                    
                case "txt", "md", "rtf":
                    let content = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.p_documentContent = .text(content)
                    }
                    
                case "html", "htm":
                    let htmlContent = try String(contentsOf: url, encoding: .utf8)
                    DispatchQueue.main.async {
                        self.p_documentContent = .web(htmlContent)
                    }
                    
                case "doc", "docx":
                    DispatchQueue.main.async {
                        self.p_documentContent = .unsupported
                    }
                    
                case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
                    if let image = UIImage(contentsOfFile: url.path) {
                        DispatchQueue.main.async {
                            self.p_documentContent = .image(image)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.p_documentContent = .error("Cannot load image")
                        }
                    }
                    
                default:
                    if let content = try? String(contentsOf: url, encoding: .utf8),
                       !content.isEmpty,
                       content.count < 100000 {
                        DispatchQueue.main.async {
                            self.p_documentContent = .text(content)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.p_documentContent = .unsupported
                        }
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.p_documentContent = .error("Error loading document: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func p_deleteContent() {
        p_isDeletionActive = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.p_storageManager.deleteDocuments([self.document])
            
            DispatchQueue.main.async {
                self.p_isDeletionActive = false
                self.p_dismiss()
            }
        }
    }
}
