import SwiftUI
import AVKit

// MARK: - TutorialView
struct TutorialView: View {
    let section: TutorialSection
    let tutorialTitle: String

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

// MARK: - SubFunctionView
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
                
                // Bullet Points
                if let bullets = data.bulletPoints, !bullets.isEmpty {
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
                
                // Bild
                if let imageName = data.imageName, !imageName.isEmpty {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                }
                
                // Video
                if let videoName = data.videoName, !videoName.isEmpty,
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
