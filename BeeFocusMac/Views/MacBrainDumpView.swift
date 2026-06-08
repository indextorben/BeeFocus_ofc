import SwiftUI

struct MacBrainDumpView: View {
    @ObservedObject private var store = MacBrainDumpStore.shared
    @EnvironmentObject var todoStore: MacTodoStore
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("mac_ai_provider") private var aiProviderRaw: String = MacAIProvider.groq.rawValue

    @State private var inputText = ""
    @State private var selectedTag: MacBrainDumpTag = .idee
    @State private var filterTag: MacBrainDumpTag? = nil
    @State private var showClearConfirm = false

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

    private var aiProvider: MacAIProvider { MacAIProvider(rawValue: aiProviderRaw) ?? .groq }

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    private var filteredEntries: [MacBrainDumpEintrag] {
        guard let tag = filterTag else { return store.eintraege }
        return store.eintraege.filter { $0.tag == tag }
    }

    private var apiKey: String? {
        MacKeychain.load(for: aiProvider.keychainKey)
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

                if !store.eintraege.isEmpty {
                    aiActionsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredEntries) { entry in
                                MacBrainDumpCard(
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
        .alert("Kein KI-Anbieter", isPresented: $showNoKeyAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Bitte richte einen KI-Anbieter in den Einstellungen ein.")
        }
        .sheet(isPresented: $showAnalyse) { analyseSheet }
        .sheet(isPresented: $showExtract) { extractSheet }
        .sheet(isPresented: $showReflexion) { reflexionSheet }
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

    // MARK: - AI Actions Row

    private var aiActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                aiChip(label: "Sortieren", icon: "sparkles") { analyseEntries() }
                aiChip(label: "Aufgaben", icon: "list.clipboard") { extrahiereAufgaben() }
                aiChip(label: "Reflexion", icon: "calendar.badge.clock") { wochenReflexion() }
            }
        }
    }

    private func aiChip(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 1))
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

    // MARK: - AI Sheets

    private var analyseSheet: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Gedanken sortieren") { showAnalyse = false }
            Divider().overlay(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if analyseLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView().tint(accent)
                                Text("Gedanken werden analysiert...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else if !analyseText.isEmpty {
                        Text(analyseText)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(14)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 400)
        .background(Color.black)
    }

    private var extractSheet: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Aufgaben extrahieren") {
                showExtract = false
                addedExtractTasks = []
            }
            Divider().overlay(Color.white.opacity(0.08))
            Group {
                if extractLoading {
                    VStack(spacing: 10) {
                        ProgressView().tint(accent)
                        Text("Suche nach Aufgaben...")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if extractedTasks.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.15))
                        Text("Keine Aufgaben gefunden")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(extractedTasks, id: \.self) { task in
                                let added = addedExtractTasks.contains(task)
                                HStack(spacing: 10) {
                                    Text(task)
                                        .font(.system(size: 13))
                                        .foregroundStyle(added ? .white.opacity(0.35) : .white.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer()
                                    Button {
                                        guard !added else { return }
                                        let todo = MacTodoItem(title: task)
                                        todoStore.addTodo(todo)
                                        addedExtractTasks.insert(task)
                                    } label: {
                                        Image(systemName: added ? "checkmark.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(added ? .green.opacity(0.6) : accent)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(added)
                                }
                                .padding(10)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
        .frame(width: 380, height: 420)
        .background(Color.black)
    }

    private var reflexionSheet: some View {
        VStack(spacing: 0) {
            sheetHeader(title: "Wochenreflexion") { showReflexion = false }
            Divider().overlay(Color.white.opacity(0.08))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if reflexionLoading {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView().tint(accent)
                                Text("Wochenreflexion wird erstellt...")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(.top, 40)
                    } else {
                        Text(reflexionText)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(14)
                            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 380, height: 400)
        .background(Color.black)
    }

    private func sheetHeader(title: String, onClose: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button("Fertig", action: onClose)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black)
    }

    // MARK: - Actions

    private func submitEntry() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.spring(response: 0.3)) {
            store.add(text: text, tag: selectedTag)
            inputText = ""
        }
        if let newEntry = store.eintraege.first {
            Task { await autoTagEntry(newEntry) }
        }
    }

    private func convertToTodo(_ entry: MacBrainDumpEintrag) {
        let todo = MacTodoItem(title: entry.text)
        todoStore.addTodo(todo)
        store.markConverted(entry)
    }

    // MARK: - AI Logic

    private func callAI(prompt: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw MacAIError.noKey
        }
        let body: [String: Any] = [
            "model": aiProvider.defaultModel,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 400,
            "temperature": 0.4
        ]
        guard let url = URL(string: aiProvider.apiURL),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw MacAIError.badRequest
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw MacAIError.httpError(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw MacAIError.parseError
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func autoTagEntry(_ entry: MacBrainDumpEintrag) async {
        guard apiKey != nil else { return }
        let id = entry.id
        await MainActor.run { autoTaggingIDs.insert(id) }
        let prompt = """
        Classify this thought into exactly one of the following categories: idee, aufgabe, frage, sorge, danke.
        Reply ONLY with the single category word, no explanation, no period.

        Thought: "\(entry.text)"
        """
        do {
            let result = try await callAI(prompt: prompt)
            let tagRaw = result.lowercased().trimmingCharacters(in: .punctuationCharacters)
            if let newTag = MacBrainDumpTag(rawValue: tagRaw), newTag != entry.tag {
                await MainActor.run {
                    withAnimation(.spring(response: 0.4)) { store.updateTag(entry, newTag: newTag) }
                }
            }
        } catch {}
        await MainActor.run { autoTaggingIDs.remove(id) }
    }

    private func analyseEntries() {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        showAnalyse = true
        analyseLoading = true
        analyseText = ""
        let entries = store.eintraege.map { "[\($0.tag.label)] \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Analyze these brain dump entries and provide a structured overview:
        - Identify patterns and recurring themes
        - Identify what is occupying the user the most
        - Give 2-3 concrete recommendations
        Maximum 200 words. No Markdown formatting.

        Entries:
        \(entries)
        """
        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run { analyseText = result; analyseLoading = false }
            } catch {
                await MainActor.run { analyseText = "Fehler: \(error.localizedDescription)"; analyseLoading = false }
            }
        }
    }

    private func extrahiereAufgaben() {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        showExtract = true
        extractLoading = true
        extractedTasks = []
        addedExtractTasks = []
        let entries = store.eintraege.filter { !$0.isConverted }
            .map { "- \($0.text)" }.joined(separator: "\n")
        let prompt = """
        Extract all concrete, actionable tasks from these brain dump entries – even if formulated as a worry, idea or question.
        Phrase each task as a clear, actionable sentence (e.g. "Schedule doctor's appointment").
        Output ONLY the tasks, one per line, no numbering, no explanations, no blank lines.
        Maximum 8 tasks.

        Entries:
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

    private func reformuliereEntry(_ entry: MacBrainDumpEintrag) {
        guard apiKey != nil else { showNoKeyAlert = true; return }
        let id = entry.id
        reformulatingIDs.insert(id)
        let prompt = """
        Rephrase this raw thought into a clear, actionable, positively worded sentence.
        Reply ONLY with the rephrased sentence, no explanations, no quotation marks.

        Thought: "\(entry.text)"
        """
        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run {
                    if !result.isEmpty {
                        withAnimation(.spring(response: 0.3)) { store.updateText(entry, newText: result) }
                    }
                    reformulatingIDs.remove(id)
                }
            } catch {
                await MainActor.run { reformulatingIDs.remove(id) }
            }
        }
    }

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
        You are a compassionate productivity coach. Create a short weekly reflection based on these brain dump entries from the last 7 days:
        - What was on the user's mind?
        - What was experienced positively (gratitude / ideas)?
        - What should be prioritized?
        - An encouraging closing statement
        Maximum 180 words. No Markdown formatting.

        Entries:
        \(entries)
        """
        Task {
            do {
                let result = try await callAI(prompt: prompt)
                await MainActor.run { reflexionText = result; reflexionLoading = false }
            } catch {
                await MainActor.run { reflexionText = "Fehler: \(error.localizedDescription)"; reflexionLoading = false }
            }
        }
    }
}

// MARK: - Brain Dump Card

struct MacBrainDumpCard: View {
    let entry: MacBrainDumpEintrag
    let accent: Color
    let isAutoTagging: Bool
    let isReformulating: Bool
    let onConvert: () -> Void
    let onDelete: () -> Void
    let onReformulate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(entry.tag.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                if isAutoTagging {
                    ProgressView().scaleEffect(0.6).tint(entry.tag.color)
                } else {
                    Image(systemName: entry.tag.icon)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.tag.color)
                }
            }
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.2), value: isAutoTagging)

            VStack(alignment: .leading, spacing: 5) {
                if isReformulating {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.55).tint(.white.opacity(0.5))
                        Text("Wird umformuliert...")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                            .italic()
                    }
                } else {
                    Text(entry.text)
                        .font(.system(size: 13))
                        .foregroundStyle(entry.isConverted ? .white.opacity(0.35) : .white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

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
        .contextMenu {
            if !entry.isConverted && !isReformulating {
                Button { onReformulate() } label: {
                    Label("Umformulieren", systemImage: "sparkles")
                }
            }
        }
    }
}
