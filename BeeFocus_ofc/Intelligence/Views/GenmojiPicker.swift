//
//  GenmojiPicker.swift
//  BeeFocus_ofc
//
//  Genmoji als Kategorie-Symbol wählen. Es gibt keine eigenständige
//  Genmoji-Auswahl in iOS – der Weg führt über ein Textfeld, das adaptive
//  Bildglyphen unterstützt. Dort blendet die Tastatur den Genmoji-Bereich ein.
//

import SwiftUI
import UIKit

// MARK: - Textfeld, das Genmoji annimmt

/// Ein schmales Eingabefeld, das ausschließlich dazu dient, ein Genmoji
/// entgegenzunehmen. Sobald eines eingefügt wird, meldet es die Bilddaten.
struct GenmojiCaptureField: UIViewRepresentable {
    /// Liefert die Bilddaten des gewählten Genmoji und dessen Beschreibung.
    var onPick: (Data, String) -> Void
    /// Wird aufgerufen, wenn der Nutzer das Feld leert.
    var onClear: () -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        // Das schaltet den Genmoji-Bereich in der Tastatur frei.
        textView.supportsAdaptiveImageGlyph = true
        textView.font = .systemFont(ofSize: 34)
        textView.textAlignment = .center
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.isScrollEnabled = false
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onClear: onClear)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let onPick: (Data, String) -> Void
        private let onClear: () -> Void

        init(onPick: @escaping (Data, String) -> Void, onClear: @escaping () -> Void) {
            self.onPick = onPick
            self.onClear = onClear
        }

        func textViewDidChange(_ textView: UITextView) {
            let attributed = textView.attributedText ?? NSAttributedString()
            var found: NSAdaptiveImageGlyph?

            attributed.enumerateAttribute(
                .adaptiveImageGlyph,
                in: NSRange(location: 0, length: attributed.length)
            ) { value, _, stop in
                if let glyph = value as? NSAdaptiveImageGlyph {
                    found = glyph
                    stop.pointee = true
                }
            }

            guard let glyph = found else {
                // Kein Genmoji (mehr) im Feld.
                if attributed.length == 0 { onClear() }
                return
            }

            onPick(glyph.imageContent, glyph.contentDescription)
            // Feld wieder leeren, damit immer nur ein Symbol gewählt wird.
            textView.attributedText = NSAttributedString(string: "")
            textView.resignFirstResponder()
        }
    }
}

// MARK: - Normalisierung

enum GenmojiImage {
    /// Maximale Kantenlänge des gespeicherten Symbols.
    /// Genmoji-Originaldaten sind mehrere hundert Kilobyte groß und enthalten
    /// mehrere Auflösungen. Für ein Symbol in Icon-Größe genügt ein kleines
    /// PNG – das hält UserDefaults, CloudKit und den Widget-Snapshot schlank.
    static let maxDimension: CGFloat = 160

    /// Rechnet die Rohdaten eines Genmoji in ein kompaktes PNG um.
    /// Gibt `nil` zurück, wenn die Daten nicht als Bild lesbar sind.
    static func normalize(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }

        // Kleine Bilder unverändert lassen, sofern sie schon kompakt sind.
        if longestSide <= maxDimension, data.count <= 40_000 {
            return data
        }

        let scale = min(1, maxDimension / longestSide)
        let targetSize = CGSize(width: image.size.width * scale,
                                height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.pngData()
    }
}

// MARK: - Auswahl-Sheet

/// Sheet zum Setzen oder Entfernen des Kategorie-Symbols.
struct GenmojiPickerSheet: View {
    let categoryName: String
    let currentIcon: Data?
    /// `nil` bedeutet: Symbol entfernen.
    let onSelect: (Data?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localizer = LocalizationManager.shared
    @AppStorage("aktivesStatistikThema") private var aktivesThema: String = ""

    @State private var pickedData: Data?
    @State private var pickedDescription: String?
    @State private var isFieldActive = false

    private var accent: Color { AIAccent.color(for: aktivesThema) }
    private var previewData: Data? { pickedData ?? currentIcon }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackgroundView().ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        preview

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Text(localizer.localizedString(forKey: "genmoji_pick_title"))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                AIBadge(text: nil)
                            }

                            Text(localizer.localizedString(forKey: "genmoji_pick_hint"))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)

                            GenmojiCaptureField(
                                onPick: { data, description in
                                    // Direkt beim Auswählen auf Icon-Größe bringen.
                                    guard let compact = GenmojiImage.normalize(data) else { return }
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        pickedData = compact
                                        pickedDescription = description
                                    }
                                },
                                onClear: {}
                            )
                            .frame(height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.white.opacity(0.08))
                            )
                            .aiGlowBorder(cornerRadius: 14, lineWidth: 1, active: false)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.white.opacity(0.06))
                        )

                        if !AIFeature.isReady {
                            Text(localizer.localizedString(forKey: "genmoji_needs_ai"))
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizer.localizedString(forKey: "cancel")) { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.localizedString(forKey: "done")) {
                        if let pickedData {
                            onSelect(pickedData, pickedDescription)
                        }
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(pickedData == nil ? .white.opacity(0.35) : accent)
                    .disabled(pickedData == nil)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var preview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: 96, height: 96)

                if let previewData, let image = UIImage(data: previewData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }

            if previewData != nil {
                Button(role: .destructive) {
                    onSelect(nil, nil)
                    dismiss()
                } label: {
                    Text(localizer.localizedString(forKey: "genmoji_remove"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Anzeige-Baustein

/// Zeigt das Symbol einer Kategorie – Genmoji, falls vorhanden, sonst den Farbpunkt.
struct CategoryIconView: View {
    let category: Category
    var size: CGFloat = 18

    var body: some View {
        if let image = category.iconImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel(Text(category.iconDescription ?? category.name))
        } else {
            Circle()
                .fill(category.color)
                .frame(width: size * 0.78, height: size * 0.78)
                .accessibilityHidden(true)
        }
    }
}
