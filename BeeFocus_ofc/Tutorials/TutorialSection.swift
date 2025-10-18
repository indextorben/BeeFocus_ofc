//
//  TutorialSection.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//
import SwiftUI

struct TutorialSection: Identifiable {
    let id = UUID()
    let heading: String
    let text: String
    let imageName: String?
    let videoName: String?
    let highlights: [String]?
    let highlightData: [String: SubFunctionData]?
    let bulletPoints: [String]?
}
