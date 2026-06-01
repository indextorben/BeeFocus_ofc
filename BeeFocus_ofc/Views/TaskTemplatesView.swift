import SwiftUI

struct TaskTemplatesView: View {
    @ObservedObject private var store = TaskTemplateStore.shared
    @EnvironmentObject var todoStore: TodoStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var showCreateSheet = false
    @State private var appliedTemplate: String? = nil

    private var accent: Color {
        aktivesThema.isEmpty ? Color(red: 0.55, green: 0.35, blue: 1.0) : appThemaFarben(aktivesThema).0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.14).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Intro
                        VStack(spacing: 8) {
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(accent)
                                .padding(.top, 8)
                            Text("Aufgaben-Vorlagen")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Wähle eine Vorlage und erstelle alle Aufgaben auf einmal")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }

                        if appliedTemplate != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Aufgaben wurden erstellt!")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.green.opacity(0.15), in: Capsule())
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Built-in templates
                        sectionHeader("Vorlagen")
                        ForEach(TaskTemplate.builtIn) { template in
                            TemplateCard(template: template, accent: accent) {
                                applyTemplate(template)
                            }
                            .padding(.horizontal, 20)
                        }

                        // Custom templates
                        if !store.customTemplates.isEmpty {
                            sectionHeader("Eigene Vorlagen")
                                .padding(.top, 4)
                            ForEach(store.customTemplates) { template in
                                TemplateCard(template: template, accent: accent, canDelete: true) {
                                    applyTemplate(template)
                                } onDelete: {
                                    store.delete(template)
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // Create custom
                        Button { showCreateSheet = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                Text("Eigene Vorlage erstellen")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.3), lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Vorlagen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateTemplateSheet(accent: accent)
            }
            .preferredColorScheme(.dark)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appliedTemplate)
        }
    }

    private func applyTemplate(_ template: TaskTemplate) {
        store.apply(template, to: todoStore)
        appliedTemplate = template.name
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            dismiss()
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Template Card

struct TemplateCard: View {
    let template: TaskTemplate
    let accent: Color
    var canDelete: Bool = false
    let onApply: () -> Void
    var onDelete: (() -> Void)? = nil

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: template.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(template.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("\(template.tasks.count) Aufgaben")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
            .padding(16)

            if expanded {
                Divider().background(.white.opacity(0.08)).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(template.tasks, id: \.title) { task in
                        HStack(spacing: 8) {
                            Circle().fill(template.color.opacity(0.7)).frame(width: 5, height: 5)
                            Text(task.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }

                    HStack(spacing: 10) {
                        Button(action: onApply) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Aufgaben erstellen")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(template.color, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        if canDelete, let del = onDelete {
                            Button(action: del) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.red.opacity(0.7))
                                    .padding(9)
                                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expanded)
    }
}

// MARK: - Create Template Sheet

struct CreateTemplateSheet: View {
    let accent: Color

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = TaskTemplateStore.shared

    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "purple"
    @State private var tasks: [String] = ["", ""]

    private let icons = ["star.fill", "bolt.fill", "flame.fill", "heart.fill", "leaf.fill",
                         "brain.head.profile", "pencil", "book.fill", "briefcase.fill",
                         "dumbbell.fill", "trophy.fill", "lightbulb.fill", "target", "list.bullet"]

    private func colorFor(_ n: String) -> Color {
        var t = TaskTemplate(name: "", icon: "", colorName: n, tasks: []); return t.color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.14).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Name
                        field("Name") {
                            TextField("z.B. Abendprogramm", text: $name)
                                .font(.system(size: 16))
                                .padding(12)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }

                        // Icon
                        field("Symbol") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                                ForEach(icons, id: \.self) { icon in
                                    Button { selectedIcon = icon } label: {
                                        Image(systemName: icon)
                                            .font(.system(size: 18))
                                            .foregroundStyle(selectedIcon == icon ? colorFor(selectedColor) : .white.opacity(0.5))
                                            .frame(height: 42)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(selectedIcon == icon ? colorFor(selectedColor).opacity(0.2) : Color.white.opacity(0.07))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Color
                        field("Farbe") {
                            HStack(spacing: 12) {
                                ForEach(["purple","blue","green","orange","red","yellow","cyan","teal"], id: \.self) { c in
                                    let col = colorFor(c)
                                    Button { selectedColor = c } label: {
                                        Circle().fill(col).frame(width: 30, height: 30)
                                            .overlay(Circle().stroke(.white, lineWidth: selectedColor == c ? 2.5 : 0))
                                            .shadow(color: col.opacity(0.5), radius: selectedColor == c ? 5 : 0)
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }

                        // Tasks
                        field("Aufgaben") {
                            VStack(spacing: 8) {
                                ForEach(tasks.indices, id: \.self) { i in
                                    HStack(spacing: 8) {
                                        TextField("Aufgabe \(i + 1)", text: $tasks[i])
                                            .font(.system(size: 14))
                                            .padding(10)
                                            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                                            .foregroundStyle(.white)
                                        if tasks.count > 1 {
                                            Button { tasks.remove(at: i) } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(.red.opacity(0.7))
                                            }
                                        }
                                    }
                                }
                                Button {
                                    tasks.append("")
                                } label: {
                                    Label("Aufgabe hinzufügen", systemImage: "plus")
                                        .font(.system(size: 13))
                                        .foregroundStyle(accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Vorlage erstellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }.foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveTemplate() }
                        .fontWeight(.semibold)
                        .foregroundStyle(name.isEmpty ? .gray : accent)
                        .disabled(name.isEmpty)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 2)
            content()
        }
    }

    private func saveTemplate() {
        let filteredTasks = tasks.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { TemplateTask(title: $0.trimmingCharacters(in: .whitespaces)) }
        guard !filteredTasks.isEmpty else { return }
        let template = TaskTemplate(
            name: name.trimmingCharacters(in: .whitespaces),
            icon: selectedIcon,
            colorName: selectedColor,
            tasks: filteredTasks
        )
        store.save(template)
        dismiss()
    }
}
