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
                Picker("Displayed tasks", selection: $taskFilter) {
                    Label("Due today", systemImage: "sun.max.fill").tag("today")
                    Label("High priority", systemImage: "exclamationmark.2").tag("priority")
                    Label("All open", systemImage: "list.bullet").tag("all")
                }
                .pickerStyle(.navigationLink)

                Picker("Max. tasks", selection: $maxTasks) {
                    Text("3 tasks").tag(3)
                    Text("5 tasks").tag(5)
                    Text("8 tasks").tag(8)
                }
                .pickerStyle(.navigationLink)
            } header: {
                Label("Tasks", systemImage: "checklist")
            } footer: {
                Text("Determines which tasks appear in the medium and large widget.")
            }

            Section {
                Toggle(isOn: $showFocusMinutes) {
                    Label("Show focus time", systemImage: "timer")
                }
                Toggle(isOn: $showOverdue) {
                    Label("Show overdue", systemImage: "exclamationmark.circle")
                }
                Toggle(isOn: $showWater) {
                    Label("Show water level", systemImage: "drop.fill")
                }
            } header: {
                Label("Display", systemImage: "eye")
            } footer: {
                Text("Applies to the medium and large widget.")
            }

            Section {
                HStack(spacing: 14) {
                    widgetPreview(size: "Small", icon: "s.square.fill")
                    widgetPreview(size: "Medium", icon: "m.square.fill")
                    widgetPreview(size: "Large", icon: "l.square.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } header: {
                Label("Preview", systemImage: "rectangle.on.rectangle")
            } footer: {
                Text("Changes are applied to the home screen immediately.")
            }
        }
        .navigationTitle("Widget Settings")
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
