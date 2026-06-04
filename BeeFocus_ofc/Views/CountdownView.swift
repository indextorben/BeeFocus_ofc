import SwiftUI

struct CountdownView: View {
    @StateObject private var store = CountdownStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var editEvent: CountdownEvent? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        if store.events.isEmpty {
                            emptyState
                        } else {
                            eventList
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundStyle(.white).font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showAdd) { CountdownAddSheet(store: store, dismiss: { showAdd = false }) }
            .sheet(item: $editEvent) { ev in CountdownAddSheet(store: store, existing: ev, dismiss: { editEvent = nil }) }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("⏳").font(.system(size: 52))
            Text("Countdowns").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Text("Keep track of important events")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75))
        }
        .multilineTextAlignment(.center)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48)).foregroundStyle(.white.opacity(0.4))
            Text("No countdowns yet\nTap + to add one")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private var eventList: some View {
        VStack(spacing: 12) {
            ForEach(store.events) { event in
                countdownCard(event)
                    .onTapGesture { editEvent = event }
            }
        }
    }

    private func countdownCard(_ event: CountdownEvent) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle().fill(event.farbe.opacity(0.25)).frame(width: 48, height: 48)
                Image(systemName: event.symbol).font(.system(size: 22)).foregroundStyle(event.farbe)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(event.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Text(datumLabel(event.datum)).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            // Counter
            VStack(alignment: .trailing, spacing: 2) {
                if event.istVorbei {
                    Text("Past").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                } else if event.istHeute {
                    Text("Today!").font(.system(size: 18, weight: .bold)).foregroundStyle(event.farbe)
                } else {
                    Text("\(event.tageVerbleibend)")
                        .font(.system(size: 26, weight: .bold)).foregroundStyle(event.farbe)
                    Text("days").font(.system(size: 11)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(event.farbe.opacity(0.3), lineWidth: 1))
        )
        .contextMenu {
            Button(role: .destructive) { store.delete(event) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func datumLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.dateStyle = .long
        return fmt.string(from: date)
    }
}

// MARK: - Add / Edit Sheet

private struct CountdownAddSheet: View {
    @ObservedObject var store: CountdownStore
    var existing: CountdownEvent? = nil
    let dismiss: () -> Void

    @State private var name: String = ""
    @State private var datum: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var symbol: String = "calendar.badge.clock"
    @State private var farbName: String = "blau"
    @State private var notiz: String = ""

    let symbole = ["calendar.badge.clock","star.fill","heart.fill","gift.fill","airplane","graduationcap.fill",
                   "house.fill","music.note","sportscourt.fill","car.fill","briefcase.fill","flag.fill",
                   "camera.fill","gamecontroller.fill","leaf.fill"]

    let farben: [(name: String, farbe: Color)] = [
        ("blau", Color(red: 0.2, green: 0.6, blue: 1.0)),
        ("gruen", Color(red: 0.2, green: 0.8, blue: 0.5)),
        ("orange", Color(red: 1.0, green: 0.55, blue: 0.1)),
        ("pink", Color(red: 1.0, green: 0.4, blue: 0.7)),
        ("lila", Color(red: 0.6, green: 0.3, blue: 1.0)),
        ("teal", Color(red: 0.2, green: 0.75, blue: 0.8)),
        ("rot", Color(red: 1.0, green: 0.25, blue: 0.25)),
        ("gelb", Color(red: 1.0, green: 0.8, blue: 0.1)),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.15, blue: 0.35), Color(red: 0.25, green: 0.1, blue: 0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        nameField
                        datumPicker
                        symbolPicker
                        farbPicker
                        notizField
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18).padding(.top, 20)
                }
            }
            .navigationTitle(existing == nil ? "New Countdown" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.4) : .white)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let ev = existing {
                    name = ev.name; datum = ev.datum
                    symbol = ev.symbol; farbName = ev.farbName; notiz = ev.notiz
                }
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("e.g. Vacation, Birthday…", text: $name)
                .font(.system(size: 15)).foregroundStyle(.white).tint(.white)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var datumPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            DatePicker("", selection: $datum, displayedComponents: .date)
                .datePickerStyle(.compact).colorScheme(.dark)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var symbolPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Icon").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                ForEach(symbole, id: \.self) { sym in
                    Button { symbol = sym } label: {
                        Image(systemName: sym)
                            .font(.system(size: 20))
                            .foregroundStyle(symbol == sym ? .black : .white)
                            .frame(width: 44, height: 44)
                            .background(symbol == sym ? Color.white : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }

    private var farbPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Color").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            HStack(spacing: 12) {
                ForEach(farben, id: \.name) { f in
                    Button { farbName = f.name } label: {
                        Circle().fill(f.farbe).frame(width: 32, height: 32)
                            .overlay { if farbName == f.name { Circle().stroke(.white, lineWidth: 3) } }
                    }
                }
            }
        }
    }

    private var notizField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            TextField("Description…", text: $notiz, axis: .vertical)
                .lineLimit(2...4).font(.system(size: 14)).foregroundStyle(.white).tint(.white)
                .padding(12).background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if var ev = existing {
            ev.name = n; ev.datum = datum; ev.symbol = symbol; ev.farbName = farbName; ev.notiz = notiz
            store.update(ev)
        } else {
            store.add(CountdownEvent(name: n, datum: datum, symbol: symbol, farbName: farbName, notiz: notiz))
        }
        dismiss()
    }
}
