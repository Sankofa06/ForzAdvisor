//
//  DisciplinePickerView.swift
//  forzadvisor
//
//  Lets the player choose the driving discipline before the selected provider
//  generates values in Forza tune-menu order.
//

import SwiftUI

struct DisciplinePickerView: View {
    let car: CarInput
    let providerDisclosure: TuneProviderDisclosure
    let onBack: () -> Void
    let onSelectionChanged: (DrivingDiscipline) -> Void
    let onStart: (DrivingDiscipline) -> Void

    @State private var selectionState: DisciplineSelectionState

    init(
        car: CarInput,
        selection: DrivingDiscipline?,
        providerDisclosure: TuneProviderDisclosure,
        onBack: @escaping () -> Void,
        onSelectionChanged: @escaping (DrivingDiscipline) -> Void,
        onStart: @escaping (DrivingDiscipline) -> Void
    ) {
        self.car = car
        self.providerDisclosure = providerDisclosure
        self.onBack = onBack
        self.onSelectionChanged = onSelectionChanged
        self.onStart = onStart
        _selectionState = State(initialValue: DisciplineSelectionState(
            selection: selection
        ))
    }

    var body: some View {
        List {
            Section {
                CarSummaryHeader(car: car)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Discipline") {
                ForEach(DrivingDiscipline.allCases) { discipline in
                    Button {
                        selectionState.select(discipline)
                        onSelectionChanged(discipline)
                    } label: {
                        DisciplineRow(
                            discipline: discipline,
                            isSelected: selectionState.selection == discipline
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("disciplineButton-\(discipline.rawValue)")
                    .accessibilityValue(
                        selectionState.selection == discipline
                            ? "Selected"
                            : "Not selected"
                    )
                    .accessibilityAddTraits(
                        selectionState.selection == discipline ? .isSelected : []
                    )
                    .accessibilityHint("Selects this discipline without starting generation")
                    .forzAdvisorRowBackground()
                }
            }

            Section("Before you start") {
                ProviderPreflightView(
                    game: car.game,
                    disclosure: providerDisclosure
                )

                Button(
                    DisciplineGenerationCopy.startButtonTitle(for: car.game)
                ) {
                    guard let selection = selectionState.startIntent else { return }
                    onStart(selection)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
                .forzAdvisorMinimumTouchTarget()
                .disabled(selectionState.startIntent == nil)
                .accessibilityIdentifier("startTuneGenerationButton")
                .accessibilityHint(
                    selectionState.startIntent == nil
                        ? "Select a discipline first"
                        : "Starts generation using the route described above"
                )
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Choose Discipline")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }
}

private struct CarSummaryHeader: View {
    let car: CarInput

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ForzAdvisorIcon(systemName: "car.side", tint: ForzAdvisorTheme.warmAccent, size: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text(car.displayName)
                        .font(.title2.weight(.bold))
                    Text("Choose the tune behavior before generating values.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForzAdvisorPill(title: car.game.shortTitle, tint: ForzAdvisorTheme.accent)
                    ForzAdvisorPill(title: "\(car.performanceClass.rawValue) \(car.performanceIndex)")
                    ForzAdvisorPill(title: car.drivetrain.rawValue, tint: ForzAdvisorTheme.warmAccent)
                    ForzAdvisorPill(title: "\(car.weightPounds) lb")
                    ForzAdvisorPill(
                        title: "\(car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))% front",
                        tint: ForzAdvisorTheme.success
                    )
                    if let peakHorsepower = car.peakHorsepower {
                        ForzAdvisorPill(title: "\(peakHorsepower) hp", tint: ForzAdvisorTheme.warmAccent)
                    }
                    if let peakTorqueFootPounds = car.peakTorqueFootPounds {
                        ForzAdvisorPill(title: "\(peakTorqueFootPounds) lb-ft")
                    }
                }
            }

            Text("Setup check: \(car.weightPounds) lb, \(car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))% front, \(car.drivetrain.rawValue). These values drive tire pressure, springs, damping, gearing, and differential baselines.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

private struct DisciplineRow: View {
    let discipline: DrivingDiscipline
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(
                systemName: discipline.symbolName,
                tint: ForzAdvisorTheme.disciplineColor(discipline)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(discipline.title)
                    .font(.headline)

                Text(discipline.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    isSelected ? ForzAdvisorTheme.accent : ForzAdvisorTheme.secondaryText
                )
                .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
    }
}
