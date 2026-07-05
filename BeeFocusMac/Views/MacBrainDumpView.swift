import SwiftUI

struct MacBrainDumpView: View {
    @ObservedObject private var store = MacBrainDumpStore.shared
    @EnvironmentObject var todoStore: MacTodoStore
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var inputText = ""
    @State private var selectedTag: MacBrainDumpTag = .idee
    @State private var filterTag: MacBrainDumpTag? = nil
    @State private var showClearConfirm = false

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var filteredEntries: [MacBrainDumpEintrag] {
        guard let tag = filterTag else { return store.eintraege }
        return store.eintraege.filter { $0.tag == tag }
    }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                inputCard
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                tagFilter
                    .padding(.top, 10)

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredEntries) { entry in
                                MacBrainDumpCard(
                                    entry: entry,
                                    accent: accent,
                                    onConvert: { convertToTodo(entry) },
                                    onDelete: {
                                        withAnimation(.spring(response: 0.3)) {
                                            store.delete(entry)
                                        }
                                    }
                                )
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: filteredEntries.map { $0.id })
                }
            }
        }
        .confirmationDialog("Alle Einträge löschen?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Alle löschen", role: .destructive) {
                withAnimation { store.clearAll() }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Brain Dump")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            if !store.eintraege.isEmpty {
                Button { showClearConfirm = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MacBrainDumpTag.allCases, id: \.self) { tag in
                        Button { selectedTag = tag } label: {
                            HStack(spacing: 4) {
                                Image(systemName: tag.icon)
                                    .font(.system(size: 11))
                                Text(tag.label)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(selectedTag == tag ? tag.color : .white.opacity(0.35))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                selectedTag == tag ? tag.color.opacity(0.2) : Color.white.opacity(0.05),
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(
                                selectedTag == tag ? tag.color.opacity(0.4) : Color.clear,
                                lineWidth: 1
                            ))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                TextField("Gedanken, Ideen, Aufgaben...", text: $inputText, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit { submitEntry() }

                Button(action: submitEntry) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(inputText.isEmpty ? .white.opacity(0.2) : accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
            }
        }
        .padding(12)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Tag Filter

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Alle", count: store.eintraege.count)
                ForEach(MacBrainDumpTag.allCases, id: \.self) { tag in
                    let count = store.eintraege.filter { $0.tag == tag }.count
                    if count > 0 {
                        filterChip(tag, label: tag.label, count: count)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ tag: MacBrainDumpTag?, label: String, count: Int) -> some View {
        Button { withAnimation { filterTag = tag } } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 10))
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .foregroundStyle(filterTag == tag ? .white : .white.opacity(0.4))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(filterTag == tag ? accent.opacity(0.2) : Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(filterTag == tag ? accent.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.12))
            Text("Kopf frei machen")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Schreib alles auf, was dich beschäftigt –\nIdeen, Aufgaben, Fragen.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Actions

    private func submitEntry() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.3)) {
            store.add(text: text, tag: selectedTag)
            inputText = ""
        }
    }

    private func convertToTodo(_ entry: MacBrainDumpEintrag) {
        let todo = MacTodoItem(title: entry.text)
        todoStore.addTodo(todo)
        store.markConverted(entry)
    }
}

// MARK: - Brain Dump Card

struct MacBrainDumpCard: View {
    let entry: MacBrainDumpEintrag
    let accent: Color
    let onConvert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(entry.tag.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: entry.tag.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(entry.tag.color)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.text)
                    .font(.system(size: 13))
                    .foregroundStyle(entry.isConverted ? .white.opacity(0.35) : .white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(entry.tag.label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(entry.tag.color.opacity(0.8))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(entry.tag.color.opacity(0.12), in: Capsule())

                    Text(entry.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.25))

                    Spacer()

                    if entry.isConverted {
                        Label("Aufgabe erstellt", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.green.opacity(0.6))
                    } else if entry.tag == .aufgabe {
                        Button(action: onConvert) {
                            Label("Als Aufgabe", systemImage: "plus.circle")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.07), lineWidth: 1))
        .opacity(entry.isConverted ? 0.7 : 1.0)
    }
}
