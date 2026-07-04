# Bulk Plugin Manager for OJS

![Version](https://img.shields.io/badge/version-1.11.0-blue)
![OJS](https://img.shields.io/badge/OJS-3.3.x-green)
![License](https://img.shields.io/badge/license-GPL--3.0-orange)

A full-featured plugin management dashboard for Open Journal Systems (OJS) 3.3.x. Manage, update, install, and troubleshoot all your plugins from a single page.

![Screenshot](screenshot1.png)

## Features

- **Dashboard** - Overview of all plugins with status counts at a glance
- **Bulk Operations** - Select multiple plugins and update/install in one go
- **OJS Services** - Browse and install plugins from [github.com/ojs-services](https://github.com/ojs-services) directly
- **DB Sync Fix** - Detect and repair database-file version mismatches that crash the OJS plugin page
- **Backup & Restore** - Automatic backups on update with one-click restore
- **PKP Gallery** - Install any compatible plugin from the official PKP Plugin Gallery
- **Sidebar Navigation** - OJS-style left menu for quick access across backend pages
- **Bilingual UI** - English and Turkish interface

## Installation

1. Download `bulkPluginManager.tar.gz` from [Releases](../../releases)
2. Extract to `plugins/generic/` in your OJS installation
3. Enable **Bulk Plugin Manager** under Website Settings > Plugins > Generic Plugins

## Access

```
https://yoursite.com/index.php/JOURNAL/bulkPluginManager
```

Or click the **Bulk Plugin Manager** link in the OJS sidebar.

## Compatibility

OJS 3.3.0.0 - 3.3.0.22

## Security

All state-changing actions require a valid OJS CSRF token. Both **site
administrators** and **journal managers** may use the tool — letting editors
manage plugins without a site-admin account is the plugin's core purpose.
(Enabling a plugin is per-journal, so a manager installing a plugin does not
activate it in other journals.) Plugin packages are downloaded only over HTTPS from
trusted PKP Gallery / `ojs-services` GitHub hosts, and every archive is checked
for path-traversal ("Zip Slip") entries before extraction. XML from remote
sources is parsed with network access and external entities disabled (XXE-safe).

> **Note:** GitHub release downloads are protected by HTTPS and a strict host
> allowlist. Release assets do not publish checksums, so no additional hash
> verification is performed for `ojs-services` downloads.

## Optional configuration

The plugin discovers `ojs-services` plugins through the GitHub API, which is
limited to 60 requests/hour for anonymous callers. To raise this to 5000/hour,
add a personal access token to `config.inc.php`:

```ini
[bulk_plugin_manager]
github_token = "ghp_your_token_here"
```

The token needs no scopes (public repositories only). When unset, anonymous
access is used and a cached repository list is shown if the limit is reached.

## License

[GPL v3](LICENSE)

## Author

[OJS Services](https://github.com/ojs-services)
