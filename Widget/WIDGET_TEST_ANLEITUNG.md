//
//  WIDGET_TEST_ANLEITUNG.md
//  BeeFocus_ofc
//
//  Wie Sie Ihre Widgets testen
//

# 🧪 Widget Testing Guide

## Methode 1: Xcode Previews (Empfohlen für schnelle Iterationen)

### Schritte:
1. Öffnen Sie `TodoWidgetDesignVariants.swift` oder `TodoWidget.swift`
2. Drücken Sie `⌥ + ⌘ + Return` (Option + Command + Enter)
3. Canvas öffnet sich rechts
4. Klicken Sie auf "Play" ▶️ bei einem Preview
5. Das Widget wird live angezeigt!

### Vorteile:
✅ Sofortige Aktualisierung bei Code-Änderungen
✅ Mehrere Größen gleichzeitig sehen
✅ Keine Installation nötig
✅ Sehr schnell

### Verschiedene Daten testen:
```swift
// In den Previews ändern Sie die Werte:
#Preview("Viele Aufgaben", as: .systemSmall) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now, 
        dueTodayCount: 15,    // ← Ändern Sie diese Werte
        overdueCount: 5,      // ← für verschiedene Szenarien
        totalOpenCount: 30
    )
}
```

---

## Methode 2: Widget im iOS Simulator

### Schritt 1: Widget Extension kompilieren

1. In Xcode oben links beim Scheme-Selector:
   - Klicken Sie auf das aktuelle Scheme
   - Wählen Sie **TodoWidget** (nicht die Haupt-App!)
   - Wählen Sie einen Simulator (z.B. iPhone 15 Pro)

2. Drücken Sie `⌘ + R` (Command + R) zum Starten

3. Xcode fragt: "Choose an app to run"
   - Wählen Sie Ihre **Haupt-App** (BeeFocus_ofc)
   - Widget wird installiert, aber App wird geöffnet

### Schritt 2: Widget zum Home-Screen hinzufügen

1. **Im Simulator**: Drücken Sie `⌘ + Shift + H` (zum Home-Screen)

2. **Bearbeitungsmodus aktivieren**:
   - Lange auf den Hintergrund klicken (mit Maus gedrückt halten)
   - Oder: Rechtsklick → "Edit Home Screen"

3. **Widget hinzufügen**:
   - Klicken Sie auf das **+** Symbol oben links
   - Scrollen Sie zu Ihrer App "BeeFocus_ofc" oder suchen Sie nach "Aufgaben"
   - Sie sehen: "Aufgaben-Übersicht"

4. **Größe wählen**:
   - Wischen Sie links/rechts für Small/Medium/Large
   - Klicken Sie "Add Widget"

5. **Fertig** (oben rechts)

### Schritt 3: Widget mit echten Daten testen

1. **Haupt-App öffnen** (im Simulator)
2. **Todos hinzufügen** mit verschiedenen Fälligkeitsdaten:
   ```
   - "Test 1" - Fällig: heute
   - "Test 2" - Fällig: heute
   - "Test 3" - Fällig: gestern (überfällig!)
   - "Test 4" - Fällig: morgen
   ```

3. **App schließen** (Home-Button: `⌘ + Shift + H`)

4. **Widget anschauen** - sollte jetzt zeigen:
   - Heute: 2
   - Überfällig: 1
   - Gesamt: 4 (wenn eine nicht erledigt ist)

---

## Methode 3: Widget auf echtem iPhone testen

### Voraussetzungen:
- iPhone mit iOS 17+
- Apple Developer Account (auch kostenlos möglich)
- iPhone mit Mac verbunden (USB oder WLAN)

### Schritte:

1. **iPhone auswählen**:
   - Xcode oben: Scheme → TodoWidget
   - Gerät: Ihr iPhone auswählen

2. **Signing konfigurieren**:
   - Target "TodoWidget" auswählen
   - Signing & Capabilities
   - Team auswählen
   - Bundle Identifier ggf. anpassen

3. **App installieren**:
   - `⌘ + R` drücken
   - App wird auf iPhone installiert

4. **Widget hinzufügen**:
   - Wie im Simulator (siehe oben)
   - Funktioniert genauso!

---

## Methode 4: Widget-Daten manuell testen (Debug)

### Test-Daten einfügen:

Erstellen Sie eine Test-Datei:

```swift
//  WidgetTestData.swift

#if DEBUG
import Foundation

extension TodoWidgetProvider {
    /// Testdaten für Entwicklung
    static func createTestData() {
        let testTodos = [
            TodoItem(title: "Test heute 1", dueDate: Date()),
            TodoItem(title: "Test heute 2", dueDate: Date()),
            TodoItem(title: "Test überfällig", dueDate: Date().addingTimeInterval(-86400)),
            TodoItem(title: "Test morgen", dueDate: Date().addingTimeInterval(86400)),
            TodoItem(title: "Ohne Datum"),
        ]
        
        WidgetDataManager.shared.saveTodos(testTodos)
    }
}
#endif
```

Dann in Ihrer Haupt-App (z.B. beim Start):

```swift
#if DEBUG
// Nur für Tests:
// TodoWidgetProvider.createTestData()
#endif
```

---

## Methode 5: Widget Live-Reload während Entwicklung

### Xcode Widget Scheme anpassen:

1. **Edit Scheme**:
   - Product → Scheme → Edit Scheme (oder `⌘ + <`)
   - Widget Extension auswählen

2. **Arguments hinzufügen**:
   - Run → Arguments
   - Environment Variables hinzufügen:
     - Name: `WIDGET_DEBUG`
     - Value: `1`

3. **Schnellere Updates**:

```swift
// In TodoWidget.swift - getTimeline Funktion:

#if DEBUG
// Im Debug-Modus: Aktualisierung alle 30 Sekunden
let nextUpdate = calendar.date(byAdding: .second, value: 30, to: currentDate)!
#else
// In Production: alle 15 Minuten
let nextUpdate = calendar.date(byAdding: .minute, value: 15, to: currentDate)!
#endif
```

---

## 🔍 Debugging-Tipps

### Widget zeigt keine Daten?

**1. Prüfen Sie UserDefaults:**

```swift
// In der Haupt-App oder Widget:
let defaults = UserDefaults(suiteName: "group.com.yourcompany.beefocus")
if let data = defaults?.data(forKey: "todos") {
    print("✅ Daten gefunden: \(data.count) bytes")
} else {
    print("❌ Keine Daten in App Group!")
}
```

**2. Prüfen Sie App Group:**

```swift
// Beide Targets müssen die GLEICHE App Group haben:
// Xcode → Target → Signing & Capabilities → App Groups
```

**3. Widget manuell aktualisieren:**

```swift
// In der Haupt-App nach jedem Update:
import WidgetKit
WidgetCenter.shared.reloadAllTimelines()
```

### Widget kompiliert nicht?

**Fehlende Abhängigkeiten:**
- Klicken Sie auf `TodoItem.swift` im Navigator
- File Inspector (rechts): Target Membership
- ✅ Aktivieren Sie die Checkbox für "TodoWidget"

Wiederholen für:
- SubTask.swift
- priority.swift
- Category.swift

---

## 📊 Test-Szenarien

### Szenario 1: Keine Aufgaben
```swift
TodoWidgetEntry(date: .now, dueTodayCount: 0, overdueCount: 0, totalOpenCount: 0)
```
**Erwartung**: Widget zeigt "0" überall

### Szenario 2: Normale Arbeitslast
```swift
TodoWidgetEntry(date: .now, dueTodayCount: 3, overdueCount: 1, totalOpenCount: 10)
```
**Erwartung**: 
- Heute: 3
- Überfällig: 1 (rot markiert)
- Gesamt: 10

### Szenario 3: Viele überfällige Aufgaben
```swift
TodoWidgetEntry(date: .now, dueTodayCount: 2, overdueCount: 15, totalOpenCount: 25)
```
**Erwartung**: Rote Warnung bei Überfällig

### Szenario 4: Extrem viele Aufgaben
```swift
TodoWidgetEntry(date: .now, dueTodayCount: 99, overdueCount: 50, totalOpenCount: 200)
```
**Erwartung**: Zahlen sollten lesbar bleiben

---

## 🎯 Checkliste vor Production

- [ ] Widget in allen drei Größen getestet
- [ ] Mit 0 Aufgaben getestet
- [ ] Mit vielen Aufgaben getestet (>50)
- [ ] Überfällige Aufgaben werden rot angezeigt
- [ ] App Group ID ist korrekt
- [ ] Widget aktualisiert sich bei App-Änderungen
- [ ] Widget funktioniert im Dark Mode
- [ ] Widget funktioniert im Light Mode
- [ ] Auf echtem Gerät getestet
- [ ] Performance ist gut (kein Lag beim Hinzufügen)

---

## ⚡ Schnell-Test

**Schnellster Weg zum Testen:**

1. Öffnen Sie `TodoWidgetDesignVariants.swift`
2. Drücken Sie `⌥ + ⌘ + Return`
3. Ändern Sie Werte in den Previews
4. Sehen Sie sofort das Ergebnis!

**Beispiel:**
```swift
#Preview("Mein Test", as: .systemMedium) {
    TodoWidget()
} timeline: {
    TodoWidgetEntry(
        date: .now,
        dueTodayCount: 7,     // ← Ändern Sie hier
        overdueCount: 3,      // ← und hier
        totalOpenCount: 15    // ← und hier
    )
}
```

Drücken Sie nach jeder Änderung `⌘ + S` zum Speichern, und die Preview aktualisiert sich automatisch! 🎉
