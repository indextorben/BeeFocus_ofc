import SwiftUI

// MARK: - Main View

struct NotizView: View {
    @StateObject private var store = NotizStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("notizViewModus") private var listModus: Bool = false

    @State private var suchText       = ""
    @State private var aktiverOrdner  = "__alle__"
    @State private var sortierung: NotizSortierung = .bearbeitet
    @State private var editNotiz: Notiz? = nil
    @State private var showNeuerOrdner = false
    @State private var neuerOrdnerName = ""
    @State private var showSortMenu    = false

    private var accent:  Color { aktivesThema.isEmpty ? Color(red: 0.6, green: 0.3, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var accent2: Color { aktivesThema.isEmpty ? Color(red: 0.35, green: 0.2, blue: 1.0) : appThemaFarben(aktivesThema).1 }

    private var gefilterte: [Notiz] {
        store.gefiltert(ordner: aktiverOrdner, suche: suchText, sort: sortierung)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.13),
                             Color(red: 0.09, green: 0.05, blue: 0.20)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    ordnerBar
                    Divider().opacity(0.1)
                    if gefilterte.isEmpty { emptyState } else { noteContent }
                }
            }
            .navigationTitle("Notizen")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar { toolbarItems }
            .sheet(item: $editNotiz) { n in
                NotizEditorView(notiz: n, accent: accent, accent2: accent2, ordnerListe: store.ordnerListe)
            }
            .alert("Neuer Ordner", isPresented: $showNeuerOrdner) {
                TextField("Name", text: $neuerOrdnerName)
                Button("Erstellen") { store.addOrdner(neuerOrdnerName); neuerOrdnerName = "" }
                Button("Abbrechen", role: .cancel) { neuerOrdnerName = "" }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 30, height: 30)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        ToolbarItem(placement: .primaryAction) {
            Button { editNotiz = Notiz() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Sortierung") {
                    ForEach(NotizSortierung.allCases) { s in
                        Button { sortierung = s } label: {
                            Label(s.rawValue, systemImage: s.icon)
                            if sortierung == s { Image(systemName: "checkmark") }
                        }
                    }
                }
                Section("Ansicht") {
                    Button { listModus = false } label: { Label("Raster", systemImage: "square.grid.2x2") }
                    Button { listModus = true  } label: { Label("Liste",  systemImage: "list.bullet") }
                }
            } label: {
                Image(systemName: listModus ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(.white.opacity(0.35))
            TextField("Suchen…", text: $suchText)
                .font(.system(size: 15)).foregroundStyle(.white)
            if !suchText.isEmpty {
                Button { suchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.3))
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
    }

    // MARK: - Ordner Bar

    private var ordnerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ordnerChip(id: "__alle__",   label: "Alle",      icon: "tray.full.fill",      count: store.notizen.count)
                ordnerChip(id: "__pinned__", label: "Angepinnt", icon: "pin.fill",             count: store.notizen.filter(\.isPinned).count)
                ForEach(store.ordnerListe, id: \.self) { o in
                    ordnerChipCustom(o)
                }
                Button { showNeuerOrdner = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 12, weight: .semibold))
                        Text("Ordner").font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func ordnerChip(id: String, label: String, icon: String, count: Int) -> some View {
        let active = aktiverOrdner == id
        return Button { withAnimation(.spring(response: 0.3)) { aktiverOrdner = id } } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(active ? 0.3 : 0.1), in: Capsule())
                }
            }
            .foregroundStyle(active ? .white : .white.opacity(0.45))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(
                active ? LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                       : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.07)], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private func ordnerChipCustom(_ name: String) -> some View {
        let active = aktiverOrdner == name
        let cnt    = store.notizen.filter { $0.ordner == name }.count
        return Button { withAnimation(.spring(response: 0.3)) { aktiverOrdner = name } } label: {
            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.system(size: 12, weight: .semibold))
                Text(name).font(.system(size: 13, weight: .semibold))
                if cnt > 0 {
                    Text("\(cnt)").font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.white.opacity(active ? 0.3 : 0.1), in: Capsule())
                }
            }
            .foregroundStyle(active ? .white : .white.opacity(0.45))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(
                active ? LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing)
                       : LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0.07)], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { store.deleteOrdner(name) } label: {
                Label("Ordner löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Content

    private var noteContent: some View {
        ScrollView(showsIndicators: false) {
            Group {
                if listModus {
                    AnyView(listeView)
                } else {
                    AnyView(rasterView)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private var rasterView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(gefilterte) { n in
                NotizKarte(notiz: n, accent: accent) {
                    editNotiz = n
                } onPin: {
                    store.togglePin(n)
                } onDelete: {
                    store.delete(n)
                }
            }
        }
    }

    private var listeView: some View {
        LazyVStack(spacing: 10) {
            ForEach(gefilterte) { n in
                NotizListenZeile(notiz: n, accent: accent) {
                    editNotiz = n
                } onPin: {
                    store.togglePin(n)
                } onDelete: {
                    store.delete(n)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent.opacity(0.15), accent2.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 90, height: 90)
                Image(systemName: aktiverOrdner == "__pinned__" ? "pin.slash" : "note.text")
                    .font(.system(size: 36))
                    .foregroundStyle(accent.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text(suchText.isEmpty ? "Keine Notizen" : "Keine Treffer")
                    .font(.system(size: 18, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                Text(suchText.isEmpty ? "Tippe auf das Stift-Symbol um zu beginnen." : "Versuche einen anderen Suchbegriff.")
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.25)).multilineTextAlignment(.center)
            }
            if suchText.isEmpty {
                Button { editNotiz = Notiz() } label: {
                    Label("Neue Notiz", systemImage: "square.and.pencil")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Notiz Karte (Raster)

private struct NotizKarte: View {
    let notiz: Notiz
    let accent: Color
    let onEdit: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    private let dateFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter(); f.locale = Locale(identifier: "de_DE"); return f
    }()

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                // Top row: pin + checklist badge + color dot
                HStack(spacing: 4) {
                    if notiz.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(notiz.farbe)
                    }
                    if notiz.typ == .checkliste {
                        HStack(spacing: 3) {
                            Image(systemName: "checklist").font(.system(size: 9, weight: .semibold))
                            Text("\(notiz.checkItemsDone)/\(notiz.checkItems.count)")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(notiz.farbe)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(notiz.farbe.opacity(0.15), in: Capsule())
                    }
                    Spacer()
                    Circle().fill(notiz.farbe).frame(width: 7, height: 7)
                }

                // Title
                if !notiz.titel.isEmpty {
                    Text(notiz.titel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                }

                // Content preview
                if notiz.typ == .checkliste {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(notiz.checkItems.prefix(4)) { item in
                            HStack(spacing: 5) {
                                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundStyle(item.isChecked ? notiz.farbe : .white.opacity(0.3))
                                Text(item.text)
                                    .font(.system(size: 11))
                                    .foregroundStyle(item.isChecked ? .white.opacity(0.3) : .white.opacity(0.65))
                                    .strikethrough(item.isChecked, color: .white.opacity(0.25))
                                    .lineLimit(1)
                            }
                        }
                        if notiz.checkItems.count > 4 {
                            Text("+ \(notiz.checkItems.count - 4) weitere")
                                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                        }
                    }
                } else if !notiz.inhalt.isEmpty {
                    Text(notiz.inhalt)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(5)
                }

                Spacer(minLength: 0)
                Text(dateFmt.localizedString(for: notiz.bearbeitetAm, relativeTo: Date()))
                    .font(.system(size: 10)).foregroundStyle(.white.opacity(0.28))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [notiz.farbe.opacity(0.18), notiz.farbe.opacity(0.06)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [notiz.farbe.opacity(0.45), notiz.farbe.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1
                    )
            )
            .shadow(color: notiz.farbe.opacity(0.15), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .contextMenu { contextMenuItems }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button { onEdit() } label: {
            Label("Bearbeiten", systemImage: "pencil")
        }
        Button { onPin() } label: {
            Label(notiz.isPinned ? "Pinning entfernen" : "Anpinnen",
                  systemImage: notiz.isPinned ? "pin.slash" : "pin.fill")
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label("Löschen", systemImage: "trash")
        }
    }
}

// MARK: - Notiz Listenzeile

private struct NotizListenZeile: View {
    let notiz: Notiz
    let accent: Color
    let onEdit: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                // Color bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(notiz.farbe)
                    .frame(width: 4, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if notiz.isPinned {
                            Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(notiz.farbe)
                        }
                        Text(notiz.titel.isEmpty ? "Ohne Titel" : notiz.titel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                        Spacer()
                        Text(dateFmt.string(from: notiz.bearbeitetAm))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.28))
                    }
                    HStack(spacing: 6) {
                        if notiz.typ == .checkliste {
                            Image(systemName: "checklist").font(.system(size: 11)).foregroundStyle(notiz.farbe)
                            Text("\(notiz.checkItemsDone)/\(notiz.checkItems.count) erledigt")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                        } else {
                            Text(notiz.inhalt.isEmpty ? "Leer" : notiz.inhalt)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(notiz.farbe.opacity(0.06))
            }
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(notiz.farbe.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Löschen", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onPin) {
                Label(notiz.isPinned ? "Lösen" : "Anpinnen",
                      systemImage: notiz.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(notiz.farbe)
        }
    }
}

// MARK: - Editor

struct NotizEditorView: View {
    @State var notiz: Notiz
    let accent:     Color
    let accent2:    Color
    let ordnerListe: [String]

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotizStore.shared
    @FocusState private var fokusInhalt: Bool
    @FocusState private var fokusTitel: Bool
    @State private var showOrdnerPicker = false
    @State private var showDeleteAlert  = false
    @State private var neuesCheckItem   = ""
    @State private var showFind         = false
    @State private var checkSuche       = ""

    private var kannSpeichern: Bool {
        !notiz.titel.isEmpty || !notiz.inhalt.isEmpty || !notiz.checkItems.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.13),
                             Color(red: 0.09, green: 0.05, blue: 0.20)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    titelField
                    metaRow
                    Divider().opacity(0.12)
                    if notiz.typ == .checkliste {
                        checklisteContent
                    } else {
                        textContent
                    }
                    bottomBar
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { editorToolbar }
            .alert("Notiz löschen?", isPresented: $showDeleteAlert) {
                Button("Löschen", role: .destructive) { store.delete(notiz); dismiss() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aktion kann nicht rückgängig gemacht werden.")
            }
        }
        .onAppear {
            if notiz.typ == .text && notiz.inhalt.isEmpty && notiz.titel.isEmpty {
                fokusTitel = true
            }
        }
    }

    // MARK: - Titel

    private var titelField: some View {
        TextField("Titel", text: $notiz.titel, axis: .vertical)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(.white)
            .focused($fokusTitel)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 10)
    }

    // MARK: - Meta Row

    private var metaRow: some View {
        HStack(spacing: 10) {
            // Date
            HStack(spacing: 4) {
                Image(systemName: "clock").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                Text(shortDate(notiz.bearbeitetAm)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
            }

            // Word count (text mode)
            if notiz.typ == .text && !notiz.inhalt.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
                    Text("\(notiz.wortanzahl) Wörter").font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                }
            }

            // Folder
            Button { showOrdnerPicker = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: notiz.ordner.isEmpty ? "tray" : "folder.fill")
                        .font(.system(size: 11))
                    Text(notiz.ordner.isEmpty ? "Ablage" : notiz.ordner)
                        .font(.system(size: 12))
                }
                .foregroundStyle(notiz.farbe.opacity(0.85))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(notiz.farbe.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .confirmationDialog("Ordner wählen", isPresented: $showOrdnerPicker) {
                Button("Alle Notizen") { notiz.ordner = "" }
                ForEach(ordnerListe, id: \.self) { o in
                    Button(o) { notiz.ordner = o }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Text Content

    private var textContent: some View {
        TextEditor(text: $notiz.inhalt)
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.88))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 16)
            .focused($fokusInhalt)
            .findNavigator(isPresented: $showFind)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            formatBtn("**Fett**",       icon: "bold",          insert: "****",       cursorOffset: 2)
                            formatBtn("*Kursiv*",       icon: "italic",        insert: "**",         cursorOffset: 1)
                            formatBtn("# Titel",        icon: "h.square",      insert: "\n# ",       cursorOffset: 0)
                            formatBtn("## Untertitel",  icon: "h.square.fill", insert: "\n## ",      cursorOffset: 0)
                            formatBtn("• Punkt",        icon: "list.bullet",   insert: "\n• ",       cursorOffset: 0)
                            formatBtn("→ Einzug",       icon: "arrow.right",   insert: "\n  ",       cursorOffset: 0)
                            formatBtn("— Trennlinie",   icon: "minus",         insert: "\n---\n",    cursorOffset: 0)
                            Divider().frame(height: 24).padding(.horizontal, 4)
                            Button {
                                withAnimation { notiz.typ = .checkliste }
                            } label: {
                                Label("Checkliste", systemImage: "checklist")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)
                    }
                    Spacer()
                    Button("Fertig") { fokusInhalt = false; fokusTitel = false }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                }
            }
    }

    private func formatBtn(_ tooltip: String, icon: String, insert: String, cursorOffset: Int) -> some View {
        Button {
            notiz.inhalt += insert
            fokusInhalt = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 36, height: 34)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Checklist Content

    private var checklisteContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Search bar (only visible when showFind)
                if showFind {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13)).foregroundStyle(.white.opacity(0.4))
                        TextField("In Checkliste suchen…", text: $checkSuche)
                            .font(.system(size: 15)).foregroundStyle(.white)
                        if !checkSuche.isEmpty {
                            Button { checkSuche = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.3))
                            }.buttonStyle(.plain)
                        }
                        let matchCount = notiz.checkItems.filter { $0.text.localizedCaseInsensitiveContains(checkSuche) }.count
                        if !checkSuche.isEmpty {
                            Text("\(matchCount) Treffer")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(matchCount > 0 ? notiz.farbe : .red.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Open items
                let filteredOpen = notiz.checkItems.filter { !$0.isChecked && (checkSuche.isEmpty || $0.text.localizedCaseInsensitiveContains(checkSuche)) }
                let filteredDone = notiz.checkItems.filter {  $0.isChecked && (checkSuche.isEmpty || $0.text.localizedCaseInsensitiveContains(checkSuche)) }
                let open   = checkSuche.isEmpty ? notiz.checkItems.filter { !$0.isChecked } : filteredOpen
                let done   = checkSuche.isEmpty ? notiz.checkItems.filter {  $0.isChecked } : filteredDone

                ForEach(open) { item in checkRow(item) }

                // New item input
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(accent)
                    TextField("Neuer Punkt…", text: $neuesCheckItem)
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .submitLabel(.done)
                        .onSubmit { appendCheckItem() }
                }
                .padding(.horizontal, 20).padding(.vertical, 13)

                if !done.isEmpty {
                    Divider().opacity(0.1).padding(.horizontal, 20).padding(.vertical, 8)
                    HStack {
                        Text("\(done.count) Erledigt")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.3))
                        Spacer()
                        Button {
                            withAnimation { notiz.checkItems.removeAll { $0.isChecked } }
                        } label: {
                            Text("Löschen")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    ForEach(done) { item in checkRow(item) }
                }

                Spacer(minLength: 60)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button {
                    withAnimation { notiz.typ = .text }
                } label: {
                    Label("Text-Modus", systemImage: "doc.text")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("Fertig") { fokusInhalt = false; fokusTitel = false }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
            }
        }
    }

    private func checkRow(_ item: CheckItem) -> some View {
        HStack(spacing: 12) {
            Button {
                if let idx = notiz.checkItems.firstIndex(where: { $0.id == item.id }) {
                    withAnimation(.spring(response: 0.3)) { notiz.checkItems[idx].isChecked.toggle() }
                }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isChecked ? notiz.farbe : .white.opacity(0.3))
                    .animation(.spring(response: 0.3), value: item.isChecked)
            }
            .buttonStyle(.plain)

            if let idx = notiz.checkItems.firstIndex(where: { $0.id == item.id }) {
                TextField("", text: Binding(
                    get: { notiz.checkItems[idx].text },
                    set: { notiz.checkItems[idx].text = $0 }
                ))
                .font(.system(size: 16))
                .foregroundStyle(item.isChecked ? .white.opacity(0.35) : .white.opacity(0.88))
                .strikethrough(item.isChecked, color: .white.opacity(0.25))
                .submitLabel(.done)
                .onSubmit { appendCheckItem() }
            }

            Spacer()

            Button {
                withAnimation { notiz.checkItems.removeAll { $0.id == item.id } }
            } label: {
                Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundStyle(.red.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
    }

    private func appendCheckItem() {
        let t = neuesCheckItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        withAnimation { notiz.checkItems.append(CheckItem(text: t)) }
        neuesCheckItem = ""
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.1)
            HStack(spacing: 0) {
                // Type toggle
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        notiz.typ = notiz.typ == .text ? .checkliste : .text
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: notiz.typ == .checkliste ? "doc.text" : "checklist")
                            .font(.system(size: 16, weight: .semibold))
                        Text(notiz.typ == .checkliste ? "Text" : "Liste")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                Divider().frame(height: 30).opacity(0.15)

                // Color picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(notizFarben, id: \.name) { item in
                            Button {
                                withAnimation(.spring(response: 0.25)) { notiz.farbName = item.name }
                            } label: {
                                Circle()
                                    .fill(item.farbe)
                                    .frame(width: notiz.farbName == item.name ? 26 : 20,
                                           height: notiz.farbName == item.name ? 26 : 20)
                                    .overlay(notiz.farbName == item.name ? Circle().stroke(.white, lineWidth: 2.5) : nil)
                                    .shadow(color: item.farbe.opacity(0.4), radius: 4)
                            }
                            .buttonStyle(.plain)
                            .animation(.spring(response: 0.25), value: notiz.farbName)
                        }
                    }
                    .padding(.horizontal, 12)
                }

                Divider().frame(height: 30).opacity(0.15)

                // Delete
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").font(.system(size: 16)).foregroundStyle(.red.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Abbrechen") { dismiss() }
                .foregroundStyle(.white.opacity(0.55))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                fokusInhalt = false
                fokusTitel  = false
                withAnimation { showFind.toggle(); if notiz.typ == .checkliste { checkSuche = "" } }
            } label: {
                Image(systemName: showFind ? "magnifyingglass.circle.fill" : "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(showFind ? notiz.farbe : .white.opacity(0.55))
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Fertig") {
                if kannSpeichern { store.save(notiz) }
                dismiss()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(notiz.farbe)
        }
    }

    // MARK: - Helper

    private func shortDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.timeStyle = .short; f.dateStyle = .none
            return "Heute, \(f.string(from: date))"
        }
        let f = DateFormatter(); f.locale = Locale(identifier: "de_DE"); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }
}
