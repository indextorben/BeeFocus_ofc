import SwiftUI
import HealthKit

struct SchlafTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @AppStorage("schlafZielStunden") private var zielStunden: Double = 8.0

    @State private var authorized = false
    @State private var loading = true
    @State private var heutigeStunden: Double = 0
    @State private var schnitt7Tage: Double = 0
    @State private var wocheDaten: [(date: Date, stunden: Double)] = []
    @State private var showZielPicker = false
    @ObservedObject private var localizer = LocalizationManager.shared

    private let hkStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!

    private var accent: Color { aktivesThema.isEmpty ? Color(red: 0.3, green: 0.6, blue: 1.0) : appThemaFarben(aktivesThema).0 }
    private var progress: Double { zielStunden > 0 ? min(heutigeStunden / zielStunden, 1.0) : 0 }

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    if loading {
                        loadingCard
                    } else if !authorized {
                        permissionCard
                    } else {
                        ringCard
                        if !wocheDaten.isEmpty { historySection }
                    }
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .padding(.top, 16).padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .onAppear { requestAndLoad() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(localizer.localizedString(forKey: "sleep_title"))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(localizer.localizedString(forKey: "sleep_health_source"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 12))
                Text("Apple Health")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.4))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color(red: 1.0, green: 0.25, blue: 0.4).opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(Color(red: 1.0, green: 0.25, blue: 0.4).opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: - Loading / Permission

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(accent)
            Text(localizer.localizedString(forKey: "sleep_loading"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var permissionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 44))
                .foregroundStyle(accent)
            Text(localizer.localizedString(forKey: "sleep_permission_title"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
            Text(localizer.localizedString(forKey: "sleep_permission_body"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                requestAndLoad()
            } label: {
                Label(localizer.localizedString(forKey: "sleep_permission_button"), systemImage: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color(red: 0.3, green: 0.2, blue: 0.8), accent],
                                       startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Ring Card

    private var ringCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 14)
                    .frame(width: 150, height: 150)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [accent, Color(red: 0.5, green: 0.3, blue: 1.0)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: progress)

                VStack(spacing: 4) {
                    Text("🌙")
                        .font(.system(size: 28))
                    Text(heutigeStunden > 0 ? formatH(heutigeStunden) : "--")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(String(format: localizer.localizedString(forKey: "sleep_of_goal"), formatH(zielStunden)))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            HStack(spacing: 16) {
                statChip(localizer.localizedString(forKey: "sleep_avg_7days"), value: schnitt7Tage > 0 ? formatH(schnitt7Tage) : "--", color: accent)
                statChip(localizer.localizedString(forKey: "sleep_goal_label"), value: formatH(zielStunden), color: Color(red: 0.5, green: 0.3, blue: 1.0))
            }

            Button { showZielPicker = true } label: {
                Text(localizer.localizedString(forKey: "sleep_change_goal"))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 1.0, green: 0.25, blue: 0.4).opacity(0.7))
                Text(localizer.localizedString(forKey: "sleep_health_note"))
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(20)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
        .sheet(isPresented: $showZielPicker) { zielPickerSheet }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(localizer.localizedString(forKey: "sleep_last7days"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))

            let maxH = max(wocheDaten.map(\.stunden).max() ?? zielStunden, zielStunden)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(wocheDaten.enumerated()), id: \.offset) { _, pair in
                    VStack(spacing: 6) {
                        if pair.stunden > 0 {
                            Text(String(format: "%.1f", pair.stunden))
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(pair.stunden >= zielStunden ? accent : .white.opacity(0.5))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(pair.stunden >= zielStunden
                                      ? LinearGradient(colors: [accent, Color(red: 0.5, green: 0.3, blue: 1.0)], startPoint: .bottom, endPoint: .top)
                                      : LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.12)], startPoint: .bottom, endPoint: .top))
                                .frame(height: CGFloat(pair.stunden / maxH) * 70 + 8)
                        } else {
                            Text("·")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.2))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 8)
                        }
                        Text(dayLabel(pair.date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Ziel Picker

    private var zielPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.16).ignoresSafeArea()
                VStack(spacing: 10) {
                    ForEach([5.0, 6.0, 7.0, 7.5, 8.0, 8.5, 9.0], id: \.self) { h in
                        Button {
                            zielStunden = h
                            showZielPicker = false
                        } label: {
                            HStack {
                                Text(formatH(h))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                if zielStunden == h {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 14)
                            .background(zielStunden == h ? accent.opacity(0.15) : Color.white.opacity(0.05),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle(localizer.localizedString(forKey: "sleep_goal_sheet_title"))
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.localizedString(forKey: "sleep_goal_sheet_done")) { showZielPicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func statChip(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale.current; f.dateFormat = "EE"
        return String(f.string(from: date).prefix(2))
    }

    private func formatH(_ h: Double) -> String {
        let hi = Int(h); let m = Int((h - Double(hi)) * 60)
        return m == 0 ? "\(hi)h" : "\(hi)h \(m)m"
    }

    // MARK: - HealthKit

    private func requestAndLoad() {
        guard HKHealthStore.isHealthDataAvailable() else {
            loading = false; return
        }
        hkStore.requestAuthorization(toShare: [], read: [sleepType]) { granted, _ in
            DispatchQueue.main.async {
                authorized = granted
                if granted { loadSleepData() } else { loading = false }
            }
        }
    }

    private func loadSleepData() {
        let cal = Calendar.current
        let now = Date()
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: cal.startOfDay(for: now))!

        let predicate = HKQuery.predicateForSamples(withStart: sevenDaysAgo, end: now)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                DispatchQueue.main.async { loading = false }
                return
            }

            // Aggregate sleep seconds per calendar day
            var byDay: [Date: Double] = [:]
            for sample in samples {
                guard isAsleep(sample.value) else { continue }
                let day = cal.startOfDay(for: sample.endDate)
                let secs = sample.endDate.timeIntervalSince(sample.startDate)
                byDay[day, default: 0] += secs
            }

            // Build last 7 days array
            var result: [(date: Date, stunden: Double)] = []
            for i in (0..<7).reversed() {
                let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -i, to: now)!)
                result.append((date: day, stunden: (byDay[day] ?? 0) / 3600))
            }

            let todayStart = cal.startOfDay(for: now)
            let todayH = (byDay[todayStart] ?? 0) / 3600
            let validDays = result.filter { $0.stunden > 0 }
            let avg = validDays.isEmpty ? 0 : validDays.map(\.stunden).reduce(0, +) / Double(validDays.count)

            DispatchQueue.main.async {
                wocheDaten = result
                heutigeStunden = todayH
                schnitt7Tage = avg
                loading = false
            }
        }
        hkStore.execute(query)
    }

    private func isAsleep(_ value: Int) -> Bool {
        guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return false }
        switch v {
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
        default: return false
        }
    }
}
