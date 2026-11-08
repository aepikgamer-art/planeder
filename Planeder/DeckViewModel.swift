import SwiftUI

enum SwipeAction { case like, nope, superLike }

@MainActor
final class DeckViewModel: ObservableObject {
    @Published var cards: [PlaneCard] = []
    @Published var loading = false
    @Published var matchPopup: PlaneCard? = nil
    @Published var queueEmpty = false
    @Published var queuedAction: SwipeAction?

    // JetAPI has no "browse" endpoint, it works per registration.
    // So the deck is a shuffled pool of airliner registrations (edit freely).
    static let regPool: [String] = [
        "G-XLEA", "G-XLEB", "G-XLEC",        // BA A380
        "D-AIXP", "D-AIXQ",                  // Lufthansa A350
        "PH-BHA", "PH-BHB",                  // KLM 787-10
        "HL7613", "HL7615",                  // Korean A380
        "JA842A", "JA843A",                  // ANA 787
        "N101DN", "N102DN",                  // Delta A321neo
        "N301DZ", "N302DZ",
        "N274AY", "N275AY",
        "N125DN", "N126DN",
        "N584UW", "N585UW",                  // ex-US A320
        "N905NK", "N906NK",                  // Spirit A320
        "N704JB", "N705JB",                  // JetBlue A320
        "N646VA",                            // Virgin
        "N2642U",
        "OE-LPD",                            // Austrian 777
        "HB-JHB",                            // Swiss 777
        "A7-ANI",                            // Qatar A380
        "A6-EUY",                            // Emirates 777
        "9V-SMA", "9V-SMB"                   // Singapore A380
    ]

    private var pending: [String] = []
    private let batchSize = 6

    func startDeck() {
        guard pending.isEmpty else { return }
        pending = Self.regPool.shuffled()
        cards.removeAll()
        Task { await loadMore() }
    }

    func loadMoreIfNeeded() {
        if cards.count <= 2 && !pending.isEmpty && !loading {
            Task { await loadMore() }
        }
    }

    private func loadMore() async {
        loading = true
        defer { loading = false }
        var loaded: [PlaneCard] = []
        let liked = MatchStore.shared.likedRegIDs()
        while loaded.count < batchSize && !pending.isEmpty {
            let reg = pending.removeFirst()
            do {
                let card = try await JetAPIClient.shared.fetchCard(reg: reg)
                if !card.imageURL.isEmpty && !liked.contains(card.id) {
                    loaded.append(card)
                }
            } catch {
                // 404 / bad reg / scraper hiccup: just skip it
                continue
            }
        }
        cards.append(contentsOf: loaded)
        queueEmpty = pending.isEmpty && cards.isEmpty
    }

    func swipe(_ card: PlaneCard, liked: Bool, superLiked: Bool = false) {
        queuedAction = nil
        cards.removeAll { $0.id == card.id }
        if liked {
            MatchStore.shared.add(card, superLiked: superLiked)
            matchPopup = card
        }
        loadMoreIfNeeded()
    }
}
