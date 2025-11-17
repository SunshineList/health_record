//
//  qingganApp.swift
//  qinggan
//
//  Created by Tuple on 2025/11/17.
//

import SwiftUI
import CoreData

@main
struct qingganApp: App {
    let persistenceController = PersistenceController.shared
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                AppRootView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .opacity(showSplash ? 0 : 1)
                if showSplash { SplashView() }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation(.easeInOut) { showSplash = false } }
            }
        }
    }
}
