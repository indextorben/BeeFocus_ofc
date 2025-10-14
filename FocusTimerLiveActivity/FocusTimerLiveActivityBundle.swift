//
//  FocusTimerLiveActivityBundle.swift
//  FocusTimerLiveActivity
//
//  Created by Torben Lehneke on 10.10.25.
//

import WidgetKit
import SwiftUI

@main
struct FocusTimerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        FocusTimerLiveActivity()
        FocusTimerLiveActivityControl()
        FocusTimerLiveActivityLiveActivity()
    }
}
