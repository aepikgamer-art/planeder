import Foundation

enum JetAPIError: Error {
    case badResponse, notFound, decoding
}

struct JetAPIClient {
    static let shared = JetAPIClient()
    private let base = URL(string: "https://www.jetapi.dev")!

    /// Try JetPhotos for a photo first; if the photo scraper is down,
    /// fall back to FlightRadar metadata (glass card, no photo).
    func fetchCard(reg: String) async throws -> PlaneCard {
        if let card = try? await fetchJetPhotosCard(reg: reg) {
            return card
        }
        return try await fetchFlightRadarCard(reg: reg)
    }

    private func makeURL(reg: String, params: [String: String]) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent("api"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "reg", value: reg)]
        for (k, v) in params { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        return comps.url!
    }

    private func fetchJetPhotosCard(reg: String) async throws -> PlaneCard {
        let (data, response) = try await URLSession.shared.data(from: makeURL(reg: reg, params: ["only_jp": "true", "photos": "1"]))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw JetAPIError.badResponse
        }
        guard let result = try? JSONDecoder().decode(JetPhotosResult.self, from: data),
              let img = result.Images.first, let image = img.Image, !image.isEmpty else {
            throw JetAPIError.notFound
        }
        return PlaneCard(
            id: result.Reg ?? reg.uppercased(),
            reg: result.Reg ?? reg.uppercased(),
            aircraft: img.Aircraft ?? "Unknown aircraft",
            airline: img.Airline ?? "Unknown airline",
            typeCode: "",
            serial: img.Serial ?? "",
            photographer: img.Photographer ?? "",
            location: img.Location ?? "",
            dateTaken: img.DateTaken ?? "",
            imageURL: image,
            jetPhotosLink: img.Link ?? "https://www.jetphotos.com/photo/keyword/(reg)"
        )
    }

    private func fetchFlightRadarCard(reg: String) async throws -> PlaneCard {
        let (data, response) = try await URLSession.shared.data(from: makeURL(reg: reg, params: ["only_fr": "true", "flights": "0"]))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw JetAPIError.badResponse
        }
        guard let fr = try? JSONDecoder().decode(FlightRadarResult.self, from: data),
              (fr.Aircraft != nil || fr.Airline != nil || fr.ModeS != nil) else {
            throw JetAPIError.notFound
        }
        return PlaneCard(
            id: reg.uppercased(),
            reg: reg.uppercased(),
            aircraft: fr.Aircraft ?? "Airliner",
            airline: fr.Airline ?? fr.Operator ?? "Unknown airline",
            typeCode: fr.TypeCode ?? "",
            serial: "",
            photographer: "",
            location: "",
            dateTaken: "",
            imageURL: nil,
            jetPhotosLink: "https://www.jetphotos.com/photo/keyword/(reg)"
        )
    }
}
