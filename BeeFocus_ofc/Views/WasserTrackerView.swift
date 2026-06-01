import SwiftUI

struct WasserTrackerView: View {
    @ObservedObject private var store = WasserStore.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""
    @State private var showGoalPicker = false
    @State private var showHistory = false
    @State private var bounceKey = UUID()

    private let quickAmounts = [150, 200, 300, 500]
    private let cyan = Color(red: 0.15, green: 0.75, blue: 0.95)
    private let blue = Color(red: 0.2, green: 0.5, blue: 1.0)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.18), Color(red: 0.07, green: 0.12, blue: 0.22)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Progress ring
                    progressRing
                        .padding(.top, 8)

                    // Quick add buttons
                    quickAddRow

                    // 7-day chart
                    weekChart

                    // Today's log
                    if !store.todayEntries.isEmpty {
                        todayLog
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Wassertracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
                    .foregroundStyle(.white.opacity(0.6))
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showGoalPicker = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(cyan)
                }
            }
        }
        .sheet(isPresented: $showGoalPicker) {
            ZielPickerSheet(store: store, cyan: cyan)
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        let pct = store.todayProgress
        let total = store.todayTotal
        let goal = store.tagesziel

        return VStack(spacing: 16) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 18)
                    .frame(width: 190, height: 190)

                // Wave fill effect (simplified as arc)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(
                        LinearGradient(colors: [cyan, blue],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 190, height: 190)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: pct)

                // Inner content
                VStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(cyan)
                    Text("\(total)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: total)
                    Text("ml von \(goal) ml")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            // Status label
            VStack(spacing: 4) {
                Text(statusLabel(pct))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(pct >= 1.0 ? cyan : .white)
                Text(remainingLabel(total: total, goal: goal))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }

    private func statusLabel(_ pct: Double) -> String {
        switch pct {
        case 1.0...: return "Tagesziel erreicht! 💧"
        case 0.75...: return "Fast geschafft 👏"
        case 0.5...: return "Gut unterwegs 💪"
        case 0.25...: return "Weiter so!"
        default:     return "Trink mehr Wasser!"
        }
    }

    private func remainingLabel(total: Int, goal: Int) -> String {
        let rem = max(0, goal - total)
        if rem == 0 { return "Ziel erreicht für heute" }
        return "Noch \(rem) ml bis zum Ziel"
    }

    // MARK: - Quick Add

    private var quickAddRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Schnell hinzufügen")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 12) {
                ForEach(quickAmounts, id: \.self) { amount in
                    Button {
                        store.add(ml: amount)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation { bounceKey = UUID() }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: glassIcon(amount))
                                .font(.system(size: 22))
                                .foregroundStyle(cyan)
                            Text("+\(amount)ml")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(cyan.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Custom amount
            CustomAmountButton(cyan: cyan) { ml in
                store.add(ml: ml)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07), lineWidth: 1))
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

        return VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.date) { day in
                    let h = max(Double(day.ml) / Double(maxML), 0.04)
                    let reachedGoal = day.ml >= store.tagesziel
                    let isToday = Calendar.current.isDateInToday(day.date)

                    VStack(spacing: 6) {
                        Text(day.ml > 0 ? "\(day.ml / 10 * 10)" : "")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(reachedGoal ? cyan : .white.opacity(0.4))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)

                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(
                                colors: reachedGoal ? [cyan, blue] : [Color.white.opacity(0.25), Color.white.opacity(0.1)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(height: CGFloat(h) * 70)
                            .overlay(
                                isToday ? RoundedRectangle(cornerRadius: 5)
                                    .stroke(.white.opacity(0.4), lineWidth: 1.5) : nil
                            )

                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 9))
                            .foregroundStyle(isToday ? .white : .white.opacity(0.35))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)

            // Goal line label
            HStack {
                Image(systemName: "arrow.right")
                    .font(.system(size: 9))
                Text("Tagesziel: \(store.tagesziel) ml")
                    .font(.system(size: 10))
            }
            .foregroundStyle(cyan.opacity(0.5))
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Today's Log

    private var todayLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Heute getrunken")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Button {
                    store.todayEntries.forEach { store.delete($0) }
                } label: {
                    Text("Zurücksetzen")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.6))
                }
            }

            ForEach(store.todayEntries) { entry in
                HStack {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(cyan.opacity(0.7))
                    Text("+\(entry.ml) ml")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(entry.date.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                    Button {
                        store.delete(entry)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(4)
                    }
                }
                .padding(.vertical, 6)
                if entry.id != store.todayEntries.last?.id {
                    Divider().background(.white.opacity(0.06))
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.07), lineWidth: 1))
    }
}

// MARK: - Custom Amount Button

private struct CustomAmountButton: View {
    let cyan: Color
    let onAdd: (Int) -> Void
    @State private var showField = false
    @State private var text = ""

    var body: some View {
        if showField {
            HStack(spacing: 10) {
                TextField("Menge in ml", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                Button {
                    if let ml = Int(text), ml > 0 {
                        onAdd(ml)
                        text = ""
                        showField = false
                    }
                } label: {
                    Text("Hinzufügen")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(cyan, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                Button { showField = false; text = "" } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        } else {
            Button { showField = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Eigene Menge")
                        .font(.system(size: 13))
                }
                .foregroundStyle(cyan.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(cyan.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Goal Picker Sheet

private struct ZielPickerSheet: View {
    @ObservedObject var store: WasserStore
    let cyan: Color
    @Environment(\.dismiss) private var dismiss

    private let presets = [1500, 2000, 2500, 3000, 3500]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.1, blue: 0.2).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Tagesziel wählen")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 8)

                    VStack(spacing: 10) {
                        ForEach(presets, id: \.self) { ml in
                            Button {
                                store.tagesziel = ml
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "drop.fill")
                                        .foregroundStyle(cyan)
                                    Text("\(ml) ml / Tag")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if store.tagesziel == ml {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(cyan)
                                    }
                                }
                                .padding(.horizontal, 18).padding(.vertical, 14)
                                .background(store.tagesziel == ml ? cyan.opacity(0.15) : Color.white.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(store.tagesziel == ml ? cyan.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
            }
            .navigationTitle("Tagesziel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.medium])
    }
}
