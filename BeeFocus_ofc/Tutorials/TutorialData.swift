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
            bulletPoints: [
                "Tippe auf den '+' Button, um eine neue Aufgabe zu erstellen",
                "Gib einen prägnanten Titel ein",
                "Optional: Füge eine Beschreibung hinzu",
                "Achte auf Vollständigkeit und Verständlichkeit"
            ]
        )
        
        let categorySubFunction = SubFunctionData(
            title: "Kategorie auswählen",
            text: "Füge deine Aufgabe zu einer bestehenden oder neuen Kategorie hinzu. So kannst du sie organisieren und nach Interessen filtern.",
            bulletPoints: [
                "Tippe auf Kategorie, um eine vorhandene Kategorie auszuwählen oder auf Kategorie hinzufügen",
                "Wähle die Kategorie aus oder gebe einen Namen für die neue Kategorie"
            ]
        )
        
        let prioritySubFunction = SubFunctionData(
            title: "Priorität wählen",
            text: "Wähle eine Priorität für deine Aufgabe aus, um sie besser zu organisieren. So kannst du schnell erkennen, welche Aufgaben zuerst erledigt werden sollten.",
            bulletPoints: [
                "Drücke auf die Prioritätsebene, um sie auszuwählen",
            ]
        )
        
        let fälligkeitSubFunction = SubFunctionData(
            title: "Fälligkeitsdatum setzen",
            text: "Setze ein Fälligkeitsdatum für deine Aufgabe, damit du sie nicht vergessen musst. Das hilft dir, deine Aufgaben strukturierter zu halten und sicherzustellen, dass du nichts verpasst.",
            bulletPoints: [
                "Fälligkeitsdatum aktivieren anklicken",
                "Datum und Uhrzeit auswählen"
            ]
        )
        
        let systemcalenderSubFunction = SubFunctionData(
            title: "Mit dem Systemkalender verbinden",
            text: "Verbinde deine Aufgaben mit deinem Systemkalender, damit du sie visuell auf dem Handy verfolgen kannst. Das ist praktisch, wenn du deine Aufgaben regelmäßig überprüfen möchtest.",
            bulletPoints: [
                "Drücke den Schieberegler hinter 'In Systemkalender eintragen', um die Todo in dein Systemkalender einzutragen",
            ]
        )
        
        let unteraufgabenSubFunction = SubFunctionData(
            title: "Unteraufgaben hinzufügen",
            text: "Erstelle Unteraufgaben für deine Hauptaufgaben, um sie besser zu verwalten. So kannst du sie nach Fortschritt verfolgen und sicherzustellen, dass nichts übersehen wird.",
            bulletPoints: [
               "Neue Unteraufgabe hinzufügen",
               "'+' Drücken"
            ]
        )
        
        let exporttodoSubFunction = SubFunctionData(
            title: "Exportieren in JSON Datei",
            text: "Exportiere deine Aufgaben einfach in deine Dateien auf dem Handy. Damit kannst du sie später noch einmal überprüfen oder sie an andere Stellen teilen. Es ist eine einfache Möglichkeit, deine Produktivität zu sichern.",
            bulletPoints: [
                "lange auf die Todo drücken",
                "Teilen auswählen",
                "Empfäger auswählen"
            ]
        )
        
        let sharetodoSubFunction = SubFunctionData(
            title: "Aufgaben teilen",
            text: "Teile deine Aufgaben mit Freunden oder Kollegen, indem du sie per E-Mail oder eine andere Plattform teilst. So kannst du gemeinsam an Projekten arbeiten und deine Ziele unterstützen.",
            bulletPoints: [
                "Aufgaben teilen",
                "Empfänger auswählen"
            ]
        )
        
        let importtodoSubFunction = SubFunctionData(
            title: "Aufgaben importieren",
            text: "Importiere Aufgaben aus anderen Productivity-Apps wie Todoist oder Asana. So kannst du deine Aufgaben aus anderen Quellen in dein System integrieren und weiterhin arbeiten.",
            bulletPoints: [
                "'+' oben Rechts drücken",
                "Auswahl treffen: „Importieren“",
                "Todo einfügen: meistens todo.json datei"
            ]
        )
        
        let pomodoroStartSubFunction = SubFunctionData(
            title: "Timer starten",
            text: "Starte den Pomodoro-Timer, um fokussiert für eine festgelegte Zeit zu arbeiten. Der Timer läuft automatisch ab und wechselt zur Pause.",
            bulletPoints: [
                "Tippe auf Start",
                "Konzentriere dich auf die Aufgabe",
                "Timer läuft automatisch ab"
            ]
        )

        let pomodoroPauseSubFunction = SubFunctionData(
            title: "Pause einlegen",
            text: "Nach jeder Fokusphase startet automatisch eine kurze Pause. Nutze sie zur Entspannung.",
            bulletPoints: [
                "Kurze Pause beginnt automatisch",
                "Entspanne dich",
                "Nach mehreren Runden folgt eine längere Pause"
            ]
        )

        let pomodoroSettingsSubFunction = SubFunctionData(
            title: "Timer anpassen",
            text: "Passe Fokus- und Pausenzeiten individuell an deine Bedürfnisse an. Diese können jederzeit angepasst werden.",
            bulletPoints: [
                "Gehe zu Einstellungen",
                "Lege Fokuszeit fest",
                "Lege Pausenlänge fest",
                "Speichern"
            ]
        )
        
        // MARK: - Section IDs definieren
        let addTaskSection = TutorialSection(
            heading: "Neue Aufgabe hinzufügen",
            text: "Tippe auf das + Symbol, um eine neue Aufgabe zu erstellen. Vergib einen Titel und optional eine Beschreibung.",
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
            highlights: nil,
            highlightData: [:],
            bulletPoints: ["Aufgabe auswählen", "Beliebige Änderungen vornehmen", "Speichern"]
        )
        
        let subTasksSection = TutorialSection(
            heading: "Unteraufgaben",
            text: "Füge Teilaufgaben hinzu, um komplexe Aufgaben zu strukturieren.",
            highlights: nil,
            highlightData: [:],
            bulletPoints: ["Unteraufgaben hinzufügen", "Status verfolgen", "Abhaken wenn erledigt"]
        )
        
        let shareTasksSection = TutorialSection(
            heading: "Aufgaben teilen & exportieren",
            text: "Teile Aufgaben mit Freunden oder exportiere sie als JSON-Datei.",
            highlights: ["Todo exportieren", "Todo teilen", "Todo importieren"],
            highlightData: [
                "Todo exportieren": exporttodoSubFunction,
                "Todo teilen": sharetodoSubFunction,
                "Todo importieren": importtodoSubFunction
            ],
            bulletPoints: ["Todo lange gedrückt halten", "Teilen drücken", "Empfänger wählen", "Todo importieren", "Datei auswählen", "Import starten"]
        )
        
        let pomodoroSection = TutorialSection(
            heading: "Pomodoro-Timer",
            text: "Nutze den Pomodoro-Timer, um konzentriert zu arbeiten und regelmäßige Pausen einzuhalten.",
            highlights: ["Timer starten", "Pause einlegen", "Timer anpassen"],
            highlightData: [
                "Timer starten": pomodoroStartSubFunction,
                "Pause einlegen": pomodoroPauseSubFunction,
                "Timer anpassen": pomodoroSettingsSubFunction
            ],
            bulletPoints: [
                "Starte den Timer",
                "Arbeite konzentriert",
                "Mache regelmäßige Pausen",
                "Steigere deine Produktivität"
            ]
        )
        
        let categoriesSection = TutorialSection(
            heading: "Kategorien verwalten",
            text: "Verwalte deine ganzen Kategorien. Du kannst neue erstellen oder bestehende bearbeiten.",
            highlights: nil,
            highlightData: [:],
            bulletPoints: [
                "Neue erstellen",
                "Bestehende bearbeiten"
            ]
        )
        
        // MARK: - TutorialItems zusammenstellen
        return [
            TutorialItem(title: "Aufgaben erstellen", sections: [addTaskSection]),
            TutorialItem(title: "Aufgaben bearbeiten", sections: [editTaskSection]),
            TutorialItem(title: "Unteraufgaben", sections: [subTasksSection]),
            TutorialItem(title: "Aufgaben teilen", sections: [shareTasksSection]),
            TutorialItem(title: "Pomodoro Timer", sections: [pomodoroSection]),
            TutorialItem(title: "Kategorien", sections: [categoriesSection]),
        ]
    }()
}
