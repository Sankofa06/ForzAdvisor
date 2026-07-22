import Foundation

struct ManualEntryDraft: Equatable, Sendable {
    var game: ForzaGame {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: game) }
    }
    var year: Int? {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: year) }
    }
    var make: String {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: make) }
    }
    var model: String {
        didSet { clearCatalogReferenceIfChanged(from: oldValue, to: model) }
    }
    var weightPounds: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: weightPounds) }
    }
    var frontWeightPercent: Double? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: frontWeightPercent) }
    }
    var performanceIndex: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: performanceIndex) }
    }
    var performanceClass: PerformanceClass? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: performanceClass) }
    }
    var drivetrain: Drivetrain? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: drivetrain) }
    }
    var peakHorsepower: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: peakHorsepower) }
    }
    var peakTorqueFootPounds: Int? {
        didSet { markCatalogValuesModifiedIfChanged(from: oldValue, to: peakTorqueFootPounds) }
    }
    var catalogReference: CatalogCarReference?
    var catalogValuesModified: Bool

    static let empty = ManualEntryDraft()

    init(
        game: ForzaGame = .fh6,
        year: Int? = nil,
        make: String = "",
        model: String = "",
        weightPounds: Int? = nil,
        frontWeightPercent: Double? = nil,
        performanceIndex: Int? = nil,
        performanceClass: PerformanceClass? = nil,
        drivetrain: Drivetrain? = nil,
        peakHorsepower: Int? = nil,
        peakTorqueFootPounds: Int? = nil,
        catalogReference: CatalogCarReference? = nil,
        catalogValuesModified: Bool = false
    ) {
        self.game = game
        self.year = year
        self.make = make
        self.model = model
        self.weightPounds = weightPounds
        self.frontWeightPercent = frontWeightPercent
        self.performanceIndex = performanceIndex
        self.performanceClass = performanceClass
        self.drivetrain = drivetrain
        self.peakHorsepower = peakHorsepower
        self.peakTorqueFootPounds = peakTorqueFootPounds
        self.catalogReference = catalogReference
        self.catalogValuesModified = catalogReference != nil && catalogValuesModified
    }

    init(car: CarInput) {
        self.init(
            game: car.game,
            year: car.year,
            make: car.make,
            model: car.model,
            weightPounds: car.weightPounds,
            frontWeightPercent: car.frontWeightPercent,
            performanceIndex: car.performanceIndex,
            performanceClass: car.performanceClass,
            drivetrain: car.drivetrain,
            peakHorsepower: car.peakHorsepower,
            peakTorqueFootPounds: car.peakTorqueFootPounds,
            catalogReference: car.catalogReference,
            catalogValuesModified: car.catalogValuesModified
        )
    }

    var validationIssues: [ManualEntryValidationIssue] {
        var issues: [ManualEntryValidationIssue] = []
        if make.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.missingName)
        }

        if let weightPounds {
            if !(1500...7000).contains(weightPounds) {
                issues.append(.invalidWeight)
            }
        } else {
            issues.append(.missingWeight)
        }

        if let frontWeightPercent {
            if !(30...70).contains(frontWeightPercent) {
                issues.append(.invalidFrontWeight)
            }
        } else {
            issues.append(.missingFrontWeight)
        }

        if let performanceIndex {
            if !(100...999).contains(performanceIndex) {
                issues.append(.invalidPerformanceIndex)
            }
        } else {
            issues.append(.missingPerformanceIndex)
        }

        if let performanceClass {
            if let classRange = game.performanceIndexRange(for: performanceClass) {
                if let performanceIndex,
                   (100...999).contains(performanceIndex),
                   !classRange.contains(performanceIndex) {
                    issues.append(.performanceIndexOutsideClass(game, performanceClass, classRange))
                }
            } else {
                issues.append(.unsupportedPerformanceClass(game, performanceClass))
            }
        } else {
            issues.append(.missingPerformanceClass)
        }

        if drivetrain == nil {
            issues.append(.missingDrivetrain)
        }

        return issues
    }

    func confirmedCarInput() -> CarInput? {
        guard
            let weightPounds,
            let frontWeightPercent,
            let performanceIndex,
            let performanceClass,
            let drivetrain
        else {
            return nil
        }

        let car = CarInput(
            game: game,
            year: year,
            make: make,
            model: model,
            weightPounds: weightPounds,
            frontWeightPercent: frontWeightPercent,
            performanceIndex: performanceIndex,
            performanceClass: performanceClass,
            drivetrain: drivetrain,
            peakHorsepower: peakHorsepower,
            peakTorqueFootPounds: peakTorqueFootPounds,
            catalogReference: catalogReference,
            catalogValuesModified: catalogValuesModified
        )

        return car.isValid ? car : nil
    }

    private mutating func clearCatalogReferenceIfChanged<Value: Equatable>(
        from oldValue: Value,
        to newValue: Value
    ) {
        if oldValue != newValue {
            catalogReference = nil
            catalogValuesModified = false
        }
    }

    private mutating func markCatalogValuesModifiedIfChanged<Value: Equatable>(
        from oldValue: Value,
        to newValue: Value
    ) {
        if catalogReference != nil, oldValue != newValue {
            catalogValuesModified = true
        }
    }
}

enum ManualEntryValidationIssue: Identifiable, Equatable {
    case missingName
    case missingWeight
    case invalidWeight
    case missingFrontWeight
    case invalidFrontWeight
    case missingPerformanceIndex
    case invalidPerformanceIndex
    case missingPerformanceClass
    case unsupportedPerformanceClass(ForzaGame, PerformanceClass)
    case performanceIndexOutsideClass(ForzaGame, PerformanceClass, ClosedRange<Int>)
    case missingDrivetrain

    var id: String { message }

    var message: String {
        switch self {
        case .missingName: "Add at least a make or model."
        case .missingWeight: "Enter the car weight."
        case .invalidWeight: "Weight should be between 1,500 and 7,000 lb."
        case .missingFrontWeight: "Enter the front weight percentage."
        case .invalidFrontWeight: "Front weight should be between 30% and 70%."
        case .missingPerformanceIndex: "Enter the PI."
        case .invalidPerformanceIndex: "PI should be between 100 and 999."
        case .missingPerformanceClass: "Choose a performance class."
        case .unsupportedPerformanceClass(let game, let performanceClass):
            "Class \(performanceClass.rawValue) is not supported by \(game.shortTitle)."
        case .performanceIndexOutsideClass(let game, let performanceClass, let range):
            "\(game.shortTitle) class \(performanceClass.rawValue) uses PI \(range.lowerBound)-\(range.upperBound)."
        case .missingDrivetrain: "Choose a drivetrain."
        }
    }
}
