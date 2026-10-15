# Project version policy

This is the authoritative version policy supplied by the PZ AI Development Framework. Project copies inherit it as a local policy; other instructions summarize or reference it. This policy does not weaken multiplayer/server-authority, sandbox or dedicated-runtime gates.

## One canonical Project Version
Use a root `VERSION` UTF-8 file containing one SemVer value and an optional final newline. No `v` prefix or comments. `version-inventory.json` declares that path and all current mirrors; it is an inventory, not another authoritative version value. An existing project's machine-readable metadata may remain the sole authority only through a documented migration/adapter decision; never create two authoritative fields. This bundled checker reads a one-line canonical file, so a non-file authority requires an explicitly implemented/tested adapter before adoption. Do not deploy or restructure active repositories automatically.

SemVer is MAJOR.MINOR.PATCH, optionally a prerelease and build suffix: `1.2.0-dev.1`, `1.2.0-alpha.1`, `1.2.0-beta.1`, `1.2.0-rc.1`, `1.2.0+build.7`. Core numbers and numeric prerelease identifiers have no leading zeroes. Build metadata does not change precedence but must match in current mirrors. See [SemVer 2.0.0](https://semver.org/spec/v2.0.0.html).

Define the public compatibility contract: gameplay functionality, configuration, persistence/saves and exposed APIs. PATCH fixes compatible bugs/crashes/typos/UI/internal behavior (`1.4.2 -> 1.4.3`). MINOR adds compatible features/options/UI/integrations/capabilities (`1.4.3 -> 1.5.0`). MAJOR makes incompatible API/config/save/removal/redesign changes (`1.5.0 -> 2.0.0`). Size alone never justifies MAJOR. Reset lower components on MINOR/MAJOR. For 0.y.z development, document compatibility changes explicitly rather than hiding breaks behind an unexplained bump.

## Version categories
- Project: this mod's canonical value, mirrored only at declared current locations.
- PZ: targeted/tested game build (for example versionMin); not the mod's version.
- Dependency: upstream release/revision/hash, independent of the project value.
- Framework: toolchain version or template provenance, not the mod's value. For the framework itself, its root VERSION is its own Project Version.
- Compatibility/API/schema: independently justified protocol/schema version; never infer it equals Project Version.

An upstream or framework change does not automatically bump mod versions. Classify actual project changes. Dates and historical release records are not current mirrors.

Inventory-only categories `inventory-schema` and `project-fixture` identify the checker format and independently versioned synthetic/seed projects. Neither is a second authority for the current project.

## Development lifecycle
At requirements/design, record current, target development and expected release versions with PATCH/MINOR/MAJOR rationale. Discover unknown values from source, never guess. When new-version work starts, update VERSION and current mirrors in the same bounded change before implementation: for example 1.4.2 -> 1.5.0-dev.1. Track meaningful changes in an Unreleased section or the current prerelease entry. Increment meaningful checkpoints deliberately; not every edit needs a bump. Optional alpha/beta/rc phases are not mandatory. Scope changes may revise the target/classification with a decision record. A justified small change can target its final version directly. Never leave unreleased behavior mislabeled as the older released version.

Before and after implementation, inventory/reconcile mirrors and run the checker. Only the writer updates versions; Scout/Auditor/Reviewer remain read-only and report inconsistencies. Do not mechanically bump versions without understanding compatibility impact.

## Explicit version inventory
`version-inventory.json` is machine-readable; `docs/VERSIONING.md` explains it. Inventory applicable mod.info `modversion`, Lua/Java constants, metadata/manifests, README/current docs, validation headers, current changelog/release notes, build/test fixtures, generated staging metadata, package filenames and Workshop version text. Do not invent fields just to fill the list. Do not edit installed/Workshop files to sync them: update source and authorized generators, and validate generated output.

Use exact file paths and targeted regex selectors with a named `(?P<version>...)` group. Each selector's match count defaults to one; missing or duplicate matches fail. All matches must equal canonical. `format` may derive an external representation using `{version}`, `{major}`, `{minor}`, `{patch}`, `{prerelease}`, `{build}` only, with a documented external-system `reason`; it cannot define an independent version. Preserve full SemVer by default. Current mirrors must exist; `stage: release` defers missing generated mirrors during development but requires them with --release, and validates them whenever present.

Maintain `other_versions` and `historical` classifications. Historical changelog entries, pinned dependency/PZ/schema references, old reports/backups and immutable released artifacts retain the version actually observed. Never rewrite history or fabricate refreshed test evidence to match a new number. Current validation summaries must identify the current version; old evidence can be reused only with a documented applicability assessment and must retain its tested version. Inventory completeness requires human/agent review; the checker never guesses that every numeric string is Project Version.

## Changelog and packaging
The declared changelog selector chooses the newest entry (first match), not any historical match. Stable versions and all --release checks require a nonempty newest entry for exactly the canonical version. Development prereleases may instead use a nonempty Unreleased entry. Every published version needs accurate change text; do not rewrite an immutable release in place. Preserve the existing changelog location where practical.

Packaging reads VERSION. Versioned filenames embed that value (example ModName-1.5.0.zip). Keep current output in a dedicated directory, such as dist/current; inventory a version-independent glob so stale names are not hidden by a glob containing the expected version. Every matched filename must contain the expected version, and --release requires at least one file per declared artifact rule. Development checks report absent packages as deferred, not validated. Generated metadata can be declared as mirrors; ZIP members can be checked explicitly with member/pattern/count entries. Packages without versioned names still require inventoried embedded version metadata or an explicit external-format adapter.

Use `packaging.not_applicable_reason` only when the project really has no distribution artifacts (such as an in-place framework update). A gameplay mod cannot use it to skip its actual packages. The seed template declares ZIP packaging that must be customized before release. Archive old released artifacts separately; do not rename them to the current version. Checksum/source parity and PZ/runtime correctness are separate validations.

## Checker interface / inventory schema 1
Run `python scripts/check_versions.py --root .` during development; run again with `--release` after authorized artifacts exist and before G8. Exit 1 blocks release; exit 0 only proves the declared version checks. `--json` returns version, errors, notes and checked paths. The framework reuses this script at project-template/scripts/check_versions.py with --root pointing to the framework; there is no second checker implementation.

Required JSON keys: schema (1), canonical (path), mirrors (list), changelog (path/pattern), packaging (artifacts list or empty list plus N/A reason), other_versions (category/reference/reason list), historical (reference/reason list). Mirrors support path, pattern, count, format, reason, stage. Artifact entries support glob, pattern (full filename match), format, reason, zip_members; ZIP-member entries use member, pattern, count, format, reason. Paths are root-relative and cannot escape the root. Patterns are Python multiline regexes; named version capture required. No commands or code from the inventory are executed. See the checked-in seed inventory for a working example.

## G8 version gate
Require valid canonical SemVer and inventory; synchronized metadata/code/docs/current validation and release notes; newest current changelog; correct current packages and embedded metadata where declared; no unintended stale current references. Version mismatch means G8 BLOCKED, never a warning. Complete declared --release validation after packaging, in addition to prior required gates. The standalone template is a scaffold, not a release-ready mod; its seed 0.1.0-dev.1 must never overwrite an existing project's version. Dedicated multiplayer G7 remains mandatory before gameplay G8.
