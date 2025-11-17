import SwiftUI

struct Card<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.12)))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}