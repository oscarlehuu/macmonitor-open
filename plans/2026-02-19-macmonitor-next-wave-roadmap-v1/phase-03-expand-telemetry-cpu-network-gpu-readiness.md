# Context links
- Parent plan: `./plan.md`
- Inputs: `./research/researcher-01-report.md`, `./research/researcher-02-report.md`
- Core files: `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`, `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`

# Overview
- Date: 2026-02-19
- Description: add CPU and network telemetry now, plus GPU readiness contract without forcing unstable GPU signal in first cut.
- Priority: P2
- Implementation status: implemented-local
- Review status: pending-verification

# Key Insights
- Collector architecture is already modular and easy to extend.
- Menu bar display model needs enum/settings expansion.
- GPU metric quality is hardware/OS-variable; staged delivery reduces risk.

# Requirements
- Add CPU usage collector with rolling smoothing.
- Add network throughput collector (up/down) with interval normalization.
- Extend menu bar mode to include CPU and network.
- Add optional internal GPU collector protocol and fallback `unavailable` state.

# Architecture
- Extend `SystemSnapshot` with `cpu` and `network` snapshots.
- Add `CPUCollector` and `NetworkCollector` protocols + concrete collectors.
- Extend menu bar formatter for new display modes.
- Keep GPU behind protocol boundary to avoid blocking release.

# Related code files
- Modify: `./MacMonitor/Sources/Core/Domain/SystemSnapshot.swift`
- Modify: `./MacMonitor/Sources/Core/Metrics/MetricsEngine.swift`
- Create: `./MacMonitor/Sources/Core/Metrics/Collectors/CPUCollector.swift`
- Create: `./MacMonitor/Sources/Core/Metrics/Collectors/NetworkCollector.swift`
- Modify: `./MacMonitor/Sources/Features/MenuBar/MenuBarDisplayFormatter.swift`
- Modify: `./MacMonitor/Sources/Features/Settings/SettingsStore.swift`

# Implementation Steps
1. Add new domain snapshot structs and backward-compatible decoding defaults.
2. Implement CPU collector using host statistics deltas.
3. Implement network collector using interface counter deltas.
4. Wire collectors into `MetricsEngine` refresh pipeline.
5. Extend settings/UI/menu bar display rendering and tests.

# Todo list
- [ ] Choose default CPU smoothing window.
- [ ] Handle interface resets and sleep/wake counter discontinuities.
- [ ] Add perf guardrails for collector overhead.
- [ ] Define GPU readiness checklist and fallback behavior.

# Success Criteria
- CPU and network metrics appear correctly in menu bar and popover.
- Refresh loop remains stable at shortest refresh interval.
- Existing snapshot consumers remain backward compatible.

# Risk Assessment
- Risk: inaccurate network rates across sleep/wake boundaries.
- Mitigation: reset delta baseline after lifecycle wake event.

# Security Considerations
- Collect only aggregate local host stats.
- No packet inspection or external transmission.

# Next steps
- Reassess GPU implementation feasibility using collected stability data.
