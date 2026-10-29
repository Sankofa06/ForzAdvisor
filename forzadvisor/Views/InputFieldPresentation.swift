import SwiftUI

/// Editing focus stays separate from validation's combined make-or-model issue.
enum InputFieldFocus: String, Hashable {
    case year, make, model, weight, frontWeight, weightPounds, frontWeightPercent
    case performanceIndex, performanceClass, drivetrain, horsepower, torque

    init(manual field: ManualEntryField) {
        self = field == .identity ? .make : Self(rawValue: field.rawValue) ?? .make
    }

    init(ocr field: OCRConfirmationUnresolvedField) {
        switch field {
        case .year: self = .year
        case .identity: self = .make
        case .weightPounds: self = .weightPounds
        case .frontWeightPercent: self = .frontWeightPercent
        case .performanceIndex: self = .performanceIndex
        case .performanceClass: self = .performanceClass
        case .drivetrain: self = .drivetrain
        case .horsepower: self = .horsepower
        case .torque: self = .torque
        }
    }
}

extension View {
    func inputFieldLabel(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            self.accessibilityLabel(title)
                .frame(minHeight: ForzAdvisorTheme.minimumTouchTarget)
        }
    }
}
