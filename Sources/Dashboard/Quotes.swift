import Foundation

/// A small bundled quote list. Phase A keeps this in-source; a later phase can
/// swap in a JSON resource + optional remote refresh.
enum Quotes {
    struct Quote: Equatable {
        let text: String
        let author: String
    }

    static let all: [Quote] = [
        .init(text: "Simplicity is the ultimate sophistication.", author: "Leonardo da Vinci"),
        .init(text: "The details are not the details. They make the design.", author: "Charles Eames"),
        .init(text: "Make it work, make it right, make it fast.", author: "Kent Beck"),
        .init(text: "Perfection is achieved when there is nothing left to take away.", author: "Antoine de Saint-Exupéry"),
        .init(text: "Design is not just what it looks like. Design is how it works.", author: "Steve Jobs"),
        .init(text: "Programs must be written for people to read.", author: "Harold Abelson"),
        .init(text: "The best way to predict the future is to invent it.", author: "Alan Kay"),
        .init(text: "Focus is about saying no.", author: "Steve Jobs"),
        .init(text: "Do the hard jobs first. The easy jobs will take care of themselves.", author: "Dale Carnegie"),
        .init(text: "It always seems impossible until it's done.", author: "Nelson Mandela"),
    ]

    /// A quote that changes once per hour but stays stable within the hour.
    static func current(for date: Date = .now) -> Quote {
        let hours = Int(date.timeIntervalSince1970 / 3600)
        return all[hours % all.count]
    }
}
