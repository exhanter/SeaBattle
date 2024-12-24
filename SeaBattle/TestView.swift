//
//  TestView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 22/12/2024.
//

import SwiftUI

//struct CustomRoundedRectangle: Shape {
//    var cornerRadius: CGFloat
//    var roundedCorners: UIRectCorner
//    func path(in rect: CGRect) -> Path {
//        let path = UIBezierPath( roundedRect: rect, byRoundingCorners: roundedCorners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
//        return Path(path.cgPath)
//    }
//}




struct TestView: View {
        var body: some View {
            Image("wood")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 200, height: 600)
                .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight]))
                .overlay(
                    CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight])
                        .stroke(Color.white, lineWidth: 4)
                )
                .shadow(radius: 10)
        }
    }

#Preview {
    TestView()
}
