# Changelog — bulkPluginManager

All notable changes to this plugin. Line = supported OJS series.
Package name: `bulkPluginManager-ojs<line>-<version>.tar.gz`.

## 1.12.4.0 — 2026-11-14 — OJS 3.3
- OJS Services: a release is offered only if its tag or package name matches the running OJS line (e.g. `ojs3.3-…` on OJS 3.3). Among matching releases the highest version is chosen.
- GitHub source archives are no longer used as a fallback. If no package exists for this OJS version, the card says so.
- Before installing a package without a `<compatibility>` block, the code is checked: OJS 3.4/3.5 code (namespaced classes) is refused on OJS 3.3 and vice versa.
- After every install or update, OJS is started in a separate process with the new plugin loaded. If that fails, the previous version and its database version record are restored automatically.
- Fixes OJS 3.4/3.5 packages being installed on OJS 3.3 sites when a release had no `<compatibility>` block.

## 1.12.3.0 — 2026-10-13 — OJS 3.3
- Backups tab: select several backups and delete them in one step. Quick selections: all, keep the newest backup of each plugin, older than 30 days.

## 1.12.2.0 — 2026-09-30 — OJS 3.3
- OJS Services: release packages are chosen by file name (`<product>-ojs<line>-<version>.tar.gz`); the package built for the running OJS line is installed, demo builds are never installed. Releases with older asset names keep working.
- Added this changelog.

## 1.12.1.0 — 2026-09-25 — OJS 3.3
- Fixed a template error in 1.12.0.0 that prevented the page from opening.

## 1.12.0.0 — 2026-09-25 — OJS 3.3 (withdrawn)
- OJS Services: enable/disable installed plugins per journal and open their settings from the same card, using OJS's own plugin actions.
- Withdrawn because of a template error; use 1.12.1.0 or later.

## 1.11.8.0 — 2026-09-25 — OJS 3.3
- Actions no longer report a server error when the server prints PHP notices before the response; successful updates are shown as successful.

## 1.11.7.0 — 2026-09-25 — OJS 3.3
- A plugin whose own `version.xml` lists earlier 3.3.0.x patch versions is accepted on later 3.3.0.x installations; packages for another OJS series are still refused.

## 1.11.6.0 — 2026-09-25 — OJS 3.3
- PKP Gallery compatibility is evaluated exactly as OJS does, including version ranges (e.g. `~3.3.0.18`). Fixes plugins such as iThenticate appearing as "Newer" while OJS offered an update.

## 1.11.5.0 — 2026-09-08 — OJS 3.3
- OJS Services offer and install the release that matches the running OJS version.
- The Installed tab correctly detects plugins that are still available in the PKP Gallery.
- A downloaded package is verified (plugin identity and OJS compatibility) before it replaces an existing plugin.

## 1.11.4.0 — 2026-09-08 — OJS 3.3
- Internal build; superseded by 1.11.5.0.

## 1.11.3.0 — 2026-08-04 — OJS 3.3
- Clean DB works for orphaned records left by legacy plugin categories (e.g. OJS 2 citation, metadata and auth plugins).

## 1.11.2.0 — 2026-08-03 — OJS 3.3
- Clean DB verifies on the server that a plugin's files are genuinely gone before removing records, refuses installed or unreadable plugins, and writes a restorable `.sql` backup first.

## 1.11.1.0 — 2026-07-19 — OJS 3.3
- Runs inside the standard OJS backend layout with the native navigation menu; the menu link is a native OJS menu item.

## 1.11.0.0 — 2026-07-04 — OJS 3.3
- Security hardening (CSRF, archive path validation, download URL validation, safe XML parsing).
- Bulk actions on the Installed tab (Fix DB, Reinstall, Clean DB) and clearer missing/orphaned classification.
- Optional GitHub API token; improved error handling; external stylesheet.
