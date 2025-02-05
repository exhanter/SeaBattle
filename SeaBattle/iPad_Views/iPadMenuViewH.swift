//
//  iPadMenuViewH.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 07/01/2025.
//

import SwiftUI

struct iPadMenuViewH: View {
    @EnvironmentObject var appState: AppState
    let width: CGFloat
    let height: CGFloat
    let relativeFontSize: CGFloat
    var tabsLockBeforeGameStart: Bool {
        if !appState.gameIsActive {
            return appState.selectedTab == .menu || appState.selectedTab == .about ? true : false
        }
        return false
    }
    var body: some View {
        ZStack {
            Image("wood")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)
                .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topLeft, .topRight]))
                .shadow(color: .white, radius: 5)
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
                        appState.selectedTab = .iPadBattleView
                    } label: {
                        if appState.selectedTab == .iPadBattleView {
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
                    .disabled(self.tabsLockBeforeGameStart)
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
    init(width: CGFloat, height: CGFloat) {
        self.width = width * 0.3
        self.height = height * 0.12
        self.relativeFontSize = width * 0.06
    }
}

#Preview {
    iPadMenuViewH(width: 300, height: 500)
        .environmentObject(AppState(tempInstance: true))
}

