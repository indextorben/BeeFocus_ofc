import SwiftUI

struct DankbarkeitView: View {
    @StateObject private var store = DankbarkeitStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var texte: [String] = ["", "", ""]
    @State private var saved = false
    @FocusState private var focusedIndex: Int?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.85, blue: 0.4), Color(red: 1.0, green: 0.6, blue: 0.3)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        streakSection
                        inputSection
                        historySection
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") { saveEntries() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadToday() }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🙏")
                .font(.system(size: 56))
            Text("Dankbarkeits-Tagebuch")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Was macht dich heute dankbar?")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
        }
        .multilineTextAlignment(.center)
    }

    private var streakSection: some View {
        HStack(spacing: 20) {
            streakChip(icon: "flame.fill", label: "\(store.streak)", subtitle: "Tage Streak", color: .orange)
            streakChip(icon: "checkmark.circle.fill", label: "\(store.eintraege.count)", subtitle: "Einträge gesamt", color: Color(red: 0.3, green: 0.8, blue: 0.5))
        }
    }

    private func streakChip(icon: String, label: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color)
                Text(label).font(.system(size: 24, weight: .bold)).foregroundStyle(.white)
            }
            Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heute bin ich dankbar für…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 12) {
                    Text("\(i + 1).")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 20)
                    TextField("Dankbarkeit \(i + 1)…", text: $texte[i], axis: .vertical)
                        .focused($focusedIndex, equals: i)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .tint(.white)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if saved {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                    Text("Gespeichert!").foregroundStyle(.white).fontWeight(.semibold)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Letzte 7 Tage")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            let days = store.last7Days()
            HStack(spacing: 8) {
                ForEach(days, id: \.date) { item in
                    VStack(spacing: 6) {
                        Circle()
                            .fill(item.hatEintrag ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if item.hatEintrag {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.3))
                                }
                            }
                        Text(dayLabel(item.date))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de")
        fmt.dateFormat = "EEE"
        return String(fmt.string(from: date).prefix(2))
    }

    private func loadToday() {
        if let entry = store.heutigerEintrag {
            for (i, t) in entry.eintraege.prefix(3).enumerated() {
                texte[i] = t
            }
        }
    }

    private func saveEntries() {
        focusedIndex = nil
        store.save(texte: texte)
        withAnimation(.spring(response: 0.4)) { saved = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                withAnimation { saved = false }
            }
        }
    }
}
