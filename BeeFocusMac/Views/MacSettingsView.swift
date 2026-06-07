import SwiftUI
import UserNotifications

struct MacSettingsView: View {
    @EnvironmentObject var timerMgr: MacTimerManager
    @EnvironmentObject var todoStore: MacTodoStore
    @EnvironmentObject var subManager: MacSubscriptionManager
    @Environment(\.colorScheme) private var colorScheme

    // Timer
    @AppStorage("mac_soundEnabled")      private var soundEnabled     = true
    @AppStorage("mac_autoStartBreaks")   private var autoStartBreaks  = false
    @AppStorage("mac_notifyOnComplete")  private var notifyOnComplete = true

    // Shared with iOS
    @AppStorage("showPastTasksGlobal")           private var showPastTasksGlobal           = false
    @AppStorage("filterCurrentMonthOnly")        private var filterCurrentMonthOnly        = false
    @AppStorage("aktivesStatistikThema")         private var aktivesThema: String           = ""
    @AppStorage("fokuspunktePeak")               private var fokuspunktePeak: Int           = 0
    @AppStorage("fokuspunkteAusgegeben")         private var fokuspunkteAusgegeben: Int     = 0
    @AppStorage("autoDeleteCompletedEnabled")    private var autoDeleteCompletedEnabled     = false
    @AppStorage("autoDeleteCompletedDays")       private var autoDeleteCompletedDays: Int   = 30

    // AI
    @AppStorage("mac_ai_provider") private var aiProviderRaw: String = MacAIProvider.groq.rawValue
    private var aiProvider: MacAIProvider { MacAIProvider(rawValue: aiProviderRaw) ?? .groq }

    @State private var headerAppeared         = false
    @State private var sectionsAppeared       = false
    @State private var showResetStatsConfirm  = false
    @State private var showNotificationBanner = false
    @State private var notificationMessage    = ""
    @State private var bannerColor: Color     = .green
    @State private var bannerDismissTask: Task<Void, Never>? = nil
    @State private var showPaywall            = false
    @State private var showAutoDeleteConfirm  = false
    @State private var aiKeyInput: String     = ""
    @State private var aiKeyVisible: Bool     = false
    @State private var aiKeySaved: Bool       = false

    private let allThemes: [(id: String, label: String)] = [
        ("", "Standard"), ("Ocean", "Ocean"), ("Forest", "Forest"),
        ("Night", "Night"), ("Solar", "Solar"), ("Cherry Blossom", "Cherry Blossom"),
        ("Volcano", "Volcano"), ("Ice", "Ice"), ("Autumn", "Autumn"),
        ("Lavender", "Lavender"), ("Sunset", "Sunset"), ("Galaxy", "Galaxy"),
        ("Northern Lights", "Northern Lights"), ("Aurora", "Aurora"),
        ("Obsidian", "Obsidian"), ("Nebula", "Nebula"),
    ]

    private var isDark: Bool { colorScheme == .dark }
    private var themeColors: (Color, Color, Color) { appThemaFarben(aktivesThema) }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    headerHero
                        .padding(.bottom, 8)
                        .opacity(sectionsAppeared ? 1 : 0)
                        .offset(y: sectionsAppeared ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: sectionsAppeared)

                    animatedSection(delay: 0.06) {
                        proCard
                    }
                    animatedSection(delay: 0.08) {
                        sectionGroup(icon: "paintbrush.fill", label: "Design", color: .indigo) { themeCard }
                    }
                    animatedSection(delay: 0.10) {
                        sectionGroup(icon: "eye", label: "Darstellung", color: .indigo) { darstellungCard }
                    }
                    animatedSection(delay: 0.14) {
                        sectionGroup(icon: "timer", label: "Timer-Einstellungen", color: .orange) { timerCard }
                    }
                    animatedSection(delay: 0.18) {
                        sectionGroup(icon: "bell.badge.fill", label: "Benachrichtigungen", color: .red) { benachrichtigungenCard }
                    }
                    animatedSection(delay: 0.22) {
                        sectionGroup(icon: "gearshape", label: "Verhalten", color: .teal) { verhaltensCard }
                    }
                    animatedSection(delay: 0.26) {
                        sectionGroup(icon: "sparkles", label: "KI Quick Input", color: .purple) { kiCard }
                    }
                    animatedSection(delay: 0.30) {
                        sectionGroup(icon: "checkmark.circle.fill", label: "Automatisches Löschen", color: .mint) { autoDeleteCard }
                    }
                    animatedSection(delay: 0.34) {
                        sectionGroup(icon: "arrow.triangle.2.circlepath", label: "Synchronisation", color: .blue) { syncCard }
                    }
                    animatedSection(delay: 0.38) {
                        sectionGroup(icon: "chart.bar.fill", label: "Statistik", color: .pink) { statistikCard }
                    }
                    animatedSection(delay: 0.42) {
                        sectionGroup(icon: "lock.shield", label: "Berechtigungen", color: .indigo) { berechtigungenCard }
                    }
                    animatedSection(delay: 0.46) {
                        sectionGroup(icon: "envelope.fill", label: "Feedback / Verbesserungen", color: .teal) { feedbackCard }
                    }

                    datenschutzCard
                        .opacity(sectionsAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.50), value: sectionsAppeared)
                    versionCard
                        .padding(.top, 2)
                        .opacity(sectionsAppeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.54), value: sectionsAppeared)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }

            // Banner
            if showNotificationBanner {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text(notificationMessage).foregroundStyle(.white).font(.subheadline.bold())
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(bannerColor.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: bannerColor.opacity(0.4), radius: 14, x: 0, y: 6)
                .padding(.horizontal, 16).padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showNotificationBanner)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) { headerAppeared = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { sectionsAppeared = true }
        }
        .alert("Statistik zurücksetzen?", isPresented: $showResetStatsConfirm) {
            Button("Zurücksetzen", role: .destructive) {
                fokuspunktePeak = 0
                fokuspunkteAusgegeben = 0
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Fokuspunkte und gespeicherte Statistiken werden zurückgesetzt.")
        }
        .alert("Erledigte Aufgaben löschen?", isPresented: $showAutoDeleteConfirm) {
            Button("Löschen", role: .destructive) {
                todoStore.deleteCompleted()
                bannerColor = .green
                showBanner(message: "Erledigte Aufgaben gelöscht")
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle abgeschlossenen Aufgaben werden unwiderruflich gelöscht.")
        }
        .sheet(isPresented: $showPaywall) {
            MacProPaywallView()
                .environmentObject(subManager)
        }
    }

    // MARK: - Hero Header

    private var themeHeroIcon: String {
        switch aktivesThema {
        case "Ocean":           return "water.waves"
        case "Forest":            return "tree.fill"
        case "Night":           return "moon.stars.fill"
        case "Solar":           return "sun.max.fill"
        case "Cherry Blossom":     return "camera.macro"
        case "Volcano":          return "flame.fill"
        case "Ice":             return "snowflake"
        case "Autumn":          return "wind"
        case "Lavender":        return "sparkles"
        case "Sunset": return "sunset.fill"
        case "Galaxy":         return "moon.circle.fill"
        case "Northern Lights":       return "aqi.medium"
        default:                return "gearshape.2.fill"
        }
    }

    private var headerHero: some View {
        let (c1, c2, _) = themeColors
        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(c1.opacity(isDark ? 0.15 : 0.08))
                    .frame(width: 84, height: 84)
                    .scaleEffect(headerAppeared ? 1.0 : 0.5)
                    .opacity(headerAppeared ? 1 : 0)

                Circle()
                    .fill(LinearGradient(colors: [c1, c2.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: c1.opacity(0.45), radius: 16, x: 0, y: 8)

                Image(systemName: themeHeroIcon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .modifier(BounceSymbolModifier(trigger: aktivesThema))
            }
            .scaleEffect(headerAppeared ? 1 : 0.7)
            .opacity(headerAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: aktivesThema)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: headerAppeared)

            VStack(spacing: 4) {
                Text("Einstellungen")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [c1, c2], startPoint: .leading, endPoint: .trailing))
                    .animation(.easeInOut(duration: 0.5), value: aktivesThema)
                Text("BeeFocus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .offset(y: headerAppeared ? 0 : 10)
            .opacity(headerAppeared ? 1 : 0)
        }
        .padding(.top, 20).padding(.bottom, 4)
    }

    // MARK: - Pro Card

    private var proCard: some View {
        let (c1, c2, _) = themeColors
        let accent  = aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : c1
        let accent2 = aktivesThema.isEmpty ? Color(red: 0.3,  green: 0.6,  blue: 1.0) : c2

        return Button {
            if !subManager.isPro { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accent2],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                        .shadow(color: accent.opacity(0.4), radius: 8)
                    Image(systemName: subManager.isPro ? "crown.fill" : "crown")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(subManager.isPro ? "BeeFocus Pro aktiv" : "BeeFocus Pro")
                        .font(.system(size: 15, weight: .bold))
                    if subManager.isPro {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.system(size: 11))
                            if let exp = subManager.expirationDate {
                                Text("Aktiv bis \(exp, format: .dateTime.day().month().year())")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            } else {
                                Text("Lifetime – danke für deine Unterstützung! 🎉")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Text("Alle Features freischalten")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if subManager.isPro {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 20))
                } else {
                    Label("Upgrade", systemImage: "arrow.up.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(
                            LinearGradient(colors: [accent, accent2], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .shadow(color: accent.opacity(0.35), radius: 6, y: 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        subManager.isPro
                            ? LinearGradient(colors: [accent.opacity(0.5), accent2.opacity(0.5)],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.primary.opacity(0.08)],
                                             startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(subManager.isPro)
    }

    // MARK: - Section Cards

    // ── Theme Picker ──────────────────────────────────────────────────
    private var themeCard: some View {
        glassCard {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(allThemes, id: \.id) { theme in
                        let (c1, c2, _) = appThemaFarben(theme.id)
                        let isSelected  = aktivesThema == theme.id
                        let accentC1    = theme.id.isEmpty ? Color.gray : c1
                        let accentC2    = theme.id.isEmpty ? Color.gray.opacity(0.6) : c2

                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { aktivesThema = theme.id }
                            NSUbiquitousKeyValueStore.default.set(theme.id, forKey: "aktivesStatistikThema")
                            NSUbiquitousKeyValueStore.default.synchronize()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [accentC1, accentC2],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 36, height: 36)
                                        .shadow(color: accentC1.opacity(isSelected ? 0.55 : 0.2),
                                                radius: isSelected ? 8 : 3)
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                    } else if theme.id.isEmpty {
                                        Image(systemName: "circle.slash")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .overlay(
                                    Circle().stroke(isSelected ? accentC1 : Color.clear, lineWidth: 2.5)
                                        .scaleEffect(1.18)
                                )

                                Text(theme.label)
                                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                    .foregroundStyle(isSelected ? accentC1 : Color.secondary)
                                    .lineLimit(1)
                                    .frame(width: 56)
                            }
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .animation(.easeInOut(duration: 0.25), value: aktivesThema)
                    }
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 82)
        }
    }

    // ── KI Quick Input ────────────────────────────────────────────────
    private var kiCard: some View {
        glassCard {
            HStack(spacing: 12) {
                iconBadge(icon: "sparkles", color: .purple)
                Text("Anbieter")
                    .font(.system(size: 16))
                Spacer()
                Picker("", selection: $aiProviderRaw) {
                    ForEach(MacAIProvider.allCases, id: \.rawValue) { p in
                        Text(p.label).tag(p.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .onChange(of: aiProviderRaw) { _ in
                    aiKeyInput = MacKeychain.load(for: aiProvider.keychainKey) ?? ""
                    aiKeySaved = false
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            cardDivider()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    iconBadge(icon: "key.fill", color: .orange)
                    Group {
                        if aiKeyVisible {
                            TextField("API Key", text: $aiKeyInput)
                        } else {
                            SecureField("API Key", text: $aiKeyInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .onAppear { aiKeyInput = MacKeychain.load(for: aiProvider.keychainKey) ?? "" }

                    Button { aiKeyVisible.toggle() } label: {
                        Image(systemName: aiKeyVisible ? "eye.slash" : "eye")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        MacKeychain.save(aiKeyInput.trimmingCharacters(in: .whitespaces),
                                         for: aiProvider.keychainKey)
                        aiKeySaved = true
                        bannerColor = .green
                        showBanner(message: "API Key gespeichert")
                    } label: {
                        Text(aiKeySaved ? "✓" : "Speichern")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(aiKeySaved ? .green : themeColors.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(aiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                Text(aiProvider == .groq
                     ? "Groq: kostenlos unter console.groq.com → API Keys"
                     : "OpenAI: platform.openai.com → API Keys")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .padding(.horizontal, 16).padding(.bottom, 10)
            }
        }
    }

    // ── Auto-Delete erledigte Aufgaben ────────────────────────────────
    private var autoDeleteCard: some View {
        glassCard {
            iconToggleRow(icon: "checkmark.circle.fill", color: .mint,
                          label: "Abgeschlossene automatisch löschen",
                          isOn: $autoDeleteCompletedEnabled)

            cardDivider()

            HStack(spacing: 12) {
                iconBadge(icon: "calendar.badge.clock", color: .purple)
                Stepper("Löschen nach \(autoDeleteCompletedDays) Tagen",
                        value: $autoDeleteCompletedDays, in: 1...365)
                    .disabled(!autoDeleteCompletedEnabled)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            cardDivider()

            Button { showAutoDeleteConfirm = true } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "trash.fill", color: .red)
                    Text("Erledigte Aufgaben jetzt löschen")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    Spacer()
                    Text("\(todoStore.todos.filter(\.isCompleted).count)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .disabled(todoStore.todos.filter(\.isCompleted).isEmpty)
        }
    }

    // ── Synchronisation ───────────────────────────────────────────────
    private var syncCard: some View {
        glassCard {
            Button {
                NSUbiquitousKeyValueStore.default.synchronize()
                MacCloudSettingsSync.shared.forceSync()
                bannerColor = .blue
                showBanner(message: "iCloud-Einstellungen synchronisiert")
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "icloud.and.arrow.down", color: .blue)
                    Text("Einstellungen jetzt synchronisieren")
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            cardDivider()

            Button {
                Task {
                    await todoStore.fetchTodos()
                    await MainActor.run {
                        bannerColor = .green
                        showBanner(message: "Aufgaben neu geladen")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "arrow.triangle.2.circlepath", color: .teal)
                    Text("Aufgaben neu laden")
                        .font(.system(size: 16)).foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var darstellungCard: some View {
        glassCard {
            iconToggleRow(icon: "clock.arrow.circlepath", color: .blue, label: "Vergangene Aufgaben anzeigen", isOn: $showPastTasksGlobal)
            cardDivider()
            iconToggleRow(icon: "calendar", color: .orange, label: "Nur aktuellen Monat (Statistik)", isOn: $filterCurrentMonthOnly)
        }
    }

    private var timerCard: some View {
        glassCard {
            HStack(spacing: 12) {
                iconBadge(icon: "brain.head.profile", color: .orange)
                Text("Fokuszeit")
                    .font(.system(size: 16))
                Spacer()
                Stepper("\(timerMgr.focusDuration) min", value: $timerMgr.focusDuration, in: 5...90)
                    .onChange(of: timerMgr.focusDuration) { v in
                        UserDefaults.standard.set(v, forKey: "mac_focusDuration")
                        if timerMgr.mode == .focus { timerMgr.resetToCurrentMode() }
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            cardDivider()

            HStack(spacing: 12) {
                iconBadge(icon: "cup.and.saucer.fill", color: Color(red: 0.2, green: 0.8, blue: 0.5))
                Text("Kurze Pause")
                    .font(.system(size: 16))
                Spacer()
                Stepper("\(timerMgr.shortBreak) min", value: $timerMgr.shortBreak, in: 1...30)
                    .onChange(of: timerMgr.shortBreak) { v in
                        UserDefaults.standard.set(v, forKey: "mac_shortBreak")
                        if timerMgr.mode == .shortBreak { timerMgr.resetToCurrentMode() }
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            cardDivider()

            HStack(spacing: 12) {
                iconBadge(icon: "moon.fill", color: Color(red: 0.3, green: 0.6, blue: 1.0))
                Text("Lange Pause")
                    .font(.system(size: 16))
                Spacer()
                Stepper("\(timerMgr.longBreak) min", value: $timerMgr.longBreak, in: 5...60)
                    .onChange(of: timerMgr.longBreak) { v in
                        UserDefaults.standard.set(v, forKey: "mac_longBreak")
                        if timerMgr.mode == .longBreak { timerMgr.resetToCurrentMode() }
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            cardDivider()

            HStack(spacing: 12) {
                iconBadge(icon: "repeat.circle.fill", color: .purple)
                Text("Sitzungen bis lange Pause")
                    .font(.system(size: 16))
                Spacer()
                Stepper("\(timerMgr.sessionsUntilLong)", value: $timerMgr.sessionsUntilLong, in: 2...8)
                    .onChange(of: timerMgr.sessionsUntilLong) { v in
                        UserDefaults.standard.set(v, forKey: "mac_sessionsUntilLong")
                    }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var benachrichtigungenCard: some View {
        glassCard {
            iconToggleRow(icon: "bell.badge.fill", color: .red, label: "Benachrichtigung bei Phasenwechsel", isOn: $notifyOnComplete)
            cardDivider()
            iconToggleRow(icon: "speaker.wave.2.fill", color: .blue, label: "Ton abspielen", isOn: $soundEnabled)
        }
    }

    private var verhaltensCard: some View {
        glassCard {
            iconToggleRow(icon: "play.circle.fill", color: .teal, label: "Pause automatisch starten", isOn: $autoStartBreaks)
        }
    }

    private var statistikCard: some View {
        glassCard {
            Button {
                showResetStatsConfirm = true
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "trash.slash.fill", color: .red)
                    Text("Statistik zurücksetzen")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            cardDivider()

            Button {
                fokuspunktePeak += 1000
                bannerColor = .green
                showBanner(message: "+1000 Fokuspunkte hinzugefügt")
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "plus.circle.fill", color: .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TEST: +1000 Fokuspunkte")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                        Text("Peak aktuell: \(fokuspunktePeak) FP")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var berechtigungenCard: some View {
        glassCard {
            Button {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        if granted {
                            bannerColor = .green
                            showBanner(message: "Benachrichtigungen erlaubt")
                        } else {
                            bannerColor = .orange
                            NSWorkspace.shared.open(
                                URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                            )
                        }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "bell.badge.fill", color: .indigo)
                    Text("Benachrichtigungen erlauben")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            cardDivider()

            Button {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
                )
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "gear", color: .gray)
                    Text("Systemeinstellungen öffnen")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var feedbackCard: some View {
        glassCard {
            Button {
                sendFeedbackEmail()
            } label: {
                HStack(spacing: 12) {
                    iconBadge(icon: "envelope.fill", color: .blue)
                    Text("Verbesserungen & Feedback")
                        .font(.system(size: 16))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            cardDivider()

            HStack(spacing: 12) {
                iconBadge(icon: "person.fill", color: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Entwickler")
                        .font(.system(size: 16))
                    Text("Torben Lehneke")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    private var datenschutzCard: some View {
        HStack(spacing: 16) {
            Link(destination: URL(string: "https://torbenlehneke.de/datenschutz")!) {
                Text("Datenschutzerklärung")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .underline()
            }
            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Link(destination: URL(string: "https://torbenlehneke.de/nutzungsbedingungen")!) {
                Text("Nutzungsbedingungen")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .underline()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var versionCard: some View {
        VStack(spacing: 4) {
            Text(Bundle.main.versionAndBuild)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Design Helpers

    private func animatedSection<C: View>(delay: Double, @ViewBuilder content: () -> C) -> some View {
        content()
            .opacity(sectionsAppeared ? 1 : 0)
            .offset(y: sectionsAppeared ? 0 : 18)
            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(delay), value: sectionsAppeared)
    }

    private func sectionGroup<Content: View>(icon: String, label: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(aktivesThema.isEmpty ? color : themeColors.0.opacity(0.85))
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(aktivesThema.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(themeColors.0.opacity(0.5)))
            }
            .padding(.horizontal, 6).padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.4), value: aktivesThema)
            content()
        }
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let hasTema = !aktivesThema.isEmpty
        let (c1, c2, _) = themeColors
        return VStack(spacing: 0) { content() }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [c1.opacity(isDark ? 0.14 : 0.09), c2.opacity(isDark ? 0.07 : 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .opacity(hasTema ? 1.0 : 0.0)
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(
                    colors: hasTema
                        ? [c1.opacity(isDark ? 0.50 : 0.32), c2.opacity(isDark ? 0.22 : 0.16)]
                        : [Color.white.opacity(isDark ? 0.13 : 0.65), Color.white.opacity(isDark ? 0.04 : 0.20)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: Color.black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
            .shadow(color: c1.opacity(isDark ? 0.18 : 0.08), radius: 18, x: 0, y: 2)
            .animation(.easeInOut(duration: 0.5), value: aktivesThema)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: color.opacity(0.35), radius: 4, x: 0, y: 2)
    }

    private func iconToggleRow(icon: String, color: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: color)
            Text(label).font(.system(size: 16))
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func cardDivider() -> some View {
        Divider().padding(.leading, 58).opacity(0.5)
    }

    // MARK: - Feedback

    private func sendFeedbackEmail() {
        let email   = "lehneketorben@gmail.com"
        let subject = "Feedback zur BeeFocus Mac App"
        let body    = "Hallo,\n\nHier ist mein Feedback:\n"
        let encoded = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: encoded) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Banner

    private func showBanner(message: String) {
        notificationMessage = message
        bannerDismissTask?.cancel()
        withAnimation(.spring()) { showNotificationBanner = true }
        bannerDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut) { showNotificationBanner = false }
            }
        }
    }
}

// MARK: - Helpers

private struct BounceSymbolModifier: ViewModifier {
    let trigger: String
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.symbolEffect(.bounce, value: trigger)
        } else {
            content
        }
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    var versionAndBuild: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build   = infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "BeeFocus \(version) (\(build))"
    }
}
