# Solution Synthesis Report

Date: 2026-02-07

## Problem statement
Build an open-source macOS Apple Silicon monitor app, ship menu bar first, prioritize thermal state now, add widget later.

## Selected direction
- Architecture: menu bar app as core.
- Heat model (v1): thermal state-based (public API only).
- Refresh cadence: every few minutes default, plus event-driven thermal change updates.
- Update path: manual installer script now, Sparkle later.

## Why this wins
- Fastest route to usable product with minimal permission friction.
- Stable against macOS updates due to public API-first strategy.
- Clean migration path to widget extension through shared snapshot model.

## Deferred work
- Exact temperature in Celsius/Fahrenheit from private/elevated channels.
- Fan/RPM and advanced power sensors.

## Unresolved questions
- Whether to include optional advanced sensor mode in v1.x or defer to v2.
