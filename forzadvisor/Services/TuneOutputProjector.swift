//
//  TuneOutputProjector.swift
//  forzadvisor
//
//  The single fail-closed boundary between generated candidates and values a
//  player may safely copy, save, or apply in game.
//

import Foundation

struct TuneOutputProjector {
    func project(
        _ candidate: TuneResult,
        for authoritativeRequest: TuneRequest? = nil,
        isPartial: Bool = false
    ) -> TuneResult {
        var projected = candidate
        if let authoritativeRequest {
            projected.request = authoritativeRequest
        }

        let context = projectionContext(for: projected.request)
        let snapshot = trustedSnapshot(for: projected.request)
        let priorReport = reusableReport(
            from: candidate,
            authoritativeRequest: authoritativeRequest,
            snapshot: snapshot,
            context: context
        )
        let resolution = snapshot.map {
            TuneCapabilityResolver(game: projected.request.car.game).resolve(
                profile: $0.capabilityProfile
            )
        }
        let capabilityBySetting = Dictionary(
            uniqueKeysWithValues: (resolution?.settings ?? []).map { ($0.setting, $0) }
        )
        let rawLines = candidate.sections.flatMap { section in
            section.lines.map { (section: section, line: $0) }
        }
        let typedLines = rawLines.compactMap { item -> (TuneFieldID, TuneSection, TuneLine)? in
            guard let field = item.line.fieldID else { return nil }
            return (field, item.section, item.line)
        }
        let counts = Dictionary(grouping: typedLines, by: { $0.0 }).mapValues(\.count)
        let expected = TuneFieldID.expectedFields(
            drivetrain: projected.request.car.drivetrain,
            gearCount: snapshot?.gearCount
        )
        let expectedSet = Set(expected)
        var orderedFields = expected
        for (field, _, _) in typedLines where !expectedSet.contains(field) && !orderedFields.contains(field) {
            orderedFields.append(field)
        }

        var fieldReports: [TuneFieldProjection] = []
        var readyFields = Set<TuneFieldID>()
        for field in orderedFields {
            let capability = capabilityBySetting[field.setting]
            let line = typedLines.first(where: { $0.0 == field })?.2
            let decision = decision(
                for: field,
                line: line,
                occurrenceCount: counts[field, default: 0],
                isExpected: expectedSet.contains(field),
                context: context,
                snapshot: snapshot,
                capability: capability,
                prior: priorReport?.fields.first { $0.field == field },
                isPartial: isPartial
            )
            fieldReports.append(decision)
            if decision.status == .ready {
                readyFields.insert(field)
            }
        }

        let readyLinesByField = Dictionary(
            uniqueKeysWithValues: typedLines.compactMap { field, _, line in
                readyFields.contains(field) ? (field, line) : nil
            }
        )
        projected.sections = canonicalSections(
            orderedFields.compactMap { field in
                guard let line = readyLinesByField[field] else { return nil }
                return TuneLine(
                    label: field.projectionLabel,
                    value: line.value,
                    unit: field.expectedDisplayUnit,
                    detail: nil,
                    fieldID: field
                )
            }
        )

        let invalidRuleset = candidate.rulesetReference.map {
            !$0.isValid || $0.game != projected.request.car.game
        } ?? false
        if invalidRuleset {
            projected.rulesetReference = nil
        }

        let newDiagnostics = rawLines.compactMap { item -> TuneProjectionDiagnostic? in
            guard item.line.fieldID == nil,
                  LocalizedNumberText.parse(item.line.value) != nil else {
                return nil
            }
            return TuneProjectionDiagnostic(
                kind: .untypedProviderLine,
                sectionTitle: nil,
                lineLabel: nil
            )
        } + (invalidRuleset ? [TuneProjectionDiagnostic(
            kind: .invalidRulesetReference,
            sectionTitle: nil,
            lineLabel: nil
        )] : [])
        let diagnostics = (priorReport?.diagnostics ?? []) + newDiagnostics.filter { diagnostic in
            !(priorReport?.diagnostics.contains(diagnostic) ?? false)
        }

        projected.projectionReport = TuneProjectionReport(
            schemaVersion: TuneProjectionReport.currentSchemaVersion,
            snapshotID: snapshot?.id,
            contextStatus: context,
            capabilityResolution: resolution,
            fields: fieldReports,
            purchasePlan: purchasePlan(from: resolution),
            confirmations: confirmations(from: resolution),
            diagnostics: diagnostics
        )
        projected.notes = deterministicNotes(for: projected)
        return projected
    }

    private func reusableReport(
        from candidate: TuneResult,
        authoritativeRequest: TuneRequest?,
        snapshot: VehicleBuildSnapshot?,
        context: TuneProjectionContextStatus
    ) -> TuneProjectionReport? {
        guard authoritativeRequest == nil || authoritativeRequest == candidate.request,
              let report = candidate.projectionReport,
              report.schemaVersion == TuneProjectionReport.currentSchemaVersion,
              report.snapshotID == snapshot?.id,
              report.contextStatus == context else {
            return nil
        }
        return report
    }

    private func canonicalSections(_ lines: [TuneLine]) -> [TuneSection] {
        let order = [
            "Tires", "Gearing", "Alignment", "Antiroll Bars", "Springs",
            "Damping", "Aero", "Brakes", "Differential"
        ]
        return order.compactMap { title in
            let matching = lines.filter { $0.fieldID?.projectionSectionTitle == title }
            guard let first = matching.first,
                  let field = first.fieldID else { return nil }
            return TuneSection(
                title: title,
                symbolName: field.projectionSectionSymbol,
                lines: matching
            )
        }
    }

    private func decision(
        for field: TuneFieldID,
        line: TuneLine?,
        occurrenceCount: Int,
        isExpected: Bool,
        context: TuneProjectionContextStatus,
        snapshot: VehicleBuildSnapshot?,
        capability: TuneSettingCapability?,
        prior: TuneFieldProjection?,
        isPartial: Bool
    ) -> TuneFieldProjection {
        func result(
            _ status: TuneProjectionStatus,
            _ reason: TuneProjectionReason,
            purchases: [TunePartID] = capability?.requiredPurchaseIDs ?? [],
            unresolved: [TunePartID] = capability?.unresolvedPartIDs ?? []
        ) -> TuneFieldProjection {
            TuneFieldProjection(
                field: field,
                status: status,
                requiredPurchaseIDs: purchases,
                unresolvedPartIDs: unresolved,
                reason: reason
            )
        }

        switch context {
        case .missingSnapshot:
            return result(.rejectedValue, .missingSnapshot, purchases: [], unresolved: [])
        case .invalidSnapshot:
            return result(.rejectedValue, .invalidSnapshot, purchases: [], unresolved: [])
        case .exactBuild, .capabilityOnly:
            break
        }

        guard isExpected else {
            if field.gearIndex != nil {
                return result(.rejectedValue, .invalidGearIndex)
            }
            return result(.rejectedValue, .unexpectedField)
        }

        guard let capability else {
            return result(.needsPartConfirmation, .partAvailabilityUnknown)
        }
        switch capability.status {
        case .unavailable:
            return result(.unavailable, .capabilityUnavailable)
        case .unknown:
            return result(.needsPartConfirmation, .partAvailabilityUnknown)
        case .requiresUpgrade:
            return result(.requiresUpgrade, .upgradeRequired)
        case .stockAvailable, .installedUpgrade:
            break
        }

        guard let snapshot,
              let constraint = snapshot.constraints.first(where: { $0.field == field }),
              constraint.verification == .productionEligible,
              constraint.validationIssues.isEmpty else {
            return result(.needsConstraint, .missingProductionConstraint)
        }
        if occurrenceCount == 0 {
            if let prior,
               prior.status == .providerOmitted
                || prior.status == .awaitingProvider
                || prior.status == .rejectedValue {
                return prior
            }
            return result(
                isPartial ? .awaitingProvider : .providerOmitted,
                isPartial ? .providerPending : .providerOmitted
            )
        }
        guard occurrenceCount == 1 else {
            return result(.rejectedValue, .duplicateField)
        }
        guard let line else {
            return result(.rejectedValue, .malformedValue)
        }
        guard line.unit == field.expectedDisplayUnit else {
            return result(.rejectedValue, .wrongDisplayUnit)
        }
        guard let value = LocalizedNumberText.parse(line.value), value.isFinite else {
            return result(.rejectedValue, .malformedValue)
        }
        guard constraint.accepts(value) else {
            return result(.rejectedValue, .valueOutsideConstraint)
        }
        return TuneFieldProjection(
            field: field,
            status: .ready,
            requiredPurchaseIDs: [],
            unresolvedPartIDs: [],
            reason: nil
        )
    }

    private func projectionContext(for request: TuneRequest) -> TuneProjectionContextStatus {
        guard let snapshot = request.buildSnapshot else { return .missingSnapshot }
        guard snapshot.isValid, snapshot.matches(car: request.car) else { return .invalidSnapshot }
        return snapshot.kind == .exactBuildObservation ? .exactBuild : .capabilityOnly
    }

    private func trustedSnapshot(for request: TuneRequest) -> VehicleBuildSnapshot? {
        guard let snapshot = request.buildSnapshot,
              snapshot.isValid,
              snapshot.matches(car: request.car) else {
            return nil
        }
        return snapshot
    }

    private func purchasePlan(from resolution: TuneCapabilityResolution?) -> [TunePurchasePlanItem] {
        guard let resolution else { return [] }
        var items: [TunePartID: TunePurchasePlanItem] = [:]
        for capability in resolution.settings where capability.status == .requiresUpgrade {
            for partID in capability.requiredPurchaseIDs {
                var item = items[partID] ?? TunePurchasePlanItem(
                    part: TunePartCatalog.definition(for: partID),
                    unlocks: [],
                    evidence: []
                )
                if !item.unlocks.contains(capability.setting) {
                    item.unlocks.append(capability.setting)
                }
                for evidence in capability.evidence where !item.evidence.contains(evidence) {
                    item.evidence.append(evidence)
                }
                items[partID] = item
            }
        }

        let slotOrder = Dictionary(uniqueKeysWithValues: TunePartSlot.allCases.enumerated().map { ($0.element, $0.offset) })
        return items.values.sorted {
            let leftSlot = slotOrder[$0.part.slot, default: .max]
            let rightSlot = slotOrder[$1.part.slot, default: .max]
            if leftSlot != rightSlot { return leftSlot < rightSlot }
            return $0.part.label.localizedStandardCompare($1.part.label) == .orderedAscending
        }
    }

    private func confirmations(from resolution: TuneCapabilityResolution?) -> [TuneSettingConfirmation] {
        guard let resolution else { return [] }
        return resolution.settings.compactMap { capability in
            guard capability.status == .unknown else { return nil }
            return TuneSettingConfirmation(
                setting: capability.setting,
                candidateParts: capability.unresolvedPartIDs.map(TunePartCatalog.definition(for:))
            )
        }
    }

    private func deterministicNotes(for tune: TuneResult) -> TuneNotes {
        let report = tune.projectionReport
        let readyCount = report?.readyCount ?? 0
        return TuneNotes(
            bias: readyCount == 0
                ? "No generated numbers passed the current capability and range checks."
                : "\(readyCount) generated settings passed the current capability and range checks.",
            ifPushesWide: "Confirm the car build and tuning-screen ranges before requesting handling changes.",
            ifSnapsOnLift: "Do not apply withheld values; record the installed parts and exact in-game ranges first.",
            retuneTrigger: "Re-verify after changing the game build, upgrades, tire compound, or vehicle statistics."
        )
    }
}

enum TuneProjectionError: LocalizedError, Equatable {
    case noEligibleVerifiedFields
    case noVerifiedChange

    var errorDescription: String? {
        switch self {
        case .noEligibleVerifiedFields:
            "No verified settings are eligible for that refinement yet."
        case .noVerifiedChange:
            "The refinement did not produce a verified setting change."
        }
    }
}

struct CapabilityProjectingTuneProvider: TuneProvider {
    var base: any TuneProvider
    var projector = TuneOutputProjector()

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        try await generateTune(for: request, onPartial: nil)
    }

    func generateTune(for request: TuneRequest, onPartial: TuneProgressHandler?) async throws -> TuneResult {
        let projectedPartial: TuneProgressHandler?
        if let onPartial {
            projectedPartial = { partial in
                onPartial(projector.project(partial, for: request, isPartial: true))
            }
        } else {
            projectedPartial = nil
        }
        let candidate = try await base.generateTune(for: request, onPartial: projectedPartial)
        return projector.project(candidate, for: request)
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        let eligible = tune.projectionReport?.readyFieldIDs.intersection(adjustment.affectedFields)
            ?? Set<TuneFieldID>()
        guard !eligible.isEmpty else {
            throw TuneProjectionError.noEligibleVerifiedFields
        }

        var providerInput = tune
        providerInput.projectionReport = nil
        let candidate = try await base.adjustTune(previous: providerInput, adjustment: adjustment)
        var restrictedCandidate = candidate.tune
        restrictedCandidate.sections = mergedSections(
            preserving: tune.sections,
            accepting: candidate.tune.sections,
            eligibleFields: eligible
        )
        let projectedTune = projector.project(restrictedCandidate, for: tune.request)
        let changes = verifiedChanges(from: tune, to: projectedTune)
        guard !changes.isEmpty else {
            throw TuneProjectionError.noVerifiedChange
        }
        return TuneAdjustmentResult(tune: projectedTune, changes: changes)
    }

    private func mergedSections(
        preserving previous: [TuneSection],
        accepting candidate: [TuneSection],
        eligibleFields: Set<TuneFieldID>
    ) -> [TuneSection] {
        let eligibleLines = candidate.flatMap(\.lines).filter { line in
            guard let field = line.fieldID else { return false }
            return eligibleFields.contains(field)
        }
        let grouped = Dictionary(grouping: eligibleLines, by: { $0.fieldID! })
        let accepted = grouped.compactMapValues { lines in
            lines.count == 1 ? lines[0] : nil
        }
        return previous.compactMap { section in
            let lines = section.lines.map { line in
                guard let field = line.fieldID,
                      let replacement = accepted[field] else { return line }
                return replacement
            }
            guard !lines.isEmpty else { return nil }
            return TuneSection(title: section.title, symbolName: section.symbolName, lines: lines)
        }
    }

    private func verifiedChanges(from previous: TuneResult, to current: TuneResult) -> [TuneAdjustmentChange] {
        let previousPairs: [(TuneFieldID, TuneLine)] = previous.sections
            .flatMap(\.lines)
            .compactMap { line in
                guard let field = line.fieldID else { return nil }
                return (field, line)
            }
        let previousByField: [TuneFieldID: TuneLine] = Dictionary(uniqueKeysWithValues: previousPairs)
        let currentLines = current.sections.flatMap { section in
            section.lines.map { (section.title, $0) }
        }

        return currentLines.compactMap { sectionTitle, line in
            guard let field = line.fieldID,
                  let oldLine = previousByField[field],
                  oldLine.value != line.value else {
                return nil
            }
            return TuneAdjustmentChange(
                sectionTitle: sectionTitle,
                lineLabel: line.label,
                oldValue: oldLine.value,
                newValue: line.value,
                unit: line.unit
            )
        }
    }
}
