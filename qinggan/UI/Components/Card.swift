import SwiftUI

struct Card<Content: View>: View {
    let content: () -> Content
    var body: some View {
        content()
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.10)))
            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}