import SwiftUI
import FamilyControls
import ManagedSettings

@available(iOS 16, *)
struct FokusModeView: View {
    @StateObject private var manager = FokusModeManager.shared
    @State private var showingPicker = false
    @State private var appeared = false
    @State private var glowPulse = false
    @State private var ringRotation: Double = 0
    @State private var wavePhase1: CGFloat = 0
    @State private var wavePhase2: CGFloat = 0
    @State private var liveSeconds: Int = 0
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

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

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        Spacer()

                        shieldIcon
                            .scaleEffect(appeared ? 1 : 0.8)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05), value: appeared)

                        Spacer().frame(height: 20)

                        if manager.isFocusModeActive {
                            Text(formatDuration(liveSeconds))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [activeGlowColor, secondaryGlowColor],
                                        startPoint: .leading, endPoint: .trailing))
                                .shadow(color: activeGlowColor.opacity(0.4), radius: 8)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.15), value: appeared)

                            Text("Fokusmodus aktiv")
                                .font(.caption)
                                .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
                                .padding(.top, 2)
                        }

                        Spacer().frame(height: manager.isFocusModeActive ? 16 : 28)

                        statusText
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                        Spacer()

                        statsButton
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.22), value: appeared)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)

                        bottomPanel
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 30)
                            .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25), value: appeared)
                            .padding(.bottom, 32)
                    }
                    .frame(minHeight: geo.size.height)
                }
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
            .opacity(["", "Wald", "Eis", "Nordlicht", "Galaxie", "Vulkan", "Herbst", "Nacht", "Solar", "Kirschblüte", "Lavendel", "Sonnenuntergang"].contains(aktivesThema) ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.8), value: aktivesThema)

            if aktivesThema == "Wald" { WaldDecorationLayer().transition(.opacity) }
            if aktivesThema == "Eis" { EisDecorationLayer().transition(.opacity) }
            if aktivesThema == "Nordlicht" { NordlichtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Galaxie" { GalaxieDecorationLayer().transition(.opacity) }
            if aktivesThema == "Vulkan" { VulkanDecorationLayer().transition(.opacity) }
            if aktivesThema == "Herbst" { HerbstDecorationLayer().transition(.opacity) }
            if aktivesThema == "Nacht" { NachtDecorationLayer().transition(.opacity) }
            if aktivesThema == "Solar" { SolarDecorationLayer().transition(.opacity) }
            if aktivesThema == "Kirschblüte" { KirschblueteDecorationLayer().transition(.opacity) }
            if aktivesThema == "Lavendel" { LavendelDecorationLayer().transition(.opacity) }
            if aktivesThema == "Sonnenuntergang" { SonnenuntergangDecorationLayer().transition(.opacity) }
        }
        .animation(.easeInOut(duration: 0.8), value: aktivesThema)
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Fokusmodus")
                .font(.title2.bold())
                .foregroundStyle(isDark ? .white : .primary)
            Spacer()
        }
        .padding(.vertical, 12)
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
            Text(manager.isFocusModeActive ? "Aktiv" : "Inaktiv")
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
                        Text("Gesperrte Apps")
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
                        Text(manager.isFocusModeActive ? "Deaktivieren" : "Jetzt aktivieren")
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
                        Text("Bildschirmzeit-Zugriff erlauben")
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
            return NSLocalizedString("fokus.selection.no_access", comment: "")
        }
        if manager.isFocusModeActive && manager.hasSelection {
            var parts: [String] = []
            if manager.selectedAppCount > 0 {
                let key = manager.selectedAppCount == 1 ? "fokus.app_count" : "fokus.apps_count"
                parts.append(String(format: NSLocalizedString(key, comment: ""), manager.selectedAppCount))
            }
            if manager.selectedCategoryCount > 0 {
                let key = manager.selectedCategoryCount == 1 ? "fokus.category_count" : "fokus.categories_count"
                parts.append(String(format: NSLocalizedString(key, comment: ""), manager.selectedCategoryCount))
            }
            return String(format: NSLocalizedString("fokus.selection.active", comment: ""), parts.joined(separator: " & "))
        } else if manager.hasSelection {
            return NSLocalizedString("fokus.selection.ready", comment: "")
        }
        return NSLocalizedString("fokus.selection.choose", comment: "")
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
                    Text("Fokus-Statistik")
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
        guard secs > 0 else { return NSLocalizedString("Noch kein Fokus heute", comment: "") }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h > 0 && m > 0 { return String(format: NSLocalizedString("fokus.today_hours", comment: ""), h, m) }
        if h > 0 { return String(format: NSLocalizedString("fokus.today_hours_only", comment: ""), h) }
        return String(format: NSLocalizedString("fokus.today_minutes", comment: ""), m)
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
                    Text("Websites sperren")
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
            parts.append(String(format: NSLocalizedString(key, comment: ""), manager.selectedAppCount))
        }
        if manager.selectedCategoryCount > 0 {
            let key = manager.selectedCategoryCount == 1 ? "fokus.category_count" : "fokus.categories_count"
            parts.append(String(format: NSLocalizedString(key, comment: ""), manager.selectedCategoryCount))
        }
        return parts.isEmpty ? NSLocalizedString("Noch keine ausgewählt", comment: "") : parts.joined(separator: ", ")
    }

    private var domainsLabel: String {
        guard !manager.blockedDomains.isEmpty else {
            return NSLocalizedString("Kategorien & eigene Domains", comment: "")
        }
        let key = manager.blockedDomains.count == 1 ? "fokus.domains_count" : "fokus.domains_count_plural"
        return String(format: NSLocalizedString(key, comment: ""), manager.blockedDomains.count)
    }
}

#Preview {
    FokusModeView()
}
