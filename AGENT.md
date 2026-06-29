# Agent Instructions

This repository should be implemented with direct, explicit behavior.

- Do not add fallback code paths unless the user explicitly asks for one.
- Do not add timeout-based logic.
- Do not use `setTimeout`, `setInterval`, sleep delays, retry delays, polling loops, or similar timer-based behavior.
- Do not hide errors behind generic fallback behavior. Surface the real error and fix the root cause.
- Do not silently continue when a required configuration, file, payment record, or service response is missing.
- Prefer deterministic state, explicit validation, and clear failure responses.
