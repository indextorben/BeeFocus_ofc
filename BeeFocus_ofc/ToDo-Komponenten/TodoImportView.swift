//
//  TodoImportView.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 17.10.25.
//

import SwiftUI
import UniformTypeIdentifiers

struct TodoImportView: UIViewControllerRepresentable {
    @ObservedObject var store: TodoStore

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var store: TodoStore
        
        init(store: TodoStore) { self.store = store }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                TodoImporter.importTodos(from: url, to: store)
            }
        }
    }
}
