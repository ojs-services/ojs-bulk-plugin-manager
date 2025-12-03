# Revolutionizing OJS Plugin Management: Bulk Plugin Manager

**This free plugin for OJS 3.3.x simplifies plugin management, solves common problems, and saves you hours of work.**

---

## 🎯 Why We Developed This Plugin

One of the most common issues OJS users face: **"The Plugins page won't load!"**

This problem usually stems from version mismatches between the database and file system. When this happens, OJS's standard interface completely freezes, leaving administrators helpless.

That's exactly why we developed **Bulk Plugin Manager**.

---

## ✨ Key Features

### 📊 Instant Dashboard
See your entire plugin status at a glance:
- Your OJS version
- Installed, active, and inactive plugin counts
- Plugins awaiting updates
- Problematic plugins

### 🔧 Automatic Problem Detection
The plugin automatically detects the following issues:
- **Sync issues:** Database and file versions differ
- **Missing files:** Database record exists but files are deleted
- **Version conflicts:** Local version is higher than Gallery version

### ⚡ One-Click Fixes
Ready-made solution buttons for every problem:
- **Fix DB:** Synchronizes database version with file
- **Clean DB:** Removes orphan records
- **Install:** Downloads missing files from Gallery
- **Update:** Updates plugin to the latest version

### 🌍 Multi-Language Support
- 🇬🇧 English
- 🇹🇷 Türkçe

### 📱 Modern Interface
- Responsive design
- Smart filtering system
- Bulk operation support
- Real-time progress indicator

---

## 🚀 When Should You Use It?

### 1. When OJS Plugin Page Won't Load
The most common scenario! When the OJS plugin page freezes due to database-file mismatch, Bulk Plugin Manager comes to the rescue. You can access it directly via URL:
```
https://yoursite.com/index.php/journal/bulkPluginManager
```

### 2. When You Need to Update Multiple Plugins
In the standard OJS interface, you have to update plugins one by one. With Bulk Plugin Manager, you can select multiple plugins and update them with a single click.

### 3. When You Need Plugin Cleanup
Ideal for detecting and cleaning up "ghost" records left in the database from deleted plugins.

### 4. For Quick Status Check
Get instant summaries with dashboard cards and spot issues immediately.

---

## 📑 What Do the Tabs Mean?

| Tab | Description |
|-----|-------------|
| 🔌 **Installed** | All installed plugins. Shows DB and file versions side by side. |
| 🔧 **DB Fix Required** | Plugins where database version is higher than Gallery. Requires fixing. |
| 🔄 **Sync Issues** | Plugins where DB and file versions differ. Can cause OJS page to freeze. |
| 📁 **Missing** | Plugins with deleted files but remaining DB records. |
| ⬆️ **Updates** | Plugins awaiting updates. |
| 📦 **Available** | Not yet installed, available plugins. |
| ⚠️ **Newer Installed** | Local version is newer than Gallery. Usually not a problem. |
| ❓ **Not in Gallery** | Custom plugins not found in PKP Gallery. |
| ℹ️ **Info** | Comprehensive user guide. |

---

## 🔍 How Do Filters Work?

The **Installed** tab has 5 filters:

| Filter | Shows |
|--------|-------|
| **All** | All plugins |
| **Active** | Only active ones |
| **Inactive** | Only inactive ones |
| **Sync Issues** | Plugins where DB ≠ File version |
| **Missing Files** | Plugins without files |

---

## 🛠️ What Do the Buttons Do?

### 🔧 Fix DB
Synchronizes database version with file version. Use when:
- OJS plugin page won't load
- Plugin is stuck in "current=0" error
- Version mismatch after manual intervention

### 🗑️ Clean DB
Deletes all database records for the plugin (versions + plugin_settings). Use when:
- You manually deleted plugin files
- Plugin appears in list but has no files

### 📦 Install
Downloads and installs the plugin from PKP Gallery. Use when:
- You want to install a new plugin
- You want to re-download missing files

### ⬆️ Update
Downloads and updates to the latest version from Gallery.

---

## 🐛 Common Problems and Solutions

### Problem 1: OJS Plugin Page Won't Load
**Cause:** Database version doesn't match file version. OJS sets current=0 and the page freezes.

**Solution:** 
1. Access Bulk Plugin Manager via URL
2. Go to "Installed" tab
3. Select "Sync Issues" filter
4. Click "Fix DB" button on each row

### Problem 2: Deleted Plugin Still in List
**Cause:** Files were deleted but database records remain.

**Solution:**
1. Go to "Installed" tab
2. Select "Missing Files" filter
3. Click "Clean DB" button

### Problem 3: Plugin Won't Update
**Cause:** Local version is higher than Gallery version (downgrade protection).

**Solution:**
1. Go to "DB Fix Required" tab
2. Reset version with "Fix DB"
3. Then update normally

---

## ⚙️ Technical Details

- **Compatibility:** OJS 3.3.x (3.3.0.0 - 3.3.0.21)
- **OJS 3.4+ Protection:** Automatically disabled on incompatible versions
- **Version Comparison:** Normalized to 4 parts (1.0.0 → 1.0.0.0)
- **Case-Insensitive:** openAIRE = openaire
- **Gallery Source:** pkp.sfu.ca/ojs/xml/plugins.xml

---

## 📥 Installation

1. Download the plugin file
2. Extract to `/plugins/generic/` folder
3. OJS Admin Panel > Website Settings > Plugins
4. Generic Plugins > "Bulk Plugin Manager for OJS" → Enable
5. Click "🔌 Bulk Plugin Manager" link in the sidebar

**Alternative Access:**
```
https://yoursite.com/index.php/JOURNAL/bulkPluginManager
```

---

## 📥 Download Links

<!-- DOWNLOAD LINKS TO BE ADDED HERE -->



---

## 📌 Important Notes

⚠️ **Backup First:** We recommend backing up before performing database operations.

👤 **Permissions:** Only Site Administrator and Journal Manager roles can access.

🔒 **OJS 3.4+ Safety:** This plugin is only compatible with OJS 3.3.x. If installed on OJS 3.4 or higher, it automatically disables itself—no white screen or errors.

🌐 **Internet Required:** Plugin information is fetched from PKP Gallery, internet connection required.

---

## 📊 Version History

| Version | Features |
|---------|----------|
| 1.5.3 | OJS 3.4+ protection, sidebar integration, Info page |
| 1.4.x | Missing Files filter, performance improvements |
| 1.3.x | Modern UI, Dashboard, case-insensitive comparison |
| 1.0.0 | Initial release |

---

## 🤝 Support

For questions or suggestions:
- GitHub Issues
- OJS Community Forum
- support@ojsservices.com

---

## 📄 License

This plugin is provided free of charge under the **GNU General Public License v3**.

---

*Developed with ❤️ by OJS Services.*
