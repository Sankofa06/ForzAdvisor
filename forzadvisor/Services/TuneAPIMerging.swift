import Foundation

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
                var replacement = partialLine
                if replacement.fieldID == nil {
                    replacement.fieldID = mergedLines[lineIndex].fieldID
                }
                mergedLines[lineIndex] = replacement
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
