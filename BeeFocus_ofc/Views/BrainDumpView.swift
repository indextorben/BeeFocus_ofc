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

    // AI state
    @AppStorage("aiProvider") private var aiProvider: String = "gemini"
    @AppStorage("openaiSelectedModel") private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel") private var groqModel: String = GroqService.models[0]
    @State private var autoTaggingIDs: Set<UUID> = []
    @State private var reformulatingIDs: Set<UUID> = []
    @State private var showNoKeyAlert = false
    @State private var showAnalyse = false
    @State private var analyseText = ""
    @State private var analyseLoading = false
    @State private var showExtract = false
    @State private var extractedTasks: [String] = []
    @State private var addedExtractTasks: Set<String> = []
    @State private var extractLoading = false
    @State private var showReflexion = false
    @State private var reflexionText = ""
    @State private var reflexionLoading = false

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var filteredEntries: [BrainDumpEintrag] {
        guard let tag = filterTag else { return store.eintraege }
        return store.eintraege.filter { $0.tag == tag }
    }

    private var apiKey: String? {
        switch aiProvider {
        case "openai": return KeychainHelper.load(for: OpenAIService.keychainKey)
        case "groq":   return KeychainHelper.load(for: GroqService.keychainKey)
        default:       return KeychainHelper.load(for: GeminiService.keychainKey)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                VStack(spacing: 0) {
                    inputCard
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    tagFilter
                        .padding(.top, 12)

                    if !store.eintraege.isEmpty {
                        aiActionsRow
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                    }

                    if filteredEntries.isEmpty {
                        emptyState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredEntries) { entry in
                                    BrainDumpCard(
                                        entry: entry,
                                        accent: accent,
                                        isAutoTagging: autoTaggingIDs.contains(entry.id),
                                        isReformulating: reformulatingIDs.contains(entry.id),
                                        onConvert: { convertToTodo(entry) },
                                        onDelete: {
                                            withAnimation(.spring(response: 0.3)) {
                                                store.delete(entry)
                                            }
                                        },
                                        onReformulate: { reformuliereEntry(entry) }
                                    )
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
            .alert("Kein KI-Anbieter", isPresented: $showNoKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Bitte richte einen KI-Anbieter in den Einstellungen ein.")
            }
            .sheet(isPresented: $showAnalyse) { analyseSheet }
            .sheet(isPresented: $showExtract) { extractSheet }
            .sheet(isPresented: $showReflexion) { reflexionSheet }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(spacing: 12) {
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

            HStack(spacing: 10) {
                TextField("Gedanken, Ideen, Aufgaben...", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))

                Button {
                    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    withAnimation(.spring(response: 0.3)) {
                        store.add(text: text, tag: selectedTag)
                        inputText = ""
                    }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if let newEntry = store.eintraege.first {
                        Task { await autoTagEntry(newEntry) }
                    }
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

    // MARK: - AI Actions Row

    private var aiActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                aiChip(label: "Aufräumen", icon: "sparkles") { analyseEntries() }
                aiChip(label: "Aufgaben", icon: "list.clipboard") { extrahiereAufgaben() }
                aiChip(label: "Reflexion", icon: "calendar.badge.clock") { wochenReflexion() }
            }
        }
    }

    private func aiChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
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

    // MARK: - AI Sheets

    private var analyseSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if analyseLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProgressView().tint(accent)
                                    Text("Analysiere deine Gedanken...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                            .padding(.top, 60)
                        } else {
                            Text(analyseText)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(16)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Gedanken aufräumen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { showAnalyse = false }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var extractSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Group {
                    if extractLoading {
                        VStack(spacing: 12) {
                            ProgressView().tint(accent)
                            Text("Suche nach Aufgaben...")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    } else if extractedTasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.15))
                            Text("Keine Aufgaben gefunden")
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(extractedTasks, id: \.self) { task in
                                    let added = addedExtractTasks.contains(task)
                                    HStack(spacing: 12) {
                                        Text(task)
                                            .font(.system(size: 14))
                                            .foregroundStyle(added ? .white.opacity(0.35) : .white.opacity(0.9))
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer()
                                        Button {
                                            guard !added else { return }
                                            let todo = TodoItem(title: task, dueDate: Date())
                                            todoStore.addTodo(todo)
                                            addedExtractTasks.insert(task)
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        } label: {
                                            Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                                .font(.system(size: 22))
                                                .foregroundStyle(added ? .green.opacity(0.6) : accent)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(added)
                                    }
                                    .padding(12)
                                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Aufgaben extrahieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") {
                        showExtract = false
                        addedExtractTasks = []
                    }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var reflexionSheet: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if reflexionLoading {
                            HStack {
                                Spacer()
                                VStack(spacing: 12) {
                                    ProgressView().tint(accent)
                                    Text("Erstelle deine Wochen-Reflexion...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Spacer()
                            }
                            .padding(.top, 60)
                        } else {
                            Text(reflexionText)
                                .font(.system(size: 15))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(16)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Wochen-Reflexion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { showReflexion = false }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - AI Logic

    private func callAI(prompt: String) async throws -> String {
        guard let key = apiKey else { throw URLError(.userAuthenticationRequired) }
        var result = ""
        switch aiProvider {
        case "openai":
            for try await chunk in OpenAIService.stream(prompt: prompt, apiKey: key, model: openaiModel) {
                result += chunk
            }
        case "groq":
            for try await chunk in GroqService.stream(prompt: prompt, apiKey: key, model: groqModel) {
                result += chunk
            }
        default:
            for try await chunk in GeminiService.stream(prompt: prompt, apiKey: key) {
                result += chunk
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Feature 1: Auto-Kategorisierung
    private func autoTagEntry(_ entry: BrainDumpEintrag) async {
        guard apiKey != nil else { return }
        let id = entry.id
        autoTaggingIDs.insert(id)

        let prompt = """
        Klassifiziere diesen Gedanken in genau eine der folgenden Kategorien: idee, aufgabe, frage, sorge, danke.
        Antworte NUR mit dem einen Wort der Kategorie, ohne Erklärung, ohne Punkt.

        Gedanke: "\(entry.text)"
        """

        do {
            let result = try await callAI(prompt: prompt)
            let tagRaw = result.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let newTag = BrainDumpTag(rawValue: tagRaw), newTag != entry.tag {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) {
                        store.updateTag(entry, newTag: newTag)
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        } catch {}

        await MainActor.run { autoTaggingIDs.remove(id) }
    }

    // Feature 2: Gedanken aufräumen
    private func analyseEntries() {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        showAnalyse = true
        analyseLoading = true
        analyseText = ""

        let entries = store.eintraege.map { "[\($0.tag.label)] \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Analysiere diese Brain-Dump-Einträge des Nutzers und gib eine strukturierte Übersicht auf Deutsch:
        - Erkenne Muster und wiederkehrende Themen
        - Identifiziere, was den Nutzer am meisten beschäftigt
        - Gib 2-3 konkrete Empfehlungen
        Nutze maximal 200 Wörter. Keine Markdown-Formatierung.

        Einträge:
        \(entries)
        """

        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run { analyseText = result; analyseLoading = false }
            } catch {
                await MainActor.run {
                    analyseText = "Fehler: \(error.localizedDescription)"
                    analyseLoading = false
                }
            }
        }
    }

    // Feature 3: Aufgaben extrahieren
    private func extrahiereAufgaben() {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        showExtract = true
        extractLoading = true
        extractedTasks = []
        addedExtractTasks = []

        let entries = store.eintraege.filter { !$0.isConverted }
            .map { "- \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Extrahiere aus diesen Brain-Dump-Einträgen alle konkreten, ausführbaren Aufgaben – auch wenn sie als Sorge, Idee oder Frage formuliert sind.
        Formuliere jede Aufgabe als klaren, aktionsfähigen deutschen Satz (z. B. "Arzttermin vereinbaren").
        Gib NUR die Aufgaben aus, eine pro Zeile, ohne Nummerierung, ohne Erklärungen, ohne Leerzeilen.
        Maximal 8 Aufgaben.

        Einträge:
        \(entries)
        """

        Task {
            do {
                let result = try await callAI(prompt: prompt)
                let tasks = result.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                await MainActor.run { extractedTasks = tasks; extractLoading = false }
            } catch {
                await MainActor.run { extractedTasks = []; extractLoading = false }
            }
        }
    }

    // Feature 4: Eintrags-Umformulierung
    private func reformuliereEntry(_ entry: BrainDumpEintrag) {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        let id = entry.id
        reformulatingIDs.insert(id)

        let prompt = """
        Formuliere diesen rohen Gedanken in einen klaren, aktionsfähigen, positiv formulierten deutschen Satz um.
        Antworte NUR mit dem umformulierten Satz, ohne Erklärungen, ohne Anführungszeichen.

        Gedanke: "\(entry.text)"
        """

        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run {
                    if !result.isEmpty {
                        withAnimation(.spring(response: 0.3)) {
                            store.updateText(entry, newText: result)
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    reformulatingIDs.remove(id)
                }
            } catch {
                await MainActor.run { reformulatingIDs.remove(id) }
            }
        }
    }

    // Feature 5: Wochen-Reflexion
    private func wochenReflexion() {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        showReflexion = true
        reflexionLoading = true
        reflexionText = ""

        let cal = Calendar.current
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = store.eintraege.filter { $0.date >= sevenDaysAgo }

        guard !recent.isEmpty else {
            reflexionText = "Keine Einträge der letzten 7 Tage gefunden."
            reflexionLoading = false
            return
        }

        let entries = recent.map { "[\($0.tag.label)] \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Du bist ein einfühlsamer Produktivitäts-Coach. Erstelle eine kurze Wochen-Reflexion auf Deutsch basierend auf diesen Brain-Dump-Einträgen der letzten 7 Tage:
        - Was hat den Nutzer beschäftigt?
        - Was wurde positiv erlebt (Dankbarkeit / Ideen)?
        - Was sollte priorisiert werden?
        - Ein ermutigendes Abschlussstatement
        Maximal 180 Wörter. Keine Markdown-Formatierung.

        Einträge:
        \(entries)
        """

        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run { reflexionText = result; reflexionLoading = false }
            } catch {
                await MainActor.run {
                    reflexionText = "Fehler: \(error.localizedDescription)"
                    reflexionLoading = false
                }
            }
        }
    }

    // MARK: - Actions

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
    let isAutoTagging: Bool
    let isReformulating: Bool
    let onConvert: () -> Void
    let onDelete: () -> Void
    let onReformulate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(entry.tag.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                if isAutoTagging {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(entry.tag.color)
                } else {
                    Image(systemName: entry.tag.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(entry.tag.color)
                }
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.2), value: isAutoTagging)

            VStack(alignment: .leading, spacing: 6) {
                if isReformulating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.6).tint(.white.opacity(0.5))
                        Text("Wird umformuliert...")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .italic()
                    }
                } else {
                    Text(entry.text)
                        .font(.system(size: 14))
                        .foregroundStyle(entry.isConverted ? .white.opacity(0.35) : .white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
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
        .contextMenu {
            if !entry.isConverted && !isReformulating {
                Button { onReformulate() } label: {
                    Label("Umformulieren", systemImage: "sparkles")
                }
            }
        }
    }
}

// MARK: - Scroll Helper

private extension View {
    func horizontallyScrollable() -> some View {
        ScrollView(.horizontal, showsIndicators: false) { self }
    }
}
