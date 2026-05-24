import WidgetKit
import SwiftUI

@main
struct BeeFocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodoWidget()
        BeeFocusLockScreenWidget()
    }
}
