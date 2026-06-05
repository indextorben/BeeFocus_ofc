import SwiftUI

struct KIEinstellungenView: View {

    // MARK: - App Storage

    @AppStorage("darkModeEnabled")       private var darkModeEnabled = false
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("aiProvider")            private var aiProvider: String = "gemini"
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("floatingAIEnabled")     private var floatingAIEnabled: Bool = true
    @AppStorage("focusCoachEnabled")     private var focusCoachEnabled: Bool = true
    @AppStorage("aiAutoSpeak")           private var aiAutoSpeak: Bool = false

    // Gemini
    @State private var geminiKey: String = KeychainHelper.load(for: GeminiService.keychainKey) ?? ""
    @State private var geminiKeyVisible   = false
    @State private var geminiValidating   = false
    @State private var geminiKeyStatus: KeyStatus = .unknown
    @AppStorage("geminiSelectedModel") private var geminiModel: String = GeminiService.models[0]

    // OpenAI
    @State private var openaiKey: String = KeychainHelper.load(for: OpenAIService.keychainKey) ?? ""
    @State private var openaiKeyVisible   = false
    @State private var openaiValidating   = false
    @State private var openaiKeyStatus: KeyStatus = .unknown
    @AppStorage("openaiSelectedModel") private var openaiModel: String = OpenAIService.models[0]

    // Groq
    @State private var groqKey: String = KeychainHelper.load(for: GroqService.keychainKey) ?? ""
    @State private var groqKeyVisible   = false
    @State private var groqValidating   = false
    @State private var groqKeyStatus: KeyStatus = .unknown
    @AppStorage("groqSelectedModel") private var groqModel: String = GroqService.models[0]

    // Test
    @State private var testResponse: String = ""
    @State private var testLoading  = false

    enum KeyStatus { case unknown, valid, invalid }

    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }
    private var accentColor: Color { aktivesThema.isEmpty ? .purple : themeC1 }

    // MARK: - Body

    var body: some View {
        ZStack {
            background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // General
                    sectionCard(header: localizer.localizedString(forKey: "ki_section_general"), icon: "gearshape.fill", color: accentColor) {
                        toggleRow(icon: "sparkles", color: accentColor,
                                  label: localizer.localizedString(forKey: "ki_floating_button"),
                                  isOn: $floatingAIEnabled)
                        divider()
                        toggleRow(icon: "brain.head.profile", color: .indigo,
                                  label: localizer.localizedString(forKey: "ki_focus_coach"),
                                  isOn: $focusCoachEnabled)
                        divider()
                        toggleRow(icon: "speaker.wave.2.fill", color: .teal,
                                  label: localizer.localizedString(forKey: "ki_auto_speak"),
                                  isOn: $aiAutoSpeak)
                        divider()
                        providerPicker
                    }

                    // Gemini
                    sectionCard(header: "Gemini", icon: "sparkles", color: .purple) {
                        geminiContent
                    }

                    // OpenAI
                    sectionCard(header: "OpenAI", icon: "cpu.fill", color: .green) {
                        openaiContent
                    }

                    // Groq
                    sectionCard(header: "Groq", icon: "bolt.fill", color: .orange) {
                        groqContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "ki_settings_title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Provider Picker

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizer.localizedString(forKey: "ki_active_provider"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            Picker("", selection: $aiProvider) {
                Text("Gemini").tag("gemini")
                Text("OpenAI").tag("openai")
                Text("Groq").tag("groq")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Gemini

    private var geminiContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(destination: GeminiKeyGuideView()) {
                guideRow(icon: "sparkles", color: .purple,
                         title: localizer.localizedString(forKey: "gemini_guide_title"),
                         sub: localizer.localizedString(forKey: "ki_gemini_info_short"))
            }
            .buttonStyle(.plain)
            divider()
            keySection(key: $geminiKey, visible: $geminiKeyVisible,
                       validating: $geminiValidating, status: $geminiKeyStatus,
                       placeholder: "AIza...", keychainKey: GeminiService.keychainKey,
                       accentColor: .purple,
                       validate: { await GeminiService.validate(apiKey: $0) })
            if !geminiKey.isEmpty {
                divider()
                modelPicker(selection: $geminiModel, models: GeminiService.models)
                divider()
                testSection(key: geminiKey) { key in
                    let stream = GeminiService.stream(prompt: testPrompt, apiKey: key)
                    for try await chunk in stream { testResponse += chunk }
                }
            }
        }
    }

    // MARK: - OpenAI

    private var openaiContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                guideRow(icon: "cpu.fill", color: .green,
                         title: "OpenAI API Key",
                         sub: localizer.localizedString(forKey: "openai_key_info"))
            }
            .buttonStyle(.plain)
            divider()
            keySection(key: $openaiKey, visible: $openaiKeyVisible,
                       validating: $openaiValidating, status: $openaiKeyStatus,
                       placeholder: "sk-...", keychainKey: OpenAIService.keychainKey,
                       accentColor: .green,
                       validate: { await OpenAIService.validate(apiKey: $0) })
            if !openaiKey.isEmpty {
                divider()
                modelPicker(selection: $openaiModel, models: OpenAIService.models)
                divider()
                testSection(key: openaiKey) { key in
                    let stream = OpenAIService.stream(prompt: testPrompt, apiKey: key, model: openaiModel)
                    for try await chunk in stream { testResponse += chunk }
                }
            }
        }
    }

    // MARK: - Groq

    private var groqContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Link(destination: URL(string: "https://console.groq.com/keys")!) {
                guideRow(icon: "bolt.fill", color: .orange,
                         title: "Groq API Key",
                         sub: localizer.localizedString(forKey: "groq_setup_desc"))
            }
            .buttonStyle(.plain)
            divider()
            keySection(key: $groqKey, visible: $groqKeyVisible,
                       validating: $groqValidating, status: $groqKeyStatus,
                       placeholder: "gsk_...", keychainKey: GroqService.keychainKey,
                       accentColor: .orange,
                       validate: { await GroqService.validate(apiKey: $0) })
            if !groqKey.isEmpty {
                divider()
                modelPicker(selection: $groqModel, models: GroqService.models)
                divider()
                testSection(key: groqKey) { key in
                    let stream = GroqService.stream(prompt: testPrompt, apiKey: key, model: groqModel)
                    for try await chunk in stream { testResponse += chunk }
                }
            }
        }
    }

    // MARK: - Shared Sub-Views

    private func guideRow(icon: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: 12) {
            badge(icon: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16)).foregroundStyle(darkModeEnabled ? .white : .primary)
                Text(sub).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
    }

    private func keySection(
        key: Binding<String>, visible: Binding<Bool>,
        validating: Binding<Bool>, status: Binding<KeyStatus>,
        placeholder: String, keychainKey: String, accentColor: Color,
        validate: @escaping (String) async -> Bool
    ) -> some View {
        Group {
            if key.wrappedValue.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localizer.localizedString(forKey: "ki_api_key_label"))
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    HStack(spacing: 8) {
                        Group {
                            if visible.wrappedValue {
                                TextField(placeholder, text: key)
                            } else {
                                SecureField(placeholder, text: key)
                            }
                        }
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                        Button { visible.wrappedValue.toggle() } label: {
                            Image(systemName: visible.wrappedValue ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)

                    HStack {
                        Spacer()
                        Button(localizer.localizedString(forKey: "ki_key_save")) {
                            let trimmed = key.wrappedValue.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            KeychainHelper.save(trimmed, for: keychainKey)
                            validating.wrappedValue = true
                            Task {
                                let ok = await validate(trimmed)
                                validating.wrappedValue = false
                                status.wrappedValue = ok ? .valid : .invalid
                            }
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(
                            key.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary.opacity(0.4) : accentColor,
                            in: Capsule()
                        )
                        .buttonStyle(.plain)
                        .disabled(key.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty || validating.wrappedValue)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(maskedKey(key.wrappedValue))
                        .font(.system(size: 14, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    if validating.wrappedValue {
                        ProgressView().scaleEffect(0.8)
                    } else if status.wrappedValue == .valid {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if status.wrappedValue == .invalid {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                    Button(localizer.localizedString(forKey: "ki_key_delete")) {
                        key.wrappedValue = ""
                        status.wrappedValue = .unknown
                        KeychainHelper.delete(for: keychainKey)
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.red).buttonStyle(.plain)
                }
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
    }

    private func modelPicker(selection: Binding<String>, models: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localizer.localizedString(forKey: "ki_model_label"))
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            Picker("", selection: selection) {
                ForEach(models, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).padding(.horizontal, 12)
        }
        .padding(.vertical, 6)
    }

    private func testSection(key: String, run: @escaping (String) async throws -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard !testLoading else { return }
                testResponse = ""
                testLoading = true
                Task {
                    do { try await run(key) } catch { testResponse = error.localizedDescription }
                    testLoading = false
                }
            } label: {
                HStack(spacing: 8) {
                    if testLoading { ProgressView().scaleEffect(0.75) }
                    Text(testLoading ? localizer.localizedString(forKey: "ki_analyzing") : localizer.localizedString(forKey: "ki_test_button"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if !testResponse.isEmpty {
                Text(testResponse)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Design Helpers

    private func sectionCard<Content: View>(header: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accentColor.opacity(0.85))
                Text(header.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            glassCard { content() }
        }
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(darkModeEnabled ? 0.14 : 0.09),
                                 themeC2.opacity(darkModeEnabled ? 0.07 : 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .opacity(aktivesThema.isEmpty ? 0 : 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: aktivesThema.isEmpty
                                ? [Color.white.opacity(darkModeEnabled ? 0.12 : 0.60),
                                   Color.white.opacity(darkModeEnabled ? 0.04 : 0.20)]
                                : [themeC1.opacity(darkModeEnabled ? 0.50 : 0.32),
                                   themeC2.opacity(darkModeEnabled ? 0.22 : 0.16)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(darkModeEnabled ? 0.25 : 0.08), radius: 16, x: 0, y: 6)
    }

    private func toggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            badge(icon: icon, color: color)
            Text(label).font(.system(size: 16))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func badge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                LinearGradient(colors: [color, color.opacity(0.75)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private func divider() -> some View {
        Divider().padding(.horizontal, 16)
    }

    // MARK: - Background

    private var background: some View {
        Group {
            if aktivesThema.isEmpty {
                (darkModeEnabled
                    ? Color(red: 0.07, green: 0.07, blue: 0.10)
                    : Color(red: 0.94, green: 0.94, blue: 0.97))
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [themeC1.opacity(darkModeEnabled ? 0.25 : 0.15),
                             themeC2.opacity(darkModeEnabled ? 0.12 : 0.07)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Helpers

    private func maskedKey(_ key: String) -> String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return String(key.prefix(4)) + String(repeating: "•", count: 8) + String(key.suffix(4))
    }

    private var testPrompt: String {
        "Give me one short, motivating productivity tip in 2 sentences."
    }
}
