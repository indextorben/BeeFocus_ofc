import SwiftUI

struct MacWasserTrackerView: View {
    @ObservedObject private var store = MacWasserStore.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var showGoalPicker = false

    private let quickAmounts = [150, 200, 300, 500]
    private let cyan = Color(red: 0.15, green: 0.75, blue: 0.95)
    private let blue = Color(red: 0.2,  green: 0.5,  blue: 1.0)

    var body: some View {
        ZStack {
            ThemeBackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        progressRing
                        quickAddRow
                        weekChart
                        if !store.todayEntries.isEmpty {
                            todayLog
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(isPresented: $showGoalPicker) {
            MacZielPickerSheet(store: store, cyan: cyan)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Wasser-Tracker")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Button { showGoalPicker = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                    .foregroundStyle(cyan)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        let pct = store.todayProgress
        let total = store.todayTotal
        let goal = store.tagesziel

        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 16)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        LinearGradient(colors: [cyan, blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pct)

                VStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(cyan)
                    Text("\(total)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: total)
                    Text("ml von \(goal) ml")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            VStack(spacing: 3) {
                Text(statusLabel(pct))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(pct >= 1.0 ? cyan : .white)
                Text(remainingLabel(total: total, goal: goal))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(.top, 8)
    }

    private func statusLabel(_ pct: Double) -> String {
        switch pct {
        case 1.0...: return "Tagesziel erreicht!"
        case 0.75...: return "Fast geschafft"
        case 0.5...: return "Auf Kurs"
        case 0.25...: return "Weiter so!"
        default:     return "Mehr Wasser trinken!"
        }
    }

    private func remainingLabel(total: Int, goal: Int) -> String {
        let rem = max(0, goal - total)
        if rem == 0 { return "Ziel für heute erreicht" }
        return "\(rem) ml bis zum Ziel"
    }

    // MARK: - Quick Add

    private var quickAddRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schnell hinzufügen")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 8) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button { store.add(ml: amount) } label: {
                        VStack(spacing: 4) {
                            Image(systemName: glassIcon(amount))
                                .font(.system(size: 18))
                                .foregroundStyle(cyan)
                            Text("+\(amount)ml")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(cyan.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            MacCustomAmountButton(cyan: cyan) { ml in store.add(ml: ml) }
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    private func glassIcon(_ ml: Int) -> String {
        switch ml {
        case ..<200: return "cup.and.saucer.fill"
        case ..<350: return "mug.fill"
        case ..<450: return "waterbottle"
        default:     return "waterbottle.fill"
        }
    }

    // MARK: - Week Chart

    private var weekChart: some View {
        let days = store.last7DaysTotals()
        let maxML = max(days.map(\.ml).max() ?? 1, store.tagesziel)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Letzte 7 Tage")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days, id: \.date) { day in
                    let h = max(Double(day.ml) / Double(maxML), 0.04)
                    let reachedGoal = day.ml >= store.tagesziel
                    let isToday = Calendar.current.isDateInToday(day.date)

                    VStack(spacing: 4) {
                        Text(day.ml > 0 ? "\(day.ml / 10 * 10)" : "")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(reachedGoal ? cyan : .white.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: reachedGoal ? [cyan, blue] : [Color.white.opacity(0.25), Color.white.opacity(0.1)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(height: CGFloat(h) * 60)
                            .overlay(
                                isToday ? RoundedRectangle(cornerRadius: 4)
                                    .stroke(.white.opacity(0.4), lineWidth: 1.5) : nil
                            )

                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 8))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 85)

            HStack(spacing: 4) {
                Image(systemName: "arrow.right").font(.system(size: 8))
                Text("Tagesziel: \(store.tagesziel) ml").font(.system(size: 9))
            }
            .foregroundStyle(cyan.opacity(0.5))
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Today Log

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Heute getrunken")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button {
                    store.todayEntries.forEach { store.delete($0) }
                } label: {
                    Text("Zurücksetzen")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            ForEach(store.todayEntries) { entry in
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(cyan.opacity(0.7))
                    Text("+\(entry.ml) ml")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.35))
                    Button { store.delete(entry) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                if entry.id != store.todayEntries.last?.id {
                    Divider().background(.white.opacity(0.06))
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Custom Amount Button

private struct MacCustomAmountButton: View {
    let cyan: Color
    let onAdd: (Int) -> Void
    @State private var showField = false
    @State private var text = ""

    var body: some View {
        if showField {
            HStack(spacing: 8) {
                TextField("Menge in ml", text: $text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                    .onSubmit { submit() }
                Button("Hinzufügen") { submit() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(cyan, in: RoundedRectangle(cornerRadius: 8))
                    .buttonStyle(.plain)
                Button { showField = false; text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        } else {
            Button { showField = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text("Eigene Menge").font(.system(size: 12))
                }
                .foregroundStyle(cyan.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cyan.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private func submit() {
        if let ml = Int(text), ml > 0 { onAdd(ml); text = ""; showField = false }
    }
}

// MARK: - Goal Picker Sheet

struct MacZielPickerSheet: View {
    @ObservedObject var store: MacWasserStore
    let cyan: Color
    @Environment(\.dismiss) private var dismiss

    private let presets = [1500, 2000, 2500, 3000, 3500]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tagesziel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Fertig") { dismiss() }
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)

            Divider().overlay(Color.white.opacity(0.08))

            VStack(spacing: 8) {
                ForEach(presets, id: \.self) { ml in
                    Button { store.tagesziel = ml; dismiss() } label: {
                        HStack {
                            Image(systemName: "drop.fill").foregroundStyle(cyan)
                            Text("\(ml) ml / Tag")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer()
                            if store.tagesziel == ml {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(cyan)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            store.tagesziel == ml ? cyan.opacity(0.15) : Color.white.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(store.tagesziel == ml ? cyan.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color.black)
        }
        .frame(width: 300, height: 340)
        .background(Color.black)
    }
}
