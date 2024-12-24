//
//  iPadMenuView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 20/12/2024.
//

import SwiftUI

struct iPadMenuView: View {
    @ObservedObject var appState: AppState
    let relativeFontSize: CGFloat
    let width: CGFloat
    let height: CGFloat
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
                    .clipShape(CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight]))
//                    .overlay(
//                        CustomRoundedRectangle(cornerRadius: 25, roundedCorners: [.topRight, .bottomRight])
//                            .stroke(Color.white, lineWidth: 4)
//                    )
                    .shadow(radius: 10)
                VStack {
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
                        } else {
                            Text("Menu")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                    Button {
                        if appState.soundOn {
                            AppState.playSound(sound: "click_sound.wav")
                        }
                        appState.selectedTab = .playerView
                    } label: {
                        if appState.selectedTab == .playerView {
                            Text("Player")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                                .underline()
                        } else {
                            Text("Battle")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .disabled(self.tabsLockBeforeGameStart)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
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
                        } else {
                            Text("About")
                                .font(.custom("Dorsa", size: relativeFontSize))
                                .foregroundColor(Color(red: 248/255, green: 1, blue: 0))
                            
                        }
                    }
                    .disabled(appState.tabsBlocked)
                    .opacity(appState.tabsBlocked ? 0.5 : 1)
                    //.padding(.horizontal)
                    Spacer()
                }
                .frame(width: width, height: height)
            }
    }
}

#Preview {
    iPadMenuView(appState: AppState(), relativeFontSize: 35, width: 50, height: 300)
}

