import SwiftUI
import WidgetKit

private let widgetStore = UserDefaults(suiteName: "group.com.TorbenLehneke.BeeFocus-ofc")

struct WidgetEinstellungenView: View {
    @EnvironmentObject var todoStore: TodoStore
    @ObservedObject private var localizer = LocalizationManager.shared

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
                Picker(localizer.localizedString(forKey: "widget_displayed_tasks"), selection: $taskFilter) {
                    Label(localizer.localizedString(forKey: "widget_due_today"), systemImage: "sun.max.fill").tag("today")
                    Label(localizer.localizedString(forKey: "widget_high_priority"), systemImage: "exclamationmark.2").tag("priority")
                    Label(localizer.localizedString(forKey: "widget_all_open"), systemImage: "list.bullet").tag("all")
                }
                .pickerStyle(.navigationLink)

                Picker(localizer.localizedString(forKey: "widget_max_tasks"), selection: $maxTasks) {
                    Text(localizer.localizedString(forKey: "widget_tasks_3")).tag(3)
                    Text(localizer.localizedString(forKey: "widget_tasks_5")).tag(5)
                    Text(localizer.localizedString(forKey: "widget_tasks_8")).tag(8)
                }
                .pickerStyle(.navigationLink)
            } header: {
                Label(localizer.localizedString(forKey: "widget_tasks_header"), systemImage: "checklist")
            } footer: {
                Text(localizer.localizedString(forKey: "widget_tasks_footer"))
            }

            Section {
                Toggle(isOn: $showFocusMinutes) {
                    Label(localizer.localizedString(forKey: "widget_show_focus"), systemImage: "timer")
                }
                Toggle(isOn: $showOverdue) {
                    Label(localizer.localizedString(forKey: "widget_show_overdue"), systemImage: "exclamationmark.circle")
                }
                Toggle(isOn: $showWater) {
                    Label(localizer.localizedString(forKey: "widget_show_water"), systemImage: "drop.fill")
                }
            } header: {
                Label(localizer.localizedString(forKey: "widget_display_header"), systemImage: "eye")
            } footer: {
                Text(localizer.localizedString(forKey: "widget_display_footer"))
            }

            Section {
                HStack(spacing: 14) {
                    widgetPreview(locKey: "widget_small", icon: "s.square.fill")
                    widgetPreview(locKey: "widget_medium", icon: "m.square.fill")
                    widgetPreview(locKey: "widget_large", icon: "l.square.fill")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            } header: {
                Label(localizer.localizedString(forKey: "widget_preview_header"), systemImage: "rectangle.on.rectangle")
            } footer: {
                Text(localizer.localizedString(forKey: "widget_preview_footer"))
            }
        }
        .navigationTitle(localizer.localizedString(forKey: "widget_settings_title"))
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

    private func widgetPreview(locKey: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(localizer.localizedString(forKey: locKey))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
