import Foundation
import CoreGraphics

struct WindowMatchCandidate {
    let title: String?
    let frame: CGRect
    let screenName: String
    let role: String?
    let subrole: String?
}

struct WindowMatchAssignment {
    let savedIndex: Int
    let runningIndex: Int
    let score: Int

    var isLowConfidence: Bool {
        score < 200
    }
}

enum WindowMatcher {
    static func match(saved: [WindowSnapshot], running: [WindowMatchCandidate]) -> [WindowMatchAssignment] {
        var unmatchedSaved = Array(saved.indices)
        var unmatchedRunning = Array(running.indices)
        var assignments: [WindowMatchAssignment] = []

        while !unmatchedSaved.isEmpty && !unmatchedRunning.isEmpty {
            var best: WindowMatchAssignment?

            for savedIndex in unmatchedSaved {
                for runningIndex in unmatchedRunning {
                    let score = score(saved: saved[savedIndex], running: running[runningIndex])
                    let candidate = WindowMatchAssignment(
                        savedIndex: savedIndex,
                        runningIndex: runningIndex,
                        score: score
                    )

                    if best == nil || candidate.score > best!.score {
                        best = candidate
                    }
                }
            }

            guard let best else { break }
            assignments.append(best)
            unmatchedSaved.removeAll { $0 == best.savedIndex }
            unmatchedRunning.removeAll { $0 == best.runningIndex }
        }

        return assignments
    }

    static func score(saved: WindowSnapshot, running: WindowMatchCandidate) -> Int {
        var score = 0

        let savedTitle = normalized(saved.windowTitle)
        let runningTitle = normalized(running.title)

        if let savedTitle {
            if let runningTitle {
                if savedTitle == runningTitle {
                    score += 1000
                } else if savedTitle.contains(runningTitle) || runningTitle.contains(savedTitle) {
                    score += 400
                } else {
                    score -= 250
                }
            } else {
                score -= 100
            }
        }

        if let role = saved.windowRole, role == running.role {
            score += 120
        }

        if let subrole = saved.windowSubrole, subrole == running.subrole {
            score += 60
        }

        if saved.screenName == running.screenName {
            score += 40
        }

        let sizeDelta = abs(saved.frame.width - Double(running.frame.width)) +
            abs(saved.frame.height - Double(running.frame.height))
        score += max(0, 120 - Int(sizeDelta.rounded()))

        return score
    }

    private static func normalized(_ title: String?) -> String? {
        guard let title else { return nil }
        let normalized = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }
}
