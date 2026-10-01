//
//  WritingToolsSupport.swift
//  BeeFocus_ofc
//
//  Aktiviert Apples Schreibwerkzeuge (Umschreiben, Korrektur, Zusammenfassen)
//  in den längeren Textfeldern der App.
//

import SwiftUI

extension View {
    /// Schaltet die volle Schreibwerkzeuge-Erfahrung frei, inklusive des
    /// eingeblendeten Bedienfelds. Auf älteren Systemen passiert nichts.
    @ViewBuilder
    func beeWritingTools() -> some View {
        if #available(iOS 18.0, *) {
            self.writingToolsBehavior(.complete)
        } else {
            self
        }
    }
}
