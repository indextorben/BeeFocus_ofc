//
//  AIPhotoToTodos.swift
//  BeeFocus_ofc
//
//  Whiteboard oder handschriftliche Liste abfotografieren – BeeFocus liest
//  den Text und macht daraus Aufgaben.
//

import Foundation
import UIKit
@preconcurrency import Vision

@MainActor
enum AIPhotoToTodos {

    /// Liest allen erkennbaren Text aus einem Bild.
    /// Läuft über Vision und funktioniert damit auch ohne Apple Intelligence.
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Handschrift und die Sprachen der App abdecken.
            request.recognitionLanguages = ["de-DE", "en-US", "fr-FR", "es-ES"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
