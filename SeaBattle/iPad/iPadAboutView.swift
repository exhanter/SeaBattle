//
//  iPadAboutView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadAboutView: View {
    
    var appState: AppState
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadAboutViewV(appState: appState)
            } else {
                iPadAboutViewH(appState: appState)
            }
        }
    }
    
    init(appState: AppState) {
        self.appState = appState
    }
}

#Preview {
    iPadAboutView(appState: AppState())
}
