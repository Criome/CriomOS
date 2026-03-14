# Guard Blockers

1. `execute session-guard` (run 2026-03-14 17:40) failed because the current HEAD (02a15921) is not pushed to `origin/dev`. This guard must be rerun after the runtime bookmark is pushed.
2. `execute root-guard` failed due to a missing sidecar: `Components/mentci-aid/src/actors/root_guard.edn` does not exist in this nested repo context. This artifact is required by root guard and should exist upstream or be provided before the guard can pass.

Both blockers are recorded here for traceability. The session guard should be rerun immediately after the push completes; the root guard failure likely needs a repository-wide fix and should be revisited once the missing sidecar is present.
