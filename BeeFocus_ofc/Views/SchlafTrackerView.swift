import SwiftUI

struct SchlafTrackerView: View {
    @StateObject private var store = SchlafStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var schlafenszeit: Date = defaultSchlafenszeit()
    @State private var aufwachzeit: Date  = defaultAufwachzeit()
    @State private var qualitaet: Int = 3
    @State private var showZielPicker = false

    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.3, green: 0.6, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var dauer: Double { max(0, aufwachzeit.timeIntervalSince(schlafenszeit) / 3600) }
    private var progress: Double { min(dauer / store.zielStunden, 1.0) }
    private var dauerText: String {
        let h = Int(dauer); let m = Int((dauer - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.14),
                         Color(red: 0.08, green: 0.06, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    ringCard
                    timePickers
                    qualitaetCard
                    saveButton
                    if !store.eintraege.isEmpty { historySection }
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
                schlafenszeit = e.schlafenszeit
                aufwachzeit   = e.aufwachzeit
                qualitaet     = e.qualitaet
            }
        }
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schlaf-Tracker")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text("Erholung ist Produktivität")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
    }

    private var ringCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 14)
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [accent, Color(red: 0.5, green: 0.3, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: dauer)

                VStack(spacing: 4) {
                    Text("🌙")
                        .font(.system(size: 28))
                    Text(dauer > 0 ? dauerText : "--")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("von \(formatH(store.zielStunden))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            HStack(spacing: 16) {
                statChip("Ø 7 Tage", value: formatH(store.schnittStunden7Tage), color: accent)
                statChip("Ziel", value: formatH(store.zielStunden), color: Color(red: 0.5, green: 0.3, blue: 1.0))
            }

            Button { showZielPicker = true } label: {
                Text("Schlafziel ändern")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        .sheet(isPresented: $showZielPicker) { zielPickerSheet }
    }

    private var timePickers: some View {
        VStack(spacing: 12) {
            timeRow(icon: "moon.fill", label: "Eingeschlafen um", color: Color(red: 0.5, green: 0.3, blue: 1.0), selection: $schlafenszeit)
            Divider().opacity(0.15)
            timeRow(icon: "sun.horizon.fill", label: "Aufgewacht um", color: .orange, selection: $aufwachzeit)
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func timeRow(icon: String, label: String, color: Color, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
                .accentColor(color)
        }
    }

    private var qualitaetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schlafqualität")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { s in
                    Button {
                        withAnimation(.spring(response: 0.3)) { qualitaet = s }
                    } label: {
                        Image(systemName: s <= qualitaet ? "moon.stars.fill" : "moon")
                            .font(.system(size: 26))
                            .foregroundStyle(s <= qualitaet ? Color(red: 0.5, green: 0.3, blue: 1.0) : .white.opacity(0.2))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var saveButton: some View {
        Button {
            var e = SchlafEintrag(datum: Date(), schlafenszeit: schlafenszeit, aufwachzeit: aufwachzeit, qualitaet: qualitaet)
            // If wakeup is before bedtime (slept past midnight), add 1 day to wakeup
            if aufwachzeit < schlafenszeit {
                aufwachzeit = aufwachzeit.addingTimeInterval(86400)
                e = SchlafEintrag(datum: Date(), schlafenszeit: schlafenszeit, aufwachzeit: aufwachzeit, qualitaet: qualitaet)
            }
            store.add(e)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            Label("Schlaf speichern", systemImage: "bed.double.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red: 0.3, green: 0.2, blue: 0.8), accent],
                                   startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .buttonStyle(.plain)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Letzte 7 Tage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            let days = store.last7Days()
            let maxH = max(days.compactMap(\.stunden).max() ?? 8, store.zielStunden)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 6) {
                        if let h = pair.stunden {
                            Text(String(format: "%.1f", h))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(h >= store.zielStunden ? accent : .white.opacity(0.5))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(h >= store.zielStunden
                                      ? LinearGradient(colors: [accent, Color(red: 0.5, green: 0.3, blue: 1.0)], startPoint: .bottom, endPoint: .top)
                                      : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.12)], startPoint: .bottom, endPoint: .top))
                                .frame(height: CGFloat(h / maxH) * 70 + 8)
                        } else {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 8)
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

    private var zielPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.16).ignoresSafeArea()
                VStack(spacing: 16) {
                    ForEach([5.0, 6.0, 7.0, 7.5, 8.0, 8.5, 9.0], id: \.self) { h in
                        Button {
                            store.zielStunden = h
                            showZielPicker = false
                        } label: {
                            HStack {
                                Text(formatH(h))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if store.zielStunden == h {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(accent)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(store.zielStunden == h ? accent.opacity(0.15) : Color.white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Schlafziel")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { showZielPicker = false }
                }
            }
        }
    }

    private func statChip(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE"
        return String(f.string(from: date).prefix(2))
    }

    private func formatH(_ h: Double) -> String {
        let hi = Int(h)
        let m  = Int((h - Double(hi)) * 60)
        return m == 0 ? "\(hi)h" : "\(hi)h \(m)m"
    }
}

private func defaultSchlafenszeit() -> Date {
    let cal = Calendar.current
    return cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
}

private func defaultAufwachzeit() -> Date {
    let cal = Calendar.current
    return cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
}
