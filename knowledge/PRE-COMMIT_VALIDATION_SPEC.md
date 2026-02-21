## Submodule Pre-Commit Validation Plan 🧷

### Summary

Implement a submodule-local hook system in catalogues/virginie-prints-catalogue using a single Git entrypoint (pre-commit) that dispatches to multiple named validation hooks (one script per validation).
This satisfies your requirement that each validation is its own hook while remaining compatible with native Git hooks.

### Scope and Goal

- Goal: prevent bad catalogue commits in the submodule before they are created.
- Scope: only pre-commit in the submodule repo.
- Enforcement level: blocking on all validation failures.
- Path policy: strict block for any staged path outside _products/.

## Implementation Design 🏗️

### 1. Hook layout

Create these files in the submodule:

- .githooks/pre-commit (dispatcher entrypoint)
- .githooks/hooks/check-top-level-paths
- .githooks/hooks/check-product-slug-format
- .githooks/hooks/check-product-required-files
- .githooks/hooks/check-product-allowed-filenames
- .githooks/hooks/check-index-frontmatter-schema
- .githooks/hooks/check-product-content-quality
- .githooks/lib/common.sh (shared helpers: staged files, error formatting, product folder extraction)
- scripts/install-hooks.sh (runs git config core.hooksPath .githooks inside submodule)

All hook scripts executable and invoked in deterministic order by .githooks/pre-commit.

### 2. Dispatcher behavior (.githooks/pre-commit)

- Compute staged files via git diff --cached --name-only --diff-filter=ACMR.
- If no staged files: exit 0.
- Run each named hook script sequentially.
- Aggregate failures and print clear per-hook failure sections.
- Exit non-zero if any hook fails.

### 3. Validation hooks (decision-complete rules)

#### check-top-level-paths

- Fail if any staged path does not start with _products/.
- This includes blocking staged edits to README.md, .gitignore, .github/**, etc.

#### check-product-slug-format

- For touched product directories under _products/<slug>/, enforce:
    - slug matches ^[a-z0-9]+(-[a-z0-9]+)*$.
- Fail on uppercase, underscores, spaces, special chars, leading/trailing -, double --.

#### check-product-required-files

- For each touched product directory (existing after staging):
    - require _products/<slug>/index.md
    - require _products/<slug>/image.jpg (exact lowercase filename)
- Fail if either is missing.

#### check-product-allowed-filenames

- For each touched product directory, allowed files are:
    - index.md
    - image.jpg
    - additional images with extensions: .jpg, .jpeg, .png, .webp (case-insensitive allowed for extension only)
- Fail on any other filename/extension.
- Fail if main image uses wrong reserved name (e.g. image.png as main required asset does not satisfy required-file hook).

#### check-index-frontmatter-schema

For each touched _products/<slug>/index.md:

- Require valid YAML front matter delimiters (--- start and end).
- Parse YAML safely.
- Validate:
    - title: required, non-empty string
    - featured: optional; if present must be boolean
    - versions: required, array (can be empty)
    - each version item: object with required non-empty string technique
    - each version.sizes: required, array (can be empty)
    - each sizes item: object with required non-empty string size and required numeric price > 0

#### check-product-content-quality

- Enforce non-positive price rejection (price <= 0 fails).
- Enforce empty/whitespace-only string rejection for:
    - title, technique, size
- Enforce duplicate (technique, size) detection:
    - normalized by trimming surrounding whitespace and case-folding
    - duplicates in same product fail commit.

## Public Interfaces / Contract Changes 🔌

- New contributor workflow in submodule:
    - Run scripts/install-hooks.sh once per clone.
- New documented local contract:
    - Commits are blocked unless staged changes are limited to _products/** and pass all validations.
- No runtime/API changes to website rendering; only content authoring workflow changes.

## Test Plan ✅

### Manual acceptance scenarios

1. Stage edit to _products/foo/index.md with valid metadata → commit passes.
2. Stage README.md in submodule → blocked by check-top-level-paths.
3. Add _products/Bad_Slug/index.md → blocked by slug check.
4. Add product folder missing image.jpg → blocked by required-files check.
5. Add unexpected file _products/foo/notes.txt → blocked by allowed-filenames check.
6. Invalid front matter (missing closing ---) → blocked.
7. featured: "yes" → blocked (if present non-boolean).
8. versions: [] and valid other fields → allowed.
9. sizes: [] under a version and valid other fields → allowed.
10. price: 0 or -1 → blocked.
11. Duplicate technique+size entries in same product → blocked.
12. Only untouched product files changed outside staged set → ignored (staged-only evaluation).

### Optional automated self-test

- Add scripts/test-hooks.sh that creates temporary staged fixtures in a temp git worktree and asserts pass/fail per case above.

## Assumptions and Defaults 📌

- Git-native hooks only; no Python/Node dependency required.
- “Each validation as its own hook” is implemented as one script per validation, orchestrated by pre-commit.
- Strict path policy is intentional and will block non-product maintenance commits in submodule unless --no-verify is used.
- Validations operate on staged changes to keep hooks fast and predictable.
