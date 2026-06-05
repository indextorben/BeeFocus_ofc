import SwiftUI

struct ZeiterfassungView: View {
    @StateObject private var store = ZeiterfassungStore.shared
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var showAdd = false
    @State private var showDeleteEintrag: ZeitEintrag? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        statsRow
                        projektChart
                        tagesChart
                        tagesEintraege
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizer.localizedString(forKey: "zeit_close")) { dismiss() }
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
            .confirmationDialog(localizer.localizedString(forKey: "zeit_delete_entry_title"), isPresented: Binding(
                get: { showDeleteEintrag != nil },
                set: { if !$0 { showDeleteEintrag = nil } }
            )) {
                Button(localizer.localizedString(forKey: "zeit_delete_button"), role: .destructive) {
                    if let e = showDeleteEintrag { store.delete(e) }
                    showDeleteEintrag = nil
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("⏱️")
                .font(.system(size: 56))
            Text(localizer.localizedString(forKey: "zeit_nav_title"))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(localizer.localizedString(forKey: "zeit_header_subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
        }
        .multilineTextAlignment(.center)
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            let h = store.heuteGesamt / 60
            let m = store.heuteGesamt % 60
            statChip(
                icon: "clock.fill",
                value: h > 0 ? "\(h)h \(m)m" : "\(m)m",
                unit: localizer.localizedString(forKey: "zeit_stat_today"),
                color: .cyan
            )
            statChip(
                icon: "folder.fill",
                value: "\(store.projekte.count)",
                unit: localizer.localizedString(forKey: "zeit_stat_projects"),
                color: Color(red: 0.8, green: 0.6, blue: 1.0)
            )
            statChip(
                icon: "calendar",
                value: "\(store.eintraege.filter { Calendar.current.isDateInToday($0.datum) }.count)",
                unit: localizer.localizedString(forKey: "zeit_stat_entries_today"),
                color: Color(red: 0.4, green: 0.9, blue: 0.6)
            )
        }
    }

    private func statChip(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 14))
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text(unit).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var projektChart: some View {
        let data = store.minutenProProjekt7Tage()
        if !data.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(localizer.localizedString(forKey: "zeit_projects_7days"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                let total = max(data.reduce(0) { $0 + $1.minuten }, 1)
                VStack(spacing: 8) {
                    ForEach(data.prefix(5), id: \.projekt) { item in
                        HStack(spacing: 10) {
                            Text(item.projekt)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 90, alignment: .leading)
                                .lineLimit(1)
                            GeometryReader { geo in
                                let w = CGFloat(item.minuten) / CGFloat(total) * geo.size.width
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ZeitEintrag(projekt: item.projekt, dauerMinuten: item.minuten, farbName: item.farbName).farbe)
                                    .frame(width: max(4, w))
                            }
                            .frame(height: 18)
                            let h = item.minuten / 60
                            let m = item.minuten % 60
                            Text(h > 0 ? "\(h)h\(m)m" : "\(m)m")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.8))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(16)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var tagesChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizer.localizedString(forKey: "zeit_daily_overview"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            let data = store.tagesMinuten7Tage()
            let maxMins = max(data.map(\.minuten).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(data, id: \.date) { item in
                    VStack(spacing: 4) {
                        if item.minuten > 0 {
                            let h = item.minuten / 60
                            let m = item.minuten % 60
                            Text(h > 0 ? "\(h)h" : "\(m)m")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.minuten > 0 ? Color.cyan : Color.white.opacity(0.2))
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

    private var tagesEintraege: some View {
        let heute = store.eintraege.filter { Calendar.current.isDateInToday($0.datum) }
            .sorted { $0.datum > $1.datum }

        return VStack(alignment: .leading, spacing: 12) {
            Text(localizer.localizedString(forKey: "zeit_todays_entries"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            if heute.isEmpty {
                Text(localizer.localizedString(forKey: "zeit_no_entries_yet"))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(heute) { eintrag in
                    zeitEintragRow(eintrag)
                }
            }
        }
    }

    private func zeitEintragRow(_ e: ZeitEintrag) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 6)
                .fill(e.farbe)
                .frame(width: 6, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(e.projekt)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    let h = e.dauerMinuten / 60
                    let m = e.dauerMinuten % 60
                    Text(h > 0 ? "\(h)h \(m)m" : "\(m) Min")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                    if !e.notiz.isEmpty {
                        Text("· \(e.notiz)")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
            Button { showDeleteEintrag = e } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private var addSheet: some View {
        ZeiterfassungAddSheet(store: store, dismiss: { showAdd = false })
    }

    private func shortDay(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(2))
    }
}

private struct ZeiterfassungAddSheet: View {
    @ObservedObject var store: ZeiterfassungStore
    let dismiss: () -> Void
    @ObservedObject private var localizer = LocalizationManager.shared

    @State private var projekt: String = ""
    @State private var neuesProjekt: String = ""
    @State private var dauer: Int = 30
    @State private var notiz: String = ""
    @State private var gewaehlteFarbe: String = "lila"
    @State private var showNeuesProjekt = false

    let farben: [(name: String, farbe: Color)] = [
        ("lila", Color(red: 0.6, green: 0.3, blue: 1.0)),
        ("blau", Color(red: 0.2, green: 0.6, blue: 1.0)),
        ("gruen", Color(red: 0.2, green: 0.8, blue: 0.5)),
        ("orange", Color(red: 1.0, green: 0.55, blue: 0.1)),
        ("pink", Color(red: 1.0, green: 0.4, blue: 0.7)),
        ("cyan", Color(red: 0.1, green: 0.85, blue: 0.95)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                VStack(spacing: 24) {
                    projektSection
                    dauerSection
                    farbeSection
                    notizSection
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle(localizer.localizedString(forKey: "zeit_log_time_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizer.localizedString(forKey: "zeit_cancel")) { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizer.localizedString(forKey: "zeit_save")) { save() }
                        .foregroundStyle(canSave ? .white : .white.opacity(0.4))
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool { !effectiveProjekt.isEmpty }

    private var effectiveProjekt: String {
        showNeuesProjekt ? neuesProjekt.trimmingCharacters(in: .whitespaces) : projekt
    }

    private var projektSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.localizedString(forKey: "zeit_project_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            if !store.projekte.isEmpty && !showNeuesProjekt {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.projekte, id: \.self) { p in
                            Button { projekt = p } label: {
                                Text(p)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(projekt == p ? Color(red: 0.25, green: 0.45, blue: 1.0) : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(projekt == p ? .white : .white.opacity(0.15), in: Capsule())
                            }
                        }
                        Button { showNeuesProjekt = true } label: {
                            Label(localizer.localizedString(forKey: "zeit_new_project_chip"), systemImage: "plus")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.15), in: Capsule())
                        }
                    }
                }
            } else {
                TextField(localizer.localizedString(forKey: "zeit_project_name_placeholder"), text: $neuesProjekt)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(12)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var dauerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: localizer.localizedString(forKey: "zeit_duration_label"), dauer))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Slider(value: Binding(get: { Double(dauer) }, set: { dauer = Int($0) }), in: 5...480, step: 5)
                .tint(.white)
            HStack {
                ForEach([15, 30, 60, 90, 120], id: \.self) { val in
                    Button { dauer = val } label: {
                        Text("\(val)m")
                            .font(.system(size: 13))
                            .foregroundStyle(dauer == val ? Color(red: 0.25, green: 0.45, blue: 1.0) : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(dauer == val ? .white : .white.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
    }

    private var farbeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizer.localizedString(forKey: "zeit_color_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                ForEach(farben, id: \.name) { f in
                    Button { gewaehlteFarbe = f.name } label: {
                        Circle()
                            .fill(f.farbe)
                            .frame(width: 34, height: 34)
                            .overlay {
                                if gewaehlteFarbe == f.name {
                                    Circle().stroke(.white, lineWidth: 3)
                                }
                            }
                    }
                }
            }
        }
    }

    private var notizSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.localizedString(forKey: "zeit_note_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            TextField(localizer.localizedString(forKey: "zeit_note_placeholder"), text: $notiz, axis: .vertical)
                .lineLimit(2...3)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .tint(.white)
                .padding(12)
                .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func save() {
        let p = effectiveProjekt
        guard !p.isEmpty else { return }
        let eintrag = ZeitEintrag(projekt: p, dauerMinuten: dauer, notiz: notiz, farbName: gewaehlteFarbe)
        store.add(eintrag)
        dismiss()
    }
}
