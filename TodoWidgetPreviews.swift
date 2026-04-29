//
//  TodoWidgetPreviews.swift
//  BeeFocus_ofc
//
//  Widget-Vorschauen für verschiedene Szenarien
//  Created on 15.04.26.
//

import SwiftUI
import WidgetKit

// MARK: - Verschiedene Szenarien für Widget-Vorschauen

struct TodoWidgetPreviews {
    
    // Szenario 1: Wenige Aufgaben
    static let fewTasks = TodoWidgetEntry(
        date: Date(),
        dueTodayCount: 2,
        overdueCount: 0,
        totalOpenCount: 5
    )
    
    // Szenario 2: Viele überfällige Aufgaben (Warnung!)
    static let manyOverdue = TodoWidgetEntry(
        date: Date(),
        dueTodayCount: 3,
        overdueCount: 7,
        totalOpenCount: 15
    )
    
    // Szenario 3: Alles erledigt! 🎉
    static let allDone = TodoWidgetEntry(
        date: Date(),
        dueTodayCount: 0,
        overdueCount: 0,
        totalOpenCount: 0
    )
    
    // Szenario 4: Viele Aufgaben heute
    static let busyDay = TodoWidgetEntry(
        date: Date(),
        dueTodayCount: 12,
        overdueCount: 3,
        totalOpenCount: 25
    )
}

// MARK: - SwiftUI Preview Provider

#if DEBUG

// Small Widget Vorschauen
#Preview("Klein - Wenig", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.fewTasks
}

#Preview("Klein - Viel zu tun", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.busyDay
}

#Preview("Klein - Alles erledigt", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.allDone
}

// Medium Widget Vorschauen
#Preview("Mittel - Normal", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.fewTasks
}

#Preview("Mittel - Überfällige Aufgaben", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.manyOverdue
}

#Preview("Mittel - Alles erledigt", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.allDone
}

// Large Widget Vorschauen
#Preview("Groß - Normal", as: .systemLarge) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.fewTasks
}

#Preview("Groß - Viele Aufgaben", as: .systemLarge) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.busyDay
}

#Preview("Groß - Überfällig", as: .systemLarge) {
    TodoWidget()
} timeline: {
    TodoWidgetPreviews.manyOverdue
}

#endif

// MARK: - Widget-Design Notizen

/*
 
 FARBEN & DESIGN:
 ================
 
 Die Widgets verwenden aktuell einen gelb-orangen Farbverlauf.
 
 Sie können dies anpassen in TodoWidget.swift:
 
 1. Für ein blaues Design:
    .fill(LinearGradient(
        colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ))
 
 2. Für ein grünes Design:
    .fill(LinearGradient(
        colors: [Color.green.opacity(0.8), Color.mint.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ))
 
 3. Für Dark Mode Unterstützung:
    @Environment(\.colorScheme) var colorScheme
    
    .fill(LinearGradient(
        colors: colorScheme == .dark 
            ? [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]
            : [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ))
 
 WIDGET-GRÖSSEN:
 ===============
 
 ┌─────────────────────────────────────────┐
 │  SMALL (Klein)                          │
 │  ┌─────────┐                            │
 │  │    ✓    │  - Zeigt nur heute fällige │
 │  │   42    │    Aufgaben                │
 │  │ Aufgaben│  - Große Zahl im Fokus     │
 │  └─────────┘  - Minimalistisch          │
 └─────────────────────────────────────────┘
 
 ┌─────────────────────────────────────────┐
 │  MEDIUM (Mittel)                        │
 │  ┌─────────────────────┐                │
 │  │  Heute │ Überfällig │ Gesamt         │
 │  │   3    │     1      │   10           │
 │  └─────────────────────┘                │
 │  - Drei Kategorien                      │
 │  - Nebeneinander                        │
 │  - Übersichtlich                        │
 └─────────────────────────────────────────┘
 
 ┌─────────────────────────────────────────┐
 │  LARGE (Groß)                           │
 │  ┌───────────────────────────────────┐  │
 │  │  📋 Meine Aufgaben     15.04.2026 │  │
 │  │                                   │  │
 │  │  📅 Heute fällig            3     │  │
 │  │  ⚠️  Überfällig             1     │  │
 │  │  📝 Gesamt offen           10     │  │
 │  └───────────────────────────────────┘  │
 │  - Detaillierte Ansicht                 │
 │  - Mit Beschreibungen                   │
 │  - Datum angezeigt                      │
 └─────────────────────────────────────────┘
 
 SYMBOLE:
 ========
 
 Aktuell verwendete SF Symbols:
 - checklist: Haupt-Icon
 - calendar.badge.clock: Heute fällig
 - exclamationmark.triangle.fill: Überfällig
 - list.bullet.circle: Gesamt
 
 Alternative Symbole:
 - checkmark.circle: Erledigt
 - clock.fill: Zeit
 - calendar: Kalender
 - flag.fill: Priorität
 - star.fill: Favoriten
 
 */
