import SwiftUI
import EventKit

struct KalenderLoeschenView: View {
    @State private var eventStore = EKEventStore()
    @State private var sections: [(title: String, calendars: [EKCalendar])] = []
    @State private var accessGranted = false
    @State private var isLoading = true

    @State private var selectedCalendar: EKCalendar? = nil
    @State private var showConfirm = false
    @State private var isDeleting = false
    @State private var deletedCount = 0
    @State private var showResult = false

    @State private var deleteFrom: Date = Calendar.current.startOfDay(for: Date())
    @State private var deleteTo: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .listRowBackground(Color.clear)
                }
            } else if !accessGranted {
                Section {
                    VStack(spacing: 14) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Kalenderzugriff erforderlich")
                            .font(.headline)
                        Text("Gehe zu Einstellungen → Datenschutz & Sicherheit → Kalender und erlaube BeeFocus den vollen Zugriff.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Einstellungen öffnen") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    DatePicker("Von", selection: $deleteFrom, displayedComponents: .date)
                    DatePicker("Bis", selection: $deleteTo, in: deleteFrom..., displayedComponents: .date)
                } header: {
                    Text("Zeitraum der zu löschenden Einträge")
                } footer: {
                    Text("Nur Einträge in diesem Zeitraum werden gelöscht.")
                }

                if sections.isEmpty {
                    Section {
                        Label("Keine beschreibbaren Kalender gefunden", systemImage: "calendar.badge.minus")
                            .foregroundStyle(.secondary)
                            .font(.footnote)
                    }
                } else {
                    ForEach(sections, id: \.title) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.calendars, id: \.calendarIdentifier) { cal in
                                Button {
                                    selectedCalendar = cal
                                    showConfirm = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(cgColor: cal.cgColor))
                                            .frame(width: 12, height: 12)
                                        Text(cal.title)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "trash")
                                            .foregroundStyle(.red)
                                            .font(.system(size: 13))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Kalendereinträge löschen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { requestAccess() }
        .confirmationDialog(
            "Kalendereinträge löschen",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) { deleteEvents() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            if let cal = selectedCalendar {
                Text("Alle Einträge aus „\(cal.title)" im gewählten Zeitraum werden unwiderruflich gelöscht.")
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                        Text("Wird gelöscht…").font(.subheadline)
                    }
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Fertig", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text("\(deletedCount) Kalendereinträge wurden gelöscht.")
        }
    }

    private func requestAccess() {
        if #available(iOS 17, *) {
            eventStore.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    accessGranted = granted
                    if granted { loadCalendars() } else { isLoading = false }
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async {
                    accessGranted = granted
                    if granted { loadCalendars() } else { isLoading = false }
                }
            }
        }
    }

    private func loadCalendars() {
        let cals = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }

        var dict: [String: [EKCalendar]] = [:]
        for cal in cals {
            let key = cal.source?.title ?? "Unbekannt"
            dict[key, default: []].append(cal)
        }

        sections = dict
            .map { (title: $0.key, calendars: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.title < $1.title }

        isLoading = false
    }

    private func deleteEvents() {
        guard let cal = selectedCalendar else { return }
        isDeleting = true

        DispatchQueue.global(qos: .userInitiated).async {
            let predicate = eventStore.predicateForEvents(
                withStart: deleteFrom,
                end: deleteTo,
                calendars: [cal]
            )
            let events = eventStore.events(matching: predicate)
            var count = 0
            for event in events {
                try? eventStore.remove(event, span: .thisEvent, commit: false)
                count += 1
            }
            try? eventStore.commit()

            DispatchQueue.main.async {
                deletedCount = count
                isDeleting = false
                showResult = true
            }
        }
    }
}
