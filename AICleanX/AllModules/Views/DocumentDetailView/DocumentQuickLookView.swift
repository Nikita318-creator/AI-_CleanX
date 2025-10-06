import SwiftUI
import QuickLook

struct DocumentQuickLookView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        
        controller.navigationItem.setHidesBackButton(true, animated: false)
        controller.navigationController?.setNavigationBarHidden(true, animated: false)
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        uiViewController.refreshCurrentPreviewItem()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var parent: DocumentQuickLookView
        
        init(_ parent: DocumentQuickLookView) {
            self.parent = parent
            super.init()
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
           1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            PreviewDocItemView(url: parent.url)
        }
        
        func previewController(_ controller: QLPreviewController, shouldOpen url: URL, for item: QLPreviewItem) -> Bool {
            false
        }
        
        func previewControllerDidDismiss(_ controller: QLPreviewController) { }
    }
}
