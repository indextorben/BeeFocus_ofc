import SwiftUI

struct NotizView: View {
    @StateObject private var store = NotizStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var suchText = ""
    @State private var editNotiz: Notiz? = nil
    @State private var showNeu = false

    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0 }

    private var gefilterte: [Notiz] {
        suchText.isEmpty ? store.sortiert :
        store.sortiert.filter { $0.titel.localizedCaseInsensitiveContains(suchText) || $0.inhalt.localizedCaseInsensitiveContains(suchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.13),
                             Color(red: 0.10, green: 0.06, blue: 0.18)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    if gefilterte.isEmpty {
                        emptyState
                    } else {
                        noteGrid
                    }
                }
            }
            .navigationTitle("Notizen")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
            .toolbar {
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
                    Button {
                        let neu = Notiz()
                        editNotiz = neu
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                }
            }
            .sheet(item: $editNotiz) { n in
                NotizEditorView(notiz: n, accent: accent)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Suchen…", text: $suchText)
                .font(.system(size: 15))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.15))
            Text("Keine Notizen")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            Text("Tippe auf das Stift-Symbol oben,\num eine neue Notiz zu erstellen.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    private var noteGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(gefilterte) { notiz in
                    NotizKarte(notiz: notiz, accent: accent) {
                        editNotiz = notiz
                    } onPin: {
                        store.togglePin(notiz)
                    } onDelete: {
                        store.delete(notiz)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Notiz Karte

private struct NotizKarte: View {
    let notiz: Notiz
    let accent: Color
    let onEdit: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    private let timeFmt: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if notiz.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(notiz.farbe)
                    }
                    Spacer()
                    Circle().fill(notiz.farbe).frame(width: 8, height: 8)
                }
                if !notiz.titel.isEmpty {
                    Text(notiz.titel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                if !notiz.inhalt.isEmpty {
                    Text(notiz.inhalt)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(4)
                }
                Spacer(minLength: 0)
                Text(timeFmt.localizedString(for: notiz.bearbeitetAm, relativeTo: Date()))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(notiz.farbe.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(notiz.farbe.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onPin() } label: {
                Label(notiz.isPinned ? "Pinning entfernen" : "Anpinnen",
                      systemImage: notiz.isPinned ? "pin.slash" : "pin.fill")
            }
            Button { onEdit() } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}

// MARK: - Notiz Editor

struct NotizEditorView: View {
    @State var notiz: Notiz
    let accent: Color
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = NotizStore.shared
    @FocusState private var focusInhalt: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.12).ignoresSafeArea()
                VStack(spacing: 0) {
                    TextField("Titel", text: $notiz.titel)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 8)

                    Divider().opacity(0.15)

                    TextEditor(text: $notiz.inhalt)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 16)
                        .focused($focusInhalt)
                        .frame(maxHeight: .infinity)

                    colorPicker
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        if !notiz.titel.isEmpty || !notiz.inhalt.isEmpty {
                            store.save(notiz)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(notiz.farbe)
                }
            }
        }
        .onAppear { focusInhalt = notiz.inhalt.isEmpty && notiz.titel.isEmpty }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(notizFarben, id: \.name) { item in
                Button {
                    withAnimation(.spring(response: 0.3)) { notiz.farbName = item.name }
                } label: {
                    Circle()
                        .fill(item.farbe)
                        .frame(width: notiz.farbName == item.name ? 28 : 22,
                               height: notiz.farbName == item.name ? 28 : 22)
                        .overlay(
                            notiz.farbName == item.name
                            ? Circle().stroke(.white, lineWidth: 2.5)
                            : nil
                        )
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.25), value: notiz.farbName)
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 14)
        .background(.white.opacity(0.04))
    }
}
