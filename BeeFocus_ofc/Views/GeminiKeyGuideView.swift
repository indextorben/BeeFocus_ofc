import SwiftUI

struct GeminiKeyGuideView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var keyInput: String = ""
    @State private var keyVisible: Bool = false
    @State private var isValidating: Bool = false
    @State private var keyStatus: KeyStatus = .empty

    enum KeyStatus { case empty, saved, valid, invalid }

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color { .purple }
    private let studioURL = URL(string: "https://aistudio.google.com/apikey")!

    private var maskedKey: String {
        let k = keyInput
        guard k.count > 8 else { return String(repeating: "•", count: k.count) }
        return String(k.prefix(4)) + String(repeating: "•", count: k.count - 8) + String(k.suffix(4))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                heroSection
                stepsSection
                keySection
                freeHintCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .background { ThemeBackgroundView().ignoresSafeArea() }
        .navigationTitle(String(localized: "gemini_guide_title"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            let saved = KeychainHelper.load(for: GeminiService.keychainKey) ?? ""
            keyInput = saved
            keyStatus = saved.isEmpty ? .empty : .saved
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0.05)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [accent, accent.opacity(0.5)],
                                                   startPoint: .top, endPoint: .bottom))
            }
            VStack(spacing: 6) {
                Text(String(localized: "gemini_guide_headline"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(String(localized: "gemini_guide_subline"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 0) {
            stepRow(number: 1, icon: "safari.fill", color: .blue,
                    title: String(localized: "gemini_step1_title"),
                    desc: String(localized: "gemini_step1_desc")) {
                Link(destination: studioURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.square.fill")
                        Text("aistudio.google.com/apikey")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(accent.opacity(0.12), in: Capsule())
                }
            }

            connector

            stepRow(number: 2, icon: "person.circle.fill", color: .orange,
                    title: String(localized: "gemini_step2_title"),
                    desc: String(localized: "gemini_step2_desc"))

            connector

            stepRow(number: 3, icon: "key.fill", color: .green,
                    title: String(localized: "gemini_step3_title"),
                    desc: String(localized: "gemini_step3_desc"))

            connector

            stepRow(number: 4, icon: "doc.on.clipboard.fill", color: accent,
                    title: String(localized: "gemini_step4_title"),
                    desc: String(localized: "gemini_step4_desc"))
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var connector: some View {
        HStack {
            Color.secondary.opacity(0.25)
                .frame(width: 1.5, height: 18)
                .padding(.leading, 37)
            Spacer()
        }
    }

    // Overload ohne extra-Inhalt
    @ViewBuilder
    private func stepRow(number: Int, icon: String, color: Color,
                         title: String, desc: String) -> some View {
        stepRow(number: number, icon: icon, color: color,
                title: title, desc: desc) { EmptyView() }
    }

    @ViewBuilder
    private func stepRow<Extra: View>(number: Int, icon: String, color: Color,
                                     title: String, desc: String,
                                     @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text("\(number).")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                }
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                extra().padding(.top, 2)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Key Input

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(String(localized: "gemini_paste_key_label"), systemImage: "key.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDark ? .white : .primary)

            if keyStatus == .empty {
                // No key yet → show input field
                HStack(spacing: 8) {
                    Group {
                        if keyVisible {
                            TextField("AIza...", text: $keyInput)
                        } else {
                            SecureField("AIza...", text: $keyInput)
                        }
                    }
                    .font(.system(size: 14, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    Button { keyVisible.toggle() } label: {
                        Image(systemName: keyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5))

                HStack {
                    Spacer()
                    Button {
                        let trimmed = keyInput.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        KeychainHelper.save(trimmed, for: GeminiService.keychainKey)
                        isValidating = true
                        Task {
                            let ok = await GeminiService.validate(apiKey: trimmed)
                            isValidating = false
                            keyStatus = ok ? .valid : .invalid
                        }
                    } label: {
                        if isValidating {
                            ProgressView().scaleEffect(0.8).tint(.white).frame(width: 80)
                        } else {
                            Text(String(localized: "ki_key_save"))
                                .font(.caption.weight(.semibold)).foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(keyInput.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary.opacity(0.4) : accent, in: Capsule())
                    .buttonStyle(.plain)
                    .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || isValidating)
                }
            } else {
                // Key already saved → show masked + delete only
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(maskedKey)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    statusBadge
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderColor, lineWidth: 1.5))

                HStack {
                    Spacer()
                    Button(String(localized: "ki_key_delete")) {
                        keyInput = ""
                        keyStatus = .empty
                        KeychainHelper.delete(for: GeminiService.keychainKey)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [accent.opacity(isDark ? 0.12 : 0.07), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isValidating {
            ProgressView().scaleEffect(0.8)
        } else {
            switch keyStatus {
            case .valid:
                Label(String(localized: "ki_key_valid"), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            case .invalid:
                Label(String(localized: "ki_key_invalid"), systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
            case .saved:
                Label(String(localized: "gemini_key_saved"), systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.blue)
            case .empty:
                EmptyView()
            }
        }
    }

    private var borderColor: Color {
        switch keyStatus {
        case .valid:   return .green.opacity(0.6)
        case .invalid: return .red.opacity(0.6)
        case .saved:   return accent.opacity(0.4)
        case .empty:   return .clear
        }
    }

    // MARK: - Free Hint

    private var freeHintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "gemini_free_title"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Text(String(localized: "gemini_free_desc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.green.opacity(isDark ? 0.12 : 0.08))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.green.opacity(0.25), lineWidth: 1)
        }
    }
}
