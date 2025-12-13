import SwiftUI
import AVKit

// MARK: - TutorialView
struct TutorialView: View {
    let section: TutorialSection
    let tutorialTitle: String
    
    @ObservedObject private var localizer = LocalizationManager.shared
            let languages = ["Deutsch", "Englisch"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: Header
                Text(section.heading)
                    .font(.largeTitle.bold())
                    .padding(.bottom, 8)
                
                Text(section.text)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // MARK: Highlights
                if let highlights = section.highlights, let highlightData = section.highlightData {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlights")
                            .font(.headline)
                        
                        ForEach(highlights, id: \.self) { highlight in
                            if let data = highlightData[highlight] {
                                NavigationLink {
                                    SubFunctionView(data: data)
                                } label: {
                                    HStack {
                                        Image(systemName: "sparkles")
                                        Text(highlight)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Image(systemName: "arrow.right.circle.fill")
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.15))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                
                // MARK: Bullet Points
                if let bullets = section.bulletPoints, !bullets.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zusammenfassung")
                            .font(.headline)
                        
                        ForEach(bullets, id: \.self) { point in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title3)
                                    .foregroundColor(.green)
                                Text(point)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(tutorialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
