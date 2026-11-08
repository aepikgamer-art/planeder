import SwiftUI

enum SwipeAction { case like, nope, superLike }

@MainActor
final class DeckViewModel: ObservableObject {
    @Published var cards: [PlaneCard] = []
    @Published var loading = false
    @Published var matchPopup: PlaneCard? = nil
    @Published var queueEmpty = false
    @Published var queuedAction: SwipeAction?

    // Verified against jetapi's FlightRadar side + solid candidates.
    // Dead regs get skipped automatically; the deck recycles until you've matched everything.
    static let regPool: [String] = [
        // verified live via jetapi (FlightRadar)
        "G-XWBA", "G-XWBB",          // BA A350
        "D-AIXQ",                    // Lufthansa A350
        "PH-BHA",                    // KLM 787-9
        "A7-ANI", "A7-ALA",          // Qatar A350
        "9V-SMA",                    // Singapore A350
        "JA843A",                    // ANA Dash 8
        "N719AN",                    // AA 777-300ER
        "HL7615",                    // Korean A380
        // candidates (skipped if jetapi can't find them)
        "G-XLEA", "G-XLEB", "G-XLEC",
        "D-AIXP", "PH-BHB", "HL7613",
        "JA842A", "N301DN", "N302DN", "N303DN",
        "N718AN", "N704JB", "N958JB",
        "VH-OQA", "B-LRA", "HB-JNA", "OE-LPD",
        "G-VLIB", "G-VNEW", "C-FIVQ",
        "N584UW", "N905NK", "N917NK",
        "A6-EUY", "F-HPJA"
    ]

    private var pending: [String] = []
    private let batchSize = 6

    func startDeck() {
        cards.removeAll()
        queueEmpty = false
        refillPending()
        Task { await loadMore() }
    }

    /// Refill from the pool, excluding matched planes. Nope'd planes come back
    /// on the next cycle, so the deck only truly runs dry when you've matched everything.
    private func refillPending() {
        let liked = MatchStore.shared.likedRegIDs()
        let pool = Self.regPool.filter { !liked.contains($0.uppercased()) }
        pending = pool.shuffled()
        if pending.isEmpty { queueEmpty = true }
    }

    func loadMoreIfNeeded() {
        if cards.count <= 2 && !loading {
            if pending.isEmpty && !queueEmpty {
                refillPending()
            }
            if !pending.isEmpty || !cards.isEmpty {
                Task { await loadMore() }
            }
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
                if !liked.contains(card.id) {
                    loaded.append(card)
                }
            } catch {
                // 404 / scraper down: just skip it
                continue
            }
        }
        cards.append(contentsOf: loaded)
        if cards.isEmpty && pending.isEmpty && !queueEmpty {
            refillPending()
        }
        queueEmpty = queueEmpty && cards.isEmpty
        if pending.isEmpty && !cards.isEmpty && !queueEmpty {
            // let the next swipe cycle back around
        }
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
