# SourceHut Migration Spec (Repo A + Repo B)

## Purpose

This document specifies how to migrate the current GitHub-based deployment setup to SourceHut while preserving the same operating model:

- Repo A (`my-catalogue`) contains website code, build pipeline, and deploy logic.
- Repo B (`virginie-prints-catalogue`) contains content only (product metadata + source images).
- A push to Repo B should eventually trigger a rebuild and redeploy of Repo A static site.

This is intended for a future Codex session to implement from end to end.

## Current Implementation (GitHub)

### Repository structure and content flow

- Repo A: Jekyll site and pipeline.
  - `index.html`, `_layouts/`, `assets/`, `_config.yml`
  - `scripts/generate_product_images.rb`
  - `Rakefile` tasks:
    - `rake images` -> generate derivatives from Repo B sources
    - `rake build` -> `rake images` + `jekyll build`
- Repo B: Git submodule in A at:
  - `catalogues/virginie-prints-catalogue`
  - tracks `master` in `.gitmodules`
- Source assets in B:
  - `catalogues/virginie-prints-catalogue/_products/<slug>/index.md`
  - `catalogues/virginie-prints-catalogue/_products/<slug>/image.jpg`
  - optional extra images in same folder
- Generated public derivatives (ignored in git, built in CI):
  - `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-320.jpg`
  - `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-580.jpg`
  - `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-square-900.jpg`
  - `catalogues/virginie-prints-catalogue/products-assets/<slug>/image-max-1000.jpg`
  - optional `image-max-1000_*.jpg`

### Current GitHub workflows

- A: `.github/workflows/pages.yml`
  - Trigger: push on `master` with path filters (site/build/catalogue-relevant files)
  - Builds with Ruby + ImageMagick detection/fallback install
  - Runs `bundle exec rake build`
  - Deploys `_site` to GitHub Pages
- A: `.github/workflows/update-catalogue-submodule.yml`
  - Trigger: `repository_dispatch` (`catalogue-updated`) and manual
  - Updates submodule pointer to latest B `master`
  - Commits and pushes if changed
  - Uses `SUBMODULE_BUMP_PUSH_TOKEN` for push auth
- B: `.github/workflows/notify-my-catalogue.yml`
  - Trigger: push on B `master`
  - Sends dispatch to A using `MY_CATALOGUE_DISPATCH_TOKEN`

## Target Implementation (SourceHut)

### Goals

1. Host static site on `pages.sr.ht`.
2. Build site in `builds.sr.ht`.
3. Keep Repo A + Repo B separation.
4. Trigger A rebuild when B changes.
5. Preserve current image derivative behavior.

### Key design decision

SourceHut does not provide a direct equivalent of GitHub `repository_dispatch` between repos out of the box in the same way Actions does. The robust design is:

- Push to Repo B emits webhook event (`git.sr.ht` webhook).
- A small relay endpoint receives event and submits a build job for Repo A via `builds.sr.ht` API.
- Build job checks out Repo A + submodule B, runs `bundle exec rake build`, publishes `_site` to `pages.sr.ht`.

## Migration Plan

## Phase 1 - Prepare SourceHut repos

1. Create Repo A and Repo B on `git.sr.ht`.
2. Mirror or migrate history from GitHub.
3. Ensure Repo A submodule URL points to SourceHut Repo B URL (not GitHub URL) in `.gitmodules`.
4. Ensure the tracked submodule branch stays `master` (or choose `main` consistently across both repos).
5. Push both repos to SourceHut and verify:
   - fresh clone of A
   - `git submodule update --init --recursive` succeeds

## Phase 2 - Add SourceHut build manifest to Repo A

Add `.build.yml` in Repo A with:

- image/container containing Ruby toolchain
- dependency install (`bundle install` or equivalent cache strategy)
- ImageMagick availability check with install fallback if missing
- build command:
  - `bundle exec rake build`
- publish command:
  - `hut pages publish -d _site <your-pages-site>`
- OAuth scope for pages publish:
  - `pages.sr.ht/PAGES:RW`

Notes:
- Keep build deterministic; do not rely on pre-existing generated files.
- Build should always generate `products-assets` from B source.

## Phase 3 - Configure automatic deploy from Repo A pushes

Enable builds webhook/integration for Repo A so pushes to A `master` trigger `.build.yml`.

Equivalent to current GitHub behavior:
- only relevant changes should trigger expensive builds.

Two options:
- Simpler: trigger on every push to A `master`.
- Optimized: in `.build.yml` or relay logic, inspect changed paths and early-exit if irrelevant.

## Phase 4 - Implement B -> A rebuild trigger

Implement a relay service (minimal HTTP endpoint) that:

1. Receives webhook from B push event.
2. Validates authenticity (shared secret or signature).
3. Submits a build to Repo A via `builds.sr.ht` API.
4. Returns success/failure and logs payload.

Recommended relay runtime:
- Cloudflare Worker, tiny Fly.io app, or small VPS endpoint.

Webhook payload requirement:
- At least repo identifier + branch ref + commit SHA.
- Only trigger for B `master`.

Build submit request should include:
- Repo A clone URL
- branch (`master`)
- manifest path (`.build.yml`)
- optional env/context values (`CATALOGUE_SHA` for traceability)

## Phase 5 - Remove GitHub-specific automation (optional cutover)

After SourceHut pipeline is stable:

- In Repo A, remove:
  - `.github/workflows/pages.yml`
  - `.github/workflows/update-catalogue-submodule.yml`
- In Repo B, remove:
  - `.github/workflows/notify-my-catalogue.yml`
- Remove now-unused GitHub secrets:
  - `MY_CATALOGUE_DISPATCH_TOKEN`
  - `SUBMODULE_BUMP_PUSH_TOKEN`

Keep this cleanup as a separate commit after successful cutover.

## Required behavior parity checklist

The migrated setup is complete only if all items pass:

1. Pushing to B `master` triggers a rebuild of A automatically.
2. Build checks out latest B content through submodule.
3. `scripts/generate_product_images.rb` runs successfully in SourceHut environment.
4. Generated `products-assets` are not committed, only published output contains them.
5. Jekyll output paths are correct for target SourceHut Pages URL/base path.
6. Site renders:
   - main listing images
   - modal max-size image
   - modal additional images navigation
   - sorting/filter controls behavior unchanged

## Base URL and routing notes

Current `_config.yml` values are GitHub-specific:

- `url: https://xpac27.github.io`
- `baseurl: /my-catalogue`

For SourceHut:

- Update `url` to SourceHut/custom-domain URL.
- Set `baseurl` according to final site path:
  - usually empty for root-hosted custom domain
  - non-empty if served under subpath

Validate generated HTML links for:

- `/assets/css/site.css`
- logo paths
- `catalogues/virginie-prints-catalogue/products-assets/...`

## Security and credentials

Credentials needed in SourceHut context:

1. Token or OAuth capability for `hut pages publish`.
2. Credentials for relay to submit `builds.sr.ht` jobs.
3. Webhook secret between B and relay.

Guidelines:
- least privilege
- no hardcoded tokens in repo
- rotate secrets after migration

## Rollout strategy

1. Stand up SourceHut build+publish on A only (manual trigger).
2. Verify output parity against GitHub Pages.
3. Enable B webhook to relay and automatic trigger.
4. Run in parallel for a short period (GitHub + SourceHut) and compare.
5. Switch DNS/custom domain to SourceHut target.
6. Remove GitHub Actions and secrets after confirmation.

## Operational runbook (post-migration)

When content editor pushes to B:

1. B webhook fires.
2. Relay submits A build.
3. Build clones A with submodule B.
4. `bundle exec rake build` runs.
5. `_site` published to `pages.sr.ht`.

If deployment fails:

1. Inspect `builds.sr.ht` logs for missing tools/auth/path issues.
2. Verify submodule fetch URL and branch.
3. Verify ImageMagick is available in build env.
4. Re-run build manually.

## Implementation task list for future Codex session

1. Add `.build.yml` to Repo A.
2. Update `.gitmodules` submodule URL to SourceHut repo URL.
3. Update `_config.yml` (`url` and `baseurl`) for SourceHut target.
4. Add short deployment section in `README.md` for SourceHut commands.
5. Implement relay endpoint code and deployment instructions.
6. Configure B webhook to relay endpoint.
7. Test B push -> A rebuild -> pages publish.
8. Cut over and remove GitHub workflows/secrets (optional final cleanup).

## Known risks

- Submodule auth failures in build environment.
- Incorrect `baseurl` causing broken assets after domain switch.
- Relay reliability (missed webhook events).
- ImageMagick package differences across build images.

Mitigations:
- explicit branch pinning
- retryable relay submit logic
- build log monitoring
- staged rollout with parallel hosting window

