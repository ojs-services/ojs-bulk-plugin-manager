<?php
/**
 * @file plugins/generic/bulkPluginManager/BulkPluginManagerHandler.inc.php
 *
 * @class BulkPluginManagerHandler
 * @brief Handler for bulk plugin update operations
 */

import('classes.handler.Handler');

class BulkPluginManagerHandler extends Handler
{

    public function __construct()
    {
        parent::__construct();
        $this->addRoleAssignment(
            array(ROLE_ID_SITE_ADMIN, ROLE_ID_MANAGER),
            array('index', 'getUpdatablePlugins', 'updatePlugin', 'getOjsServicesPlugins', 'installOjsServicesPlugin')
        );
    }

    public function authorize($request, &$args, $roleAssignments)
    {
        import('lib.pkp.classes.security.authorization.PolicySet');
        $rolePolicy = new PolicySet(COMBINING_PERMIT_OVERRIDES);
        import('lib.pkp.classes.security.authorization.PKPSiteAccessPolicy');
        $rolePolicy->addPolicy(new PKPSiteAccessPolicy($request, null, $roleAssignments));
        import('lib.pkp.classes.security.authorization.ContextAccessPolicy');
        $rolePolicy->addPolicy(new ContextAccessPolicy($request, $roleAssignments));
        $this->addPolicy($rolePolicy);
        return parent::authorize($request, $args, $roleAssignments);
    }

    /**
     * Cache duration in seconds (1 hour)
     */
    const CACHE_DURATION = 3600;

    /**
     * Whitelisted plugin categories for security
     */
    const ALLOWED_CATEGORIES = array(
        'generic',
        'themes',
        'gateways',
        'importexport',
        'reports',
        'blocks',
        'oaiMetadataFormats',
        'pubIds',
        'paymethod'
    );

    public function index($args, $request)
    {
        $this->setupTemplate($request);
        $templateMgr = TemplateManager::getManager($request);

        // Pass context info for sidebar
        $context = $request->getContext();
        $templateMgr->assign('currentContext', $context);

        // Sidebar: only show links for installed OJS Services plugins
        $sidebarPlugins = array();

        $certInfo = $this->getInstalledInfo('generic', 'certificatepro');
        if ($certInfo['filesExist']) {
            $sidebarPlugins[] = array(
                'page' => 'certificatepro',
                'op' => 'manageCertificates',
                'label' => 'Certificates Pro',
                'icon' => '📄'
            );
        }

        $submitAiInfo = $this->getInstalledInfo('generic', 'submitai');
        if ($submitAiInfo['filesExist']) {
            $sidebarPlugins[] = array(
                'page' => 'submitai-settings',
                'op' => '',
                'label' => 'SubmitAI',
                'icon' => '🤖'
            );
        }

        $templateMgr->assign('sidebarPlugins', $sidebarPlugins);

        $plugin = PluginRegistry::getPlugin('generic', 'bulkpluginmanagerplugin');
        return $templateMgr->display($plugin->getTemplateResource('index.tpl'));
    }

    /**
     * Get all plugins needing attention (AJAX)
     */
    public function getUpdatablePlugins($args, $request)
    {
        $refresh = $request->getUserVar('refresh') ? true : false;
        $result = $this->fetchAllPlugins($refresh);

        header('Content-Type: application/json');
        echo json_encode($result);
        exit;
    }

    /**
     * Check OJS version compatibility
     */
    private function isVersionCompatible($versionString)
    {
        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();
        $major = $currentVersion->getMajor();
        $minor = $currentVersion->getMinor();

        $parts = explode('.', $versionString);
        $galleryMajor = isset($parts[0]) ? (int) $parts[0] : 0;
        $galleryMinor = isset($parts[1]) ? (int) $parts[1] : 0;

        return ($galleryMajor == $major && $galleryMinor == $minor);
    }

    /**
     * Normalize version string to 4 parts (e.g., 0.7.8 -> 0.7.8.0)
     */
    private function normalizeVersion($version)
    {
        if (!$version || $version === '-')
            return null;
        $parts = explode('.', $version);
        while (count($parts) < 4) {
            $parts[] = '0';
        }
        return implode('.', array_slice($parts, 0, 4));
    }

    /**
     * Get installed plugin info - both DB and file versions
     */
    private function getInstalledInfo($category, $product)
    {
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
    private function fetchAllPlugins($forceRefresh = false)
    {
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

        // Fetch gallery with caching
        $cacheFile = sys_get_temp_dir() . '/ojs_plugins_xml_cache.xml';
        $xmlContent = '';

        if (!$forceRefresh && file_exists($cacheFile) && (time() - filemtime($cacheFile) < self::CACHE_DURATION)) {
            $xmlContent = file_get_contents($cacheFile);
            $debug['source'] = 'cache';
        } else {
            $client = Application::get()->getHttpClient();
            try {
                $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml');
                $xmlContent = (string) $response->getBody();
                file_put_contents($cacheFile, $xmlContent);
                $debug['source'] = 'network';
            } catch (Exception $e) {
                // If network fails, try cache even if expired
                if (file_exists($cacheFile)) {
                    $xmlContent = file_get_contents($cacheFile);
                    $debug['source'] = 'expired_cache';
                } else {
                    return array('status' => 'error', 'message' => 'Gallery fetch failed: ' . $e->getMessage());
                }
            }
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

            if (!$latestRelease)
                continue;

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
                    $pluginData['action'] = 'DB fix required';
                    $dbFix[] = $pluginData;
                    $debug['checked'][] = $product . ': DB FIX (DB:' . $info['dbVersion'] . ' > Gallery:' . $galleryVer . ', File:' . $info['fileVersion'] . ')';
                } else if ($cmpGalleryFile > 0) {
                    $pluginData['status'] = 'sync_update';
                    $pluginData['action'] = 'DB sync + update';
                    $syncIssue[] = $pluginData;
                    $debug['checked'][] = $product . ': SYNC+UPDATE (DB:' . $info['dbVersion'] . ' File:' . $info['fileVersion'] . ' -> ' . $galleryVer . ')';
                } else if ($cmpGalleryFile == 0) {
                    $pluginData['status'] = 'sync_only';
                    $pluginData['action'] = 'DB sync only';
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
        foreach ($updatable as $p)
            $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($missing as $p)
            $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($syncIssue as $p)
            $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($downgrade as $p)
            $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;
        foreach ($dbFix as $p)
            $checkedProducts[strtolower($p['category'] . '/' . $p['product'])] = true;

        foreach ($result as $row) {
            $productType = $row->product_type;
            $product = $row->product;
            $category = str_replace('plugins.', '', $productType);
            $key = strtolower($category . '/' . $product);

            if (isset($checkedProducts[$key]))
                continue;

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
        $sorter = function ($a, $b) {
            return strcasecmp($a['displayName'], $b['displayName']);
        };
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
            $filesExist = false;
            if (is_dir($categoryDir)) {
                $dirs = @scandir($categoryDir);
                if ($dirs) {
                    foreach ($dirs as $dir) {
                        if (strtolower($dir) === strtolower($product)) {
                            $actualDir = $categoryDir . '/' . $dir;
                            if (file_exists($actualDir . '/index.php') || file_exists($actualDir . '/version.xml')) {
                                $filesExist = true;
                            }
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
            if (!$filesExist) {
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
                'filesExist' => $filesExist,
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

        // Get Backups
        $backups = $this->getBackups();

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
            'backups' => $backups,
            'debug' => $debug
        );
    }

    /**
     * Update or install a plugin (AJAX)
     */
    public function updatePlugin($args, $request)
    {
        $product = $request->getUserVar('product');
        $category = $request->getUserVar('category');
        $action = $request->getUserVar('action'); // 'update', 'install', 'sync_update', 'sync_only', 'missing', 'dbfix', 'restore', 'delete_backup'
        $backupId = $request->getUserVar('backupId');

        if (!$product || !$category) {
            $this->jsonResponse('error', 'Missing parameters');
        }

        // Security: Path Traversal Check
        if (!in_array($category, self::ALLOWED_CATEGORIES)) {
            $this->jsonResponse('error', 'Invalid category: ' . $category);
        }
        if (preg_match('/[^a-zA-Z0-9_]/', $product)) {
            $this->jsonResponse('error', 'Invalid product name');
        }

        try {
            // Restore from ZIP Backup
            if ($action === 'restore') {
                if (!$backupId)
                    throw new Exception('Backup ID missing');
                // Sanitize backup ID (zip filename)
                if (preg_match('/[^a-zA-Z0-9_.]/', $backupId))
                    throw new Exception('Invalid backup ID');

                $backupZip = $this->getBackupDir() . '/' . $backupId;

                if (!file_exists($backupZip))
                    throw new Exception('Backup file not found');

                $pluginDir = Core::getBaseDir() . '/plugins/' . $category . '/' . $product;

                // 1. Safety backup of current version before restoring
                if (is_dir($pluginDir)) {
                    $safetyZip = $this->getBackupDir() . '/' . $category . '_' . $product . '_bak_auto_' . date('YmdHis') . '.zip';
                    $this->createZipBackup($pluginDir, $safetyZip);
                    $this->recursiveDelete($pluginDir);
                }

                // 2. Extract backup ZIP
                $zip = new ZipArchive();
                if ($zip->open($backupZip) !== true) {
                    // Restore safety backup if extraction fails
                    if (isset($safetyZip) && file_exists($safetyZip)) {
                        $sz = new ZipArchive();
                        if ($sz->open($safetyZip) === true) {
                            $sz->extractTo($pluginDir);
                            $sz->close();
                        }
                    }
                    throw new Exception('Restore failed: cannot open backup');
                }
                $zip->extractTo($pluginDir);
                $zip->close();

                // 3. Sync Database
                $versionFile = $pluginDir . '/version.xml';
                if (file_exists($versionFile)) {
                    $this->updateDatabaseVersion($versionFile, $category, $product);
                }

                $this->jsonResponse('success', 'Backup restored successfully', $product);
                return;
            }

            // Delete Backup ZIP
            if ($action === 'delete_backup') {
                if (!$backupId)
                    throw new Exception('Backup ID missing');
                if (preg_match('/[^a-zA-Z0-9_.]/', $backupId))
                    throw new Exception('Invalid backup ID');

                $backupFile = $this->getBackupDir() . '/' . $backupId;
                if (!file_exists($backupFile))
                    throw new Exception('Backup file not found');

                // Security: must be a .zip backup file
                if (strpos($backupId, '_bak_') === false || substr($backupId, -4) !== '.zip')
                    throw new Exception('Not a valid backup file');

                unlink($backupFile);
                $this->jsonResponse('success', 'Backup deleted', $product);
                return;
            }

            // Get current state
            $info = $this->getInstalledInfo($category, $product);

            // Handle DB fix action - sync DB to file version
            if ($action === 'dbfix') {
                if (!$info['fileVersion']) {
                    throw new Exception('File version not found');
                }
                $syncResult = $this->syncDatabaseVersion($category, $product, $info['fileVersion']);
                if (!$syncResult) {
                    throw new Exception('DB fix failed');
                }
                $this->jsonResponse('success', 'DB fixed: ' . $info['fileVersion'], $product);
                return;
            }

            // Handle DB clean action - remove DB entries for missing plugins
            if ($action === 'cleandb') {
                $versionDao = DAORegistry::getDAO('VersionDAO');

                $versionDao->update(
                    "DELETE FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)",
                    array('plugins.' . $category, $product)
                );

                $pluginName = strtolower($product . 'plugin');
                $versionDao->update(
                    "DELETE FROM plugin_settings WHERE LOWER(plugin_name) = LOWER(?)",
                    array($pluginName)
                );

                $this->jsonResponse('success', 'DB records cleaned', $product);
                return;
            }

            // Get gallery info first to compare versions
            $pluginInfo = $this->getGalleryPluginInfo($product, $category);

            // Safety check: If DB version > Gallery version, refuse to downgrade
            if ($info['dbVersion'] && $pluginInfo && $action !== 'sync_only') {
                $dbVer = $info['dbVersion'];
                $galleryVer = $pluginInfo['version'];

                if (version_compare($dbVer, $galleryVer, '>')) {
                    throw new Exception('DB version (' . $dbVer . ') > Gallery version (' . $galleryVer . '). Cannot downgrade. Fix DB sync first.');
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
                        $this->jsonResponse('success', 'Synced, no update needed', $product);
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
                    $this->jsonResponse('success', 'DB synced', $product);
                } else {
                    throw new Exception('File version not found');
                }
                return;
            }

            // Step 3: Verify we have gallery info
            if (!$pluginInfo) {
                throw new Exception('No compatible OJS 3.3 version found in Gallery');
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
    private function syncDatabaseVersion($category, $product, $targetVersion)
    {
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
            $major = isset($parts[0]) ? (int) $parts[0] : 1;
            $minor = isset($parts[1]) ? (int) $parts[1] : 0;
            $revision = isset($parts[2]) ? (int) $parts[2] : 0;
            $build = isset($parts[3]) ? (int) $parts[3] : 0;

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
    private function downloadAndInstall($category, $product, $packageUrl, $md5sum, $isNewInstall = false)
    {
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

            $extractSuccess = false;

            // Method 1: PharData (preferred)
            try {
                if (class_exists('PharData')) {
                    $phar = new PharData($packageFile);
                    $phar->extractTo($extractDir);
                    $extractSuccess = true;
                }
            } catch (Exception $e) {
                error_log('PharData extract failed: ' . $e->getMessage());
            }

            // Method 2: System tar command (fallback)
            if (!$extractSuccess) {
                $output = array();
                $returnCode = 0;
                // Check if tar command exists
                exec('tar --version', $output, $returnCode);
                if ($returnCode === 0) {
                    exec("tar -xzf " . escapeshellarg($packageFile) . " -C " . escapeshellarg($extractDir), $output, $returnCode);
                    if ($returnCode === 0) {
                        $extractSuccess = true;
                    } else {
                        error_log('tar command failed: ' . implode("\n", $output));
                    }
                }
            }

            if (!$extractSuccess) {
                throw new Exception('Extraction failed (tried PharData and tar command)');
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

            // Backup existing plugin as ZIP before overwriting
            if (is_dir($pluginDestDir)) {
                $backupDir = $this->getBackupDir();
                $zipFile = $backupDir . '/' . $category . '_' . $product . '_bak_' . date('YmdHis') . '.zip';
                if (!$this->createZipBackup($pluginDestDir, $zipFile)) {
                    throw new Exception('Backup failed');
                }
                $this->recursiveDelete($pluginDestDir);
            }

            // Copy files
            if (!$this->recursiveCopy($pluginSourceDir, $pluginDestDir)) {
                throw new Exception('File copy failed');
            }

            // Update database version
            $versionFile = $pluginDestDir . '/version.xml';
            if (!$this->updateDatabaseVersion($versionFile, $category, $product)) {
                // Don't fail, just log
                error_log('Warning: Could not update version in database for ' . $product);
            }

            // Cleanup temp
            $this->recursiveDelete($tempDir);

            return true;

        } catch (Exception $e) {
            $this->recursiveDelete($tempDir);
            return $e->getMessage();
        }
    }

    private function findPluginDir($extractDir, $product)
    {
        if (is_dir($extractDir . '/' . $product)) {
            return $extractDir . '/' . $product;
        }

        $dirs = glob($extractDir . '/*', GLOB_ONLYDIR);
        foreach ($dirs as $dir) {
            if (basename($dir) === $product)
                return $dir;
            if (file_exists($dir . '/version.xml'))
                return $dir;
            if (is_dir($dir . '/' . $product))
                return $dir . '/' . $product;

            $subDirs = glob($dir . '/*', GLOB_ONLYDIR);
            foreach ($subDirs as $subDir) {
                if (basename($subDir) === $product)
                    return $subDir;
                if (file_exists($subDir . '/version.xml'))
                    return $subDir;
            }
        }

        return null;
    }

    /**
     * Get backup storage directory (inside OJS files_dir, isolated from plugins)
     */
    private function getBackupDir()
    {
        $dir = Config::getVar('files', 'files_dir') . '/bulkPluginManager_backups';
        if (!is_dir($dir)) {
            mkdir($dir, 0755, true);
        }
        return $dir;
    }

    /**
     * Create a ZIP backup of a plugin directory
     */
    private function createZipBackup($sourceDir, $zipPath)
    {
        $zip = new ZipArchive();
        if ($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true) {
            return false;
        }

        $sourceDir = realpath($sourceDir);
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($sourceDir, RecursiveDirectoryIterator::SKIP_DOTS),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($iterator as $file) {
            $filePath = $file->getRealPath();
            $relativePath = substr($filePath, strlen($sourceDir) + 1);

            if ($file->isDir()) {
                $zip->addEmptyDir($relativePath);
            } else {
                $zip->addFile($filePath, $relativePath);
            }
        }

        return $zip->close();
    }

    /**
     * Read version from version.xml inside a ZIP backup
     */
    private function getVersionFromZip($zipPath)
    {
        $zip = new ZipArchive();
        if ($zip->open($zipPath) !== true) {
            return '-';
        }

        $content = $zip->getFromName('version.xml');
        $zip->close();

        if (!$content) {
            return '-';
        }

        $cleanXml = preg_replace('/<!DOCTYPE[^>]*>/', '', $content);
        $xml = @simplexml_load_string($cleanXml);
        if ($xml && isset($xml->release)) {
            return (string) $xml->release;
        }

        return '-';
    }

    /**
     * Scan for ZIP backups
     */
    private function getBackups()
    {
        $backups = array();
        $backupDir = $this->getBackupDir();

        $files = @scandir($backupDir);
        if (!$files) return $backups;

        foreach ($files as $file) {
            if (substr($file, -4) !== '.zip' || strpos($file, '_bak_') === false) {
                continue;
            }

            // Format: {category}_{product}_bak_{YYYYMMDDHHMMSS}.zip
            $basename = substr($file, 0, -4); // strip .zip
            $parts = explode('_bak_', $basename);
            if (count($parts) < 2) continue;

            $dateStr = $parts[1]; // may include 'auto_' prefix
            $catProduct = $parts[0];

            // Split category and product: first segment is category
            $firstUnderscore = strpos($catProduct, '_');
            if ($firstUnderscore === false) continue;

            $category = substr($catProduct, 0, $firstUnderscore);
            $product = substr($catProduct, $firstUnderscore + 1);

            if (!$category || !$product) continue;

            // Format date for display (strip 'auto_' prefix if present)
            $cleanDate = str_replace('auto_', '', $dateStr);
            $dateDisplay = $cleanDate;
            if (strlen($cleanDate) == 14) {
                $dateDisplay = substr($cleanDate, 0, 4) . '-' . substr($cleanDate, 4, 2) . '-' . substr($cleanDate, 6, 2) . ' ' .
                    substr($cleanDate, 8, 2) . ':' . substr($cleanDate, 10, 2) . ':' . substr($cleanDate, 12, 2);
            }

            // Read version from ZIP
            $version = $this->getVersionFromZip($backupDir . '/' . $file);

            $backups[] = array(
                'id' => $file,
                'product' => $product,
                'category' => $category,
                'date' => $dateDisplay,
                'version' => $version,
                'path' => $backupDir . '/' . $file
            );
        }

        // Sort by date desc
        usort($backups, function ($a, $b) {
            return strcmp($b['date'], $a['date']);
        });

        return $backups;
    }

    private function updateDatabaseVersion($versionFile, $category, $product)
    {
        import('lib.pkp.classes.site.VersionCheck');
        $versionInfo = VersionCheck::parseVersionXML($versionFile);
        if (!$versionInfo)
            return false;

        $versionDao = DAORegistry::getDAO('VersionDAO');
        $version = $versionInfo['version'];
        $version->setProductType('plugins.' . $category);
        $version->setProduct($product);
        $version->setCurrent(1);

        $versionDao->disableVersion('plugins.' . $category, $product);
        $versionDao->insertVersion($version, true);

        return true;
    }

    private function getGalleryPluginInfo($product, $category)
    {
        $client = Application::get()->getHttpClient();
        try {
            $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml');
            $xml = @simplexml_load_string((string) $response->getBody());
        } catch (Exception $e) {
            return null;
        }

        if (!$xml)
            return null;

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

    private function recursiveCopy($src, $dst)
    {
        $dir = opendir($src);
        if (!$dir)
            return false;
        @mkdir($dst, 0755, true);
        while (($file = readdir($dir)) !== false) {
            if ($file == '.' || $file == '..')
                continue;
            $srcPath = $src . '/' . $file;
            $dstPath = $dst . '/' . $file;
            if (is_dir($srcPath)) {
                if (!$this->recursiveCopy($srcPath, $dstPath)) {
                    closedir($dir);
                    return false;
                }
            } else {
                if (!copy($srcPath, $dstPath)) {
                    closedir($dir);
                    return false;
                }
            }
        }
        closedir($dir);
        return true;
    }

    private function recursiveDelete($dir)
    {
        if (!is_dir($dir))
            return;
        $files = array_diff(scandir($dir), array('.', '..'));
        foreach ($files as $file) {
            $path = $dir . '/' . $file;
            is_dir($path) ? $this->recursiveDelete($path) : unlink($path);
        }
        rmdir($dir);
    }

    /**
     * Repos in ojs-services org to exclude from plugin discovery
     */
    const OJS_SERVICES_EXCLUDED_REPOS = array(
        'ojs-bulk-plugin-manager'
    );

    /**
     * GitHub API cache duration (1 hour)
     */
    const GITHUB_CACHE_DURATION = 3600;

    /**
     * Fetch list of repos from ojs-services GitHub organization (cached)
     */
    private function fetchOrgRepos($forceRefresh = false)
    {
        $cacheFile = sys_get_temp_dir() . '/ojs_services_org_repos.json';

        if (!$forceRefresh && file_exists($cacheFile) && (time() - filemtime($cacheFile) < self::GITHUB_CACHE_DURATION)) {
            $cached = json_decode(file_get_contents($cacheFile), true);
            if ($cached !== null) {
                return $cached;
            }
        }

        $client = Application::get()->getHttpClient();
        $allRepos = array();
        $page = 1;

        do {
            $url = 'https://api.github.com/orgs/ojs-services/repos?per_page=100&page=' . $page;
            try {
                $response = $client->request('GET', $url, [
                    'timeout' => 20,
                    'headers' => [
                        'Accept' => 'application/vnd.github.v3+json',
                        'User-Agent' => 'OJS-BulkPluginManager/1.10'
                    ]
                ]);
                $repos = json_decode((string)$response->getBody(), true);
                if (!is_array($repos) || empty($repos)) {
                    break;
                }
                $allRepos = array_merge($allRepos, $repos);
                $page++;
            } catch (Exception $e) {
                // On failure, try expired cache
                if (file_exists($cacheFile)) {
                    $cached = json_decode(file_get_contents($cacheFile), true);
                    return $cached ?: array();
                }
                return array();
            }
        } while (count($repos) === 100);

        $result = array();
        foreach ($allRepos as $repo) {
            $repoName = $repo['name'];

            // Skip excluded repos
            if (in_array($repoName, self::OJS_SERVICES_EXCLUDED_REPOS)) {
                continue;
            }

            // Skip archived/disabled repos
            if (!empty($repo['archived']) || !empty($repo['disabled'])) {
                continue;
            }

            $result[] = array(
                'name' => $repoName,
                'description' => $repo['description'] ?: '',
                'default_branch' => $repo['default_branch'] ?: 'main'
            );
        }

        file_put_contents($cacheFile, json_encode($result));
        return $result;
    }

    /**
     * Get OJS Services plugins list (AJAX)
     */
    public function getOjsServicesPlugins($args, $request)
    {
        $refresh = $request->getUserVar('refresh') ? true : false;
        $result = $this->fetchOjsServicesPlugins($refresh);

        header('Content-Type: application/json');
        echo json_encode($result);
        exit;
    }

    /**
     * Fetch OJS Services plugins with version info (dynamic GitHub discovery)
     */
    private function fetchOjsServicesPlugins($forceRefresh = false)
    {
        $plugins = array();
        $client = Application::get()->getHttpClient();

        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();
        $ojsVersion = $currentVersion->getVersionString();

        // Phase 1: Get repo list dynamically from GitHub org
        $repos = $this->fetchOrgRepos($forceRefresh);
        if (empty($repos)) {
            return array(
                'status' => 'error',
                'message' => 'Could not fetch organization repositories',
                'plugins' => array(),
                'ojsVersion' => $ojsVersion
            );
        }

        foreach ($repos as $repoInfo) {
            $repo = $repoInfo['name'];
            $branch = $repoInfo['default_branch'];
            $githubDescription = $repoInfo['description'];

            // Cache key uses sanitized repo name
            $safeName = preg_replace('/[^a-zA-Z0-9_-]/', '_', $repo);

            // Get version.xml from GitHub (with caching)
            $cacheFile = sys_get_temp_dir() . '/ojs_services_' . $safeName . '_version.xml';
            $versionXmlContent = '';

            if (!$forceRefresh && file_exists($cacheFile) && (time() - filemtime($cacheFile) < self::GITHUB_CACHE_DURATION)) {
                $versionXmlContent = file_get_contents($cacheFile);
            } else {
                $rawUrl = 'https://raw.githubusercontent.com/ojs-services/' . $repo . '/' . $branch . '/version.xml';
                try {
                    $response = $client->request('GET', $rawUrl, ['timeout' => 15]);
                    $versionXmlContent = (string)$response->getBody();
                    file_put_contents($cacheFile, $versionXmlContent);
                } catch (Exception $e) {
                    // version.xml not found = not an OJS plugin, skip silently
                    if (file_exists($cacheFile)) {
                        $versionXmlContent = file_get_contents($cacheFile);
                    } else {
                        continue; // Skip this repo entirely
                    }
                }
            }

            if (!$versionXmlContent) {
                continue; // Not a plugin repo
            }

            // Parse version.xml
            $cleanXml = preg_replace('/<!DOCTYPE[^>]*>/', '', $versionXmlContent);
            $vxml = @simplexml_load_string($cleanXml);
            if (!$vxml || !isset($vxml->application)) {
                continue; // Invalid version.xml, skip
            }

            // Extract product name from version.xml
            $product = (string)$vxml->application;

            // Skip bulkPluginManager itself (safety check)
            if ($product === 'bulkPluginManager') continue;

            // Extract category from <type> (e.g., "plugins.generic" → "generic")
            $category = 'generic';
            if (isset($vxml->type)) {
                $typeParts = explode('.', (string)$vxml->type);
                if (count($typeParts) >= 2) {
                    $category = $typeParts[1];
                }
            }

            // Generate displayName from camelCase product name
            $displayName = preg_replace('/([a-z])([A-Z])/', '$1 $2', $product);
            $displayName = ucwords($displayName);

            $pluginData = array(
                'product' => $product,
                'repo' => $repo,
                'category' => $category,
                'displayName' => $displayName,
                'description' => $githubDescription ?: $displayName,
                'repoVersion' => null,
                'installedVersion' => null,
                'filesExist' => false,
                'compatible' => false,
                'status' => 'available',
                'downloadUrl' => null,
                'repoUrl' => 'https://github.com/ojs-services/' . $repo
            );

            // Parse version and compatibility from version.xml
            $pluginData['repoVersion'] = isset($vxml->release) ? (string)$vxml->release : null;

            if (isset($vxml->compatibility)) {
                foreach ($vxml->compatibility as $compat) {
                    $app = (string)$compat['application'];
                    if ($app === 'ojs2' || $app === 'ojs') {
                        foreach ($compat->version as $ver) {
                            if ($this->isVersionCompatible((string)$ver)) {
                                $pluginData['compatible'] = true;
                                break 2;
                            }
                        }
                    }
                }
            } else {
                // OJS Services plugins without compatibility block
                // are assumed compatible (all built for OJS 3.3.x)
                $pluginData['compatible'] = true;
            }

            // Get latest release download URL (with caching)
            $releaseCacheFile = sys_get_temp_dir() . '/ojs_services_' . $safeName . '_release.json';
            $releaseData = null;

            if (!$forceRefresh && file_exists($releaseCacheFile) && (time() - filemtime($releaseCacheFile) < self::GITHUB_CACHE_DURATION)) {
                $releaseData = json_decode(file_get_contents($releaseCacheFile), true);
            } else {
                $releaseUrl = 'https://api.github.com/repos/ojs-services/' . $repo . '/releases/latest';
                try {
                    $response = $client->request('GET', $releaseUrl, [
                        'timeout' => 15,
                        'headers' => ['Accept' => 'application/vnd.github.v3+json', 'User-Agent' => 'OJS-BulkPluginManager/1.10']
                    ]);
                    $releaseData = json_decode((string)$response->getBody(), true);
                    file_put_contents($releaseCacheFile, json_encode($releaseData));
                } catch (Exception $e) {
                    if (file_exists($releaseCacheFile)) {
                        $releaseData = json_decode(file_get_contents($releaseCacheFile), true);
                    }
                }
            }

            if ($releaseData && isset($releaseData['assets']) && count($releaseData['assets']) > 0) {
                foreach ($releaseData['assets'] as $asset) {
                    if (strpos($asset['name'], '.tar.gz') !== false) {
                        $pluginData['downloadUrl'] = $asset['browser_download_url'];
                        break;
                    }
                }
            }

            // Fallback: use GitHub archive URL if no release asset
            if (!$pluginData['downloadUrl'] && $releaseData && isset($releaseData['tag_name'])) {
                $pluginData['downloadUrl'] = 'https://api.github.com/repos/ojs-services/' . $repo . '/tarball/' . $releaseData['tag_name'];
            }

            // Check if installed locally
            $info = $this->getInstalledInfo($category, $product);
            $pluginData['filesExist'] = $info['filesExist'];
            if ($info['fileVersion']) {
                $pluginData['installedVersion'] = $info['fileVersion'];
            } elseif ($info['dbVersion']) {
                $pluginData['installedVersion'] = $info['dbVersion'];
            }

            // Determine status
            if (!$pluginData['compatible']) {
                $pluginData['status'] = 'incompatible';
            } elseif ($pluginData['filesExist'] && $pluginData['installedVersion']) {
                if ($pluginData['repoVersion'] && version_compare($pluginData['repoVersion'], $pluginData['installedVersion'], '>')) {
                    $pluginData['status'] = 'update';
                } else {
                    $pluginData['status'] = 'installed';
                }
            } else {
                $pluginData['status'] = 'available';
            }

            $plugins[] = $pluginData;
        }

        return array(
            'status' => 'success',
            'plugins' => $plugins,
            'ojsVersion' => $ojsVersion
        );
    }

    /**
     * Install/update a plugin from OJS Services GitHub (AJAX)
     */
    public function installOjsServicesPlugin($args, $request)
    {
        $product = $request->getUserVar('product');
        $downloadUrl = $request->getUserVar('downloadUrl');
        $action = $request->getUserVar('action'); // 'install' or 'update'
        $category = $request->getUserVar('category') ?: 'generic';

        if (!$product || !$downloadUrl) {
            $this->jsonResponse('error', 'Missing parameters');
        }

        // Security: validate product name
        if (preg_match('/[^a-zA-Z0-9_]/', $product)) {
            $this->jsonResponse('error', 'Invalid product name');
        }

        // Security: validate category
        if (!in_array($category, self::ALLOWED_CATEGORIES)) {
            $this->jsonResponse('error', 'Invalid category');
        }

        // Security: validate download URL is from GitHub ojs-services
        if (strpos($downloadUrl, 'github.com/ojs-services/') === false &&
            strpos($downloadUrl, 'api.github.com/repos/ojs-services/') === false) {
            $this->jsonResponse('error', 'Invalid download URL: must be from ojs-services GitHub');
        }

        try {
            $result = $this->downloadAndInstall($category, $product, $downloadUrl, '', $action === 'install');
            if ($result !== true) {
                throw new Exception($result);
            }
            $this->jsonResponse('success', 'OK', $product);
        } catch (Exception $e) {
            $this->jsonResponse('error', $e->getMessage(), $product);
        }
    }

    private function jsonResponse($status, $message, $product = null)
    {
        header('Content-Type: application/json');
        $response = array('status' => $status, 'message' => $message);
        if ($product)
            $response['product'] = $product;
        echo json_encode($response);
        exit;
    }

    public function setupTemplate($request)
    {
        AppLocale::requireComponents(LOCALE_COMPONENT_PKP_ADMIN);
        parent::setupTemplate($request);
    }
}
