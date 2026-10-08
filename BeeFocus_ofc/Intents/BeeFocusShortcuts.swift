//
//  BeeFocusShortcuts.swift
//  BeeFocus_ofc
//
//  Sprachbefehle, die direkt nach der Installation funktionieren –
//  ohne dass der Nutzer erst einen Kurzbefehl anlegen muss.
//

import AppIntents

struct BeeFocusShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor { .orange }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Füge zu \(.applicationName) hinzu",
                "Neue Aufgabe in \(.applicationName)",
                "Neue Aufgabe mit \(.applicationName)",
                "Merk dir in \(.applicationName)",
                "Erinnere mich mit \(.applicationName)",
                "Notiere eine Aufgabe in \(.applicationName)",
                "\(.applicationName) Aufgabe anlegen",
                "\(.applicationName) Aufgabe hinzufügen",
                "Add a task to \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Aufgabe hinzufügen",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: QuickCaptureIntent(),
            phrases: [
                "Schnell erfassen in \(.applicationName)",
                "\(.applicationName) Schnellerfassung",
                "Quick capture in \(.applicationName)"
            ],
            shortTitle: "Schnell erfassen",
            systemImageName: "wand.and.stars"
        )

        AppShortcut(
            intent: TodaysFocusIntent(),
            phrases: [
                "Was ist heute wichtig in \(.applicationName)",
                "Zeig mir meinen Tag in \(.applicationName)",
                "\(.applicationName) Tagesübersicht"
            ],
            shortTitle: "Heute wichtig",
            systemImageName: "sun.max.fill"
        )

        AppShortcut(
            intent: StartFocusIntent(),
            phrases: [
                "Starte Fokus in \(.applicationName)",
                "\(.applicationName) Fokus starten",
                "Ich will mich konzentrieren mit \(.applicationName)"
            ],
            shortTitle: "Fokus starten",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: FocusStatusIntent(),
            phrases: [
                "Wie lange läuft der Fokus in \(.applicationName)",
                "\(.applicationName) Timer Status"
            ],
            shortTitle: "Timer-Status",
            systemImageName: "clock.badge.questionmark"
        )

        AppShortcut(
            intent: OpenBeeVoiceIntent(),
            phrases: [
                "Öffne Bee Voice in \(.applicationName)",
                "\(.applicationName) Sprachassistent",
                "Ich will mit \(.applicationName) sprechen"
            ],
            shortTitle: "Bee Voice",
            systemImageName: "waveform"
        )

        AppShortcut(
            intent: OpenDayPlannerIntent(),
            phrases: [
                "Plane meinen Tag mit \(.applicationName)",
                "\(.applicationName) Tagesplan erstellen"
            ],
            shortTitle: "Tag planen",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Ich habe Wasser getrunken in \(.applicationName)",
                "\(.applicationName) Wasser eintragen"
            ],
            shortTitle: "Wasser eintragen",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: BrainDumpIntent(),
            phrases: [
                "Notiere in \(.applicationName)",
                "\(.applicationName) Gedanken notieren"
            ],
            shortTitle: "Gedanke notieren",
            systemImageName: "brain.head.profile"
        )

        AppShortcut(
            intent: ToggleFocusModeIntent(),
            phrases: [
                "Fokusmodus in \(.applicationName)",
                "Blockiere Ablenkungen mit \(.applicationName)"
            ],
            shortTitle: "Fokusmodus",
            systemImageName: "shield.fill"
        )
    }
}
