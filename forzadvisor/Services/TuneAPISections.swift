//
//  TuneAPISections.swift
//  forzadvisor
//
//  Remaining tune API schema pieces plus conversion from API JSON sections
//  into the app's tune-menu display models.
//

import Foundation

struct TuneAPIDamping: Codable, Equatable {
    var frontRebound: Double?
    var rearRebound: Double?
    var frontBump: Double?
    var rearBump: Double?

    enum CodingKeys: String, CodingKey {
        case frontRebound = "front_rebound"
        case rearRebound = "rear_rebound"
        case frontBump = "front_bump"
        case rearBump = "rear_bump"
    }

    init(frontRebound: Double? = nil, rearRebound: Double? = nil, frontBump: Double? = nil, rearBump: Double? = nil) {
        self.frontRebound = frontRebound
        self.rearRebound = rearRebound
        self.frontBump = frontBump
        self.rearBump = rearBump
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.frontRebound = section.number("Front rebound")
        self.rearRebound = section.number("Rear rebound")
        self.frontBump = section.number("Front bump")
        self.rearBump = section.number("Rear bump")
    }
}

struct TuneAPIBrakes: Codable, Equatable {
    var balancePercent: Double?
    var pressurePercent: Double?

    enum CodingKeys: String, CodingKey {
        case balancePercent = "balance_pct"
        case pressurePercent = "pressure_pct"
    }

    init(balancePercent: Double? = nil, pressurePercent: Double? = nil) {
        self.balancePercent = balancePercent
        self.pressurePercent = pressurePercent
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.balancePercent = section.number("Balance")
        self.pressurePercent = section.number("Pressure")
    }
}

struct TuneAPIDifferential: Codable, Equatable {
    var accelPercent: Double?
    var decelPercent: Double?
    var frontAccelPercent: Double?
    var frontDecelPercent: Double?
    var rearAccelPercent: Double?
    var rearDecelPercent: Double?
    var centerBalanceRearPercent: Double?

    enum CodingKeys: String, CodingKey {
        case accelPercent = "accel_pct"
        case decelPercent = "decel_pct"
        case frontAccelPercent = "front_accel_pct"
        case frontDecelPercent = "front_decel_pct"
        case rearAccelPercent = "rear_accel_pct"
        case rearDecelPercent = "rear_decel_pct"
        case centerBalanceRearPercent = "center_balance_rear_pct"
    }

    init(accelPercent: Double? = nil, decelPercent: Double? = nil, frontAccelPercent: Double? = nil, frontDecelPercent: Double? = nil, rearAccelPercent: Double? = nil, rearDecelPercent: Double? = nil, centerBalanceRearPercent: Double? = nil) {
        self.accelPercent = accelPercent
        self.decelPercent = decelPercent
        self.frontAccelPercent = frontAccelPercent
        self.frontDecelPercent = frontDecelPercent
        self.rearAccelPercent = rearAccelPercent
        self.rearDecelPercent = rearDecelPercent
        self.centerBalanceRearPercent = centerBalanceRearPercent
    }

    init?(section: TuneSection?) {
        guard let section else { return nil }
        self.accelPercent = section.number("Accel")
        self.decelPercent = section.number("Decel")
        self.frontAccelPercent = section.number("Front accel")
        self.frontDecelPercent = section.number("Front decel")
        self.rearAccelPercent = section.number("Rear accel")
        self.rearDecelPercent = section.number("Rear decel")
        self.centerBalanceRearPercent = section.number("Center balance")
    }
}

struct TuneAPINotes: Codable, Equatable {
    var bias: String?
    var ifPushesWide: String?
    var ifSnapsOnLift: String?
    var retuneTrigger: String?

    enum CodingKeys: String, CodingKey {
        case bias
        case ifPushesWide = "if_pushes_wide"
        case ifSnapsOnLift = "if_snaps_on_lift"
        case retuneTrigger = "retune_trigger"
    }

    init(bias: String? = nil, ifPushesWide: String? = nil, ifSnapsOnLift: String? = nil, retuneTrigger: String? = nil) {
        self.bias = bias
        self.ifPushesWide = ifPushesWide
        self.ifSnapsOnLift = ifSnapsOnLift
        self.retuneTrigger = retuneTrigger
    }

    init(notes: TuneNotes) {
        self.bias = notes.bias
        self.ifPushesWide = notes.ifPushesWide
        self.ifSnapsOnLift = notes.ifSnapsOnLift
        self.retuneTrigger = notes.retuneTrigger
    }
}

extension TuneAPITune {
    func sections() -> [TuneSection] {
        [
            tiresSection,
            gearingSection,
            alignmentSection,
            antirollBarSection,
            springSection,
            dampingSection,
            aeroSection,
            brakeSection,
            differentialSection
        ].compactMap { $0 }
    }

    private var tiresSection: TuneSection? {
        guard let tires else { return nil }
        return section("Tires", "circle.dashed", [
            line("Front pressure", tires.frontPsi, "PSI"),
            line("Rear pressure", tires.rearPsi, "PSI")
        ])
    }

    private var gearingSection: TuneSection? {
        guard let gearing else { return nil }
        var lines = [line("Final drive", gearing.finalDrive, "")]
        if let gears = gearing.gears, !gears.isEmpty {
            lines.append(TuneLine(label: "Individual gears", value: gears.map { formatted($0) }.joined(separator: " / "), unit: "", detail: nil))
        }
        return section("Gearing", "gearshape.2", lines)
    }

    private var alignmentSection: TuneSection? {
        guard let alignment else { return nil }
        return section("Alignment", "arrow.left.and.right", [
            line("Front camber", alignment.frontCamber, "deg"),
            line("Rear camber", alignment.rearCamber, "deg"),
            line("Front toe", alignment.frontToe, "deg"),
            line("Rear toe", alignment.rearToe, "deg"),
            line("Caster", alignment.caster, "deg")
        ])
    }

    private var antirollBarSection: TuneSection? {
        guard let antirollBars else { return nil }
        return section("Antiroll Bars", "arrow.up.left.and.arrow.down.right", [
            line("Front", antirollBars.front, ""),
            line("Rear", antirollBars.rear, "")
        ])
    }

    private var springSection: TuneSection? {
        guard let springs else { return nil }
        return section("Springs", "waveform.path.ecg", [
            line("Front rate", springs.frontRate, "lb/in", digits: 0),
            line("Rear rate", springs.rearRate, "lb/in", digits: 0),
            line("Front ride height", springs.frontRideHeight, "in"),
            line("Rear ride height", springs.rearRideHeight, "in")
        ])
    }

    private var dampingSection: TuneSection? {
        guard let damping else { return nil }
        return section("Damping", "slider.horizontal.3", [
            line("Front rebound", damping.frontRebound, ""),
            line("Rear rebound", damping.rearRebound, ""),
            line("Front bump", damping.frontBump, ""),
            line("Rear bump", damping.rearBump, "")
        ])
    }

    private var aeroSection: TuneSection? {
        guard let aero else { return nil }
        return section("Aero", "wind", [
            line("Front", aero.front, "lb", digits: 0),
            line("Rear", aero.rear, "lb", digits: 0)
        ])
    }

    private var brakeSection: TuneSection? {
        guard let brakes else { return nil }
        return section("Brakes", "exclamationmark.octagon", [
            line("Balance", brakes.balancePercent, "%", digits: 0),
            line("Pressure", brakes.pressurePercent, "%", digits: 0)
        ])
    }

    private var differentialSection: TuneSection? {
        guard let differential else { return nil }
        return section("Differential", "point.3.connected.trianglepath.dotted", [
            line("Accel", differential.accelPercent, "%", digits: 0),
            line("Decel", differential.decelPercent, "%", digits: 0),
            line("Front accel", differential.frontAccelPercent, "%", digits: 0),
            line("Front decel", differential.frontDecelPercent, "%", digits: 0),
            line("Rear accel", differential.rearAccelPercent, "%", digits: 0),
            line("Rear decel", differential.rearDecelPercent, "%", digits: 0),
            line("Center balance", differential.centerBalanceRearPercent, "% rear", digits: 0)
        ])
    }

    private func section(_ title: String, _ symbolName: String, _ lines: [TuneLine?]) -> TuneSection? {
        let resolvedLines = lines.compactMap { $0 }
        guard !resolvedLines.isEmpty else { return nil }
        return TuneSection(title: title, symbolName: symbolName, lines: resolvedLines)
    }

    private func line(_ label: String, _ value: Double?, _ unit: String, digits: Int = 1) -> TuneLine? {
        guard let value else { return nil }
        return TuneLine(label: label, value: formatted(value, digits: digits), unit: unit, detail: nil)
    }

    private func formatted(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits)))
    }
}

extension Array where Element == TuneSection {
    func merging(into existingSections: [TuneSection]) -> [TuneSection] {
        var mergedSections = existingSections

        for partialSection in self {
            guard let sectionIndex = mergedSections.firstIndex(where: { $0.title == partialSection.title }) else {
                mergedSections.append(partialSection)
                continue
            }

            mergedSections[sectionIndex].lines = partialSection.lines.merging(
                into: mergedSections[sectionIndex].lines
            )
        }

        return mergedSections
    }
}

extension Array where Element == TuneLine {
    func merging(into existingLines: [TuneLine]) -> [TuneLine] {
        var mergedLines = existingLines

        for partialLine in self {
            if let lineIndex = mergedLines.firstIndex(where: { $0.label == partialLine.label }) {
                mergedLines[lineIndex] = partialLine
            } else {
                mergedLines.append(partialLine)
            }
        }

        return mergedLines
    }
}

extension TuneAPINotes {
    func merging(into existingNotes: TuneNotes) -> TuneNotes {
        TuneNotes(
            bias: bias ?? existingNotes.bias,
            ifPushesWide: ifPushesWide ?? existingNotes.ifPushesWide,
            ifSnapsOnLift: ifSnapsOnLift ?? existingNotes.ifSnapsOnLift,
            retuneTrigger: retuneTrigger ?? existingNotes.retuneTrigger
        )
    }
}

extension TuneResult {
    func section(_ title: String) -> TuneSection? {
        sections.first { $0.title == title }
    }
}

extension TuneSection {
    func number(_ label: String) -> Double? {
        lines.first { $0.label == label }?.numericValue
    }
}

extension TuneLine {
    var numericValue: Double? {
        Double(value.replacingOccurrences(of: ",", with: ""))
    }
}

extension DrivingDiscipline {
    var apiValue: String {
        switch self {
        case .road: "road"
        case .touge: "touge"
        case .drift: "drift"
        case .dirt: "dirt"
        case .crossCountry: "cross_country"
        case .drag: "drag"
        }
    }
}
