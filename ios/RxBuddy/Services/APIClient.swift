import Foundation

/// Talks to the FastAPI backend (docs/plan/README.md §4).
/// Base URL: `-api http://192.168.1.20:8000` launch argument, else localhost (simulator).
struct APIClient {
    static let shared = APIClient()

    var baseURL = URL(string: UserDefaults.standard.string(forKey: "api") ?? "http://localhost:8000")!

    struct ParseResult: Decodable { var meds: [Medication]; var warnings: [String] }
    struct AnalyzeResult: Decodable { var clashes: [Clash]; var schedule: [DoseEvent] }

    private struct AnalyzeBody: Encodable { var meds: [Medication]; var wake: String; var sleep: String }

    func parse(image jpeg: Data) async throws -> ParseResult {
        let boundary = UUID().uuidString
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"label.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: baseURL.appending(path: "parse"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return try await send(req)
    }

    func analyze(meds: [Medication], wake: Date, sleep: Date) async throws -> AnalyzeResult {
        var req = URLRequest(url: baseURL.appending(path: "analyze"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try Self.encoder.encode(AnalyzeBody(meds: meds, wake: Self.hhmm(wake), sleep: Self.hhmm(sleep)))
        return try await send(req)
    }

    private func send<T: Decodable>(_ req: URLRequest) async throws -> T {
        var req = req
        req.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Server error \(code)"])
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    static func hhmm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }()
}
