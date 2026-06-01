import SwiftUI

struct StimmungsTrackerView: View {
    @StateObject private var store = StimmungsStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var gewaehlte: Int = 3
    @State private var notiz: String = ""
    @State private var gespeichert = false

    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.13),
                         Color(red: 0.10, green: 0.06, blue: 0.18)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerSection
                    todaySelectorCard
                    if gespeichert || store.heutigerEintrag != nil { historySection }
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            VStack {
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
            }
        }
        .onAppear {
            if let e = store.heutigerEintrag {
                gewaehlte = e.stufe
                notiz = e.notiz
                gespeichert = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stimmungs-Tracker")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Wie fühlst du dich heute?")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
            }
        }
    }

    private var todaySelectorCard: some View {
        VStack(spacing: 20) {
            Text("Heute")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Emoji Auswahl
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { s in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            gewaehlte = s
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(stimmungsEmoji(s))
                                .font(.system(size: gewaehlte == s ? 46 : 34))
                                .scaleEffect(gewaehlte == s ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gewaehlte)
                            if gewaehlte == s {
                                Text(stimmungsLabel(s))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(stimmungsColor(s))
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            gewaehlte == s
                            ? stimmungsColor(s).opacity(0.15)
                            : Color.white.opacity(0.03),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay {
                            if gewaehlte == s {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(stimmungsColor(s).opacity(0.5), lineWidth: 1.5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 3)
                }
            }

            // Notiz
            VStack(alignment: .leading, spacing: 8) {
                Text("Notiz (optional)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Was bewegt dich gerade?", text: $notiz, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3...5)
                    .padding(12)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }

            Button {
                store.set(stufe: gewaehlte, notiz: notiz)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { gespeichert = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: gespeichert ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                    Text(gespeichert ? "Gespeichert" : "Stimmung speichern")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(gespeichert
                              ? AnyShapeStyle(Color(red: 0.2, green: 0.75, blue: 0.4))
                              : AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing)))
                )
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gespeichert)
        }
        .padding(18)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Letzte 7 Tage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            let days = store.last7Days()
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 6) {
                        if let s = pair.stufe {
                            Text(stimmungsEmoji(s))
                                .font(.system(size: 22))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stimmungsColor(s))
                                .frame(height: CGFloat(s) * 10 + 10)
                        } else {
                            Text("·")
                                .font(.system(size: 18))
                                .foregroundStyle(.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 10)
                        }
                        Text(dayLabel(pair.date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE"
        return String(f.string(from: date).prefix(2))
    }
}
