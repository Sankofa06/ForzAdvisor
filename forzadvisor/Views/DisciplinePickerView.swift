//
//  DisciplinePickerView.swift
//  forzadvisor
//
//  Lets the player choose the driving discipline before the local tune provider
//  generates values in Forza tune-menu order.
//

import SwiftUI

struct DisciplinePickerView: View {
    let car: CarInput
    let onBack: () -> Void
    let onSelect: (DrivingDiscipline) -> Void

    var body: some View {
        List {
            Section {
                CarSummaryHeader(car: car)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Discipline") {
                ForEach(DrivingDiscipline.allCases) { discipline in
                    Button {
                        onSelect(discipline)
                    } label: {
                        DisciplineRow(discipline: discipline)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("disciplineButton-\(discipline.rawValue)")
                    .signatureDisciplineBackground(discipline == .touge)
                }
            }
        }
        .navigationTitle("Pick Tune Type")
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
                    ForzAdvisorPill(title: "\(car.performanceClass.rawValue) \(car.performanceIndex)")
                    ForzAdvisorPill(title: car.drivetrain.rawValue, tint: ForzAdvisorTheme.warmAccent)
                    ForzAdvisorPill(title: "\(car.weightPounds) lb")
                    ForzAdvisorPill(
                        title: "\(car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))% front",
                        tint: ForzAdvisorTheme.success
                    )
                }
            }
        }
        .padding(.vertical, 6)
    }
}

private struct DisciplineRow: View {
    let discipline: DrivingDiscipline

    var body: some View {
        HStack(spacing: 12) {
            ForzAdvisorIcon(
                systemName: discipline.symbolName,
                tint: ForzAdvisorTheme.disciplineColor(discipline)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(discipline.title)
                        .font(.headline)
                    if discipline == .touge {
                        Text("Signature")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ForzAdvisorTheme.warmAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ForzAdvisorTheme.warmAccent.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(discipline.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func signatureDisciplineBackground(_ isSignature: Bool) -> some View {
        if isSignature {
            listRowBackground(
                LinearGradient(
                    colors: [
                        ForzAdvisorTheme.warmAccent.opacity(0.13),
                        ForzAdvisorTheme.surface
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            self.forzAdvisorRowBackground()
        }
    }
}

struct TuneLoadingView: View {
    let request: TuneRequest

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(ForzAdvisorTheme.accent.opacity(0.14))
                    .frame(width: 72, height: 72)
                ProgressView()
                    .controlSize(.large)
            }
            Text("Tuning \(request.car.displayName)")
                .font(.title3.weight(.semibold))
            Text(request.discipline.title)
                .font(.subheadline)
                .foregroundStyle(ForzAdvisorTheme.disciplineColor(request.discipline))
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ForzAdvisorTheme.screenBackground.ignoresSafeArea())
        .tint(ForzAdvisorTheme.accent)
        .navigationTitle("Generating")
    }
}
