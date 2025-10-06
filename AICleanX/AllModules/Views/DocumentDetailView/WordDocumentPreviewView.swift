import SwiftUI
import QuickLook
import Foundation

struct DocumentDetailView: View {
    let document: SafeDocumentData
    @Environment(\.dismiss) private var dismissAction
    @EnvironmentObject private var dataStore: SafeStorageManager // Переименовано safeStorageManager
    
    // Переименованные приватные переменные состояния
    @State private var isExportFlowActive = false // Переименовано isSharingActive
    @State private var isDeleteConfirmationShown = false // Переименовано isConfirmingDeletion
    @State private var isDeletionProcessActive = false // Переименовано isRemovalInProgress
    
    // Переименованная приватная переменная
    private var layoutScale: CGFloat { // Переименовано uiScaleFactor
        UIScreen.main.bounds.height / 844
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CMColor.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    fileHeader(safeAreaTop: geometry.safeAreaInsets.top) // Переименован вызов fileNavigationBar
                    fileContentArea // Переименован вызов fileMainContent
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $isExportFlowActive) { // Обновлено $isExportFlowActive
            ActivityView(activityItems: [document.documentURL])
        }
        // Обновлены текстовки для alert
        .alert("Confirm File Deletion", isPresented: $isDeleteConfirmationShown) { // Обновлен заголовок и переменная
            Button("Permanently Delete", role: .destructive) { // Обновлен текст кнопки
                startDeletionProcedure() // Переименованный вызов
            }
            Button("Cancel", role: .cancel) { } // Обновлен текст кнопки
        } message: {
            Text("Are you sure you want to delete the file \"\(document.fileName)\"? This action cannot be undone.") // Обновлен текст сообщения
        }
    }
    
    // Переименованная функция
    private func fileHeader(safeAreaTop: CGFloat) -> some View { // Переименовано fileNavigationBar
        HStack {
            Button(action: {
                dismissAction() // Обновлено dismiss()
            }) {
                HStack(spacing: 6 * layoutScale) { // Обновлено layoutScale
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16 * layoutScale, weight: .semibold)) // Обновлено layoutScale
                    Text("Go Back") // Обновлено с "Return"
                        .font(.system(size: 16 * layoutScale, weight: .medium)) // Обновлено layoutScale
                }
                .foregroundColor(CMColor.primary)
            }
            
            Spacer()
            
            Text(document.fileName)
                .font(.system(size: 16 * layoutScale, weight: .semibold)) // Обновлено layoutScale
                .foregroundColor(CMColor.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            HStack(spacing: 16 * layoutScale) { // Обновлено layoutScale
                Button(action: {
                    isExportFlowActive = true // Обновлено
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18 * layoutScale, weight: .medium)) // Обновлено layoutScale
                        .foregroundColor(CMColor.primary)
                }
                
                Button(action: {
                    isDeleteConfirmationShown = true // Обновлено
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 18 * layoutScale, weight: .medium)) // Обновлено layoutScale
                        .foregroundColor(CMColor.error)
                }
            }
        }
        .padding(.horizontal, 16 * layoutScale) // Обновлено layoutScale
        .padding(.top, safeAreaTop + 8 * layoutScale) // Обновлено layoutScale
        .padding(.bottom, 12 * layoutScale) // Обновлено layoutScale
        .background(
            CMColor.background
                .shadow(color: CMColor.black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
    }
    
    // MARK: - Document Content View
    // Переименованный computed property
    private var fileContentArea: some View { // Переименовано fileMainContent
        VStack(spacing: 0) {
            fileInfoDisplay // Переименован вызов fileDetailsHeader
            fileDisplayView // Переименован вызов fileVisualArea
        }
    }
    
    // Переименованный computed property
    private var fileInfoDisplay: some View { // Переименовано fileDetailsHeader
        VStack(spacing: 16 * layoutScale) { // Обновлено layoutScale
            HStack(spacing: 12 * layoutScale) { // Обновлено layoutScale
                ZStack {
                    RoundedRectangle(cornerRadius: 8 * layoutScale) // Обновлено layoutScale
                        .fill(CMColor.primary.opacity(0.1))
                        .frame(width: 40 * layoutScale, height: 40 * layoutScale) // Обновлено layoutScale
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20 * layoutScale)) // Обновлено layoutScale
                        .foregroundColor(CMColor.primary)
                }
                
                VStack(alignment: .leading, spacing: 2 * layoutScale) { // Обновлено layoutScale
                    Text(document.fileName)
                        .font(.system(size: 16 * layoutScale, weight: .medium)) // Обновлено layoutScale
                        .foregroundColor(CMColor.primaryText)
                        .lineLimit(1)
                    
                    Text("\(document.fileSizeFormatted) • \(document.fileExtension?.uppercased() ?? "FILE")") // Обновлено "DOC"
                        .font(.system(size: 14 * layoutScale)) // Обновлено layoutScale
                        .foregroundColor(CMColor.secondaryText)
                }
                
                Spacer()
            }
            .padding(.all, 16 * layoutScale) // Обновлено layoutScale
            .background(CMColor.surface)
            .cornerRadius(12 * layoutScale) // Обновлено layoutScale
            .overlay(
                RoundedRectangle(cornerRadius: 12 * layoutScale) // Обновлено layoutScale
                    .stroke(CMColor.border.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16 * layoutScale) // Обновлено layoutScale
        .padding(.top, 16 * layoutScale) // Обновлено layoutScale
    }
    
    // Переименованный computed property
    private var fileDisplayView: some View { // Переименовано fileVisualArea
        VStack(spacing: 0) {
            if QLPreviewController.canPreview(document.documentURL as QLPreviewItem) {
                SecuredQuickLookView(url: document.documentURL) // Переименованный struct
                    .background(CMColor.white)
                    .cornerRadius(0)
                    .padding(.horizontal, 16 * layoutScale) // Обновлено layoutScale
            } else {
                previewUnavailableView // Переименован вызов unsupportedFormatView
            }
        }
    }
    
    // Переименованный computed property
    private var previewUnavailableView: some View { // Переименовано unsupportedFormatView
        VStack(spacing: 20 * layoutScale) { // Обновлено layoutScale
            Spacer()
            
            VStack(spacing: 16 * layoutScale) { // Обновлено layoutScale
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48 * layoutScale)) // Обновлено layoutScale
                    .foregroundColor(CMColor.primary.opacity(0.6))
                
                VStack(spacing: 8 * layoutScale) { // Обновлено layoutScale
                    Text("File Preview Not Supported") // Обновлено с "Visualization Unavailable"
                        .font(.system(size: 18 * layoutScale, weight: .semibold)) // Обновлено layoutScale
                        .foregroundColor(CMColor.primaryText)
                    
                    // Обновленный текст
                    Text("This file format cannot be displayed directly within the application. Please use the Export option to open it in a compatible external app.")
                        .font(.system(size: 14 * layoutScale)) // Обновлено layoutScale
                        .foregroundColor(CMColor.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32 * layoutScale) // Обновлено layoutScale
                }
                
                Button(action: {
                    isExportFlowActive = true // Обновлено
                }) {
                    HStack(spacing: 8 * layoutScale) { // Обновлено layoutScale
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16 * layoutScale, weight: .medium)) // Обновлено layoutScale
                        
                        Text("Export to External App") // Обновлено с "Export to External Viewer"
                            .font(.system(size: 16 * layoutScale, weight: .semibold)) // Обновлено layoutScale
                    }
                    .foregroundColor(.white)
                    .frame(height: 48 * layoutScale) // Обновлено layoutScale
                    .frame(maxWidth: 240 * layoutScale) // Обновлено layoutScale
                    .background(CMColor.primary)
                    .cornerRadius(24 * layoutScale) // Обновлено layoutScale
                }
                .padding(.top, 8 * layoutScale) // Обновлено layoutScale
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16 * layoutScale) // Обновлено layoutScale
    }
    
    // Переименованная функция
    private func startDeletionProcedure() { // Переименовано initiateFileRemoval
        isDeletionProcessActive = true // Обновлено
        dataStore.deleteDocuments([document]) // Обновлено safeStorageManager
        dismissAction() // Обновлено dismiss()
    }
}
