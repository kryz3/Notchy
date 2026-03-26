import Foundation

enum AppLanguage: String, CaseIterable {
    case fr = "Français"
    case en = "English"
}

enum L {
    static var lang: AppLanguage = .fr

    // MARK: - Tabs
    static var calendar: String { lang == .fr ? "Calendrier" : "Calendar" }
    static var reminders: String { lang == .fr ? "Rappels" : "Reminders" }
    static var notes: String { lang == .fr ? "Notes" : "Notes" }
    static var terminal: String { lang == .fr ? "Terminal" : "Terminal" }

    // MARK: - Calendar
    static var today: String { lang == .fr ? "Aujourd'hui" : "Today" }
    static var todayShort: String { lang == .fr ? "Auj." : "Today" }
    static var noEvents: String { lang == .fr ? "Aucun événement" : "No events" }
    static var allDay: String { lang == .fr ? "Toute la journée" : "All day" }
    static var ongoing: String { lang == .fr ? "En cours" : "Now" }
    static var eventTitle: String { lang == .fr ? "Titre" : "Title" }
    static var add: String { lang == .fr ? "Ajouter" : "Add" }

    // MARK: - Reminders
    static var newReminder: String { lang == .fr ? "Nouveau rappel..." : "New reminder..." }
    static var allDone: String { lang == .fr ? "Tout est fait !" : "All done!" }
    static var openReminders: String { lang == .fr ? "Ouvre Rappels et crée une liste" : "Open Reminders and create a list" }
    static var accessRequired: String { lang == .fr ? "Accès aux rappels requis" : "Reminders access required" }
    static var openReminderApp: String { lang == .fr ? "Ouvrir Rappels" : "Open Reminders" }
    static var openSettings: String { lang == .fr ? "Ouvrir les Réglages" : "Open Settings" }

    // MARK: - Music
    static var nothingPlaying: String { lang == .fr ? "Rien en lecture" : "Nothing playing" }
    static var shuffle: String { lang == .fr ? "Aléatoire" : "Shuffle" }
    static var autoplay: String { lang == .fr ? "Lecture automatique" : "Autoplay" }
    static var shuffleMode: String { lang == .fr ? "Mode aléatoire" : "Shuffle mode" }
    static var orderUnavailable: String { lang == .fr ? "L'ordre de lecture\nn'est pas disponible" : "Play order\nis not available" }
    static var upNext: String { lang == .fr ? "À suivre" : "Up Next" }
    static var history: String { lang == .fr ? "Historique" : "History" }
    static var noHistory: String { lang == .fr ? "Pas encore d'historique" : "No history yet" }
    static var albumNotInLibrary: String { lang == .fr ? "Album non disponible\ndans la bibliothèque" : "Album not available\nin library" }
    static var playAll: String { lang == .fr ? "Tout lire" : "Play All" }
    static var playlist: String { lang == .fr ? "Liste de lecture" : "Playlist" }
    static var connected: String { lang == .fr ? "Connecté" : "Connected" }

    // MARK: - Notes
    static var drawMode: String { lang == .fr ? "Dessin" : "Draw" }
    static var textMode: String { lang == .fr ? "Texte" : "Text" }

    // MARK: - Settings
    static var settings: String { lang == .fr ? "Réglages" : "Settings" }
    static var appearance: String { lang == .fr ? "Apparence" : "Appearance" }
    static var language: String { lang == .fr ? "Langue" : "Language" }
    static var queueSize: String { lang == .fr ? "File d'attente" : "Queue size" }
    static var tracks: String { lang == .fr ? "morceaux" : "tracks" }
    static var musicHistory: String { lang == .fr ? "Historique musique" : "Music history" }
    static var terminalHistory: String { lang == .fr ? "Historique terminal" : "Terminal history" }
    static var launchAtLogin: String { lang == .fr ? "Lancer au démarrage" : "Launch at login" }
    static var quit: String { lang == .fr ? "Quitter Notchy" : "Quit Notchy" }
    static var createdBy: String { lang == .fr ? "Créé par" : "Created by" }

    // MARK: - Settings extra
    static var musicPlayer: String { lang == .fr ? "Lecteur musique" : "Music player" }

    // MARK: - Date locale
    static var dateLocale: Locale { Locale(identifier: lang == .fr ? "fr_FR" : "en_US") }
}
