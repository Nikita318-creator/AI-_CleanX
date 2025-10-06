import SwiftUI

struct SimpleDocumentPreviewView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismiss
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
                    ScrollView {
                        VStack(spacing: 24 * scalingFactor) {
                            // Document icon and basic info
                            documentHeaderView(scalingFactor: scalingFactor)
                            
                            // Document details
                            documentDetailsView(scalingFactor: scalingFactor)
                            
                            // Share button
                            shareButtonView(scalingFactor: scalingFactor)
                        }
                        .padding(.horizontal, 16 * scalingFactor)
                        .padding(.vertical, 32 * scalingFactor)
                    }
                }
            }
        }
        .onAppear {
            print("🚀 SimpleDocumentPreviewView appeared for: \(document.fileName)")
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [document.documentURL])
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
            
            Text("Document")
                .font(.system(size: 17 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            Spacer()
            
            Button(action: {
                showShareSheet = true
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
        }
        .padding(.horizontal, 16 * scalingFactor)
        .padding(.vertical, 12 * scalingFactor)
        .background(CMColor.background)
    }
    
    // MARK: - Document Header
    private func documentHeaderView(scalingFactor: CGFloat) -> some View {
        VStack(spacing: 16 * scalingFactor) {
            // Large document icon
            ZStack {
                Circle()
                    .fill(CMColor.primary.opacity(0.1))
                    .frame(width: 120 * scalingFactor, height: 120 * scalingFactor)
                
                Image(systemName: document.iconName)
                    .font(.system(size: 48 * scalingFactor, weight: .medium))
                    .foregroundColor(CMColor.primary)
            }
            
            // Document name
            VStack(spacing: 8 * scalingFactor) {
                Text(document.fileName)
                    .font(.system(size: 20 * scalingFactor, weight: .semibold))
                    .foregroundColor(CMColor.primaryText)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 8 * scalingFactor) {
                    Text(document.fileSizeFormatted)
                        .font(.system(size: 16 * scalingFactor))
                        .foregroundColor(CMColor.secondaryText)
                    
                    if let fileExtension = document.fileExtension {
                        Text("•")
                            .font(.system(size: 16 * scalingFactor))
                            .foregroundColor(CMColor.secondaryText)
                        
                        Text(fileExtension.uppercased())
                            .font(.system(size: 16 * scalingFactor, weight: .medium))
                            .foregroundColor(CMColor.secondaryText)
                    }
                }
            }
        }
    }
    
    // MARK: - Document Details
    private func documentDetailsView(scalingFactor: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16 * scalingFactor) {
            Text("Document Information")
                .font(.system(size: 18 * scalingFactor, weight: .semibold))
                .foregroundColor(CMColor.primaryText)
            
            VStack(spacing: 12 * scalingFactor) {
                detailRow(title: "File Name", value: document.fileName, scalingFactor: scalingFactor)
                detailRow(title: "File Size", value: document.fileSizeFormatted, scalingFactor: scalingFactor)
                
                if let fileExtension = document.fileExtension {
                    detailRow(title: "File Type", value: fileExtension.uppercased(), scalingFactor: scalingFactor)
                }
                
                if let mimeType = document.mimeType {
                    detailRow(title: "MIME Type", value: mimeType, scalingFactor: scalingFactor)
                }
                
                detailRow(title: "Date Added", value: formatDate(document.dateAdded), scalingFactor: scalingFactor)
                detailRow(title: "Created", value: formatDate(document.createdAt), scalingFactor: scalingFactor)
                detailRow(title: "Storage Path", value: document.documentURL.lastPathComponent, scalingFactor: scalingFactor)
            }
        }
        .padding(20 * scalingFactor)
        .background(CMColor.surface)
        .cornerRadius(16 * scalingFactor)
        .overlay(
            RoundedRectangle(cornerRadius: 16 * scalingFactor)
                .stroke(CMColor.border, lineWidth: 1)
        )
    }
    
    private func detailRow(title: String, value: String, scalingFactor: CGFloat) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 14 * scalingFactor, weight: .medium))
                .foregroundColor(CMColor.secondaryText)
                .frame(width: 100 * scalingFactor, alignment: .leading)
            
            Text(value)
                .font(.system(size: 14 * scalingFactor))
                .foregroundColor(CMColor.primaryText)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
    
    // MARK: - Share Button
    private func shareButtonView(scalingFactor: CGFloat) -> some View {
        Button(action: {
            showShareSheet = true
        }) {
            HStack(spacing: 8 * scalingFactor) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16 * scalingFactor, weight: .medium))
                
                Text("Share Document")
                    .font(.system(size: 16 * scalingFactor, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50 * scalingFactor)
            .background(CMColor.primary)
            .cornerRadius(25 * scalingFactor)
        }
    }
    
    // MARK: - Helper Methods
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    SimpleDocumentPreviewView(
        document: SafeDocumentData(
            documentURL: URL(fileURLWithPath: "/tmp/sample.pdf"),
            fileName: "Sample Document.pdf",
            fileSize: 1024000,
            fileExtension: "pdf"
        )
    )
}
