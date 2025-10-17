import Foundation

struct FoodItem {
    let name: String
    let calories: Double?
    let carbs: Double?
    let protein: Double?
    let fat: Double?
    let fiber: Double?
    let alerts: [FoodAlert]
}

struct FoodAlert: Identifiable, Equatable {
    let id: UUID = UUID()
    let title: String
    let issued: Date?
    let allergens: [String]
    let url: URL?

    init(title: String, issued: Date? = nil, allergens: [String] = [], url: URL? = nil) {
        self.title = title
        self.issued = issued
        self.allergens = allergens
        self.url = url
    }
}

enum FoodLookupError: LocalizedError {
    case productNotFound
    case decodingFailed
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "We couldn't find nutrition data for that barcode."
        case .decodingFailed:
            return "The nutrition data was in an unexpected format."
        case .serviceUnavailable:
            return "The nutrition service is unavailable. Please try again later."
        }
    }
}

final class FoodLookupService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Look up a product using the Open Food Facts API. Returns a `FoodItem` with key macro data.
    func lookupProduct(byBarcode barcode: String) async throws -> FoodItem {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            throw FoodLookupError.productNotFound
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw FoodLookupError.serviceUnavailable
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw FoodLookupError.serviceUnavailable
        }

        do {
            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            guard decoded.status == 1, let product = decoded.product else {
                throw FoodLookupError.productNotFound
            }

            let nutrients = product.nutriments
            let alerts = await (try? fetchFoodAlerts(for: product.productName ?? "")) ?? []
            let item = FoodItem(
                name: product.productName ?? "Meal",
                calories: nutrients?.energyKcal100g ?? nutrients?.energyKcalServing,
                carbs: nutrients?.carbohydrates ?? nutrients?.carbohydratesServing,
                protein: nutrients?.proteins ?? nutrients?.proteinsServing,
                fat: nutrients?.fat ?? nutrients?.fatServing,
                fiber: nutrients?.fiber ?? nutrients?.fiberServing,
                alerts: alerts
            )
            return item
        } catch {
            throw FoodLookupError.decodingFailed
        }
    }

    private func fetchFoodAlerts(for productName: String) async throws -> [FoodAlert] {
        let trimmed = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://data.food.gov.uk/food-alerts/alerts?_limit=5&_search=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(FSAResponse.self, from: data)
            return payload.alerts.map { alert in
                FoodAlert(
                    title: alert.shortTitle ?? alert.title ?? "Food Standards Alert",
                    issued: alert.reportingDate,
                    allergens: alert.allergens ?? [],
                    url: URL(string: alert.link ?? "")
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - Open Food Facts Models

private struct OpenFoodFactsResponse: Decodable {
    let status: Int
    let product: Product?

    struct Product: Decodable {
        let productName: String?
        let nutriments: Nutriments?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case nutriments
        }
    }

    struct Nutriments: Decodable {
        let energyKcal100g: Double?
        let energyKcalServing: Double?
        let carbohydrates: Double?
        let carbohydratesServing: Double?
        let proteins: Double?
        let proteinsServing: Double?
        let fat: Double?
        let fatServing: Double?
        let fiber: Double?
        let fiberServing: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case energyKcalServing = "energy-kcal_serving"
            case carbohydrates = "carbohydrates_100g"
            case carbohydratesServing = "carbohydrates_serving"
            case proteins = "proteins_100g"
            case proteinsServing = "proteins_serving"
            case fat = "fat_100g"
            case fatServing = "fat_serving"
            case fiber = "fiber_100g"
            case fiberServing = "fiber_serving"
        }
    }
}

// MARK: - FSA Models

private struct FSAResponse: Decodable {
    let alerts: [Alert]

    struct Alert: Decodable {
        let title: String?
        let shortTitle: String?
        let problem: String?
        let reportingDate: Date?
        let allergens: [String]?
        let link: String?

        enum CodingKeys: String, CodingKey {
            case title
            case shortTitle = "shortTitle"
            case problem
            case reportingDate = "reportingBusinessDate"
            case allergens
            case link
        }
    }
}
