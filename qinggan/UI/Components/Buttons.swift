import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [AppTheme.brandDark, AppTheme.brand], startPoint: .topLeading, endPoint: .bottomTrailing)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.0)))
        .shadow(color: AppTheme.brand.opacity(0.16), radius: 6, x: 0, y: 3)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.brand.opacity(0.25)))
}
}

struct PrimaryLabel: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [AppTheme.brandDark, AppTheme.brand], startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
}

struct SecondaryLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.brand.opacity(0.25)))
    }
}