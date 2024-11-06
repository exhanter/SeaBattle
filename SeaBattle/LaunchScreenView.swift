//
//  LaunchScreenView.swift
//  SeaBattle
//
//  Created by Иван Ткачев on 06/11/2024.
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
            .ignoresSafeArea()
            .onAppear {
                print("Launch screen")
            }
    }
}

#Preview {
    LaunchScreenView()
}
