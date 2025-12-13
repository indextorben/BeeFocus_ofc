//
//  FullAppTutorialView.swift
//  BeeFocus_ofc
//
//  Maxed-Out Tutorial
//

import SwiftUI
import AVKit

struct FullAppTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIndex = 0
    
    @ObservedObject private var localizer = LocalizationManager.shared
            let languages = ["Deutsch", "Englisch"]
    
    // MARK: - Alle Tutorial-Seiten
    private let pages: [TutorialPage] = [
        TutorialPage(title: "Willkommen bei BeeFocus!", description: "Hier erfährst du, wie du Aufgaben organisierst, den Pomodoro Timer nutzt und deine Produktivität maximierst.", imageName: "tutorial_intro"),
        
        TutorialPage(title: "Neue Aufgabe hinzufügen", description: "Tippe auf das + Symbol, um eine neue Aufgabe zu erstellen. Vergib einen Titel, Beschreibung und weise sie ggf. Kategorien zu.", imageName: "tutorial_add_task"),
        
        TutorialPage(title: "Titel & Beschreibung", description: "Gib deiner Aufgabe einen aussagekräftigen Titel und optional eine detaillierte Beschreibung. So behältst du den Überblick und kannst Aufgaben leichter priorisieren.", imageName: "tutorial_add_task_title", bulletPoints: [
            "Tippe auf + Button",
            "Titel eingeben",
            "Optional Beschreibung hinzufügen",
            "Auf Vollständigkeit achten"
        ]),
        
        TutorialPage(title: "Kategorie auswählen", description: "Füge deine Aufgabe zu einer bestehenden oder neuen Kategorie hinzu, um sie besser zu organisieren.", imageName: "tutorial_category", bulletPoints: [
            "Kategorie auswählen oder hinzufügen",
            "Einen Namen für die neue Kategorie eingeben"
        ]),
        
        TutorialPage(title: "Priorität wählen", description: "Setze die Priorität deiner Aufgabe (Niedrig, Mittel, Hoch), um deine Arbeit zu strukturieren.", imageName: "tutorial_priority", bulletPoints: [
            "Priorität auswählen",
            "Aufgaben filtern",
            "Effizient arbeiten"
        ]),
        
        TutorialPage(title: "Fälligkeitsdatum setzen", description: "Plane das Datum, an dem die Aufgabe erledigt sein soll.", imageName: "tutorial_due_date", bulletPoints: [
            "Datum auswählen",
            "Optional Erinnerungen aktivieren"
        ]),
        
        TutorialPage(title: "Unteraufgaben hinzufügen", description: "Unterteile komplexe Aufgaben in Teilaufgaben, um alles im Blick zu behalten.", imageName: "tutorial_subtasks", bulletPoints: [
            "Unteraufgaben hinzufügen",
            "Status verfolgen",
            "Abhaken wenn erledigt"
        ]),
        
        TutorialPage(title: "Aufgaben bearbeiten", description: "Drücke auf eine Aufgabe, um sie zu bearbeiten oder zu löschen.", imageName: "tutorial_edit_task", bulletPoints: [
            "Aufgabe auswählen",
            "Titel ändern",
            "Kategorie wechseln"
        ]),
        
        TutorialPage(title: "Aufgaben teilen & exportieren", description: "Teile Aufgaben mit Freunden oder exportiere sie als JSON-Datei.", imageName: "tutorial_share", bulletPoints: [
            "Aufgabe auswählen",
            "Teilen / Exportieren",
            "Empfänger wählen"
        ]),
        
        TutorialPage(title: "Pomodoro-Timer", description: "Nutze den Pomodoro-Timer, um fokussiert zu arbeiten und Pausen einzuplanen.", imageName: "tutorial_pomodoro", bulletPoints: [
            "Timer starten",
            "Arbeits- & Pausenintervalle einhalten",
            "Produktivität tracken"
        ]),
        
        TutorialPage(title: "Dark Mode & Themes", description: "Wähle Light oder Dark Mode und passe Farbthemes an.", imageName: "tutorial_theme", bulletPoints: [
            "Dark Mode aktivieren",
            "Farbtheme auswählen",
            "App-Stil speichern"
        ]),
        
        TutorialPage(title: "Kategorien verwalten", description: "Erstelle, bearbeite oder lösche Kategorien.", imageName: "tutorial_kategorie", bulletPoints: [
            "Kategorie erstellen",
            "Kategorie bearbeiten",
            "Kategorie löschen"
        ]),
        
        TutorialPage(title: "Einstellungen & Tipps", description: "Passe deine App an und finde zusätzliche Tipps.", imageName: "tutorial_settings", bulletPoints: [
            "Dark Mode aktivieren",
            "Sprache auswählen",
            "Benachrichtigungen konfigurieren",
            "Tutorial erneut anzeigen"
        ])
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $selectedIndex) {
                ForEach(pages.indices, id: \.self) { index in
                    TutorialPageView(page: pages[index])
                        .tag(index)
                        .padding(.horizontal)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .animation(.easeInOut, value: selectedIndex)
            
            // Weiter / Los geht's Button
            Button(action: {
                if selectedIndex < pages.count - 1 {
                    withAnimation { selectedIndex += 1 }
                } else {
                    dismiss()
                }
            }) {
                Text(selectedIndex < pages.count - 1 ? "Weiter" : "Los geht's!")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .shadow(radius: 5)
            }
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [Color.white, Color.blue.opacity(0.1)]),
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
    }
}

// MARK: - Einzelne Seite
struct TutorialPageView: View {
    let page: TutorialPage
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            if let imageName = page.imageName, !imageName.isEmpty {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .cornerRadius(20)
                    .shadow(radius: 8)
            }
            Text(page.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Bullet Points
            if let bullets = page.bulletPoints, !bullets.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(bullet)
                        }
                    }
                }
                .padding(.top, 10)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Modell
struct TutorialPage {
    let title: String
    let description: String
    let imageName: String?
    var bulletPoints: [String]? = nil
}
