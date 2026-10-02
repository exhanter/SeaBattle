# Глоссарий перевода (RU / NL)

Собран в R4.5a, когда весь каталог `Localizable.xcstrings` переводился на русский и
нидерландский. **Новые строки переводить по нему же**: два блока ниже — это ровно то,
что получали агенты-переводчики (скилл `translation-coordinator` → `translation`),
только на английском, как они его и читали. Отдавать блок агенту файлом и писать в
задании: «read it first, it takes precedence over the style guide».

Как шёл перевод и что за грабли — в `docs/STATUS.md`, раздел «R4.5a — как вышло».

---

## RU

Project guidance (takes precedence over the style guide; still read the style guide as the baseline for anything not covered here):
- App: "Sea Battle", a Battleship game for iPhone and iPad. App name in Russian: «Морской бой».
- The UI was originally designed in Russian. The mockups file /Users/ivantkachev/Developer/SeaBattle/docs/design/mockups.html contains the canonical Russian copy for most screens. For each string, grep that file for the matching Russian wording (e.g. `grep -o "Выйти из партии[^<]*" mockups.html`) and prefer it when it exists. Ignore Russian there that is designer notes (pixel sizes, token names, «тур N»).
- Address the player with «вы» (lowercase), imperative in the plural/formal form: «Передавайте телефон по очереди», «Ваш ход».
- Glossary: Single player = Одиночная игра; Two players on one device = Вдвоём на устройстве; Nearby, no internet = Рядом без сети; Online = По сети; Paper game = Игра на бумаге; Menu = Меню; Settings = Настройки; Statistics = Статистика; match = партия (not «матч»); Continue game = Продолжить партию; Your fleet = Ваш флот; My board = Моё поле; Opponent's board / Enemy field = Поле противника; Your turn = Ваш ход; Shuffle = Перемешать; Play = Играть; Start = Старт; Change = Изменить; Done = Готово; Leave the match? = Выйти из партии?; Leave = Выйти; Stay = Остаться; Surrender and leave = Сдаться и выйти; Miss / Hit / Sunk = мимо / ранен / убит (capitalise only if the English does); levels Easy / Medium / Hard / Expert = Легко / Средне / Сложно / Эксперт; Computer level = Уровень компьютера; opponent (a person) = соперник; the computer = компьютер; points = баллы; hint = подсказка; wallet = кошелёк; A one-cell gap is needed = Нужен зазор в одну клетку; Pro, Game Center, App Store, Apple ID, iPhone, iPad, iOS stay in Latin script.
- Numbers with nouns MUST get plural variations (one/few/many/other) — e.g. «1 балл, 2 балла, 5 баллов». If StringCatalogContext returns sourcePluralCasesToAdd, first add the English source plural variations (en: one/other, e.g. "%lld win" / "%lld wins"), then the Russian ones. For the key "%@%lld points" the first argument is just a sign ("+", "−" or empty) glued to the number: vary only argument 2.
- A label that sits under or next to a number it does not contain (stats and results captions: "shots", "hints", "turns", "games", "wins") goes in the nominative plural — «выстрелы», «подсказки», «ходы», «партии», «победы»: it reads as a heading with any number, unlike «1 подсказок».
- Keep it compact: most strings sit in buttons, segmented controls, list rows and capsules on a 375-pt-wide iPhone screen. Prefer the shorter natural wording; never longer than needed.
- Use «ёлочки» for quotes, typographic dashes (—) and the ellipsis character (…) as in the source. Keep format specifiers exactly.
- Terms already chosen (keep consistent): Monthly plan = Подписка на месяц, Yearly plan = Подписка на год; Cancel = Отмена; Undo = Отменить; Coin toss = Жребий; Enemy = Противник; Hit = Ранен; Miss = Мимо; shop = витрина; Icon = Значок; Colour = Цвет; Copy = Скопировать; Create a code = Придумайте код; Repeat the code = Повторите код; Enter a code = Ввести код; a code lives N minutes = код действует N минут; Leave the match = Выйти из партии; Latest entries = Последние начисления; More = Ещё; Nearby = Рядом; About the app = О приложении; AI = ИИ.
- Opponent on the score bar / board = Противник, a person elsewhere = соперник (Соперник вышел, Ход соперника); Rematch = Реванш; Play again = Сыграть ещё; Ready = Готов; Points = Баллы; Random opponent = Случайный соперник; Pass the phone = Передайте телефон; Played before = Играли раньше; Player = Игрок; paid until = оплачено до.

---

## NL

Project guidance (takes precedence over the style guide; still read the style guide as the baseline for anything not covered here):
- App: "Sea Battle", a Battleship game for iPhone and iPad. App name in Dutch: "Zeeslag".
- Informal address: "je/jij/jouw" (e.g. "Jouw beurt").
- Buttons use the infinitive (Annuleren, Sluiten, Kopiëren, Verwijderen, Herstellen, Spelen, Wijzigen) — the usual form in Dutch apps; confirmed by the owner 02.10.
- Glossary: Single player = Eén speler; Two players on one device = Met z'n tweeën op één apparaat (shorten where needed, e.g. "Met z'n tweeën"); Nearby, no internet = Dichtbij, zonder internet; Online = Online; Paper game = Spel op papier; Menu = Menu; Settings = Instellingen; Statistics = Statistieken; match = potje (e.g. "Potje hervatten"), game in general = spel; Your fleet = Jouw vloot; My board = Mijn veld; Opponent's board / Enemy field = Veld van de tegenstander; Your turn = Jouw beurt; Shuffle (= place the ships at random again) = Willekeurig (NOT "Schudden"); Play = Spelen; Start = Start; Change = Wijzigen; Done = Klaar; Leave the match? = Potje verlaten?; Leave = Verlaten; Stay = Blijven; Surrender and leave = Opgeven en verlaten; Miss / Hit / Sunk = mis / raak / gezonken; levels Easy / Medium / Hard / Expert = Makkelijk / Gemiddeld / Moeilijk / Expert; opponent = tegenstander (never "Vijand"); the computer = de computer; points = punten; hint = hint; wallet = portemonnee; Pro, Game Center, App Store, Apple ID, iPhone, iPad, iOS stay as is.
- Numbers with nouns MUST get plural variations (one/other), e.g. "1 punt" / "%lld punten". If StringCatalogContext returns sourcePluralCasesToAdd, add the English one/other variations first. For the key "%@%lld points" the first argument is just a sign ("+", "−" or empty) glued to the number: vary only argument 2.
- Keep it compact: most strings sit in buttons, segmented controls, list rows and capsules on a 375-pt-wide iPhone screen. Prefer the shorter natural wording.
- Use typographic quotes (“…” / ‘…’), dashes (—) and the ellipsis character (…) as in the source. Keep format specifiers exactly.
- Terms already chosen (keep consistent): cell on the board = vak / vakken (not "cel", not "vakje"); wins / losses counters = gewonnen / verloren; Coin toss = Kop of munt; Continue (resume a game) = Hervatten; Cancel = Annuleren; Choose a plan = Kies een abonnement; Enter a code = Code invoeren; Create a code = Bedenk een code; Copy = Kopiëren; wallet history entries = boekingen; balance = saldo; Arrangement / layout = Opstelling; level = niveau; mode = modus (plural modi); series = reeks; Icon = Pictogram; Leave the match = Potje verlaten; Match code = Code van het potje; Monthly plan = Maandabonnement, Yearly plan = Jaarabonnement; a code "lives" N minutes = is N minuten geldig; Not signed in = Niet ingelogd; Locked = Vergrendeld; Unlocked = Ontgrendeld; shop = winkel; Result = Uitslag; Reset = Wissen; Vibration = Trillen.
