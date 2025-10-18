//
//  TutorialData.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import SwiftUI
import AVKit

struct TutorialData {
    static let all: [TutorialItem] = {
        
        // MARK: - SubFunctionData definieren
        let titleDescriptionSubFunction = SubFunctionData(
            title: "Titel & Beschreibung",
            text: """
                Gib deiner Aufgabe einen aussagekräftigen Titel, der den Inhalt kurz beschreibt. Optional kannst du eine detaillierte Beschreibung hinzufügen, um wichtige Informationen zu notieren. So behältst du den Überblick und kannst Aufgaben leichter priorisieren.
                """,
            imageName: "tutorial_add_task_title",
            videoName: "add_task_title_video",
            bulletPoints: [
                "Tippe auf den + Button, um eine neue Aufgabe zu erstellen",
                "Gib einen prägnanten Titel ein",
                "Optional: Füge eine Beschreibung hinzu",
                "Achte auf Vollständigkeit und Verständlichkeit"
            ]
        )
        
        let categorySubFunction = SubFunctionData(
            title: "Kategorie auswählen",
            text: "Füge deine Aufgabe zu einer bestehenden oder neuen Kategorie hinzu. So kannst du sie organisieren und nach Interessen filtern.",
            imageName: "tutorial_category",
            videoName: nil,
            bulletPoints: [
                "Tippe auf Kategorie, um eine vorhandene Kategorie auszuwählen oder auf Kategorie hinzufügen",
                "Wähle die Kategorie aus oder gebe einen Namen für die neue Kategorie"
            ]
        )
        
        let prioritySubFunction = SubFunctionData(
            title: "Priorität wählen",
            text: "Wähle eine Priorität für deine Aufgabe aus, um sie besser zu organisieren. So kannst du schnell erkennen, welche Aufgaben zuerst erledigt werden sollten.",
            imageName: "tutorial_priority",
            videoName: nil,
            bulletPoints: [
                "Drücke auf die Prioritätsebene, um sie auszuwählen",
            ]
        )
        
        let fälligkeitSubFunction = SubFunctionData(
            title: "Fälligkeitsdatum setzen",
            text: "Setze ein Fälligkeitsdatum für deine Aufgabe, damit du sie nicht vergessen musst. Das hilft dir, deine Aufgaben strukturierter zu halten und sicherzustellen, dass du nichts verpasst.",
            imageName: "tutorial_deadline",
            videoName: nil,
            bulletPoints: [
                "Fälligkeitsdatum aktivieren anklicken",
                "Datum und Uhrzeit auswählen"
            ]
        )
        
        let systemcalenderSubFunction = SubFunctionData(
            title: "Mit dem Systemkalender verbinden",
            text: "Verbinde deine Aufgaben mit deinem Systemkalender, damit du sie visuell auf dem Handy verfolgen kannst. Das ist praktisch, wenn du deine Aufgaben regelmäßig überprüfen möchtest.",
            imageName: "tutorial_integrate_calendar",
            videoName: nil,
            bulletPoints: [
                "Drücke den Schieberegler hinter 'In Systemkalender eintragen', um die Todo in dein Systemkalender einzutragen",
            ]
        )
        
        let unteraufgabenSubFunction = SubFunctionData(
            title: "Unteraufgaben hinzufügen",
            text: "Erstelle Unteraufgaben für deine Hauptaufgaben, um sie besser zu verwalten. So kannst du sie nach Fortschritt verfolgen und sicherzustellen, dass nichts übersehen wird.",
            imageName: "tutorial_subtasks",
            videoName: nil,
            bulletPoints: [
               "Neue Unteraufgabe hinzufügen",
               "+ Drücken"
            ]
        )
        
        let exporttodoSubFunction = SubFunctionData(
            title: "Exportieren in JSON Datei",
            text: "Exportiere deine Aufgaben einfach in deine Dateien auf dem Handy. Damit kannst du sie später noch einmal überprüfen oder sie an andere Stellen teilen. Es ist eine einfache Möglichkeit, deine Produktivität zu sichern.",
            imageName: nil,
            videoName: nil,
            bulletPoints: [
                "lange auf die Todo drücken",
                "Teilen auswählen",
                "Empfäger auswählen"
            ]
        )
        
        let sharetodoSubFunction = SubFunctionData(
            title: "Aufgaben teilen",
            text: "Teile deine Aufgaben mit Freunden oder Kollegen, indem du sie per E-Mail oder eine andere Plattform teilst. So kannst du gemeinsam an Projekten arbeiten und deine Ziele unterstützen.",
            imageName: "tutorial_share_todo",
            videoName: nil,
            bulletPoints: [
                "Aufgaben teilen",
                "Empfänger auswählen"
            ]
        )
        
        let importtodoSubFunction = SubFunctionData(
            title: "Aufgaben importieren",
            text: "Importiere Aufgaben aus anderen Productivity-Apps wie Todoist oder Asana. So kannst du deine Aufgaben aus anderen Quellen in dein System integrieren und weiterhin arbeiten.",
            imageName: "tutorial_import_todo",
            videoName: nil,
            bulletPoints: [
                "'+' oben Rechts drücken",
                "Auswahl treffen: „Importieren“",
                "Todo einfügen: meistens todo.json datei"
            ]
        )
        
        // MARK: - Section IDs definieren
        let addTaskSection = TutorialSection(
            heading: "Neue Aufgabe hinzufügen",
            text: "Tippe auf das + Symbol, um eine neue Aufgabe zu erstellen. Vergib einen Titel und optional eine Beschreibung.",
            imageName: "tutorial_add_task",
            videoName: "add_task_video",
            highlights: ["Titel & Beschreibung", "Kategorie auswählen", "Priorität wählen", "Fälligkeitsdatum setzen", "Systemkalender verbinden", "Unteraufgaben hinzufügen"],
            highlightData: [
                "Titel & Beschreibung": titleDescriptionSubFunction,
                "Kategorie auswählen": categorySubFunction,
                "Priorität wählen": prioritySubFunction,
                "Fälligkeitsdatum setzen": fälligkeitSubFunction,
                "Systemkalender verbinden": systemcalenderSubFunction,
                "Unteraufgaben hinzufügen": unteraufgabenSubFunction
            ],
            bulletPoints: [
                "Drücke +",
                "Neue Aufgabe hinzufügen",
                "Titel eingeben",
                "Beschreibung hinzufügen",
                "Kategorie auswählen/ hinzufügen",
                "Priorität wählen",
                "Fälligkeitsdatum setzen",
                "gegebenenfalls Unteraufgaben hinzufügen",
                "Speichern tippen"
            ]
        )
        
        let editTaskSection = TutorialSection(
            heading: "Aufgabe bearbeiten",
            text: "Drücke auf eine Aufgabe, um sie zu bearbeiten. Klicke erneut, um sie zu löschen.",
            imageName: "tutorial_edit_task",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: ["Aufgabe auswählen", "Beliebige Änderungen vornehmen", "Speichern"]
        )
        
        let subTasksSection = TutorialSection(
            heading: "Unteraufgaben",
            text: "Füge Teilaufgaben hinzu, um komplexe Aufgaben zu strukturieren.",
            imageName: "tutorial_subtasks",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: ["Unteraufgaben hinzufügen", "Status verfolgen", "Abhaken wenn erledigt"]
        )
        
        let shareTasksSection = TutorialSection(
            heading: "Aufgaben teilen & exportieren",
            text: "Teile Aufgaben mit Freunden oder exportiere sie als JSON-Datei.",
            imageName: "tutorial_share",
            videoName: "share_tasks_video",
            highlights: ["Todo exportieren", "Todo teilen", "Todo importieren"],
            highlightData: [
                "Todo exportieren": exporttodoSubFunction,
                "Todo teilen": sharetodoSubFunction,
                "Todo importieren": importtodoSubFunction
            ],
            bulletPoints: ["Todo lange gedrückt halten", "Teilen drücken", "Empfänger wählen", "Todo importieren", "Datei auswählen", "Import starten"]
        )
        
        let darkModeSection = TutorialSection(
            heading: "Dark Mode & Themes",
            text: "Passe die App deinem Stil an mit Light- und Darkmode sowie Farbthemes.",
            imageName: "tutorial_theme",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: ["Dark Mode aktivieren", "Farbtheme auswählen", "App-Stil speichern"]
        )
        
        let pomodoroSection = TutorialSection(
            heading: "Pomodoro-Timer",
            text: "Verwende das Pomodoro-System, um Aufgaben effizient zu erledigen.",
            imageName: "tutorial_pomodoro",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: []
        )
        
        let categoriesSection = TutorialSection(
            heading: "Kategorien hinzufügen",
            text: "Verwende Kategorien, um Aufgaben besser zu organisieren.",
            imageName: "tutorial_kategorie",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: []
        )
        
        let settingsSection = TutorialSection(
            heading: "Einstellungen",
            text: "Ajustiere deine App-Einstellungen, wie z.B. das Dark Mode.",
            imageName: "tutorial_settings",
            videoName: nil,
            highlights: nil,
            highlightData: [:],
            bulletPoints: []
        )
        
        // MARK: - TutorialItems zusammenstellen
        return [
            TutorialItem(title: "Aufgaben erstellen", sections: [addTaskSection]),
            TutorialItem(title: "Aufgaben bearbeiten", sections: [editTaskSection]),
            TutorialItem(title: "Unteraufgaben", sections: [subTasksSection]),
            TutorialItem(title: "Aufgaben teilen", sections: [shareTasksSection]),
            TutorialItem(title: "Dark Mode & Themes", sections: [darkModeSection]),
            TutorialItem(title: "Pomodoro Timer", sections: [pomodoroSection]),
            TutorialItem(title: "Kategorien", sections: [categoriesSection]),
            TutorialItem(title: "Einstellungen", sections: [settingsSection])
        ]
    }()
}
