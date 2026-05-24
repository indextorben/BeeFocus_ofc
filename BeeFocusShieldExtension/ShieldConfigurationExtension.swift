import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private static let motivationsDE: [String] = [
        "Du bist stärker als jede Ablenkung. 💪",
        "Jede Minute Fokus bringt dich näher zu deinem Ziel. 🎯",
        "Dein zukünftiges Ich wird dir danken. 🌟",
        "Fokus ist die Superkraft der Erfolgreichen. ⚡",
        "Tiefe Arbeit schafft außergewöhnliche Ergebnisse. 🔥",
        "Ablenkungen sind der Feind des Fortschritts. 🛡️",
        "Kleine Schritte, großer Fortschritt – bleib dabei. 🚀",
        "Dein Potenzial wartet auf dich – hier und jetzt. ✨",
        "Wer fokussiert bleibt, gewinnt den Tag. 🏆",
        "Jetzt ist die Zeit für Fokus – Belohnungen kommen danach. 🎁",
        "Du baust gerade etwas Großartiges auf. 🏗️",
        "Konzentration ist die Brücke zwischen Träumen und Erfolg. 🌉",
        "Starke Menschen wählen Fokus über Ablenkung. 💎",
        "Halte durch – dein Ziel ist es wert. 🎖️",
        "Du bist im Flow – bleib drin! 🌊",
        "Jeder Moment der Konzentration zählt. ⏱️",
        "Die besten Ergebnisse entstehen durch ungeteilte Aufmerksamkeit. 🧠",
        "Erfolg beginnt mit dem Mut, sich zu konzentrieren. 🦁",
        "Ablenkung kostet Zeit. Fokus schafft Wert. ⚖️",
        "Du schaffst das! Bleib dran und ernte die Früchte deiner Arbeit. 🌱"
    ]

    private static let motivationsEN: [String] = [
        "You are stronger than any distraction. 💪",
        "Every minute of focus brings you closer to your goal. 🎯",
        "Your future self will thank you. 🌟",
        "Focus is the superpower of the successful. ⚡",
        "Deep work creates extraordinary results. 🔥",
        "Distractions are the enemy of progress. 🛡️",
        "Small steps, big progress – keep going. 🚀",
        "Your potential is waiting – right here, right now. ✨",
        "Those who stay focused win the day. 🏆",
        "Now is the time for focus – rewards come after. 🎁",
        "You are building something great right now. 🏗️",
        "Concentration is the bridge between dreams and success. 🌉",
        "Strong people choose focus over distraction. 💎",
        "Hold on – your goal is worth it. 🎖️",
        "You are in the flow – stay there! 🌊",
        "Every moment of concentration counts. ⏱️",
        "The best results come from undivided attention. 🧠",
        "Success begins with the courage to concentrate. 🦁",
        "Distraction costs time. Focus creates value. ⚖️",
        "You've got this! Stay on it and reap the rewards. 🌱"
    ]

    private static var isGerman: Bool {
        let preferred = Locale.preferredLanguages.first ?? "de"
        return preferred.hasPrefix("de")
    }

    private static var currentMotivation: String {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: Date())
        let minute = cal.component(.minute, from: Date())
        let list = isGerman ? motivationsDE : motivationsEN
        let slot = (hour * 2 + minute / 30) % list.count
        return list[slot]
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfig(appBlocked: true)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig(appBlocked: true)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfig(appBlocked: false)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig(appBlocked: false)
    }

    private func makeConfig(appBlocked: Bool) -> ShieldConfiguration {
        let background = UIColor(red: 0.06, green: 0.05, blue: 0.18, alpha: 1)
        let accent    = UIColor(red: 0.50, green: 0.22, blue: 1.00, alpha: 1)
        let gold      = UIColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1)
        let white     = UIColor.white
        let dimWhite  = UIColor.white.withAlphaComponent(0.78)

        let isDE = Self.isGerman
        let header = appBlocked
            ? (isDE ? "🔒 App gesperrt" : "🔒 App blocked")
            : (isDE ? "🔒 Website gesperrt" : "🔒 Website blocked")
        let buttonLabel = isDE ? "Fokus behalten" : "Stay focused"
        let subtitleText = "\(header)\n\n\(Self.currentMotivation)"

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: background,
            icon: UIImage(systemName: "bolt.shield.fill")?
                .withTintColor(gold, renderingMode: .alwaysOriginal)
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 58, weight: .bold)),
            title: ShieldConfiguration.Label(text: "BeeFocus", color: white),
            subtitle: ShieldConfiguration.Label(text: subtitleText, color: dimWhite),
            primaryButtonLabel: ShieldConfiguration.Label(text: buttonLabel, color: white),
            primaryButtonBackgroundColor: accent
        )
    }
}
