import SwiftUI

// MARK: - Picker Sheet (von TagesplanerView geöffnet)

struct BausteinPickerSheet: View {
    let datum: Date
    let onEinfuegen: (TagesplanBaustein) -> Void

    @StateObject private var store = BausteinStore.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingVerwaltung = false
    @State private var suche: String = ""
    @FocusState private var sucheFocused: Bool

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    // Smart-scored top picks (max 4) für die Chips-Leiste oben
    private var topPicks: [TagesplanBaustein] {
        store.smartVorschlaege(datum: datum, eingabe: "").prefix(4).map { $0 }
    }

    // Suchergebnis oder vollständige Score-sortierte Liste
    private var gefilterteBausteine: [TagesplanBaustein] {
        if suche.trimmingCharacters(in: .whitespaces).isEmpty {
            return store.bausteine.sorted {
                ($0.verwendungen, $0.passtzuWochentag(datum) ? 1 : 0) >
                ($1.verwendungen, $1.passtzuWochentag(datum) ? 1 : 0)
            }
        }
        return store.smartVorschlaege(datum: datum, eingabe: suche)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()

                Group {
                    if store.bausteine.isEmpty {
                        emptyState
                    } else {
                        liste
                    }
                }
            }
            .navigationTitle("Insert Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingVerwaltung = true } label: {
                        Label("Manage", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .navigationDestination(isPresented: $showingVerwaltung) {
                BausteinListView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hauptliste

    private var liste: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Suchfeld
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(sucheFocused || !suche.isEmpty ? themeC1 : .secondary)
                    TextField("Search…", text: $suche)
                        .font(.system(size: 15))
                        .focused($sucheFocused)
                        .submitLabel(.search)
                    if !suche.isEmpty {
                        Button { withAnimation { suche = "" } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 15))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: sucheFocused)

                // Smart-Chips (nur ohne Suche)
                if suche.isEmpty && !topPicks.isEmpty {
                    smartChipsRow
                }

                // Trennlinie + Sektionsheader
                let bausteine = gefilterteBausteine
                if bausteine.isEmpty {
                    keineErgebnisse
                } else {
                    pickerSection(
                        titel: suche.isEmpty ? "All Blocks" : "Results",
                        symbol: suche.isEmpty ? nil : "magnifyingglass",
                        bausteine: bausteine
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: suche)
        }
    }

    // MARK: - Smart-Chips oben

    private var smartChipsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(themeC1)
                Text("Fitting now")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(topPicks) { b in
                        Button {
                            einfuegen(b)
                        } label: {
                            HStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(b.farbe.color.opacity(0.18))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: b.symbol)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(b.farbe.color)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(b.titel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
                                        .lineLimit(1)
                                    Text(b.zeitLabel)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(b.farbe.color.opacity(0.85))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(b.farbe.color.opacity(isDark ? 0.16 : 0.09),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(b.farbe.color.opacity(0.28), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Sektion + Zeile

    private func pickerSection(titel: String, symbol: String?, bausteine: [TagesplanBaustein]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                if let sym = symbol {
                    Image(systemName: sym)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                }
                Text(titel.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(bausteine) { b in
                    pickerRow(b)
                }
            }
        }
    }

    private func pickerRow(_ b: TagesplanBaustein) -> some View {
        Button {
            einfuegen(b)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(b.farbe.color.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: b.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(b.farbe.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(b.titel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)
                        if b.isHighPriority {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.orange)
                        }
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(b.zeitLabel)
                            .font(.system(size: 12))
                        if b.verwendungen > 0 {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Image(systemName: "arrow.trianglehead.counterclockwise")
                                .font(.system(size: 9))
                            Text("\(b.verwendungen)×")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundStyle(isDark ? .white.opacity(0.42) : .secondary)
                }

                Spacer()

                if !b.wochentageKurz.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(b.wochentageKurz, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(b.farbe.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(b.farbe.color.opacity(0.12), in: Capsule())
                        }
                    }
                }

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(themeC1)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(b.farbe.color.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func einfuegen(_ b: TagesplanBaustein) {
        store.verwendungErhoehen(b)
        onEinfuegen(b)
        dismiss()
    }

    private var keineErgebnisse: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(themeC1.opacity(0.35))
            Text("No blocks found")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDark ? .white.opacity(0.7) : .primary)
            Text("Try a different search term.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 48))
                .foregroundStyle(themeC1.opacity(0.4))
            Text("No blocks yet")
                .font(.headline)
                .foregroundStyle(isDark ? .white : .primary)
            Text("Create blocks you can repeatedly insert into your daily plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingVerwaltung = true
            } label: {
                Label("Create first block", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxHeight: .infinity)
    }
}

// MARK: - List View (Verwaltung)

struct BausteinListView: View {
    @StateObject private var store = BausteinStore.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema = ""
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    @State private var editingBaustein: TagesplanBaustein? = nil
    @State private var showingNew = false

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            Group {
                if store.bausteine.isEmpty {
                    emptyState
                } else {
                    liste
                }
            }
        }
        .navigationTitle("Blocks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    var neu = TagesplanBaustein()
                    editingBaustein = neu
                } label: {
                    Image(systemName: "plus").fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $editingBaustein) { b in
            BausteinEditSheet(baustein: b) { gespeichert in
                store.upsert(gespeichert)
            }
        }
    }

    private var liste: some View {
        List {
            ForEach(store.bausteine) { b in
                Button {
                    editingBaustein = b
                } label: {
                    bausteinRow(b)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete { offsets in
                store.loeschenIndexSet(offsets, in: store.bausteine)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func bausteinRow(_ b: TagesplanBaustein) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(b.farbe.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: b.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(b.farbe.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(b.titel.isEmpty ? "New Block" : b.titel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                    if b.isHighPriority {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                }
                Text(b.zeitLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
                if !b.wochentageKurz.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(b.wochentageKurz, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(b.farbe.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(b.farbe.color.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isDark ? .white.opacity(0.25) : .secondary.opacity(0.5))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(b.farbe.color.opacity(0.2), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 52))
                .foregroundStyle(themeC1.opacity(0.35))
            Text("No blocks yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isDark ? .white : .primary)
            Text("Create reusable time blocks for your daily plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                editingBaustein = TagesplanBaustein()
            } label: {
                Label("Create first block", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [themeC1, themeC2], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Edit Sheet

struct BausteinEditSheet: View {
    let onSave: (TagesplanBaustein) -> Void

    @AppStorage("aktivesStatistikThema") private var aktivesThema = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var baustein: TagesplanBaustein
    @State private var showDeleteConfirm = false
    @StateObject private var store = BausteinStore.shared

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    private let wochentageNamen = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let symbole = [
        "square.fill", "circle.fill", "star.fill", "bolt.fill", "flame.fill",
        "brain.head.profile", "book.fill", "dumbbell.fill", "fork.knife",
        "figure.run", "cup.and.saucer.fill", "moon.fill", "sun.max.fill",
        "laptopcomputer", "music.note", "heart.fill", "cart.fill", "pencil"
    ]

    init(baustein: TagesplanBaustein, onSave: @escaping (TagesplanBaustein) -> Void) {
        _baustein = State(initialValue: baustein)
        self.onSave = onSave
    }

    private var isExisting: Bool {
        store.bausteine.contains(where: { $0.id == baustein.id })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        previewCard
                        titelSection
                        zeitSection
                        wochentageSection
                        symbolSection
                        farbeSection
                        optionenSection
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle(isExisting ? "Edit Block" : "New Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(baustein)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(baustein.titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Preview

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(baustein.farbe.color.opacity(0.22))
                    .frame(width: 52, height: 52)
                Image(systemName: baustein.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(baustein.farbe.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(baustein.titel.isEmpty ? "Title…" : baustein.titel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(baustein.zeitLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
            }
            Spacer()
            if baustein.isHighPriority {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(baustein.farbe.color.opacity(isDark ? 0.12 : 0.07),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(baustein.farbe.color.opacity(0.3), lineWidth: 1.5))
    }

    // MARK: Titel

    private var titelSection: some View {
        editSection(label: "Title") {
            TextField("e.g. Deep Work Session", text: $baustein.titel)
                .font(.system(size: 16))
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Zeit

    private var zeitSection: some View {
        editSection(label: "Time Range") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconBadge("clock", color: baustein.farbe.color)
                    Text("Set start time")
                        .font(.system(size: 15))
                    Spacer()
                    Toggle("", isOn: $baustein.hatStartZeit).labelsHidden()
                }
                .padding(14)

                if baustein.hatStartZeit {
                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 12) {
                        iconBadge("play.fill", color: .green)
                        Text("From")
                            .font(.system(size: 15))
                        Spacer()
                        zeitPicker(stunde: $baustein.startStunde, minute: $baustein.startMinute)
                    }
                    .padding(14)

                    Divider().padding(.horizontal, 14)
                    HStack(spacing: 12) {
                        iconBadge("stop.fill", color: .red)
                        Text("Until (optional)")
                            .font(.system(size: 15))
                        Spacer()
                        Toggle("", isOn: $baustein.hatEndZeit).labelsHidden()
                    }
                    .padding(14)

                    if baustein.hatEndZeit {
                        Divider().padding(.horizontal, 14)
                        HStack(spacing: 12) {
                            iconBadge("flag.fill", color: .red)
                            Text("End")
                                .font(.system(size: 15))
                            Spacer()
                            zeitPicker(stunde: $baustein.endStunde, minute: $baustein.endMinute)
                        }
                        .padding(14)
                    }
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func zeitPicker(stunde: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            Picker("", selection: stunde) {
                ForEach(0..<24) { h in Text(String(format: "%02d", h)).tag(h) }
            }
            .pickerStyle(.wheel)
            .frame(width: 56, height: 80)
            .clipped()

            Text(":")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)

            Picker("", selection: minute) {
                ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 56, height: 80)
            .clipped()
        }
    }

    // MARK: Wochentage

    private var wochentageSection: some View {
        editSection(label: "Recurring on") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose days on which this block appears as a suggestion.")
                    .font(.caption)
                    .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                    .padding(.horizontal, 2)

                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { tag in
                        let isOn = baustein.wochentage.contains(tag)
                        Button {
                            if isOn {
                                baustein.wochentage.removeAll { $0 == tag }
                            } else {
                                baustein.wochentage.append(tag)
                            }
                        } label: {
                            Text(wochentageNamen[tag - 1])
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    isOn ? AnyShapeStyle(baustein.farbe.color)
                                         : AnyShapeStyle(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)),
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .foregroundStyle(isOn ? .white : (isDark ? .white.opacity(0.6) : .secondary))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Symbol

    private var symbolSection: some View {
        editSection(label: "Icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(symbole, id: \.self) { sym in
                    let isOn = baustein.symbol == sym
                    Button {
                        baustein.symbol = sym
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isOn ? baustein.farbe.color.opacity(0.25) : (isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOn ? baustein.farbe.color : Color.clear, lineWidth: 1.5))
                            Image(systemName: sym)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isOn ? baustein.farbe.color : (isDark ? .white.opacity(0.55) : Color.secondary))
                        }
                        .frame(height: 46)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Farbe

    private var farbeSection: some View {
        editSection(label: "Color") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BausteinFarbe.allCases, id: \.rawValue) { f in
                        let isOn = baustein.farbe == f
                        Button {
                            baustein.farbe = f
                        } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(f.color)
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: isOn ? 2.5 : 0)
                                            .padding(2)
                                    )
                                    .shadow(color: f.color.opacity(isOn ? 0.5 : 0), radius: 6)
                                    .scaleEffect(isOn ? 1.12 : 1.0)
                                    .animation(.spring(response: 0.2), value: isOn)
                                Text(f.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Optionen

    private var optionenSection: some View {
        editSection(label: "Options") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    iconBadge("exclamationmark.circle.fill", color: .orange)
                    Text("High Priority")
                        .font(.system(size: 15))
                    Spacer()
                    Toggle("", isOn: $baustein.isHighPriority).labelsHidden()
                }
                .padding(14)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                onSave(baustein)
                dismiss()
            } label: {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
                    .foregroundStyle(.white)
            }
            .disabled(baustein.titel.trimmingCharacters(in: .whitespaces).isEmpty)

            if isExisting {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Block", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(isDark ? 0.18 : 0.10),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.red)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.red.opacity(0.25), lineWidth: 1))
                }
                .confirmationDialog("Delete Block?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        store.loeschen(baustein)
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("\"\(baustein.titel)\" will be permanently deleted.")
                }
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: Helpers

    private func editSection<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                .padding(.horizontal, 4)
            content()
        }
    }

    private func iconBadge(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(LinearGradient(colors: [color, color.opacity(0.75)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 7))
            .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
    }
}
