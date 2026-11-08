import Foundation

// JetAPI (jetapi.dev) response shapes

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

// FlightRadar metadata (lenient decoding - fields are all optional/never-fatal)
struct FlightRadarResult: Decodable {
    let Aircraft: String?
    let Airline: String?
    let Operator: String?
    let TypeCode: String?
    let ModeS: String?

    enum CodingKeys: String, CodingKey {
        case Aircraft, Airline, Operator, TypeCode, ModeS
    }

    init(from decoder: Decoder) throws {
        let c = decoder.container(keyedBy: CodingKeys.self)
        Aircraft = (try? c.decodeIfPresent(String.self, forKey: .Aircraft)) ?? nil
        Airline = (try? c.decodeIfPresent(String.self, forKey: .Airline)) ?? nil
        Operator = (try? c.decodeIfPresent(String.self, forKey: .Operator)) ?? nil
        TypeCode = (try? c.decodeIfPresent(String.self, forKey: .TypeCode)) ?? nil
        ModeS = (try? c.decodeIfPresent(String.self, forKey: .ModeS)) ?? nil
    }
}

struct PlaneCard: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let reg: String
    let aircraft: String
    let airline: String
    let typeCode: String
    let serial: String
    let photographer: String
    let location: String
    let dateTaken: String
    let imageURL: String?
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
        ChatStore.shared.seedStories(for: plane)
    }

    func remove(_ match: Match) {
        matches.removeAll { $0.id == match.id }
        ChatStore.shared.removeThread(for: match.id)
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
