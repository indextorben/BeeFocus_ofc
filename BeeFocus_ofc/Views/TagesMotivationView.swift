import SwiftUI

struct TagesMotivationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var appeared = false
    @State private var nextQuote = false

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 1.0, green: 0.5, blue: 0.8) : appThemaFarben(aktivesThema).0
    }

    private static let quotes: [(text: String, author: String)] = [
        ("Der einzige Weg, großartige Arbeit zu leisten, ist zu lieben, was du tust.", "Steve Jobs"),
        ("Du musst die Veränderung sein, die du in der Welt sehen willst.", "Mahatma Gandhi"),
        ("Erfolg ist die Summe kleiner Anstrengungen, die sich Tag für Tag wiederholen.", "Robert Collier"),
        ("Glaube an dich selbst und alles, was du bist. Wisse, dass es etwas in dir gibt, das größer ist als jedes Hindernis.", "Christian D. Larson"),
        ("Der beste Zeitpunkt, einen Baum zu pflanzen, war vor 20 Jahren. Der zweitbeste Zeitpunkt ist jetzt.", "Chinesisches Sprichwort"),
        ("Deine Einstellung bestimmt deine Richtung.", "Unbekannt"),
        ("Perfektion ist nicht erreichbar. Aber wenn wir nach Perfektion streben, können wir Exzellenz erreichen.", "Vince Lombardi"),
        ("Jeder Experte war einmal ein Anfänger.", "Helen Hayes"),
        ("Das Geheimnis des Fortschritts ist, mit dem Anfangen anzufangen.", "Mark Twain"),
        ("Du bist fähiger, als du glaubst, stärker, als du denkst, und klüger, als du dir vorstellst.", "Unbekannt"),
        ("Träume groß, fange klein an, handle jetzt.", "Robin Sharma"),
        ("Diszip­lin ist die Brücke zwischen Zielen und Leistung.", "Jim Rohn"),
        ("Der einzige Unterschied zwischen einem guten Tag und einem schlechten Tag ist deine Einstellung.", "Dennis S. Brown"),
        ("Erfolg hat drei Buchstaben: T-U-N.", "Johann Wolfgang von Goethe"),
        ("Nicht weil es schwer ist, wagen wir es nicht. Es ist schwer, weil wir es nicht wagen.", "Seneca"),
        ("Was hinter uns liegt und was vor uns liegt, sind winzige Dinge im Vergleich zu dem, was in uns liegt.", "Ralph Waldo Emerson"),
        ("Wenn du denkst, du kannst, hast du recht. Wenn du denkst, du kannst es nicht, hast du auch recht.", "Henry Ford"),
        ("Das Leben ist 10 % das, was dir passiert, und 90 % wie du darauf reagierst.", "Charles R. Swindoll"),
        ("Eine kleine positive Tat ist besser als tausend positive Gedanken.", "Unbekannt"),
        ("Jeder Tag ist eine neue Chance, das zu werden, was du sein willst.", "Unbekannt"),
        ("Der Unterschied zwischen dem Gewöhnlichen und dem Außergewöhnlichen ist das kleine Extra.", "Jimmy Johnson"),
        ("Fang dort an, wo du bist. Nutze, was du hast. Tu, was du kannst.", "Arthur Ashe"),
        ("Halte deine Ziele groß und deine Schritte klein.", "Unbekannt"),
        ("Energie und Beharrlichkeit besiegen alles.", "Benjamin Franklin"),
        ("Wer aufhört, besser zu werden, hat aufgehört, gut zu sein.", "Philip Rosenthal"),
        ("Der einzige Weg, nicht zu scheitern, ist, es erst gar nicht zu versuchen. Das ist keine Option.", "Elon Musk"),
        ("Sorge nicht um deine Schwächen, sondern entwickle deine Stärken.", "Unbekannt"),
        ("Das Ziel liegt nicht immer darin, es zu erreichen, sondern dahin zu streben.", "Audrey Hepburn"),
        ("Aufgeben ist keine Option.", "Michael Schumacher"),
        ("Steh auf, wenn du fällst. Mach weiter, wenn du müde bist.", "Unbekannt"),
        ("Mit Geduld und Ausdauer erzielt man mehr als mit Hast und Stärke.", "Jean de La Fontaine"),
        ("Tue jeden Tag etwas, das dich deinem Traum ein Stück näher bringt.", "Unbekannt"),
        ("Wer kämpft, kann verlieren. Wer nicht kämpft, hat schon verloren.", "Bertolt Brecht"),
        ("Mach es mit Leidenschaft oder gar nicht.", "Unbekannt"),
        ("Heute ist der Tag, an dem du anfängst.", "Unbekannt"),
        ("Der Weg zur Perfektion führt durch Konsequenz.", "Unbekannt"),
        ("Kleine tägliche Verbesserungen führen zu großen Ergebnissen.", "Robin Sharma"),
        ("Glaube an den Prozess. Vertraue auf die Arbeit.", "Unbekannt"),
        ("Disziplin bedeutet, das zu tun, was getan werden muss, auch wenn du keine Lust hast.", "Unbekannt"),
        ("Du hast nur diese eine Chance. Nutze sie.", "Unbekannt"),
        ("Ruhm gehört denen, die niemals aufgeben.", "Winston Churchill"),
        ("Größe entsteht durch konsequentes Handeln, nicht durch Worte.", "Unbekannt"),
        ("Heute getroffene Entscheidungen formen dein Morgen.", "Unbekannt"),
        ("Die Motivation bringt dich zum Start. Die Gewohnheit hält dich im Laufen.", "Jim Ryun"),
        ("Wer ein klares Warum hat, erträgt fast jedes Wie.", "Friedrich Nietzsche"),
        ("Sei die beste Version deiner selbst.", "Unbekannt"),
        ("Jeder Morgen ist ein neuer Anfang.", "Unbekannt"),
        ("Stärke entsteht nicht durch das, was du schaffst, sondern durch das, was du überwindest.", "Rikki Rogers"),
        ("Du bist näher am Ziel als gestern.", "Unbekannt"),
        ("Mach heute das, was andere nicht tun, und lebe morgen, wie andere es nicht können.", "Jerry Rice"),
        ("Fortschritt, nicht Perfektion.", "Unbekannt"),
        ("Tue Gutes und vergiss es nicht.", "Unbekannt"),
        ("Es ist nie zu spät, das zu werden, was man hätte sein können.", "George Eliot"),
        ("Der Mut, anzufangen, ist alles.", "Unbekannt"),
        ("Zusammen kommen ist ein Beginn. Zusammen bleiben ist Fortschritt. Zusammen arbeiten ist Erfolg.", "Henry Ford"),
        ("Die Zukunft gehört denen, die an die Schönheit ihrer Träume glauben.", "Eleanor Roosevelt"),
        ("Gestalte dein Leben oder jemand anderes tut es für dich.", "John Lennon"),
        ("Halte die Augen auf das Ziel gerichtet, nicht auf die Hindernisse.", "Unbekannt"),
        ("Wo ein Wille ist, ist auch ein Weg.", "Deutsches Sprichwort"),
        ("Fehler sind Beweise dafür, dass du es versuchst.", "Unbekannt"),
        ("Höre auf, dir vorzustellen, was passieren könnte, und beginne, dein Leben zu gestalten.", "Unbekannt"),
        ("Ein Schritt nach dem anderen bringt dich ans Ziel.", "Unbekannt"),
        ("Du bist stärker als du denkst.", "Unbekannt"),
    ]

    private var todayQuote: (text: String, author: String) {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return Self.quotes[(day - 1) % Self.quotes.count]
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16).padding(.trailing, 20)
                }

                Spacer()

                VStack(spacing: 32) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Image(systemName: "quote.bubble.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(accent)
                    }
                    .scaleEffect(appeared ? 1.0 : 0.6)
                    .opacity(appeared ? 1.0 : 0)

                    // Quote card
                    VStack(spacing: 20) {
                        Text("Heutiges Zitat")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .tracking(1.5)
                            .textCase(.uppercase)

                        VStack(spacing: 16) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 28))
                                .foregroundStyle(accent.opacity(0.5))

                            Text(todayQuote.text)
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .padding(.horizontal, 8)

                            Text("— \(todayQuote.author)")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                                .italic()
                        }
                        .padding(28)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.2), lineWidth: 1.5))
                    }
                    .opacity(appeared ? 1.0 : 0)
                    .offset(y: appeared ? 0 : 30)

                    // Date chip
                    Text(Date().formatted(date: .complete, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(appeared ? 1.0 : 0)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Share button
                Button {
                    let shareText = "\"\(todayQuote.text)\"\n— \(todayQuote.author)"
                    let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let vc = scene.windows.first?.rootViewController {
                        vc.present(av, animated: true)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Zitat teilen")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(accent.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.4), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1.0 : 0)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}
