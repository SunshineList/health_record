import SwiftUI

struct AppRootView: View {
    @State private var selectedTab: Int = 0
    @State private var appearance: String = ConfigStore.shared.load().appearance ?? "system"
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab).tabItem { Image(systemName: "house"); Text("首页") }.tag(0)
            LogView().tabItem { Image(systemName: "camera"); Text("记录") }.tag(1)
            DashboardView().tabItem { Image(systemName: "chart.bar"); Text("趋势面板") }.tag(2)
            ChatView().tabItem { Image(systemName: "message"); Text("AI教练") }.tag(3)
            SettingsView().tabItem { Image(systemName: "gearshape"); Text("设置") }.tag(4)
        }
        .preferredColorScheme(appColorScheme(for: appearance))
        .onReceive(NotificationCenter.default.publisher(for: SettingsViewModel.settingsDidChange)) { _ in appearance = ConfigStore.shared.load().appearance ?? "system" }
    }
}

private func appColorScheme(for appearance: String) -> ColorScheme? {
    switch appearance { case "light": return .light; case "dark": return .dark; default: return nil }
}