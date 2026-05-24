import SwiftUI

struct WebsiteBlockCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let domains: [String]
}

let websiteBlockCategories: [WebsiteBlockCategory] = [
    WebsiteBlockCategory(
        name: "Social Media",
        icon: "bubble.left.and.bubble.right.fill",
        color: .pink,
        domains: [
            "instagram.com", "facebook.com", "twitter.com", "x.com",
            "tiktok.com", "snapchat.com", "pinterest.com", "threads.net",
            "reddit.com", "tumblr.com", "linkedin.com", "discord.com",
            "mastodon.social", "bsky.app"
        ]
    ),
    WebsiteBlockCategory(
        name: "Unterhaltung",
        icon: "play.rectangle.fill",
        color: .red,
        domains: [
            "youtube.com", "netflix.com", "twitch.tv", "primevideo.com",
            "disneyplus.com", "hulu.com", "vimeo.com", "dailymotion.com",
            "maxdome.de", "joyn.de", "ard-mediathek.de", "zdf.de",
            "rtl.de", "sat1.de"
        ]
    ),
    WebsiteBlockCategory(
        name: "Gaming",
        icon: "gamecontroller.fill",
        color: .green,
        domains: [
            "store.steampowered.com", "twitch.tv", "epicgames.com",
            "roblox.com", "minecraft.net", "ea.com", "ubisoft.com",
            "xbox.com", "playstation.com", "battle.net", "gog.com",
            "ign.com", "gamespot.com"
        ]
    ),
    WebsiteBlockCategory(
        name: "Nachrichten",
        icon: "newspaper.fill",
        color: .blue,
        domains: [
            "spiegel.de", "bild.de", "zeit.de", "focus.de", "faz.net",
            "sueddeutsche.de", "welt.de", "stern.de", "tagesschau.de",
            "cnn.com", "bbc.com", "nytimes.com", "theguardian.com",
            "derwesten.de", "heise.de"
        ]
    ),
    WebsiteBlockCategory(
        name: "Shopping",
        icon: "cart.fill",
        color: .orange,
        domains: [
            "amazon.de", "amazon.com", "ebay.de", "ebay.com",
            "zalando.de", "otto.de", "aboutyou.de", "asos.com",
            "aliexpress.com", "shein.com", "wish.com", "etsy.com",
            "mediamarkt.de", "saturn.de"
        ]
    ),
    WebsiteBlockCategory(
        name: "Musik & Podcasts",
        icon: "music.note",
        color: .purple,
        domains: [
            "spotify.com", "soundcloud.com", "deezer.com",
            "music.apple.com", "tidal.com", "bandcamp.com",
            "mixcloud.com", "audiomack.com"
        ]
    ),
    WebsiteBlockCategory(
        name: "Erwachsene",
        icon: "eye.slash.fill",
        color: .gray,
        domains: [
            "pornhub.com", "xvideos.com", "xhamster.com",
            "redtube.com", "youporn.com", "xnxx.com",
            "onlyfans.com", "livejasmin.com"
        ]
    ),
]
