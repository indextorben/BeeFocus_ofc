import SwiftUI

struct LangzeitZieleView: View {
    @ObservedObject private var store = LangzeitZieleStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var showAddSheet = false
    @State private var editingZiel: LangzeitZiel? = nil
    @State private var showArchiv = false

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.13).ignoresSafeArea()

                Group {
                    if store.aktiveZiele.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 14) {
                                ForEach(store.aktiveZiele) { ziel in
                                    ZielCard(ziel: ziel, accent: accent) {
                                        editingZiel = ziel
                                    }
                                    .padding(.horizontal, 16)
                                }

                                if !store.archiviertZiele.isEmpty {
                                    Button { showArchiv.toggle() } label: {
                                        HStack {
                                            Text(showArchiv ? "Archiv verbergen" : "Archiv anzeigen (\(store.archiviertZiele.count))")
                                                .font(.system(size: 13))
                                                .foregroundStyle(.white.opacity(0.35))
                                            Spacer()
                                            Image(systemName: showArchiv ? "chevron.up" : "chevron.down")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.top, 4)
                                    }
                                    .buttonStyle(.plain)

                                    if showArchiv {
                                        ForEach(store.archiviertZiele) { ziel in
                                            ZielCard(ziel: ziel, accent: accent, dimmed: true) {
                                                editingZiel = ziel
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("Langzeit-Ziele")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                ZielEditSheet(accent: accent)
            }
            .sheet(item: $editingZiel) { ziel in
                ZielEditSheet(ziel: ziel, accent: accent)
            }
            .preferredColorScheme(.dark)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.aktiveZiele.map { $0.id })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.15))
            Text("Noch keine Ziele")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text("Setze dir große Ziele und verfolge deinen Fortschritt.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button { showAddSheet = true } label: {
                Label("Erstes Ziel erstellen", systemImage: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.3), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}

// MARK: - Ziel Card

struct ZielCard: View {
    let ziel: LangzeitZiel
    let accent: Color
    var dimmed: Bool = false
    let onEdit: () -> Void

    @ObservedObject private var store = LangzeitZieleStore.shared
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ziel.color.opacity(dimmed ? 0.1 : 0.2))
                        .frame(width: 42, height: 42)
                    Image(systemName: ziel.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ziel.color.opacity(dimmed ? 0.4 : 1.0))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ziel.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(dimmed ? .white.opacity(0.4) : .white)
                        .lineLimit(1)
                    if let days = ziel.daysLeft {
                        Text(days == 0 ? "Heute fällig" : "Noch \(days) Tage")
                            .font(.system(size: 11))
                            .foregroundStyle(days < 7 ? .orange : .white.opacity(0.4))
                    } else {
                        Text("\(ziel.meilensteine.filter { $0.isCompleted }.count)/\(ziel.meilensteine.count) Meilensteine")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                // Progress %
                VStack(spacing: 2) {
                    Text("\(Int(ziel.progress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ziel.isCompleted ? .green : ziel.color.opacity(dimmed ? 0.4 : 1.0))
                    Button {
                        withAnimation(.spring(response: 0.3)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(14)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.07)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [ziel.color, ziel.color.opacity(0.5)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * ziel.progress, height: 4)
                        .animation(.spring(response: 0.5), value: ziel.progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 14)
            .padding(.bottom, expanded ? 0 : 14)

            if expanded {
                Divider().background(.white.opacity(0.07)).padding(.horizontal, 14).padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    if !ziel.beschreibung.isEmpty {
                        Text(ziel.beschreibung)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.bottom, 4)
                    }

                    // Milestones
                    if !ziel.meilensteine.isEmpty {
                        ForEach(ziel.meilensteine) { ms in
                            Button {
                                store.toggleMeilenstein(ms.id, in: ziel.id)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: ms.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 16))
                                        .foregroundStyle(ms.isCompleted ? ziel.color : .white.opacity(0.3))
                                    Text(ms.title)
                                        .font(.system(size: 13))
                                        .foregroundStyle(ms.isCompleted ? .white.opacity(0.4) : .white.opacity(0.8))
                                        .strikethrough(ms.isCompleted, color: .white.opacity(0.3))
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Keine Meilensteine")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.25))
                    }

                    HStack(spacing: 10) {
                        Button(action: onEdit) {
                            Label("Bearbeiten", systemImage: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(ziel.color.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            var updated = ziel
                            updated.isArchived = !ziel.isArchived
                            store.save(updated)
                        } label: {
                            Label(ziel.isArchived ? "Wiederherstellen" : "Archivieren",
                                  systemImage: ziel.isArchived ? "arrow.uturn.left" : "archivebox")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
            ziel.isCompleted ? ziel.color.opacity(0.4) : .white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expanded)
    }
}

// MARK: - Ziel Edit Sheet

struct ZielEditSheet: View {
    var ziel: LangzeitZiel? = nil
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LangzeitZieleStore.shared

    @State private var title = ""
    @State private var beschreibung = ""
    @State private var selectedIcon = "target"
    @State private var selectedColor = "purple"
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var meilensteine: [String] = [""]
    @State private var showDeleteConfirm = false

    private let colors = ["purple","blue","green","orange","red","yellow","cyan","teal","pink"]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.13).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Title
                        field("Ziel") {
                            TextField("z.B. Buch schreiben", text: $title)
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Description
                        field("Beschreibung (optional)") {
                            TextField("Warum ist dieses Ziel wichtig?", text: $beschreibung, axis: .vertical)
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                                .lineLimit(3...5)
                                .padding(12)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Icon
                        field("Symbol") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                                ForEach(LangzeitZiel.availableIcons, id: \.self) { icon in
                                    let col = colorValue(selectedColor)
                                    Button { selectedIcon = icon } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 18))
                                            .foregroundStyle(selectedIcon == icon ? col : .white.opacity(0.4))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 44)
                                            .background(selectedIcon == icon ? col.opacity(0.2) : Color.white.opacity(0.06),
                                                        in: RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Color
                        field("Farbe") {
                            HStack(spacing: 10) {
                                ForEach(colors, id: \.self) { c in
                                    let col = colorValue(c)
                                    Button { selectedColor = c } label: {
                                        Circle().fill(col).frame(width: 28, height: 28)
                                            .overlay(Circle().stroke(.white, lineWidth: selectedColor == c ? 2.5 : 0))
                                            .shadow(color: col.opacity(0.5), radius: selectedColor == c ? 4 : 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }

                        // Deadline
                        field("Deadline") {
                            VStack(spacing: 10) {
                                Toggle("Deadline setzen", isOn: $hasDeadline)
                                    .tint(accent)
                                    .foregroundStyle(.white)
                                if hasDeadline {
                                    DatePicker("", selection: $deadline, in: Date()..., displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(accent)
                                }
                            }
                            .padding(12)
                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Milestones
                        field("Meilensteine") {
                            VStack(spacing: 8) {
                                ForEach(meilensteine.indices, id: \.self) { i in
                                    HStack(spacing: 8) {
                                        TextField("Meilenstein \(i + 1)", text: $meilensteine[i])
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white)
                                            .padding(10)
                                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                        if meilensteine.count > 1 {
                                            Button { meilensteine.remove(at: i) } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red.opacity(0.7))
                                            }
                                        }
                                    }
                                }
                                Button { meilensteine.append("") } label: {
                                    Label("Meilenstein hinzufügen", systemImage: "plus")
                                        .font(.system(size: 13))
                                        .foregroundStyle(accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if ziel != nil {
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("Ziel löschen", systemImage: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.red.opacity(0.25), lineWidth: 1))
                            }
                            .confirmationDialog("Ziel löschen?", isPresented: $showDeleteConfirm) {
                                Button("Löschen", role: .destructive) {
                                    if let z = ziel { store.delete(z) }
                                    dismiss()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(ziel == nil ? "Neues Ziel" : "Ziel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(title.isEmpty ? .gray : accent)
                        .disabled(title.isEmpty)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear { prefill() }
        }
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.leading, 2)
            content()
        }
    }

    private func colorValue(_ name: String) -> Color {
        LangzeitZiel(title: "", icon: "", colorName: name).color
    }

    private func prefill() {
        guard let z = ziel else { return }
        title = z.title
        beschreibung = z.beschreibung
        selectedIcon = z.icon
        selectedColor = z.colorName
        hasDeadline = z.deadline != nil
        deadline = z.deadline ?? Date()
        meilensteine = z.meilensteine.map { $0.title }
        if meilensteine.isEmpty { meilensteine = [""] }
    }

    private func save() {
        let filtered = meilensteine.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var updated = ziel ?? LangzeitZiel(title: "")
        updated.title = title.trimmingCharacters(in: .whitespaces)
        updated.beschreibung = beschreibung.trimmingCharacters(in: .whitespaces)
        updated.icon = selectedIcon
        updated.colorName = selectedColor
        updated.deadline = hasDeadline ? deadline : nil

        // Preserve completion state of existing milestones by title match
        let existingMap = Dictionary(uniqueKeysWithValues: (ziel?.meilensteine ?? []).map { ($0.title, $0) })
        updated.meilensteine = filtered.map { t in
            existingMap[t] ?? ZielMeilenstein(title: t)
        }

        store.save(updated)
        dismiss()
    }
}
