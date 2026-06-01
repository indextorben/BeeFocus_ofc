import SwiftUI

struct LernzielView: View {
    @StateObject private var store = LernzielStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAddZiel = false
    @State private var showLogSession: Lernziel? = nil
    @State private var showDetail: Lernziel? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        headerSection
                        if store.streak > 0 || store.gesamtStundenHeute > 0 {
                            statsRow
                        }
                        aktiveZiele
                        if store.ziele.contains(where: { $0.abgeschlossen }) {
                            abgeschlosseneZiele
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18).padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddZiel = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.white).font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showAddZiel) { LernzielAddSheet(store: store, dismiss: { showAddZiel = false }) }
            .sheet(item: $showLogSession) { ziel in
                LernSessionSheet(store: store, ziel: ziel, dismiss: { showLogSession = nil })
            }
            .sheet(item: $showDetail) { ziel in
                LernzielDetailSheet(store: store, ziel: ziel, dismiss: { showDetail = nil }) {
                    showLogSession = ziel
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("📚").font(.system(size: 52))
            Text("Lernziele").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Text("Wissen aufbauen, Fortschritt verfolgen")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
        }
        .multilineTextAlignment(.center)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statChip(icon: "flame.fill", value: "\(store.streak)", unit: "Tage Streak", color: .orange)
            statChip(icon: "clock.fill",
                     value: String(format: "%.1f", store.gesamtStundenHeute),
                     unit: "Std. heute", color: Color(red: 0.4, green: 0.7, blue: 1.0))
            statChip(icon: "checkmark.circle.fill",
                     value: "\(store.ziele.filter { $0.abgeschlossen }.count)",
                     unit: "Abgeschlossen", color: .green)
        }
    }

    private func statChip(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 14))
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text(unit).font(.system(size: 10)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var aktiveZiele: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.ziele.filter({ !$0.abgeschlossen }).isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.35))
                    Text("Noch kein Lernziel.\nTippe auf + um eines hinzuzufügen.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                Text("Aktive Ziele")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                ForEach(store.ziele.filter { !$0.abgeschlossen }) { ziel in
                    zielCard(ziel)
                }
            }
        }
    }

    private var abgeschlosseneZiele: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Abgeschlossen ✓")
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            ForEach(store.ziele.filter { $0.abgeschlossen }) { ziel in
                zielCard(ziel, abgeschlossen: true)
            }
        }
    }

    private func zielCard(_ ziel: Lernziel, abgeschlossen: Bool = false) -> some View {
        let progress = store.fortschritt(fuer: ziel)
        let erledigte = store.erledigteStunden(fuer: ziel)

        return Button { showDetail = ziel } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    // Progress ring
                    ZStack {
                        Circle().stroke(ziel.farbe.opacity(0.2), lineWidth: 5).frame(width: 48, height: 48)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(abgeschlossen ? Color.green : ziel.farbe,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 48, height: 48)
                            .rotationEffect(.degrees(-90))
                        Image(systemName: abgeschlossen ? "checkmark" : ziel.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(abgeschlossen ? .green : ziel.farbe)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ziel.titel).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        Text(String(format: "%.1f / %.0f Std.", erledigte, ziel.zielStunden))
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    if !abgeschlossen {
                        Button {
                            showLogSession = ziel
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24)).foregroundStyle(ziel.farbe)
                        }
                    }
                }

                if !abgeschlossen {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(ziel.farbe.opacity(0.2)).frame(height: 6)
                            Capsule().fill(ziel.farbe)
                                .frame(width: max(6, geo.size.width * progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                        abgeschlossen ? Color.green.opacity(0.3) : ziel.farbe.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { store.deleteZiel(ziel) } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Ziel Sheet

private struct LernzielAddSheet: View {
    @ObservedObject var store: LernzielStore
    let dismiss: () -> Void

    @State private var titel: String = ""
    @State private var beschreibung: String = ""
    @State private var zielStunden: Double = 10
    @State private var symbol: String = "book.fill"
    @State private var farbName: String = "blau"

    let symbole = ["book.fill","graduationcap.fill","brain.head.profile","pencil.and.ruler.fill",
                   "music.note","paintpalette.fill","laptopcomputer","flask.fill",
                   "figure.run","dumbbell.fill","guitar.fill","mic.fill"]

    let farben: [(name: String, farbe: Color)] = [
        ("blau", Color(red: 0.2, green: 0.6, blue: 1.0)),
        ("gruen", Color(red: 0.2, green: 0.8, blue: 0.5)),
        ("orange", Color(red: 1.0, green: 0.55, blue: 0.1)),
        ("pink", Color(red: 1.0, green: 0.4, blue: 0.7)),
        ("lila", Color(red: 0.6, green: 0.3, blue: 1.0)),
        ("teal", Color(red: 0.2, green: 0.75, blue: 0.8)),
        ("gelb", Color(red: 1.0, green: 0.8, blue: 0.1)),
        ("mint", Color(red: 0.2, green: 0.9, blue: 0.7)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        titelField
                        stundenSlider
                        symbolPicker
                        farbPicker
                        beschreibungField
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18).padding(.top, 20)
                }
            }
            .navigationTitle("Neues Lernziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") { save() }
                        .foregroundStyle(titel.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.4) : .white)
                        .fontWeight(.semibold)
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var titelField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thema / Fähigkeit").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("z.B. SwiftUI, Gitarre, Spanisch…", text: $titel)
                .font(.system(size: 15)).foregroundStyle(.white).tint(.white)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var stundenSlider: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ziel: \(Int(zielStunden)) Stunden")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            Slider(value: $zielStunden, in: 1...500, step: 1).tint(.white)
            HStack {
                ForEach([5, 10, 20, 50, 100], id: \.self) { v in
                    Button { zielStunden = Double(v) } label: {
                        Text("\(v)h")
                            .font(.system(size: 12))
                            .foregroundStyle(Int(zielStunden) == v ? .black : .white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Int(zielStunden) == v ? Color.white : Color.white.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Symbol").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                ForEach(symbole, id: \.self) { sym in
                    Button { symbol = sym } label: {
                        Image(systemName: sym).font(.system(size: 20))
                            .foregroundStyle(symbol == sym ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(symbol == sym ? Color.white : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var farbPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Farbe").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            HStack(spacing: 12) {
                ForEach(farben, id: \.name) { f in
                    Button { farbName = f.name } label: {
                        Circle().fill(f.farbe).frame(width: 32, height: 32)
                            .overlay { if farbName == f.name { Circle().stroke(.white, lineWidth: 3) } }
                    }
                }
            }
        }
    }

    private var beschreibungField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beschreibung (optional)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("Warum willst du das lernen?", text: $beschreibung, axis: .vertical)
                .lineLimit(2...4).font(.system(size: 14)).foregroundStyle(.white).tint(.white)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func save() {
        let t = titel.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.addZiel(Lernziel(titel: t, beschreibung: beschreibung, symbol: symbol, farbName: farbName, zielStunden: zielStunden))
        dismiss()
    }
}

// MARK: - Log Session Sheet

private struct LernSessionSheet: View {
    @ObservedObject var store: LernzielStore
    let ziel: Lernziel
    let dismiss: () -> Void

    @State private var dauer: Int = 30
    @State private var notiz: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
                VStack(spacing: 24) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(ziel.farbe.opacity(0.2)).frame(width: 50, height: 50)
                            Image(systemName: ziel.symbol).font(.system(size: 22)).foregroundStyle(ziel.farbe)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ziel.titel).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            Text(String(format: "%.1f / %.0f Std.", store.erledigteStunden(fuer: ziel), ziel.zielStunden))
                                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Dauer: \(dauer) Minuten")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        Slider(value: Binding(get: { Double(dauer) }, set: { dauer = Int($0) }), in: 5...300, step: 5).tint(.white)
                        HStack {
                            ForEach([15, 30, 45, 60, 90], id: \.self) { v in
                                Button { dauer = v } label: {
                                    Text("\(v)m")
                                        .font(.system(size: 12))
                                        .foregroundStyle(dauer == v ? .black : .white)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(dauer == v ? Color.white : Color.white.opacity(0.15), in: Capsule())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notiz (optional)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        TextField("Was hast du gelernt?", text: $notiz, axis: .vertical)
                            .lineLimit(2...4).font(.system(size: 14)).foregroundStyle(.white).tint(.white)
                            .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Lerneinheit erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        store.addSession(LernSession(lernzielID: ziel.id, dauerMinuten: dauer, notiz: notiz))
                        dismiss()
                    }
                    .foregroundStyle(.white).fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Detail Sheet

private struct LernzielDetailSheet: View {
    @ObservedObject var store: LernzielStore
    let ziel: Lernziel
    let dismiss: () -> Void
    let onLogSession: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.15, blue: 0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Ring + title
                        let progress = store.fortschritt(fuer: ziel)
                        VStack(spacing: 12) {
                            ZStack {
                                Circle().stroke(ziel.farbe.opacity(0.15), lineWidth: 14).frame(width: 100, height: 100)
                                Circle()
                                    .trim(from: 0, to: progress)
                                    .stroke(ziel.farbe, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                                    .frame(width: 100, height: 100).rotationEffect(.degrees(-90))
                                VStack(spacing: 2) {
                                    Text("\(Int(progress * 100))%").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                                    Text("Fertig").font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            Text(ziel.titel).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                            Text(String(format: "%.1f / %.0f Stunden", store.erledigteStunden(fuer: ziel), ziel.zielStunden))
                                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, 8)

                        // Sessions
                        let recent = store.recenteSessions(fuer: ziel, limit: 10)
                        if !recent.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Letzte Einheiten").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                                ForEach(recent) { s in
                                    HStack {
                                        Image(systemName: "clock.fill").foregroundStyle(ziel.farbe).font(.system(size: 13))
                                        Text("\(s.dauerMinuten) Min").font(.system(size: 14)).foregroundStyle(.white)
                                        if !s.notiz.isEmpty {
                                            Text("· \(s.notiz)").font(.system(size: 13)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                                        }
                                        Spacer()
                                        Text(kurzDatum(s.datum)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding(12)
                                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onLogSession() }
                        } label: {
                            Label("Lerneinheit hinzufügen", systemImage: "plus.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(ziel.farbe, in: RoundedRectangle(cornerRadius: 14))
                        }
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }.foregroundStyle(.white)
                }
            }
        }
    }

    private func kurzDatum(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de"); f.dateFormat = "d. MMM"
        return f.string(from: date)
    }
}
