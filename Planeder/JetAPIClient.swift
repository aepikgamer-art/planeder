import Foundation

enum JetAPIError: Error {
    case badResponse, notFound, decoding
}

// planespotters.net free photo API (https://api.planespotters.net/pub/photos/reg?reg=)
struct PlanespottersResponse: Decodable {
    let photos: [PlanespottersPhoto]
}

struct PlanespottersPhoto: Decodable {
    struct Thumb: Decodable { let src: String? }
    let thumbnail_large: Thumb?
    let link: String?
    let photographer: String?
}

struct JetAPIClient {
    static let shared = JetAPIClient()
    private let base = URL(string: "https://www.jetapi.dev")!

    /// Photos come from planespotters.net (jetapi's JetPhotos scraper is unreliable);
    /// metadata comes from jetapi's FlightRadar endpoint. Falls back to a
    /// metadata-only glass art card when a reg has no photo anywhere.
    func fetchCard(reg: String) async throws -> PlaneCard {
        let fr = try? await fetchFlightRadar(reg: reg)

        if let photo = await fetchPlanespottersPhoto(reg: reg) {
            return PlaneCard(
                id: reg.uppercased(),
                reg: reg.uppercased(),
                aircraft: fr?.Aircraft ?? "Airliner",
                airline: fr?.Airline ?? fr?.Operator ?? "Unknown airline",
                typeCode: fr?.TypeCode ?? "",
                serial: "",
                photographer: photo.photographer,
                location: "",
                dateTaken: "",
                imageURL: photo.url,
                jetPhotosLink: photo.link
            )
        }

        // legacy path in case jetapi's JetPhotos scraper comes back
        if let card = try? await fetchJetPhotosCard(reg: reg) {
            return card
        }

        if let fr, fr.Aircraft != nil || fr.Airline != nil {
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
                jetPhotosLink: "https://www.jetphotos.com/photo/keyword/" + reg
            )
        }

        throw JetAPIError.notFound
    }

    private func makeURL(reg: String, params: [String: String]) -> URL {
        var comps = URLComponents(url: base.appendingPathComponent("api"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "reg", value: reg)]
        for (k, v) in params { items.append(URLQueryItem(name: k, value: v)) }
        comps.queryItems = items
        return comps.url!
    }

    // MARK: planespotters photo

    private func fetchPlanespottersPhoto(reg: String) async -> (url: String, link: String, photographer: String)? {
        guard let url = URL(string: "https://api.planespotters.net/pub/photos/reg?reg=" + reg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let ps = try? JSONDecoder().decode(PlanespottersResponse.self, from: data),
              let first = ps.photos.first else { return nil }
        var src = first.thumbnail_large?.src ?? ""
        if src.hasSuffix("_280.jpg") {
            // try the hi-res variant; card view falls back to art card if it fails
            src = src.replacingOccurrences(of: "_280.jpg", with: "_hd.jpg")
        }
        guard !src.isEmpty else { return nil }
        return (src, first.link ?? "https://www.planespotters.net/search?q=" + reg, first.photographer ?? "")
    }

    // MARK: jetapi (legacy JetPhotos + FlightRadar metadata)

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
            jetPhotosLink: img.Link ?? "https://www.jetphotos.com/photo/keyword/" + reg
        )
    }

    private func fetchFlightRadar(reg: String) async throws -> FlightRadarResult {
        let (data, response) = try await URLSession.shared.data(from: makeURL(reg: reg, params: ["only_fr": "true", "flights": "0"]))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw JetAPIError.badResponse
        }
        guard let fr = try? JSONDecoder().decode(FlightRadarResult.self, from: data) else {
            throw JetAPIError.notFound
        }
        return fr
    }
}
