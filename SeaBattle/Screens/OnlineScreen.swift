//
//  OnlineScreen.swift
//  Sea Battle — «По сети»: вход до партии (R3.3b)
//
//  Спека 4.8, кадры `screen5NetSearch` (радар), `screen5NetInvite` (код),
//  `screen13NoNet` (нет соединения). Один экран на всё, что показывает
//  `OnlineLobby` до партии; сама партия — `NetScreen`.
//
//  Решения R3.3b (кадров нет):
//  - **Экран выбора** — три `ModeRow`: «Случайный соперник», «Пригласить по
//    коду», «Ввести код». Так же выглядит меню, откуда игрок пришёл.
//  - **Ввод кода** — та же карточка, что у кода приглашения, с полем вместо
//    цифр: игрок видит, что набирает то, что ему показали.
//  - **Нет входа в Game Center** — как «Нет соединения», другие значок и текст:
//    выход из тупика тот же — два режима без сети.
//  - **Низ «Нет соединения»** — главная «Повторить» и `NavRow`, а не кнопка
//    «В меню» из кадра: `NavRow` последним стоит на всех экранах партии (3.1).
//

import SwiftUI
import GameKit
import UIKit

// MARK: - Числа

/// Кадры `screen5NetSearch`, `screen5NetInvite`, `screen13NoNet`.
enum OnlineMetrics {
    /// Радар: кольца 280 · 212 · 144 · 76, центр 62.
    static let radar: CGFloat = 280
    static let rings: [(scale: CGFloat, opacity: Double)] = [
        (1, 0.18), (212 / 280, 0.28), (144 / 280, 0.42), (76 / 280, 0.6),
    ]
    static let radarCore: CGFloat = 62
    static let radarIcon: CGFloat = 26
    static let radarGlow: CGFloat = 17          // CSS 0 0 34
    /// Один оборот луча.
    static let sweepPeriod: Double = 3
    static let searchTitle: CGFloat = 21
    static let searchClock: CGFloat = 15
    static let searchNote: CGFloat = 13
    /// Карточка кода.
    static let cardRadius: CGFloat = 24
    static let cardPaddingV: CGFloat = 20
    static let cardPaddingH: CGFloat = 18
    static let cardGap: CGFloat = 14
    static let overline: CGFloat = 11
    static let code: CGFloat = 40
    static let codeGlow: CGFloat = 13           // CSS 0 0 26
    static let cardNote: CGFloat = 12.5
    /// Строки под карточкой.
    static let rowRadius: CGFloat = 20
    static let rowTitle: CGFloat = 14.5
    static let rowDetail: CGFloat = 12
    static let rowIcon: CGFloat = 26
    static let dot: CGFloat = 7
    /// «Нет соединения».
    static let errorRadius: CGFloat = 22
    static let errorIconBox: CGFloat = 58
    static let errorIconRadius: CGFloat = 20
    static let errorTitle: CGFloat = 19
    static let errorText: CGFloat = 13.5
    static let errorGlow: CGFloat = 13          // CSS 0 0 26
    static let errorTextWidth: CGFloat = 280
    static let alternativesRadius: CGFloat = 18
    static let blockGap: CGFloat = 12
}

// MARK: - Экран

struct OnlineScreen: View {

    @Bindable var lobby: OnlineLobby
    /// Партия приглашающего уже создана — флот расставлен заранее.
    var hasArrangedAhead = false
    var onArrangeAhead: () -> Void = {}
    var onNearby: () -> Void = {}
    var onSinglePlayer: () -> Void = {}
    /// Уйти совсем — в меню.
    var onBack: () -> Void = {}

    @State private var gameCenter = GameCenterManager.shared

    var body: some View {
        VStack(spacing: 0) {
            title
                .padding(.top, NavMetrics.titleTopBelowSafeArea)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottom
        }
        .animation(Motion.quick, value: lobby.stage)
        .task { if lobby.stage == .checking { await lobby.enter() } }
        .sheet(isPresented: signInBinding) {
            if let controller = gameCenter.authViewController {
                GameCenterSheet(viewController: controller)
            }
        }
    }

    // MARK: Верх

    // Замыкания, а не ссылки на методы (`lobby.cancel`), и без вложенных
    // образцов вроде `.failed(.join(let code))`: сборка их принимает, а
    // обёртка превью — нет.

    @ViewBuilder
    private var title: some View {
        switch lobby.stage {
        case .searching:
            ScreenTitle(title: "Finding an opponent", back: "Online", onBack: { lobby.cancel() })
        case .hosting, .codeExpired:
            ScreenTitle(title: "Online game", back: "Online", onBack: { lobby.cancel() })
        case .entering, .joining:
            ScreenTitle(title: "Enter a code", back: "Online", onBack: { lobby.cancel() })
        case .failed(let search):
            ScreenTitle(title: search == .random ? "Finding an opponent" : "Enter a code",
                        back: "Online", onBack: { lobby.cancel() })
        case .checking, .signingIn, .noConnection, .signInFailed, .choosing:
            ScreenTitle(title: "Online", back: "Play", onBack: { leave() })
        }
    }

    // MARK: Середина

    @ViewBuilder
    private var content: some View {
        switch lobby.stage {
        case .checking, .signingIn:
            checking
        case .noConnection:
            OnlineErrorBlock(icon: "wifi.slash", title: "No connection",
                             message: "Online play needs the internet. Check the connection and try again.",
                             onNearby: onNearby, onSinglePlayer: onSinglePlayer)
        case .signInFailed:
            OnlineErrorBlock(icon: "person.crop.circle.badge.exclamationmark",
                             title: "Not signed in to Game Center",
                             message: "Online play goes through Game Center. Sign in under Settings → Game Center and try again.",
                             onNearby: onNearby, onSinglePlayer: onSinglePlayer)
        case .choosing:
            choices
        case .searching(let since):
            RadarBlock(title: "Looking for an opponent", since: since,
                       note: "It usually takes less than half a minute.")
        case .joining(let code, let since):
            RadarBlock(title: "Joining the match", since: since,
                       note: "Code \(code.display). The player who gave it must be on the code screen.")
        case .failed(let search):
            failedCard(search)
        case .hosting(let code, _):
            InviteBlock(code: code, expired: false, arrangedAhead: hasArrangedAhead,
                        onArrangeAhead: onArrangeAhead)
        case .codeExpired(let code):
            InviteBlock(code: code, expired: true, arrangedAhead: hasArrangedAhead,
                        onArrangeAhead: onArrangeAhead)
        case .entering:
            CodeEntryBlock(text: $lobby.typedCode, onSubmit: { lobby.join() })
        }
    }

    @ViewBuilder
    private func failedCard(_ search: OnlineSearch) -> some View {
        switch search {
        case .random:
            OnlineNoticeCard(icon: "person.fill.questionmark", title: "Nobody found",
                             message: "No one is looking for a match right now. Try again in a minute, or invite a friend with a code.")
        case .join(let code):
            OnlineNoticeCard(icon: "number", title: "No match with this code",
                             message: "Nobody is waiting with the code \(code.display). Check the digits: a code lives for 10 minutes.")
        }
    }

    private var checking: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.inkPrimary)
            Text(lobby.stage == .checking ? "Checking the connection…" : "Signing in to Game Center…")
                .font(.system(size: OnlineMetrics.searchNote))
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private var choices: some View {
        ScrollView {
            VStack(spacing: Geometry.Nav.stackGap) {
                ModeRow(icon: "dice", title: "Random opponent",
                        subtitle: "Game Center finds a player", action: { lobby.findRandom() })
                    .accessibilityIdentifier("onlineRandom")
                ModeRow(icon: "person.badge.plus", title: "Invite with a code",
                        subtitle: "Six digits for a friend", action: { lobby.host() })
                    .accessibilityIdentifier("onlineHost")
                ModeRow(icon: "number", title: "Enter a code",
                        subtitle: "A friend sent you one", action: { lobby.beginEntering() })
                    .accessibilityIdentifier("onlineJoin")
            }
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padding(.top, Geometry.Nav.titleGap * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: Низ

    private var bottom: some View {
        BottomStack(onMenu: { leave() }) {
            switch lobby.stage {
            case .noConnection, .signInFailed:
                Button { Task { await lobby.enter() } } label: { Text("Retry") }
                    .primaryButton()
            case .searching:
                Button { lobby.cancel() } label: { Text("Cancel search") }
                    .secondaryButton()
            case .joining:
                Button { lobby.beginEntering() } label: { Text("Cancel search") }
                    .secondaryButton()
            case .failed(let search):
                failedActions(search)
            case .hosting:
                Button { lobby.cancel() } label: { Text("Cancel the match") }
                    .secondaryButton()
            case .codeExpired:
                Button { lobby.renewCode() } label: { Text("New code") }
                    .primaryButton()
            case .entering:
                Button { lobby.join() } label: { Text("Join") }
                    .primaryButton(enabled: lobby.enteredCode != nil)
                    .accessibilityIdentifier("onlineJoinButton")
            case .checking, .signingIn, .choosing:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func failedActions(_ search: OnlineSearch) -> some View {
        switch search {
        case .random:
            Button { lobby.findRandom() } label: { Text("Search again") }
                .primaryButton()
        case .join(let code):
            Button { lobby.beginEntering() } label: { Text("Another code") }
                .secondaryButton()
            Button { lobby.join(code) } label: { Text("Try again") }
                .primaryButton()
        }
    }

    private func leave() {
        lobby.leave()
        onBack()
    }

    private var signInBinding: Binding<Bool> {
        Binding(get: { gameCenter.authViewController != nil },
                set: { if !$0 { gameCenter.sheetDismissed() } })
    }
}

// MARK: - Радар

/// `screen5NetSearch`: одна фигура на экране, время идёт вслух. Радар
/// ужимается по высоте — на 375 × 667 целиком он не помещается.
struct RadarBlock: View {
    let title: LocalizedStringKey
    let since: Date
    let note: LocalizedStringKey

    var body: some View {
        GeometryReader { proxy in
            let side = min(OnlineMetrics.radar, proxy.size.height - 120, proxy.size.width - 48)
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Radar(side: max(side, 120))
                TimelineView(.periodic(from: since, by: 1)) { context in
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: OnlineMetrics.searchTitle, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.inkPrimary)
                        Text(verbatim: netClock(.seconds(context.date.timeIntervalSince(since))))
                            .font(.system(size: OnlineMetrics.searchClock, design: .monospaced))
                            .foregroundStyle(Color.roleYou)
                        Text(note)
                            .font(.system(size: OnlineMetrics.searchNote))
                            .lineSpacing(OnlineMetrics.searchNote * 0.5)
                            .foregroundStyle(Color.inkSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// Кольца, латунный центр и луч. Луч — единственное, что движется; при
/// Reduce Motion он стоит.
struct Radar: View {
    var side: CGFloat = OnlineMetrics.radar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(OnlineMetrics.rings.indices, id: \.self) { index in
                let ring = OnlineMetrics.rings[index]
                Circle()
                    .strokeBorder(Color.roleYou, lineWidth: 1)
                    .frame(width: side * ring.scale, height: side * ring.scale)
                    .opacity(ring.opacity)
            }
            TimelineView(.animation(paused: reduceMotion)) { context in
                let turn = context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: OnlineMetrics.sweepPeriod) / OnlineMetrics.sweepPeriod
                Circle()
                    // Кадр — `conic-gradient(from 210deg, .32 → 0 at 38%)`, но он
                    // неподвижен. Луч идёт по часовой, поэтому яркая кромка —
                    // в конце градиента, а след гаснет позади неё.
                    .fill(AngularGradient(stops: [.init(color: Color.roleYou.opacity(0), location: 0),
                                                  .init(color: Color.roleYou.opacity(0), location: 0.62),
                                                  .init(color: Color.roleYou.opacity(0.32), location: 1)],
                                          center: .center))
                    // У SwiftUI ноль справа, у CSS сверху — отсюда −90.
                    .rotationEffect(.degrees(210 - 90 + (reduceMotion ? 0 : turn * 360)))
                    .frame(width: side, height: side)
            }
            Circle()
                .fill(RadialGradient(colors: [Color.roleYou.opacity(0.65), Color.roleYou.opacity(0.12)],
                                     center: UnitPoint(x: 0.5, y: 0.35),
                                     startRadius: 0, endRadius: OnlineMetrics.radarCore * 0.6))
                .overlay { Circle().strokeBorder(Color.roleYou, lineWidth: 1) }
                .frame(width: OnlineMetrics.radarCore, height: OnlineMetrics.radarCore)
                .shadow(color: .roleYouSoft, radius: OnlineMetrics.radarGlow)
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: symbolFontSize(inBox: OnlineMetrics.radarIcon)))
                .foregroundStyle(Color.inkPrimary)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}

// MARK: - Код приглашения

/// `screen5NetInvite`: код крупно и один на экране, рядом два способа его
/// передать. Ожидание не блокирует экран — флот можно расставить заранее.
struct InviteBlock: View {
    let code: InviteCode
    let expired: Bool
    let arrangedAhead: Bool
    var onArrangeAhead: () -> Void = {}

    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: OnlineMetrics.blockGap) {
                card
                if !expired { waiting }
                arrangeRow
            }
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padding(.top, Geometry.Nav.titleGap * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var card: some View {
        VStack(spacing: OnlineMetrics.cardGap) {
            OnlineOverline(text: "Match code")
            Text(verbatim: code.display)
                .font(.system(size: OnlineMetrics.code, weight: .medium, design: .monospaced))
                .tracking(OnlineMetrics.code * 0.08)
                .foregroundStyle(Color.inkPrimary)
                .shadow(color: .roleYouSoft, radius: OnlineMetrics.codeGlow)
                .opacity(expired ? 0.45 : 1)
                .accessibilityLabel(Text(verbatim: code.display))
                .accessibilityIdentifier("onlineCode")
            Text(expired ? "The code has expired. Get a new one — the fleet stays as it is."
                         : "Your opponent enters the code in the same mode. The code lives for 10 minutes.")
                .font(.system(size: OnlineMetrics.cardNote))
                .lineSpacing(OnlineMetrics.cardNote * 0.45)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !expired {
                HStack(spacing: 8) {
                    Button {
                        UIPasteboard.general.string = code.display
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .secondaryButton()
                    ShareLink(item: String(localized: "Let's play Sea Battle! Match code: \(code.display)")) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .secondaryButton()
                }
            }
        }
        .padding(.vertical, OnlineMetrics.cardPaddingV)
        .padding(.horizontal, OnlineMetrics.cardPaddingH)
        .frame(maxWidth: .infinity)
        .glassPanel(.g2, radius: OnlineMetrics.cardRadius)
        .onChange(of: code) { copied = false }
    }

    private var waiting: some View {
        HStack(spacing: 12) {
            InviteDots()
            VStack(alignment: .leading, spacing: 2) {
                Text("Waiting for your opponent")
                    .font(.system(size: OnlineMetrics.rowTitle, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(arrangedAhead ? "Your fleet is ready" : "Meanwhile you can place your fleet")
                    .font(.system(size: OnlineMetrics.rowDetail))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .glassPanel(.g2, radius: OnlineMetrics.rowRadius)
        .accessibilityElement(children: .combine)
    }

    private var arrangeRow: some View {
        Button {
            onArrangeAhead()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: symbolFontSize(inBox: OnlineMetrics.rowIcon)))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: OnlineMetrics.rowIcon, height: OnlineMetrics.rowIcon)
                Text(arrangedAhead ? "Back to your fleet" : "Place the fleet in advance")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(minHeight: Geometry.Hit.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassPanel(.g2, radius: OnlineMetrics.rowRadius)
        .accessibilityIdentifier("onlineArrangeAhead")
    }
}

/// Три точки ожидания 7 pt: 1 · 0,6 · 0,3, яркость бежит по кругу.
private struct InviteDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let step = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate / 0.4) % 3
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.roleYou)
                        .frame(width: OnlineMetrics.dot, height: OnlineMetrics.dot)
                        .opacity([1, 0.6, 0.3][(index - step + 3) % 3])
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step)
        }
        .accessibilityHidden(true)
    }
}

private struct OnlineOverline: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text)
            .font(.system(size: OnlineMetrics.overline, weight: .bold))
            .tracking(OnlineMetrics.overline * 0.12)
            .textCase(.uppercase)
            .foregroundStyle(Color.inkSecondary)
    }
}

// MARK: - Ввод кода

/// Карточка кода приглашения, но с полем: набирают то, что показали.
struct CodeEntryBlock: View {
    @Binding var text: String
    var onSubmit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: OnlineMetrics.cardGap) {
                OnlineOverline(text: "Match code")
                TextField(text: $text, prompt: Text(verbatim: "000 000").foregroundStyle(Color.inkTertiary)) {
                    Text("Match code")
                }
                .font(.system(size: OnlineMetrics.code, weight: .medium, design: .monospaced))
                .tracking(OnlineMetrics.code * 0.08)
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("onlineCodeField")
                Text("Your friend sees the code on their screen. It lives for 10 minutes.")
                    .font(.system(size: OnlineMetrics.cardNote))
                    .lineSpacing(OnlineMetrics.cardNote * 0.45)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, OnlineMetrics.cardPaddingV)
            .padding(.horizontal, OnlineMetrics.cardPaddingH)
            .frame(maxWidth: .infinity)
            .glassPanel(.g2, radius: OnlineMetrics.cardRadius)
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padding(.top, Geometry.Nav.titleGap * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear { focused = true }
        .onChange(of: text) { _, typed in
            let formatted = CodeEntryBlock.format(typed)
            if formatted != typed { text = formatted }
        }
    }

    /// Не больше шести цифр, пробел после третьей — как код показан у друга.
    static func format(_ typed: String) -> String {
        let digits = String(typed.filter { $0.isASCII && $0.isNumber }.prefix(6))
        guard digits.count > 3 else { return digits }
        return "\(digits.prefix(3)) \(digits.dropFirst(3))"
    }
}

// MARK: - Ошибки

/// `screen13NoNet`: карточка с холодной кромкой и два режима, которые
/// работают без сети, — игрок не остаётся в тупике.
struct OnlineErrorBlock: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var onNearby: () -> Void = {}
    var onSinglePlayer: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: OnlineMetrics.blockGap) {
                OnlineNoticeCard(icon: icon, title: title, message: message, framed: false)
                alternatives
            }
            .padding(.horizontal, Geometry.Nav.stackInset)
            .padding(.top, Geometry.Nav.titleGap * 2)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var alternatives: some View {
        VStack(spacing: 0) {
            row("Nearby, no internet", detail: "Two devices side by side, no internet needed",
                action: onNearby)
                .accessibilityIdentifier("onlineOfflineNearby")
            Rectangle()
                .fill(Color.glassStroke)
                .frame(height: 1)
                .padding(.horizontal, 14)
            row("Single player", detail: "Against the computer, four levels", action: onSinglePlayer)
                .accessibilityIdentifier("onlineOfflineSingle")
        }
        .glassPanel(.g2, radius: OnlineMetrics.alternativesRadius)
    }

    private func row(_ title: LocalizedStringKey, detail: LocalizedStringKey,
                     action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.inkPrimary)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .frame(minHeight: Geometry.Hit.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Значок в холодной рамке, заголовок, пояснение. Кромка `Role/Foe` со
/// свечением — у «Нет соединения»; у неудачного поиска без неё: беды тут
/// нет, просто никого не нашли.
struct OnlineNoticeCard: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    /// `false` — карточка стоит в прокрутке родителя, отступы его.
    var framed = true

    var body: some View {
        if framed {
            ScrollView {
                card(edge: false)
                    .padding(.horizontal, Geometry.Nav.stackInset)
                    .padding(.top, Geometry.Nav.titleGap * 2)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            card(edge: true)
        }
    }

    private func card(edge: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: OnlineMetrics.errorRadius, style: .continuous)
        return VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: symbolFontSize(inBox: OnlineMetrics.radarIcon)))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: OnlineMetrics.errorIconBox, height: OnlineMetrics.errorIconBox)
                .background {
                    RoundedRectangle(cornerRadius: OnlineMetrics.errorIconRadius, style: .continuous)
                        .fill(Color.roleFoe.opacity(0.18))
                        .overlay {
                            RoundedRectangle(cornerRadius: OnlineMetrics.errorIconRadius, style: .continuous)
                                .strokeBorder(Color.roleFoe, lineWidth: 1)
                        }
                }
            Text(title)
                .font(.system(size: OnlineMetrics.errorTitle, weight: .bold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: OnlineMetrics.errorText))
                .lineSpacing(OnlineMetrics.errorText * 0.5)
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: OnlineMetrics.errorTextWidth)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .glassPanel(.g2, radius: OnlineMetrics.errorRadius)
        .overlay {
            if edge { shape.strokeBorder(Color.roleFoe, lineWidth: 1) }
        }
        .shadow(color: edge ? .roleFoeSoft : .clear, radius: OnlineMetrics.errorGlow)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Вход в Game Center

/// Экран входа, который отдаёт сам Game Center.
private struct GameCenterSheet: UIViewControllerRepresentable {
    let viewController: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { viewController }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Превью

/// Сервис превью: сеть и вход — как задано, поиск не кончается.
@MainActor
final class PreviewOnlineService: OnlineService {
    var online = true
    var signedIn = true
    var playerID: String { "preview" }
    var playerName: String { "Превью" }

    init(online: Bool = true, signedIn: Bool = true) {
        self.online = online
        self.signedIn = signedIn
    }

    func isOnline() async -> Bool { online }
    func signIn() async -> Bool { signedIn }
    func findMatch(playerGroup: Int) async throws -> FoundMatch {
        try await Task.sleep(for: .seconds(3600))
        throw CancellationError()
    }
    func cancelSearch() {}
}

private struct OnlineDemo: View {
    @State private var lobby: OnlineLobby
    private let setup: (OnlineLobby) -> Void

    init(online: Bool = true, signedIn: Bool = true, setup: @escaping (OnlineLobby) -> Void = { _ in }) {
        _lobby = State(initialValue: OnlineLobby(service: PreviewOnlineService(online: online,
                                                                              signedIn: signedIn)))
        self.setup = setup
    }

    var body: some View {
        ZStack {
            SeaBackground()
                .ignoresSafeArea()
            OnlineScreen(lobby: lobby)
        }
        .task {
            await lobby.enter()
            setup(lobby)
        }
    }
}

#Preview("По сети · выбор") {
    OnlineDemo()
        .preferredColorScheme(.dark)
}

#Preview("По сети · поиск") {
    OnlineDemo { $0.findRandom() }
        .preferredColorScheme(.dark)
}

#Preview("По сети · код") {
    OnlineDemo { $0.host() }
        .preferredColorScheme(.dark)
}

#Preview("По сети · ввод кода") {
    OnlineDemo {
        $0.beginEntering()
        $0.typedCode = "472 91"
    }
    .preferredColorScheme(.dark)
}

#Preview("По сети · нет соединения") {
    OnlineDemo(online: false)
        .preferredColorScheme(.dark)
}

#Preview("По сети · нет Game Center · светлая") {
    OnlineDemo(signedIn: false)
        .preferredColorScheme(.light)
}

#Preview("По сети · поиск · 375", traits: .fixedLayout(width: 375, height: 667)) {
    OnlineDemo { $0.findRandom() }
        .preferredColorScheme(.dark)
}
