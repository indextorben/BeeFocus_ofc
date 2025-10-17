//
//  TutorialItem.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//
import SwiftUI

struct TutorialItem: Identifiable {
    let id = UUID()
    let title: String
    let sections: [TutorialSection]
}
