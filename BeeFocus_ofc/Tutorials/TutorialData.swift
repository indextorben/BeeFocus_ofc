//  TutorialData.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import SwiftUI
import AVKit

struct TutorialData {
    static let all: [TutorialItem] = {
        
        let titleDescriptionSubFunction = SubFunctionData(
            title: "Titel & Beschreibung",
            text: """
                Gib deiner Aufgabe einen aussagekräftigen Titel, der den Inhalt kurz beschreibt. Optional kannst du eine detaillierte Beschreibung hinzufügen, um wichtige Informationen zu notieren. So behältst du den Überblick und kannst Aufgaben leichter priorisieren.
                """,
            imageName: "tutorial_add_task_title",  // Bild aus Assets
            videoName: "add_task_title_video",     // Video aus Bundle (optional)
            bulletPoints: [
                "Tippe auf den + Button, um eine neue Aufgabe zu erstellen",
                "Gib einen prägnanten Titel ein",
                "Optional: Füge eine Beschreibung hinzu",
                "Achte auf Vollständigkeit und Verständlichkeit"
            ]
        )
        
        // MARK: - Section IDs definieren
        let addTaskSection = TutorialSection(
            heading: "Neue Aufgabe hinzufügen",
            text: "Tippe auf das + Symbol, um eine neue Aufgabe zu erstellen. Vergib einen Titel und optional eine Beschreibung.",
            imageName: "tutorial_add_task",
            videoName: "add_task_video",
            highlights: ["Titel & Beschreibung", "Kategorie auswählen", "Priorität wählen", "Fälligkeitsdatum setzen", "Unteraufgaben hinzufügen", "Kategorie wählen"],
            highlightTargets: [titleDescriptionSubFunction],
            bulletPoints: ["Drücke +", "Neue Aufgabe hinzufügen", "Titel eingeben", "Beschreibung hinzufügen", "Kategorie auswählen/ hinzufügen", "Priorität wählen", "Fälligkeitsdatum setzen", "gegebenfalls Unteraufgaben hinzufügen", "Speichern tippen"]
        )
        
        //Aufgabe bearbeiten
        let editTaskSection = TutorialSection(
            heading: "Aufgabe bearbeiten",
            text: "Drücke auf eine Aufgabe, um sie zu bearbeiten. Klicke erneut, um sie zu löschen.",
            imageName: "tutorial_edit_task",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints: ["Aufgabe auswählen", "Titel ändern", "Kategorie wechseln"]
        )
        
        let subTasksSection = TutorialSection(
            heading: "Unteraufgaben",
            text: "Füge Teilaufgaben hinzu, um komplexe Aufgaben zu strukturieren.",
            imageName: "tutorial_subtasks",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints: ["Unteraufgaben hinzufügen", "Status verfolgen", "Abhaken wenn erledigt"]
        )
        
        let shareTasksSection = TutorialSection(
            heading: "Aufgaben teilen & exportieren",
            text: "Teile Aufgaben mit Freunden oder exportiere sie als JSON-Datei.",
            imageName: "tutorial_share",
            videoName: "share_tasks_video",
            highlights: nil,
            highlightTargets: [],
            bulletPoints: ["Aufgabe auswählen", "Teilen/Exportieren", "Empfänger wählen"]
        )
        
        let darkModeSection = TutorialSection(
            heading: "Dark Mode & Themes",
            text: "Passe die App deinem Stil an mit Light- und Darkmode sowie Farbthemes.",
            imageName: "tutorial_theme",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints: ["Dark Mode aktivieren", "Farbtheme auswählen", "App-Stil speichern"]
        )
        
        let pomodoroSection = TutorialSection(
            heading: "Pomodoro-Timer",
            text: "Verwende das Pomodoro-System, um Aufgaben effizient zu erledigen.",
            imageName: "tutorial_pomodoro",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints:  []
        )
        
        let kategoriesSection = TutorialSection(
            heading: "Kategorien hinzufügen",
            text: "Verwende Kategorien, um Aufgaben besser zu organisieren.",
            imageName: "tutorial_kategorie",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints:  []
        )
        
        let settingsSection = TutorialSection(
            heading: "Einstellungen",
            text: "Ajustiere deine App-Einstellungen, wie z.B. das Dark Mode.",
            imageName: "tutorial_settings",
            videoName: nil,
            highlights: nil,
            highlightTargets: [],
            bulletPoints:  []
        )
        
        // MARK: - Highlights auf Ziel-Sections setzen
        var mutableAddTask = addTaskSection
        var mutableeditTask = editTaskSection
        var mutableSubTasks = subTasksSection
        var mutableShareTasks = shareTasksSection
        var mutablepomodoro = pomodoroSection
        var mutablekategories = kategoriesSection
        var mutablesettings = settingsSection
        var mutablesharetasks = shareTasksSection
        
        mutableAddTask.highlightTargets = [titleDescriptionSubFunction] // Beispiel
        mutableeditTask.highlightTargets = nil
        mutableSubTasks.highlightTargets = nil
        mutableShareTasks.highlightTargets = nil
        mutablepomodoro.highlightTargets = nil
        mutablekategories.highlightTargets = nil
        mutablesettings.highlightTargets = nil
        mutablesharetasks.highlightTargets = nil
        
        return [
            TutorialItem(
                title: "Aufgaben erstellen",
                sections: [mutableAddTask, mutableSubTasks]
            ),
            TutorialItem(
                title: "Aufgaben bearbeiten",
                sections: [mutableeditTask]
            ),
            TutorialItem(
                title: "Aufgaben teilen",
                sections: [mutablesharetasks]
            ),
            TutorialItem(
                title: "Kategorien",
                sections: [mutablekategories]
            ),
            TutorialItem(
                title: "Pomodoro Timer",
                sections: [mutablepomodoro]
            ),
            TutorialItem(
                title: "Einstellungen",
                sections: [mutablesettings]
            ),
            TutorialItem(
                title: "Tipps & Tricks",
                sections: [darkModeSection]
            )
        ]
    }()
}
