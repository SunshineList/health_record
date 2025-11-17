import SwiftUI

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(tint.opacity(0.16)).frame(width: 36, height: 36)
                    Image(systemName: icon).foregroundColor(tint)
                }
                Text(title).font(.footnote).foregroundColor(.secondary)
                Spacer()
            }
            Text(value).font(.system(size: 28, weight: .bold)).foregroundColor(.primary)
            Text(subtitle).font(.footnote).foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.12))
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}