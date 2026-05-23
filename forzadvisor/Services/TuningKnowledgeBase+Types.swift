//
//  TuningKnowledgeBase+Types.swift
//  forzadvisor
//
//  Small value types returned by the source-backed offline tuning tables.
//

import Foundation

struct TirePressureBaseline: Equatable {
    var frontPsi: Double
    var rearPsi: Double
    var detail: String
}

struct AlignmentBaseline: Equatable {
    var frontCamber: Double
    var rearCamber: Double
    var frontToe: Double
    var rearToe: Double
    var caster: Double
}

struct SpringBaseline: Equatable {
    var frontRate: Double
    var rearRate: Double
}

struct DampingBaseline: Equatable {
    var frontRebound: Double
    var rearRebound: Double
    var frontBump: Double
    var rearBump: Double
}

struct FrontRearBaseline: Equatable {
    var front: Double
    var rear: Double
}

struct BrakeBaseline: Equatable {
    var balancePercent: Double
    var pressurePercent: Double
}

struct DifferentialBaseline: Equatable {
    var accel: Double?
    var decel: Double?
    var frontAccel: Double?
    var frontDecel: Double?
    var rearAccel: Double?
    var rearDecel: Double?
    var centerBalance: Double?

    init(
        accel: Double? = nil,
        decel: Double? = nil,
        frontAccel: Double? = nil,
        frontDecel: Double? = nil,
        rearAccel: Double? = nil,
        rearDecel: Double? = nil,
        centerBalance: Double? = nil
    ) {
        self.accel = accel
        self.decel = decel
        self.frontAccel = frontAccel
        self.frontDecel = frontDecel
        self.rearAccel = rearAccel
        self.rearDecel = rearDecel
        self.centerBalance = centerBalance
    }
}
