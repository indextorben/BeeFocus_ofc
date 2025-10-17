//
//  TodoShare.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 17.10.25.
//

import SwiftUI
import UIKit

struct TodoShare {
    static func share(todo: TodoItem) {
        guard let data = try? JSONEncoder().encode(todo) else { return }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("todo.json")
        try? data.write(to: url)
        
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}
