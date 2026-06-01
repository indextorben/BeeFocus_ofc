import SwiftUI

struct FinanzTrackerView: View {
    @StateObject private var store = FinanzStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var filterTyp: FinanzTyp? = nil

    private let currencyFmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .currency; f.locale = Locale(identifier: "de_DE"); return f
    }()

    func fmt(_ val: Double) -> String { currencyFmt.string(from: NSNumber(value: val)) ?? "0,00 €" }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.1, green: 0.4, blue: 0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        headerSection
                        bilanzCard
                        kategorienChart
                        filterBar
                        eintragListe
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
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.white).font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showAdd) { FinanzAddSheet(store: store, dismiss: { showAdd = false }) }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("💰").font(.system(size: 52))
            Text("Finanz-Tracker").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Text("Einnahmen & Ausgaben diesen Monat")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
        }
        .multilineTextAlignment(.center)
    }

    private var bilanzCard: some View {
        VStack(spacing: 16) {
            // Main balance
            VStack(spacing: 4) {
                Text("Bilanz")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase).tracking(0.8)
                Text(fmt(store.bilanz))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(store.bilanz >= 0 ? Color(red: 0.3, green: 0.9, blue: 0.5) : Color(red: 1.0, green: 0.4, blue: 0.4))
            }

            Divider().background(.white.opacity(0.2))

            // Einnahmen / Ausgaben
            HStack(spacing: 0) {
                bilanzHalf(label: "Einnahmen", value: store.einnahmenDiesenMonat, color: Color(red: 0.3, green: 0.9, blue: 0.5), icon: "arrow.down.circle.fill")
                Divider().frame(height: 40).background(.white.opacity(0.2))
                bilanzHalf(label: "Ausgaben", value: store.ausgabenDiesenMonat, color: Color(red: 1.0, green: 0.45, blue: 0.45), icon: "arrow.up.circle.fill")
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
    }

    private func bilanzHalf(label: String, value: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 18))
            Text(fmt(value)).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var kategorienChart: some View {
        let data = store.ausgabenProKategorie()
        if !data.isEmpty {
            let total = max(data.reduce(0) { $0 + $1.betrag }, 1)
            VStack(alignment: .leading, spacing: 12) {
                Text("Ausgaben nach Kategorie")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                VStack(spacing: 8) {
                    ForEach(data.prefix(5), id: \.name) { item in
                        let farbe: Color = {
                            let tmp = FinanzKategorie(name: item.name, symbol: item.symbol, farbName: item.farbName)
                            return tmp.farbe
                        }()
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).foregroundStyle(farbe).font(.system(size: 13)).frame(width: 20)
                            Text(item.name).font(.system(size: 13)).foregroundStyle(.white).frame(width: 90, alignment: .leading).lineLimit(1)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(farbe)
                                    .frame(width: max(4, CGFloat(item.betrag / total) * geo.size.width))
                            }
                            .frame(height: 14)
                            Text(fmt(item.betrag)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            filterChip(label: "Alle", active: filterTyp == nil) { filterTyp = nil }
            filterChip(label: "Einnahmen", active: filterTyp == .einnahme) { filterTyp = .einnahme }
            filterChip(label: "Ausgaben", active: filterTyp == .ausgabe) { filterTyp = .ausgabe }
        }
    }

    private func filterChip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? .black : .white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(active ? Color.white : Color.white.opacity(0.15), in: Capsule())
        }
    }

    private var eintragListe: some View {
        let eintraege = store.diesenMonat.filter { filterTyp == nil || $0.typ == filterTyp }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Diesen Monat")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            if eintraege.isEmpty {
                Text("Noch keine Einträge").font(.system(size: 14)).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
            } else {
                ForEach(eintraege) { e in
                    finanzRow(e)
                }
            }
        }
    }

    private func finanzRow(_ e: FinanzEintrag) -> some View {
        let farbe: Color = {
            let tmp = FinanzKategorie(name: e.kategorieName, symbol: e.kategorieSymbol, farbName: e.kategorieFarbName)
            return tmp.farbe
        }()
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(farbe.opacity(0.2)).frame(width: 40, height: 40)
                Image(systemName: e.kategorieSymbol).foregroundStyle(farbe).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.kategorieName).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                if !e.notiz.isEmpty {
                    Text(e.notiz).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text((e.typ == .einnahme ? "+" : "-") + fmt(e.betrag))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(e.typ == .einnahme ? Color(red: 0.3, green: 0.9, blue: 0.5) : Color(red: 1.0, green: 0.45, blue: 0.45))
                Text(kurzDatum(e.datum)).font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
        .contextMenu {
            Button(role: .destructive) { store.delete(e) } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private func kurzDatum(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "de"); f.dateFormat = "d. MMM"
        return f.string(from: date)
    }
}

// MARK: - Add Sheet

private struct FinanzAddSheet: View {
    @ObservedObject var store: FinanzStore
    let dismiss: () -> Void

    @State private var typ: FinanzTyp = .ausgabe
    @State private var betragText: String = ""
    @State private var gewaehlteKategorie: FinanzKategorie?
    @State private var notiz: String = ""
    @State private var datum: Date = Date()

    private let currencyFmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.locale = Locale(identifier: "de_DE"); return f
    }()

    private var betrag: Double {
        let s = betragText.replacingOccurrences(of: ",", with: ".")
        return Double(s) ?? 0
    }

    private var canSave: Bool { betrag > 0 && gewaehlteKategorie != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.1, green: 0.4, blue: 0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        typSelector
                        betragField
                        datumRow
                        kategorieGrid
                        notizField
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18).padding(.top, 20)
                }
            }
            .navigationTitle("Eintrag hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") { save() }
                        .foregroundStyle(canSave ? .white : .white.opacity(0.4))
                        .fontWeight(.semibold).disabled(!canSave)
                }
            }
        }
    }

    private var typSelector: some View {
        HStack(spacing: 12) {
            ForEach(FinanzTyp.allCases, id: \.self) { t in
                Button { typ = t } label: {
                    Label(t.rawValue, systemImage: t == .einnahme ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(typ == t ? .black : .white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(typ == t ? Color.white : Color.white.opacity(0.15), in: Capsule())
                }
            }
        }
    }

    private var betragField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Betrag (€)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("0,00", text: $betragText)
                .keyboardType(.decimalPad)
                .font(.system(size: 28, weight: .bold)).foregroundStyle(.white).tint(.white)
                .multilineTextAlignment(.center)
                .padding(16).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var datumRow: some View {
        HStack {
            Text("Datum").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            Spacer()
            DatePicker("", selection: $datum, displayedComponents: .date)
                .datePickerStyle(.compact).colorScheme(.dark)
        }
    }

    private var kategorieGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kategorie").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                ForEach(store.kategorien) { kat in
                    Button { gewaehlteKategorie = kat } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kat.symbol).font(.system(size: 20)).foregroundStyle(gewaehlteKategorie?.id == kat.id ? .black : kat.farbe)
                            Text(kat.name).font(.system(size: 11, weight: .medium)).foregroundStyle(gewaehlteKategorie?.id == kat.id ? .black : .white).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(gewaehlteKategorie?.id == kat.id ? kat.farbe : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private var notizField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notiz (optional)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("Beschreibung…", text: $notiz, axis: .vertical)
                .lineLimit(2...3).font(.system(size: 14)).foregroundStyle(.white).tint(.white)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func save() {
        guard let kat = gewaehlteKategorie, betrag > 0 else { return }
        let e = FinanzEintrag(datum: datum, typ: typ,
                              kategorieName: kat.name, kategorieSymbol: kat.symbol,
                              kategorieFarbName: kat.farbName, betrag: betrag, notiz: notiz)
        store.add(e)
        dismiss()
    }
}
