import SwiftUI
import AVKit

// MARK: - TutorialView
struct TutorialView: View {
    let section: TutorialSection
    let tutorialTitle: String
    
    // 🔹 Mapping von Highlights → SubFunctionData
    private var subFunctionMapping: [String: SubFunctionData] {
        var mapping: [String: SubFunctionData] = [:]
        if let highlights = section.highlights {
            for highlight in highlights {
                switch highlight {
                case "Titel & Beschreibung":
                    mapping[highlight] = SubFunctionData(
                        title: "Titel & Beschreibung",
                        text: """
                        Gib deiner Aufgabe einen aussagekräftigen Titel, der den Inhalt kurz beschreibt. Optional kannst du eine detaillierte Beschreibung hinzufügen, um wichtige Informationen zu notieren. So behältst du den Überblick und kannst Aufgaben leichter priorisieren.
                        """,
                        imageName: "tutorial_add_task_title",
                        videoName: "add_task_title_video",
                        bulletPoints: [
                            "Tippe auf den + Button, um eine neue Aufgabe zu erstellen",
                            "Gib einen prägnanten Titel ein",
                            "Optional: Füge eine Beschreibung hinzu",
                            "Achte auf Vollständigkeit und Verständlichkeit"
                        ]
                    )
                case "Unteraufgaben":
                    mapping[highlight] = SubFunctionData(
                        title: "Unteraufgaben erstellen",
                        text: "Füge Teilaufgaben hinzu, um komplexe Aufgaben zu strukturieren.",
                        imageName: "tutorial_subtasks",
                        videoName: "subtasks_video",
                        bulletPoints: ["Unteraufgaben hinzufügen", "Status verfolgen", "Abhaken"]
                    )
                default:
                    mapping[highlight] = SubFunctionData(
                        title: highlight,
                        text: "Hier kannst du die Unterfunktion \(highlight) erklären.",
                        imageName: nil,
                        videoName: nil,
                        bulletPoints: nil
                    )
                }
            }
        }
        return mapping
    }
    
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
                if let highlights = section.highlights {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Highlights")
                            .font(.headline)
                        
                        ForEach(highlights, id: \.self) { highlight in
                            if let data = subFunctionMapping[highlight] {
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
                if let bullets = section.bulletPoints {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Was du lernst")
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
                
                // MARK: Bild & Video
                if let imageName = section.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .shadow(radius: 4)
                }
                
                if let videoName = section.videoName,
                   let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 260)
                        .cornerRadius(16)
                        .shadow(radius: 4)
                }
            }
            .padding()
        }
        .navigationTitle(tutorialTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

struct SubFunctionView: View {
    let data: SubFunctionData
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(data.title)
                    .font(.largeTitle.bold())
                    .padding()
                
                Text(data.text)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                if let bullets = data.bulletPoints {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(bullets, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(point)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let imageName = data.imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                }
                
                if let videoName = data.videoName,
                   let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(height: 250)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, 20)
        }
        .navigationTitle(data.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}
