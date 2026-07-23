//
//  CarCatalogReviewView.swift
//  forzadvisor
//
//  Explicit stock-value and provenance review before tune generation.
//

import SwiftUI

struct CarCatalogReviewView: View {
    static let fh5PlanOnlyMessage = "FH5 uses a provider-independent local build planner. It creates upgrade paths only and does not generate numeric tuning settings."

    let selection: CatalogCarSelection
    let onBack: () -> Void
    let onUseCar: () -> Void
    let onEditValues: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(selection.entry.displayName)
                        .font(.title2.weight(.bold))
                    Text(selection.entry.game.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForzAdvisorPill(
                                title: "\(selection.entry.stock.performanceClass.rawValue) \(selection.entry.stock.performanceIndex)"
                            )
                            ForzAdvisorPill(title: selection.entry.stock.drivetrain.rawValue)
                            ForzAdvisorPill(title: "\(selection.entry.stock.weightPounds) lb")
                            ForzAdvisorPill(title: "\(selection.entry.stock.frontWeightPercent.formatted())% front")
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            Section("Stock Specifications") {
                CatalogSpecificationRow(label: "Performance", value: "\(selection.entry.stock.performanceClass.rawValue) \(selection.entry.stock.performanceIndex)")
                CatalogSpecificationRow(label: "Drivetrain", value: selection.entry.stock.drivetrain.rawValue)
                CatalogSpecificationRow(label: "Weight", value: "\(selection.entry.stock.weightPounds) lb")
                CatalogSpecificationRow(label: "Front weight", value: "\(selection.entry.stock.frontWeightPercent.formatted())%")
                CatalogSpecificationRow(label: "Power", value: "\(selection.entry.stock.peakHorsepower) hp")
                CatalogSpecificationRow(label: "Torque", value: "\(selection.entry.stock.peakTorqueFootPounds) lb-ft")
            }
            .forzAdvisorRowBackground()

            Section("Verification") {
                Label(selection.reference.verificationStatus.label, systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ForzAdvisorTheme.accent)
                    .accessibilityIdentifier("catalogVerificationBadge")
                Text(selection.reference.verificationStatus.disclaimer)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if selection.entry.game == .fh5 {
                    Text(Self.fh5PlanOnlyMessage)
                        .font(.caption)
                        .foregroundStyle(ForzAdvisorTheme.warning)
                }
            }
            .forzAdvisorRowBackground()

            Section("Sources") {
                CatalogProvenanceView(reference: selection.reference)
            }
            .forzAdvisorRowBackground()

            Section {
                Button("Use This Car", action: onUseCar)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("catalogUseCarButton")
                Button("Edit Values", action: onEditValues)
                    .accessibilityIdentifier("catalogEditValuesButton")
            }
            .forzAdvisorRowBackground()
        }
        .navigationTitle("Review Car")
        .forzAdvisorScreenChrome()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back", action: onBack)
            }
        }
    }
}

struct CatalogProvenanceView: View {
    let reference: CatalogCarReference
    var showsOriginMessage = false
    var valuesModified = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsOriginMessage {
                Text(valuesModified
                     ? "Stock values were edited before tuning; sources below identify the catalog data origin."
                     : "Selected from community-crosschecked stock data")
                    .font(.subheadline.weight(.semibold))
            }

            Text("Catalog revision \(reference.revision)")
                .font(.caption)
            Text("Reviewed \(reference.reviewedAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(reference.sources) { source in
                Link(destination: source.url) {
                    Label(source.title, systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .accessibilityIdentifier("catalogSource-\(source.id)")
            }
        }
        .accessibilityIdentifier("catalogProvenance")
    }
}

private struct CatalogSpecificationRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
