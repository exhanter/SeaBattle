//
//  iPadAboutView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadAboutView: View {
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width < geometry.size.height {
                iPadAboutViewV()
            } else {
                iPadAboutViewH()
            }
        }
    }
}

#Preview {
    iPadAboutView()
}
