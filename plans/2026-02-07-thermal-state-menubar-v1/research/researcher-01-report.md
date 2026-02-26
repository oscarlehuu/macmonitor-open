# Researcher 01 Report: Apple Silicon Thermal + Metrics APIs

Date: 2026-02-07
Scope: public APIs first, non-public alternatives second.

## Findings
- Public thermal API exists: `ProcessInfo.processInfo.thermalState` + `NSProcessInfoThermalStateDidChangeNotification`.
- Public API does not expose exact CPU package temperature in Celsius/Fahrenheit.
- Public system counters for memory/CPU/load are available through host/vm Mach APIs (`host_statistics64`, `host_processor_info`, `vm_statistics64`).
- `MetricKit` is useful for aggregate performance/energy trends, not real-time menu bar values.

## Non-public / elevated options
- `powermetrics` can expose richer thermal/power data, but typically requires root.
- Private IOReport-based paths used by OSS tools can work but have breakage risk on macOS updates.

## Recommendation
- v1 ship with public APIs only.
- Render heat via thermal state levels and trend history.
- Keep an optional advanced sensor mode for future only if user explicitly opts in.

## Risks
- Users may expect exact Celsius by default; must set expectation in UI copy.
- Thermal state is coarse; use trend + severity color to improve utility.

## Sources
- https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum
- https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/RespondToThermalStateChanges.html
- https://developer.apple.com/documentation/kernel/1502863-host_statistics64
- https://developer.apple.com/documentation/kernel/1502854-host_processor_info
- https://developer.apple.com/documentation/kernel/vm_statistics64_t
- https://manp.gs/mac/1/powermetrics
