//
//  StockCatalogAdditionReviewView.swift
//  forzadvisor
//
//  Separate human release review for one exact canonical curation preflight.
//

import SwiftUI

struct StockCatalogAdditionReviewView: View {
    let preflightCanonicalJSON: Data
    let packetCanonicalJSON: Data

    @State private var preflight:
        StockCatalogCurationPreflight?
    @State private var reviewDate = Date()
    @State private var identitySourceRole:
        CatalogSourceRole = .officialRoster
    @State private var confirmations =
        StockCatalogAdditionReviewConfirmations.empty
    @State private var preparedReview: String?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                ForzAdvisorScreenHeader(
                    title: "Catalog Addition Review",
                    subtitle:
                        "Prepare a release-review-only schema-v2 catalog proposal.",
                    systemImage: "checkmark.seal",
                    tint: ForzAdvisorTheme.warmAccent
                )
            }
            .listRowBackground(ForzAdvisorTheme.heroRowBackground)

            candidateSection
            sourceSection
            confirmationsSection

            Section("Release-Only Boundary") {
                Text(StockCatalogAdditionReviewPolicy.reviewBoundary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Prepare Catalog Addition Review") {
                    prepareReview()
                }
                .disabled(preflight == nil
                    || !confirmations.allConfirmed)
                .accessibilityIdentifier(
                    "prepareStockCatalogAdditionReview"
                )

                if let preparedReview {
                    ShareLink(item: preparedReview) {
                        Label(
                            "Share Catalog Addition Review",
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .accessibilityIdentifier(
                        "shareStockCatalogAdditionReview"
                    )
                }
            }
            .forzAdvisorRowBackground()

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "stockCatalogAdditionReviewStatus"
                        )
                }
                .forzAdvisorRowBackground()
            }
        }
        .navigationTitle("Release Review")
        .forzAdvisorScreenChrome()
        .accessibilityIdentifier("stockCatalogAdditionReview")
        .task {
            loadPreflight()
        }
        .onChange(of: reviewDraftFingerprint) {
            previous, current in
            if previous != current {
                preparedReview = nil
            }
        }
    }

    @ViewBuilder
    private var candidateSection: some View {
        Section("Read-Only Candidate") {
            if let preflight {
                let vehicle = preflight.selection.vehicle
                LabeledContent(
                    "Car",
                    value:
                        "\(vehicle.year) \(vehicle.make) \(vehicle.model)"
                )
                LabeledContent(
                    "Game",
                    value: preflight.selection.game.shortTitle
                )
                LabeledContent(
                    "Catalog ID",
                    value: preflight.proposal.catalogID
                )
                LabeledContent(
                    "Revision",
                    value: preflight.proposal.revision
                )
                LabeledContent(
                    "Status",
                    value:
                        preflight.proposal.verificationStatus.label
                )
            } else {
                Text(
                    "The exact preflight could not be validated against the current bundled catalog."
                )
                .foregroundStyle(ForzAdvisorTheme.warning)
            }
        }
        .forzAdvisorRowBackground()
    }

    private var sourceSection: some View {
        Section("Release Source Decision") {
            Picker(
                "Identity source role",
                selection: $identitySourceRole
            ) {
                Text("Official roster")
                    .tag(CatalogSourceRole.officialRoster)
                Text("Community QA")
                    .tag(CatalogSourceRole.communityQA)
            }
            DatePicker(
                "Catalog review date",
                selection: $reviewDate,
                displayedComponents: [.date]
            )
            Text(
                "The identity source remains the exact reviewed HTTPS source from preflight. Stock facts use privacy-safe permission-bound first-party provenance with no contributor identifiers or URL."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var confirmationsSection: some View {
        Section("Explicit Maintainer Confirmations") {
            Toggle(
                "Exact preflight and current catalog revalidated",
                isOn:
                    $confirmations
                    .currentPreflightAndCatalogRevalidated
            )
            Toggle(
                "Identity source role independently reviewed",
                isOn: $confirmations.identityRoleReviewed
            )
            Toggle(
                "Candidate facts and proposed status reviewed",
                isOn: $confirmations.factsAndStatusReviewed
            )
            Toggle(
                "Source rights are sufficient for this release",
                isOn:
                    $confirmations.rightsSufficientForRelease
            )
            Toggle(
                "Proposed revision and review date approved",
                isOn: $confirmations.revisionAndDateApproved
            )
            Toggle(
                "Manual bundle change and release gates understood",
                isOn:
                    $confirmations.manualBundleChangeUnderstood
            )
            Text(
                "These are human release decisions. ForzAdvisor does not establish legal sufficiency."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .forzAdvisorRowBackground()
    }

    private var reviewDraftFingerprint: String {
        [
            String(reviewDate.timeIntervalSinceReferenceDate),
            identitySourceRole.rawValue,
            String(
                confirmations
                    .currentPreflightAndCatalogRevalidated
            ),
            String(confirmations.identityRoleReviewed),
            String(confirmations.factsAndStatusReviewed),
            String(confirmations.rightsSufficientForRelease),
            String(confirmations.revisionAndDateApproved),
            String(confirmations.manualBundleChangeUnderstood)
        ].joined(separator: "|")
    }

    private func loadPreflight() {
        do {
            let catalog = try BundledCarCatalog.load().get()
            preflight = try StockCatalogCurationPreflightExporter()
                .validate(
                    preflightCanonicalJSON,
                    packetCanonicalJSON: packetCanonicalJSON,
                    baseCatalog: catalog
                )
            statusMessage = nil
        } catch {
            preflight = nil
            preparedReview = nil
            statusMessage = error.localizedDescription
        }
    }

    private func prepareReview() {
        do {
            let catalog = try BundledCarCatalog.load().get()
            let artifact = try StockCatalogAdditionReviewExporter()
                .makeArtifact(
                    preflightCanonicalJSON:
                        preflightCanonicalJSON,
                    packetCanonicalJSON: packetCanonicalJSON,
                    baseCatalog: catalog,
                    request: .init(
                        reviewedAt: reviewDate,
                        identitySourceRole: identitySourceRole,
                        confirmations: confirmations
                    )
                )
            guard let text = String(
                data: artifact.canonicalJSON,
                encoding: .utf8
            ) else {
                throw StockCatalogAdditionReviewError.invalidJSON
            }
            preparedReview = text
            statusMessage =
                "Prepared a validated schema-v2 catalog proposal for manual release review. No bundled catalog or tuning state changed."
        } catch {
            preparedReview = nil
            statusMessage = error.localizedDescription
        }
    }
}
