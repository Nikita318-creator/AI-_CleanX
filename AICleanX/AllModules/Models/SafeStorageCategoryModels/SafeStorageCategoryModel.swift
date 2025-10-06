import SwiftUI

struct SafeStorageCategory: Identifiable {
    let id = UUID()
    let title: String
    let count: String
    let icon: String
    let color: Color
}

struct SafeStorageFile: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}
