import SwiftUI

struct HealthChipStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        selected
                        ? LinearGradient(colors: [AppTheme.brandLight, Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.gray.opacity(colorScheme == .dark ? 0.20 : 0.10), Color.gray.opacity(colorScheme == .dark ? 0.20 : 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppTheme.brand.opacity(0.45) : Color.gray.opacity(0.18))
            )
            .foregroundColor(selected ? AppTheme.brandDark : .primary)
            .shadow(color: selected ? AppTheme.brand.opacity(0.10) : .clear, radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}