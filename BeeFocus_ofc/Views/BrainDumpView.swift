import SwiftUI

struct BrainDumpView: View {
    @ObservedObject private var store = BrainDumpStore.shared
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var inputText = ""
    @State private var selectedTag: BrainDumpTag = .idee
    @State private var filterTag: BrainDumpTag? = nil
    @State private var showClearConfirm = false

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var filteredEntries: [BrainDumpEintrag] {
        guard let tag = filterTag else { return store.eintraege }
        return store.eintraege.filter { $0.tag == tag }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                VStack(spacing: 0) {
                    // Input area
                    inputCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // Tag filter
                    tagFilter
                        .padding(.top, 12)

                    // Entries list
                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredEntries) { entry in
                                    BrainDumpCard(entry: entry, accent: accent) {
                                        convertToTodo(entry)
                                    } onDelete: {
                                        withAnimation(.spring(response: 0.3)) {
                                            store.delete(entry)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                                }
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 40)
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: filteredEntries.map { $0.id })
                    }
                }
            }
            .navigationTitle("Brain Dump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                if !store.eintraege.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showClearConfirm = true } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.6))
                        }
                    }
                }
            }
            .confirmationDialog("Alle Einträge löschen?", isPresented: $showClearConfirm, titleVisibility: .visible) {
                Button("Alles löschen", role: .destructive) {
                    withAnimation { store.clearAll() }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 12) {
            // Tag selector
            HStack(spacing: 8) {
                ForEach(BrainDumpTag.allCases, id: \.self) { tag in
                    Button { selectedTag = tag } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tag.icon)
                                .font(.system(size: 11))
                            Text(tag.label)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(selectedTag == tag ? tag.color : .white.opacity(0.35))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(selectedTag == tag ? tag.color.opacity(0.2) : Color.white.opacity(0.05),
                                    in: Capsule())
                        .overlay(Capsule().stroke(selectedTag == tag ? tag.color.opacity(0.4) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .horizontallyScrollable()

            // Text input + send
            HStack(spacing: 10) {
                TextField("Gedanken, Ideen, Aufgaben...", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    withAnimation(.spring(response: 0.3)) {
                        store.add(text: inputText, tag: selectedTag)
                        inputText = ""
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(inputText.isEmpty ? .white.opacity(0.2) : accent)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Tag Filter

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(nil, label: "Alle", count: store.eintraege.count)
                ForEach(BrainDumpTag.allCases, id: \.self) { tag in
                    let count = store.eintraege.filter { $0.tag == tag }.count
                    if count > 0 {
                        filterChip(tag, label: tag.label, count: count)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func filterChip(_ tag: BrainDumpTag?, label: String, count: Int) -> some View {
        Button { withAnimation { filterTag = tag } } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 11))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.white.opacity(0.1), in: Capsule())
            }
            .foregroundStyle(filterTag == tag ? .white : .white.opacity(0.4))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(filterTag == tag ? accent.opacity(0.2) : Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(filterTag == tag ? accent.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.12))
            Text("Kopf leeren")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text("Schreib alles auf, was dir durch den Kopf geht – Ideen, Aufgaben, Fragen.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func convertToTodo(_ entry: BrainDumpEintrag) {
        let todo = TodoItem(title: entry.text, dueDate: Date())
        todoStore.addTodo(todo)
        store.markConverted(entry)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Brain Dump Card

struct BrainDumpCard: View {
    let entry: BrainDumpEintrag
    let accent: Color
    let onConvert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Tag icon
            ZStack {
                Circle()
                    .fill(entry.tag.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: entry.tag.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(entry.tag.color)
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .font(.system(size: 14))
                    .foregroundStyle(entry.isConverted ? .white.opacity(0.35) : .white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    // Tag label
                    Text(entry.tag.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(entry.tag.color.opacity(0.8))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(entry.tag.color.opacity(0.12), in: Capsule())

                    Text(entry.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))

                    Spacer()

                    if entry.isConverted {
                        Label("Aufgabe erstellt", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green.opacity(0.6))
                    } else if entry.tag == .aufgabe {
                        Button(action: onConvert) {
                            Label("Zu Aufgabe", systemImage: "plus.circle")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.25))
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.07), lineWidth: 1))
        .opacity(entry.isConverted ? 0.7 : 1.0)
    }
}

// MARK: - Scroll Helper

private extension View {
    func horizontallyScrollable() -> some View {
        ScrollView(.horizontal, showsIndicators: false) { self }
    }
}
