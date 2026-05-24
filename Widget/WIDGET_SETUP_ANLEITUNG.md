//
//  WIDGET_SETUP_ANLEITUNG.md
//  BeeFocus_ofc
//
//  Created on 15.04.26.
//

# Widget Setup Anleitung

## Schritt 1: Widget Extension in Xcode hinzufügen

1. Öffnen Sie Ihr Projekt in Xcode
2. Gehen Sie zu **File > New > Target**
3. Wählen Sie **Widget Extension**
4. Name: `TodoWidget`
5. Klicken Sie auf **Finish**
6. Wenn gefragt, aktivieren Sie **Activate scheme**

## Schritt 2: App Group erstellen

Um Daten zwischen der Haupt-App und dem Widget zu teilen, benötigen Sie eine App Group:

### Für die Haupt-App:
1. Wählen Sie Ihr **Haupt-App Target** aus
2. Gehen Sie zu **Signing & Capabilities**
3. Klicken Sie auf **+ Capability**
4. Wählen Sie **App Groups**
5. Klicken Sie auf **+** und erstellen Sie eine neue App Group:
   - Format: `group.com.IhrName.beefocus` (z.B. `group.com.torbenlehneke.beefocus`)
6. Aktivieren Sie die Checkbox für diese App Group

### Für das Widget:
1. Wählen Sie Ihr **Widget Extension Target** aus
2. Wiederholen Sie die Schritte 2-6 oben
3. **Wichtig:** Verwenden Sie die **gleiche App Group ID** wie in der Haupt-App!

## Schritt 3: App Group ID anpassen

Öffnen Sie `WidgetDataManager.swift` und ersetzen Sie:

```swift
private let appGroupIdentifier = "group.com.yourcompany.beefocus"
```

Mit Ihrer tatsächlichen App Group ID, z.B.:

```swift
private let appGroupIdentifier = "group.com.torbenlehneke.beefocus"
```

Das Gleiche in `TodoWidget.swift` in der Funktion `loadTodos()`:

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.torbenlehneke.beefocus")
```

## Schritt 4: TodoStore anpassen

Fügen Sie in Ihrem bestehenden `TodoStore` die Widget-Synchronisation hinzu.

Beispiel - fügen Sie diese Zeile hinzu, wenn Todos gespeichert werden:

```swift
// In Ihrer save() oder saveTodos() Methode:
WidgetDataManager.shared.saveTodos(todos)
```

Oder wenn Sie direkt nach jedem Update das Widget aktualisieren möchten:

```swift
// Nach jedem Update:
WidgetDataManager.shared.reloadWidgets()
```

## Schritt 5: Dateien zum Widget Target hinzufügen

Stellen Sie sicher, dass diese Dateien zum Widget Target gehören:

1. Klicken Sie auf `TodoItem.swift` im Navigator
2. Im File Inspector (rechts) unter **Target Membership**
3. Aktivieren Sie die Checkbox für Ihr **Widget Extension Target**

Wiederholen Sie dies für:
- `TodoItem.swift` ✅ (wichtig!)
- `Category.swift` (falls TodoItem darauf verweist)
- `TodoPriority.swift` (falls verwendet)
- `SubTask.swift` (falls verwendet)

## Schritt 6: Widget testen

1. Führen Sie die Haupt-App aus
2. Fügen Sie einige Todos mit verschiedenen Fälligkeitsdaten hinzu
3. Gehen Sie zum Home-Bildschirm
4. Halten Sie den Bildschirm gedrückt, um in den Bearbeitungsmodus zu gelangen
5. Tippen Sie auf das **+** Symbol oben links
6. Suchen Sie nach Ihrem Widget "Aufgaben-Übersicht"
7. Wählen Sie eine Größe (Small, Medium oder Large)
8. Fügen Sie das Widget hinzu

## Widget-Größen

### Small (Klein):
- Zeigt nur die Anzahl der heute fälligen Aufgaben
- Kompakt mit großer Zahl

### Medium (Mittel):
- Zeigt drei Kategorien:
  - Heute fällig
  - Überfällig
  - Gesamt offen

### Large (Groß):
- Ausführliche Ansicht mit Beschreibungen
- Alle drei Kategorien mit Icons und Details
- Datum der letzten Aktualisierung

## Troubleshooting

### Widget zeigt keine Daten:
1. Überprüfen Sie, ob die App Group IDs übereinstimmen
2. Stellen Sie sicher, dass `TodoItem.swift` zum Widget Target gehört
3. Überprüfen Sie, ob `WidgetDataManager.shared.saveTodos()` aufgerufen wird

### Widget aktualisiert sich nicht:
1. Fügen Sie `WidgetDataManager.shared.reloadWidgets()` nach jedem Update hinzu
2. Das Widget aktualisiert sich automatisch alle 15 Minuten

### Build-Fehler:
1. Stellen Sie sicher, dass alle benötigten Dateien zum Widget Target gehören
2. Überprüfen Sie, ob SwiftUI und WidgetKit importiert sind

## Erweiterte Anpassungen

### Farben anpassen:
In `TodoWidget.swift` können Sie die Farben ändern:

```swift
.fill(LinearGradient(
    colors: [Color.blue, Color.purple], // Ihre Farben hier
    startPoint: .topLeading,
    endPoint: .bottomTrailing
))
```

### Weitere Statistiken hinzufügen:
Erweitern Sie `TodoWidgetEntry` um neue Felder:

```swift
struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let dueTodayCount: Int
    let overdueCount: Int
    let totalOpenCount: Int
    let completedTodayCount: Int // Neu
}
```

### Deep Links zur App hinzufügen:
Fügen Sie zu den Widget-Views hinzu:

```swift
.widgetURL(URL(string: "beefocus://todos")!)
```

Dann können Sie in der Haupt-App auf diese URLs reagieren.
