import SwiftUI
import WidgetKit

private let widgetStore = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")

struct WidgetEinstellungenView: View {
    @EnvironmentObject var todoStore: TodoStore

    @State private var taskFilter: String = widgetStore?.string(forKey: "widgetTaskFilter") ?? "today"
    @State private var maxTasks: Int = {
        let v = widgetStore?.integer(forKey: "widgetMaxTasks") ?? 0
        return v == 0 ? 5 : v
    }()
    @State private var showFocusMinutes: Bool = widgetStore?.object(forKey: "widgetShowFocusMinutes") as? Bool ?? true
    @State private var showOverdue: Bool = widgetStore?.object(forKey: "widgetShowOverdue") as? Bool ?? true
    @State private var showWater: Bool = widgetStore?.object(forKey: "widgetShowWater") as? Bool ?? false

    var body: some View {
        List {
            Section {
                Picker("Angezeigte Aufgaben", selection: $taskFilter) {
                    Label("Heute fällig", systemImage: "sun.max.fill").tag("today")
                    Label("Hohe Priorität", systemImage: "exclamationmark.2").tag("priority")
                    Label("Alle offenen", systemImage: "list.bullet").tag("all")
                }
                .pickerStyle(.navigationLink)

                Picker("Max. Aufgaben", selection: $maxTasks) {
                    Text("3 Aufgaben").tag(3)
                    Text("5 Aufgaben").tag(5)
                    Text("8 Aufgaben").tag(8)
                }
                .pickerStyle(.navigationLink)
            } header: {
                Label("Aufgaben", systemImage: "checklist")
            } footer: {
                Text("Bestimmt, welche Aufgaben im mittleren und großen Widget erscheinen.")
            }

            Section {
                Toggle(isOn: $showFocusMinutes) {
                    Label("Fokuszeit anzeigen", systemImage: "timer")
                }
                Toggle(isOn: $showOverdue) {
                    Label("Überfällige anzeigen", systemImage: "exclamationmark.circle")
                }
                Toggle(isOn: $showWater) {
                    Label("Wasserstand anzeigen", systemImage: "drop.fill")
                }
            } header: {
                Label("Anzeige", systemImage: "eye")
            } footer: {
                Text("Gilt für das mittlere und große Widget.")
            }

            Section {
                HStack(spacing: 14) {
                    widgetPreview(size: "Klein", icon: "s.square.fill")
                    widgetPreview(size: "Mittel", icon: "m.square.fill")
                    widgetPreview(size: "Groß", icon: "l.square.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } header: {
                Label("Vorschau", systemImage: "rectangle.on.rectangle")
            } footer: {
                Text("Änderungen werden sofort auf dem Homescreen übernommen.")
            }
        }
        .navigationTitle("Widget-Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: taskFilter)      { _, _ in save() }
        .onChange(of: maxTasks)        { _, _ in save() }
        .onChange(of: showFocusMinutes){ _, _ in save() }
        .onChange(of: showOverdue)     { _, _ in save() }
        .onChange(of: showWater)       { _, _ in save() }
    }

    private func save() {
        widgetStore?.set(taskFilter, forKey: "widgetTaskFilter")
        widgetStore?.set(maxTasks, forKey: "widgetMaxTasks")
        widgetStore?.set(showFocusMinutes, forKey: "widgetShowFocusMinutes")
        widgetStore?.set(showOverdue, forKey: "widgetShowOverdue")
        widgetStore?.set(showWater, forKey: "widgetShowWater")
        todoStore.writeWidgetSnapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func widgetPreview(size: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(size)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
