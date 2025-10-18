//
//  SubFunctionData.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import SwiftUI
import AVKit

struct SubFunctionData: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let bulletPoints: [String]?  // optionale Liste von Schritten
}
