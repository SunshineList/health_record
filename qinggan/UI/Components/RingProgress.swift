import SwiftUI

struct RingProgress: View {
    let progress: Double
    let color: Color
    let title: String
    let valueText: String
    var body: some View {
        let pct = min(max(progress, 0), 1)
        let ringColor = progress > 1 ? Color.red : color
        ZStack {
            Circle().stroke(Color.gray.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(title).font(.footnote).foregroundColor(.secondary)
                Text(valueText).font(.headline)
                Text(String(format: "%.0f%%", pct*100)).font(.caption).foregroundColor(.secondary)
            }
        }
        .frame(width: 112, height: 112)
    }
}
