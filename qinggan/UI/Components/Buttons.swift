import SwiftUI

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.brand))
        .shadow(color: AppTheme.brand.opacity(0.25), radius: 8, x: 0, y: 4)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2)))
    }
}

struct PrimaryLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppTheme.brand))
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
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.2)))
    }
}