import SwiftUI
import UIKit

struct TodoShare {
    static func share(todo: TodoItem) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            // Export als Array, weil Importer ein Array erwartet
            let data = try encoder.encode([todo])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("todo.json")
            try data.write(to: url)
            
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("❌ Fehler beim JSON-Export: \(error)")
        }
    }
}
