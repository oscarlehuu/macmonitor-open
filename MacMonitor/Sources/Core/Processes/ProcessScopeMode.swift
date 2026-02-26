import Foundation

enum ProcessScopeMode: String, CaseIterable, Identifiable {
    case sameUserOnly
    case allDiscoverable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sameUserOnly:
            return "Mine"
        case .allDiscoverable:
            return "All"
        }
    }
}
