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
    @Environment(\.colorScheme) var colorScheme

    var isDark: Bool { colorScheme == .dark }

    var activeGlowColor: Color { manager.isFocusModeActive ? .green : .indigo }
    var secondaryGlowColor: Color { manager.isFocusModeActive ? Color(red: 0.2, green: 0.9, blue: 0.6) : Color(red: 0.5, green: 0.4, blue: 1.0) }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer()

                shieldIcon
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.05), value: appeared)

                Spacer().frame(height: 28)

                statusText
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

                Spacer()

                bottomPanel
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8).delay(0.25), value: appeared)
                    .padding(.bottom, 32)
            }
        }
        .familyActivityPicker(isPresented: $showingPicker, selection: $manager.selection)
        .onChange(of: manager.selection) { _ in
            manager.saveSelection()
            if manager.isFocusModeActive { manager.enableFocusMode() }
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
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            if isDark {
                LinearGradient(
                    colors: manager.isFocusModeActive
                        ? [Color(red: 0.04, green: 0.12, blue: 0.08),
                           Color(red: 0.06, green: 0.14, blue: 0.10),
                           Color(red: 0.04, green: 0.10, blue: 0.06)]
                        : [Color(red: 0.06, green: 0.06, blue: 0.14),
                           Color(red: 0.10, green: 0.08, blue: 0.20),
                           Color(red: 0.08, green: 0.06, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                LinearGradient(
                    colors: manager.isFocusModeActive
                        ? [Color(red: 0.90, green: 0.98, blue: 0.93),
                           Color(red: 0.95, green: 1.0, blue: 0.96),
                           Color(red: 0.88, green: 0.97, blue: 0.91)]
                        : [Color(red: 0.95, green: 0.93, blue: 1.0),
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
                    .animation(.easeInOut(duration: 0.6), value: manager.isFocusModeActive)

                Circle()
                    .fill(RadialGradient(
                        colors: [secondaryGlowColor.opacity(isDark ? 0.18 : 0.10), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.35))
                    .frame(width: geo.size.width * 0.7, height: geo.size.width * 0.7)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.75)
                    .blur(radius: 22)
                    .animation(.easeInOut(duration: 0.6), value: manager.isFocusModeActive)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: manager.isFocusModeActive)
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
            return "Erlaube den Zugriff auf die Bildschirmzeit,\num Apps sperren zu können"
        }
        if manager.isFocusModeActive && manager.hasSelection {
            var parts: [String] = []
            if manager.selectedAppCount > 0 {
                parts.append("\(manager.selectedAppCount) App\(manager.selectedAppCount == 1 ? "" : "s")")
            }
            if manager.selectedCategoryCount > 0 {
                parts.append("\(manager.selectedCategoryCount) Kategorie\(manager.selectedCategoryCount == 1 ? "" : "n")")
            }
            return parts.joined(separator: " & ") + " gesperrt"
        } else if manager.hasSelection {
            return "Bereit – tippe auf Aktivieren, um zu starten"
        }
        return "Wähle Apps aus, die du sperren möchtest"
    }

    private var appSelectionLabel: String {
        var parts: [String] = []
        if manager.selectedAppCount > 0 {
            parts.append("\(manager.selectedAppCount) App\(manager.selectedAppCount == 1 ? "" : "s")")
        }
        if manager.selectedCategoryCount > 0 {
            parts.append("\(manager.selectedCategoryCount) Kategorie\(manager.selectedCategoryCount == 1 ? "" : "n")")
        }
        return parts.isEmpty ? "Noch keine ausgewählt" : parts.joined(separator: ", ")
    }
}

#Preview {
    FokusModeView()
}
