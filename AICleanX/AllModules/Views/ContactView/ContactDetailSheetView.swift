import SwiftUI

struct ContactDetailSheetView: View {
    let contactData: ContactData
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            AICleanerContactDetailView(contactData: contactData, isPresented: $isPresented)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Готово") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}
