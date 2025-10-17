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
        
        // MARK: - Section IDs definieren
        let addTaskSection = TutorialSection(
            heading: "Neue Aufgabe hinzufügen",
            text: "Tippe auf das + Symbol, um eine neue Aufgabe zu erstellen. Vergib einen Titel und optional eine Beschreibung.",
            imageName: "tutorial_add_task",
            videoName: "add_task_video",
            highlights: ["Unteraufgaben", "Priorität setzen"],
            highlightTargets: [], // wird unten gesetzt
            bulletPoints: ["+ Button drücken", "Titel eingeben", "Kategorie auswählen"]
        )
        
        //Aufgabe bearbeiten
        let editTaskSection = TutorialSection(
            heading: "Aufgabe bearbeiten",
            text: "Drücke auf eine Aufgabe, um sie zu bearbeiten. Klicke erneut, um sie zu löschen.",
            imageName: "tutorial_edit_task",
            videoName: nil,
            highlights: ["Aufgabe teilen & exportieren"],
            highlightTargets: [],
            bulletPoints: ["Aufgabe auswählen", "Titel ändern", "Kategorie wechseln"]
        )
        
        let subTasksSection = TutorialSection(
            heading: "Unteraufgaben",
            text: "Füge Teilaufgaben hinzu, um komplexe Aufgaben zu strukturieren.",
            imageName: "tutorial_subtasks",
            videoName: nil,
            highlights: ["Aufgabe teilen & exportieren"],
            highlightTargets: [],
            bulletPoints: ["Unteraufgaben hinzufügen", "Status verfolgen", "Abhaken wenn erledigt"]
        )
        
        let shareTasksSection = TutorialSection(
            heading: "Aufgaben teilen & exportieren",
            text: "Teile Aufgaben mit Freunden oder exportiere sie als JSON-Datei.",
            imageName: "tutorial_share",
            videoName: "share_tasks_video",
            highlights: ["Dark Mode & Themes"],
            highlightTargets: [],
            bulletPoints: ["Aufgabe auswählen", "Teilen/Exportieren", "Empfänger wählen"]
        )
        
        let darkModeSection = TutorialSection(
            heading: "Dark Mode & Themes",
            text: "Passe die App deinem Stil an mit Light- und Darkmode sowie Farbthemes.",
            imageName: "tutorial_theme",
            videoName: nil,
            highlights: nil,
            highlightTargets: nil,
            bulletPoints: ["Dark Mode aktivieren", "Farbtheme auswählen", "App-Stil speichern"]
        )
        
        // MARK: - Highlights auf Ziel-Sections setzen
        var mutableAddTask = addTaskSection
        var mutableeditTask = editTaskSection
        var mutableSubTasks = subTasksSection
        var mutableShareTasks = shareTasksSection
        
        mutableAddTask.highlightTargets = [subTasksSection.id, mutableAddTask.id] // Beispiel
        mutableeditTask.highlightTargets = nil
        mutableSubTasks.highlightTargets = [shareTasksSection.id]
        mutableShareTasks.highlightTargets = [darkModeSection.id]
        
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
                title: "Tipps & Tricks",
                sections: [mutableShareTasks, darkModeSection]
            )
        ]
    }()
}
