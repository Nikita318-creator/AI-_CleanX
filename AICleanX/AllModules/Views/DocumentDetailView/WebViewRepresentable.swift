import SwiftUI
import QuickLook
import PDFKit
import WebKit
import Foundation

struct WebViewRepresentable: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlContent, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update if needed
    }
}
