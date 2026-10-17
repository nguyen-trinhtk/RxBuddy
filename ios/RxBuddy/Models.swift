import SwiftUI

// Mirrors the API contract in docs/plan/README.md §4.

enum FoodRule: String, Codable, CaseIterable, Identifiable {
    case emptyStomach = "empty_stomach", withFood = "with_food", any
    var id: String { rawValue }
    var label: String {
        switch self {
        case .emptyStomach: "Empty stomach"
        case .withFood: "With food"
        case .any: "Any time"
        }
    }
}

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var rawName: String
    var rxcui: String?
    var ingredient: String
    var strength: String
    var frequencyPerDay: Int
    var withFood: FoodRule
    var confidence: Double

    var dosing: String {
        let times = ["once", "twice", "3 times", "4 times", "5 times", "6 times"][max(0, min(frequencyPerDay, 6) - 1)]
        return "\(strength) · \(times) a day"
    }

    var tint: Color {
        let palette = [Theme.sky, Color(hex: 0xF2A7A0), Color(hex: 0x9CCFAE), Color(hex: 0xF2CF6B)]
        let seed = ingredient.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[seed % palette.count]
    }
}

enum ClashType: String, Codable {
    case timingResolvable = "timing_resolvable"
    case pharmacistRequired = "pharmacist_required"
}

struct LabelSource: Codable, Hashable {
    var setid: String
    var section: String
    var quote: String
}

struct Clash: Identifiable, Codable, Hashable {
    var id = UUID()
    var drugs: [String]
    var type: ClashType
    var gapHours: Int?
    var summary: String
    var source: LabelSource
}

struct DoseEvent: Identifiable, Codable, Hashable {
    var id = UUID()
    var ingredient: String
    var time: String
    var note: String?
    var status: Status = .upcoming

    enum Status: String, Codable { case upcoming, taken, skipped }
}

enum Sample {
    static let meds: [Medication] = [
        .init(rawName: "Synthroid 50mcg", rxcui: "966222", ingredient: "levothyroxine",
              strength: "50 mcg", frequencyPerDay: 1, withFood: .emptyStomach, confidence: 0.94),
        .init(rawName: "Calcium Carbonate 600mg", rxcui: "318076", ingredient: "calcium carbonate",
              strength: "600 mg", frequencyPerDay: 2, withFood: .withFood, confidence: 0.88),
        .init(rawName: "Warfarin 5mg", rxcui: "855332", ingredient: "warfarin",
              strength: "5 mg", frequencyPerDay: 1, withFood: .any, confidence: 0.91),
        .init(rawName: "Ibuprofn 200", rxcui: nil, ingredient: "ibuprofen",
              strength: "200 mg", frequencyPerDay: 3, withFood: .withFood, confidence: 0.58),
    ]

    static let clashes: [Clash] = [
        .init(drugs: ["levothyroxine", "calcium carbonate"], type: .timingResolvable, gapHours: 4,
              summary: "Calcium blocks absorption.",
              source: .init(setid: "1f9d6b5b-…", section: "Drug Interactions",
                            quote: "Administer levothyroxine at least 4 hours before or after drugs known to interfere with absorption (calcium carbonate…).")),
        .init(drugs: ["warfarin", "ibuprofen"], type: .pharmacistRequired, gapHours: nil,
              summary: "Raises bleeding risk.",
              source: .init(setid: "d0c4b1f8-…", section: "Warnings",
                            quote: "NSAIDs… may increase the risk of bleeding when coadministered with warfarin.")),
    ]

    static let schedule: [DoseEvent] = [
        .init(ingredient: "levothyroxine", time: "07:00", note: "Empty stomach", status: .taken),
        .init(ingredient: "warfarin", time: "08:00", note: nil),
        .init(ingredient: "ibuprofen", time: "08:00", note: "With food"),
        .init(ingredient: "calcium carbonate", time: "11:00", note: "With food"),
        .init(ingredient: "ibuprofen", time: "14:00", note: "With food"),
        .init(ingredient: "calcium carbonate", time: "19:00", note: "With food"),
        .init(ingredient: "ibuprofen", time: "20:00", note: "With food"),
    ]
}

@Observable
final class AppState {
    var meds: [Medication] = []
    var clashes: [Clash] = []
    var schedule: [DoseEvent] = []
    var wake = Calendar.current.date(from: DateComponents(hour: 7)) ?? .now
    var sleep = Calendar.current.date(from: DateComponents(hour: 23)) ?? .now
    var remindersOn = true

    init(preview: Bool = true) {
        if preview {
            meds = Sample.meds
            clashes = Sample.clashes
            schedule = Sample.schedule
        }
    }

    func med(for ingredient: String) -> Medication? {
        meds.first { $0.ingredient == ingredient }
    }

    func clashes(for ingredient: String) -> [Clash] {
        clashes.filter { $0.drugs.contains(ingredient) }
    }

    var nextDose: DoseEvent? { schedule.first { $0.status == .upcoming } }

    func mark(_ dose: DoseEvent, _ status: DoseEvent.Status) {
        guard let i = schedule.firstIndex(where: { $0.id == dose.id }) else { return }
        schedule[i].status = status
    }
}
