# Solution Synthesis: Persistent Per-App RAM Policy (Notify-Only)

## Locked Decisions (from user)
- Scope: total app RAM (main + helpers).
- Limit input: user can pick `%` or `GB`.
- Trigger behavior: support immediate and sustained modes.
- Enforcement action: notify only.
- App eligibility: allow any app.
- Event history: keep logs for 7 days.
- Storage location: `~/Library/Application Support/com.oscar.macmonitor/`.

## Recommended v1 Shape
1. Add a small RAM policy domain (`Core/RAMPolicy`) with JSON persistence.
2. Add app-usage aggregation by bundle id from process snapshots.
3. Add threshold evaluator supporting `%` and `GB`, immediate/sustained/both.
4. Add notify-only execution path with cooldown and retention-pruned logs.
5. Add simple policy UI in Settings for create/edit/enable/disable.

## Why This Is Best Fit
- KISS/YAGNI: no new DB stack, no daemon, no kill/quit behavior.
- Reuses existing process and metrics flow instead of parallel monitoring architecture.
- Keeps user mental model simple: pick app, pick `%` or `GB`, pick trigger, receive alerts.

## Risks and Guards
- Attribution ambiguity for non-bundled processes: log and surface clearly as unresolved/unknown app.
- Notification permissions off: persist events and show in-app warning instead of failing hard.
- Alert spam: enforce per-policy cooldown.

## Unresolved Questions
- Default sustained window confirmation (plan assumes 15 seconds).
- UI placement preference if we need one launch surface only.
