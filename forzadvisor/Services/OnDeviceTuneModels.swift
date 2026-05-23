//
//  OnDeviceTuneModels.swift
//  forzadvisor
//
//  Foundation Models guided-generation schema and mapping helpers. The schema
//  mirrors the existing API tune sections, then maps into TuneResult so every
//  provider shares the same renderer and persistence model.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels

@Generable(description: "Complete Forza Horizon 6 tune response.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceTuneResponse {
    let tune: OnDeviceTune
    let notes: OnDeviceTuneNotes
}

@Generable(description: "Complete tune sections in Forza tune-menu order.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceTune {
    let tires: OnDeviceTires
    let gearing: OnDeviceGearing
    let alignment: OnDeviceAlignment
    let arbs: OnDeviceFrontRear
    let springs: OnDeviceSprings
    let damping: OnDeviceDamping
    let aero: OnDeviceAero
    let brakes: OnDeviceBrakes
    let differential: OnDeviceDifferential
}

@Generable(description: "Tire pressure values in PSI.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceTires {
    let frontPsi: Double
    let rearPsi: Double
}

@Generable(description: "Gearing values.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceGearing {
    let finalDrive: Double
}

@Generable(description: "Alignment values in degrees.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceAlignment {
    let frontCamber: Double
    let rearCamber: Double
    let frontToe: Double
    let rearToe: Double
    let caster: Double
}

@Generable(description: "Front and rear paired values.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceFrontRear {
    let front: Double
    let rear: Double
}

@Generable(description: "Spring rates and ride heights.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceSprings {
    let frontRate: Double
    let rearRate: Double
    let frontRideHeight: Double
    let rearRideHeight: Double
}

@Generable(description: "Damping values.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceDamping {
    let frontRebound: Double
    let rearRebound: Double
    let frontBump: Double
    let rearBump: Double
}

@Generable(description: "Aero downforce in pounds.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceAero {
    let frontPounds: Double
    let rearPounds: Double
}

@Generable(description: "Brake balance and pressure percentages.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceBrakes {
    let balancePercent: Double
    let pressurePercent: Double
}

@Generable(description: "Differential percentages. Leave irrelevant drivetrain fields nil.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceDifferential {
    let accelPercent: Double?
    let decelPercent: Double?
    let frontAccelPercent: Double?
    let frontDecelPercent: Double?
    let rearAccelPercent: Double?
    let rearDecelPercent: Double?
    let centerBalanceRearPercent: Double?
}

@Generable(description: "Short tune notes.", representNilExplicitlyInGeneratedContent: true)
struct OnDeviceTuneNotes {
    let bias: String
    let ifPushesWide: String
    let ifSnapsOnLift: String
    let retuneTrigger: String
}

extension OnDeviceTuneResponse {
    @MainActor
    func tuneResult(for request: TuneRequest, id: UUID, generatedAt: Date) -> TuneResult {
        asPartiallyGenerated().tuneResult(for: request, id: id, generatedAt: generatedAt)
    }
}

extension OnDeviceTuneResponse.PartiallyGenerated {
    @MainActor
    func tuneResult(for request: TuneRequest, id: UUID, generatedAt: Date) -> TuneResult {
        TuneResult(
            id: id,
            request: request,
            sections: tune?.apiTune.sections() ?? [],
            notes: notes.resolvedNotes,
            generatedAt: generatedAt
        )
    }
}

private extension Optional where Wrapped == OnDeviceTuneNotes.PartiallyGenerated {
    @MainActor
    var resolvedNotes: TuneNotes {
        TuneNotes(
            bias: self?.bias?.shortNote ?? "Streaming on-device tune.",
            ifPushesWide: self?.ifPushesWide?.shortNote ?? "Ask for more rotation if the car pushes wide.",
            ifSnapsOnLift: self?.ifSnapsOnLift?.shortNote ?? "Ask for more stability if the car snaps on lift.",
            retuneTrigger: self?.retuneTrigger?.shortNote ?? "Re-tune if weight distribution shifts more than 2%."
        )
    }
}

private extension OnDeviceTune.PartiallyGenerated {
    @MainActor
    var apiTune: TuneAPITune {
        TuneAPITune(
            tires: tires.map {
                TuneAPITires(
                    frontPsi: clamp($0.frontPsi, 15...40),
                    rearPsi: clamp($0.rearPsi, 15...40)
                )
            },
            gearing: gearing.map {
                TuneAPIGearing(finalDrive: clamp($0.finalDrive, 2.5...5.5))
            },
            alignment: alignment.map {
                TuneAPIAlignment(
                    frontCamber: clamp($0.frontCamber, -5...0),
                    rearCamber: clamp($0.rearCamber, -5...0),
                    frontToe: clamp($0.frontToe, -2...2),
                    rearToe: clamp($0.rearToe, -2...2),
                    caster: clamp($0.caster, 3...8)
                )
            },
            antirollBars: arbs.map {
                TuneAPIFrontRear(
                    front: clamp($0.front, 1...65),
                    rear: clamp($0.rear, 1...65)
                )
            },
            springs: springs.map {
                TuneAPISprings(
                    frontRate: clamp($0.frontRate, 100...2_000),
                    rearRate: clamp($0.rearRate, 100...2_000),
                    frontRideHeight: clamp($0.frontRideHeight, 2...12),
                    rearRideHeight: clamp($0.rearRideHeight, 2...12)
                )
            },
            damping: damping.map {
                TuneAPIDamping(
                    frontRebound: clamp($0.frontRebound, 1...20),
                    rearRebound: clamp($0.rearRebound, 1...20),
                    frontBump: clamp($0.frontBump, 1...20),
                    rearBump: clamp($0.rearBump, 1...20)
                )
            },
            aero: aero.map {
                TuneAPIAero(
                    frontPounds: clamp($0.frontPounds, 0...600),
                    rearPounds: clamp($0.rearPounds, 0...600)
                )
            },
            brakes: brakes.map {
                TuneAPIBrakes(
                    balancePercent: clamp($0.balancePercent, 0...100),
                    pressurePercent: clamp($0.pressurePercent, 50...200)
                )
            },
            differential: differential.map {
                TuneAPIDifferential(
                    accelPercent: clamp($0.accelPercent, 0...100),
                    decelPercent: clamp($0.decelPercent, 0...100),
                    frontAccelPercent: clamp($0.frontAccelPercent, 0...100),
                    frontDecelPercent: clamp($0.frontDecelPercent, 0...100),
                    rearAccelPercent: clamp($0.rearAccelPercent, 0...100),
                    rearDecelPercent: clamp($0.rearDecelPercent, 0...100),
                    centerBalanceRearPercent: clamp($0.centerBalanceRearPercent, 0...100)
                )
            }
        )
    }
}

private func clamp(_ value: Double?, _ range: ClosedRange<Double>) -> Double? {
    guard let value else { return nil }
    return min(max(value, range.lowerBound), range.upperBound)
}

private extension String {
    var shortNote: String {
        String(prefix(120))
    }
}
#endif
