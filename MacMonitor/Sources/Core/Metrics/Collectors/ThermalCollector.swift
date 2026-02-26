import Combine
import Foundation

protocol ThermalCollecting {
    func collect() -> ThermalSnapshot
    var stateDidChangePublisher: AnyPublisher<ThermalState, Never> { get }
}

struct ThermalCollector: ThermalCollecting {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func collect() -> ThermalSnapshot {
        ThermalSnapshot(state: Self.map(ProcessInfo.processInfo.thermalState))
    }

    var stateDidChangePublisher: AnyPublisher<ThermalState, Never> {
        notificationCenter.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .map { _ in Self.map(ProcessInfo.processInfo.thermalState) }
            .eraseToAnyPublisher()
    }

    private static func map(_ state: ProcessInfo.ThermalState) -> ThermalState {
        switch state {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .unknown
        }
    }
}
