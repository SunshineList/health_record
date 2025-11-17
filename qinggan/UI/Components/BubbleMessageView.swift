import SwiftUI

struct BubbleMessageView: View {
    let content: String
    let isMe: Bool
    let timestamp: Date?
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isMe { Spacer(minLength: 0) } else { AvatarView(initial: "AI") }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                Text(content)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isMe ? AppTheme.brand.opacity(0.18) : Color.gray.opacity(0.12)))
                    .foregroundColor(.primary)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: isMe ? .trailing : .leading)
                if let t = timestamp { Text(timeString(t)).font(.caption2).foregroundColor(.secondary) }
            }
            if isMe { AvatarView(initial: "我") } else { Spacer(minLength: 0) }
        }
        .padding(.vertical, 8)
    }
}

private func timeString(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "HH:mm"; return f.string(from: date) }

struct AvatarView: View {
    let initial: String
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemBackground)).frame(width: 28, height: 28)
            Circle().stroke(initial == "AI" ? AppTheme.brand : Color.gray.opacity(0.4), lineWidth: 1).frame(width: 28, height: 28)
            Text(initial).font(.caption).foregroundColor(initial == "AI" ? AppTheme.brand : .secondary)
        }
    }
}