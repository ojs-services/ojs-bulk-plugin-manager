# Bulk Plugin Manager for OJS

![Version](https://img.shields.io/badge/version-1.9.0-blue)
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

## License

[GPL v3](LICENSE)

## Author

[OJS Services](https://github.com/ojs-services)
