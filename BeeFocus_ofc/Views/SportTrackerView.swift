import SwiftUI

struct SportTrackerView: View {
    @StateObject private var store = SportStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var gewaehlteSportart: SportArt = .laufen
    @State private var dauer: Int = 30
    @State private var intensitaet: Int = 2
    @State private var notiz: String = ""
    @State private var showAdd = false
    @State private var showDeleteConfirm: SportEintrag? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.6, blue: 0.4), Color(red: 0.1, green: 0.4, blue: 0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        statsRow
                        weekChart
                        todayList
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showAdd) { addSheet }
            .confirmationDialog("Eintrag löschen?", isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            )) {
                Button("Löschen", role: .destructive) {
                    if let e = showDeleteConfirm { store.delete(e) }
                    showDeleteConfirm = nil
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🏃")
                .font(.system(size: 56))
            Text("Sport-Tracker")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Bleib aktiv und verfolge deinen Fortschritt")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
        }
        .multilineTextAlignment(.center)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statChip(icon: "flame.fill", value: "\(store.heutigeGesamtMinuten)", unit: "Min heute", color: .orange)
            statChip(icon: "flame.fill", value: "\(store.streak)", unit: "Tage Streak", color: Color(red: 1.0, green: 0.5, blue: 0.2))
            statChip(icon: "heart.fill", value: "\(store.heutigeEintraege.reduce(0) { $0 + $1.kalorien })", unit: "kcal heute", color: .pink)
        }
    }

    private func statChip(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 14))
            Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text(unit).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }

    private var weekChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            let data = store.last7Days()
            let maxMins = max(data.map(\.minuten).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.date) { item in
                    VStack(spacing: 4) {
                        if item.minuten > 0 {
                            Text("\(item.minuten)")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.minuten > 0 ? Color.white : Color.white.opacity(0.2))
                            .frame(height: max(4, CGFloat(item.minuten) / CGFloat(maxMins) * 80))
                        Text(shortDay(item.date))
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
    }

    private var todayList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heute")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            if store.heutigeEintraege.isEmpty {
                Text("Noch keine Aktivität heute. Los geht's! 💪")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.heutigeEintraege) { eintrag in
                    sportRow(eintrag)
                }
            }
        }
    }

    private func sportRow(_ e: SportEintrag) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(e.art.farbe.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: e.art.icon)
                    .foregroundStyle(e.art.farbe)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(e.art.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text("\(e.dauerMinuten) Min")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(intensitaetLabel(e.intensitaet))
                        .font(.system(size: 13))
                        .foregroundStyle(intensitaetFarbe(e.intensitaet))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(e.kalorien) kcal")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer()
            Button { showDeleteConfirm = e } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var addSheet: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.15, green: 0.6, blue: 0.4), Color(red: 0.1, green: 0.4, blue: 0.6)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    sportArtGrid
                    dauerSection
                    intensitaetSection
                    notizSection
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("Aktivität hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { showAdd = false }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        store.add(SportEintrag(art: gewaehlteSportart, dauerMinuten: dauer, intensitaet: intensitaet, notiz: notiz))
                        showAdd = false
                    }
                    .foregroundStyle(.white).fontWeight(.semibold)
                }
            }
        }
    }

    private var sportArtGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
            ForEach(SportArt.allCases, id: \.self) { art in
                Button { gewaehlteSportart = art } label: {
                    VStack(spacing: 6) {
                        Image(systemName: art.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(gewaehlteSportart == art ? .white : art.farbe)
                        Text(art.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(gewaehlteSportart == art ? .white : .white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(gewaehlteSportart == art ? art.farbe : .white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var dauerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dauer: \(dauer) Minuten")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Slider(value: Binding(get: { Double(dauer) }, set: { dauer = Int($0) }), in: 5...180, step: 5)
                .tint(.white)
        }
    }

    private var intensitaetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Intensität")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                ForEach(1...3, id: \.self) { i in
                    Button { intensitaet = i } label: {
                        VStack(spacing: 4) {
                            Text(intensitaetEmoji(i)).font(.system(size: 22))
                            Text(intensitaetLabel(i)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(intensitaet == i ? .white.opacity(0.25) : .white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if intensitaet == i {
                                RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: 1.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private var notizSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notiz (optional)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            TextField("Wie war das Training?", text: $notiz, axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .tint(.white)
                .padding(12)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shortDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de")
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(2))
    }

    private func intensitaetLabel(_ i: Int) -> String {
        switch i { case 1: "Leicht"; case 2: "Mittel"; default: "Intensiv" }
    }
    private func intensitaetEmoji(_ i: Int) -> String {
        switch i { case 1: "🚶"; case 2: "🏃"; default: "🔥" }
    }
    private func intensitaetFarbe(_ i: Int) -> Color {
        switch i { case 1: .mint; case 2: .yellow; default: .orange }
    }
}
