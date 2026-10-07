//
//  AboutScreen.swift
//  Sea Battle — «О приложении» (R4.6)
//
//  Страница таба «Настройки», как «Ваше имя» и «Pro активен»: своего кадра у
//  неё нет, поэтому она собрана из того, что уже есть, — `ScreenTitle`,
//  `ListGroup`, `ListRow`, карточка G2. Содержимое перенесено со старого
//  `AboutView` (удалён в R4.6): правила, связь, авторы.
//
//  Авторы — не украшение: звуки с freesound под лицензией Attribution 4.0
//  требуют упоминания, поэтому строки со ссылками и лицензией обязательны.
//  Фото деревянной доски с Unsplash из списка ушло вместе с самой картинкой:
//  в приложении её больше нет.
//

import SwiftUI

enum AboutMetrics {
    static let cardRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14
    static let paragraphGap: CGFloat = 10
    static let headerText: CGFloat = 13
}

/// Что показывает страница — без SwiftUI, чтобы ссылки и лицензии проверялись
/// тестом.
enum AboutContent {

    struct Sound: Identifiable, Sendable {
        let id: Int
        /// Лицензия так, как её пишет freesound.
        let license: License

        var url: URL { URL(string: "https://freesound.org/s/\(id)/")! }
    }

    enum License: Sendable {
        case attribution4
        case cc0

        /// Названия лицензий не переводятся.
        var name: String {
            switch self {
            case .attribution4: "CC BY 4.0"
            case .cc0: "CC0"
            }
        }
    }

    /// Звуки игры, в том порядке, как их перечислял старый экран.
    static let sounds: [Sound] = [
        Sound(id: 120956, license: .attribution4),
        Sound(id: 117095, license: .attribution4),
        Sound(id: 751086, license: .attribution4),
        Sound(id: 531132, license: .attribution4),
        Sound(id: 394466, license: .cc0),
        Sound(id: 388758, license: .cc0),
    ]

    static let email = "request@brapps.nl"
    static let emailURL = URL(string: "mailto:\(email)")!
    static let website = "brapps.nl"
    static let websiteURL = URL(string: "https://www.brapps.nl")!

    /// «1.4 (27)» — версия и сборка из `Info.plist`.
    static func version(in bundle: Bundle = .main) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        guard let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              build != short else { return short }
        return "\(short) (\(build))"
    }
}

struct AboutScreen: View {
    var onBack: () -> Void = {}

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            ScreenTitle(title: "About the app", back: "Settings", onBack: onBack)
                .padding(.top, NavMetrics.titleTopBelowSafeArea)

            ScrollView {
                VStack(spacing: SettingsMetrics.groupGap) {
                    header

                    ListGroup("Rules") {
                        rules
                    }

                    ListGroup("Contact") {
                        link("Email", value: AboutContent.email, to: AboutContent.emailURL)
                            .accessibilityIdentifier("aboutEmail")
                        link("Website", value: AboutContent.website, to: AboutContent.websiteURL)
                    }

                    ListGroup("Credits") {
                        ListRow(title: "Pictures", value: Text("AI-generated"))
                        ListRow(title: "Music", value: Text("AI-generated"))
                        ForEach(Array(AboutContent.sounds.enumerated()), id: \.element.id) { index, sound in
                            // Источник и лицензия — значением строки, а не
                            // подписью: номер звука в ключе каталога писался бы
                            // по правилам языка («120 956»).
                            ListRow(title: "Sound effect \(index + 1)",
                                    value: Text(verbatim: "freesound · \(sound.license.name)")) {
                                openURL(sound.url)
                            }
                        }
                    }
                }
                .padding(.horizontal, Geometry.Nav.stackInset)
                .padding(.top, Geometry.Nav.titleGap * 2)
                .padding(.bottom, 12)
            }
            .seaScroll()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Sea Battle")
                .font(TypeScale.title)
                .foregroundStyle(Color.inkPrimary)
            Text("Version \(AboutContent.version())")
                .font(.scalable(size: AboutMetrics.headerText))
                .foregroundStyle(Color.inkSecondary)
            Text("Made by Brabant Mobile Apps for iPhone and iPad")
                .font(.scalable(size: AboutMetrics.headerText))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AboutMetrics.cardPadding)
        .glassPanel(.g2, radius: AboutMetrics.cardRadius)
        .accessibilityElement(children: .combine)
    }

    /// Правила одной карточкой, абзацами: читают их подряд, а не выбирают
    /// строку, поэтому разделителей группы между ними нет.
    private var rules: some View {
        VStack(alignment: .leading, spacing: AboutMetrics.paragraphGap) {
            Text("Sink the whole enemy fleet before yours is sunk.")
            Text("Each player has a 10 × 10 field and a fleet of ten ships: one of four cells, two of three, three of two and four of one.")
            Text("Ships stand horizontally or vertically and never touch, not even at the corners.")
            Text("Players take turns firing at a cell on the opponent's field. A miss passes the turn; a hit lets you fire again.")
            Text("The first to sink all of the opponent's ships wins.")
        }
        .font(TypeScale.callout)
        .foregroundStyle(Color.inkPrimary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AboutMetrics.cardPadding)
    }

    private func link(_ title: LocalizedStringKey, value: String, to url: URL) -> some View {
        ListRow(title: title, value: Text(verbatim: value)) { openURL(url) }
    }
}

#Preview("О приложении") {
    ZStack {
        SeaBackground().ignoresSafeArea()
        AboutScreen()
    }
    .environment(AppState())
}
