import SwiftUI

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Text(title)
        }
        .buttonStyle(HealthChipStyle(selected: selected))
    }
}