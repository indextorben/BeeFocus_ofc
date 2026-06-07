//
//  TutorialData.swift
//  BeeFocus_ofc
//

import SwiftUI

struct TutorialData {

    static func all(localizer: LocalizationManager = .shared) -> [TutorialItem] {
        let l = localizer
        func loc(_ k: String) -> String { l.localizedString(forKey: k) }

        // MARK: - 1. Aufgaben

        let aufgabenSection = TutorialSection(
            heading: loc("tut_sec_aufgaben_heading"),
            icon: "plus.circle.fill",
            text: loc("tut_sec_aufgaben_text"),
            highlights: [loc("tut_hl_schnell"), loc("tut_hl_titel_desc"), loc("tut_hl_kat_prio"), loc("tut_hl_datum"), loc("tut_hl_unteraufgaben"), loc("tut_hl_wiederholung")],
            highlightData: [
                loc("tut_hl_schnell"): SubFunctionData(title: loc("tut_sub_schnell_title"), text: loc("tut_sub_schnell_text"), bulletPoints: [loc("tut_sub_schnell_b1"), loc("tut_sub_schnell_b2"), loc("tut_sub_schnell_b3")]),
                loc("tut_hl_titel_desc"): SubFunctionData(title: loc("tut_sub_titel_title"), text: loc("tut_sub_titel_text"), bulletPoints: [loc("tut_sub_titel_b1"), loc("tut_sub_titel_b2"), loc("tut_sub_titel_b3")]),
                loc("tut_hl_kat_prio"): SubFunctionData(title: loc("tut_sub_katprio_title"), text: loc("tut_sub_katprio_text"), bulletPoints: [loc("tut_sub_katprio_b1"), loc("tut_sub_katprio_b2"), loc("tut_sub_katprio_b3")]),
                loc("tut_hl_datum"): SubFunctionData(title: loc("tut_sub_datum_title"), text: loc("tut_sub_datum_text"), bulletPoints: [loc("tut_sub_datum_b1"), loc("tut_sub_datum_b2"), loc("tut_sub_datum_b3")]),
                loc("tut_hl_unteraufgaben"): SubFunctionData(title: loc("tut_sub_unteraufg_title"), text: loc("tut_sub_unteraufg_text"), bulletPoints: [loc("tut_sub_unteraufg_b1"), loc("tut_sub_unteraufg_b2"), loc("tut_sub_unteraufg_b3")]),
                loc("tut_hl_wiederholung"): SubFunctionData(title: loc("tut_sub_wiederh_title"), text: loc("tut_sub_wiederh_text"), bulletPoints: [loc("tut_sub_wiederh_b1"), loc("tut_sub_wiederh_b2"), loc("tut_sub_wiederh_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_schnell"): "bolt.fill",
                loc("tut_hl_titel_desc"): "text.cursor",
                loc("tut_hl_kat_prio"): "tag.fill",
                loc("tut_hl_datum"): "calendar.badge.clock",
                loc("tut_hl_unteraufgaben"): "list.bullet.indent",
                loc("tut_hl_wiederholung"): "arrow.clockwise"
            ],
            bulletPoints: [loc("tut_sec_aufgaben_b1"), loc("tut_sec_aufgaben_b2"), loc("tut_sec_aufgaben_b3")]
        )

        // MARK: - 2. Ordner & Filter

        let ordnerSection = TutorialSection(
            heading: loc("tut_sec_ordner_heading"),
            icon: "folder.fill",
            text: loc("tut_sec_ordner_text"),
            highlights: [loc("tut_hl_std_ordner"), loc("tut_hl_eigene_ordner"), loc("tut_hl_suche_filter")],
            highlightData: [
                loc("tut_hl_std_ordner"): SubFunctionData(title: loc("tut_sub_std_ordner_title"), text: loc("tut_sub_std_ordner_text"), bulletPoints: [loc("tut_sub_std_ordner_b1"), loc("tut_sub_std_ordner_b2"), loc("tut_sub_std_ordner_b3"), loc("tut_sub_std_ordner_b4")]),
                loc("tut_hl_eigene_ordner"): SubFunctionData(title: loc("tut_sub_eigene_ordner_title"), text: loc("tut_sub_eigene_ordner_text"), bulletPoints: [loc("tut_sub_eigene_ordner_b1"), loc("tut_sub_eigene_ordner_b2"), loc("tut_sub_eigene_ordner_b3")]),
                loc("tut_hl_suche_filter"): SubFunctionData(title: loc("tut_sub_suche_title"), text: loc("tut_sub_suche_text"), bulletPoints: [loc("tut_sub_suche_b1"), loc("tut_sub_suche_b2"), loc("tut_sub_suche_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_std_ordner"): "folder.fill",
                loc("tut_hl_eigene_ordner"): "folder.badge.plus",
                loc("tut_hl_suche_filter"): "magnifyingglass"
            ],
            bulletPoints: [loc("tut_sec_ordner_b1"), loc("tut_sec_ordner_b2"), loc("tut_sec_ordner_b3")]
        )

        // MARK: - 3. Tagesplaner

        let tagesplanerSection = TutorialSection(
            heading: loc("tut_sec_tages_heading"),
            icon: "calendar.day.timeline.leading",
            text: loc("tut_sec_tages_text"),
            highlights: [loc("tut_hl_zeitplan"), loc("tut_hl_bausteine"), loc("tut_hl_ki_tagesplan")],
            highlightData: [
                loc("tut_hl_zeitplan"): SubFunctionData(title: loc("tut_sub_zeitplan_title"), text: loc("tut_sub_zeitplan_text"), bulletPoints: [loc("tut_sub_zeitplan_b1"), loc("tut_sub_zeitplan_b2"), loc("tut_sub_zeitplan_b3")]),
                loc("tut_hl_bausteine"): SubFunctionData(title: loc("tut_sub_bausteine_title"), text: loc("tut_sub_bausteine_text"), bulletPoints: [loc("tut_sub_bausteine_b1"), loc("tut_sub_bausteine_b2"), loc("tut_sub_bausteine_b3")]),
                loc("tut_hl_ki_tagesplan"): SubFunctionData(title: loc("tut_sub_ki_tagesplan_title"), text: loc("tut_sub_ki_tagesplan_text"), bulletPoints: [loc("tut_sub_ki_tagesplan_b1"), loc("tut_sub_ki_tagesplan_b2"), loc("tut_sub_ki_tagesplan_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_zeitplan"): "clock.fill",
                loc("tut_hl_bausteine"): "square.grid.2x2.fill",
                loc("tut_hl_ki_tagesplan"): "sparkles"
            ],
            bulletPoints: [loc("tut_sec_tages_b1"), loc("tut_sec_tages_b2"), loc("tut_sec_tages_b3")]
        )

        // MARK: - 4. Timer & Pomodoro

        let timerSection = TutorialSection(
            heading: loc("tut_sec_timer_heading"),
            icon: "timer",
            text: loc("tut_sec_timer_text"),
            highlights: [loc("tut_hl_timer_start"), loc("tut_hl_timer_modi"), loc("tut_hl_timer_atemub"), loc("tut_hl_timer_einstellungen")],
            highlightData: [
                loc("tut_hl_timer_start"): SubFunctionData(title: loc("tut_sub_timer_start_title"), text: loc("tut_sub_timer_start_text"), bulletPoints: [loc("tut_sub_timer_start_b1"), loc("tut_sub_timer_start_b2"), loc("tut_sub_timer_start_b3"), loc("tut_sub_timer_start_b4")]),
                loc("tut_hl_timer_modi"): SubFunctionData(title: loc("tut_sub_timer_modi_title"), text: loc("tut_sub_timer_modi_text"), bulletPoints: [loc("tut_sub_timer_modi_b1"), loc("tut_sub_timer_modi_b2"), loc("tut_sub_timer_modi_b3"), loc("tut_sub_timer_modi_b4")]),
                loc("tut_hl_timer_atemub"): SubFunctionData(title: loc("tut_sub_atemub_title"), text: loc("tut_sub_atemub_text"), bulletPoints: [loc("tut_sub_atemub_b1"), loc("tut_sub_atemub_b2"), loc("tut_sub_atemub_b3"), loc("tut_sub_atemub_b4")]),
                loc("tut_hl_timer_einstellungen"): SubFunctionData(title: loc("tut_sub_timer_einst_title"), text: loc("tut_sub_timer_einst_text"), bulletPoints: [loc("tut_sub_timer_einst_b1"), loc("tut_sub_timer_einst_b2"), loc("tut_sub_timer_einst_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_timer_start"): "play.circle.fill",
                loc("tut_hl_timer_modi"): "waveform.path",
                loc("tut_hl_timer_atemub"): "wind",
                loc("tut_hl_timer_einstellungen"): "slider.horizontal.3"
            ],
            bulletPoints: [loc("tut_sec_timer_b1"), loc("tut_sec_timer_b2"), loc("tut_sec_timer_b3")]
        )

        // MARK: - 5. Fokus-Modus

        let fokusSection = TutorialSection(
            heading: loc("tut_sec_fokus_heading"),
            icon: "brain.head.profile",
            text: loc("tut_sec_fokus_text"),
            highlights: [loc("tut_hl_fokus_start"), loc("tut_hl_fokus_ziel"), loc("tut_hl_fokus_websites"), loc("tut_hl_fokus_stats")],
            highlightData: [
                loc("tut_hl_fokus_start"): SubFunctionData(title: loc("tut_sub_fokus_start_title"), text: loc("tut_sub_fokus_start_text"), bulletPoints: [loc("tut_sub_fokus_start_b1"), loc("tut_sub_fokus_start_b2"), loc("tut_sub_fokus_start_b3")]),
                loc("tut_hl_fokus_ziel"): SubFunctionData(title: loc("tut_sub_fokus_ziel_title"), text: loc("tut_sub_fokus_ziel_text"), bulletPoints: [loc("tut_sub_fokus_ziel_b1"), loc("tut_sub_fokus_ziel_b2"), loc("tut_sub_fokus_ziel_b3"), loc("tut_sub_fokus_ziel_b4")]),
                loc("tut_hl_fokus_websites"): SubFunctionData(title: loc("tut_sub_fokus_web_title"), text: loc("tut_sub_fokus_web_text"), bulletPoints: [loc("tut_sub_fokus_web_b1"), loc("tut_sub_fokus_web_b2"), loc("tut_sub_fokus_web_b3")]),
                loc("tut_hl_fokus_stats"): SubFunctionData(title: loc("tut_sub_fokus_stats_title"), text: loc("tut_sub_fokus_stats_text"), bulletPoints: [loc("tut_sub_fokus_stats_b1"), loc("tut_sub_fokus_stats_b2"), loc("tut_sub_fokus_stats_b3"), loc("tut_sub_fokus_stats_b4")])
            ],
            highlightIcons: [
                loc("tut_hl_fokus_start"): "bolt.shield.fill",
                loc("tut_hl_fokus_ziel"): "target",
                loc("tut_hl_fokus_websites"): "shield.lefthalf.filled",
                loc("tut_hl_fokus_stats"): "chart.bar.fill"
            ],
            bulletPoints: [loc("tut_sec_fokus_b1"), loc("tut_sec_fokus_b2"), loc("tut_sec_fokus_b3")]
        )

        // MARK: - 6. Statistiken & Store

        let statistikSection = TutorialSection(
            heading: loc("tut_sec_stat_heading"),
            icon: "chart.bar.xaxis",
            text: loc("tut_sec_stat_text"),
            highlights: [loc("tut_hl_stat_produktiv"), loc("tut_hl_stat_achievements"), loc("tut_hl_stat_store")],
            highlightData: [
                loc("tut_hl_stat_produktiv"): SubFunctionData(title: loc("tut_sub_produktiv_title"), text: loc("tut_sub_produktiv_text"), bulletPoints: [loc("tut_sub_produktiv_b1"), loc("tut_sub_produktiv_b2"), loc("tut_sub_produktiv_b3"), loc("tut_sub_produktiv_b4")]),
                loc("tut_hl_stat_achievements"): SubFunctionData(title: loc("tut_sub_achiev_title"), text: loc("tut_sub_achiev_text"), bulletPoints: [loc("tut_sub_achiev_b1"), loc("tut_sub_achiev_b2"), loc("tut_sub_achiev_b3")]),
                loc("tut_hl_stat_store"): SubFunctionData(title: loc("tut_sub_store_title"), text: loc("tut_sub_store_text"), bulletPoints: [loc("tut_sub_store_b1"), loc("tut_sub_store_b2"), loc("tut_sub_store_b3"), loc("tut_sub_store_b4")])
            ],
            highlightIcons: [
                loc("tut_hl_stat_produktiv"): "gauge.with.dots.needle.67percent",
                loc("tut_hl_stat_achievements"): "medal.fill",
                loc("tut_hl_stat_store"): "storefront.fill"
            ],
            bulletPoints: [loc("tut_sec_stat_b1"), loc("tut_sec_stat_b2"), loc("tut_sec_stat_b3")]
        )

        // MARK: - 7. Wellness & Tracking

        let wellnessSection = TutorialSection(
            heading: loc("tut_sec_wellness_heading"),
            icon: "heart.fill",
            text: loc("tut_sec_wellness_text"),
            highlights: [loc("tut_hl_wasser"), loc("tut_hl_stimmung"), loc("tut_hl_schlaf"), loc("tut_hl_sport"), loc("tut_hl_gewohnheiten")],
            highlightData: [
                loc("tut_hl_wasser"): SubFunctionData(title: loc("tut_sub_wasser_title"), text: loc("tut_sub_wasser_text"), bulletPoints: [loc("tut_sub_wasser_b1"), loc("tut_sub_wasser_b2"), loc("tut_sub_wasser_b3"), loc("tut_sub_wasser_b4")]),
                loc("tut_hl_stimmung"): SubFunctionData(title: loc("tut_sub_stimmung_title"), text: loc("tut_sub_stimmung_text"), bulletPoints: [loc("tut_sub_stimmung_b1"), loc("tut_sub_stimmung_b2"), loc("tut_sub_stimmung_b3"), loc("tut_sub_stimmung_b4")]),
                loc("tut_hl_schlaf"): SubFunctionData(title: loc("tut_sub_schlaf_title"), text: loc("tut_sub_schlaf_text"), bulletPoints: [loc("tut_sub_schlaf_b1"), loc("tut_sub_schlaf_b2"), loc("tut_sub_schlaf_b3"), loc("tut_sub_schlaf_b4")]),
                loc("tut_hl_sport"): SubFunctionData(title: loc("tut_sub_sport_title"), text: loc("tut_sub_sport_text"), bulletPoints: [loc("tut_sub_sport_b1"), loc("tut_sub_sport_b2"), loc("tut_sub_sport_b3"), loc("tut_sub_sport_b4")]),
                loc("tut_hl_gewohnheiten"): SubFunctionData(title: loc("tut_sub_gewohnheiten_title"), text: loc("tut_sub_gewohnheiten_text"), bulletPoints: [loc("tut_sub_gewohnheiten_b1"), loc("tut_sub_gewohnheiten_b2"), loc("tut_sub_gewohnheiten_b3"), loc("tut_sub_gewohnheiten_b4")])
            ],
            highlightIcons: [
                loc("tut_hl_wasser"): "drop.fill",
                loc("tut_hl_stimmung"): "face.smiling.inverse",
                loc("tut_hl_schlaf"): "moon.zzz.fill",
                loc("tut_hl_sport"): "figure.run",
                loc("tut_hl_gewohnheiten"): "checkmark.circle.fill"
            ],
            bulletPoints: [loc("tut_sec_wellness_b1"), loc("tut_sec_wellness_b2"), loc("tut_sec_wellness_b3")]
        )

        // MARK: - 8. Journal & Reflexion

        let journalSection = TutorialSection(
            heading: loc("tut_sec_journal_heading"),
            icon: "book.closed.fill",
            text: loc("tut_sec_journal_text"),
            highlights: [loc("tut_hl_fokusjournal"), loc("tut_hl_dankbarkeit"), loc("tut_hl_braindump")],
            highlightData: [
                loc("tut_hl_fokusjournal"): SubFunctionData(title: loc("tut_sub_fokusjournal_title"), text: loc("tut_sub_fokusjournal_text"), bulletPoints: [loc("tut_sub_fokusjournal_b1"), loc("tut_sub_fokusjournal_b2"), loc("tut_sub_fokusjournal_b3"), loc("tut_sub_fokusjournal_b4")]),
                loc("tut_hl_dankbarkeit"): SubFunctionData(title: loc("tut_sub_dankbarkeit_title"), text: loc("tut_sub_dankbarkeit_text"), bulletPoints: [loc("tut_sub_dankbarkeit_b1"), loc("tut_sub_dankbarkeit_b2"), loc("tut_sub_dankbarkeit_b3")]),
                loc("tut_hl_braindump"): SubFunctionData(title: loc("tut_sub_braindump_title"), text: loc("tut_sub_braindump_text"), bulletPoints: [loc("tut_sub_braindump_b1"), loc("tut_sub_braindump_b2"), loc("tut_sub_braindump_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_fokusjournal"): "pencil.and.scribble",
                loc("tut_hl_dankbarkeit"): "heart.text.square.fill",
                loc("tut_hl_braindump"): "brain"
            ],
            bulletPoints: [loc("tut_sec_journal_b1"), loc("tut_sec_journal_b2"), loc("tut_sec_journal_b3")]
        )

        // MARK: - 9. Ziele & Planung

        let zieleSection = TutorialSection(
            heading: loc("tut_sec_ziele_heading"),
            icon: "target",
            text: loc("tut_sec_ziele_text"),
            highlights: [loc("tut_hl_langzeitziele"), loc("tut_hl_wochenziele"), loc("tut_hl_lernziele"), loc("tut_hl_eisenhower")],
            highlightData: [
                loc("tut_hl_langzeitziele"): SubFunctionData(title: loc("tut_sub_langzeit_title"), text: loc("tut_sub_langzeit_text"), bulletPoints: [loc("tut_sub_langzeit_b1"), loc("tut_sub_langzeit_b2"), loc("tut_sub_langzeit_b3")]),
                loc("tut_hl_wochenziele"): SubFunctionData(title: loc("tut_sub_wochenziel_title"), text: loc("tut_sub_wochenziel_text"), bulletPoints: [loc("tut_sub_wochenziel_b1"), loc("tut_sub_wochenziel_b2"), loc("tut_sub_wochenziel_b3")]),
                loc("tut_hl_lernziele"): SubFunctionData(title: loc("tut_sub_lernziele_title"), text: loc("tut_sub_lernziele_text"), bulletPoints: [loc("tut_sub_lernziele_b1"), loc("tut_sub_lernziele_b2"), loc("tut_sub_lernziele_b3")]),
                loc("tut_hl_eisenhower"): SubFunctionData(title: loc("tut_sub_eisenhower_title"), text: loc("tut_sub_eisenhower_text"), bulletPoints: [loc("tut_sub_eisenhower_b1"), loc("tut_sub_eisenhower_b2"), loc("tut_sub_eisenhower_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_langzeitziele"): "flag.2.crossed.fill",
                loc("tut_hl_wochenziele"): "calendar.badge.checkmark",
                loc("tut_hl_lernziele"): "graduationcap.fill",
                loc("tut_hl_eisenhower"): "square.grid.2x2.fill"
            ],
            bulletPoints: [loc("tut_sec_ziele_b1"), loc("tut_sec_ziele_b2"), loc("tut_sec_ziele_b3")]
        )

        // MARK: - 10. KI-Funktionen

        let kiSection = TutorialSection(
            heading: loc("tut_sec_ki_heading"),
            icon: "sparkles.rectangle.stack.fill",
            text: loc("tut_sec_ki_text"),
            highlights: [loc("tut_hl_ki_einrichten"), loc("tut_hl_ki_analyse"), loc("tut_hl_ki_zerteiler"), loc("tut_hl_ki_bericht"), loc("tut_hl_ki_reflexion"), loc("tut_hl_ki_strategie")],
            highlightData: [
                loc("tut_hl_ki_einrichten"): SubFunctionData(title: loc("tut_sub_ki_einrichten_title"), text: loc("tut_sub_ki_einrichten_text"), bulletPoints: [loc("tut_sub_ki_einrichten_b1"), loc("tut_sub_ki_einrichten_b2"), loc("tut_sub_ki_einrichten_b3"), loc("tut_sub_ki_einrichten_b4")]),
                loc("tut_hl_ki_analyse"): SubFunctionData(title: loc("tut_sub_ki_analyse_title"), text: loc("tut_sub_ki_analyse_text"), bulletPoints: [loc("tut_sub_ki_analyse_b1"), loc("tut_sub_ki_analyse_b2"), loc("tut_sub_ki_analyse_b3")]),
                loc("tut_hl_ki_zerteiler"): SubFunctionData(title: loc("tut_sub_ki_zerteiler_title"), text: loc("tut_sub_ki_zerteiler_text"), bulletPoints: [loc("tut_sub_ki_zerteiler_b1"), loc("tut_sub_ki_zerteiler_b2"), loc("tut_sub_ki_zerteiler_b3")]),
                loc("tut_hl_ki_bericht"): SubFunctionData(title: loc("tut_sub_ki_bericht_title"), text: loc("tut_sub_ki_bericht_text"), bulletPoints: [loc("tut_sub_ki_bericht_b1"), loc("tut_sub_ki_bericht_b2"), loc("tut_sub_ki_bericht_b3"), loc("tut_sub_ki_bericht_b4")]),
                loc("tut_hl_ki_reflexion"): SubFunctionData(title: loc("tut_sub_ki_reflexion_title"), text: loc("tut_sub_ki_reflexion_text"), bulletPoints: [loc("tut_sub_ki_reflexion_b1"), loc("tut_sub_ki_reflexion_b2"), loc("tut_sub_ki_reflexion_b3")]),
                loc("tut_hl_ki_strategie"): SubFunctionData(title: loc("tut_sub_ki_strategie_title"), text: loc("tut_sub_ki_strategie_text"), bulletPoints: [loc("tut_sub_ki_strategie_b1"), loc("tut_sub_ki_strategie_b2"), loc("tut_sub_ki_strategie_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_ki_einrichten"): "key.fill",
                loc("tut_hl_ki_analyse"): "wand.and.stars",
                loc("tut_hl_ki_zerteiler"): "scissors",
                loc("tut_hl_ki_bericht"): "doc.text.fill",
                loc("tut_hl_ki_reflexion"): "moon.stars.fill",
                loc("tut_hl_ki_strategie"): "lightbulb.fill"
            ],
            bulletPoints: [loc("tut_sec_ki_b1"), loc("tut_sec_ki_b2"), loc("tut_sec_ki_b3")]
        )

        // MARK: - 11. Einstellungen

        let einstellungenSection = TutorialSection(
            heading: loc("tut_sec_einst_heading"),
            icon: "gearshape.2.fill",
            text: loc("tut_sec_einst_text"),
            highlights: [loc("tut_hl_benachrichtigungen"), loc("tut_hl_themes"), loc("tut_hl_sync"), loc("tut_hl_sprache")],
            highlightData: [
                loc("tut_hl_benachrichtigungen"): SubFunctionData(title: loc("tut_sub_benachricht_title"), text: loc("tut_sub_benachricht_text"), bulletPoints: [loc("tut_sub_benachricht_b1"), loc("tut_sub_benachricht_b2"), loc("tut_sub_benachricht_b3"), loc("tut_sub_benachricht_b4")]),
                loc("tut_hl_themes"): SubFunctionData(title: loc("tut_sub_themes_title"), text: loc("tut_sub_themes_text"), bulletPoints: [loc("tut_sub_themes_b1"), loc("tut_sub_themes_b2"), loc("tut_sub_themes_b3"), loc("tut_sub_themes_b4")]),
                loc("tut_hl_sync"): SubFunctionData(title: loc("tut_sub_sync_title"), text: loc("tut_sub_sync_text"), bulletPoints: [loc("tut_sub_sync_b1"), loc("tut_sub_sync_b2"), loc("tut_sub_sync_b3"), loc("tut_sub_sync_b4")]),
                loc("tut_hl_sprache"): SubFunctionData(title: loc("tut_sub_sprache_title"), text: loc("tut_sub_sprache_text"), bulletPoints: [loc("tut_sub_sprache_b1"), loc("tut_sub_sprache_b2"), loc("tut_sub_sprache_b3")])
            ],
            highlightIcons: [
                loc("tut_hl_benachrichtigungen"): "bell.badge.fill",
                loc("tut_hl_themes"): "paintbrush.fill",
                loc("tut_hl_sync"): "icloud.and.arrow.up.fill",
                loc("tut_hl_sprache"): "globe"
            ],
            bulletPoints: [loc("tut_sec_einst_b1"), loc("tut_sec_einst_b2"), loc("tut_sec_einst_b3")]
        )

        // MARK: - 12. Teilen & Export

        let exportSection = TutorialSection(
            heading: loc("tut_sec_export_heading"),
            icon: "square.and.arrow.up.fill",
            text: loc("tut_sec_export_text"),
            highlights: [loc("tut_hl_export2"), loc("tut_hl_teilen"), loc("tut_hl_kalender_import")],
            highlightData: [
                loc("tut_hl_export2"): SubFunctionData(title: loc("tut_sub_export2_title"), text: loc("tut_sub_export2_text"), bulletPoints: [loc("tut_sub_export2_b1"), loc("tut_sub_export2_b2"), loc("tut_sub_export2_b3")]),
                loc("tut_hl_teilen"): SubFunctionData(title: loc("tut_sub_teilen_title"), text: loc("tut_sub_teilen_text"), bulletPoints: [loc("tut_sub_teilen_b1"), loc("tut_sub_teilen_b2"), loc("tut_sub_teilen_b3")]),
                loc("tut_hl_kalender_import"): SubFunctionData(title: loc("tut_sub_kalender_title"), text: loc("tut_sub_kalender_text"), bulletPoints: [loc("tut_sub_kalender_b1"), loc("tut_sub_kalender_b2"), loc("tut_sub_kalender_b3"), loc("tut_sub_kalender_b4")])
            ],
            highlightIcons: [
                loc("tut_hl_export2"): "square.and.arrow.up.fill",
                loc("tut_hl_teilen"): "person.2.fill",
                loc("tut_hl_kalender_import"): "calendar.badge.plus"
            ],
            bulletPoints: [loc("tut_sec_export_b1"), loc("tut_sec_export_b2"), loc("tut_sec_export_b3")]
        )

        // MARK: - Items

        return [
            TutorialItem(title: loc("tut_item_aufgaben"),      icon: "checklist",                      sections: [aufgabenSection]),
            TutorialItem(title: loc("tut_item_ordner"),         icon: "folder.fill",                    sections: [ordnerSection]),
            TutorialItem(title: loc("tut_item_tagesplaner"),    icon: "calendar.day.timeline.leading",  sections: [tagesplanerSection]),
            TutorialItem(title: loc("tut_item_timer"),          icon: "timer",                          sections: [timerSection]),
            TutorialItem(title: loc("tut_item_fokus"),          icon: "brain.head.profile",             sections: [fokusSection]),
            TutorialItem(title: loc("tut_item_statistik"),      icon: "chart.bar.xaxis",                sections: [statistikSection]),
            TutorialItem(title: loc("tut_item_wellness"),       icon: "heart.fill",                     sections: [wellnessSection]),
            TutorialItem(title: loc("tut_item_journal"),        icon: "book.closed.fill",               sections: [journalSection]),
            TutorialItem(title: loc("tut_item_ziele"),          icon: "target",                         sections: [zieleSection]),
            TutorialItem(title: loc("tut_item_ki"),             icon: "sparkles.rectangle.stack.fill",  sections: [kiSection]),
            TutorialItem(title: loc("tut_item_einstellungen"),  icon: "gearshape.2.fill",               sections: [einstellungenSection]),
            TutorialItem(title: loc("tut_item_export"),         icon: "square.and.arrow.up.fill",       sections: [exportSection])
        ]
    }
}
