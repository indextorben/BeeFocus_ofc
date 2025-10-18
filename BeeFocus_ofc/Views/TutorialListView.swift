import SwiftUI

struct TutorialListView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(TutorialData.all) { tutorial in
                    ForEach(tutorial.sections) { section in
                        NavigationLink(destination: TutorialView(section: section, tutorialTitle: tutorial.title)) {
                            Text(section.heading)
                                .font(.body)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Tutorials")
        }
    }
}
