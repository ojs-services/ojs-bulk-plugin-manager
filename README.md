# Bulk Plugin Manager for OJS

![Version](https://img.shields.io/badge/version-1.6.2-blue)
![OJS](https://img.shields.io/badge/OJS-3.3.x-green)
![License](https://img.shields.io/badge/license-GPL--3.0-orange)

**Version:** 1.6.2  
**Compatibility:** OJS 3.3.x only (3.3.0.0 - 3.3.0.21)  
**Author:** OJS Services  
**License:** GPL v3

---

## 📋 Description

Bulk Plugin Manager is a comprehensive plugin management tool for Open Journal Systems (OJS). Unlike OJS's standard plugin gallery interface, it displays all plugins on a single page, allows bulk operations, and detects/fixes database-file synchronization issues.

---

## 🎯 When to Use?

### 1. When OJS Plugin Page Crashes
If OJS's `/management/settings/website` > `Plugins` page won't load or is very slow, this is usually caused by database-file version mismatch. Bulk Plugin Manager detects and fixes this issue.

### 2. When Multiple Plugin Updates Are Needed
In the standard OJS interface, you must update plugins one by one. With this plugin, you can select multiple plugins and bulk update them.

### 3. For Quick Plugin Status Overview
Dashboard cards provide instant summary:
- How many plugins installed?
- How many active/inactive?
- How many can be updated?
- Any problematic plugins?

### 4. For Database Cleanup
Detect and clean "ghost" records left in the database from deleted plugins.

### 5. To Fix Version Mismatches
Fix DB-file version differences caused by manual interventions or failed updates with a single click.

---

## ✨ Features

### 🖥️ Modern Dashboard
- **OJS Version:** Running OJS version
- **Gallery Plugins:** Compatible plugins count from PKP Gallery
- **Installed:** Total registered plugins
- **Active/Inactive:** Enabled and disabled plugin counts
- **DB Fix:** Plugins needing database fix
- **Available:** Compatible plugins not yet installed
- **Newer Installed:** Local version newer than Gallery

### 📑 Smart Tab System
| Tab | Description |
|-----|-------------|
| 🔌 **Installed** | All registered plugins with DB/File versions |
| 🔧 **DB Fix Required** | DB version higher than Gallery (needs fix) |
| 🔄 **Sync Issues** | DB ≠ File version (can crash OJS) |
| 📁 **Missing Files** | DB record exists but files deleted |
| ⬆️ **Updates** | Newer versions available |
| 📦 **Available** | New plugins to install |
| ⚠️ **Newer Installed** | Local version > Gallery version |
| ❓ **Not in Gallery** | Custom/third-party plugins |

### 🔍 Filters (Installed Tab)
- **All:** All plugins
- **Active:** Only enabled
- **Inactive:** Only disabled
- **Sync Issues:** DB ≠ File version
- **Missing Files:** No files on server

### 🛠️ Action Buttons
| Button | Function |
|--------|----------|
| **Fix DB** | Sync database version to file version |
| **Clean DB** | Remove all database entries for plugin |
| **Install** | Download and install from PKP Gallery |
| **Update** | Update to latest Gallery version |

### 🌍 Multi-Language Support
- 🇬🇧 English
- 🇹🇷 Türkçe

### 🔒 OJS 3.4+ Protection
Automatically disables on incompatible OJS versions - no white screen or errors.

---

## 📥 Installation

1. Download `bulkPluginManager.tar.gz` from [Releases](../../releases)
2. Extract to `/plugins/generic/` folder
3. Go to OJS Admin Panel > Website Settings > Plugins
4. Enable "Bulk Plugin Manager" under Generic Plugins
5. Click "🔌 Bulk Plugin Manager" link in the sidebar

**Alternative Access (Direct URL):**
```
https://yoursite.com/index.php/JOURNAL/bulkPluginManager
```

---

## 🐛 Common Problems & Solutions

### Problem 1: OJS Plugin Page Not Loading
**Cause:** Database version doesn't match file version  
**Solution:** Go to "Installed" tab → "Sync Issues" filter → Click "Fix DB" for each

### Problem 2: Deleted Plugin Still in List
**Cause:** Files deleted but database records remain  
**Solution:** Go to "Installed" tab → "Missing Files" filter → Click "Clean DB"

### Problem 3: Plugin Won't Update
**Cause:** DB version higher than Gallery (downgrade protection)  
**Solution:** Go to "DB Fix Required" tab → Click "Fix DB" → Then update normally

---

## ⚙️ Technical Details

- **Version Comparison:** Normalized to 4 parts (1.0.0 → 1.0.0.0)
- **Case Insensitive:** Plugin names compared case-insensitively
- **Current Flag:** Fixes OJS current=0 issues automatically
- **Gallery Source:** pkp.sfu.ca/ojs/xml/plugins.xml

---

## 📊 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.6.2 | 2024-12 | Info button moved to header, tab descriptions added |
| 1.6.1 | 2024-12 | Tab layout improvements, separators, mobile scroll |
| 1.6.0 | 2024-12 | All tabs always visible, green zero badges |
| 1.5.x | 2024-12 | Sidebar integration, OJS 3.4+ protection, Info page |
| 1.4.x | 2024-12 | Missing Files filter, removed auto-refresh |
| 1.3.x | 2024-12 | Modern UI, Dashboard, case-insensitive comparison |
| 1.0.0 | 2024-12 | Initial release |

---

## 📌 Important Notes

⚠️ **Backup First:** Recommended before database operations  
👤 **Permissions:** Only Site Admin and Journal Manager can access  
🔒 **OJS 3.4+ Safe:** Auto-disables on incompatible versions  
🌐 **Internet Required:** Plugin info fetched from PKP Gallery

---

## 🤝 Support

- GitHub Issues
- OJS Community Forum
- info@ojs-services.com

---

## 📄 License

This plugin is provided free of charge under the **GNU General Public License v3**.

