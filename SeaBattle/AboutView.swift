//
//  AboutView.swift
//  SeaBattle
//
//  Created by Ivan Tkachev on 06/02/2024.
//

import SwiftUI

struct AboutView: View {
    

    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.11, green: 0.77, blue: 0.56).opacity(0.60), Color(red: 0.04, green: 0.10, blue: 0.25).opacity(0.80)]), startPoint: .bottom, endPoint: .top)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading) {
                    
                    Text("This game was made by Ivan Tkachev with educational purposes.")
                        .italic()
                        .padding(.top, 50)
                    Text("If you have any questions, you can contact me:")
                        .italic()
                    Text("Email: 2ivan.tkachev@gmail.com")
                        .italic()
                    Text("LinkedIn: [https://www.linkedin.com/in/ivan-tkachev](https://www.linkedin.com/in/ivan-tkachev)")
                        .italic()
                    Text("Used pictures:")
                        .padding(.top)
                    Text("AI generated pictures and")
                    Text("[engin akyurt](https://unsplash.com/@enginakyurt?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash) on [Unsplash](https://unsplash.com/photos/a-wood-surface-with-a-hole-in-it-_5aw4QuKAwA?utm_content=creditCopyText&utm_medium=referral&utm_source=unsplash)")
                    Text("Music - AI generated music.")
                        .padding(.top)
                    Text("Sounds effects:")
                        .padding(.top)
                    Text("https://freesound.org/s/120956/ -- License: Attribution 4.0")
                    Text("https://freesound.org/s/117095/ -- License: Attribution 4.0")
                    Text("https://freesound.org/s/751086/ -- License: Attribution 4.0")
                    Text("https://freesound.org/s/531132/ -- License: Attribution 4.0")
                    Text("https://freesound.org/s/394466/ -- License: Creative Commons 0")
                    Text("https://freesound.org/s/388758/ -- License: Creative Commons 0")
                    Spacer()
                }
            }
            .italic()
            .padding(20)
        }
        .statusBar(hidden: true)
    }
}

#Preview {
    AboutView()
}
