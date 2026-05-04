import Foundation

enum SlideDuration: String, Equatable, Sendable, CaseIterable, Codable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case thirty = "30"
    case sixty = "60"
    case manual

    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        case .sixty: return 60
        case .manual: return nil
        }
    }

    var displayLabel: String {
        switch self {
        case .five: return "5 sec"
        case .ten: return "10 sec"
        case .fifteen: return "15 sec"
        case .thirty: return "30 sec"
        case .sixty: return "60 sec"
        case .manual: return "None"
        }
    }
}
