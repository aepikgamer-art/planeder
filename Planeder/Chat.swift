import Foundation

// MARK: - Chat models + story bank

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let date: Date
}

final class ChatStore: ObservableObject {
    static let shared = ChatStore()
    private let key = "planeder.chats"

    @Published private(set) var threads: [String: [ChatMessage]] = [:]

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [ChatMessage]].self, from: data) {
            threads = decoded
        }
    }

    func messages(for planeID: String) -> [ChatMessage] {
        threads[planeID] ?? []
    }

    func lastMessage(for planeID: String) -> ChatMessage? {
        messages(for: planeID).last
    }

    func seedStories(for plane: PlaneCard) {
        guard threads[plane.id] == nil else { return }
        let lines = StoryBank.stories(for: plane)
        let now = Date()
        threads[plane.id] = lines.enumerated().map { i, line in
            ChatMessage(id: UUID(), text: line, isUser: false, date: now.addingTimeInterval(-Double(lines.count - i) * 47))
        }
        save()
    }

    func send(_ text: String, to plane: PlaneCard) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var msgs = threads[plane.id] ?? []
        msgs.append(ChatMessage(id: UUID(), text: trimmed, isUser: true, date: Date()))
        threads[plane.id] = msgs
        save()
    }

    func removeThread(for planeID: String) {
        threads.removeValue(forKey: planeID)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(threads) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

/// Plane "stories": a few canned opener messages per plane, picked by
/// aircraft type + registration so each plane feels different.
enum StoryBank {

    static let byType: [(keyword: String, lines: [String])] = [
        ("a380", [
            "i'm literally the biggest thing in the sky 😌",
            "double deck energy, no one matches me",
            "they call me the superjumbo for a reason 👀",
            "gate too small for my personality fr"
        ]),
        ("747", [
            "queen of the skies, seeking co-pilot 👑",
            "that hump? all natural baby",
            "8 engines of charm. wait no. 4. 4 engines 💀",
            "been hauling hearts since 1970"
        ]),
        ("787", [
            "i'm called the Dreamliner but you're the dream 💅",
            "made of plastic but my feelings are real",
            "longest range in my fleet, longest crush too",
            "carbon fiber body, zero emotional baggage"
        ]),
        ("350", [
            "new gen jet, new gen love ✨",
            "carbon wings, carbon chemistry",
            "i cruise at mach 0.89 but fell fast tbh",
            "quiet cabin, louder heart"
        ]),
        ("777", [
            "triple seven. lucky in love? we'll see 🎰",
            "biggest engines in the game, humble brag",
            "i only do ultra long haul relationships",
            "ETOPS certified to fly far from land, not far from you"
        ]),
        ("737", [
            "short hops are my love language",
            "you've probably seen me at every airport ever",
            "longest relationship i've had was a 6hr flight to Hawaii",
            "i'm the worldwide side piece of airlines 💀"
        ]),
        ("320", [
            "i'm the one you see every day and you're still not over me",
            "on-time performance: 62%. love performance: 100%",
            "neo? more like neo-niverse, i'm outta this world",
            "sharklets so i can swim thru your dms"
        ]),
        ("dash 8", [
            "prop me up 🌀",
            "i do the short-haul grind, respect it",
            "turboprop means turbo romantic",
            "landing gear personality: down to earth"
        ]),
        ("a220", [
            "small but mighty, just like my feelings",
            "newest one in the fleet, be gentle",
            "wide cabin, wide open heart"
        ]),
        ("a330", [
            "i'm the reliable type, older but golden",
            "some call me basic, i call it consistent"
        ]),
        ("a321", [
            "long body, long-term intentions",
            "XLR: extra long range, extra longing too"
        ])
    ]

    static let generic: [String] = [
        "wheels up whenever you are ✈️",
        "my cruising altitude is 41,000ft but i'd come down for you",
        "just taxiing into your dms 🛬",
        "checking you on FR24 rn btw",
        "don't mind the turbulence, i'm just nervous around you",
        "i only fly point-to-point but with you it feels nonstop",
        "fuel's expensive but flirting is free",
        "quick turnaround, that's me",
        "you make my flaps deploy",
        "final approach to your heart, request clearance 📡",
        "i've been holding at the pattern altitude waiting for you",
        "cabin crew has been notified of my crush"
    ]

    /// Deterministically pick a few lines for this plane based on its type + reg.
    static func stories(for plane: PlaneCard) -> [String] {
        let type = plane.aircraft.lowercased()
        var pool = generic
        if let match = byType.first(where: { type.contains($0.keyword) }) {
            pool = match.lines + generic
        }
        // seed the shuffle by reg so each plane always tells the same story
        var seed = 0
        for c in plane.reg.unicodeScalars { seed = (seed &* 31 &+ Int(c.value)) & 0xFFFF }
        var rng = SeededGenerator(seed: UInt64(max(1, seed)))
        let count = 3 + seed % 2 // 3-4 story lines
        var picked: [String] = []
        var source = pool
        for _ in 0..<min(count, source.count) {
            let idx = Int(rng.next() % UInt64(max(1, source.count)))
            picked.append(source.remove(at: idx))
        }
        return picked
    }
}

/// Tiny deterministic RNG (xorshift) so stories are stable per plane.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
