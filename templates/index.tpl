<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bulk Plugin Manager</title>
    <link rel="stylesheet" href="{$pluginStylePath|escape}">
</head>
<body>
    <!-- Mobile sidebar toggle -->
    <button class="ojs-sidebar-toggle" onclick="document.querySelector('.ojs-sidebar').classList.toggle('open')">☰</button>

    <!-- OJS Sidebar -->
    <nav class="ojs-sidebar">
        <div class="ojs-sidebar-header">
            <a href="{url page="index"}" class="context-name" id="sidebarContextName">
                {if $currentContext}{$currentContext->getLocalizedName()|escape}{else}OJS{/if}
            </a>
        </div>
        <div class="ojs-sidebar-nav">
            <ul>
                <li><a href="{url page="submissions"}"><span class="nav-icon">📋</span> <span data-i18n="navSubmissions">Submissions</span></a></li>
                <li><a href="{url page="manageIssues"}"><span class="nav-icon">📰</span> <span data-i18n="navIssues">Issues</span></a></li>
                <li><div class="nav-divider"></div></li>

                <li><span class="nav-group-label" data-i18n="navSettings">Settings</span></li>
                <li>
                    <ul class="nav-submenu">
                        <li><a href="{url page="management" op="settings" path="context"}"><span class="nav-icon">📖</span> <span data-i18n="navJournal">Journal</span></a></li>
                        <li><a href="{url page="management" op="settings" path="website"}"><span class="nav-icon">🌐</span> <span data-i18n="navWebsite">Website</span></a></li>
                        <li><a href="{url page="management" op="settings" path="workflow"}"><span class="nav-icon">⚙️</span> <span data-i18n="navWorkflow">Workflow</span></a></li>
                        <li><a href="{url page="management" op="settings" path="distribution"}"><span class="nav-icon">📤</span> <span data-i18n="navDistribution">Distribution</span></a></li>
                        <li><a href="{url page="management" op="settings" path="access"}"><span class="nav-icon">👥</span> <span data-i18n="navUsersRoles">Users & Roles</span></a></li>
                    </ul>
                </li>

                <li><span class="nav-group-label" data-i18n="navStatistics">Statistics</span></li>
                <li>
                    <ul class="nav-submenu">
                        <li><a href="{url page="stats" op="publications"}"><span class="nav-icon">📊</span> <span data-i18n="navStatsArticles">Articles</span></a></li>
                        <li><a href="{url page="stats" op="editorial"}"><span class="nav-icon">✏️</span> <span data-i18n="navStatsEditorial">Editorial Activity</span></a></li>
                        <li><a href="{url page="stats" op="users"}"><span class="nav-icon">👤</span> <span data-i18n="navStatsUsers">Users</span></a></li>
                        <li><a href="{url page="stats" op="reports"}"><span class="nav-icon">📋</span> <span data-i18n="navStatsReports">Reports</span></a></li>
                    </ul>
                </li>

                <li><a href="{url page="management" op="tools"}"><span class="nav-icon">🔨</span> <span data-i18n="navTools">Tools</span></a></li>
                <li><a href="{url journal="index" page="admin"}"><span class="nav-icon">🛡️</span> <span data-i18n="navAdministration">Administration</span></a></li>

                <li><div class="nav-divider"></div></li>
                {foreach from=$sidebarPlugins item=sp}
                    <li><a href="{url page=$sp.page op=$sp.op}"{if $sp.page == 'bulkPluginManager'} class="active"{/if}><span class="nav-icon">{$sp.icon}</span> {$sp.label}</a></li>
                {/foreach}
            </ul>
        </div>
    </nav>

    <!-- Page Wrapper -->
    <div class="page-wrapper">
    <div class="main-content">
        <!-- Header -->
        <div class="header-bar">
            <div class="back-link">
                <a href="{url page="management" op="settings" path="website"}">← <span data-i18n="backToOJS">Back to OJS Panel</span></a>
            </div>
            <div class="header-top">
                <div class="header-title">
                    <span>🔌</span>
                    <span data-i18n="title">Bulk Plugin Manager for OJS</span>
                </div>
                <div class="header-actions">
                    <button class="lang-btn active" onclick="setLang('en')">EN</button>
                    <button class="lang-btn" onclick="setLang('tr')">TR</button>
                    <button class="btn btn-light" onclick="loadPlugins(true)">🔄 <span data-i18n="refresh">Refresh</span></button>
                    <button class="btn btn-success" id="processBtn" onclick="processSelected()" disabled>
                        ⬆️ <span data-i18n="processSelected">Process Selected</span>
                    </button>
                    <button class="btn btn-info" onclick="setActiveTab('info')">
                        ℹ️ <span data-i18n="tabInfo">Info</span>
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Dashboard -->
        <div class="dashboard" id="dashboard"></div>
        
        <!-- Sync Alert -->
        <div class="alert alert-warning" id="syncAlert" style="display: none;">
            <span class="alert-text">⚠️ <span data-i18n="syncWarning">Version sync issues detected. Fix before updating.</span></span>
            <button class="btn btn-warning" onclick="fixSyncIssues()">🔧 <span data-i18n="fixSync">Fix Sync Issues</span></button>
        </div>
        
        <!-- Completed Section - Üstte göster -->
        <div class="completed-section" id="completedSection">
            <div class="completed-header">✅ <span data-i18n="completedOps">Completed Operations</span> (<span id="completedCount">0</span>)</div>
            <div class="completed-list" id="completedList"></div>
        </div>
        
        <!-- Tabs Container -->
        <div class="tabs-container" id="tabsContainer">
            <div class="tabs-header" id="tabsHeader"></div>
            <div class="tabs-content-wrapper" id="tabsContent"></div>
        </div>
    </div>
    
    <!-- Sticky Footer -->
    <div class="footer">
        <span data-i18n="poweredBy">Powered by</span> <a href="https://ojs-services.com/" target="_blank">OJS Services</a> ·
        <span data-i18n="version">Version</span> 1.11.0 ·
        OJS <span id="ojsVersion">-</span>
    </div>
    </div><!-- /page-wrapper -->

    <!-- Progress Modal -->
    <div class="progress-overlay" id="progressOverlay">
        <div class="progress-modal">
            <div class="progress-title" data-i18n="processing">Processing...</div>
            <div class="progress-bar-bg">
                <div class="progress-bar" id="progressBar">0%</div>
            </div>
            <div class="progress-info" id="progressInfo">0 / 0</div>
            <div class="progress-current" id="progressCurrent"></div>
            <div class="progress-counters">
                <div class="counter">
                    <div class="counter-value success" id="liveSuccess">0</div>
                    <div class="counter-label" data-i18n="success">Success</div>
                </div>
                <div class="counter">
                    <div class="counter-value error" id="liveError">0</div>
                    <div class="counter-label" data-i18n="failed">Failed</div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
    var i18n = {
        en: {
            title: 'Bulk Plugin Manager for OJS',
            backToOJS: 'Back to OJS Panel',
            refresh: 'Refresh',
            processSelected: 'Process Selected',
            syncWarning: 'Version sync issues detected. Fix before updating.',
            fixSync: 'Fix Sync Issues',
            completedOps: 'Completed Operations',
            poweredBy: 'Powered by',
            version: 'Version',
            processing: 'Processing...',
            success: 'Success',
            failed: 'Failed',
            error: 'Error',
            errServer: 'Server error. Please reload the page and try again.',
            selectAllMissing: 'Select all missing',
            selectAllActionable: 'Select all fixable',
            bulkFixDb: 'Fix DB (selected)',
            bulkReinstall: 'Reinstall selected',
            bulkCleanDb: 'Clean DB (selected)',
            confirmBulkClean: 'plugin(s) will have their database records PERMANENTLY deleted (settings included). This does not touch files. Continue?',
            bulkNoReinstallable: 'None of the selected plugins are in the PKP Gallery, so they cannot be reinstalled. Use "Clean DB" to remove orphaned records.',
            loading: 'Loading plugins...',
            selectAll: 'Select all',
            search: 'Search plugins...',
            allUpToDate: 'All plugins are up to date!',
            completed: 'Completed!',
            confirmProcess: 'plugins will be processed. Continue?',
            confirmFix: 'sync issues will be fixed. Continue?',
            dashOJS: 'OJS Version',
            dashGallery: 'Gallery Plugins',
            dashInstalled: 'Installed',
            dashActive: 'Active',
            dashInactive: 'Inactive',
            dashSync: 'Sync Issues',
            dashDbFix: 'DB Fix',
            dashMissing: 'Missing Files',
            dashUpdate: 'Updates',
            dashAvailable: 'Available',
            dashDowngrade: 'Newer Installed',
            tabInstalled: 'Installed',
            tabDbFix: 'DB Fix Required',
            tabSync: 'Sync Issues',
            tabMissing: 'Missing',
            tabUpdate: 'Updates',
            tabAvailable: 'Available',
            tabDowngrade: 'Newer',
            tabNotInGallery: 'Not in Gallery',
            thPlugin: 'Plugin',
            thCategory: 'Category',
            thDB: 'DB',
            thFile: 'File',
            thGallery: 'Gallery',
            thVersion: 'Version',
            thDesc: 'Description',
            thStatus: 'Status',
            statusSync: 'Sync issue',
            statusMissing: 'Missing',
            statusAvailable: 'Available',
            statusDowngrade: 'Newer installed',
            statusNotInGallery: 'Not in gallery',
            statusDone: 'Done',
            statusActive: 'Active',
            statusInactive: 'Inactive',
            filterAll: 'All',
            filterActive: 'Active',
            filterInactive: 'Inactive',
            filterSync: 'Sync Issues',
            filterMissing: 'Missing Files',
            btnFix: '🔧 Fix DB',
            btnInstall: '📦 Install',
            btnCleanDb: '🗑️ Clean DB',
            fixing: 'Fixing...',
            fixed: 'Fixed',
            installed: 'Installed',
            cleaning: 'Cleaning...',
            cleaned: 'Cleaned',
            confirmCleanDb: 'Are you sure you want to remove this plugin from database? This will delete all plugin settings.',
            dbFixInfo: '⚠️ These plugins have DB version higher than Gallery. Click Fix to sync DB with file version.',
            thAction: 'Action',
            installing: 'Installing',
            updating: 'Updating',
            syncing: 'Syncing',
            reinstalling: 'Reinstalling',
            tabInfo: 'Info',
            infoTitle: 'User Guide',
            infoSubtitle: 'Learn about all features and functions of Bulk Plugin Manager',
            infoDashboardTitle: 'Dashboard Cards',
            infoDashOJS: 'OJS Version',
            infoDashOJSDesc: 'The OJS version currently running on your system.',
            infoDashGallery: 'Gallery Plugins',
            infoDashGalleryDesc: 'Total number of plugins compatible with your OJS version in PKP Plugin Gallery.',
            infoDashInstalled: 'Installed',
            infoDashInstalledDesc: 'Total number of plugins registered in your database (including active and inactive).',
            infoDashActive: 'Active',
            infoDashActiveDesc: 'Plugins that are currently enabled and running.',
            infoDashInactive: 'Inactive',
            infoDashInactiveDesc: 'Plugins that are installed but currently disabled.',
            infoDashAvailable: 'Available',
            infoDashAvailableDesc: 'Plugins in the Gallery that you haven\'t installed yet.',
            infoDashNewer: 'Newer Installed',
            infoDashNewerDesc: 'Plugins where your local version is newer than the Gallery version.',
            infoTabsTitle: 'Tab Descriptions',
            infoTabInstalled: 'Shows all plugins registered in your database. Displays DB version, File version, and status (active/inactive). You can filter by status or find sync issues.',
            infoTabDbFix: 'Lists plugins where DB version is higher than Gallery version. This usually happens after failed updates or manual DB edits. Click "Fix DB" to sync.',
            infoTabSync: 'Plugins where DB version differs from File version. This can prevent OJS plugin page from loading. Requires synchronization.',
            infoTabMissing: 'RECOVERABLE missing files: the database record exists, files are gone, but the plugin IS in the PKP Gallery — so it can be re-downloaded. Select rows and use "Process Selected" to bulk-reinstall (restores files + syncs the DB).',
            infoTabUpdate: 'Plugins that have newer versions available in the Gallery. Select and click "Process Selected" to update.',
            infoTabAvailable: 'New plugins from PKP Gallery that are compatible with your OJS version and not yet installed.',
            infoTabDowngrade: 'Your installed version is newer than Gallery version. Usually safe to ignore - you might have a beta/dev version.',
            infoTabNotInGallery: 'ORPHANED records: a database entry exists, the files are gone, AND the plugin is not in the PKP Gallery — so it cannot be reinstalled. Select rows and use "Process Selected" to bulk Clean DB (removes the stale versions + settings rows).',
            infoFiltersTitle: 'Installed Tab Filters',
            infoFilterAll: 'Shows all installed plugins without any filter.',
            infoFilterActive: 'Shows only plugins that are currently enabled.',
            infoFilterInactive: 'Shows only plugins that are currently disabled.',
            infoFilterSync: 'Shows plugins where DB version doesn\'t match File version. These need to be fixed.',
            infoFilterMissing: 'Shows plugins that have database records but no files on server. Need reinstall or cleanup.',
            infoButtonsTitle: 'Action Buttons',
            infoButtonFix: 'Updates the database version to match the file version. Use when DB and File versions are different. This fixes "current=0" issues and OJS plugin page crashes.',
            infoButtonClean: 'Deletes all database records for the plugin (versions + plugin_settings). Use for ORPHANED plugins (files gone, not in Gallery). This does not touch any files. Available in bulk on the "Not in Gallery" tab and on the Installed tab\'s "Missing Files" filter.',
            infoButtonInstall: 'Downloads the plugin from the PKP Gallery and installs it. Use for RECOVERABLE missing files or new plugins. Available in bulk on the "Missing" tab.',
            infoButtonUpdate: 'Downloads the latest version from Gallery and updates the plugin. Replaces existing files.',
            infoStatusTitle: 'Status Indicators',
            infoStatusActive: 'Plugin is enabled and running. It\'s performing its functions.',
            infoStatusInactive: 'Plugin is installed but disabled. It won\'t run until enabled.',
            infoStatusOK: 'Plugin is healthy. DB version matches File version, no issues detected.',
            infoStatusMissing: 'Plugin files are missing from server. Only database record exists.',
            infoColumnsTitle: 'Version Columns',
            infoColumnDB: 'Database Version - The version recorded in OJS versions table. This is what OJS thinks is installed.',
            infoColumnFile: 'File Version - The version from plugin\'s version.xml file. This is what\'s actually on the server.',
            infoColumnGallery: 'Gallery Version - The latest version available in PKP Plugin Gallery.',
            infoProblemsTitle: 'Common Problems & Solutions',
            infoCause: 'Cause',
            infoSolution: 'Solution',
            infoProblem1Title: 'OJS Plugin Page Not Loading',
            infoProblem1Cause: 'Database version doesn\'t match file version. OJS sets current=0 and page crashes.',
            infoProblem1Solution: 'Go to "Installed" tab → "Sync Issues" filter → Click "Fix DB" for each plugin.',
            infoProblem2Title: 'Deleted Plugin Still in List',
            infoProblem2Cause: 'Plugin files were deleted but database records remain in versions and plugin_settings tables.',
            infoProblem2Solution: 'Go to "Installed" tab → "Missing Files" filter → Click "Clean DB" to remove orphan records.',
            infoProblem3Title: 'Plugin Won\'t Update',
            infoProblem3Cause: 'DB version is higher than Gallery version (downgrade protection).',
            infoProblem3Solution: 'Go to "DB Fix Required" tab → Click "Fix DB" to reset version, then update normally.',
            infoTechTitle: 'Technical Notes',
            infoTech1: 'Version Comparison: Versions are normalized to 4 parts (e.g., 1.0.0 becomes 1.0.0.0) for accurate comparison.',
            infoTech2: 'Case Insensitive: Plugin names are compared case-insensitively (openAIRE = openaire).',
            infoTech3: 'Current Flag: OJS uses current=1 for active version. When DB≠File, OJS sets current=0 causing issues.',
            infoTech4: 'Gallery Source: Plugin data is fetched from pkp.sfu.ca/ojs/xml/plugins.xml - internet connection required.',
            noItems: 'No Issues Found',
            noItemsDesc_dbFix: 'All plugins have correct database versions. No fixes needed.',
            noItemsDesc_syncIssue: 'All plugins are synchronized. Database and file versions match.',
            noItemsDesc_missing: 'All installed plugins have their files intact. No missing files.',
            noItemsDesc_updatable: 'All plugins are up to date. No updates available.',
            noItemsDesc_available: 'All compatible plugins from the Gallery are already installed.',
            tabDesc_installedList: 'Overview of every plugin registered in your database (DB version, File version, active/inactive). Use the "Missing Files" filter to review all plugins whose files are gone — a bulk bar then lets you Reinstall the recoverable ones (in Gallery) or Clean DB the orphaned ones in one go.',
            tabDesc_dbFix: 'Lists plugins where DB version is higher than Gallery. Usually happens after failed updates or manual DB edits. Click "Fix DB" to sync.',
            tabDesc_syncIssue: 'Plugins where DB version differs from File version. This can prevent OJS plugin page from loading. Requires synchronization.',
            tabDesc_missing: 'RECOVERABLE missing files — the plugin IS in the PKP Gallery, so it can be re-downloaded. Tick the plugins you want back and click "Process Selected" to bulk-reinstall (restores files + syncs the DB).',
            tabDesc_updatable: 'Plugins with newer versions available in Gallery. Select and click "Process Selected" to update.',
            tabDesc_available: 'New plugins from PKP Gallery compatible with your OJS version and not yet installed.',
            tabDesc_downgrade: 'Your installed version is newer than Gallery version. Usually safe to ignore - you might have a beta/dev version.',
            tabDesc_notInGallery: 'ORPHANED records — a database entry exists but the files are gone and the plugin is not in the PKP Gallery, so it cannot be reinstalled. Tick them and click "Process Selected" to bulk Clean DB (removes the stale versions + settings rows).',
            noItemsDesc_downgrade: 'No plugins have newer versions than the Gallery. Everything is normal.',
            noItemsDesc_notInGallery: 'All installed plugins are available in the PKP Gallery.',
            tabOjsServices: 'OJS Services Plugins',
            ojsServicesTitle: 'OJS Services Plugins',
            ojsServicesDesc: 'Official plugins developed by OJS Services team. Install or update directly from GitHub.',
            ojsServicesLoading: 'Loading OJS Services plugins...',
            ojsAvailable: 'Available',
            ojsInstalled: 'Installed',
            ojsUpdate: 'Update Available',
            ojsIncompatible: 'Incompatible',
            ojsRepoVersion: 'Repo',
            ojsLocalVersion: 'Local',
            ojsInstallBtn: 'Install',
            ojsUpdateBtn: 'Update',
            ojsInstallingBtn: 'Installing...',
            ojsUpdatingBtn: 'Updating...',
            ojsInstalledBtn: 'Installed',
            ojsViewRepo: 'GitHub',
            ojsRefresh: 'Refresh',
            ojsNoPlugins: 'No OJS Services plugins found.',
            navSubmissions: 'Submissions',
            navIssues: 'Issues',
            navSettings: 'Settings',
            navJournal: 'Journal',
            navWebsite: 'Website',
            navWorkflow: 'Workflow',
            navDistribution: 'Distribution',
            navUsersRoles: 'Users & Roles',
            navStatistics: 'Statistics',
            navStatsArticles: 'Articles',
            navStatsEditorial: 'Editorial Activity',
            navStatsUsers: 'Users',
            navStatsReports: 'Reports',
            navTools: 'Tools',
            navAdministration: 'Administration',
            tabBackups: 'Backups',
            tabDesc_backups: 'Manage plugin backups created during updates. You can restore a previous version if an update fails.',
            btnRestore: '♻️ Restore',
            btnDelete: '🗑️ Delete',
            btnFixAll: '🔧 Fix All',
            confirmRestore: 'Are you sure you want to restore this backup? Current files will be replaced.',
            confirmDeleteBackup: 'Are you sure you want to delete this backup?',
            confirmFixAll: 'This will fix all database issues in this list one by one. Continue?',
            restoring: 'Restoring...',
            restored: 'Restored',
            deleting: 'Deleting...',
            deleted: 'Deleted',
            thDate: 'Date',
            thBackupId: 'Backup ID',
            noItemsDesc_backups: 'No backups found.',
            statusRestored: 'Restored'
        },
        tr: {
            title: 'OJS Toplu Eklenti Yöneticisi',
            backToOJS: 'OJS Paneline Geri Dön',
            refresh: 'Yenile',
            processSelected: 'Seçilenleri İşle',
            syncWarning: 'Versiyon uyumsuzlukları tespit edildi. Güncelleme öncesi düzeltilmeli.',
            fixSync: 'Uyumsuzlukları Düzelt',
            completedOps: 'Tamamlanan İşlemler',
            poweredBy: 'Geliştiren',
            version: 'Versiyon',
            processing: 'İşleniyor...',
            success: 'Başarılı',
            failed: 'Başarısız',
            error: 'Hata',
            errServer: 'Sunucu hatası. Lütfen sayfayı yenileyip tekrar deneyin.',
            selectAllMissing: 'Tüm eksikleri seç',
            selectAllActionable: 'Onarılabilir olanları seç',
            bulkFixDb: 'Seçilenleri DB Düzelt',
            bulkReinstall: 'Seçilenleri Yeniden Kur',
            bulkCleanDb: 'Seçilenleri DB’den Temizle',
            confirmBulkClean: 'eklentinin veritabanı kaydı KALICI olarak silinecek (ayarlar dahil). Dosyalara dokunulmaz. Devam edilsin mi?',
            bulkNoReinstallable: 'Seçilen eklentilerin hiçbiri PKP Gallery’de yok, bu yüzden yeniden kurulamaz. Yetim kayıtları kaldırmak için "DB Temizle" kullanın.',
            loading: 'Eklentiler yükleniyor...',
            selectAll: 'Tümünü seç',
            search: 'Eklenti ara...',
            allUpToDate: 'Tüm eklentiler güncel!',
            completed: 'Tamamlandı!',
            confirmProcess: 'eklenti işlenecek. Devam edilsin mi?',
            confirmFix: 'uyumsuzluk düzeltilecek. Devam edilsin mi?',
            dashOJS: 'OJS Versiyonu',
            dashGallery: 'Gallery Eklentileri',
            dashInstalled: 'Yüklü',
            dashActive: 'Aktif',
            dashInactive: 'Pasif',
            dashSync: 'Senkron Sorunu',
            dashDbFix: 'DB Düzeltme',
            dashMissing: 'Eksik Dosya',
            dashUpdate: 'Güncelleme',
            dashAvailable: 'Yüklenebilir',
            dashDowngrade: 'Yüklü Daha Yeni',
            tabInstalled: 'Kurulu',
            tabDbFix: 'DB Düzeltme',
            tabSync: 'Senkron Sorunu',
            tabMissing: 'Eksik Dosya',
            tabUpdate: 'Güncelleme',
            tabAvailable: 'Yüklenebilir',
            tabDowngrade: 'Daha Yeni',
            tabNotInGallery: 'Gallery\'de Yok',
            thPlugin: 'Eklenti',
            thCategory: 'Kategori',
            thDB: 'DB',
            thFile: 'Dosya',
            thGallery: 'Gallery',
            thVersion: 'Versiyon',
            thDesc: 'Açıklama',
            thStatus: 'Durum',
            statusSync: 'Senkron sorunu',
            statusMissing: 'Eksik',
            statusAvailable: 'Yüklenebilir',
            statusDowngrade: 'Yüklü daha yeni',
            statusNotInGallery: 'Gallery\'de yok',
            statusDone: 'Tamamlandı',
            statusActive: 'Aktif',
            statusInactive: 'Pasif',
            filterAll: 'Tümü',
            filterActive: 'Aktif',
            filterInactive: 'Pasif',
            filterSync: 'Senkron Sorunu',
            filterMissing: 'Eksik Dosya',
            btnFix: '🔧 DB Düzelt',
            btnInstall: '📦 Yükle',
            btnCleanDb: '🗑️ DB Temizle',
            fixing: 'Düzeltiliyor...',
            fixed: 'Düzeltildi',
            installed: 'Yüklendi',
            cleaning: 'Temizleniyor...',
            cleaned: 'Temizlendi',
            confirmCleanDb: 'Bu eklentiyi veritabanından silmek istediğinize emin misiniz? Tüm eklenti ayarları silinecek.',
            dbFixInfo: '⚠️ Bu eklentilerin DB versiyonu Gallery versiyonundan büyük. Düzelt\'e tıklayarak DB\'yi dosya versiyonuyla eşleştirin.',
            thAction: 'İşlem',
            installing: 'Yükleniyor',
            updating: 'Güncelleniyor',
            syncing: 'Senkronize ediliyor',
            reinstalling: 'Yeniden yükleniyor',
            tabInfo: 'Bilgi',
            infoTitle: 'Kullanım Kılavuzu',
            infoSubtitle: 'Bulk Plugin Manager\'ın tüm özelliklerini ve işlevlerini öğrenin',
            infoDashboardTitle: 'Dashboard Kartları',
            infoDashOJS: 'OJS Versiyonu',
            infoDashOJSDesc: 'Sisteminizde çalışan OJS sürümü.',
            infoDashGallery: 'Gallery Eklentileri',
            infoDashGalleryDesc: 'PKP Plugin Gallery\'de OJS versiyonunuzla uyumlu toplam eklenti sayısı.',
            infoDashInstalled: 'Kurulu',
            infoDashInstalledDesc: 'Veritabanınızda kayıtlı toplam eklenti sayısı (aktif ve pasif dahil).',
            infoDashActive: 'Aktif',
            infoDashActiveDesc: 'Şu anda etkin ve çalışan eklentiler.',
            infoDashInactive: 'Pasif',
            infoDashInactiveDesc: 'Kurulu ama devre dışı bırakılmış eklentiler.',
            infoDashAvailable: 'Yüklenebilir',
            infoDashAvailableDesc: 'Gallery\'de olup henüz kurmadığınız eklentiler.',
            infoDashNewer: 'Yüklü Daha Yeni',
            infoDashNewerDesc: 'Yerel versiyonunuz Gallery versiyonundan daha yeni olan eklentiler.',
            infoTabsTitle: 'Tab Açıklamaları',
            infoTabInstalled: 'Veritabanınızda kayıtlı tüm eklentileri gösterir. DB versiyonu, Dosya versiyonu ve durum (aktif/pasif) bilgilerini içerir. Duruma göre filtreleyebilir veya senkron sorunlarını bulabilirsiniz.',
            infoTabDbFix: 'DB versiyonu Gallery versiyonundan yüksek olan eklentileri listeler. Bu genellikle başarısız güncellemeler veya manuel DB değişikliklerinden sonra olur. "DB Düzelt" ile senkronize edin.',
            infoTabSync: 'DB versiyonu Dosya versiyonundan farklı olan eklentiler. Bu durum OJS eklenti sayfasının yüklenmesini engelleyebilir. Senkronizasyon gerektirir.',
            infoTabMissing: 'KURTARILABİLİR eksik dosyalar: veritabanı kaydı var, dosyalar silinmiş ama eklenti PKP Gallery\'de MEVCUT — yani yeniden indirilebilir. Satırları işaretleyip "Seçilenleri İşle" ile toplu yeniden kurun (dosyalar geri gelir + DB senkronlanır).',
            infoTabUpdate: 'Gallery\'de daha yeni versiyonları bulunan eklentiler. Seçip "Seçilenleri İşle" ile güncelleyin.',
            infoTabAvailable: 'PKP Gallery\'den OJS versiyonunuzla uyumlu ve henüz kurulmamış yeni eklentiler.',
            infoTabDowngrade: 'Kurulu versiyonunuz Gallery versiyonundan daha yeni. Genellikle güvenle göz ardı edilebilir - beta/geliştirme versiyonunuz olabilir.',
            infoTabNotInGallery: 'YETİM kayıtlar: veritabanı kaydı var ama dosyalar silinmiş VE eklenti PKP Gallery\'de yok — yani yeniden kurulamaz. Satırları işaretleyip "Seçilenleri İşle" ile toplu DB Temizle yapın (yetim versions + settings kayıtlarını siler).',
            infoFiltersTitle: 'Kurulu Tab Filtreleri',
            infoFilterAll: 'Tüm kurulu eklentileri filtresiz gösterir.',
            infoFilterActive: 'Sadece şu anda etkin olan eklentileri gösterir.',
            infoFilterInactive: 'Sadece şu anda devre dışı olan eklentileri gösterir.',
            infoFilterSync: 'DB versiyonu Dosya versiyonuyla eşleşmeyen eklentileri gösterir. Bunların düzeltilmesi gerekir.',
            infoFilterMissing: 'Veritabanı kaydı olan ama sunucuda dosyası olmayan eklentileri gösterir. Yeniden kurulum veya temizlik gerekir.',
            infoButtonsTitle: 'İşlem Butonları',
            infoButtonFix: 'Veritabanı versiyonunu dosya versiyonuyla eşitler. DB ve Dosya versiyonları farklı olduğunda kullanın. "current=0" sorunlarını ve OJS eklenti sayfası çökmelerini düzeltir.',
            infoButtonClean: 'Eklentinin tüm veritabanı kayıtlarını siler (versions + plugin_settings). YETİM eklentiler için kullanın (dosya yok, galeride yok). Dosyalara dokunmaz. "Gallery\'de Yok" sekmesinde ve Installed sekmesinin "Eksik Dosya" filtresinde toplu olarak yapılabilir.',
            infoButtonInstall: 'Eklentiyi PKP Gallery\'den indirir ve kurar. KURTARILABİLİR eksik dosyalar veya yeni eklentiler için kullanın. "Missing" sekmesinde toplu olarak yapılabilir.',
            infoButtonUpdate: 'Gallery\'den en son versiyonu indirir ve eklentiyi günceller. Mevcut dosyaların üzerine yazar.',
            infoStatusTitle: 'Durum Göstergeleri',
            infoStatusActive: 'Eklenti etkin ve çalışıyor. Fonksiyonlarını yerine getiriyor.',
            infoStatusInactive: 'Eklenti kurulu ama devre dışı. Etkinleştirilene kadar çalışmaz.',
            infoStatusOK: 'Eklenti sağlıklı. DB versiyonu Dosya versiyonuyla eşleşiyor, sorun tespit edilmedi.',
            infoStatusMissing: 'Eklenti dosyaları sunucuda yok. Sadece veritabanı kaydı mevcut.',
            infoColumnsTitle: 'Versiyon Sütunları',
            infoColumnDB: 'Veritabanı Versiyonu - OJS versions tablosunda kayıtlı versiyon. OJS\'nin kurulu olduğunu düşündüğü versiyon.',
            infoColumnFile: 'Dosya Versiyonu - Eklentinin version.xml dosyasındaki versiyon. Sunucuda gerçekte olan versiyon.',
            infoColumnGallery: 'Gallery Versiyonu - PKP Plugin Gallery\'deki en son versiyon.',
            infoProblemsTitle: 'Sık Karşılaşılan Sorunlar ve Çözümleri',
            infoCause: 'Sebep',
            infoSolution: 'Çözüm',
            infoProblem1Title: 'OJS Eklenti Sayfası Açılmıyor',
            infoProblem1Cause: 'Veritabanı versiyonu dosya versiyonuyla eşleşmiyor. OJS current=0 yapıyor ve sayfa çöküyor.',
            infoProblem1Solution: '"Kurulu" tab\'ına git → "Senkron Sorunu" filtresi → Her eklenti için "DB Düzelt" tıkla.',
            infoProblem2Title: 'Silinen Eklenti Hala Listede',
            infoProblem2Cause: 'Eklenti dosyaları silindi ama versions ve plugin_settings tablolarında kayıtlar duruyor.',
            infoProblem2Solution: '"Kurulu" tab\'ına git → "Eksik Dosya" filtresi → Sahipsiz kayıtları silmek için "DB Temizle" tıkla.',
            infoProblem3Title: 'Eklenti Güncellenmiyor',
            infoProblem3Cause: 'DB versiyonu Gallery versiyonundan yüksek (downgrade koruması).',
            infoProblem3Solution: '"DB Düzeltme Gerekli" tab\'ına git → Versiyonu sıfırlamak için "DB Düzelt" tıkla, sonra normal güncelle.',
            infoTechTitle: 'Teknik Notlar',
            infoTech1: 'Versiyon Karşılaştırma: Versiyonlar doğru karşılaştırma için 4 parçaya normalize edilir (örn: 1.0.0 → 1.0.0.0).',
            infoTech2: 'Büyük/Küçük Harf Duyarsız: Eklenti adları büyük/küçük harf duyarsız karşılaştırılır (openAIRE = openaire).',
            infoTech3: 'Current Flag: OJS aktif versiyon için current=1 kullanır. DB≠Dosya olduğunda OJS current=0 yapar ve sorunlara yol açar.',
            infoTech4: 'Gallery Kaynağı: Eklenti verileri pkp.sfu.ca/ojs/xml/plugins.xml adresinden çekilir - internet bağlantısı gereklidir.',
            noItems: 'Sorun Bulunamadı',
            noItemsDesc_dbFix: 'Tüm eklentilerin veritabanı versiyonları doğru. Düzeltme gerekmiyor.',
            noItemsDesc_syncIssue: 'Tüm eklentiler senkronize. Veritabanı ve dosya versiyonları eşleşiyor.',
            noItemsDesc_missing: 'Tüm kurulu eklentilerin dosyaları mevcut. Eksik dosya yok.',
            noItemsDesc_updatable: 'Tüm eklentiler güncel. Güncelleme bekleyen eklenti yok.',
            noItemsDesc_available: 'Gallery\'deki tüm uyumlu eklentiler zaten kurulu.',
            noItemsDesc_downgrade: 'Hiçbir eklentinin versiyonu Gallery\'den yüksek değil. Her şey normal.',
            noItemsDesc_notInGallery: 'Tüm kurulu eklentiler PKP Gallery\'de mevcut.',
            tabDesc_installedList: 'Veritabanınızdaki tüm eklentilerin genel görünümü (DB versiyonu, Dosya versiyonu, aktif/pasif). "Eksik Dosya" filtresiyle dosyası silinmiş tüm eklentileri görün — çıkan toplu çubukla kurtarılabilir olanları (galeride) Yeniden Kur, yetimleri tek seferde DB Temizle yapabilirsiniz.',
            tabDesc_dbFix: 'DB versiyonu Gallery versiyonundan yüksek olan eklentileri listeler. Bu genellikle başarısız güncellemeler veya manuel DB değişikliklerinden sonra olur. "DB Düzelt" ile senkronize edin.',
            tabDesc_syncIssue: 'DB versiyonu Dosya versiyonundan farklı olan eklentiler. Bu durum OJS eklenti sayfasının yüklenmesini engelleyebilir. Senkronizasyon gerektirir.',
            tabDesc_missing: 'KURTARILABİLİR eksik dosyalar — eklenti PKP Gallery\'de mevcut, yani yeniden indirilebilir. Geri istediklerini işaretleyip "Seçilenleri İşle" ile toplu yeniden kur (dosyalar geri gelir + DB senkronlanır).',
            tabDesc_updatable: 'Gallery\'de daha yeni versiyonları bulunan eklentiler. Seçip "Seçilenleri İşle" ile güncelleyin.',
            tabDesc_available: 'PKP Gallery\'den OJS versiyonunuzla uyumlu ve henüz kurulmamış yeni eklentiler.',
            tabDesc_downgrade: 'Kurulu versiyonunuz Gallery versiyonundan daha yeni. Genellikle güvenle göz ardı edilebilir - beta/geliştirme versiyonunuz olabilir.',
            tabDesc_notInGallery: 'YETİM kayıtlar — veritabanı kaydı var ama dosyalar silinmiş ve eklenti PKP Gallery\'de yok, yani yeniden kurulamaz. İşaretleyip "Seçilenleri İşle" ile toplu DB Temizle yap (yetim versions + settings kayıtlarını siler).',
            
            // New Translations TR
            tabBackups: 'Yedekler',
            tabDesc_backups: 'Güncellemeler sırasında alınan yedekleri yönetin. Güncelleme başarısız olursa eski versiyona dönebilirsiniz.',
            btnRestore: '♻️ Geri Yükle',
            btnDelete: '🗑️ Sil',
            btnFixAll: '🔧 Tümünü Onar',
            confirmRestore: 'Bu yedeği geri yüklemek istediğinize emin misiniz? Mevcut dosyalar değiştirilecek.',
            confirmDeleteBackup: 'Bu yedeği silmek istediğinize emin misiniz?',
            confirmFixAll: 'Bu listedeki tüm DB sorunları sırayla düzeltilecek. Devam edilsin mi?',
            restoring: 'Yükleniyor...',
            restored: 'Yüklendi',
            deleting: 'Siliniyor...',
            deleted: 'Silindi',
            thDate: 'Tarih',
            thBackupId: 'Yedek ID',
            noItemsDesc_backups: 'Yedek bulunamadı.',
            statusRestored: 'Geri Yüklendi',
            tabOjsServices: 'OJS Services Eklentileri',
            ojsServicesTitle: 'OJS Services Eklentileri',
            ojsServicesDesc: 'OJS Services ekibi tarafından geliştirilen resmi eklentiler. GitHub\'dan doğrudan yükleyin veya güncelleyin.',
            ojsServicesLoading: 'OJS Services eklentileri yükleniyor...',
            ojsAvailable: 'Yüklenebilir',
            ojsInstalled: 'Kurulu',
            ojsUpdate: 'Güncelleme Var',
            ojsIncompatible: 'Uyumsuz',
            ojsRepoVersion: 'Repo',
            ojsLocalVersion: 'Yerel',
            ojsInstallBtn: 'Yükle',
            ojsUpdateBtn: 'Güncelle',
            ojsInstallingBtn: 'Yükleniyor...',
            ojsUpdatingBtn: 'Güncelleniyor...',
            ojsInstalledBtn: 'Kuruldu',
            ojsViewRepo: 'GitHub',
            ojsRefresh: 'Yenile',
            ojsNoPlugins: 'OJS Services eklentisi bulunamadı.',
            navSubmissions: 'Gönderiler',
            navIssues: 'Sayılar',
            navSettings: 'Ayarlar',
            navJournal: 'Dergi',
            navWebsite: 'Web Sitesi',
            navWorkflow: 'İş Akışı',
            navDistribution: 'Dağıtım',
            navUsersRoles: 'Kullanıcılar ve Roller',
            navStatistics: 'İstatistikler',
            navStatsArticles: 'Makaleler',
            navStatsEditorial: 'Editöryal Faaliyet',
            navStatsUsers: 'Kullanıcılar',
            navStatsReports: 'Raporlar',
            navTools: 'Araçlar',
            navAdministration: 'Yönetim'
        }
    };
    
    var currentLang = 'en';
    var apiUrl = '{url page="bulkPluginManager" op="getUpdatablePlugins"}';
    var updateUrl = '{url page="bulkPluginManager" op="updatePlugin"}';
    var csrfToken = '{$csrfToken|escape:"javascript"}';
    var data = {};
    var processing = false;
    var processedProducts = {};
    var activeTab = '';
    var ojsVersion = '';
    var galleryCount = 0;
    var installed = { total: 0, active: 0, inactive: 0 };
    
    function t(key) { return i18n[currentLang][key] || key; }

    // Append the CSRF token to a POST body string. All state-changing requests
    // (updatePlugin / installOjsServicesPlugin) require it server-side.
    function withCsrf(body) {
        return (body ? body + '&' : '') + 'csrfToken=' + encodeURIComponent(csrfToken);
    }

    function escapeHtml(text) {
        if (text === null || text === undefined) return '';
        return String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }
    
    function setLang(lang) {
        currentLang = lang;
        document.querySelectorAll('.lang-btn').forEach(function(btn) {
            btn.classList.toggle('active', btn.textContent.toLowerCase() === lang);
        });
        applyTranslations();
        renderDashboard();
        renderTabs();
        // Activate first tab after language change
        activateFirstTab();
    }
    
    function applyTranslations() {
        document.querySelectorAll('[data-i18n]').forEach(function(el) {
            var key = el.getAttribute('data-i18n');
            if (i18n[currentLang][key]) el.textContent = i18n[currentLang][key];
        });
    }
    
    function activateFirstTab() {
        var tabs = ['installedList', 'dbFix', 'syncIssue', 'missing', 'updatable', 'available', 'downgrade', 'notInGallery'];
        for (var i = 0; i < tabs.length; i++) {
            if (data[tabs[i]] && data[tabs[i]].length > 0) {
                setActiveTab(tabs[i]);
                return;
            }
        }
    }
    
    document.addEventListener('DOMContentLoaded', function() {
        applyTranslations();
        loadPlugins();
    });
    
    function loadPlugins(refresh) {
        document.getElementById('tabsContent').innerHTML = '<div class="loading-state"><div class="spinner"></div><p>' + t('loading') + '</p></div>';
        document.getElementById('tabsHeader').innerHTML = '';
        
        var url = apiUrl;
        if (refresh) {
            url += (url.indexOf('?') > -1 ? '&' : '?') + 'refresh=1';
        }
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'error') {
                        document.getElementById('tabsContent').innerHTML = '<div class="empty-state"><p style="color:red;">' + t('error') + ': ' + escapeHtml(result.message) + '</p></div>';
                        return;
                    }
                    
                    data = {
                        syncIssue: result.syncIssue || [],
                        missing: result.missing || [],
                        updatable: result.updatable || [],
                        available: result.available || [],
                        downgrade: result.downgrade || [],
                        notInGallery: result.notInGallery || [],
                        dbFix: result.dbFix || [],
                        installedList: result.installed || [],
                        backups: result.backups || [],
                        ojsServices: []
                    };
                    
                    if (result.debug) {
                        ojsVersion = result.debug.ojsVersion || '-';
                        galleryCount = result.debug.galleryCount || 0;
                        document.getElementById('ojsVersion').textContent = ojsVersion;
                        if (result.debug.installed) {
                            installed = result.debug.installed;
                        }
                    }
                    
                    document.getElementById('syncAlert').style.display = data.syncIssue.length > 0 ? 'flex' : 'none';
                    
                    renderDashboard();
                    renderTabs();
                    activateFirstTab();
                } catch(e) {
                    document.getElementById('tabsContent').innerHTML = '<div class="empty-state"><p style="color:red;">' + t('errServer') + '</p></div>';
                }
            } else if (xhr.readyState === 4) {
                document.getElementById('tabsContent').innerHTML = '<div class="empty-state"><p style="color:red;">' + t('errServer') + ' (' + xhr.status + ')</p></div>';
            }
        };
        xhr.send();
    }

    function renderDashboard() {
        var h = '';
        h += '<div class="dash-card info"><div class="icon">🖥️</div><div class="value">' + escapeHtml(ojsVersion) + '</div><div class="label">' + t('dashOJS') + '</div></div>';
        h += '<div class="dash-card info"><div class="icon">📚</div><div class="value">' + escapeHtml(galleryCount) + '</div><div class="label">' + t('dashGallery') + '</div></div>';
        h += '<div class="dash-card installed"><div class="icon">🔌</div><div class="value">' + escapeHtml(installed.total) + '</div><div class="label">' + t('dashInstalled') + '</div></div>';
        h += '<div class="dash-card active"><div class="icon">✅</div><div class="value">' + escapeHtml(installed.active) + '</div><div class="label">' + t('dashActive') + '</div></div>';
        h += '<div class="dash-card inactive"><div class="icon">⏸️</div><div class="value">' + escapeHtml(installed.inactive) + '</div><div class="label">' + t('dashInactive') + '</div></div>';
        
        if (data.syncIssue && data.syncIssue.length > 0) {
            h += '<div class="dash-card sync"><div class="icon">🔄</div><div class="value">' + data.syncIssue.length + '</div><div class="label">' + t('dashSync') + '</div></div>';
        }
        if (data.dbFix && data.dbFix.length > 0) {
            h += '<div class="dash-card dbfix"><div class="icon">🔧</div><div class="value">' + data.dbFix.length + '</div><div class="label">' + t('dashDbFix') + '</div></div>';
        }
        if (data.missing && data.missing.length > 0) {
            h += '<div class="dash-card missing"><div class="icon">📁</div><div class="value">' + data.missing.length + '</div><div class="label">' + t('dashMissing') + '</div></div>';
        }
        if (data.updatable && data.updatable.length > 0) {
            h += '<div class="dash-card update"><div class="icon">🔄</div><div class="value">' + data.updatable.length + '</div><div class="label">' + t('dashUpdate') + '</div></div>';
        }
        if (data.available && data.available.length > 0) {
            h += '<div class="dash-card available"><div class="icon">📦</div><div class="value">' + data.available.length + '</div><div class="label">' + t('dashAvailable') + '</div></div>';
        }
        if (data.downgrade && data.downgrade.length > 0) {
            h += '<div class="dash-card downgrade"><div class="icon">⚠️</div><div class="value">' + data.downgrade.length + '</div><div class="label">' + t('dashDowngrade') + '</div></div>';
        }
        
        document.getElementById('dashboard').innerHTML = h;
    }
    
    function renderTabs() {
        // Two-row tab design: Main row (top) + Secondary row (bottom)
        var allTabs = [
            { key: 'installedList', icon: '🔌', label: 'tabInstalled', selectable: false, special: 'installed', group: 'main' },
            { key: 'updatable', icon: '⬆️', label: 'tabUpdate', selectable: true, group: 'main' },
            { key: 'available', icon: '📦', label: 'tabAvailable', selectable: true, group: 'main' },
            { key: 'ojsServices', icon: '🚀', label: 'tabOjsServices', selectable: false, special: 'ojsServices', group: 'main' },
            { key: 'dbFix', icon: '🔧', label: 'tabDbFix', selectable: false, special: 'dbfix', group: 'issues' },
            { key: 'syncIssue', icon: '🔄', label: 'tabSync', selectable: false, group: 'issues' },
            { key: 'missing', icon: '📁', label: 'tabMissing', selectable: true, group: 'issues' },
            { key: 'downgrade', icon: '⚠️', label: 'tabDowngrade', selectable: false, group: 'other' },
            { key: 'notInGallery', icon: '❓', label: 'tabNotInGallery', selectable: true, group: 'other' },
            { key: 'backups', icon: '💾', label: 'tabBackups', selectable: false, special: 'backups', group: 'other' }
        ];

        var mainRowHtml = '';
        var secondaryRowHtml = '';
        var contentHtml = '';
        var hasSecondary = false;

        allTabs.forEach(function(tab) {
            var count = data[tab.key] ? data[tab.key].length : 0;

            // Hide issue tabs when count is 0
            if (tab.group === 'issues' && count === 0) {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '"></div>';
                return;
            }

            var badgeClass = count === 0 ? 'badge-zero' : '';
            if (tab.group === 'issues' && count > 0) badgeClass = 'badge-alert';

            // OJS Services: hide badge until data is loaded
            var badgeContent = (tab.key === 'ojsServices') ? '' : count;
            var tabExtraClass = tab.key === 'ojsServices' ? ' tab-ojs-services' : '';
            var btnHtml = '<button class="tab-btn' + tabExtraClass + '" data-tab="' + tab.key + '" onclick="setActiveTab(\'' + tab.key + '\')">' +
                tab.icon + ' ' + t(tab.label) + ' <span class="badge ' + badgeClass + '">' + badgeContent + '</span></button>';

            if (tab.group === 'main') {
                mainRowHtml += btnHtml;
            } else {
                secondaryRowHtml += btnHtml;
                hasSecondary = true;
            }

            // Render tab content
            if (tab.special === 'installed') {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '">' + renderInstalledTabContent() + '</div>';
            } else if (tab.special === 'dbfix') {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '">' + renderDbFixTabContent() + '</div>';
            } else if (tab.special === 'backups') {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '">' + renderBackupsTabContent() + '</div>';
            } else if (tab.special === 'ojsServices') {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '">' + renderOjsServicesTabContent() + '</div>';
            } else {
                contentHtml += '<div class="tab-content" id="tab-' + tab.key + '">' + renderTabContent(tab.key, tab.selectable) + '</div>';
            }
        });

        // Build two-row header
        var headerHtml = '<div class="tab-row tab-row-main">' + mainRowHtml + '</div>';
        if (hasSecondary) {
            headerHtml += '<div class="tab-row tab-row-secondary">' + secondaryRowHtml + '</div>';
        }

        // Info tab - only content (button in header)
        contentHtml += '<div class="tab-content" id="tab-info">' + renderInfoTabContent() + '</div>';

        document.getElementById('tabsHeader').innerHTML = headerHtml;
        document.getElementById('tabsContent').innerHTML = contentHtml;
    }
    
    function renderDbFixTabContent() {
        var items = data.dbFix || [];
        
        // Boş durum kontrolü
        if (items.length === 0) {
            return '<div class="tab-description">🔧 ' + t('tabDesc_dbFix') + '</div><div class="empty-state"><div class="icon">✅</div><h3>' + t('noItems') + '</h3><p>' + t('noItemsDesc_dbFix') + '</p></div>';
        }
        
        var h = '<div class="tab-description">🔧 ' + t('tabDesc_dbFix') + '</div>';
        
        h += '<div class="table-controls">';
        h += '<input type="text" class="search-input" id="search-dbFix" placeholder="🔍 ' + t('search') + '" onkeyup="filterTable(\'dbFix\')">';
        
        // Fix All Button
        if (items.length > 0) {
            h += '<button class="btn btn-warning" onclick="fixAll(\'dbFix\')">🔧 ' + t('btnFixAll') + '</button>';
        }
        h += '</div>';
        
        h += '<div class="table-wrapper"><table><thead><tr>';
        h += '<th class="col-plugin">' + t('thPlugin') + '</th>';
        h += '<th class="col-cat">' + t('thCategory') + '</th>';
        h += '<th class="col-ver">' + t('thDB') + '</th>';
        h += '<th class="col-ver">' + t('thFile') + '</th>';
        h += '<th class="col-ver">' + t('thGallery') + '</th>';
        h += '<th class="col-action">' + t('thAction') + '</th>';
        h += '</tr></thead><tbody>';
        
        items.forEach(function(p) {
            h += '<tr id="dbfix-row-' + escapeHtml(p.product) + '" data-search="' + escapeHtml((p.displayName + ' ' + p.product).toLowerCase()) + '">';
            h += '<td class="col-plugin"><span class="plugin-name">' + escapeHtml(p.displayName) + '</span><span class="plugin-id">' + escapeHtml(p.product) + '</span></td>';
            h += '<td class="col-cat"><span class="badge badge-gray">' + escapeHtml(p.category) + '</span></td>';
            h += '<td class="col-ver"><span class="badge badge-red">' + escapeHtml(p.dbVersion) + '</span></td>';
            h += '<td class="col-ver"><span class="badge badge-blue">' + escapeHtml(p.fileVersion) + '</span></td>';
            h += '<td class="col-ver"><span class="badge badge-green">' + escapeHtml(p.galleryVersion) + '</span></td>';
            h += '<td class="col-action"><button class="btn btn-fix" onclick="fixDbVersion(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.category) + '\', \'' + escapeHtml(p.fileVersion) + '\')">' + t('btnFix') + '</button></td>';
            h += '</tr>';
        });
        
        h += '</tbody></table></div>';
        return h;
    }
    
    function renderBackupsTabContent() {
        var items = data.backups || [];

        if (items.length === 0) {
            return '<div class="tab-description">💾 ' + t('tabDesc_backups') + '</div><div class="empty-state"><div class="icon">💾</div><h3>' + t('noItems') + '</h3><p>' + t('noItemsDesc_backups') + '</p></div>';
        }

        var h = '<div class="tab-description">💾 ' + t('tabDesc_backups') + '</div>';

        h += '<div class="table-controls">';
        h += '<input type="text" class="search-input" id="search-backups" placeholder="🔍 ' + t('search') + '" onkeyup="filterTable(\'backups\')">';
        h += '</div>';

        h += '<div class="table-wrapper"><table><thead><tr>';
        h += '<th class="col-plugin">' + t('thPlugin') + '</th>';
        h += '<th class="col-cat">' + t('thCategory') + '</th>';
        h += '<th class="col-ver">' + t('thDate') + '</th>';
        h += '<th class="col-ver">' + t('thVersion') + '</th>';
        h += '<th class="col-action" style="min-width:160px">' + t('thAction') + '</th>';
        h += '</tr></thead><tbody>';

        items.forEach(function(b, idx) {
            h += '<tr id="backup-row-' + idx + '" data-search="' + escapeHtml((b.product + ' ' + b.date).toLowerCase()) + '">';
            h += '<td class="col-plugin"><span class="plugin-name">' + escapeHtml(b.product) + '</span></td>';
            h += '<td class="col-cat"><span class="badge badge-gray">' + escapeHtml(b.category) + '</span></td>';
            h += '<td class="col-ver">' + escapeHtml(b.date) + '</td>';
            h += '<td class="col-ver"><span class="badge badge-purple">' + escapeHtml(b.version) + '</span></td>';
            h += '<td class="col-action">';
            h += '<button class="btn btn-info" style="margin-right:5px" onclick="restoreBackup(\'' + escapeHtml(b.id) + '\', \'' + escapeHtml(b.product) + '\', \'' + escapeHtml(b.category) + '\')">' + t('btnRestore') + '</button>';
            h += '<button class="btn btn-danger-sm" onclick="deleteBackup(\'' + escapeHtml(b.id) + '\', \'' + escapeHtml(b.product) + '\', \'' + escapeHtml(b.category) + '\')">' + t('btnDelete') + '</button>';
            h += '</td>';
            h += '</tr>';
        });

        h += '</tbody></table></div>';
        return h;
    }

    function fixDbVersion(product, category, fileVersion) {
        var btn = event.target;
        var row = document.getElementById('dbfix-row-' + product);
        btn.disabled = true;
        btn.innerHTML = '⏳ ' + t('fixing');
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '{url page="bulkPluginManager" op="updatePlugin"}', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('fixed');
                        btn.classList.add('btn-success');
                        if (row) row.style.background = '#d4edda';
                        // Reload after 1 second
                        setTimeout(function() { loadPlugins(); }, 1000);
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.classList.add('btn-danger');
                        btn.disabled = false;
                        alert(result.message || 'Fix failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                    alert(t('errServer'));
                }
            } else {
                btn.innerHTML = '❌ ' + t('error');
                btn.disabled = false;
                alert(t('errServer') + ' (' + xhr.status + ')');
            }
        };
        xhr.send(withCsrf('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=dbfix'));
    }

    function renderInstalledTabContent() {
        var items = data.installedList || [];
        
        var h = '<div class="tab-description">🔌 ' + t('tabDesc_installedList') + '</div>';
        
        h += '<div class="table-controls">';
        h += '<input type="text" class="search-input" id="search-installedList" placeholder="🔍 ' + t('search') + '" onkeyup="filterTable(\'installedList\')">';
        h += '<div class="filter-btns">';
        h += '<button class="filter-btn active" onclick="filterInstalled(\'all\', this)">' + t('filterAll') + '</button>';
        h += '<button class="filter-btn" onclick="filterInstalled(\'active\', this)">' + t('filterActive') + '</button>';
        h += '<button class="filter-btn" onclick="filterInstalled(\'inactive\', this)">' + t('filterInactive') + '</button>';
        h += '<button class="filter-btn" onclick="filterInstalled(\'sync\', this)">' + t('filterSync') + '</button>';
        h += '<button class="filter-btn" onclick="filterInstalled(\'missing\', this)">' + t('filterMissing') + '</button>';
        h += '</div>';
        h += '</div>';

        // Bulk action bar for actionable rows: sync issues (Fix DB), recoverable
        // missing (Reinstall), and orphaned missing (Clean DB).
        var missingItems = items.filter(function(p) { return !p.filesExist; });
        var syncItems = items.filter(function(p) { return p.filesExist && p.syncIssue; });
        if (missingItems.length > 0 || syncItems.length > 0) {
            h += '<div class="bulk-bar" id="installedBulk">';
            h += '<label class="select-all"><input type="checkbox" id="imSelectAll" onchange="toggleInstalledBulk(this)"> ' + t('selectAllActionable') + '</label>';
            h += '<span class="bulk-count" id="imCount">0</span>';
            if (syncItems.length > 0) {
                h += '<button class="btn btn-fix" id="imFixBtn" disabled onclick="bulkInstalledAction(\'dbfix\')">🔧 ' + t('bulkFixDb') + '</button>';
            }
            if (missingItems.length > 0) {
                h += '<button class="btn btn-install" id="imReinstallBtn" disabled onclick="bulkInstalledAction(\'reinstall\')">🔄 ' + t('bulkReinstall') + '</button>';
                h += '<button class="btn btn-danger-sm" id="imCleanBtn" disabled onclick="bulkInstalledAction(\'clean\')">🗑️ ' + t('bulkCleanDb') + '</button>';
            }
            h += '</div>';
        }

        h += '<div class="table-wrapper"><table><thead><tr>';
        h += '<th class="col-check"></th>';
        h += '<th class="col-plugin">' + t('thPlugin') + '</th>';
        h += '<th class="col-cat">' + t('thCategory') + '</th>';
        h += '<th class="col-ver">' + t('thDB') + '</th>';
        h += '<th class="col-ver">' + t('thFile') + '</th>';
        h += '<th class="col-status">' + t('thStatus') + '</th>';
        h += '<th class="col-action">' + t('thAction') + '</th>';
        h += '</tr></thead><tbody>';
        
        items.forEach(function(p) {
            var statusClass = p.enabled ? 'green' : 'gray';
            var statusText = p.enabled ? t('statusActive') : t('statusInactive');
            var statusIcon = p.enabled ? '✅' : '⏸️';
            
            var dbBadgeClass = 'badge-blue';
            var fileBadgeClass = 'badge-blue';
            var hasSyncIssue = p.syncIssue || false;
            var rowClass = '';
            
            if (hasSyncIssue) {
                dbBadgeClass = 'badge-red';
                fileBadgeClass = 'badge-green';
                rowClass = 'sync-issue-row';
            }
            
            if (!p.filesExist) {
                fileBadgeClass = 'badge-orange';
                rowClass = 'missing-file-row';
            }

            h += '<tr id="installed-row-' + escapeHtml(p.product) + '" class="' + rowClass + '" data-search="' + escapeHtml((p.displayName + ' ' + p.product).toLowerCase()) + '" data-status="' + (p.enabled ? 'active' : 'inactive') + '" data-sync="' + (hasSyncIssue ? 'yes' : 'no') + '" data-missing="' + (!p.filesExist ? 'yes' : 'no') + '">';
            if (!p.filesExist) {
                h += '<td class="col-check"><input type="checkbox" class="imcheck" data-kind="missing" data-product="' + escapeHtml(p.product) + '" data-category="' + escapeHtml(p.category) + '" data-ingallery="' + (p.inGallery ? 'yes' : 'no') + '" onchange="checkInstalledBulk()"></td>';
            } else if (hasSyncIssue) {
                h += '<td class="col-check"><input type="checkbox" class="imcheck" data-kind="sync" data-product="' + escapeHtml(p.product) + '" data-category="' + escapeHtml(p.category) + '" onchange="checkInstalledBulk()"></td>';
            } else {
                h += '<td class="col-check"></td>';
            }
            h += '<td class="col-plugin"><span class="plugin-name">' + escapeHtml(p.displayName) + '</span><span class="plugin-id">' + escapeHtml(p.product) + '</span></td>';
            h += '<td class="col-cat"><span class="badge badge-gray">' + escapeHtml(p.category) + '</span></td>';
            h += '<td class="col-ver"><span class="badge ' + dbBadgeClass + '">' + escapeHtml(p.dbVersion) + '</span></td>';
            h += '<td class="col-ver"><span class="badge ' + fileBadgeClass + '">' + escapeHtml(p.fileVersion) + '</span></td>';
            h += '<td class="col-status"><span class="status-text ' + statusClass + '">' + statusIcon + ' ' + statusText + '</span></td>';
            
            // Fix button for sync issues
            if (hasSyncIssue && p.filesExist) {
                h += '<td class="col-action"><button class="btn btn-fix" onclick="fixInstalledDbVersion(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.category) + '\', \'' + escapeHtml(p.fileVersion) + '\')">' + t('btnFix') + '</button></td>';
            } else if (!p.filesExist) {
                // Missing files - show Install or Clean DB button
                if (p.inGallery) {
                    h += '<td class="col-action"><button class="btn btn-install" onclick="installMissingPlugin(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.category) + '\')">' + t('btnInstall') + '</button></td>';
                } else {
                    h += '<td class="col-action"><button class="btn btn-danger-sm" onclick="cleanDbEntry(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.category) + '\')">' + t('btnCleanDb') + '</button></td>';
                }
            } else {
                h += '<td class="col-action"><span class="status-text green">✓ OK</span></td>';
            }
            
            h += '</tr>';
        });
        
        h += '</tbody></table></div>';
        return h;
    }
    
    function filterInstalled(filter, btn) {
        // Update button states
        document.querySelectorAll('#tab-installedList .filter-btn').forEach(function(b) { b.classList.remove('active'); });
        btn.classList.add('active');
        
        // Filter rows
        document.querySelectorAll('#tab-installedList tbody tr').forEach(function(row) {
            if (filter === 'all') {
                row.style.display = '';
            } else if (filter === 'sync') {
                row.style.display = row.getAttribute('data-sync') === 'yes' ? '' : 'none';
            } else if (filter === 'missing') {
                row.style.display = row.getAttribute('data-missing') === 'yes' ? '' : 'none';
            } else {
                row.style.display = row.getAttribute('data-status') === filter ? '' : 'none';
            }
        });
    }

    // --- Bulk actions for actionable rows in the Installed tab ---
    // kinds: 'sync' (Fix DB), 'missing' (Reinstall if in gallery / Clean DB otherwise)
    function checkInstalledBulk() {
        var checked = document.querySelectorAll('#tab-installedList .imcheck:checked');
        var countEl = document.getElementById('imCount');
        if (countEl) countEl.textContent = checked.length;
        var nSync = 0, nReinstall = 0, nMissing = 0;
        checked.forEach(function(cb) {
            var kind = cb.getAttribute('data-kind');
            if (kind === 'sync') {
                nSync++;
            } else if (kind === 'missing') {
                nMissing++;
                if (cb.getAttribute('data-ingallery') === 'yes') nReinstall++;
            }
        });
        var fixBtn = document.getElementById('imFixBtn');
        var reBtn = document.getElementById('imReinstallBtn');
        var clBtn = document.getElementById('imCleanBtn');
        if (fixBtn) fixBtn.disabled = nSync === 0 || processing;
        if (reBtn) reBtn.disabled = nReinstall === 0 || processing;
        if (clBtn) clBtn.disabled = nMissing === 0 || processing;
    }

    function toggleInstalledBulk(cb) {
        document.querySelectorAll('#tab-installedList .imcheck').forEach(function(box) {
            var row = box.closest('tr');
            if (row && row.style.display !== 'none') box.checked = cb.checked;
        });
        checkInstalledBulk();
    }

    function bulkInstalledAction(mode) {
        var checked = Array.prototype.slice.call(document.querySelectorAll('#tab-installedList .imcheck:checked'));
        if (checked.length === 0) return;
        var list = [];
        checked.forEach(function(cb) {
            var kind = cb.getAttribute('data-kind');
            var inGallery = cb.getAttribute('data-ingallery') === 'yes';
            var action = null;
            if (mode === 'dbfix' && kind === 'sync') action = 'dbfix';
            else if (mode === 'reinstall' && kind === 'missing' && inGallery) action = 'missing';
            else if (mode === 'clean' && kind === 'missing') action = 'cleandb';
            if (!action) return;
            list.push({
                product: cb.getAttribute('data-product'),
                category: cb.getAttribute('data-category'),
                displayName: cb.getAttribute('data-product'),
                _action: action
            });
        });
        if (list.length === 0) {
            if (mode === 'reinstall') alert(t('bulkNoReinstallable'));
            return;
        }
        if (mode === 'clean') {
            if (!confirm(list.length + ' ' + t('confirmBulkClean'))) return;
        } else {
            if (!confirm(list.length + ' ' + t('confirmProcess'))) return;
        }
        currentAction = 'bulk_' + mode;
        startProcess(list);
    }

    function fixInstalledDbVersion(product, category, fileVersion) {
        var btn = event.target;
        var row = document.getElementById('installed-row-' + product);
        btn.disabled = true;
        btn.innerHTML = '⏳ ' + t('fixing');
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '{url page="bulkPluginManager" op="updatePlugin"}', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('fixed');
                        btn.classList.remove('btn-fix');
                        btn.classList.add('btn-success');
                        if (row) {
                            row.classList.remove('sync-issue-row');
                            row.style.background = '#d4edda';
                            // Update DB version cell to show file version
                            var cells = row.querySelectorAll('td');
                            if (cells[2]) {
                                cells[2].innerHTML = '<span class="badge badge-blue">' + escapeHtml(fileVersion) + '</span>';
                            }
                        }
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.classList.add('btn-danger');
                        btn.disabled = false;
                        alert(result.message || 'Fix failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                    alert(t('errServer'));
                }
            } else {
                btn.innerHTML = '❌ ' + t('error');
                btn.disabled = false;
                alert(t('errServer') + ' (' + xhr.status + ')');
            }
        };
        xhr.send(withCsrf('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=dbfix'));
    }

    function installMissingPlugin(product, category) {
        var btn = event.target;
        var row = document.getElementById('installed-row-' + product);
        btn.disabled = true;
        btn.innerHTML = '⏳ ' + t('installing');
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '{url page="bulkPluginManager" op="updatePlugin"}', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('installed');
                        btn.classList.remove('btn-install');
                        btn.classList.add('btn-success');
                        if (row) {
                            row.classList.remove('missing-file-row');
                            row.style.background = '#d4edda';
                        }
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.classList.add('btn-danger');
                        btn.disabled = false;
                        alert(result.message || 'Install failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                    alert(t('errServer'));
                }
            } else {
                btn.innerHTML = '❌ ' + t('error');
                btn.disabled = false;
                alert(t('errServer') + ' (' + xhr.status + ')');
            }
        };
        xhr.send(withCsrf('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=install'));
    }
    
    function cleanDbEntry(product, category) {
        if (!confirm(t('confirmCleanDb'))) return;
        
        var btn = event.target;
        var row = document.getElementById('installed-row-' + product);
        btn.disabled = true;
        btn.innerHTML = '⏳ ' + t('cleaning');
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '{url page="bulkPluginManager" op="updatePlugin"}', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('cleaned');
                        btn.classList.remove('btn-danger-sm');
                        btn.classList.add('btn-success');
                        if (row) {
                            row.style.opacity = '0.5';
                            row.style.background = '#d4edda';
                        }
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.disabled = false;
                        alert(result.message || 'Clean failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                    alert(t('errServer'));
                }
            } else {
                btn.innerHTML = '❌ ' + t('error');
                btn.disabled = false;
                alert(t('errServer') + ' (' + xhr.status + ')');
            }
        };
        xhr.send(withCsrf('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=cleandb'));
    }
    
    function renderInfoTabContent() {
        var h = '<div class="info-page">';
        
        // Header
        h += '<div class="info-header">';
        h += '<h2>ℹ️ ' + t('infoTitle') + '</h2>';
        h += '<p class="info-subtitle">' + t('infoSubtitle') + '</p>';
        h += '</div>';
        
        // Dashboard Cards Section
        h += '<div class="info-section">';
        h += '<h3>📊 ' + t('infoDashboardTitle') + '</h3>';
        h += '<div class="info-grid">';
        h += '<div class="info-item"><span class="info-icon">🖥️</span><strong>' + t('infoDashOJS') + '</strong><p>' + t('infoDashOJSDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">📚</span><strong>' + t('infoDashGallery') + '</strong><p>' + t('infoDashGalleryDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">🔌</span><strong>' + t('infoDashInstalled') + '</strong><p>' + t('infoDashInstalledDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">✅</span><strong>' + t('infoDashActive') + '</strong><p>' + t('infoDashActiveDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">⏸️</span><strong>' + t('infoDashInactive') + '</strong><p>' + t('infoDashInactiveDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">📦</span><strong>' + t('infoDashAvailable') + '</strong><p>' + t('infoDashAvailableDesc') + '</p></div>';
        h += '<div class="info-item"><span class="info-icon">⚠️</span><strong>' + t('infoDashNewer') + '</strong><p>' + t('infoDashNewerDesc') + '</p></div>';
        h += '</div></div>';
        
        // Tabs Section
        h += '<div class="info-section">';
        h += '<h3>📑 ' + t('infoTabsTitle') + '</h3>';
        h += '<div class="info-list">';
        h += '<div class="info-list-item"><span class="info-badge">🔌 ' + t('tabInstalled') + '</span><p>' + t('infoTabInstalled') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">🔧 ' + t('tabDbFix') + '</span><p>' + t('infoTabDbFix') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">🔄 ' + t('tabSync') + '</span><p>' + t('infoTabSync') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">📁 ' + t('tabMissing') + '</span><p>' + t('infoTabMissing') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">⬆️ ' + t('tabUpdate') + '</span><p>' + t('infoTabUpdate') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">📦 ' + t('tabAvailable') + '</span><p>' + t('infoTabAvailable') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">⚠️ ' + t('tabDowngrade') + '</span><p>' + t('infoTabDowngrade') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge">❓ ' + t('tabNotInGallery') + '</span><p>' + t('infoTabNotInGallery') + '</p></div>';
        h += '</div></div>';
        
        // Filters Section
        h += '<div class="info-section">';
        h += '<h3>🔍 ' + t('infoFiltersTitle') + '</h3>';
        h += '<div class="info-list">';
        h += '<div class="info-list-item"><span class="info-badge filter-badge">' + t('filterAll') + '</span><p>' + t('infoFilterAll') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge filter-badge">' + t('filterActive') + '</span><p>' + t('infoFilterActive') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge filter-badge">' + t('filterInactive') + '</span><p>' + t('infoFilterInactive') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge filter-badge">' + t('filterSync') + '</span><p>' + t('infoFilterSync') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge filter-badge">' + t('filterMissing') + '</span><p>' + t('infoFilterMissing') + '</p></div>';
        h += '</div></div>';
        
        // Buttons Section
        h += '<div class="info-section">';
        h += '<h3>🛠️ ' + t('infoButtonsTitle') + '</h3>';
        h += '<div class="info-list">';
        h += '<div class="info-list-item"><span class="info-btn btn-fix">🔧 Fix DB</span><p>' + t('infoButtonFix') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-btn btn-danger-sm">🗑️ Clean DB</span><p>' + t('infoButtonClean') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-btn btn-install">📦 Install</span><p>' + t('infoButtonInstall') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-btn btn-update">⬆️ Update</span><p>' + t('infoButtonUpdate') + '</p></div>';
        h += '</div></div>';
        
        // Statuses Section
        h += '<div class="info-section">';
        h += '<h3>📋 ' + t('infoStatusTitle') + '</h3>';
        h += '<div class="info-list">';
        h += '<div class="info-list-item"><span class="status-text green">✅ ' + t('statusActive') + '</span><p>' + t('infoStatusActive') + '</p></div>';
        h += '<div class="info-list-item"><span class="status-text gray">⏸️ ' + t('statusInactive') + '</span><p>' + t('infoStatusInactive') + '</p></div>';
        h += '<div class="info-list-item"><span class="status-text green">✓ OK</span><p>' + t('infoStatusOK') + '</p></div>';
        h += '<div class="info-list-item"><span class="status-text orange">⚠️ Missing</span><p>' + t('infoStatusMissing') + '</p></div>';
        h += '</div></div>';
        
        // Columns Section
        h += '<div class="info-section">';
        h += '<h3>📊 ' + t('infoColumnsTitle') + '</h3>';
        h += '<div class="info-list">';
        h += '<div class="info-list-item"><span class="info-badge badge-blue">DB</span><p>' + t('infoColumnDB') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge badge-green">File</span><p>' + t('infoColumnFile') + '</p></div>';
        h += '<div class="info-list-item"><span class="info-badge badge-gray">Gallery</span><p>' + t('infoColumnGallery') + '</p></div>';
        h += '</div></div>';
        
        // Common Problems Section
        h += '<div class="info-section">';
        h += '<h3>🐛 ' + t('infoProblemsTitle') + '</h3>';
        h += '<div class="info-problems">';
        h += '<div class="info-problem">';
        h += '<h4>' + t('infoProblem1Title') + '</h4>';
        h += '<p><strong>' + t('infoCause') + ':</strong> ' + t('infoProblem1Cause') + '</p>';
        h += '<p><strong>' + t('infoSolution') + ':</strong> ' + t('infoProblem1Solution') + '</p>';
        h += '</div>';
        h += '<div class="info-problem">';
        h += '<h4>' + t('infoProblem2Title') + '</h4>';
        h += '<p><strong>' + t('infoCause') + ':</strong> ' + t('infoProblem2Cause') + '</p>';
        h += '<p><strong>' + t('infoSolution') + ':</strong> ' + t('infoProblem2Solution') + '</p>';
        h += '</div>';
        h += '<div class="info-problem">';
        h += '<h4>' + t('infoProblem3Title') + '</h4>';
        h += '<p><strong>' + t('infoCause') + ':</strong> ' + t('infoProblem3Cause') + '</p>';
        h += '<p><strong>' + t('infoSolution') + ':</strong> ' + t('infoProblem3Solution') + '</p>';
        h += '</div>';
        h += '</div></div>';
        
        // Technical Notes Section
        h += '<div class="info-section">';
        h += '<h3>⚙️ ' + t('infoTechTitle') + '</h3>';
        h += '<div class="info-tech">';
        h += '<p>' + t('infoTech1') + '</p>';
        h += '<p>' + t('infoTech2') + '</p>';
        h += '<p>' + t('infoTech3') + '</p>';
        h += '<p>' + t('infoTech4') + '</p>';
        h += '</div></div>';
        
        h += '</div>';
        return h;
    }
    
    function renderTabContent(key, selectable) {
        var items = data[key] || [];
        var isAvailable = key === 'available';
        
        // Tab ikonları
        var tabIcons = {
            'syncIssue': '🔄',
            'missing': '📁',
            'updatable': '⬆️',
            'available': '📦',
            'downgrade': '⚠️',
            'notInGallery': '❓'
        };
        var icon = tabIcons[key] || '📋';
        
        // Boş durum kontrolü
        if (items.length === 0) {
            return '<div class="tab-description">' + icon + ' ' + t('tabDesc_' + key) + '</div><div class="empty-state"><div class="icon">✅</div><h3>' + t('noItems') + '</h3><p>' + t('noItemsDesc_' + key) + '</p></div>';
        }
        
        var h = '<div class="tab-description">' + icon + ' ' + t('tabDesc_' + key) + '</div>';
        
        h += '<div class="table-controls">';
        if (selectable) {
            h += '<label class="select-all"><input type="checkbox" onchange="toggleAll(\'' + key + '\', this)"> ' + t('selectAll') + '</label>';
        }
        h += '<input type="text" class="search-input" id="search-' + key + '" placeholder="🔍 ' + t('search') + '" onkeyup="filterTable(\'' + key + '\')">';
        h += '</div>';
        
        h += '<div class="table-wrapper"><table><thead><tr>';
        if (selectable) h += '<th class="col-check"></th>';
        h += '<th class="col-plugin">' + t('thPlugin') + '</th>';
        h += '<th class="col-cat">' + t('thCategory') + '</th>';
        
        if (isAvailable) {
            h += '<th class="col-ver">' + t('thVersion') + '</th>';
            h += '<th class="col-desc">' + t('thDesc') + '</th>';
        } else {
            h += '<th class="col-ver">' + t('thDB') + '</th>';
            h += '<th class="col-ver">' + t('thFile') + '</th>';
            h += '<th class="col-ver">' + t('thGallery') + '</th>';
        }
        h += '<th class="col-status">' + t('thStatus') + '</th>';
        h += '</tr></thead><tbody>';
        
        items.forEach(function(p, idx) {
            var isProcessed = processedProducts[p.product];
            h += '<tr id="row-' + escapeHtml(p.product) + '" class="' + (isProcessed ? 'updated' : '') + '" data-search="' + escapeHtml((p.displayName + ' ' + p.product).toLowerCase()) + '">';
            
            if (selectable) {
                h += '<td class="col-check"><input type="checkbox" class="pcheck" data-key="' + key + '" data-idx="' + idx + '" data-product="' + escapeHtml(p.product) + '" onchange="checkButtons()"' + (isProcessed ? ' disabled checked' : '') + '></td>';
            }
            
            h += '<td class="col-plugin"><span class="plugin-name">' + escapeHtml(p.displayName) + '</span><span class="plugin-id">' + escapeHtml(p.product) + '</span></td>';
            h += '<td class="col-cat"><span class="badge badge-gray">' + escapeHtml(p.category) + '</span></td>';
            
            if (isAvailable) {
                h += '<td class="col-ver"><span class="badge badge-green">' + escapeHtml(p.galleryVersion) + '</span></td>';
                h += '<td class="col-desc"><span class="plugin-desc" title="' + escapeHtml((p.description || '')).replace(/"/g, '&quot;') + '">' + escapeHtml(p.description || '-') + '</span></td>';
            } else {
                var dbBadge = key === 'syncIssue' ? 'badge-red' : (key === 'missing' ? 'badge-orange' : 'badge-blue');
                h += '<td class="col-ver"><span class="badge ' + dbBadge + '">' + escapeHtml(p.dbVersion || '-') + '</span></td>';
                
                var fileVer = p.fileVersion || '-';
                var fileBadge = key === 'syncIssue' ? 'badge-purple' : (key === 'downgrade' ? 'badge-green' : 'badge-orange');
                h += '<td class="col-ver"><span class="badge ' + (fileVer === '-' ? 'badge-red' : fileBadge) + '">' + escapeHtml(fileVer) + '</span></td>';
                
                var galleryVer = p.galleryVersion || '-';
                h += '<td class="col-ver"><span class="badge ' + (key === 'downgrade' ? 'badge-red' : 'badge-green') + '">' + escapeHtml(galleryVer) + '</span></td>';
            }
            
            h += '<td class="col-status" id="status-' + escapeHtml(p.product) + '">';
            if (isProcessed) {
                h += '<span class="status-text green">✓ ' + t('statusDone') + '</span>';
            } else if (key === 'syncIssue') {
                h += '<span class="status-text purple">🔧 ' + t('statusSync') + '</span>';
            } else if (key === 'missing') {
                h += '<span class="status-text orange">📁 ' + t('statusMissing') + '</span>';
            } else if (key === 'available') {
                h += '<span class="status-text green">📦 ' + t('statusAvailable') + '</span>';
            } else if (key === 'downgrade') {
                h += '<span class="status-text red">⚠️ ' + t('statusDowngrade') + '</span>';
            } else if (key === 'notInGallery') {
                h += '<span class="status-text">❓ ' + t('statusNotInGallery') + '</span>';
            }
            h += '</td></tr>';
        });
        
        h += '</tbody></table></div>';
        return h;
    }
    
    function setActiveTab(key) {
        activeTab = key;
        document.querySelectorAll('.tab-btn').forEach(function(btn) {
            btn.classList.toggle('active', btn.getAttribute('data-tab') === key);
        });
        document.querySelectorAll('.tab-content').forEach(function(content) {
            content.classList.toggle('active', content.id === 'tab-' + key);
        });
    }
    
    function filterTable(key) {
        var q = document.getElementById('search-' + key).value.toLowerCase();
        document.querySelectorAll('#tab-' + key + ' tbody tr').forEach(function(row) {
            row.style.display = row.getAttribute('data-search').indexOf(q) >= 0 ? '' : 'none';
        });
    }
    
    function toggleAll(key, cb) {
        document.querySelectorAll('#tab-' + key + ' .pcheck:not(:disabled)').forEach(function(box) {
            box.checked = cb.checked;
        });
        checkButtons();
    }
    
    function checkButtons() {
        var count = document.querySelectorAll('.pcheck:checked:not(:disabled)').length;
        document.getElementById('processBtn').disabled = count === 0 || processing;
    }
    
    function getSelectedPlugins() {
        var selected = [];
        document.querySelectorAll('.pcheck:checked:not(:disabled)').forEach(function(box) {
            var key = box.getAttribute('data-key');
            var idx = parseInt(box.getAttribute('data-idx'));
            var arr = data[key];
            if (arr && arr[idx]) {
                var p = Object.assign({}, arr[idx]);
                p._dataKey = key;
                if (key === 'available') p._action = 'install';
                else if (key === 'missing') p._action = 'missing';
                else if (key === 'notInGallery') p._action = 'cleandb';
                else p._action = 'update';
                selected.push(p);
            }
        });
        return selected;
    }
    
    function processSelected() {
        var selected = getSelectedPlugins();
        if (selected.length === 0) return;
        // If the selection contains destructive DB-clean actions, warn explicitly.
        var cleanCount = selected.filter(function(p) { return p._action === 'cleandb'; }).length;
        if (cleanCount > 0) {
            if (!confirm(cleanCount + ' ' + t('confirmBulkClean'))) return;
        }
        if (confirm(selected.length + ' ' + t('confirmProcess'))) startProcess(selected);
    }
    
    function fixSyncIssues() {
        if (!data.syncIssue || data.syncIssue.length === 0) return;
        if (confirm(data.syncIssue.length + ' ' + t('confirmFix'))) {
            var list = data.syncIssue.map(function(p) {
                var copy = Object.assign({}, p);
                copy._dataKey = 'syncIssue';
                copy._action = 'sync_only';
                return copy;
            });
            startProcess(list);
        }
    }
    
    function startProcess(list) {
        processing = true;
        // Structural changes (reinstall / DB clean) alter which rows exist, so the
        // list must be reloaded from the server when the run finishes.
        var needsReload = list.some(function(p) {
            return p._action === 'cleandb' || p._action === 'missing' || p._action === 'install' || p._action === 'dbfix';
        });
        document.getElementById('processBtn').disabled = true;
        document.getElementById('progressOverlay').classList.add('show');
        document.getElementById('completedSection').classList.add('show');
        document.getElementById('completedList').innerHTML = '';
        document.getElementById('completedCount').textContent = '0';
        
        var done = 0, ok = 0, fail = 0, total = list.length;
        
        function updateProgress() {
            var pct = Math.round((done / total) * 100);
            document.getElementById('progressBar').style.width = pct + '%';
            document.getElementById('progressBar').textContent = pct + '%';
            document.getElementById('progressInfo').textContent = done + ' / ' + total;
            document.getElementById('liveSuccess').textContent = ok;
            document.getElementById('liveError').textContent = fail;
        }
        
        function next(i) {
            if (i >= list.length) {
                processing = false;
                document.getElementById('progressOverlay').classList.remove('show');
                document.querySelector('.progress-title').textContent = t('completed');
                checkButtons();
                if (data.syncIssue && data.syncIssue.every(function(p) { return processedProducts[p.product]; })) {
                    document.getElementById('syncAlert').style.display = 'none';
                }
                // Refresh list if backup was restored/deleted, or after any
                // structural change (reinstall / DB clean) so the tables reflect reality.
                if (needsReload || currentAction === 'restore' || currentAction === 'delete_backup') {
                    setTimeout(function() { loadPlugins(); }, 1200);
                }
                return;
            }
            
            var p = list[i];
            var row = document.getElementById('row-' + p.product);
            var st = document.getElementById('status-' + p.product);
            
            if (row) { row.classList.add('updating'); row.classList.remove('updated', 'error'); }
            
            var actionText = t('processing');
            if (p._action === 'install') actionText = t('installing');
            else if (p._action === 'sync_only') actionText = t('syncing');
            else if (p._action === 'missing') actionText = t('reinstalling');
            else if (p._action === 'restore') actionText = t('restoring');
            else if (p._action === 'delete_backup') actionText = t('deleting');
            else actionText = t('updating');
            
            if (st) st.innerHTML = '<span class="spinner"></span> ' + actionText + '...';
            document.getElementById('progressCurrent').textContent = '➤ ' + escapeHtml(p.displayName || p.product);
            
            var xhr = new XMLHttpRequest();
            xhr.open('POST', updateUrl, true);
            xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== 4) return;
                done++;
                var success = false, errorMsg = '';

                if (xhr.status === 200) {
                    try {
                        var result = JSON.parse(xhr.responseText);
                        if (result.status === 'success') {
                            success = true; ok++;
                            processedProducts[p.product] = true;
                            if (row) { row.classList.remove('updating'); row.classList.add('updated'); }
                            if (st) st.innerHTML = '<span class="status-text green">✓ ' + t('statusDone') + '</span>';

                            var cb = document.querySelector('.pcheck[data-product="' + p.product + '"]');
                            if (cb) { cb.disabled = true; cb.checked = true; }
                        } else {
                            fail++; errorMsg = result.message || t('failed');
                            if (row) { row.classList.remove('updating'); row.classList.add('error'); }
                            if (st) st.innerHTML = '<span class="status-text red">✗ ' + escapeHtml(errorMsg) + '</span>';
                        }
                    } catch(e) {
                        fail++; errorMsg = t('errServer');
                        if (row) { row.classList.remove('updating'); row.classList.add('error'); }
                        if (st) st.innerHTML = '<span class="status-text red">✗ ' + escapeHtml(errorMsg) + '</span>';
                    }
                } else {
                    fail++; errorMsg = t('errServer') + ' (' + xhr.status + ')';
                    if (row) { row.classList.remove('updating'); row.classList.add('error'); }
                    if (st) st.innerHTML = '<span class="status-text red">✗ ' + escapeHtml(errorMsg) + '</span>';
                }

                addToCompleted(p, success, errorMsg);
                updateProgress();
                setTimeout(function() { next(i + 1); }, 300);
            };

            var params = 'product=' + encodeURIComponent(p.product) + '&category=' + encodeURIComponent(p.category) + '&action=' + encodeURIComponent(p._action || 'update');
            if (p.backupId) params += '&backupId=' + encodeURIComponent(p.backupId);

            xhr.send(withCsrf(params));
        }
        
        updateProgress();
        next(0);
    }
    
    function addToCompleted(plugin, success, message) {
        var list = document.getElementById('completedList');
        var countEl = document.getElementById('completedCount');
        
        var item = document.createElement('div');
        item.className = 'completed-item ' + (success ? 'success' : 'error');
        item.innerHTML = '<span class="icon">' + (success ? '✅' : '❌') + '</span>' +
            '<span class="name">' + escapeHtml(plugin.displayName || plugin.product) + '</span>' +
            '<span class="result">' + (success ? t('success') : (escapeHtml(message) || t('failed'))) + '</span>';
        
        list.insertBefore(item, list.firstChild);
        countEl.textContent = parseInt(countEl.textContent) + 1;
    }

    // New Functions for Backup/Restore/FixAll
    var currentAction = '';

    function fixAll(type) {
        var items = [];
        if (type === 'dbFix') items = data.dbFix;
        // else if (type === 'syncIssue') items = data.syncIssue; // Potentially supported later
        
        if (!items || items.length === 0) return;
        
        if (confirm(t('confirmFixAll'))) {
            var list = items.map(function(p) {
                var copy = Object.assign({}, p);
                copy._action = 'dbfix'; // Force dbfix action
                return copy;
            });
            currentAction = 'fix_all';
            startProcess(list);
        }
    }

    function restoreBackup(id, product, category) {
        if (!confirm(t('confirmRestore'))) return;

        var datePart = id.split('_bak_')[1] || '';
        datePart = datePart.replace('.zip', '');
        var item = {
            id: id,
            product: product,
            category: category,
            displayName: product + ' (' + datePart + ')',
            _action: 'restore',
            backupId: id
        };
        currentAction = 'restore';
        startProcess([item]);
    }

    function deleteBackup(id, product, category) {
        if (!confirm(t('confirmDeleteBackup'))) return;

        var datePart = id.split('_bak_')[1] || '';
        datePart = datePart.replace('.zip', '');
        var item = {
            id: id,
            product: product,
            category: category,
            displayName: product + ' (' + datePart + ')',
            _action: 'delete_backup',
            backupId: id
        };
        currentAction = 'delete_backup';
        startProcess([item]);
    }
    // === OJS Services Tab ===
    var ojsServicesApiUrl = '{url page="bulkPluginManager" op="getOjsServicesPlugins"}';
    var ojsServicesInstallUrl = '{url page="bulkPluginManager" op="installOjsServicesPlugin"}';
    var ojsServicesData = null;
    var ojsServicesLoaded = false;

    function renderOjsServicesTabContent() {
        var h = '<div class="ojs-services-header">';
        h += '<div>';
        h += '<h3>🚀 ' + t('ojsServicesTitle') + '</h3>';
        h += '<p>' + t('ojsServicesDesc') + '</p>';
        h += '</div>';
        h += '<button class="btn btn-light" onclick="loadOjsServicesPlugins(true)" style="color:#e65100">🔄 ' + t('ojsRefresh') + '</button>';
        h += '</div>';
        h += '<div id="ojsServicesContent" class="ojs-services-loading"><div class="spinner"></div><p>' + t('ojsServicesLoading') + '</p></div>';
        return h;
    }

    function loadOjsServicesPlugins(refresh) {
        var content = document.getElementById('ojsServicesContent');
        if (!content) return;
        content.innerHTML = '<div class="ojs-services-loading"><div class="spinner"></div><p>' + t('ojsServicesLoading') + '</p></div>';

        var url = ojsServicesApiUrl;
        if (refresh) {
            url += (url.indexOf('?') > -1 ? '&' : '?') + 'refresh=1';
        }

        var xhr = new XMLHttpRequest();
        xhr.open('POST', url, true);
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        ojsServicesData = result.plugins || [];
                        data.ojsServices = ojsServicesData;
                        renderOjsServicesCards();
                        // Update badge count
                        var badge = document.querySelector('.tab-btn[data-tab="ojsServices"] .badge');
                        if (badge) {
                            badge.textContent = ojsServicesData.length;
                            badge.className = 'badge';
                        }
                    } else {
                        content.innerHTML = '<div class="ojs-services-loading"><p style="color:red;">Error: ' + escapeHtml(result.message || 'Unknown error') + '</p></div>';
                    }
                } catch(e) {
                    content.innerHTML = '<div class="ojs-services-loading"><p style="color:red;">' + t('errServer') + '</p></div>';
                }
            } else if (xhr.readyState === 4) {
                content.innerHTML = '<div class="ojs-services-loading"><p style="color:red;">' + t('errServer') + ' (' + xhr.status + ')</p></div>';
            }
        };
        xhr.send();
    }

    function renderOjsServicesCards() {
        var content = document.getElementById('ojsServicesContent');
        if (!content || !ojsServicesData) return;

        if (ojsServicesData.length === 0) {
            content.innerHTML = '<div class="ojs-services-loading"><p>' + t('ojsNoPlugins') + '</p></div>';
            return;
        }

        var h = '<div class="ojs-services-grid">';
        ojsServicesData.forEach(function(p, idx) {
            var statusClass = p.status;
            var statusText = '';
            if (p.status === 'available') statusText = t('ojsAvailable');
            else if (p.status === 'installed') statusText = t('ojsInstalled');
            else if (p.status === 'update') statusText = t('ojsUpdate');
            else if (p.status === 'incompatible') statusText = t('ojsIncompatible');

            h += '<div class="ojs-service-card" id="ojs-card-' + escapeHtml(p.product) + '">';
            h += '<div class="card-header">';
            h += '<div><div class="card-title">' + escapeHtml(p.displayName) + '</div>';
            h += '<div class="card-product">' + escapeHtml(p.product) + '</div></div>';
            h += '<span class="card-status ' + statusClass + '">' + statusText + '</span>';
            h += '</div>';
            h += '<div class="card-desc">' + escapeHtml(p.description || '') + '</div>';
            h += '<div class="card-versions">';
            if (p.repoVersion) {
                h += '<span class="card-ver repo">' + t('ojsRepoVersion') + ': ' + escapeHtml(p.repoVersion) + '</span>';
            }
            if (p.installedVersion) {
                h += '<span class="card-ver local">' + t('ojsLocalVersion') + ': ' + escapeHtml(p.installedVersion) + '</span>';
            }
            h += '</div>';
            h += '<div class="card-actions">';

            if (p.status === 'available' && p.downloadUrl) {
                h += '<button class="btn-ojs-install" id="ojs-btn-' + escapeHtml(p.product) + '" onclick="installOjsServicePlugin(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.downloadUrl) + '\', \'install\', \'' + escapeHtml(p.category || 'generic') + '\')">' + t('ojsInstallBtn') + '</button>';
            } else if (p.status === 'update' && p.downloadUrl) {
                h += '<button class="btn-ojs-update" id="ojs-btn-' + escapeHtml(p.product) + '" onclick="installOjsServicePlugin(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.downloadUrl) + '\', \'update\', \'' + escapeHtml(p.category || 'generic') + '\')">' + t('ojsUpdateBtn') + '</button>';
            } else if (p.status === 'installed') {
                h += '<span class="status-text green">✅ ' + t('ojsInstalled') + '</span>';
            } else if (p.status === 'incompatible') {
                h += '<span class="status-text red">⚠️ ' + t('ojsIncompatible') + '</span>';
            }

            if (p.repoUrl) {
                h += '<a href="' + escapeHtml(p.repoUrl) + '" target="_blank">🔗 ' + t('ojsViewRepo') + '</a>';
            }
            h += '</div></div>';
        });
        h += '</div>';
        content.innerHTML = h;
    }

    function installOjsServicePlugin(product, downloadUrl, action, category) {
        var btn = document.getElementById('ojs-btn-' + product);
        var card = document.getElementById('ojs-card-' + product);
        if (!btn) return;

        btn.disabled = true;
        var origText = btn.textContent;
        btn.textContent = action === 'update' ? t('ojsUpdatingBtn') : t('ojsInstallingBtn');

        var xhr = new XMLHttpRequest();
        xhr.open('POST', ojsServicesInstallUrl, true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status === 200) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.textContent = '✅ ' + t('ojsInstalledBtn');
                        btn.classList.add('success');
                        btn.disabled = true;
                        if (card) card.style.borderColor = '#4caf50';
                        // Update card status indicator
                        var statusEl = card ? card.querySelector('.card-status') : null;
                        if (statusEl) {
                            statusEl.className = 'card-status installed';
                            statusEl.textContent = t('ojsInstalled');
                        }
                    } else {
                        btn.textContent = '❌ ' + (result.message || t('failed'));
                        btn.disabled = false;
                        setTimeout(function() { btn.textContent = origText; btn.disabled = false; }, 3000);
                    }
                } catch(e) {
                    btn.textContent = '❌ ' + t('errServer');
                    btn.disabled = false;
                    setTimeout(function() { btn.textContent = origText; btn.disabled = false; }, 3000);
                }
            } else {
                btn.textContent = '❌ ' + t('errServer');
                btn.disabled = false;
                setTimeout(function() { btn.textContent = origText; btn.disabled = false; }, 3000);
            }
        };
        xhr.send(withCsrf('product=' + encodeURIComponent(product) + '&downloadUrl=' + encodeURIComponent(downloadUrl) + '&action=' + encodeURIComponent(action) + '&category=' + encodeURIComponent(category || 'generic')));
    }

    // Override setActiveTab to lazy-load OJS Services data
    var _originalSetActiveTab = setActiveTab;
    setActiveTab = function(key) {
        _originalSetActiveTab(key);
        if (key === 'ojsServices' && !ojsServicesLoaded) {
            ojsServicesLoaded = true;
            loadOjsServicesPlugins(false);
        }
    };
    </script>
</body>
</html>
