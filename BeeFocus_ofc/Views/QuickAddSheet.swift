import SwiftUI

// MARK: - Quick-Add: Natürliche Sprache → Aufgabe

struct QuickAddSheet: View {

    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss

    let themeC1: Color
    let themeC2: Color

    @AppStorage("aiProvider")          private var aiProvider: String = "gemini"
    @AppStorage("geminiSelectedModel") private var geminiModel: String = GeminiService.models[0]
    @AppStorage("openaiSelectedModel") private var openaiModel: String = OpenAIService.models[0]
    @AppStorage("groqSelectedModel")   private var groqModel:   String = GroqService.models[0]
    @AppStorage("darkModeEnabled")     private var darkModeEnabled = false

    @State private var userInput: String = ""
    @State private var isProcessing = false
    @State private var parsedTask: ParsedTask? = nil
    @State private var errorText: String = ""
    @State private var addedSuccessfully = false

    @FocusState private var inputFocused: Bool

    struct ParsedTask {
        var title: String
        var priority: TodoPriority
        var dueDate: Date?
        var category: Category?
        var note: String
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (darkModeEnabled
                    ? Color(red: 0.07, green: 0.07, blue: 0.10)
                    : Color(red: 0.94, green: 0.94, blue: 0.97))
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if addedSuccessfully {
                        successView
                    } else if let task = parsedTask {
                        previewView(task: task)
                    } else {
                        inputView
                    }
                }
            }
            .navigationTitle(String(localized: "quickadd_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Abbrechen")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeC1.opacity(0.2), themeC2.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 8) {
                Text(String(localized: "quickadd_headline"))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "quickadd_sub"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Text input
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    TextField(String(localized: "quickadd_placeholder"), text: $userInput, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...5)
                        .focused($inputFocused)
                        .submitLabel(.done)
                        .onSubmit { if !userInput.trimmingCharacters(in: .whitespaces).isEmpty { Task { await parse() } } }

                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(themeC1)
                    } else {
                        Button {
                            Task { await parse() }
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(
                                    userInput.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? AnyShapeStyle(Color.secondary.opacity(0.4))
                                        : AnyShapeStyle(LinearGradient(colors: [themeC1, themeC2],
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(themeC1.opacity(0.25), lineWidth: 1)
                )

                if !errorText.isEmpty {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 24)

            // Examples
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "quickadd_examples_label"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                ForEach(examplePrompts, id: \.self) { example in
                    Button {
                        userInput = example
                        inputFocused = false
                        Task { await parse() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.caption)
                                .foregroundStyle(themeC1)
                            Text(example)
                                .font(.system(size: 13))
                                .foregroundStyle(darkModeEnabled ? .white.opacity(0.8) : .primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear { inputFocused = true }
    }

    // MARK: - Preview View

    private func previewView(task: ParsedTask) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // Task card
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(themeC1)
                    Text(task.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(darkModeEnabled ? .white : .primary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    priorityBadge(task.priority)

                    if let date = task.dueDate {
                        Label(date.formatted(date: .abbreviated, time: date.formatted(.dateTime.hour().minute()) == "00:00" ? .omitted : .shortened),
                              systemImage: "calendar")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }

                    if let cat = task.category {
                        Label(cat.name, systemImage: "tag")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                if !task.note.isEmpty {
                    Text(task.note)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [themeC1.opacity(0.10), themeC2.opacity(0.05)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(themeC1.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    addTask(task)
                } label: {
                    Label(String(localized: "quickadd_add"), systemImage: "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [themeC1, themeC2],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    parsedTask = nil
                    userInput = ""
                    errorText = ""
                    inputFocused = true
                } label: {
                    Text(String(localized: "quickadd_retry"))
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity))
    }

    // MARK: - Success View

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [themeC1.opacity(0.2), themeC2.opacity(0.1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [themeC1, themeC2],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            Text(String(localized: "quickadd_success"))
                .font(.system(size: 22, weight: .bold))
            Text(String(localized: "quickadd_success_sub"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - AI Parsing

    private func parse() async {
        let trimmed = userInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        errorText = ""
        isProcessing = true
        inputFocused = false

        let categoryNames = todoStore.categories.map { $0.name }.joined(separator: ", ")
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE, d. MMMM yyyy"
        let today = formatter.string(from: Date())

        let prompt = """
        Heute ist \(today).
        Extrahiere aus dem folgenden Text eine strukturierte Aufgabe.
        Vorhandene Kategorien: \(categoryNames.isEmpty ? "keine" : categoryNames)

        Antworte NUR mit diesem JSON-Objekt (kein Markdown, kein Text davor oder danach):
        {"title":"...","priority":"low|medium|high","dueDate":"YYYY-MM-DDTHH:mm:ss" oder null,"category":"Kategoriename aus der Liste" oder null,"note":"" oder kurze Notiz}

        Regeln:
        - title: kurzer, klarer Aufgabentitel
        - priority: "high" wenn dringend/wichtig, "medium" Standard, "low" wenn optional
        - dueDate: Datum aus relativem Text ableiten (morgen, nächste Woche, Freitag, etc.). Uhrzeit wenn angegeben, sonst null für die Zeit.
        - category: nur aus der vorhandenen Liste wählen, sonst null
        - note: nur wenn wirklich zusätzliche Info im Text steckt, sonst leerer String

        Text: \(trimmed)
        """

        var fullResponse = ""
        do {
            let stream = aiStream(prompt: prompt)
            for try await chunk in stream {
                fullResponse += chunk
            }
            let task = try parseJSON(fullResponse)
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    parsedTask = task
                    isProcessing = false
                }
            }
        } catch {
            await MainActor.run {
                errorText = String(localized: "quickadd_error")
                isProcessing = false
            }
        }
    }

    private func aiStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        switch aiProvider {
        case "openai":
            let key = KeychainHelper.load(for: OpenAIService.keychainKey) ?? ""
            return OpenAIService.stream(prompt: prompt, apiKey: key, model: openaiModel)
        case "groq":
            let key = KeychainHelper.load(for: GroqService.keychainKey) ?? ""
            return GroqService.stream(prompt: prompt, apiKey: key, model: groqModel)
        default:
            let key = KeychainHelper.load(for: GeminiService.keychainKey) ?? ""
            return GeminiService.stream(prompt: prompt, apiKey: key)
        }
    }

    private func parseJSON(_ raw: String) throws -> ParsedTask {
        // Extract JSON object from response
        let jsonStr: String
        if let start = raw.range(of: "{"), let end = raw.range(of: "}", options: .backwards) {
            jsonStr = String(raw[start.lowerBound...end.upperBound])
        } else {
            throw ParserError.noJSON
        }

        guard let data = jsonStr.data(using: .utf8),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ParserError.invalidJSON
        }

        let title    = obj["title"] as? String ?? userInput
        let priStr   = obj["priority"] as? String ?? "medium"
        let dateStr  = obj["dueDate"] as? String
        let catName  = obj["category"] as? String
        let note     = obj["note"] as? String ?? ""

        let priority: TodoPriority = priStr == "high" ? .high : priStr == "low" ? .low : .medium

        var dueDate: Date? = nil
        if let ds = dateStr {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dueDate = iso.date(from: ds)
            if dueDate == nil {
                iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
                dueDate = iso.date(from: ds)
            }
        }

        let category = catName.flatMap { name in
            todoStore.categories.first { $0.name.lowercased() == name.lowercased() }
        }

        return ParsedTask(title: title, priority: priority, dueDate: dueDate, category: category, note: note)
    }

    private func addTask(_ task: ParsedTask) {
        let item = TodoItem(
            title: task.title,
            description: task.note,
            dueDate: task.dueDate,
            category: task.category,
            categoryID: task.category?.id,
            priority: task.priority
        )
        todoStore.addTodo(item)

        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            addedSuccessfully = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
        }
    }

    // MARK: - Helpers

    private func priorityBadge(_ priority: TodoPriority) -> some View {
        let (label, color): (String, Color) = switch priority {
        case .high:   (String(localized: "priority_high"),   .red)
        case .medium: (String(localized: "priority_medium"), .orange)
        case .low:    (String(localized: "priority_low"),    .green)
        }
        return Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.15), in: Capsule())
    }

    private var examplePrompts: [String] {
        Locale.current.language.languageCode?.identifier == "en"
            ? ["Call dentist tomorrow afternoon, important",
               "Buy groceries on Friday",
               "Finish project report by end of next week, high priority"]
            : ["Zahnarzt morgen Nachmittag anrufen, wichtig",
               "Einkaufen am Freitag",
               "Projektbericht bis Ende nächster Woche fertig, hohe Priorität"]
    }

    enum ParserError: Error { case noJSON, invalidJSON }
}
