import SwiftData
import XCTest
@testable import forzadvisor

class FH5ResearchTestCase: XCTestCase {
    let capturedAt = Date(timeIntervalSinceReferenceDate: 1_000)
    let recordID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let submissionID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    let permissionID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
    let snapshotID = UUID(uuidString: "40000000-0000-0000-0000-000000000004")!
}
