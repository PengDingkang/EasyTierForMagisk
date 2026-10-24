# EasyTier For Magisk v1.2.0

**Upgrade notice: shell command mounting defaults to OFF for new installs and legacy upgrades without a saved preference.** After reboot, use `/data/adb/easytier/easytier` from a root shell and update scripts that relied on short command names. Previously saved mount choices are preserved.

- Use a separate main-table policy priority for this service so stopping it preserves WireGuard and other modules; add lifecycle routing regression coverage.
- Add the module-wide **Shell Command Mount** switch and `easytier mount {enable|disable|status|supported}` CLI commands; switching requires a reboot.
- Disable the option and reject CLI enable requests on KernelSU without an enabled mounting metamodule. Magisk/APatch keep their built-in mounting support.
- Use data-directory tools for WebUI, boot autostart and internal calls so the service remains available without system mounts.
- Preserve existing service configuration and identity data, and add upgrade/provider/private-tool/boot regression coverage to build and release checks.
- Fetch official EasyTier tools by a pinned release tag and archive SHA256, verify ARM64 static ELF files, and cache the verified archive across build/release workflows.
- Stop tracking generated core/CLI binaries in Git without rewriting existing history.
- Avoid duplicate system tools by creating mount payloads only on demand; synchronize choices with pending upgrades and roll back failed payload preparation.
- Add core integrity/cache-key regression tests and pin CI runners to Ubuntu 24.04.
- Publish updater metadata only after the uploaded public ZIP matches the local package; preserve stable metadata on failures or prereleases, and retry concurrent branch updates without downgrading versions.

Core version: `v2.6.4`

# EasyTier For Magisk v1.1.2

- Updated bundled EasyTier Core to `v2.6.4`
- Added KernelSU no-overlay fallback paths for WebUI and boot auto-start

Core version: `v2.6.4`

# EasyTier For Magisk v1.1.1

- Switched module update metadata to a static repository `update.json`
- Improved release workflow and package contents validation
- Added shell script checks in GitHub Actions
- Improved WebUI log viewer:
  - added log clear action
  - stripped ANSI color escape codes from displayed logs
- Refined module versioning:
  - module version is managed independently
  - bundled EasyTier Core version is tracked separately

Core version: `v2.6.0`
