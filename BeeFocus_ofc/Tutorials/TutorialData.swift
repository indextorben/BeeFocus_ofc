//
//  TutorialData.swift
//  BeeFocus_ofc
//
//  Created by Torben Lehneke on 18.10.25.
//

import SwiftUI
import AVKit

struct TutorialData {

    static func all(localizer: LocalizationManager = .shared) -> [TutorialItem] {

        // MARK: - SubFunctions

        let titleDescription = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_title_desc_title"),
            text: localizer.localizedString(forKey: "tutorial_title_desc_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_title_desc_b1"),
                localizer.localizedString(forKey: "tutorial_title_desc_b2"),
                localizer.localizedString(forKey: "tutorial_title_desc_b3"),
                localizer.localizedString(forKey: "tutorial_title_desc_b4")
            ]
        )

        let category = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_category_title"),
            text: localizer.localizedString(forKey: "tutorial_category_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_category_b1"),
                localizer.localizedString(forKey: "tutorial_category_b2")
            ]
        )

        let priority = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_priority_title"),
            text: localizer.localizedString(forKey: "tutorial_priority_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_priority_b1")
            ]
        )

        let dueDate = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_duedate_title"),
            text: localizer.localizedString(forKey: "tutorial_duedate_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_duedate_b1"),
                localizer.localizedString(forKey: "tutorial_duedate_b2")
            ]
        )

        let calendar = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_calendar_title"),
            text: localizer.localizedString(forKey: "tutorial_calendar_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_calendar_b1")
            ]
        )

        let subtasks = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_subtasks_title"),
            text: localizer.localizedString(forKey: "tutorial_subtasks_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_subtasks_b1"),
                localizer.localizedString(forKey: "tutorial_subtasks_b2")
            ]
        )

        let exportTodo = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_export_title"),
            text: localizer.localizedString(forKey: "tutorial_export_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_export_b1"),
                localizer.localizedString(forKey: "tutorial_export_b2"),
                localizer.localizedString(forKey: "tutorial_export_b3")
            ]
        )

        let shareTodo = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_share_title"),
            text: localizer.localizedString(forKey: "tutorial_share_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_share_b1"),
                localizer.localizedString(forKey: "tutorial_share_b2")
            ]
        )

        let importTodo = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_import_title"),
            text: localizer.localizedString(forKey: "tutorial_import_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_import_b1"),
                localizer.localizedString(forKey: "tutorial_import_b2"),
                localizer.localizedString(forKey: "tutorial_import_b3")
            ]
        )

        let pomodoroStart = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_pomo_start_title"),
            text: localizer.localizedString(forKey: "tutorial_pomo_start_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_pomo_start_b1"),
                localizer.localizedString(forKey: "tutorial_pomo_start_b2")
            ]
        )

        let pomodoroPause = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_pomo_pause_title"),
            text: localizer.localizedString(forKey: "tutorial_pomo_pause_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_pomo_pause_b1"),
                localizer.localizedString(forKey: "tutorial_pomo_pause_b2")
            ]
        )

        let pomodoroSettings = SubFunctionData(
            title: localizer.localizedString(forKey: "tutorial_pomo_settings_title"),
            text: localizer.localizedString(forKey: "tutorial_pomo_settings_text"),
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_pomo_settings_b1"),
                localizer.localizedString(forKey: "tutorial_pomo_settings_b2"),
                localizer.localizedString(forKey: "tutorial_pomo_settings_b3")
            ]
        )

        // MARK: - Sections

        let addTask = TutorialSection(
            heading: localizer.localizedString(forKey: "tutorial_add_heading"),
            text: localizer.localizedString(forKey: "tutorial_add_text"),
            highlights: [
                localizer.localizedString(forKey: "hl_title_desc"),
                localizer.localizedString(forKey: "hl_category"),
                localizer.localizedString(forKey: "hl_priority"),
                localizer.localizedString(forKey: "hl_duedate"),
                localizer.localizedString(forKey: "hl_calendar"),
                localizer.localizedString(forKey: "hl_subtasks")
            ],
            highlightData: [
                localizer.localizedString(forKey: "hl_title_desc"): titleDescription,
                localizer.localizedString(forKey: "hl_category"): category,
                localizer.localizedString(forKey: "hl_priority"): priority,
                localizer.localizedString(forKey: "hl_duedate"): dueDate,
                localizer.localizedString(forKey: "hl_calendar"): calendar,
                localizer.localizedString(forKey: "hl_subtasks"): subtasks
            ],
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_add_b1"),
                localizer.localizedString(forKey: "tutorial_add_b2"),
                localizer.localizedString(forKey: "tutorial_add_b3")
            ]
        )

        let shareSection = TutorialSection(
            heading: localizer.localizedString(forKey: "tutorial_share_section_heading"),
            text: localizer.localizedString(forKey: "tutorial_share_section_text"),
            highlights: [
                localizer.localizedString(forKey: "hl_export"),
                localizer.localizedString(forKey: "hl_share"),
                localizer.localizedString(forKey: "hl_import")
            ],
            highlightData: [
                localizer.localizedString(forKey: "hl_export"): exportTodo,
                localizer.localizedString(forKey: "hl_share"): shareTodo,
                localizer.localizedString(forKey: "hl_import"): importTodo
            ],
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_share_section_b1"),
                localizer.localizedString(forKey: "tutorial_share_section_b2")
            ]
        )

        let pomodoroSection = TutorialSection(
            heading: localizer.localizedString(forKey: "tutorial_pomo_heading"),
            text: localizer.localizedString(forKey: "tutorial_pomo_text"),
            highlights: [
                localizer.localizedString(forKey: "hl_pomo_start"),
                localizer.localizedString(forKey: "hl_pomo_pause"),
                localizer.localizedString(forKey: "hl_pomo_settings")
            ],
            highlightData: [
                localizer.localizedString(forKey: "hl_pomo_start"): pomodoroStart,
                localizer.localizedString(forKey: "hl_pomo_pause"): pomodoroPause,
                localizer.localizedString(forKey: "hl_pomo_settings"): pomodoroSettings
            ],
            bulletPoints: [
                localizer.localizedString(forKey: "tutorial_pomo_b1"),
                localizer.localizedString(forKey: "tutorial_pomo_b2")
            ]
        )

        // MARK: - Items

        return [
            TutorialItem(title: localizer.localizedString(forKey: "tutorial_item_tasks"), sections: [addTask]),
            TutorialItem(title: localizer.localizedString(forKey: "tutorial_item_share"), sections: [shareSection]),
            TutorialItem(title: localizer.localizedString(forKey: "tutorial_item_pomo"), sections: [pomodoroSection])
        ]
    }
}
