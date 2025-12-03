<?php
/**
 * @file plugins/generic/bulkPluginManager/BulkPluginManagerHandler.inc.php
 *
 * @class BulkPluginManagerHandler
 * @brief Handler for bulk plugin update operations
 */

import('classes.handler.Handler');

class BulkPluginManagerHandler extends Handler {

    public function __construct() {
        parent::__construct();
        $this->addRoleAssignment(
            array(ROLE_ID_SITE_ADMIN, ROLE_ID_MANAGER),
            array('index', 'getUpdatablePlugins', 'updatePlugin')
        );
    }

    public function authorize($request, &$args, $roleAssignments) {
        import('lib.pkp.classes.security.authorization.PolicySet');
        $rolePolicy = new PolicySet(COMBINING_PERMIT_OVERRIDES);
        import('lib.pkp.classes.security.authorization.PKPSiteAccessPolicy');
        $rolePolicy->addPolicy(new PKPSiteAccessPolicy($request, null, $roleAssignments));
        import('lib.pkp.classes.security.authorization.ContextAccessPolicy');
        $rolePolicy->addPolicy(new ContextAccessPolicy($request, $roleAssignments));
        $this->addPolicy($rolePolicy);
        return parent::authorize($request, $args, $roleAssignments);
    }

    public function index($args, $request) {
        $this->setupTemplate($request);
        $templateMgr = TemplateManager::getManager($request);
        $plugin = PluginRegistry::getPlugin('generic', 'bulkpluginmanagerplugin');
        return $templateMgr->display($plugin->getTemplateResource('index.tpl'));
    }

    /**
     * Get all plugins needing attention (AJAX)
     */
    public function getUpdatablePlugins($args, $request) {
        $result = $this->fetchAllPlugins();
        
        header('Content-Type: application/json');
        echo json_encode($result);
        exit;
    }

    /**
     * Check OJS version compatibility
     */
    private function isVersionCompatible($versionString) {
        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();
        $major = $currentVersion->getMajor();
        $minor = $currentVersion->getMinor();
        
        $parts = explode('.', $versionString);
        $galleryMajor = isset($parts[0]) ? (int)$parts[0] : 0;
        $galleryMinor = isset($parts[1]) ? (int)$parts[1] : 0;
        
        return ($galleryMajor == $major && $galleryMinor == $minor);
    }

    /**
     * Normalize version string to 4 parts (e.g., 0.7.8 -> 0.7.8.0)
     */
    private function normalizeVersion($version) {
        if (!$version || $version === '-') return null;
        $parts = explode('.', $version);
        while (count($parts) < 4) {
            $parts[] = '0';
        }
        return implode('.', array_slice($parts, 0, 4));
    }
    
    /**
     * Get installed plugin info - both DB and file versions
     */
    private function getInstalledInfo($category, $product) {
        $pluginDir = Core::getBaseDir() . '/plugins/' . $category . '/' . $product;
        $result = array(
            'dbVersion' => null,
            'fileVersion' => null,
            'filesExist' => false,
            'inDatabase' => false,
            'syncIssue' => false
        );
        
        // Check if files exist (case-insensitive directory check)
        $result['filesExist'] = false;
        $categoryDir = Core::getBaseDir() . '/plugins/' . $category;
        if (is_dir($categoryDir)) {
            $dirs = @scandir($categoryDir);
            if ($dirs) {
                foreach ($dirs as $dir) {
                    if (strtolower($dir) === strtolower($product)) {
                        $pluginDir = $categoryDir . '/' . $dir;
                        if (file_exists($pluginDir . '/index.php') || file_exists($pluginDir . '/version.xml')) {
                            $result['filesExist'] = true;
                            
                            // Get file version from version.xml
                            $versionFile = $pluginDir . '/version.xml';
                            if (file_exists($versionFile)) {
                                $versionXml = @simplexml_load_file($versionFile);
                                if ($versionXml && isset($versionXml->release)) {
                                    $result['fileVersion'] = (string) $versionXml->release;
                                }
                            }
                        }
                        break;
                    }
                }
            }
        }
        
        // Get DB version - prefer current=1, fallback to highest
        $versionDao = DAORegistry::getDAO('VersionDAO');
        $dbResult = $versionDao->retrieve(
            "SELECT major, minor, revision, build FROM versions 
             WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)
             ORDER BY current DESC, major DESC, minor DESC, revision DESC, build DESC LIMIT 1",
            array('plugins.' . $category, $product)
        );
        
        foreach ($dbResult as $row) {
            $result['dbVersion'] = $row->major . '.' . $row->minor . '.' . $row->revision . '.' . $row->build;
            $result['inDatabase'] = true;
            break;
        }
        
        // Check sync issue: DB and file versions don't match (normalized comparison)
        $normDbVer = $this->normalizeVersion($result['dbVersion']);
        $normFileVer = $this->normalizeVersion($result['fileVersion']);
        if ($normDbVer && $normFileVer && $normDbVer !== $normFileVer) {
            $result['syncIssue'] = true;
        }
        
        return $result;
    }

    /**
     * Fetch all plugins and categorize them
     */
    private function fetchAllPlugins() {
        $updatable = array();
        $missing = array();
        $syncIssue = array();
        $downgrade = array();
        $notInGallery = array();
        $available = array();  // New: plugins that can be installed
        $dbFix = array();      // New: plugins needing DB version fix
        $debug = array();
        
        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();
        $debug['ojsVersion'] = $currentVersion->getVersionString();
        
        // Fetch gallery
        $client = Application::get()->getHttpClient();
        try {
            $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml');
            $xmlContent = (string) $response->getBody();
        } catch (Exception $e) {
            return array('status' => 'error', 'message' => 'Gallery fetch failed: ' . $e->getMessage());
        }
        
        $xml = @simplexml_load_string($xmlContent);
        if (!$xml) {
            return array('status' => 'error', 'message' => 'XML parse failed');
        }
        
        $debug['galleryCount'] = count($xml->plugin);
        $debug['checked'] = array();
        
        $versionDao = DAORegistry::getDAO('VersionDAO');
        
        // Build gallery products cache for fast lookup
        $galleryProducts = array();
        foreach ($xml->plugin as $plugin) {
            $product = (string) $plugin['product'];
            $category = (string) $plugin['category'];
            $key = strtolower($category . '/' . $product);
            
            // Find latest compatible release
            $latestRelease = null;
            $latestVersion = '0.0.0.0';
            foreach ($plugin->release as $release) {
                if (isset($release['application']) && (string) $release['application'] === 'ojs2') {
                    foreach ($release->compatibility as $compat) {
                        if ($this->isVersionCompatible((string) $compat['version'])) {
                            $relVer = (string) $release['version'];
                            if (version_compare($relVer, $latestVersion, '>')) {
                                $latestVersion = $relVer;
                                $latestRelease = $release;
                            }
                        }
                    }
                }
            }
            
            if ($latestRelease) {
                $galleryProducts[$key] = array(
                    'product' => $product,
                    'category' => $category,
                    'name' => (string) $plugin->name,
                    'version' => (string) $latestRelease['version'],
                    'package' => (string) $latestRelease->package,
                    'md5' => (string) $latestRelease->md5
                );
            }
        }
        
        // Check each plugin in gallery
        foreach ($xml->plugin as $plugin) {
            $product = (string) $plugin['product'];
            $category = (string) $plugin['category'];
            
            // Find latest compatible release
            $latestRelease = null;
            $latestVersion = '0.0.0.0';
            
            foreach ($plugin->release as $release) {
                foreach ($release->compatibility as $compat) {
                    if ((string) $compat['application'] === 'ojs2') {
                        foreach ($compat->version as $ver) {
                            if ($this->isVersionCompatible((string) $ver)) {
                                $relVer = (string) $release['version'];
                                if (version_compare($relVer, $latestVersion, '>')) {
                                    $latestVersion = $relVer;
                                    $latestRelease = $release;
                                }
                                break 2;
                            }
                        }
                    }
                }
            }
            
            if (!$latestRelease) continue;
            
            // Get display name
            $name = $product;
            foreach ($plugin->name as $nameEl) {
                if ((string) $nameEl['locale'] === 'en_US' || !(string) $nameEl['locale']) {
                    $name = (string) $nameEl;
                    break;
                }
            }
            
            // Get description
            $description = '';
            foreach ($plugin->description as $descEl) {
                if ((string) $descEl['locale'] === 'en_US' || !(string) $descEl['locale']) {
                    $description = (string) $descEl;
                    break;
                }
            }
            
            $galleryVer = (string) $latestRelease['version'];
            
            // Get installed info
            $info = $this->getInstalledInfo($category, $product);
            
            $pluginData = array(
                'product' => $product,
                'category' => $category,
                'displayName' => $name,
                'description' => $description,
                'dbVersion' => $info['dbVersion'] ?: '-',
                'fileVersion' => $info['fileVersion'] ?: '-',
                'galleryVersion' => $galleryVer,
                'package' => (string) $latestRelease->package,
                'md5' => (string) $latestRelease->md5
            );
            
            // Case 0: Not installed at all - available for installation
            if (!$info['inDatabase'] && !$info['filesExist']) {
                $pluginData['status'] = 'available';
                $available[] = $pluginData;
                continue;
            }
            
            // Case 1: Files missing
            if ($info['inDatabase'] && !$info['filesExist']) {
                $pluginData['status'] = 'missing';
                $missing[] = $pluginData;
                $debug['checked'][] = $product . ': MISSING (DB:' . $info['dbVersion'] . ')';
                continue;
            }
            
            // Case 2: Sync issue - DB and file version mismatch
            if ($info['syncIssue']) {
                $cmpGalleryFile = version_compare($galleryVer, $info['fileVersion']);
                $cmpDbGallery = version_compare($info['dbVersion'], $galleryVer);
                
                // DB version > Gallery version = needs DB fix first
                if ($cmpDbGallery > 0) {
                    $pluginData['status'] = 'dbfix';
                    $pluginData['action'] = 'DB düzeltme gerekli';
                    $dbFix[] = $pluginData;
                    $debug['checked'][] = $product . ': DB FIX (DB:' . $info['dbVersion'] . ' > Gallery:' . $galleryVer . ', File:' . $info['fileVersion'] . ')';
                } else if ($cmpGalleryFile > 0) {
                    $pluginData['status'] = 'sync_update';
                    $pluginData['action'] = 'DB senkronize + güncelleme';
                    $syncIssue[] = $pluginData;
                    $debug['checked'][] = $product . ': SYNC+UPDATE (DB:' . $info['dbVersion'] . ' File:' . $info['fileVersion'] . ' -> ' . $galleryVer . ')';
                } else if ($cmpGalleryFile == 0) {
                    $pluginData['status'] = 'sync_only';
                    $pluginData['action'] = 'Sadece DB senkronize';
                    $syncIssue[] = $pluginData;
                    $debug['checked'][] = $product . ': SYNC ONLY (DB:' . $info['dbVersion'] . ' -> File:' . $info['fileVersion'] . ')';
                } else {
                    $pluginData['status'] = 'downgrade';
                    $downgrade[] = $pluginData;
                    $debug['checked'][] = $product . ': FILE NEWER (File:' . $info['fileVersion'] . ' > Gallery:' . $galleryVer . ')';
                }
                continue;
            }
            
            // Case 3: Normal - use file version (or db version if no file)
            $effectiveVersion = $info['fileVersion'] ?: $info['dbVersion'];
            $cmp = version_compare($galleryVer, $effectiveVersion);
            
            if ($cmp > 0) {
                $pluginData['status'] = 'update';
                $updatable[] = $pluginData;
                $debug['checked'][] = $product . ': ' . $effectiveVersion . ' -> ' . $galleryVer . ' [UPDATE]';
            } else if ($cmp < 0) {
                $pluginData['status'] = 'downgrade';
                $downgrade[] = $pluginData;
                $debug['checked'][] = $product . ': ' . $effectiveVersion . ' > ' . $galleryVer . ' [NEWER]';
            } else {
                $debug['checked'][] = $product . ': ' . $effectiveVersion . ' (up to date)';
            }
        }
        
        // Check for plugins in DB that are not in gallery - prefer current=1
        $result = $versionDao->retrieve(
            "SELECT v.product_type, v.product, v.major, v.minor, v.revision, v.build 
             FROM versions v
             WHERE v.product_type LIKE 'plugins.%'
             AND (
                 v.current = 1 
                 OR (
                     v.current = 0 
                     AND NOT EXISTS (
                         SELECT 1 FROM versions v2 
                         WHERE v2.product_type = v.product_type 
                         AND v2.product = v.product 
                         AND v2.current = 1
                     )
                     AND (v.major*1000000 + v.minor*10000 + v.revision*100 + v.build) = (
                         SELECT MAX(v3.major*1000000 + v3.minor*10000 + v3.revision*100 + v3.build)
                         FROM versions v3
                         WHERE v3.product_type = v.product_type AND v3.product = v.product
                     )
                 )
             )"
        );
        
        $checkedProducts = array();
        foreach ($updatable as $p) $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($missing as $p) $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($syncIssue as $p) $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($downgrade as $p) $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($dbFix as $p) $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        
        foreach ($result as $row) {
            $productType = $row->product_type;
            $product = $row->product;
            $category = str_replace('plugins.', '', $productType);
            $key = strtolower($category . '/' . $product);
            
            if (isset($checkedProducts[$key])) continue;
            
            $info = $this->getInstalledInfo($category, $product);
            
            if ($info['inDatabase'] && !$info['filesExist']) {
                $dbVer = $row->major . '.' . $row->minor . '.' . $row->revision . '.' . $row->build;
                $notInGallery[] = array(
                    'product' => $product,
                    'category' => $category,
                    'displayName' => $product,
                    'dbVersion' => $dbVer,
                    'fileVersion' => '-',
                    'galleryVersion' => '-',
                    'status' => 'not_in_gallery'
                );
                $debug['checked'][] = $product . ': NOT IN GALLERY (missing)';
            }
        }
        
        // Sort
        $sorter = function($a, $b) { return strcasecmp($a['displayName'], $b['displayName']); };
        usort($updatable, $sorter);
        usort($missing, $sorter);
        usort($syncIssue, $sorter);
        usort($downgrade, $sorter);
        usort($notInGallery, $sorter);
        usort($available, $sorter);
        usort($dbFix, $sorter);
        
        // Get all installed plugins with their status
        $installedPlugins = array();
        $installedActive = 0;
        $installedInactive = 0;
        
        // Get current context
        $request = Application::get()->getRequest();
        $context = $request->getContext();
        $contextId = $context ? $context->getId() : 0;
        
        // Query all installed plugins - prefer current=1, fallback to highest version
        $pluginResult = $versionDao->retrieve(
            "SELECT v.product_type, v.product, v.major, v.minor, v.revision, v.build
             FROM versions v
             WHERE v.product_type LIKE 'plugins.%'
             AND (
                 v.current = 1 
                 OR (
                     v.current = 0 
                     AND NOT EXISTS (
                         SELECT 1 FROM versions v2 
                         WHERE v2.product_type = v.product_type 
                         AND v2.product = v.product 
                         AND v2.current = 1
                     )
                     AND (v.major*1000000 + v.minor*10000 + v.revision*100 + v.build) = (
                         SELECT MAX(v3.major*1000000 + v3.minor*10000 + v3.revision*100 + v3.build)
                         FROM versions v3
                         WHERE v3.product_type = v.product_type AND v3.product = v.product
                     )
                 )
             )
             ORDER BY LOWER(v.product)"
        );
        
        foreach ($pluginResult as $row) {
            $category = str_replace('plugins.', '', $row->product_type);
            $product = $row->product;
            $dbVersion = $row->major . '.' . $row->minor . '.' . $row->revision . '.' . $row->build;
            
            // Get file version
            $fileVersion = null;
            $pluginDir = Core::getBaseDir() . '/plugins/' . $category . '/' . $product;
            $categoryDir = Core::getBaseDir() . '/plugins/' . $category;
            
            // Case-insensitive directory check
            if (is_dir($categoryDir)) {
                $dirs = @scandir($categoryDir);
                if ($dirs) {
                    foreach ($dirs as $dir) {
                        if (strtolower($dir) === strtolower($product)) {
                            $actualDir = $categoryDir . '/' . $dir;
                            $versionFile = $actualDir . '/version.xml';
                            if (file_exists($versionFile)) {
                                $versionXml = @simplexml_load_file($versionFile);
                                if ($versionXml && isset($versionXml->release)) {
                                    $fileVersion = (string) $versionXml->release;
                                }
                            }
                            break;
                        }
                    }
                }
            }
            
            // Check if plugin is enabled - query directly from plugin_settings
            $enabled = false;
            $pluginName = strtolower($product . 'plugin');
            
            // Check in plugin_settings table directly (case-insensitive)
            $settingsResult = $versionDao->retrieve(
                "SELECT setting_value FROM plugin_settings 
                 WHERE LOWER(plugin_name) = LOWER(?) AND setting_name = 'enabled' 
                 AND (context_id = ? OR context_id = 0)
                 ORDER BY context_id DESC LIMIT 1",
                array($pluginName, $contextId)
            );
            
            foreach ($settingsResult as $settingRow) {
                if ($settingRow->setting_value === '1' || $settingRow->setting_value === 1 || $settingRow->setting_value === true) {
                    $enabled = true;
                }
                break;
            }
            
            // Get display name
            $displayName = ucfirst(preg_replace('/([A-Z])/', ' $1', $product));
            
            // Check for sync issue (normalized comparison)
            $normDbVer = $this->normalizeVersion($dbVersion);
            $normFileVer = $this->normalizeVersion($fileVersion);
            $hasSyncIssue = ($normDbVer && $normFileVer && $normDbVer !== $normFileVer);
            
            // Check if in gallery (for missing files case) - use cache
            $galleryInfo = null;
            if (!$fileVersion) {
                $galleryKey = strtolower($category . '/' . $product);
                if (isset($galleryProducts[$galleryKey])) {
                    $galleryInfo = $galleryProducts[$galleryKey];
                }
            }
            
            $installedPlugins[] = array(
                'product' => $product,
                'category' => $category,
                'displayName' => trim($displayName),
                'dbVersion' => $dbVersion,
                'fileVersion' => $fileVersion ?: '-',
                'enabled' => $enabled,
                'filesExist' => ($fileVersion !== null),
                'syncIssue' => $hasSyncIssue,
                'inGallery' => ($galleryInfo !== null),
                'galleryVersion' => $galleryInfo ? $galleryInfo['version'] : null
            );
            
            if ($enabled) {
                $installedActive++;
            } else {
                $installedInactive++;
            }
        }
        
        usort($installedPlugins, $sorter);
        
        $debug['counts'] = array(
            'updatable' => count($updatable),
            'missing' => count($missing),
            'syncIssue' => count($syncIssue),
            'downgrade' => count($downgrade),
            'notInGallery' => count($notInGallery),
            'available' => count($available),
            'dbFix' => count($dbFix)
        );
        
        $debug['installed'] = array(
            'total' => count($installedPlugins),
            'active' => $installedActive,
            'inactive' => $installedInactive
        );
        
        return array(
            'status' => 'success',
            'updatable' => $updatable,
            'missing' => $missing,
            'syncIssue' => $syncIssue,
            'downgrade' => $downgrade,
            'notInGallery' => $notInGallery,
            'available' => $available,
            'dbFix' => $dbFix,
            'installed' => $installedPlugins,
            'debug' => $debug
        );
    }

    /**
     * Update or install a plugin (AJAX)
     */
    public function updatePlugin($args, $request) {
        $product = $request->getUserVar('product');
        $category = $request->getUserVar('category');
        $action = $request->getUserVar('action'); // 'update', 'install', 'sync_update', 'sync_only', 'missing', 'dbfix'
        
        if (!$product || !$category) {
            $this->jsonResponse('error', 'Missing parameters');
        }
        
        try {
            // Get current state
            $info = $this->getInstalledInfo($category, $product);
            
            // Handle DB fix action - sync DB to file version
            if ($action === 'dbfix') {
                if (!$info['fileVersion']) {
                    throw new Exception('Dosya versiyonu bulunamadı');
                }
                $syncResult = $this->syncDatabaseVersion($category, $product, $info['fileVersion']);
                if (!$syncResult) {
                    throw new Exception('DB düzeltme başarısız');
                }
                $this->jsonResponse('success', 'DB düzeltildi: ' . $info['fileVersion'], $product);
                return;
            }
            
            // Handle DB clean action - remove DB entries for missing plugins
            if ($action === 'cleandb') {
                $versionDao = DAORegistry::getDAO('VersionDAO');
                
                // Delete version entries using update() for non-SELECT queries
                $versionDao->update(
                    "DELETE FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)",
                    array('plugins.' . $category, $product)
                );
                
                // Also clean plugin_settings
                $pluginName = strtolower($product . 'plugin');
                $versionDao->update(
                    "DELETE FROM plugin_settings WHERE LOWER(plugin_name) = LOWER(?)",
                    array($pluginName)
                );
                
                $this->jsonResponse('success', 'DB kayıtları temizlendi', $product);
                return;
            }
            
            // Get gallery info first to compare versions
            $pluginInfo = $this->getGalleryPluginInfo($product, $category);
            
            // Safety check: If DB version > Gallery version, refuse to downgrade
            if ($info['dbVersion'] && $pluginInfo && $action !== 'sync_only') {
                $dbVer = $info['dbVersion'];
                $galleryVer = $pluginInfo['version'];
                
                if (version_compare($dbVer, $galleryVer, '>')) {
                    throw new Exception('DB versiyonu (' . $dbVer . ') Gallery versiyonundan (' . $galleryVer . ') büyük. Downgrade yapılamaz. Önce DB senkronizasyonu gerekli.');
                }
            }
            
            // Step 1: Fix sync issue if needed (DB version != file version)
            if ($info['syncIssue'] && $info['fileVersion'] && $action !== 'sync_only') {
                // Before syncing, check if file version is compatible with gallery
                if ($pluginInfo) {
                    $fileVer = $info['fileVersion'];
                    $galleryVer = $pluginInfo['version'];
                    
                    // Sync DB to file version first
                    $syncResult = $this->syncDatabaseVersion($category, $product, $fileVer);
                    if (!$syncResult) {
                        throw new Exception('DB sync failed');
                    }
                    
                    // If file version >= gallery version, no need to update
                    if (version_compare($fileVer, $galleryVer, '>=')) {
                        $this->jsonResponse('success', 'Senkronize edildi, güncelleme gerekmedi', $product);
                        return;
                    }
                }
            }
            
            // Step 2: If sync_only, just sync DB to file version
            if ($action === 'sync_only') {
                if ($info['fileVersion']) {
                    $syncResult = $this->syncDatabaseVersion($category, $product, $info['fileVersion']);
                    if (!$syncResult) {
                        throw new Exception('DB sync failed');
                    }
                    $this->jsonResponse('success', 'DB senkronize edildi', $product);
                } else {
                    throw new Exception('Dosya versiyonu bulunamadı');
                }
                return;
            }
            
            // Step 3: Verify we have gallery info
            if (!$pluginInfo) {
                throw new Exception('Gallery\'de OJS 3.3 uyumlu versiyon bulunamadı');
            }
            
            // Step 4: Download and install from gallery
            $result = $this->downloadAndInstall($category, $product, $pluginInfo['package'], $pluginInfo['md5'], $action === 'install');
            
            if ($result !== true) {
                throw new Exception($result);
            }
            
            $this->jsonResponse('success', 'OK', $product);
            
        } catch (Exception $e) {
            $this->jsonResponse('error', $e->getMessage(), $product);
        }
    }
    
    /**
     * Sync database version to match file version
     */
    private function syncDatabaseVersion($category, $product, $targetVersion) {
        $versionDao = DAORegistry::getDAO('VersionDAO');
        
        try {
            // First, set all existing versions for this plugin to current=0 using direct SQL
            $versionDao->update(
                "UPDATE versions SET current = 0 
                 WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)",
                array('plugins.' . $category, $product)
            );
            
            // Parse target version string (e.g., "3.2.0.3" or "1.1.3.15")
            $parts = explode('.', $targetVersion);
            $major = isset($parts[0]) ? (int)$parts[0] : 1;
            $minor = isset($parts[1]) ? (int)$parts[1] : 0;
            $revision = isset($parts[2]) ? (int)$parts[2] : 0;
            $build = isset($parts[3]) ? (int)$parts[3] : 0;
            
            // Check if this exact version already exists
            $existingResult = $versionDao->retrieve(
                "SELECT * FROM versions 
                 WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)
                 AND major = ? AND minor = ? AND revision = ? AND build = ?",
                array('plugins.' . $category, $product, $major, $minor, $revision, $build)
            );
            
            $exists = false;
            foreach ($existingResult as $row) {
                $exists = true;
                break;
            }
            
            if ($exists) {
                // Update existing record to current=1
                $versionDao->update(
                    "UPDATE versions SET current = 1, date_installed = NOW() 
                     WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)
                     AND major = ? AND minor = ? AND revision = ? AND build = ?",
                    array('plugins.' . $category, $product, $major, $minor, $revision, $build)
                );
            } else {
                // Get product_class_name from existing record if available
                $classNameResult = $versionDao->retrieve(
                    "SELECT product_class_name FROM versions 
                     WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?) 
                     AND product_class_name != '' LIMIT 1",
                    array('plugins.' . $category, $product)
                );
                $productClassName = '';
                foreach ($classNameResult as $row) {
                    $productClassName = $row->product_class_name;
                    break;
                }
                
                // If still empty, generate it from product name
                if (empty($productClassName)) {
                    $productClassName = ucfirst($product) . 'Plugin';
                }
                
                // Insert new version record
                $versionDao->update(
                    "INSERT INTO versions (major, minor, revision, build, date_installed, current, product_type, product, product_class_name, lazy_load, sitewide) 
                     VALUES (?, ?, ?, ?, NOW(), 1, ?, ?, ?, 1, 0)",
                    array($major, $minor, $revision, $build, 'plugins.' . $category, $product, $productClassName)
                );
            }
            
            return true;
        } catch (Exception $e) {
            error_log('syncDatabaseVersion error: ' . $e->getMessage());
            return false;
        }
    }

    /**
     * Download and install plugin
     */
    private function downloadAndInstall($category, $product, $packageUrl, $md5sum, $isNewInstall = false) {
        $tempDir = sys_get_temp_dir() . '/ojs_plugin_' . uniqid();
        if (!mkdir($tempDir, 0755, true)) {
            return 'Temp dir creation failed';
        }
        
        try {
            // Download
            $packageFile = $tempDir . '/plugin.tar.gz';
            $client = Application::get()->getHttpClient();
            
            try {
                $client->request('GET', $packageUrl, ['sink' => $packageFile, 'timeout' => 60]);
            } catch (Exception $e) {
                throw new Exception('Download failed: ' . $e->getMessage());
            }
            
            if (!file_exists($packageFile) || filesize($packageFile) < 100) {
                throw new Exception('Download failed or file too small');
            }
            
            // Verify MD5
            if ($md5sum && md5_file($packageFile) !== $md5sum) {
                throw new Exception('MD5 checksum mismatch');
            }
            
            // Extract
            $extractDir = $tempDir . '/extracted';
            mkdir($extractDir, 0755, true);
            
            try {
                $phar = new PharData($packageFile);
                $phar->extractTo($extractDir);
            } catch (Exception $e) {
                throw new Exception('Extract failed: ' . $e->getMessage());
            }
            
            // Find plugin source
            $pluginSourceDir = $this->findPluginDir($extractDir, $product);
            if (!$pluginSourceDir) {
                throw new Exception('Plugin folder not found in archive');
            }
            
            // Verify version.xml exists
            if (!file_exists($pluginSourceDir . '/version.xml')) {
                throw new Exception('version.xml not found in plugin');
            }
            
            // Target directory
            $pluginDestDir = Core::getBaseDir() . '/plugins/' . $category . '/' . $product;
            
            // Backup if exists
            $backupDir = null;
            if (is_dir($pluginDestDir)) {
                $backupDir = $pluginDestDir . '_bak_' . date('YmdHis');
                if (!rename($pluginDestDir, $backupDir)) {
                    throw new Exception('Backup failed');
                }
            }
            
            // Copy files
            if (!$this->recursiveCopy($pluginSourceDir, $pluginDestDir)) {
                if ($backupDir && is_dir($backupDir)) {
                    rename($backupDir, $pluginDestDir);
                }
                throw new Exception('File copy failed');
            }
            
            // Update database version
            $versionFile = $pluginDestDir . '/version.xml';
            if (!$this->updateDatabaseVersion($versionFile, $category, $product)) {
                // Don't fail, just log
                error_log('Warning: Could not update version in database for ' . $product);
            }
            
            // Remove backup
            if ($backupDir && is_dir($backupDir)) {
                $this->recursiveDelete($backupDir);
            }
            
            // Cleanup temp
            $this->recursiveDelete($tempDir);
            
            return true;
            
        } catch (Exception $e) {
            $this->recursiveDelete($tempDir);
            return $e->getMessage();
        }
    }

    private function findPluginDir($extractDir, $product) {
        if (is_dir($extractDir . '/' . $product)) {
            return $extractDir . '/' . $product;
        }
        
        $dirs = glob($extractDir . '/*', GLOB_ONLYDIR);
        foreach ($dirs as $dir) {
            if (basename($dir) === $product) return $dir;
            if (file_exists($dir . '/version.xml')) return $dir;
            if (is_dir($dir . '/' . $product)) return $dir . '/' . $product;
            
            $subDirs = glob($dir . '/*', GLOB_ONLYDIR);
            foreach ($subDirs as $subDir) {
                if (basename($subDir) === $product) return $subDir;
                if (file_exists($subDir . '/version.xml')) return $subDir;
            }
        }
        
        return null;
    }

    private function updateDatabaseVersion($versionFile, $category, $product) {
        import('lib.pkp.classes.site.VersionCheck');
        $versionInfo = VersionCheck::parseVersionXML($versionFile);
        if (!$versionInfo) return false;
        
        $versionDao = DAORegistry::getDAO('VersionDAO');
        $version = $versionInfo['version'];
        $version->setProductType('plugins.' . $category);
        $version->setProduct($product);
        $version->setCurrent(1);
        
        $versionDao->disableVersion('plugins.' . $category, $product);
        $versionDao->insertVersion($version, true);
        
        return true;
    }

    private function getGalleryPluginInfo($product, $category) {
        $client = Application::get()->getHttpClient();
        try {
            $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml');
            $xml = @simplexml_load_string((string) $response->getBody());
        } catch (Exception $e) {
            return null;
        }
        
        if (!$xml) return null;
        
        foreach ($xml->plugin as $plugin) {
            if ((string) $plugin['product'] !== $product || (string) $plugin['category'] !== $category) {
                continue;
            }
            
            // Find best compatible release
            $bestRelease = null;
            $bestVersion = '0.0.0.0';
            
            foreach ($plugin->release as $release) {
                foreach ($release->compatibility as $compat) {
                    if ((string) $compat['application'] === 'ojs2') {
                        foreach ($compat->version as $ver) {
                            if ($this->isVersionCompatible((string) $ver)) {
                                $relVer = (string) $release['version'];
                                if (version_compare($relVer, $bestVersion, '>')) {
                                    $bestVersion = $relVer;
                                    $bestRelease = $release;
                                }
                                break 2;
                            }
                        }
                    }
                }
            }
            
            if ($bestRelease) {
                return array(
                    'product' => $product,
                    'category' => $category,
                    'package' => (string) $bestRelease->package,
                    'md5' => (string) $bestRelease->md5,
                    'version' => (string) $bestRelease['version']
                );
            }
        }
        
        return null;
    }

    private function recursiveCopy($src, $dst) {
        $dir = opendir($src);
        if (!$dir) return false;
        @mkdir($dst, 0755, true);
        while (($file = readdir($dir)) !== false) {
            if ($file == '.' || $file == '..') continue;
            $srcPath = $src . '/' . $file;
            $dstPath = $dst . '/' . $file;
            if (is_dir($srcPath)) {
                if (!$this->recursiveCopy($srcPath, $dstPath)) { closedir($dir); return false; }
            } else {
                if (!copy($srcPath, $dstPath)) { closedir($dir); return false; }
            }
        }
        closedir($dir);
        return true;
    }

    private function recursiveDelete($dir) {
        if (!is_dir($dir)) return;
        $files = array_diff(scandir($dir), array('.', '..'));
        foreach ($files as $file) {
            $path = $dir . '/' . $file;
            is_dir($path) ? $this->recursiveDelete($path) : unlink($path);
        }
        rmdir($dir);
    }

    private function jsonResponse($status, $message, $product = null) {
        header('Content-Type: application/json');
        $response = array('status' => $status, 'message' => $message);
        if ($product) $response['product'] = $product;
        echo json_encode($response);
        exit;
    }

    public function setupTemplate($request) {
        AppLocale::requireComponents(LOCALE_COMPONENT_PKP_ADMIN);
        parent::setupTemplate($request);
    }
}
