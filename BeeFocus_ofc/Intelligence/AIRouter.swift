//
//  AIRouter.swift
//  BeeFocus_ofc
//
//  Schaltstelle, über die Siri, Kurzbefehle, Widgets und Deep Links ein
//  Intelligence-Sheet in der App öffnen können.
//

import Foundation
import SwiftUI

@MainActor
final class AIRouter: ObservableObject {
    static let shared = AIRouter()

    enum Destination: String, Identifiable, Equatable {
        case voice
        case planner
        case coach
        /// "Schnell erfassen" – läuft auch ohne Apple Intelligence.
        case quickCapture

        var id: String { rawValue }
    }

    /// Wird von der UI beobachtet und nach dem Öffnen zurückgesetzt.
    @Published var pending: Destination?

    /// Wortlaut, mit dem der Tagesplaner vorbelegt wird – etwa der Satz, den
    /// der Nutzer gerade in "Schnell erfassen" gesprochen hat. Leer bedeutet:
    /// Der Planer startet mit leerem Feld.
    private(set) var plannerText: String = ""

    private init() {}

    func request(_ destination: Destination) {
        if destination != .planner { plannerText = "" }
        pending = destination
    }

    /// Öffnet den Tagesplaner und legt ihm diesen Text vor.
    func requestPlanner(with text: String) {
        plannerText = text
        pending = .planner
    }

    func clear() {
        pending = nil
    }
}
