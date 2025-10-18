import SwiftUI

struct TutorialListView: View {
    var body: some View {
        List {
            ForEach(TutorialData.all) { tutorial in
                Section(header: Text(tutorial.title).font(.headline)) {
                    ForEach(tutorial.sections) { section in
                        NavigationLink(destination: TutorialView(section: section, tutorialTitle: tutorial.title)) {
                            HStack {
                                // Vorschaubild der Section, falls vorhanden
                                if let imageName = section.imageName {
                                    Image(imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        .shadow(radius: 2)
                                }
                                
                                Text(section.heading)
                                    .font(.body)
                                    .padding(.leading, section.imageName != nil ? 10 : 0)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tutorials")
    }
}
