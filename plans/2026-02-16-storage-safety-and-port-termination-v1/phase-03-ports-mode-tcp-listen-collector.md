## 1) Context links
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/plan.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/research/researcher-02-report.md`
- `./plans/2026-02-16-storage-safety-and-port-termination-v1/scout/scout-01-report.md`
- `./MacMonitor/Sources/Core/Processes/LibprocProcessListCollector.swift`
- `./MacMonitor/Sources/Core/Processes/ProcessProtectionPolicy.swift`
- `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`

## 2) Overview
- date: 2026-02-16
- description: Introduce RAM Details Ports mode backed by a TCP LISTEN-only collector.
- priority: P2
- implementation status: pending
- review status: pending

## 3) Key Insights
- `lsof` is practical for stable port-to-PID mapping on macOS.
- V1 must stay TCP LISTEN only to avoid scope explosion.
- Existing protection policy can be reused to pre-mark blocked rows.

## 4) Requirements
- Add a new RAM mode/tab named `Ports`.
- Collect ports from one snapshot command per refresh.
- Restrict to TCP `LISTEN` only in v1.
- Show all rows by default, including protected/non-selectable rows with visible reason labels.
- Model fields: protocol, port, pid, processName, user, protectionReason.
- Apply protection policy for selectable vs blocked rows.
- Testing strategy: parser fixture tests + view-model mode-switch tests.

## 5) Architecture
- Create dedicated ports collector service in `Core/Processes`.
- Collector outputs normalized `ListeningPort` domain rows.
- `RAMDetailsViewModel` owns mode switching and row state.
- Wire service through `AppContainer` for testability.

## 6) Related code files
- create: `./MacMonitor/Sources/Core/Processes/ListeningPortModels.swift`
- create: `./MacMonitor/Sources/Core/Processes/LsofListeningPortCollector.swift`
- modify: `./MacMonitor/Sources/Core/DI/AppContainer.swift`
- modify: `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsViewModel.swift`
- modify: `./MacMonitor/Sources/Features/RAMDetails/RAMDetailsView.swift`
- create: `./MacMonitor/Tests/LsofListeningPortCollectorTests.swift`
- modify: `./MacMonitor/Tests/RAMDetailsViewModelTests.swift`

## 7) Implementation Steps
1. Define `ListeningPort` model and parser contract.
2. Implement LISTEN-only `lsof` snapshot collector.
3. Add DI registration and view-model loading path for Ports mode.
4. Add Ports UI mode and row presentation.
5. Add parser fixtures and mode-switch tests.

## 8) Todo list
- [ ] Define `ListeningPort` model with protection metadata.
- [ ] Implement TCP LISTEN-only collector.
- [ ] Add Ports mode state to RAM view-model.
- [ ] Render Ports mode in RAM details view.
- [ ] Add parser and mode-switch tests.

## 9) Success Criteria
- Ports mode shows TCP LISTEN rows with owning PID.
- Protected/system rows are visible but non-selectable.
- Parser and mode tests pass on representative output.

## 10) Risk Assessment
- Risk: `lsof` output shape drift by macOS variant.
- Risk: large port lists impacting refresh responsiveness.
- Mitigation: strict parser tests and bounded snapshot parsing.

## 11) Security Considerations
- No shell interpolation from user input in collector command.
- UI copy must state action kills owning process, not socket.
- Protection policy runs before any termination action.

## 12) Next steps
- Move to phase 4 for PID dedupe and graceful-to-force termination in Ports mode.
