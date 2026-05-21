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
                VStack(alignment: .leading, spacing: 8) {
                    Text(car.displayName)
                        .font(.title2.weight(.bold))
                    Text("\(car.performanceClass.rawValue) \(car.performanceIndex) - \(car.drivetrain.rawValue) - \(car.weightPounds) lb - \(car.frontWeightPercent.formatted(.number.precision(.fractionLength(1))))% front")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Discipline") {
                ForEach(DrivingDiscipline.allCases) { discipline in
                    Button {
                        onSelect(discipline)
                    } label: {
                        DisciplineRow(discipline: discipline)
                    }
                    .buttonStyle(.plain)
                    .signatureDisciplineBackground(discipline == .touge)
                }
            }
        }
        .navigationTitle("Pick Tune Type")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }
}

private struct DisciplineRow: View {
    let discipline: DrivingDiscipline

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: discipline.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(discipline.title)
                        .font(.headline)
                    if discipline == .touge {
                        Text("Signature")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.16))
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
            listRowBackground(Color.accentColor.opacity(0.12))
        } else {
            self
        }
    }
}

struct TuneLoadingView: View {
    let request: TuneRequest

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Tuning \(request.car.displayName)")
                .font(.title3.weight(.semibold))
            Text(request.discipline.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Generating")
    }
}
