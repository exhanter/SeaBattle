//
//  CellView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 12/07/2024.
//

import SwiftUI

struct NoPressEffect: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct CellView: View {
    func defineReltiveSizes(constant: CGFloat) -> CGFloat {
        return cellWidth / 35 / constant
    }
    var fireStrokeIsOn: Bool
    let cellStatus: Cell.CurrentStatus
    let cellWidth: CGFloat
    
    @State private var fireStrokeState: Bool = false

    @ViewBuilder
    var baseCell: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .fill(Color(red: 0.8, green: 0.9, blue: 1.0)) // Светло-голубой цвет
            .frame(width: cellWidth, height: cellWidth)
    }
    
    @ViewBuilder
    var yellowCell: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .fill(LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.8, green: 0.9, blue: 1.0), Color(red: 0.2, green: 0.2, blue: 0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )) // Gradient from light to dark
            .frame(width: cellWidth, height: cellWidth)
    }
    
    @ViewBuilder
    var darkCell: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .fill(LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.2, green: 0.2, blue: 0.2), Color(red: 0.1, green: 0.1, blue: 0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )) // Dark grey gradient
            .frame(width: cellWidth, height: cellWidth)
    }
    
    @ViewBuilder
    // White frame with blur
    var whiteStroke: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .stroke(Color.white, lineWidth: cellWidth / 8.75)
            .blur(radius: cellWidth / 8.75)
            .mask(RoundedRectangle(cornerRadius: cellWidth / 5).fill(LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
    
    @ViewBuilder
    // Black frame with blur
    var blackStroke: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .stroke(Color.black, lineWidth: cellWidth / 4.375)
            .blur(radius: cellWidth / 8.75)
            .mask(RoundedRectangle(cornerRadius: cellWidth / 5).fill(LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .topLeading, endPoint: .bottomTrailing)))
    }
    
    @ViewBuilder
    // Crater for missed missle
    var crater: some View {
        Circle()
            .fill(LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.5), Color.white.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: cellWidth * 0.43, height: cellWidth * 0.43)
            .shadow(color: Color.black.opacity(0.3), radius: cellWidth / 8.75)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.7), lineWidth: cellWidth / 17.5)
                    .blur(radius: cellWidth / 17.5)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: cellWidth / 17.5)
                    .blur(radius: cellWidth / 17.5)
            )
    }
    
    @ViewBuilder
    // Fire frame
    var fireStroke: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .stroke(LinearGradient(gradient: Gradient(
                colors: [Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 1.0, green: 0.2, blue: 0.0)]),
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: cellWidth / 17.5)
            .blur(radius: cellWidth / 17.5)
    }
    
    @ViewBuilder
    var strongFireStroke: some View {
        RoundedRectangle(cornerRadius: cellWidth / 5)
            .stroke(LinearGradient(gradient: Gradient(
                colors: [Color(red: 1.0, green: 0.5, blue: 0.0), Color(red: 1.0, green: 0.2, blue: 0.0)]),
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: cellWidth / 11.67)
            .blur(radius: cellWidth / 17.5)
    }
    
    @ViewBuilder
    var cross: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: cellWidth * 0.29, y: cellWidth * 0.29))
                path.addLine(to: CGPoint(x: cellWidth * 0.71, y: cellWidth * 0.71))
                path.move(to: CGPoint(x: cellWidth * 0.71, y: cellWidth * 0.29))
                path.addLine(to: CGPoint(x: cellWidth * 0.29, y: cellWidth * 0.71))
            }
            .stroke(Color(red: 1.0, green: 0.2, blue: 0.0), lineWidth: cellWidth / 11.67)
            .blur(radius: cellWidth / 35)
            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.7), radius: cellWidth / 8.75)
            .shadow(color: Color.black.opacity(0.3), radius: cellWidth / 17.5, x: cellWidth / 17.5, y: cellWidth / 17.5)
            .shadow(color: Color.white.opacity(0.7), radius: cellWidth / 17.5, x: -cellWidth / 17.5, y: -cellWidth / 17.5)
        }
    }
    
    @ViewBuilder
    var crossThick: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: cellWidth * 0.14, y: cellWidth * 0.14))
                path.addLine(to: CGPoint(x: cellWidth * 0.57, y: cellWidth * 0.57))
                path.move(to: CGPoint(x: cellWidth * 0.57, y: cellWidth * 0.14))
                path.addLine(to: CGPoint(x: cellWidth * 0.14, y: cellWidth * 0.57))
            }
            .stroke(Color(red: 1.0, green: 0.4, blue: 0.0), lineWidth: cellWidth / 11.67)
            .blur(radius: cellWidth / 35)
            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.7), radius: cellWidth / 8.75)
            .shadow(color: Color.black.opacity(0.3), radius: cellWidth / 17.5, x: cellWidth / 17.5, y: cellWidth / 17.5)
            .shadow(color: Color.white.opacity(0.7), radius: cellWidth / 17.5, x: -cellWidth / 17.5, y: -cellWidth / 17.5)
        }
    }
    
    @ViewBuilder
    var crossThin: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: cellWidth * 0.14, y: cellWidth * 0.14))
                path.addLine(to: CGPoint(x: cellWidth * 0.57, y: cellWidth * 0.57))
                path.move(to: CGPoint(x: cellWidth * 0.57, y: cellWidth * 0.14))
                path.addLine(to: CGPoint(x: cellWidth * 0.14, y: cellWidth * 0.57))
            }
            .stroke(Color(red: 1.0, green: 0.4, blue: 0.0), lineWidth: cellWidth / 17.5)
            .blur(radius: cellWidth / 35)
            .shadow(color: Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.7), radius: cellWidth / 8.75)
            .shadow(color: Color.black.opacity(0.3), radius: cellWidth / 17.5, x: cellWidth / 17.5, y: cellWidth / 17.5)
            .shadow(color: Color.white.opacity(0.7), radius: cellWidth / 17.5, x: -cellWidth / 17.5, y: -cellWidth / 17.5)
        }
    }
    
    @ViewBuilder
    var innerYellowSquare: some View {
        RoundedRectangle(cornerRadius: cellWidth / 7)
            .fill(LinearGradient(gradient: Gradient(colors: [
                Color(red: 248/255, green: 1, blue: 0),
                Color(red: 90/255, green: 74/255, blue: 66/255).opacity(0.8)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            .frame(width: cellWidth * 0.71, height: cellWidth * 0.71)
    }
    
    var innerBlackSquare: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cellWidth / 7)
                .fill(Color.black)
                .frame(width: cellWidth * 0.71, height: cellWidth * 0.71)
                .overlay(crossThin)
        }
    }
    
    @ViewBuilder
    var unknownView: some View {
        baseCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
    }
    
    @ViewBuilder
    var missedView: some View {
        baseCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(crater)
    }
    @ViewBuilder
    var missedHaloView: some View {
        baseCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(crater)
            .overlay(fireStroke)
    }
    @ViewBuilder
    var onFireView: some View {
        baseCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(cross)
            .overlay(fireStroke)
    }
    
    @ViewBuilder
    var onFireHaloView: some View {
        baseCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(cross)
            .overlay(strongFireStroke)
    }
    @ViewBuilder
    var destroyedView: some View {
        darkCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(innerBlackSquare)
    }
    
    @ViewBuilder
    var destroyedHaloView: some View {
        darkCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(innerBlackSquare)
            .overlay(fireStroke)
    }
    
    @ViewBuilder
    var showShipView: some View {
        yellowCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(innerYellowSquare)
    }
    
    @ViewBuilder
    var showShipHaloView: some View {
        yellowCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(innerYellowSquare)
            .overlay(fireStroke)
    }
    
    @ViewBuilder
    var showShipOnFireView: some View {
        yellowCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(
                innerYellowSquare
                    .overlay(crossThick)
            )
    }
    
    @ViewBuilder
    var showShipOnFireHaloView: some View {
        yellowCell
            .overlay(whiteStroke)
            .overlay(blackStroke)
            .overlay(
                innerYellowSquare
                    .overlay(crossThick)
            )
            .overlay(fireStroke)
    }
    
    var body: some View {
        switch cellStatus {
        case .unknown:
            unknownView
        case .missed:
            if fireStrokeIsOn {
                missedHaloView
            } else {
                missedView
            }
        case .onFire:
            if fireStrokeIsOn {
                onFireHaloView
            } else {
                onFireView
            }
        case .destroyed:
            if fireStrokeIsOn {
                destroyedHaloView
            } else {
                destroyedView
            }
        case .showShip:
            if fireStrokeIsOn {
                showShipHaloView
            } else {
                showShipView
            }
        case .showShipOnFire:
            if fireStrokeIsOn {
                showShipOnFireHaloView
            } else {
                showShipOnFireView
            }
        case .showShipHalo:
            showShipHaloView
        }
    }
    
}

#Preview {
    CellView(fireStrokeIsOn: true, cellStatus: .unknown, cellWidth: 35)
}
