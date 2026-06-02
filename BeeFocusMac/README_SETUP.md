# BeeFocusMac – Xcode Setup

## 1. Neues macOS-Projekt erstellen

1. Xcode öffnen → **File → New → Project**
2. **macOS → App** auswählen
3. Einstellungen:
   - **Product Name:** `BeeFocusMac`
   - **Bundle Identifier:** `com.TorbenLehneke.BeeFocusMac`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - Kein Core Data, kein Tests-Target

## 2. Dateien hinzufügen

Alle Swift-Dateien aus diesem Ordner in das neue Xcode-Projekt ziehen:

```
BeeFocusMacApp.swift          → Ersetze die automatisch generierte App-Datei
Models/
  MacTodoItem.swift
  MacTodoStore.swift
Helpers/
  MacTimerManager.swift
Views/
  MenuBarContentView.swift
  TasksTabView.swift
  TimerTabView.swift
```

## 3. Deployment Target

- **Minimum Deployment:** macOS 13.0 (für `MenuBarExtra`)

## 4. Entitlements konfigurieren

1. In Xcode: Project → Target → **Signing & Capabilities**
2. **+ Capability** → **iCloud** hinzufügen
3. Haken bei **CloudKit**
4. Container: `iCloud.com.TorbenLehneke.BeeFocus` (muss derselbe wie in der iOS-App sein!)
5. Die Datei `BeeFocusMac.entitlements` als Entitlements-Datei des Targets setzen

## 5. Info.plist – App als MenuBar-Only

Füge in der **Info.plist** hinzu:
```xml
<key>LSUIElement</key>
<true/>
```
→ Verhindert, dass die App im Dock erscheint

## 6. Notifications-Permission

In `AppDelegate` oder `BeeFocusMacApp.init()`:
```swift
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
```

## 7. Build & Run

- Target: **My Mac**
- Das Bienen-Icon erscheint in der Menübar oben rechts
- Klick öffnet das Popover

## Sync mit iOS-App

Die App liest und schreibt direkt in denselben CloudKit-Container wie die iOS-App.
Änderungen auf dem Mac sind automatisch auf dem iPhone sichtbar (und umgekehrt).

**Voraussetzung:** Auf Mac und iPhone mit demselben iCloud-Account angemeldet.
