import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [AppTheme.brand, AppTheme.brand.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 140, height: 140)
                    Image(systemName: "heart.fill").resizable().scaledToFit().frame(width: 72, height: 72).foregroundColor(.white)
                }
                Text("健康追踪者").font(.system(size: 24, weight: .semibold)).foregroundColor(.white)
                ProgressView().tint(.white)
            }
        }
        .statusBarHidden(true)
    }
}