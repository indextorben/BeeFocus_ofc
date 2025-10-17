import SwiftUI

struct TutorialListView: View {
    var body: some View {
        List(TutorialData.all) { tutorial in
            NavigationLink(destination: TutorialView(tutorial: tutorial)) {
                HStack {
                    // Verwende das erste Bild der ersten Section als Vorschaubild
                    if let imageName = tutorial.sections.first?.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    Text(tutorial.title)
                        .font(.headline)
                        .padding(.leading, tutorial.sections.first?.imageName != nil ? 10 : 0)
                }
            }
        }
        .navigationTitle("Tutorials")
    }
}
