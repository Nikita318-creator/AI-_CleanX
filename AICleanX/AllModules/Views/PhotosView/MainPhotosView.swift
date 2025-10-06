import SwiftUI
import PhotosUI

struct MainPhotosView: View {
    var body: some View {
        NavigationView {
            if #available(iOS 16.0, *) {
                PhotosView()
            } else {
                PhotosViewLegacy()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) 
    }
}
