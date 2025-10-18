import Foundation

struct GLP1Medication: Identifiable, Equatable {
    let id: String
    let brandName: String
    let genericName: String
    let frequency: String
    let titrationDoses: [String]
    let maintenanceDoses: [String]
    let notes: String

    var displayName: String { brandName }
}

enum GLP1MedicationLibrary {
    static let customID = "custom"

    static let medications: [GLP1Medication] = [
        GLP1Medication(
            id: "ozempic",
            brandName: "Ozempic",
            genericName: "Semaglutide",
            frequency: "Weekly injection",
            titrationDoses: ["0.25 mg", "0.5 mg"],
            maintenanceDoses: ["0.5 mg", "1.0 mg", "2.0 mg"],
            notes: "Common starter for type 2 diabetes and weight support."
        ),
        GLP1Medication(
            id: "wegovy",
            brandName: "Wegovy",
            genericName: "Semaglutide",
            frequency: "Weekly injection",
            titrationDoses: ["0.25 mg", "0.5 mg", "1.0 mg", "1.7 mg"],
            maintenanceDoses: ["1.7 mg", "2.4 mg"],
            notes: "Approved specifically for obesity treatment."
        ),
        GLP1Medication(
            id: "mounjaro",
            brandName: "Mounjaro",
            genericName: "Tirzepatide",
            frequency: "Weekly injection",
            titrationDoses: ["2.5 mg", "5 mg"],
            maintenanceDoses: ["5 mg", "7.5 mg", "10 mg", "12.5 mg", "15 mg"],
            notes: "Dual GIP/GLP-1 agonist used for diabetes and weight management."
        ),
        GLP1Medication(
            id: "zepbound",
            brandName: "Zepbound",
            genericName: "Tirzepatide",
            frequency: "Weekly injection",
            titrationDoses: ["2.5 mg", "5 mg"],
            maintenanceDoses: ["5 mg", "7.5 mg", "10 mg", "12.5 mg", "15 mg"],
            notes: "Weight-loss indication of tirzepatide."
        ),
        GLP1Medication(
            id: "trulicity",
            brandName: "Trulicity",
            genericName: "Dulaglutide",
            frequency: "Weekly injection",
            titrationDoses: ["0.75 mg"],
            maintenanceDoses: ["0.75 mg", "1.5 mg", "3.0 mg", "4.5 mg"],
            notes: "Once-weekly pen with easy single-use device."
        ),
        GLP1Medication(
            id: "saxenda",
            brandName: "Saxenda",
            genericName: "Liraglutide",
            frequency: "Daily injection",
            titrationDoses: ["0.6 mg", "1.2 mg", "1.8 mg", "2.4 mg"],
            maintenanceDoses: ["3.0 mg"],
            notes: "Daily dosing; counsel on nausea during titration."
        ),
        GLP1Medication(
            id: "victoza",
            brandName: "Victoza",
            genericName: "Liraglutide",
            frequency: "Daily injection",
            titrationDoses: ["0.6 mg", "1.2 mg"],
            maintenanceDoses: ["1.2 mg", "1.8 mg"],
            notes: "Type 2 diabetes indication, same molecule as Saxenda."
        ),
        GLP1Medication(
            id: "bydureon",
            brandName: "Bydureon BCise",
            genericName: "Exenatide (ER)",
            frequency: "Weekly injection",
            titrationDoses: ["2 mg"],
            maintenanceDoses: ["2 mg"],
            notes: "Extended-release exenatide."
        )
    ]

    static var defaultMedication: GLP1Medication {
        medications.first ?? GLP1Medication(
            id: "default",
            brandName: "GLP-1",
            genericName: "",
            frequency: "Weekly",
            titrationDoses: ["0.25 mg"],
            maintenanceDoses: ["0.5 mg"],
            notes: ""
        )
    }

    static func medication(with id: String) -> GLP1Medication? {
        medications.first { $0.id == id }
    }
}
