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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
