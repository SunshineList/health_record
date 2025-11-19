import SwiftUI

struct BannerCard: View {
    let icon: String
    let title: String
    let text: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(AppTheme.brand)
                Text(title).font(.subheadline).foregroundColor(AppTheme.brand)
            }
            Text(text).font(.subheadline).foregroundColor(.primary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? LinearGradient(colors: [AppTheme.brand.opacity(0.2), Color(.secondarySystemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [AppTheme.brandLight, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.06) : Color.gray.opacity(0.12))
        )
        .shadow(color: (colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05)), radius: 8, x: 0, y: 4)
    }
}