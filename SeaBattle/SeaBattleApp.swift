//
//  SeaBattleApp.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 03/02/2024.
//

import SwiftUI

@main
struct SeaBattleApp: App {
    @State private var appState = AppState()
    @State private var premiumManager = PremiumManager()
    var body: some Scene {
        WindowGroup {
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad переезжает на новую оболочку в R2.6; до тех пор —
                    // старое меню.
                    iPadStartMenuView()
                } else {
                    AppShell()
                }
            }
            .environment(appState)
            .environment(premiumManager)
            .environment(\.locale, Locale(identifier: appState.language))
            .task {
                premiumManager.start()
                CloudSyncManager.shared.start()
            }
        }
    }
}
