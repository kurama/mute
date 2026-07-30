# Releasing Mute

Mute ships through two channels with very different timing:

- **Mac App Store** — Apple reviews every build **manually and asynchronously** (hours to days). CI can *upload* a build but can never know whether it will be *accepted*.
- **Homebrew / direct download** — a Developer ID–signed, notarized `.dmg`. Publishing it is instant.

To avoid Homebrew ever serving a version the App Store later **rejects**, the release is split into two phases. Nothing is public until you promote it.

## Phase 1 — build & stage (automatic)

Push the version tag:

```bash
git tag v1.2.3
git push origin v1.2.3
```

This runs [`release.yml`](.github/workflows/release.yml), which:

1. Archives, exports and **uploads the build to App Store Connect** (`altool`). This only *delivers* it to Apple — it does not submit for review or wait for acceptance.
2. Builds, **notarizes and staples** the Developer ID `.dmg`.
3. Creates a **draft** GitHub release with the `.dmg` attached.

At this point nothing is public: no published release, no Homebrew update.

> You can also run the workflow manually (`workflow_dispatch`) against an existing tag to rebuild it.

## Phase 2 — promote (manual, after App Store acceptance)

Wait for Apple to **accept** the build in App Store Connect. Then run the
**Promote release** workflow (`workflow_dispatch`) with the tag (e.g. `v1.2.3`).
This runs [`promote.yml`](.github/workflows/promote.yml), which:

1. Downloads the staged `.dmg` from the draft release.
2. **Publishes** the GitHub release (undrafts it, marks it latest).
3. Points the [Homebrew tap](https://github.com/kurama/homebrew-tap) at it (version + SHA-256).

Only now is the version installable via `brew` and the direct download — and by
then you already know the App Store accepted it.

## Required secrets

`APPSTORE_CERTIFICATE`, `APPSTORE_CERTIFICATE_PASSWORD`, `APPSTORE_PROVISIONING_PROFILE`,
`DEVID_CERTIFICATE`, `DEVID_CERTIFICATE_PASSWORD`, `KEYCHAIN_PASSWORD`,
`APPLE_ID`, `APP_SPECIFIC_PASSWORD`, `TAP_TOKEN`.
