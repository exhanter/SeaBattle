//
//  iPadMenuViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMenuViewH: View {
    @ObservedObject var appState: AppState
    let width: CGFloat
    let height: CGFloat
    let relativeFontSize: CGFloat
    var body: some View {
        ZStack {
            Image("wood")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topLeft, .topRight]))
                .shadow(color: .white, radius: height * 0.06)
            HStack(alignment: .bottom) {
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .menu
                    } label: {
                        if appState.selectedTab == .menu {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        } else {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .iPadBattleFieldView
                    } label: {
                        if appState.selectedTab == .iPadBattleFieldView {
                            Text("Battle")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        } else {
                            Text("Battle")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .about
                    } label: {
                        if appState.selectedTab == .about {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        } else {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .fixedSize(horizontal: true, vertical: true)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    Spacer()
                }
            .padding(.bottom, height * 0.11)
                .frame(width: width, height: height)
            }
    }
    init(appState: AppState, width: CGFloat, height: CGFloat) {
        self.width = width * 0.3
        self.height = height * 0.12
        self.relativeFontSize = width * 0.06
        self.appState = appState
    }
}

#Preview {
    iPadMenuViewH(appState: AppState(), width: 300, height: 500)
}

