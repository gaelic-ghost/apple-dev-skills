# AGENTS.md

- Use `xcode-app-project-workflow` for normal work inside this existing Xcode project.
- Use `sync-xcode-project-guidance` when this repo's local workflow guidance drifts and should be refreshed or merged forward.
- Re-run `sync-xcode-project-guidance` after substantial Xcode-workflow or plugin updates so local guidance stays aligned.
- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation, `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps, and `scripts/repo-maintenance/release.sh` for releases.
- Read relevant Apple documentation before proposing or making Xcode, SwiftUI, lifecycle, or architecture changes.
- Prefer the simplest correct Swift that is easiest to read and reason about.
- Prefer synthesized and framework-provided behavior over extra wrappers and boilerplate.
- Keep data flow straight and dependency direction unidirectional.
- Prefer Swift Testing for modern unit-style tests, keep XCTest where Apple tooling or dependencies still require it, and use XCUITest with explicit element wait APIs instead of fixed sleeps.
- Keep `.xctestplan` files versioned when the project depends on repeatable test-plan configurations, and inspect or run them explicitly with `xcodebuild -showTestPlans` and `xcodebuild -testPlan ...`.
- When scripts add files on disk, verify project membership, target membership, build phases, and resource inclusion afterward; files existing in the directory tree alone are not enough.
- Validate both Debug and Release paths when behavior can diverge, and treat tagged releases as a cue to build and verify Release artifacts in addition to the everyday Debug flow.
- Never edit `.pbxproj` files directly. If a project-file change is needed and no safe project-aware tool is available, stop and make that change through Xcode instead.
