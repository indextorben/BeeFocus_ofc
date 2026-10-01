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

    enum Destination: String, Identifiable {
        case voice
        case planner
        case coach
        /// "Schnell erfassen" – läuft auch ohne Apple Intelligence.
        case quickCapture

        var id: String { rawValue }
    }

    /// Wird von der UI beobachtet und nach dem Öffnen zurückgesetzt.
    @Published var pending: Destination?

    private init() {}

    func request(_ destination: Destination) {
        pending = destination
    }

    func clear() {
        pending = nil
    }
}
