import Foundation

// JetAPI (jetapi.dev) response when called with only_jp=true:
// https://www.jetapi.dev/api?reg=G-XLEA&only_jp=true&photos=1

struct JetPhotosResult: Codable {
    let Reg: String?
    let Images: [ImageAttributes]
}

struct ImageAttributes: Codable {
    let Image: String?
    let Link: String?
    let Thumbnail: String?
    let DateTaken: String?
    let DateUploaded: String?
    let Location: String?
    let Photographer: String?
    let Aircraft: String?
    let Serial: String?
    let Airline: String?
}

struct PlaneCard: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let reg: String
    let aircraft: String
    let airline: String
    let serial: String
    let photographer: String
    let location: String
    let dateTaken: String
    let imageURL: String
    let jetPhotosLink: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PlaneCard, rhs: PlaneCard) -> Bool { lhs.id == rhs.id }
}

struct Match: Codable, Identifiable {
    let id: String
    let plane: PlaneCard
    let superLiked: Bool
    let date: Date
}

final class MatchStore: ObservableObject {
    static let shared = MatchStore()
    private let key = "planeder.matches"

    @Published private(set) var matches: [Match] = []

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Match].self, from: data) {
            matches = decoded
        }
    }

    func add(_ plane: PlaneCard, superLiked: Bool) {
        guard !matches.contains(where: { $0.plane.id == plane.id }) else { return }
        matches.insert(Match(id: plane.id, plane: plane, superLiked: superLiked, date: Date()), at: 0)
        save()
    }

    func remove(_ match: Match) {
        matches.removeAll { $0.id == match.id }
        save()
    }

    func likedRegIDs() -> Set<String> {
        Set(matches.map { $0.plane.id })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(matches) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
