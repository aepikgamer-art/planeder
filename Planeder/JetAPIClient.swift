import Foundation

enum JetAPIError: Error {
    case badResponse, notFound, decoding
}

struct JetAPIClient {
    static let shared = JetAPIClient()
    private let base = URL(string: "https://www.jetapi.dev")!

    func fetchCard(reg: String) async throws -> PlaneCard {
        var comps = URLComponents(url: base.appendingPathComponent("api"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "reg", value: reg),
            URLQueryItem(name: "only_jp", value: "true"),
            URLQueryItem(name: "photos", value: "1")
        ]
        let (data, response) = try await URLSession.shared.data(from: comps.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw JetAPIError.badResponse
        }
        guard let result = try? JSONDecoder().decode(JetPhotosResult.self, from: data),
              let img = result.Images.first else {
            throw JetAPIError.notFound
        }
        return PlaneCard(
            id: result.Reg ?? reg.uppercased(),
            reg: result.Reg ?? reg.uppercased(),
            aircraft: img.Aircraft ?? "Unknown aircraft",
            airline: img.Airline ?? "Unknown airline",
            serial: img.Serial ?? "",
            photographer: img.Photographer ?? "",
            location: img.Location ?? "",
            dateTaken: img.DateTaken ?? "",
            imageURL: img.Image ?? img.Thumbnail ?? "",
            jetPhotosLink: img.Link ?? "https://www.jetphotos.com"
        )
    }
}
