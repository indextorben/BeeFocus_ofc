import SwiftUI
import AVKit

struct TutorialView: View {
    let tutorial: TutorialItem
    @State private var selectedSection: TutorialSection?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    Text(tutorial.title)
                        .font(.largeTitle)
                        .bold()
                        .padding(.bottom, 10)
                    
                    ForEach(tutorial.sections) { section in
                        VStack(alignment: .leading, spacing: 15) {
                            Text(section.heading)
                                .font(.title2)
                                .bold()
                                .id(section.id)  // Scroll-Ziel
                            
                            Text(section.text)
                                .font(.body)
                            
                            // BulletPoints
                            if let bulletPoints = section.bulletPoints {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(bulletPoints, id: \.self) { point in
                                        HStack(alignment: .top) {
                                            Text("•")
                                            Text(point)
                                        }
                                    }
                                }
                                .padding(.leading, 10)
                            }
                            
                            // Highlights als Buttons
                            if let highlights = section.highlights,
                               let targets = section.highlightTargets,
                               highlights.count == targets.count {
                                HStack {
                                    ForEach(Array(highlights.enumerated()), id: \.offset) { index, highlight in
                                        Button(action: {
                                            withAnimation {
                                                proxy.scrollTo(targets[index], anchor: .top)
                                            }
                                        }) {
                                            Text(highlight)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.2))
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            
                            // Bild & Video
                            if let imageName = section.imageName {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                            if let videoName = section.videoName,
                               let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
                                VideoPlayer(player: AVPlayer(url: url))
                                    .frame(height: 250)
                                    .cornerRadius(12)
                                    .shadow(radius: 5)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }
}
