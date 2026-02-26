# Phase 02: Metrics Engine + Thermal Domain

## Context links
- Parent plan: `./plan.md`
- Dependencies: Phase 01
- Docs: Foundation ProcessInfo thermal APIs, Mach host/vm stats

## Overview
- Date: 2026-02-07
- Description: implement collectors for RAM/storage/thermal state with refresh policy.
- Priority: P1
- Implementation status: pending
- Review status: pending

## Key Insights
- Thermal should be event-driven + periodic refresh for resilience.
- RAM/storage should be sampled on schedule, no busy polling.

## Requirements
- Thermal state collector using official APIs only.
- RAM usage collector (`used`, `total`, `pressure hint`).
- Storage collector for startup volume and optional selected volume.
- Snapshot domain model with timestamp + staleness metadata.

## Architecture
- `Core/Metrics/MetricsEngine.swift`: orchestrates collectors.
- `Core/Metrics/Collectors/ThermalCollector.swift`
- `Core/Metrics/Collectors/MemoryCollector.swift`
- `Core/Metrics/Collectors/StorageCollector.swift`
- `Core/Domain/SystemSnapshot.swift`

## Related code files
- `MacMonitor/Core/Domain/SystemSnapshot.swift`
- `MacMonitor/Core/Metrics/MetricsEngine.swift`
- `MacMonitor/Core/Metrics/Collectors/ThermalCollector.swift`
- `MacMonitor/Core/Metrics/Collectors/MemoryCollector.swift`
- `MacMonitor/Core/Metrics/Collectors/StorageCollector.swift`
- `MacMonitorTests/Core/MetricsEngineTests.swift`

## Implementation Steps
1. Define immutable snapshot DTOs and formatting helpers.
2. Implement collector protocols with async entrypoints.
3. Add thermal-state change observer and debounced emission.
4. Add scheduler (default 180s, configurable).
5. Write unit tests with fakes for deterministic snapshots.

## Todo list
- [ ] Thermal enum mapping to UI semantics.
- [ ] Snapshot stale-state computation.
- [ ] Failure handling (`unknown`, last-known-good fallback).
- [ ] Tests for collector timeout and partial failure.

## Success Criteria
- Snapshot updates every configured interval.
- Thermal transitions update within 2s of notification.
- Collector failures do not crash app.

## Risk Assessment
- OS notifications may be sparse; must keep periodic fallback.
- Incorrect memory math can confuse users.

## Security Considerations
- Use only non-privileged public APIs in v1.
- Avoid private frameworks and shelling out in metrics path.

## Next steps
- Build UX layer to present metrics and settings safely.
