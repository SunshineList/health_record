import SwiftUI

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).padding(.horizontal, 12).padding(.vertical, 6).background(RoundedRectangle(cornerRadius: 12).fill(selected ? AppTheme.brand.opacity(0.15) : Color.gray.opacity(0.12))).foregroundColor(selected ? AppTheme.brand : .primary)
        }
    }
}