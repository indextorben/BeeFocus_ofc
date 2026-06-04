import SwiftUI

struct ProfilView: View {
    @AppStorage("aktivesStatistikThema") private var aktivesThema = ""
    @AppStorage("darkModeEnabled")       private var darkModeEnabled = false
    @Environment(\.colorScheme) var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var themeC1: Color { appThemaFarben(aktivesThema).0 }
    private var themeC2: Color { appThemaFarben(aktivesThema).1 }

    // MARK: - Hardcoded developer data

    private let devName      = "Torben Lehneke"
    private let devBio       = "iOS-Entwickler & Designer von BeeFocus"
    private let devEmail     = "lehneketorben@gmail.com"
    private let devInstagram = "torben.lehneke_"
    private let devWebsite   = "torbenlehneke.de"

    var body: some View {
        ZStack {
            ThemeBackgroundView()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    avatarHeader
                    contactCard
                    appInfoCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 52)
            }
        }
        .navigationTitle("About the Developer")
        .navigationBarTitleDisplayMode(.large)
        .environment(\.colorScheme, darkModeEnabled ? .dark : .light)
    }

    // MARK: - Avatar Header

    private var avatarHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [themeC1, themeC2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: themeC1.opacity(0.5), radius: 22, x: 0, y: 10)

                Text("TL")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(devName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : .primary)

                Text(devBio)
                    .font(.system(size: 14))
                    .foregroundStyle(isDark ? .white.opacity(0.55) : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        profileSection(title: "Kontakt", icon: "person.crop.circle.fill", color: themeC1) {
            contactRow(
                icon: "envelope.fill",
                color: .red,
                label: "E-Mail",
                value: devEmail
            ) {
                open("mailto:\(devEmail)")
            }

            divider()

            contactRow(
                icon: "camera.fill",
                color: .pink,
                label: "Instagram",
                value: "@\(devInstagram)"
            ) {
                open("https://instagram.com/\(devInstagram)")
            }

            divider()

            contactRow(
                icon: "globe",
                color: .teal,
                label: "Website",
                value: devWebsite
            ) {
                open("https://\(devWebsite)")
            }
        }
    }

    // MARK: - App Info Card

    private var appInfoCard: some View {
        profileSection(title: "App", icon: "app.fill", color: themeC2) {
            infoRow(icon: "app.badge.fill", color: themeC1, label: "App", value: "BeeFocus")
            divider()
            infoRow(icon: "number", color: .indigo, label: "Version", value: Bundle.main.versionAndBuild)
            divider()
            infoRow(icon: "hammer.fill", color: .orange, label: "Entwickelt mit", value: "SwiftUI · iOS 16+")
        }
    }

    // MARK: - Helpers

    private func profileSection<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(color.opacity(0.8))
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [themeC1.opacity(isDark ? 0.12 : 0.07),
                                 themeC2.opacity(isDark ? 0.06 : 0.04)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [themeC1.opacity(isDark ? 0.45 : 0.28),
                                     themeC2.opacity(isDark ? 0.20 : 0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(isDark ? 0.22 : 0.07), radius: 14, x: 0, y: 5)
        }
    }

    private func contactRow(icon: String, color: Color, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBadge(icon: icon, color: color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
                    Text(value)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? .white : .primary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundStyle(themeC1.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func infoRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: color)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(isDark ? .white.opacity(0.45) : .secondary)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isDark ? .white : .primary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func iconBadge(icon: String, color: Color) -> some View {
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
        Divider()
            .padding(.leading, 58)
            .opacity(0.45)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        ProfilView()
    }
}
