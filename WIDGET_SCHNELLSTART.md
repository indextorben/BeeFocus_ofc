# 📱 Widget Schnellstart-Checkliste

## ✅ Setup-Schritte (in Xcode)

### 1. Widget Extension erstellen
- [ ] File → New → Target → Widget Extension
- [ ] Name: "TodoWidget" 
- [ ] Activate Scheme bestätigen

### 2. App Group einrichten

#### Haupt-App:
- [ ] Target auswählen (BeeFocus_ofc)
- [ ] Signing & Capabilities
- [ ] "+ Capability" → "App Groups"
- [ ] "+ App Group" → z.B. `group.com.torbenlehneke.beefocus`
- [ ] Checkbox aktivieren

#### Widget Extension:
- [ ] Target auswählen (TodoWidget)
- [ ] Signing & Capabilities
- [ ] "+ Capability" → "App Groups"
- [ ] **DIE GLEICHE** App Group auswählen
- [ ] Checkbox aktivieren

### 3. Dateien einbinden

Widget Extension Target Membership hinzufügen für:
- [ ] TodoItem.swift
- [ ] SubTask.swift
- [ ] priority.swift (TodoPriority)
- [ ] Category.swift (oder CategoryFallback.swift)

### 4. Code-Anpassungen

- [ ] `WidgetDataManager.swift` öffnen
- [ ] App Group ID anpassen (Zeile 16):
  ```swift
  private let appGroupIdentifier = "group.com.IHR-NAME.beefocus"
  ```

- [ ] `TodoWidget.swift` öffnen
- [ ] App Group ID anpassen (Zeile 43):
  ```swift
  let sharedDefaults = UserDefaults(suiteName: "group.com.IHR-NAME.beefocus")
  ```

### 5. TodoStore Integration

In Ihrer bestehenden `TodoStore.swift` oder `ToDoStore.swift`:

```swift
// Am Anfang der Datei importieren:
import WidgetKit

// In Ihrer saveTodos() Methode hinzufügen:
func saveTodos() {
    // Ihre bestehende Save-Logik...
    
    // NEU: Widget aktualisieren
    WidgetDataManager.shared.saveTodos(todos)
}
```

Oder verwenden Sie die bereitgestellten Extension-Methoden aus `TodoStore+Widget.swift`.

### 6. Testen

- [ ] Haupt-App ausführen
- [ ] Einige Todos mit Fälligkeitsdaten erstellen
- [ ] Home-Bildschirm öffnen
- [ ] Lange drücken → "+" oben links
- [ ] "Aufgaben-Übersicht" Widget suchen
- [ ] Widget in gewünschter Größe hinzufügen

---

## 🎨 Anpassungen (Optional)

### Farben ändern

In `TodoWidget.swift`, alle drei Views (`Small`, `Medium`, `Large`):

```swift
// Aktuell: Gelb-Orange
.fill(LinearGradient(
    colors: [Color.yellow.opacity(0.8), Color.orange.opacity(0.6)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
))

// Option 1: Blau
.fill(LinearGradient(
    colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
))

// Option 2: Grün
.fill(LinearGradient(
    colors: [Color.green.opacity(0.8), Color.mint.opacity(0.6)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
))

// Option 3: Lila
.fill(LinearGradient(
    colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.6)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
))
```

### Aktualisierungsintervall ändern

In `TodoWidget.swift`, Funktion `getTimeline`:

```swift
// Aktuell: alle 15 Minuten
let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!

// Häufiger: alle 5 Minuten
let nextUpdate = calendar.date(byAdding: .minute, value: 5, to: currentDate)!

// Seltener: jede Stunde
let nextUpdate = calendar.date(byAdding: .hour, value: 1, to: currentDate)!
```

⚠️ **Hinweis**: Häufigere Updates können die Batterie belasten!

### Deep Links hinzufügen

Um aus dem Widget zur App zu springen:

1. In `TodoWidget.swift`, zu den Views hinzufügen:
```swift
.widgetURL(URL(string: "beefocus://open")!)
```

2. In Ihrer Haupt-App (z.B. ContentView):
```swift
.onOpenURL { url in
    if url.scheme == "beefocus", url.host == "open" {
        // Zur Todo-Liste navigieren
    }
}
```

---

## 🐛 Fehlerbehebung

### Widget zeigt keine Daten

**Problem**: Widget bleibt leer oder zeigt nur Placeholder

**Lösung**:
1. App Group IDs überprüfen (müssen identisch sein!)
2. In Xcode: Clean Build Folder (⇧⌘K)
3. App und Widget neu compilieren
4. Widget vom Home-Screen entfernen und neu hinzufügen

### Widget aktualisiert sich nicht

**Problem**: Zahlen ändern sich nicht, wenn Todos geändert werden

**Lösung**:
```swift
// Nach JEDER Todo-Änderung aufrufen:
WidgetDataManager.shared.reloadWidgets()
```

### Build-Fehler: "Cannot find TodoItem in scope"

**Problem**: Widget findet TodoItem nicht

**Lösung**:
1. TodoItem.swift im Navigator anklicken
2. Rechte Seite: File Inspector
3. "Target Membership" überprüfen
4. Checkbox für Widget Extension aktivieren

### Widget zeigt alte Daten

**Problem**: Widget zeigt nicht die neuesten Todos

**Lösung**:
1. Sicherstellen, dass `saveTodos()` aufgerufen wird
2. Widget manuell aktualisieren:
   ```swift
   WidgetDataManager.shared.saveTodos(todos)
   WidgetDataManager.shared.reloadWidgets()
   ```

---

## 📊 Was die Widgets anzeigen

### Small (Klein)
- **Heute fällig**: Anzahl der Aufgaben mit Fälligkeitsdatum heute

### Medium (Mittel)  
- **Heute**: Aufgaben fällig heute
- **Überfällig**: Aufgaben deren Fälligkeitsdatum in der Vergangenheit liegt
- **Gesamt**: Alle nicht erledigten Aufgaben

### Large (Groß)
- Alle Informationen wie Medium, aber mit:
  - Icons und Beschreibungen
  - Aktuelles Datum
  - Größere, lesbarere Darstellung

---

## 🚀 Nächste Schritte

Nach erfolgreichem Setup können Sie:

1. **Weitere Statistiken hinzufügen**:
   - Heute erledigte Aufgaben
   - Diese Woche fällig
   - Aufgaben nach Priorität

2. **Interaktive Widgets** (iOS 17+):
   - Aufgaben direkt als erledigt markieren
   - Button zum Hinzufügen neuer Aufgaben

3. **Lock Screen Widgets**:
   - Kleine Circular/Rectangular Widgets
   - Für den Sperrbildschirm

4. **Live Activities** (optional):
   - Zeige aktive Pomodoro-Sessions
   - Countdown für nächste Aufgabe

---

## 📝 Notizen

- Widget-Daten werden in UserDefaults (App Group) gespeichert
- Maximum Update-Frequenz: iOS entscheidet, aber ~15min ist optimal
- Widgets können nicht unbegrenzt aktualisiert werden (System-Budget)
- Für Echtzeit-Updates: Live Activities verwenden
