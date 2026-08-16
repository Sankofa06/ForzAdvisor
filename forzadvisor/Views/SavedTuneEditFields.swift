import SwiftUI

struct SavedTuneIdentityFields: View {
    @Binding var car: CarInput

    var body: some View {
        Section("Car") {
            TextField("Year", text: optionalNumberText($car.year))
                .keyboardType(.numberPad)
            TextField("Make", text: $car.make)
                .textInputAutocapitalization(.words)
            TextField("Model", text: $car.model)
                .textInputAutocapitalization(.words)
        }
        .forzAdvisorRowBackground()
    }

    private func optionalNumberText(_ value: Binding<Int?>) -> Binding<String> {
        Binding {
            value.wrappedValue.map(String.init) ?? ""
        } set: { newValue in
            let digits = newValue.filter(\.isNumber)
            value.wrappedValue = digits.isEmpty ? nil : Int(digits)
        }
    }
}

struct SavedTunePerformanceFields: View {
    @Binding var car: CarInput

    var body: some View {
        Section("Performance") {
            LabeledContent("Weight") {
                TextField("lb", value: $car.weightPounds, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                    "Front weight",
                    value: "\(car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))%"
                )
                Slider(value: $car.frontWeightPercent, in: 30...70, step: 0.5)
            }
            LabeledContent("PI") {
                TextField("100-999", value: $car.performanceIndex, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            Picker("Class", selection: $car.performanceClass) {
                ForEach(car.game.supportedPerformanceClasses) { performanceClass in
                    Text(performanceClass.rawValue).tag(performanceClass)
                }
            }
            .pickerStyle(.menu)
            Picker("Drivetrain", selection: $car.drivetrain) {
                ForEach(Drivetrain.allCases) { drivetrain in
                    Text(drivetrain.rawValue).tag(drivetrain)
                }
            }
            .pickerStyle(.segmented)
        }
        .forzAdvisorRowBackground()
    }
}
