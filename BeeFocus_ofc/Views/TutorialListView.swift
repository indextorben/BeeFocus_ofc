import SwiftUI

struct TutorialListView: View {
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(TutorialData.all(localizer: localizer)) { tutorial in
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
