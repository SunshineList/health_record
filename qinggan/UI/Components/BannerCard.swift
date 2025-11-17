import SwiftUI

struct BannerCard: View {
    let icon: String
    let title: String
    let text: String
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
                .fill(LinearGradient(colors: [AppTheme.brandLight, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}