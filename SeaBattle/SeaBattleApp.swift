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
    @State private var pointsShop = PointsShop()
    var body: some Scene {
        WindowGroup {
            // С R2.6 новая оболочка и на iPad: раскладку iPad (рельс, стол
            // на два поля, колонки) она включает по этому флагу.
            AppShell()
                .environment(\.usesPadLayout, UIDevice.current.userInterfaceIdiom == .pad)
                .environment(\.mirrorsBottomTiles, appState.ownBoardOnRight)
                .phoneStyle(UIDevice.current.userInterfaceIdiom == .pad)
                .environment(appState)
                .environment(premiumManager)
                .environment(pointsShop)
                .environment(\.locale, Locale(identifier: appState.language))
                .task {
                    premiumManager.start()
                    pointsShop.start()
                    CloudSyncManager.shared.start()
                }
        }
    }
}
