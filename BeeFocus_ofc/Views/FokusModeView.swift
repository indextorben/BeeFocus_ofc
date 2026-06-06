import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - FokusModeView

@available(iOS 16, *)
struct FokusModeView: View {
    @StateObject private var manager = FokusModeManager.shared
    @ObservedObject private var localizer = LocalizationManager.shared
    @State private var showingPicker = false
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var ringRotation: Double = 0
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0
    @State private var liveSeconds: Int = 0
    @State private var showingGoalPicker = false
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("fokusZitatEnabled") private var fokusZitatEnabled: Bool = false

    private func loc(_ key: String) -> String { localizer.localizedString(forKey: key) }

    private var zitate: [String] {
        (0..<10).map { i in loc("fmv_quote_\(i)") }
    }

    private var tagesZitat: String {
        let dayIndex = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return zitate[dayIndex % zitate.count]
    }

    var isDark: Bool { colorScheme == .dark }

    private var themeColors: (Color, Color) {
        if aktivesThema.isEmpty {
            return manager.isFocusModeActive
                ? (.green, Color(red: 0.2, green: 0.9, blue: 0.6))
                : (.indigo, Color(red: 0.5, green: 0.4, blue: 1.0))
        }
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return (c1, c2)
    }

    var activeGlowColor: Color { themeColors.0 }
    var secondaryGlowColor: Color { themeColors.1 }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                shieldIcon
                    .scaleEffect(manager.isFocusModeActive
                        ? (appeared ? 0.72 : 0.58)
                        : (appeared ? 1.0  : 0.8))
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05), value: appeared)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: manager.isFocusModeActive)

                Spacer().frame(height: manager.isFocusModeActive ? 4 : 20)

                if manager.isFocusModeActive {
                    Text(formatDuration(liveSeconds))
                        .font(.system(size: 38, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [activeGlowColor, secondaryGlowColor],
                                startPoint: .leading, endPoint: .trailing))
                        .shadow(color: activeGlowColor.opacity(0.4), radius: 8)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                    Text(loc("fmv_active_label"))
                        .font(.caption)
                        .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                        .padding(.top, 2)

                    if fokusZitatEnabled {
                        Text("\u{201E}\(tagesZitat)\u{201C}")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .italic()
                            .foregroundStyle(isDark ? .white.opacity(0.35) : Color.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer().frame(height: manager.isFocusModeActive ? 10 : 24)

                statusText
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                Spacer(minLength: 12)

                statsButton
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.24), value: appeared)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                bottomPanel
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25), value: appeared)
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showingGoalPicker) {
            GoalPickerSheet(themeC1: activeGlowColor, currentMinutes: manager.dailyGoalMinutes) { mins in
                manager.setGoalMinutes(mins)
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $manager.selection)
        .onChange(of: manager.selection) { _ in
            manager.saveSelection()
            if manager.isFocusModeActive { manager.enableFocusMode() }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if manager.isFocusModeActive, let start = manager.currentSessionStart {
                liveSeconds = Int(Date().timeIntervalSince(start))
            }
        }
        .onChange(of: manager.isFocusModeActive) { active in
            if !active { liveSeconds = 0 }
        }
        .task { await manager.requestAuthorizationIfNeeded() }
        .onAppear {
            withAnimation { appeared = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                wavePhase1 = .pi * 2
            }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                wavePhase2 = .pi * 2
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        let (c1, c2, _) = appThemaFarben(aktivesThema)
        return ZStack {
            if isDark {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.06, blue: 0.14),
                             Color(red: 0.10, green: 0.08, blue: 0.20),
                             Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                             Color(red: 0.98, green: 0.96, blue: 1.0),
                             Color(red: 0.93, green: 0.97, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            GeometryReader { geo in
                Circle()
                    .fill(RadialGradient(
                        colors: [activeGlowColor.opacity(isDark ? (glowPulse ? 0.35 : 0.20) : (glowPulse ? 0.18 : 0.10)), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width, height: geo.size.width)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.42)
                    .blur(radius: 35)
                    .animation(.easeInOut(duration: 0.6), value: aktivesThema)

                Circle()
                    .fill(RadialGradient(
                        colors: [secondaryGlowColor.opacity(isDark ? 0.18 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.75)
                    .blur(radius: 22)
                    .animation(.easeInOut(duration: 0.6), value: aktivesThema)
            }

            GeometryReader { geo in
                WaveShape(phase: wavePhase2, amplitude: 16, frequency: 1.5)
                    .fill(c2.opacity(isDark ? 0.09 : 0.06))
                    .frame(width: geo.size.width, height: geo.size.height * 0.38)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.38 * 0.5)
                WaveShape(phase: wavePhase1, amplitude: 11, frequency: 2.2)
                    .fill(c1.opacity(isDark ? 0.14 : 0.09))
                    .frame(width: geo.size.width, height: geo.size.height * 0.25)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - geo.size.height * 0.25 * 0.5)
            }
            .opacity(["", "Forest", "Ice", "Northern Lights", "Galaxy", "Volcano", "Autumn", "Night", "Solar", "Cherry Blossom", "Lavender", "Sunset"].contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)

            if aktivesThema == "Forest" { WaldDecorationLayer().transition(.opacity) }
            if aktivesThema == "Ice" { EisDecorationLayer().transition(.opacity) }
            if aktivesThema == "Northern Lights" { NordlichtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Galaxy" { GalaxieDecorationLayer().transition(.opacity) }
            if aktivesThema == "Volcano" { VulkanDecorationLayer().transition(.opacity) }
            if aktivesThema == "Autumn" { HerbstDecorationLayer().transition(.opacity) }
            if aktivesThema == "Night" { NachtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Solar" { SolarDecorationLayer().transition(.opacity) }
            if aktivesThema == "Cherry Blossom" { KirschblueteDecorationLayer().transition(.opacity) }
            if aktivesThema == "Lavender" { LavendelDecorationLayer().transition(.opacity) }
            if aktivesThema == "Sunset" { SonnenuntergangDecorationLayer().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.8), value: aktivesThema)
        .ignoresSafeArea()
    }

    // MARK: - Shield Icon

    private var shieldIcon: some View {
        ZStack {
            // Outer glow rings
            if manager.isFocusModeActive {
                Circle()
                    .stroke(activeGlowColor.opacity(glowPulse ? 0.25 : 0.08), lineWidth: 1.5)
                    .frame(width: 190, height: 190)
                    .scaleEffect(glowPulse ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)

                Circle()
                    .stroke(activeGlowColor.opacity(glowPulse ? 0.15 : 0.04), lineWidth: 1)
                    .frame(width: 230, height: 230)
                    .scaleEffect(glowPulse ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.3), value: glowPulse)
            }

            // Rotating dashed ring
            Circle()
                .stroke(
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 8])
                )
                .foregroundStyle(activeGlowColor.opacity(manager.isFocusModeActive ? 0.4 : 0.2))
                .frame(width: 158, height: 158)
                .rotationEffect(.degrees(ringRotation))
                .animation(.easeInOut(duration: 0.6), value: manager.isFocusModeActive)

            // Background circle
            Circle()
                .fill(RadialGradient(
                    colors: [activeGlowColor.opacity(isDark ? 0.25 : 0.15), activeGlowColor.opacity(0.05)],
                    center: .center, startRadius: 10, endRadius: 70))
                .frame(width: 140, height: 140)
                .scaleEffect(glowPulse && manager.isFocusModeActive ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)

            // Shield icon
            Image(systemName: manager.isFocusModeActive ? "shield.fill" : "shield")
                .font(.system(size: 68, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [activeGlowColor, secondaryGlowColor],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: activeGlowColor.opacity(0.5), radius: 16, y: 4)
                .scaleEffect(glowPulse && manager.isFocusModeActive ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: glowPulse)
                .animation(.spring(response: 0.4), value: manager.isFocusModeActive)
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        VStack(spacing: 8) {
            Text(manager.isFocusModeActive ? loc("fmv_status_active") : loc("fmv_status_inactive"))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? .white : .primary)
                .animation(.easeInOut(duration: 0.3), value: manager.isFocusModeActive)

            Text(selectionSummary)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .animation(.easeInOut, value: manager.isFocusModeActive)
        }
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            // App selection row
            Button {
                showingPicker = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(activeGlowColor.opacity(0.2))
                            .frame(width: 38, height: 38)
                        Image(systemName: "app.badge.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(activeGlowColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("fmv_blocked_apps"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isDark ? .white : .primary)
                        Text(appSelectionLabel)
                            .font(.caption)
                            .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isDark ? .white.opacity(0.3) : Color(.tertiaryLabel))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(activeGlowColor.opacity(0.2), lineWidth: 1)
                )
            }
            .disabled(!manager.isAuthorized)
            .padding(.horizontal, 20)

            // Website blocking section
            websiteSection

            // Main action button
            if manager.isAuthorized {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        if manager.isFocusModeActive {
                            manager.disableFocusMode()
                        } else {
                            manager.enableFocusMode()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.isFocusModeActive ? "xmark.shield.fill" : "shield.checkered")
                            .font(.system(size: 18, weight: .semibold))
                        Text(manager.isFocusModeActive ? loc("fmv_btn_deactivate") : loc("fmv_btn_activate"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        manager.isFocusModeActive
                            ? LinearGradient(colors: [.red, Color(red: 1, green: 0.3, blue: 0.3)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [activeGlowColor, secondaryGlowColor], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: (manager.isFocusModeActive ? Color.red : activeGlowColor).opacity(0.4), radius: 12, y: 4)
                }
                .disabled(!manager.hasSelection && !manager.isFocusModeActive)
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.4), value: manager.isFocusModeActive)
            } else {
                Button {
                    Task { await manager.requestAuthorization() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(loc("fmv_btn_allow_screen_time"))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .indigo.opacity(0.4), radius: 12, y: 4)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private var selectionSummary: String {
        if !manager.isAuthorized {
            return loc("fokus.selection.no_access")
        }
        if manager.isFocusModeActive && manager.hasSelection {
            var parts: [String] = []
            if manager.selectedAppCount > 0 {
                let key = manager.selectedAppCount == 1 ? "fokus.app_count" : "fokus.apps_count"
                parts.append(String(format: loc(key), manager.selectedAppCount))
            }
            if manager.selectedCategoryCount > 0 {
                let key = manager.selectedCategoryCount == 1 ? "fokus.category_count" : "fokus.categories_count"
                parts.append(String(format: loc(key), manager.selectedCategoryCount))
            }
            return String(format: loc("fokus.selection.active"), parts.joined(separator: " & "))
        } else if manager.hasSelection {
            return loc("fmv_ready")
        }
        return loc("fmv_choose_apps")
    }

    // MARK: - Stats Button

    private var statsButton: some View {
        NavigationLink(destination: FokusStatistikView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(isDark ? 0.25 : 0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("fmv_stats_title"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                    Text(statsSubtitle)
                        .font(.caption)
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.3) : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var statsSubtitle: String {
        var secs = manager.todaySeconds
        if manager.isFocusModeActive, let start = manager.currentSessionStart {
            secs += Int(Date().timeIntervalSince(start))
        }
        guard secs > 0 else { return loc("fmv_no_focus_today") }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 && m > 0 { return String(format: loc("fokus.today_hours"), h, m) }
        if h > 0 { return String(format: loc("fokus.today_hours_only"), h) }
        return String(format: loc("fokus.today_minutes"), m)
    }

    // MARK: - Website Section

    private var websiteSection: some View {
        NavigationLink(destination: WebsiteSettingsView()) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "globe.badge.chevron.backward")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("fmv_block_websites"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isDark ? .white : .primary)
                    Text(verbatim: domainsLabel)
                        .font(.caption)
                        .foregroundStyle(isDark ? .white.opacity(0.5) : .secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.3) : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(manager.blockedDomains.isEmpty ? 0.2 : 0.4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .disabled(!manager.isAuthorized)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    private var appSelectionLabel: String {
        var parts: [String] = []
        if manager.selectedAppCount > 0 {
            let key = manager.selectedAppCount == 1 ? "fokus.app_count" : "fokus.apps_count"
            parts.append(String(format: loc(key), manager.selectedAppCount))
        }
        if manager.selectedCategoryCount > 0 {
            let key = manager.selectedCategoryCount == 1 ? "fokus.category_count" : "fokus.categories_count"
            parts.append(String(format: loc(key), manager.selectedCategoryCount))
        }
        return parts.isEmpty ? loc("fmv_none_selected") : parts.joined(separator: ", ")
    }

    private var domainsLabel: String {
        guard !manager.blockedDomains.isEmpty else {
            return loc("fmv_domains_label")
        }
        let key = manager.blockedDomains.count == 1 ? "fokus.domains_count" : "fokus.domains_count_plural"
        return String(format: loc(key), manager.blockedDomains.count)
    }

    // MARK: - Streak & Goal Row

    private var streakGoalRow: some View {
        HStack(spacing: 0) {
            // Streak
            HStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 26))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(manager.currentStreak)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(isDark ? .white : .primary)
                    Text(loc("fmv_day_streak"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08))
                .frame(width: 1, height: 44)

            // Daily goal progress
            Button { showingGoalPicker = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(activeGlowColor.opacity(0.2), lineWidth: 5)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: manager.todayProgress)
                            .stroke(activeGlowColor,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 44, height: 44)
                            .animation(.easeOut(duration: 0.6), value: manager.todayProgress)
                        if manager.todayProgress >= 1.0 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(activeGlowColor)
                        } else {
                            Text("\(Int(manager.todayProgress * 100))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(activeGlowColor)
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc("fmv_daily_goal"))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(goalDisplayLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isDark ? .white : .primary)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(activeGlowColor.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private var goalDisplayLabel: String {
        let h = manager.dailyGoalMinutes / 60
        let m = manager.dailyGoalMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)min" }
        if h > 0 { return "\(h)h" }
        return "\(m)min"
    }

}

// MARK: - Goal Picker Sheet

struct GoalPickerSheet: View {
    let themeC1: Color
    let currentMinutes: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared

    private func loc(_ key: String) -> String { localizer.localizedString(forKey: key) }

    private let options: [(key: String, mins: Int)] = [
        ("fmv_goal_30min",  30),
        ("fmv_goal_45min",  45),
        ("fmv_goal_1h",     60),
        ("fmv_goal_1_5h",   90),
        ("fmv_goal_2h",    120),
        ("fmv_goal_3h",    180),
        ("fmv_goal_4h",    240),
        ("fmv_goal_6h",    360),
    ]

    var body: some View {
        NavigationStack {
            List(options, id: \.mins) { option in
                Button {
                    onSelect(option.mins)
                    dismiss()
                } label: {
                    HStack {
                        Text(loc(option.key)).foregroundStyle(.primary)
                        Spacer()
                        if currentMinutes == option.mins {
                            Image(systemName: "checkmark").foregroundStyle(themeC1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(loc("fmv_goal_picker_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("ki_done")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    FokusModeView()
}
