import SwiftUI
import UserNotifications

// MARK: - Onboarding Flow (First Launch)

struct OnboardingView: View {
    var onComplete: () -> Void

    @ObservedObject private var localizer = LocalizationManager.shared
    @Environment(\.colorScheme) private var colorScheme

    // Step management
    @State private var step: Int = 0
    private let totalSteps = 4

    // Language step
    @State private var selectedLang: String = {
        let code = Locale.current.language.languageCode?.identifier ?? "de"
        return code == "en" ? "Englisch" : "Deutsch"
    }()

    // KI step
    @State private var kiProvider: String = "groq"   // default to free option
    @State private var kiKey: String = ""
    @State private var kiKeyVisible: Bool = false
    @State private var kiSaving: Bool = false
    @State private var kiStatus: KIOnboardStatus = .empty
    @State private var showGeminiGuide: Bool = false

    // Notifications step
    @State private var notifStatus: NotifOnboardStatus = .unknown

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { .purple }

    enum KIOnboardStatus { case empty, saved, valid, invalid }
    enum NotifOnboardStatus { case unknown, granted, denied }

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                progressDots
                    .padding(.top, 60)
                    .padding(.bottom, 8)

                ZStack {
                    stepView(for: 0).opacity(step == 0 ? 1 : 0)
                    stepView(for: 1).opacity(step == 1 ? 1 : 0)
                    stepView(for: 2).opacity(step == 2 ? 1 : 0)
                    stepView(for: 3).opacity(step == 3 ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.35), value: step)
            }
        }
        .onAppear {
            // Apply auto-detected language on first open
            if localizer.selectedLanguage != selectedLang {
                localizer.selectedLanguage = selectedLang
            }
        }
        .sheet(isPresented: $showGeminiGuide) {
            NavigationStack {
                GeminiKeyGuideView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc("done")) { showGeminiGuide = false }
                        }
                    }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: isDark
                ? [Color(hex: "1a0a2e"), Color(hex: "0d0d1a")]
                : [Color(hex: "f5f0ff"), Color(hex: "ffe8f5")],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Progress Dots

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? accent : accent.opacity(0.25))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: step)
            }
        }
    }

    // MARK: - Step Dispatcher

    @ViewBuilder
    private func stepView(for index: Int) -> some View {
        switch index {
        case 0: languageStep
        case 1: kiStep
        case 2: notificationsStep
        case 3: readyStep
        default: EmptyView()
        }
    }

    // MARK: - Step 0: Language

    private var languageStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    stepIcon(systemName: "globe", color: .blue)

                    VStack(spacing: 10) {
                        Text("BeeFocus")
                            .font(.system(size: 34, weight: .black))
                            .foregroundStyle(
                                LinearGradient(colors: [accent, .blue],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                        Text(loc("onboarding_welcome_sub"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        Text(loc("onboarding_language_title"))
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)

                        HStack(spacing: 12) {
                            langButton(title: "Deutsch", flag: "🇩🇪", code: "Deutsch")
                            langButton(title: "English", flag: "🇬🇧", code: "Englisch")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 24)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
            bottomBar(
                primaryLabel: loc("onboarding_next"),
                primaryAction: { advance() }
            )
        }
    }

    private func langButton(title: String, flag: String, code: String) -> some View {
        Button {
            selectedLang = code
            localizer.selectedLanguage = code
        } label: {
            VStack(spacing: 8) {
                Text(flag).font(.system(size: 36))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(selectedLang == code ? accent : (isDark ? .white : .primary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedLang == code ? accent.opacity(0.15) : Color.white.opacity(isDark ? 0.06 : 0.6))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selectedLang == code ? accent.opacity(0.6) : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 1: KI-Anbieter

    private var kiStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    stepIcon(systemName: "sparkles", color: .purple)

                    VStack(spacing: 10) {
                        Text(loc("onboarding_ki_title"))
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isDark ? .white : .primary)
                        Text(loc("onboarding_ki_sub"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Provider picker
                    HStack(spacing: 12) {
                        kiProviderButton(
                            title: "Groq",
                            icon: "bolt.fill",
                            color: .orange,
                            badge: loc("onboarding_ki_free_badge"),
                            tag: "groq"
                        )
                        kiProviderButton(
                            title: "Gemini",
                            icon: "sparkles",
                            color: .purple,
                            badge: loc("onboarding_ki_google_badge"),
                            tag: "gemini"
                        )
                    }
                    .padding(.horizontal, 4)

                    // Key input card
                    VStack(alignment: .leading, spacing: 12) {
                        Label(loc("ki_api_key_label"), systemImage: "key.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)

                        HStack(spacing: 8) {
                            Group {
                                if kiKeyVisible {
                                    TextField(kiPlaceholder, text: $kiKey)
                                } else {
                                    SecureField(kiPlaceholder, text: $kiKey)
                                }
                            }
                            .font(.system(size: 14, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: kiKey) { _ in
                                if kiStatus == .valid || kiStatus == .invalid { kiStatus = .saved }
                            }

                            Button { kiKeyVisible.toggle() } label: {
                                Image(systemName: kiKeyVisible ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(kiKeyBorderColor, lineWidth: 1.5)
                        )

                        HStack {
                            kiStatusBadge
                            Spacer()
                            if kiProvider == "gemini" {
                                Button {
                                    showGeminiGuide = true
                                } label: {
                                    Label(loc("gemini_guide_short_btn"), systemImage: "questionmark.circle")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(accent)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Link(destination: URL(string: "https://console.groq.com/keys")!) {
                                    Label(loc("onboarding_ki_get_key"), systemImage: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 4)
                    .animation(.easeInOut(duration: 0.2), value: kiProvider)

                    // Info row
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill").foregroundStyle(.green)
                        Text(kiInfoText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .animation(.easeInOut(duration: 0.2), value: kiProvider)
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
            bottomBar(
                primaryLabel: kiKey.trimmingCharacters(in: .whitespaces).isEmpty
                    ? loc("onboarding_skip") : loc("ki_key_save"),
                primaryAction: { saveKIAndAdvance() },
                isLoading: kiSaving
            )
        }
    }

    private func kiProviderButton(title: String, icon: String, color: Color, badge: String, tag: String) -> some View {
        Button {
            kiProvider = tag
            kiKey = ""
            kiStatus = .empty
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(kiProvider == tag ? color : .secondary)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(kiProvider == tag ? color : (isDark ? .white : .primary))
                Text(badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(kiProvider == tag ? color.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(kiProvider == tag ? color.opacity(0.12) : Color.white.opacity(isDark ? 0.06 : 0.6))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(kiProvider == tag ? color.opacity(0.6) : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: kiProvider)
    }

    private var kiPlaceholder: String {
        kiProvider == "gemini" ? "AIza..." : "gsk_..."
    }

    private var kiInfoText: String {
        kiProvider == "gemini"
            ? loc("onboarding_gemini_free")
            : loc("onboarding_groq_free")
    }

    private var kiKeyBorderColor: Color {
        switch kiStatus {
        case .valid:   return .green.opacity(0.6)
        case .invalid: return .red.opacity(0.6)
        case .saved:   return accent.opacity(0.4)
        case .empty:   return Color.white.opacity(0.1)
        }
    }

    @ViewBuilder
    private var kiStatusBadge: some View {
        if kiSaving {
            ProgressView().scaleEffect(0.8)
        } else {
            switch kiStatus {
            case .valid:
                Label(loc("ki_key_valid"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            case .invalid:
                Label(loc("ki_key_invalid"), systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            case .saved:
                Label(loc("gemini_key_saved"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.blue)
            case .empty:
                EmptyView()
            }
        }
    }

    private func saveKIAndAdvance() {
        let trimmed = kiKey.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { advance(); return }
        kiSaving = true
        if kiProvider == "gemini" {
            KeychainHelper.save(trimmed, for: GeminiService.keychainKey)
            Task {
                let ok = await GeminiService.validate(apiKey: trimmed)
                kiSaving = false
                kiStatus = ok ? .valid : .invalid
                if ok { try? await Task.sleep(nanoseconds: 600_000_000) }
                advance()
            }
        } else {
            KeychainHelper.save(trimmed, for: GroqService.keychainKey)
            // Set Groq as active provider
            UserDefaults.standard.set("groq", forKey: "aiProvider")
            Task {
                let ok = await GroqService.validate(apiKey: trimmed)
                kiSaving = false
                kiStatus = ok ? .valid : .invalid
                if ok { try? await Task.sleep(nanoseconds: 600_000_000) }
                advance()
            }
        }
    }

    // MARK: - Step 2: Notifications

    private var notificationsStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    stepIcon(systemName: "bell.badge.fill", color: .orange)

                    VStack(spacing: 10) {
                        Text(loc("onboarding_notif_title"))
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(isDark ? .white : .primary)
                        Text(loc("onboarding_notif_sub"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Feature bullets
                    VStack(spacing: 0) {
                        notifFeatureRow(icon: "sun.max.fill", color: .orange,
                                        text: loc("onboarding_notif_f1"))
                        Divider().padding(.horizontal, 16)
                        notifFeatureRow(icon: "checkmark.circle.fill", color: .green,
                                        text: loc("onboarding_notif_f2"))
                        Divider().padding(.horizontal, 16)
                        notifFeatureRow(icon: "clock.fill", color: .blue,
                                        text: loc("onboarding_notif_f3"))
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    switch notifStatus {
                    case .granted:
                        Label(loc("onboarding_notif_granted"), systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    case .denied:
                        Text(loc("onboarding_notif_denied"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    case .unknown:
                        EmptyView()
                    }
                }
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
            bottomBar(
                primaryLabel: notifStatus == .unknown
                    ? loc("onboarding_notif_allow") : loc("onboarding_next"),
                primaryAction: { requestNotifAndAdvance() },
                skipLabel: notifStatus == .unknown ? loc("onboarding_skip") : nil,
                skipAction: { advance() }
            )
        }
    }

    private func notifFeatureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 32)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.9) : .primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func requestNotifAndAdvance() {
        if notifStatus != .unknown {
            advance()
            return
        }
        NotificationManager.shared.requestAuthorization { granted in
            DispatchQueue.main.async {
                notifStatus = granted ? .granted : .denied
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    advance()
                }
            }
        }
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                ZStack {
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(accent.opacity(0.08 + Double(i) * 0.02))
                            .frame(width: CGFloat(90 + i * 18), height: CGFloat(90 + i * 18))
                    }
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [accent, .blue],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }

                VStack(spacing: 10) {
                    Text(loc("onboarding_ready_title"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(isDark ? .white : .primary)
                        .multilineTextAlignment(.center)
                    Text(loc("onboarding_ready_sub"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            bottomBar(
                primaryLabel: loc("onboarding_start"),
                primaryAction: {
                    let gen = UIImpactFeedbackGenerator(style: .heavy)
                    gen.impactOccurred()
                    onComplete()
                }
            )
        }
    }

    // MARK: - Shared UI

    private func stepIcon(systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [color.opacity(0.25), color.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 100)
            Image(systemName: systemName)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [color, color.opacity(0.6)],
                                   startPoint: .top, endPoint: .bottom)
                )
        }
    }

    private func bottomBar(
        primaryLabel: String,
        primaryAction: @escaping () -> Void,
        isLoading: Bool = false,
        skipLabel: String? = nil,
        skipAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 12) {
            Divider()
            HStack(spacing: 12) {
                if let skip = skipLabel, let skipAct = skipAction {
                    Button(skip) { skipAct() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    primaryAction()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                            .frame(width: 140)
                    } else {
                        Text(primaryLabel)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 140)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(accent, in: Capsule())
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private func advance() {
        withAnimation(.easeInOut(duration: 0.35)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func loc(_ key: String) -> String {
        localizer.localizedString(forKey: key)
    }
}

