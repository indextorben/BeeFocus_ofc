import SwiftUI
import Charts

@available(iOS 16, *)
struct FokusStatistikView: View {
    @StateObject private var manager = FokusModeManager.shared
    @State private var liveSeconds: Int = 0
    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) var colorScheme

    var isDark: Bool { colorScheme == .dark }

    private var todayTotal: Int { manager.todaySeconds + liveSeconds }
    private var weekTotal: Int { manager.weekSeconds + liveSeconds }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    topCards
                    chartCard
                    allTimeStat
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Fokus-Statistik")
        .navigationBarTitleDisplayMode(.large)
        .onReceive(ticker) { _ in
            guard manager.isFocusModeActive, let start = manager.currentSessionStart else {
                liveSeconds = 0
                return
            }
            liveSeconds = Int(Date().timeIntervalSince(start))
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
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
                        colors: [Color.indigo.opacity(isDark ? 0.22 : 0.12), .clear],
                        center: .center, startRadius: 0, endRadius: geo.size.width * 0.5))
                    .frame(width: geo.size.width, height: geo.size.width)
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.15)
                    .blur(radius: 30)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Cards

    private var topCards: some View {
        HStack(spacing: 14) {
            statCard(
                title: "Heute",
                value: formatDuration(todayTotal),
                subtitle: manager.isFocusModeActive ? "Aktiv" : "Gesamt",
                icon: "sun.max.fill",
                color: .orange,
                isLive: manager.isFocusModeActive
            )
            statCard(
                title: "Diese Woche",
                value: formatDuration(weekTotal),
                subtitle: "7 Tage",
                icon: "calendar",
                color: .indigo,
                isLive: false
            )
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color, isLive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isDark ? .white.opacity(0.6) : .secondary)
                Spacer()
                if isLive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? .white : .primary)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(color.opacity(0.9))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Letzte 7 Tage")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDark ? .white : .primary)
                Spacer()
                Text("in Minuten")
                    .font(.caption)
                    .foregroundStyle(isDark ? .white.opacity(0.4) : .secondary)
            }

            Chart {
                ForEach(manager.last7Days, id: \.date) { entry in
                    let minutes = entry.seconds / 60
                    let isToday = Calendar.current.isDateInToday(entry.date)
                    BarMark(
                        x: .value("Tag", entry.date, unit: .day),
                        y: .value("Minuten", isToday ? (todayTotal / 60) : minutes)
                    )
                    .foregroundStyle(
                        isToday
                            ? LinearGradient(colors: [.indigo, Color(red: 0.5, green: 0.4, blue: 1.0)], startPoint: .bottom, endPoint: .top)
                            : LinearGradient(colors: [Color.indigo.opacity(0.4), Color.indigo.opacity(0.6)], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(6)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .foregroundStyle(isDark ? Color.white.opacity(0.4) : Color.secondary)
                    AxisGridLine()
                        .foregroundStyle(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.06))
                }
            }
            .frame(height: 180)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.indigo.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - All Time

    private var allTimeStat: some View {
        let total = manager.dailyFocusSeconds.values.reduce(0, +) + liveSeconds
        let sessions = manager.dailyFocusSeconds.values.filter { $0 > 0 }.count
        let maxDay = manager.last7Days.max(by: { $0.seconds < $1.seconds })

        return VStack(spacing: 0) {
            statRow(label: "Gesamt (alle Zeit)", value: formatDuration(total), icon: "infinity", color: .purple)
            Divider().opacity(0.3).padding(.horizontal, 16)
            statRow(label: "Aktive Tage", value: "\(sessions)", icon: "calendar.badge.checkmark", color: .green)
            Divider().opacity(0.3).padding(.horizontal, 16)
            statRow(
                label: "Bester Tag (7T)",
                value: maxDay.map { formatDuration($0.seconds) } ?? "—",
                icon: "trophy.fill",
                color: .orange
            )
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
    }

    private func statRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.subheadline)
                .foregroundStyle(isDark ? .white.opacity(0.85) : .primary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isDark ? .white : .primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0 min" }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m) min"
    }
}

#Preview {
    if #available(iOS 16, *) {
        NavigationStack {
            FokusStatistikView()
        }
    }
}
