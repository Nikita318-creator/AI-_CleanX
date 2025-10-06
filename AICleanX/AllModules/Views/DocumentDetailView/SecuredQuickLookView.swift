import SwiftUI
import QuickLook
import Foundation

struct SecuredQuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        
        controller.navigationItem.setHidesBackButton(true, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.refreshCurrentPreviewItem()
    }
    
    func makeCoordinator() -> QuickLookCoordinator {
        QuickLookCoordinator(self)
    }
    
    class QuickLookCoordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var parent: SecuredQuickLookView
        
        init(_ parent: SecuredQuickLookView) { 
            self.parent = parent
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
        
        func previewControllerWillDismiss(_ controller: QLPreviewController) {}
    }
}

