//
//  AIStrings.swift
//  BeeFocus_ofc
//
//  Kurz-Helper für lokalisierte Texte der Intelligence-Features.
//

import Foundation

/// Kürzel für `LocalizationManager.shared.localizedString(forKey:)`.
@inline(__always)
func AIL(_ key: String) -> String {
    LocalizationManager.shared.localizedString(forKey: key)
}

/// Lokalisierter Text mit Platzhaltern (`%@`, `%d`).
@inline(__always)
func AIL(_ key: String, _ args: CVarArg...) -> String {
    String(format: LocalizationManager.shared.localizedString(forKey: key), arguments: args)
}

/// Einstiegsprüfung für alle Apple-Intelligence-Funktionen.
///
/// Die App unterstützt weiterhin iOS 18.5. Das Foundation-Models-Framework
/// gibt es erst ab iOS 26, darum laufen alle KI-Funktionen hinter dieser
/// Prüfung – auf älteren Systemen bleibt BeeFocus unverändert nutzbar.
@MainActor
enum AIFeature {
    /// Läuft das System neu genug für Apple Intelligence?
    static var isSupportedOS: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Ist Apple Intelligence tatsächlich einsatzbereit (Gerät, Einstellung, Modell)?
    static var isReady: Bool {
        if #available(iOS 26.0, *) {
            return AIAvailability.shared.isAvailable
        }
        return false
    }

    /// Lädt das Modell vor, falls möglich.
    static func prewarm() {
        if #available(iOS 26.0, *) {
            AIAvailability.shared.prewarm()
        }
    }

    /// Verfügbarkeit neu prüfen.
    static func refresh() {
        if #available(iOS 26.0, *) {
            AIAvailability.shared.refresh()
        }
    }
}
