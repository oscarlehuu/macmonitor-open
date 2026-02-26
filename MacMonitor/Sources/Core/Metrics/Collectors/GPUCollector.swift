import Foundation

protocol GPUCollecting {
    func collect() -> GPUSnapshot
}

struct DefaultGPUCollector: GPUCollecting {
    func collect() -> GPUSnapshot {
        .unavailable
    }
}
