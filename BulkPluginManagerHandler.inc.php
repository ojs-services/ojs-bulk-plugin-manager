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
        // Render inside OJS's standard backend layout (backend.tpl) so the real
        // OJS navigation menu is used instead of a hand-built replica.
        $this->_isBackendPage = true;
        // Site admins AND journal managers may use the tool. Letting a journal
        // manager (editor) manage plugins without needing a site-admin account is
        // the plugin's core purpose. Plugin FILES are inherently site-wide in OJS,
        // but ENABLING a plugin is per-journal (plugin_settings.context_id), so a
        // manager installing a plugin does not activate it in other journals.
        // Requests are still CSRF-protected (see requireCSRF).
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
        // setupTemplate() triggers setupBackendPage() (via $_isBackendPage), which
        // builds OJS's real navigation menu — no custom sidebar reconstruction needed.
        $this->setupTemplate($request);
        $templateMgr = TemplateManager::getManager($request);

        $plugin = PluginRegistry::getPlugin('generic', 'bulkpluginmanagerplugin');

        // Load the stylesheet in the <head> (backend context) so it applies before
        // first paint. Linking it from the page body caused a brief unstyled/narrow
        // flash before the styles kicked in.
        $templateMgr->addStyleSheet(
            'bulkPluginManagerCss',
            $request->getBaseUrl() . '/' . $plugin->getPluginPath() . '/css/bulkPluginManager.css',
            array('contexts' => 'backend', 'priority' => STYLE_SEQUENCE_LAST)
        );

        $templateMgr->assign(array(
            'pageTitle' => __('plugins.generic.bulkPluginManager.displayName'),
            'pageWidth' => 'full',
            // CSRF token for AJAX POST requests
            'csrfToken' => $request->getSession()->getCSRFToken(),
        ));

        return $templateMgr->display($plugin->getTemplateResource('index.tpl'));
    }

    /**
     * Verify the CSRF token on a state-changing request; abort with a JSON error if invalid.
     */
    private function requireCSRF($request)
    {
        if (!$request->checkCSRF()) {
            $this->jsonResponse('error', 'Invalid or missing CSRF token. Please reload the page and try again.');
        }
    }

    /**
     * Safely parse an XML string from an untrusted remote source.
     * Disables network access and (on PHP < 8) external entity loading to block XXE.
     * @return SimpleXMLElement|false
     */
    private function parseXmlSafe($xmlContent)
    {
        if (!is_string($xmlContent) || $xmlContent === '') {
            return false;
        }
        // libxml_disable_entity_loader is deprecated/removed in PHP 8 where external
        // entity loading is already off by default; guard the call for older runtimes.
        if (PHP_VERSION_ID < 80000 && function_exists('libxml_disable_entity_loader')) {
            $previous = libxml_disable_entity_loader(true);
        }
        $xml = @simplexml_load_string($xmlContent, 'SimpleXMLElement', LIBXML_NONET);
        if (isset($previous)) {
            libxml_disable_entity_loader($previous);
        }
        return $xml;
    }

    /**
     * Guard against Zip Slip: reject any archive entry whose path would escape the
     * extraction directory (contains "..", is absolute, or has a null byte).
     * @param $names array list of entry names inside the archive
     * @throws Exception on the first unsafe entry
     */
    private function assertSafeArchive($names)
    {
        foreach ($names as $name) {
            $normalized = str_replace('\\', '/', (string) $name);
            if (strpos($normalized, "\0") !== false) {
                throw new Exception('Unsafe archive entry (null byte): ' . $name);
            }
            // Absolute paths (unix "/..." or Windows "C:...")
            if ($normalized === '' || $normalized[0] === '/' || preg_match('#^[A-Za-z]:#', $normalized)) {
                throw new Exception('Unsafe archive entry (absolute path): ' . $name);
            }
            // Any ".." path segment
            foreach (explode('/', $normalized) as $segment) {
                if ($segment === '..') {
                    throw new Exception('Unsafe archive entry (path traversal): ' . $name);
                }
            }
        }
    }

    /**
     * Collect all entry names from an open ZipArchive for validation.
     */
    private function zipEntryNames($zip)
    {
        $names = array();
        for ($i = 0; $i < $zip->numFiles; $i++) {
            $names[] = $zip->getNameIndex($i);
        }
        return $names;
    }

    /**
     * Get all plugins needing attention (AJAX)
     */
    public function getUpdatablePlugins($args, $request)
    {
        ob_start(); // swallow any stray warnings/notices so they can't corrupt the JSON
        $refresh = $request->getUserVar('refresh') ? true : false;
        $result = $this->fetchAllPlugins($refresh);

        $this->sendJson($result);
    }

    /**
     * Check OJS version compatibility
     */
    private function isVersionCompatible($versionString)
    {
        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();

        // Delegate to OJS's own compatibility check (Composer Semver under the
        // hood) — exactly what the core plugin gallery / "plugin updates" list
        // uses. This understands range syntax such as "~3.3.0.18" (>= 3.3.0.18
        // within the 3.3.0 line) used by newer releases. The previous string
        // parsing cast "~3" to 0, so any release whose only 3.3 statement used
        // the tilde form looked incompatible — which made the tool pick an older
        // release (e.g. iThenticate 1.0.6.1 instead of 1.3.0.2) and disagree with
        // OJS's own update list.
        if (method_exists($currentVersion, 'isCompatible')) {
            try {
                return (bool) $currentVersion->isCompatible((string) $versionString);
            } catch (Exception $e) {
                // Unparseable constraint — fall through to the lenient check below.
            }
        }

        // Fallback (older cores / unparseable constraint): strip a leading range
        // operator and match on major.minor only.
        $clean = ltrim((string) $versionString, "~^<>= \t");
        $parts = explode('.', $clean);
        $galleryMajor = isset($parts[0]) ? (int) $parts[0] : 0;
        $galleryMinor = isset($parts[1]) ? (int) $parts[1] : 0;
        return ($galleryMajor == $currentVersion->getMajor() && $galleryMinor == $currentVersion->getMinor());
    }

    /**
     * Pick the newest PKP Gallery release compatible with the running OJS.
     *
     * plugins.xml structure (compatibility is declared as CHILD <version>
     * elements — there is no version attribute, and <release> has no
     * application attribute):
     *
     *   <release version="1.2.0.0" ...>
     *     <compatibility application="ojs2">
     *       <version>3.3.0.0</version> ...
     *     </compatibility>
     *   </release>
     *
     * Single source of truth for all three gallery lookups.
     * @return SimpleXMLElement|null the chosen <release>, or null if none match
     */
    private function pickCompatibleGalleryRelease($plugin)
    {
        $best = null;
        $bestVersion = '0.0.0.0';

        foreach ($plugin->release as $release) {
            $compatible = false;
            foreach ($release->compatibility as $compat) {
                if ((string) $compat['application'] !== 'ojs2') {
                    continue;
                }
                foreach ($compat->version as $ver) {
                    if ($this->isVersionCompatible((string) $ver)) {
                        $compatible = true;
                        break 2;
                    }
                }
            }
            if (!$compatible) {
                continue;
            }
            $relVer = (string) $release['version'];
            if (version_compare($relVer, $bestVersion, '>')) {
                $bestVersion = $relVer;
                $best = $release;
            }
        }

        return $best;
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
     * Probe a plugin's files with a THREE-state result, so a destructive DB
     * clean can never be triggered by a filesystem read failure.
     *
     *   readable + present  => ['status'=>'readable','exists'=>true,'path'=>...]
     *   readable + absent   => ['status'=>'readable','exists'=>false,'path'=>null]
     *   unreadable/unknown  => ['status'=>'unreadable','reason'=>...]
     *
     * Unlike getInstalledInfo() (which suppresses errors and treats any failure
     * as "no files"), this never swallows read errors — a permissions/IO failure
     * must surface as 'unreadable', not be mistaken for "the plugin is gone".
     */
    private function probePluginFiles($category, $product)
    {
        // The plugins/ root must be readable for any conclusion to be trustworthy.
        $pluginsRoot = Core::getBaseDir() . '/plugins';
        if (!is_dir($pluginsRoot) || !is_readable($pluginsRoot)) {
            return array('status' => 'unreadable', 'reason' => 'plugins directory not readable');
        }

        $categoryDir = $pluginsRoot . '/' . $category;

        if (!is_dir($categoryDir)) {
            // The category folder does not exist under a readable plugins/ root, so
            // the plugin — often its whole legacy OJS 2 category (citationLookup,
            // citationOutput, metadata…) — is genuinely gone. Safe to clean.
            return array('status' => 'readable', 'exists' => false, 'path' => null);
        }
        if (!is_readable($categoryDir)) {
            return array('status' => 'unreadable', 'reason' => 'category directory not readable (permissions): ' . $category);
        }

        $dirs = scandir($categoryDir); // no '@' — a read failure must surface, not be swallowed
        if ($dirs === false) {
            return array('status' => 'unreadable', 'reason' => 'scandir failed on plugins/' . $category);
        }

        foreach ($dirs as $dir) {
            if (strtolower($dir) === strtolower($product)) {
                $path = $categoryDir . '/' . $dir;
                if (!is_readable($path)) {
                    // The directory exists but we cannot read it — do NOT report "absent".
                    return array('status' => 'unreadable', 'reason' => 'plugin directory not readable (permissions): ' . $product);
                }
                $entries = scandir($path);
                $hasFiles = file_exists($path . '/version.xml')
                    || file_exists($path . '/index.php')
                    || ($entries !== false && count(array_diff($entries, array('.', '..'))) > 0);
                return array('status' => 'readable', 'exists' => $hasFiles, 'path' => $path);
            }
        }

        // Directory listing succeeded and the plugin folder is genuinely not there.
        return array('status' => 'readable', 'exists' => false, 'path' => null);
    }

    /**
     * Dump the versions + plugin_settings rows for a plugin to a restorable .sql
     * file before a DB clean, so a mistaken removal can be reverted by hand.
     * @return string absolute path of the backup file
     */
    private function backupPluginDbRows($category, $product, $pluginName)
    {
        $versionDao = DAORegistry::getDAO('VersionDAO');
        $lines = array(
            '-- Bulk Plugin Manager DB backup',
            '-- product: plugins.' . $category . ' / ' . $product,
            '-- plugin_name: ' . $pluginName,
            '',
        );

        $vres = $versionDao->retrieve(
            "SELECT * FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)",
            array('plugins.' . $category, $product)
        );
        foreach ($vres as $row) {
            $lines[] = $this->buildInsertStatement('versions', (array) $row);
        }

        $sres = $versionDao->retrieve(
            "SELECT * FROM plugin_settings WHERE LOWER(plugin_name) = LOWER(?)",
            array($pluginName)
        );
        foreach ($sres as $row) {
            $lines[] = $this->buildInsertStatement('plugin_settings', (array) $row);
        }

        $safeProduct = preg_replace('/[^a-zA-Z0-9_]/', '_', $product);
        $file = $this->getBackupDir() . '/db_' . $safeProduct . '_' . date('YmdHis') . '.sql';
        file_put_contents($file, implode("\n", $lines) . "\n");
        return $file;
    }

    /**
     * Build a single INSERT statement from an associative row (values escaped).
     */
    private function buildInsertStatement($table, $row)
    {
        $cols = array();
        $vals = array();
        foreach ($row as $col => $value) {
            $cols[] = '`' . $col . '`';
            if ($value === null) {
                $vals[] = 'NULL';
            } else {
                $vals[] = "'" . str_replace(array('\\', "'"), array('\\\\', "\\'"), (string) $value) . "'";
            }
        }
        return 'INSERT INTO `' . $table . '` (' . implode(', ', $cols) . ') VALUES (' . implode(', ', $vals) . ');';
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
            // Guard against a concurrent cache write/delete between the check above and the read.
            $cached = @file_get_contents($cacheFile);
            $xmlContent = ($cached === false) ? '' : $cached;
            $debug['source'] = 'cache';
        }
        if ($xmlContent === '') {
            $client = Application::get()->getHttpClient();
            try {
                $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml', ['timeout' => 30, 'connect_timeout' => 10]);
                $xmlContent = (string) $response->getBody();
                file_put_contents($cacheFile, $xmlContent);
                $debug['source'] = 'network';
            } catch (Exception $e) {
                // If network fails, try cache even if expired
                error_log('BulkPluginManager: PKP gallery fetch failed: ' . $e->getMessage());
                if (file_exists($cacheFile)) {
                    $xmlContent = file_get_contents($cacheFile);
                    $debug['source'] = 'expired_cache';
                } else {
                    return array('status' => 'error', 'message' => 'Gallery fetch failed: ' . $e->getMessage());
                }
            }
        }

        $xml = $this->parseXmlSafe($xmlContent);
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

            // Find latest compatible release (shared helper — see pickCompatibleGalleryRelease)
            $latestRelease = $this->pickCompatibleGalleryRelease($plugin);

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

            // Find latest compatible release (shared helper)
            $latestRelease = $this->pickCompatibleGalleryRelease($plugin);

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
        ob_start(); // swallow any stray warnings/notices so they can't corrupt the JSON
        $this->requireCSRF($request);

        $product = $request->getUserVar('product');
        $category = $request->getUserVar('category');
        $action = $request->getUserVar('action'); // 'update', 'install', 'sync_update', 'sync_only', 'missing', 'dbfix', 'restore', 'delete_backup'
        $backupId = $request->getUserVar('backupId');

        if (!$product || !$category) {
            $this->jsonResponse('error', 'Missing parameters');
        }

        // Security: category and product must be safe path segments (no traversal).
        if (preg_match('/[^a-zA-Z0-9_]/', $category)) {
            $this->jsonResponse('error', 'Invalid category: ' . $category);
        }
        if (preg_match('/[^a-zA-Z0-9_]/', $product)) {
            $this->jsonResponse('error', 'Invalid product name');
        }
        // Actions that download and write plugin files must target a known OJS 3
        // category. DB-only actions (dbfix / cleandb / sync_only) may operate on
        // legacy categories (e.g. citationLookup / citationOutput left over from an
        // OJS 2 upgrade) whose orphaned rows still linger in the versions table.
        $fileDownloadActions = array('install', 'update', 'missing', 'sync_update');
        if (in_array($action, $fileDownloadActions) && !in_array($category, self::ALLOWED_CATEGORIES)) {
            $this->jsonResponse('error', 'Invalid category: ' . $category);
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
                            $this->assertSafeArchive($this->zipEntryNames($sz));
                            $sz->extractTo($pluginDir);
                            $sz->close();
                        }
                    }
                    throw new Exception('Restore failed: cannot open backup');
                }
                $this->assertSafeArchive($this->zipEntryNames($zip));
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

            // Handle DB clean action - remove DB entries for genuinely orphaned plugins.
            if ($action === 'cleandb') {
                // Destructive-op precondition: NEVER delete DB records unless we can
                // prove the plugin's files are truly gone. A filesystem read failure
                // (permissions, open_basedir, I/O) must not be mistaken for "removed".
                // Deleting the versions row of a plugin whose files are still present
                // makes OJS re-run its install schema, which wipes the plugin's OWN
                // tables (e.g. a slider plugin's slides) — that is real data loss.
                $probe = $this->probePluginFiles($category, $product);
                if ($probe['status'] !== 'readable') {
                    throw new Exception(
                        'Filesystem could not be verified (' . $probe['reason'] . '). '
                        . 'No records were removed. Check the plugin directory permissions and try again.'
                    );
                }
                if (!empty($probe['exists'])) {
                    throw new Exception(
                        'Plugin files are still present. Refusing to delete the database records of an '
                        . 'installed plugin — this could make OJS reinstall it and wipe its own data.'
                    );
                }

                $versionDao = DAORegistry::getDAO('VersionDAO');
                $pluginName = strtolower($product . 'plugin');

                // Save a restorable backup of the affected rows before deleting anything.
                $backupFile = $this->backupPluginDbRows($category, $product, $pluginName);

                $versionDao->update(
                    "DELETE FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)",
                    array('plugins.' . $category, $product)
                );
                $versionDao->update(
                    "DELETE FROM plugin_settings WHERE LOWER(plugin_name) = LOWER(?)",
                    array($pluginName)
                );

                $this->jsonResponse('success', 'Orphaned DB records removed (backup: ' . basename($backupFile) . ')', $product);
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
                    // Zip Slip guard: validate every entry path before extracting.
                    $names = array();
                    $iterator = new RecursiveIteratorIterator($phar, RecursiveIteratorIterator::SELF_FIRST);
                    foreach ($iterator as $item) {
                        $names[] = $iterator->getSubPathName();
                    }
                    $this->assertSafeArchive($names);
                    $phar->extractTo($extractDir);
                    $extractSuccess = true;
                }
            } catch (Exception $e) {
                error_log('PharData extract failed: ' . $e->getMessage());
                // If the failure was our own safety check, do not silently fall through
                // to tar — abort so an unsafe archive is never extracted.
                if (strpos($e->getMessage(), 'Unsafe archive entry') !== false) {
                    throw $e;
                }
            }

            // Method 2: System tar command (fallback)
            if (!$extractSuccess) {
                $output = array();
                $returnCode = 0;
                // Check if tar command exists
                exec('tar --version', $output, $returnCode);
                if ($returnCode === 0) {
                    // Zip Slip guard: list archive contents and validate before extracting.
                    $listOut = array();
                    $listRc = 0;
                    exec("tar -tzf " . escapeshellarg($packageFile), $listOut, $listRc);
                    if ($listRc === 0) {
                        $this->assertSafeArchive($listOut);
                    }
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

            // Verify the archive really contains the requested plugin and targets the
            // running OJS series — BEFORE the existing installation is touched, so a
            // wrong or incompatible package can never replace a working plugin.
            $manifest = $this->parseVersionXml(@file_get_contents($pluginSourceDir . '/version.xml'));
            if (!$manifest || !isset($manifest->application)) {
                throw new Exception('version.xml in the archive is invalid');
            }
            $archiveProduct = (string) $manifest->application;
            if (strtolower($archiveProduct) !== strtolower($product)) {
                throw new Exception('Archive contains plugin "' . $archiveProduct . '" but "' . $product . '" was requested');
            }
            import('lib.pkp.classes.site.VersionCheck');
            $ojsLine = $this->currentOjsLine();
            $compat = $this->xmlCompatibility($manifest);
            if ($compat === false) {
                throw new Exception(
                    'Package targets a different OJS version (this site runs OJS '
                    . VersionCheck::getCurrentCodeVersion()->getVersionString() . '). Nothing was changed.'
                );
            }
            if ($compat === null) {
                // No <compatibility> block: judge by the code itself.
                $codeLine = $this->packageCodeLine($pluginSourceDir, $manifest);
                $legacySite = version_compare($ojsLine, '3.4', '<');
                if ($legacySite && $codeLine === '3.4+') {
                    throw new Exception(
                        'This package contains OJS 3.4/3.5 code (namespaced classes) and cannot run on OJS '
                        . $ojsLine . '. Nothing was changed.'
                    );
                }
                if (!$legacySite && $codeLine === '3.3') {
                    throw new Exception(
                        'This package contains OJS 3.3 code (.inc.php classes) and cannot run on OJS '
                        . $ojsLine . '. Nothing was changed.'
                    );
                }
            }

            // Target directory
            $pluginDestDir = Core::getBaseDir() . '/plugins/' . $category . '/' . $product;

            // Smoke-test baseline: confirm, BEFORE anything changes, that OJS boots in a
            // separate CLI process. If it does, a failure after the install can only come
            // from the new plugin. '' = smoke test unavailable on this server (skipped).
            $cliPhp = $this->findCliPhp($tempDir);

            // State needed to undo the install
            $versionRows = $this->captureVersionRows($category, $product);
            $zipFile = null;

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
                $restored = $this->rollbackInstall($category, $product, $pluginDestDir, $zipFile, $versionRows);
                throw new Exception('File copy failed; ' . $restored . '.');
            }

            // Update database version
            $versionFile = $pluginDestDir . '/version.xml';
            if (!$this->updateDatabaseVersion($versionFile, $category, $product)) {
                // Don't fail, just log
                error_log('Warning: Could not update version in database for ' . $product);
            }

            // Post-install smoke test: the plugin class must load. Otherwise undo
            // everything (files from the ZIP backup, versions rows as they were).
            if ($cliPhp !== '') {
                $smoke = $this->runSmokeScript($cliPhp, $tempDir, 'load', $category, $product);
                if (!$smoke['ok']) {
                    error_log('BulkPluginManager: smoke test failed for ' . $category . '/' . $product . ":\n" . $smoke['output']);
                    $restored = $this->rollbackInstall($category, $product, $pluginDestDir, $zipFile, $versionRows);
                    throw new Exception(
                        'The installed plugin failed to load (' . $this->smokeErrorSummary($smoke) . '); '
                        . $restored . '.'
                    );
                }
            } else {
                error_log('BulkPluginManager: post-install smoke test skipped for ' . $category . '/' . $product);
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
        $xml = $this->parseXmlSafe($cleanXml);
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
            $response = $client->request('GET', 'https://pkp.sfu.ca/ojs/xml/plugins.xml', ['timeout' => 30, 'connect_timeout' => 10]);
            $xml = $this->parseXmlSafe((string) $response->getBody());
        } catch (Exception $e) {
            return null;
        }

        if (!$xml)
            return null;

        foreach ($xml->plugin as $plugin) {
            if ((string) $plugin['product'] !== $product || (string) $plugin['category'] !== $category) {
                continue;
            }

            // Find best compatible release (shared helper)
            $bestRelease = $this->pickCompatibleGalleryRelease($plugin);

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
        'ojs-bulk-plugin-manager',
        'bulkPluginManager'
    );

    /**
     * Package file name convention for OJS Services releases:
     *   <product>-ojs<line>[-<line>]-<version>[-demo|-yama].tar.gz
     *   e.g. mailSettings-ojs3.3-1.4.4.0.tar.gz, canonicalUrl-ojs3.4-3.5-1.3.0.0.tar.gz
     */
    const RELEASE_ASSET_PATTERN = '/^([A-Za-z0-9]+)-ojs(3\.\d+)(?:-(3\.\d+))?-(\d+(?:\.\d+){1,3})(?:-(demo|yama))?\.tar\.gz$/';

    /**
     * Choose the package to download from a GitHub release's assets.
     *
     * Assets named by the convention above are matched against the running OJS
     * line (a range such as ojs3.4-3.5 covers both); demo builds are never
     * installed. Older releases whose assets don't follow the convention fall
     * back to the first non-demo .tar.gz, as before.
     *
     * @return string|null download URL, or null to let the caller fall back
     */
    private function pickReleaseAsset($assets)
    {
        import('lib.pkp.classes.site.VersionCheck');
        $current = VersionCheck::getCurrentCodeVersion();
        $line = $current->getMajor() . '.' . $current->getMinor();

        $legacy = null;
        foreach ($assets as $asset) {
            $name = isset($asset['name']) ? (string) $asset['name'] : '';
            $url = isset($asset['browser_download_url']) ? (string) $asset['browser_download_url'] : '';
            if ($url === '' || substr($name, -7) !== '.tar.gz') {
                continue;
            }
            if (preg_match(self::RELEASE_ASSET_PATTERN, $name, $m)) {
                if (isset($m[5]) && $m[5] === 'demo') {
                    continue;
                }
                $from = $m[2];
                $to = (isset($m[3]) && $m[3] !== '') ? $m[3] : $m[2];
                if (version_compare($line, $from, '>=') && version_compare($line, $to, '<=')) {
                    return $url;
                }
                continue; // built for another OJS line
            }
            if ($legacy === null && stripos($name, 'demo') === false) {
                $legacy = $url;
            }
        }
        return $legacy;
    }

    /**
     * GitHub API cache duration (1 hour)
     */
    const GITHUB_CACHE_DURATION = 3600;

    /**
     * How many recent releases to scan when looking for one that is compatible
     * with the running OJS version (repos may ship parallel OJS 3.3 / 3.5 lines).
     */
    const OJS_SERVICES_MAX_RELEASES = 10;

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

        // Base request headers. An optional GitHub token (config.inc.php:
        // [bulk_plugin_manager] github_token = "...") raises the anonymous
        // 60 requests/hour limit to 5000/hour.
        $headers = array(
            'Accept' => 'application/vnd.github.v3+json',
            'User-Agent' => 'OJS-BulkPluginManager'
        );
        $githubToken = $this->getGithubToken();
        if ($githubToken) {
            $headers['Authorization'] = 'token ' . $githubToken;
        }

        do {
            $url = 'https://api.github.com/orgs/ojs-services/repos?per_page=100&page=' . $page;
            try {
                $response = $client->request('GET', $url, [
                    'timeout' => 20,
                    'connect_timeout' => 10,
                    'headers' => $headers
                ]);
                // Stop early and fall back to cache if we are rate-limited.
                $remaining = $response->getHeaderLine('X-RateLimit-Remaining');
                if ($remaining !== '' && (int) $remaining <= 0) {
                    error_log('BulkPluginManager: GitHub API rate limit reached; using cached repo list.');
                    if (file_exists($cacheFile)) {
                        $cached = json_decode(file_get_contents($cacheFile), true);
                        if ($cached !== null) {
                            return $cached;
                        }
                    }
                }
                $repos = json_decode((string)$response->getBody(), true);
                if (!is_array($repos) || empty($repos)) {
                    break;
                }
                $allRepos = array_merge($allRepos, $repos);
                $page++;
            } catch (Exception $e) {
                // On failure (network error or 403 rate limit), fall back to expired cache
                error_log('BulkPluginManager: GitHub org repos fetch failed: ' . $e->getMessage());
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
        ob_start(); // swallow any stray warnings/notices so they can't corrupt the JSON
        $refresh = $request->getUserVar('refresh') ? true : false;
        $result = $this->fetchOjsServicesPlugins($refresh);

        $this->sendJson($result);
    }

    /**
     * Fetch a repo's recent releases (newest first), cached.
     */
    private function fetchRepoReleases($repo, $forceRefresh = false)
    {
        $safeName = preg_replace('/[^a-zA-Z0-9_-]/', '_', $repo);
        $cacheFile = sys_get_temp_dir() . '/ojs_services_' . $safeName . '_releases.json';

        if (!$forceRefresh && file_exists($cacheFile) && (time() - filemtime($cacheFile) < self::GITHUB_CACHE_DURATION)) {
            $cached = json_decode(@file_get_contents($cacheFile), true);
            if (is_array($cached)) {
                return $cached;
            }
        }

        $headers = array('Accept' => 'application/vnd.github.v3+json', 'User-Agent' => 'OJS-BulkPluginManager');
        $token = $this->getGithubToken();
        if ($token) {
            $headers['Authorization'] = 'token ' . $token;
        }

        try {
            $client = Application::get()->getHttpClient();
            $response = $client->request(
                'GET',
                'https://api.github.com/repos/ojs-services/' . $repo . '/releases?per_page=' . self::OJS_SERVICES_MAX_RELEASES,
                array('timeout' => 15, 'connect_timeout' => 10, 'headers' => $headers)
            );
            $releases = json_decode((string) $response->getBody(), true);
            if (!is_array($releases)) {
                $releases = array();
            }
            file_put_contents($cacheFile, json_encode($releases));
            return $releases;
        } catch (Exception $e) {
            error_log('BulkPluginManager: releases fetch failed for ' . $repo . ': ' . $e->getMessage());
            if (file_exists($cacheFile)) {
                $cached = json_decode(@file_get_contents($cacheFile), true);
                if (is_array($cached)) {
                    return $cached;
                }
            }
            return array();
        }
    }

    /**
     * Fetch a repo's version.xml at a given git ref (branch or tag), cached.
     * @return string raw XML, or '' when unavailable
     */
    private function fetchVersionXmlAtRef($repo, $ref, $forceRefresh = false)
    {
        if (!preg_match('#^[A-Za-z0-9._/-]+$#', (string) $ref)) {
            return '';
        }

        $safeName = preg_replace('/[^a-zA-Z0-9_-]/', '_', $repo . '__' . $ref);
        $cacheFile = sys_get_temp_dir() . '/ojs_services_' . $safeName . '_version.xml';

        if (!$forceRefresh && file_exists($cacheFile) && (time() - filemtime($cacheFile) < self::GITHUB_CACHE_DURATION)) {
            $cached = @file_get_contents($cacheFile);
            if ($cached !== false) {
                return $cached;
            }
        }

        try {
            $client = Application::get()->getHttpClient();
            $response = $client->request(
                'GET',
                'https://raw.githubusercontent.com/ojs-services/' . $repo . '/' . $ref . '/version.xml',
                array('timeout' => 15, 'connect_timeout' => 10)
            );
            $content = (string) $response->getBody();
            file_put_contents($cacheFile, $content);
            return $content;
        } catch (Exception $e) {
            // Missing version.xml at this ref is normal (not a plugin / older layout)
            if (file_exists($cacheFile)) {
                $cached = @file_get_contents($cacheFile);
                if ($cached !== false) {
                    return $cached;
                }
            }
            return '';
        }
    }

    /**
     * Parse a version.xml string safely, stripping the DOCTYPE first.
     * @return SimpleXMLElement|false
     */
    private function parseVersionXml($xmlContent)
    {
        if (!$xmlContent) {
            return false;
        }
        return $this->parseXmlSafe(preg_replace('/<!DOCTYPE[^>]*>/', '', $xmlContent));
    }

    /**
     * Series-level compatibility for a single <version> entry of a plugin's OWN
     * version.xml: true when it targets the running OJS major.minor line
     * (e.g. any 3.3.0.x on an OJS 3.3 site). Range prefixes like "~" are stripped.
     *
     * Deliberately more lenient than isVersionCompatible(): many plugins list
     * explicit patch versions only up to the release they were tested on (e.g.
     * 3.3.0.0 … 3.3.0.16) and still run fine on later 3.3.0.x patches. The job of
     * this check is to reject the WRONG SERIES (an OJS 3.5 package on a 3.3 site),
     * not to demand an exact patch match — that would wrongly flag working plugins
     * as incompatible and block their installation.
     */
    private function isSeriesCompatible($versionString)
    {
        import('lib.pkp.classes.site.VersionCheck');
        $currentVersion = VersionCheck::getCurrentCodeVersion();

        $clean = ltrim((string) $versionString, "~^<>= \t");
        $parts = explode('.', $clean);
        if (!isset($parts[0], $parts[1]) || !ctype_digit($parts[0]) || !ctype_digit(preg_replace('/\D.*$/', '', $parts[1]))) {
            return false;
        }
        return ((int) $parts[0] == $currentVersion->getMajor() && (int) $parts[1] == $currentVersion->getMinor());
    }

    /**
     * Does this version.xml declare compatibility with the running OJS version?
     * @return bool|null true = compatible, false = declares another OJS series,
     *                   null = no <compatibility> block at all (caller decides)
     */
    private function xmlCompatibility($vxml)
    {
        if (!isset($vxml->compatibility)) {
            return null;
        }
        foreach ($vxml->compatibility as $compat) {
            $app = (string) $compat['application'];
            if ($app === 'ojs2' || $app === 'ojs') {
                foreach ($compat->version as $ver) {
                    // Series-level check (see isSeriesCompatible): reject the wrong
                    // OJS line, but don't require an exact patch match.
                    if ($this->isSeriesCompatible((string) $ver)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }


    /**
     * Running OJS series as "major.minor" (e.g. "3.3").
     */
    private function currentOjsLine()
    {
        import('lib.pkp.classes.site.VersionCheck');
        $v = VersionCheck::getCurrentCodeVersion();
        return $v->getMajor() . '.' . $v->getMinor();
    }

    /**
     * OJS line(s) a GitHub release is built for, read from its tag name
     * ("ojs3.3-1.4.4.0", "ojs3.4-3.5-2.0.0.3") or, failing that, from its asset
     * names (RELEASE_ASSET_PATTERN). Returns a list of array(from, to) ranges;
     * an empty list means the line cannot be determined from naming.
     */
    private function releaseLineRanges($release)
    {
        $tag = isset($release['tag_name']) ? (string) $release['tag_name'] : '';
        if (preg_match('/^ojs(3\.\d+)(?:-(3\.\d+))?-\d/', $tag, $m)) {
            return array(array($m[1], (isset($m[2]) && $m[2] !== '') ? $m[2] : $m[1]));
        }
        $ranges = array();
        if (!empty($release['assets']) && is_array($release['assets'])) {
            foreach ($release['assets'] as $asset) {
                $name = isset($asset['name']) ? (string) $asset['name'] : '';
                if (preg_match(self::RELEASE_ASSET_PATTERN, $name, $m)) {
                    if (isset($m[5]) && $m[5] === 'demo') {
                        continue;
                    }
                    $ranges[] = array($m[2], (isset($m[3]) && $m[3] !== '') ? $m[3] : $m[2]);
                }
            }
        }
        return $ranges;
    }

    private function lineInRanges($line, $ranges)
    {
        foreach ($ranges as $r) {
            if (version_compare($line, $r[0], '>=') && version_compare($line, $r[1], '<=')) {
                return true;
            }
        }
        return false;
    }

    /**
     * Which OJS generation the code in an extracted plugin folder targets.
     * OJS 3.3 plugins load "<Class>.inc.php" files; OJS 3.4+ plugins use
     * namespaced "<Class>.php" files ("namespace APP\plugins\...").
     * @return string|null '3.3', '3.4+', or null when it cannot be told apart
     */
    private function packageCodeLine($pluginDir, $manifest)
    {
        $class = ($manifest && isset($manifest->class)) ? trim((string) $manifest->class) : '';

        $legacy = false;
        if ($class !== '' && file_exists($pluginDir . '/' . $class . '.inc.php')) {
            $legacy = true;
        } elseif (glob($pluginDir . '/*Plugin.inc.php')) {
            $legacy = true;
        }

        $namespaced = false;
        $candidates = array();
        if ($class !== '' && file_exists($pluginDir . '/' . $class . '.php')) {
            $candidates[] = $pluginDir . '/' . $class . '.php';
        }
        foreach ((array) glob($pluginDir . '/*Plugin.php') as $f) {
            $candidates[] = $f;
        }
        foreach (array_unique($candidates) as $f) {
            $head = @file_get_contents($f, false, null, 0, 4096);
            if ($head !== false && preg_match('/^\s*namespace\s+APP\\\\plugins\\\\/m', $head)) {
                $namespaced = true;
                break;
            }
        }

        if ($namespaced && !$legacy) {
            return '3.4+';
        }
        if ($legacy && !$namespaced) {
            return '3.3';
        }
        return null;
    }

    /**
     * Cached PHP CLI binary usable for the post-install smoke test, or ''.
     */
    private $_cliPhp = null;

    /**
     * Find a PHP command-line binary of the SAME major.minor version as the web
     * PHP, and verify it can bootstrap this OJS installation. Returns '' when
     * none is usable (exec disabled, no CLI, version mismatch, bootstrap fails).
     */
    private function findCliPhp($workDir)
    {
        if ($this->_cliPhp !== null) {
            return $this->_cliPhp;
        }
        $this->_cliPhp = '';

        $disabled = array_map('trim', explode(',', (string) ini_get('disable_functions')));
        if (!function_exists('exec') || in_array('exec', $disabled, true)) {
            error_log('BulkPluginManager: smoke test unavailable (exec disabled)');
            return '';
        }

        $mm = PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
        $candidates = array();
        if (PHP_SAPI === 'cli' || preg_match('/^php[0-9.]*(-cli)?(\.exe)?$/i', basename((string) PHP_BINARY))) {
            $candidates[] = PHP_BINARY;
        }
        $ext = (string) ini_get('extension_dir');
        if ($ext !== '') {
            $base = dirname(rtrim($ext, '/\\'));
            $candidates[] = $base . '/php.exe';
            $candidates[] = $base . '/php';
            $candidates[] = $base . '/bin/php';
        }
        $candidates[] = PHP_BINDIR . '/php';
        $candidates[] = PHP_BINDIR . '/php.exe';
        $candidates[] = '/opt/cpanel/ea-php' . PHP_MAJOR_VERSION . PHP_MINOR_VERSION . '/root/usr/bin/php';
        $candidates[] = '/opt/alt/php' . PHP_MAJOR_VERSION . PHP_MINOR_VERSION . '/usr/bin/php';
        $candidates[] = '/usr/bin/php' . $mm;
        $candidates[] = '/usr/local/bin/php';
        $candidates[] = '/usr/bin/php';

        foreach (array_unique($candidates) as $php) {
            if (!@is_file($php)) {
                continue;
            }
            $res = $this->runSmokeScript($php, $workDir, 'boot', '', '');
            if ($res['boot']) {
                $this->_cliPhp = $php;
                return $php;
            }
        }
        error_log('BulkPluginManager: smoke test unavailable (no PHP ' . $mm . ' CLI that can bootstrap OJS)');
        return '';
    }

    /**
     * Run OJS in a separate CLI process. Mode "boot" only bootstraps OJS (this
     * loads every enabled generic plugin); mode "load" also loads the given
     * plugin. A separate process is required: in this request the old plugin
     * class may already be in memory, and a fatal error must not kill the
     * request that has to roll the installation back.
     * @return array('start' => bool, 'boot' => bool, 'ok' => bool, 'output' => string)
     */
    private function runSmokeScript($php, $workDir, $mode, $category, $product)
    {
        $base = Core::getBaseDir();
        $script = $workDir . '/bpm_smoke_' . $mode . '.php';
        $code = "<?php\n"
            . "echo 'BPM_CLI_START ' . PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . \"\\n\";\n"
            . "if (PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION !== " . var_export(PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION, true) . ") { echo \"BPM_CLI_MISMATCH\\n\"; exit(3); }\n"
            . "chdir(" . var_export($base, true) . ");\n"
            . "require(" . var_export($base . '/tools/bootstrap.inc.php', true) . ");\n"
            . "class BpmSmokeTool extends CommandLineTool {\n"
            . "  function execute() {\n"
            . "    echo \"BPM_BOOT_OK\\n\";\n"
            . "    if (" . var_export($mode, true) . " !== 'load') return;\n"
            . "    \$p = PluginRegistry::loadPlugin(" . var_export($category, true) . ", " . var_export($product, true) . ");\n"
            . "    if (!is_object(\$p)) { echo \"BPM_SMOKE_FAIL plugin did not load\\n\"; return; }\n"
            . "    \$p->getDisplayName();\n"
            . "    echo 'BPM_SMOKE_OK ' . get_class(\$p) . \"\\n\";\n"
            . "  }\n"
            . "}\n"
            . "\$t = new BpmSmokeTool(array('bpmSmoke'));\n"
            . "\$t->execute();\n";
        if (@file_put_contents($script, $code) === false) {
            return array('start' => false, 'boot' => false, 'ok' => false, 'output' => 'cannot write smoke script');
        }

        $out = array();
        $rc = 0;
        $cmd = escapeshellarg($php) . ' -d display_errors=stderr -d log_errors=0 -d xdebug.mode=off '
            . escapeshellarg($script) . ' 2>&1';
        @exec($cmd, $out, $rc);
        @unlink($script);

        $text = implode("\n", (array) $out);
        return array(
            'start' => strpos($text, 'BPM_CLI_START') !== false && strpos($text, 'BPM_CLI_MISMATCH') === false,
            'boot' => strpos($text, 'BPM_BOOT_OK') !== false,
            'ok' => strpos($text, 'BPM_SMOKE_OK') !== false,
            'output' => $text,
        );
    }

    /**
     * Last error lines of a smoke run, for a readable failure message.
     */
    private function smokeErrorSummary($smoke)
    {
        $lines = array();
        foreach (preg_split('/\r?\n/', (string) $smoke['output']) as $line) {
            if (preg_match('/(Fatal error|Parse error|Uncaught|Error:|BPM_SMOKE_FAIL)/i', $line)) {
                $lines[] = trim(preg_replace('/\s+/', ' ', $line));
            }
        }
        $summary = substr(implode(' | ', array_slice($lines, 0, 2)), 0, 400);
        if (empty($smoke['boot'])) {
            // OJS itself could not start with the new files in place — what the site
            // would show too (e.g. the plugin list no longer opens).
            return 'OJS could not start with this plugin installed' . ($summary !== '' ? ': ' . $summary : '');
        }
        return $summary !== '' ? $summary : 'the plugin class could not be loaded';
    }

    /**
     * Snapshot of the versions rows for a plugin (to undo a failed install).
     */
    private function captureVersionRows($category, $product)
    {
        $rows = array();
        $versionDao = DAORegistry::getDAO('VersionDAO');
        $res = $versionDao->retrieve(
            'SELECT * FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)',
            array('plugins.' . $category, $product)
        );
        foreach ($res as $row) {
            $rows[] = (array) $row;
        }
        return $rows;
    }

    private function restoreVersionRows($category, $product, $rows)
    {
        $versionDao = DAORegistry::getDAO('VersionDAO');
        $versionDao->update(
            'DELETE FROM versions WHERE LOWER(product_type) = LOWER(?) AND LOWER(product) = LOWER(?)',
            array('plugins.' . $category, $product)
        );
        foreach ($rows as $row) {
            $cols = array_keys($row);
            $versionDao->update(
                'INSERT INTO versions (' . implode(', ', $cols) . ') VALUES (' . implode(', ', array_fill(0, count($cols), '?')) . ')',
                array_values($row)
            );
        }
    }

    /**
     * Undo a plugin installation: remove the new files, put the previous
     * version back from its ZIP backup (if there was one) and restore the
     * versions rows exactly as they were.
     * @return string short description of what was restored
     */
    private function rollbackInstall($category, $product, $pluginDestDir, $backupZip, $versionRows)
    {
        if (is_dir($pluginDestDir)) {
            $this->recursiveDelete($pluginDestDir);
        }
        $restored = 'the plugin was removed';
        if ($backupZip && file_exists($backupZip)) {
            $zip = new ZipArchive();
            if ($zip->open($backupZip) === true) {
                $this->assertSafeArchive($this->zipEntryNames($zip));
                $zip->extractTo($pluginDestDir);
                $zip->close();
                $restored = 'the previous version was restored';
            }
        }
        try {
            $this->restoreVersionRows($category, $product, $versionRows);
        } catch (Throwable $e) {
            error_log('BulkPluginManager: versions rollback failed for ' . $category . '/' . $product . ': ' . $e->getMessage());
        }
        return $restored;
    }

    /**
     * Pick the newest release whose version.xml is compatible with the running OJS.
     *
     * A repo can ship parallel lines (e.g. an OJS 3.3 release and an OJS 3.5 port).
     * GitHub's /releases/latest returns the newest by date regardless of which OJS
     * series it targets, which would offer — and install — the wrong package.
     *
     * @return array|null array('release' => <github release>, 'vxml' => SimpleXMLElement)
     */
    /**
     * Why the last selectCompatibleRelease() call found nothing:
     * 'otherLine' = releases exist but all target another OJS line; 'none' = no usable release.
     */
    private $_lastSelectReason = '';

    private function selectCompatibleRelease($repo, $forceRefresh = false)
    {
        $line = $this->currentOjsLine();
        $releases = $this->fetchRepoReleases($repo, $forceRefresh);

        // Two tiers: releases whose naming names the running OJS line win over
        // releases whose line cannot be read from their names. Within a tier the
        // highest plugin version wins (GitHub's list order is by date, not version).
        $best = array('named' => null, 'unnamed' => null);
        $bestVersion = array('named' => '', 'unnamed' => '');
        $sawOtherLine = false;

        foreach ($releases as $release) {
            if (!empty($release['draft'])) {
                continue;
            }
            $tag = isset($release['tag_name']) ? (string) $release['tag_name'] : '';
            if ($tag === '') {
                continue;
            }

            // The tag / asset name states which OJS line the release is built for
            // (packaging rule). A release named for another line is never offered,
            // whatever its version.xml says (many of our version.xml files have no
            // <compatibility> block, which used to mean "assume compatible").
            $ranges = $this->releaseLineRanges($release);
            if ($ranges && !$this->lineInRanges($line, $ranges)) {
                $sawOtherLine = true;
                continue;
            }

            $vxml = $this->parseVersionXml($this->fetchVersionXmlAtRef($repo, $tag, $forceRefresh));
            if (!$vxml || !isset($vxml->application)) {
                continue;
            }

            $compat = $this->xmlCompatibility($vxml);
            if ($compat === false) {
                $sawOtherLine = true;
                continue;
            }

            // Compatible by declaration or by name; or, with neither a block nor a
            // line in the name, the legacy fallback (the install-time code check
            // in downloadAndInstall() still guards against the wrong code).
            $tier = $ranges ? 'named' : 'unnamed';
            $ver = isset($vxml->release) ? (string) $vxml->release : '0';
            if ($best[$tier] === null || version_compare($ver, $bestVersion[$tier], '>')) {
                $best[$tier] = array('release' => $release, 'vxml' => $vxml);
                $bestVersion[$tier] = $ver;
            }
        }

        $selected = $best['named'] !== null ? $best['named'] : $best['unnamed'];
        $this->_lastSelectReason = $selected ? '' : ($sawOtherLine ? 'otherLine' : 'none');
        return $selected;
    }

    /**
     * Fetch OJS Services plugins with version info (dynamic GitHub discovery)
     */
    private function fetchOjsServicesPlugins($forceRefresh = false)
    {
        $plugins = array();

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

            // Sanitize repo/branch names before building URLs (defense-in-depth in case
            // the GitHub API response is tampered with): allow only safe ref characters.
            if (!preg_match('#^[A-Za-z0-9._/-]+$#', (string) $repo)
                || !preg_match('#^[A-Za-z0-9._/-]+$#', (string) $branch)) {
                continue;
            }

            // Base manifest from the default branch — identifies the repo as a plugin.
            $vxml = $this->parseVersionXml($this->fetchVersionXmlAtRef($repo, $branch, $forceRefresh));
            if (!$vxml || !isset($vxml->application)) {
                continue; // Not a plugin repo / invalid version.xml
            }

            // Prefer the newest RELEASE that targets the running OJS series. A repo may
            // ship parallel lines (e.g. an OJS 3.3 release and an OJS 3.5 port); using
            // the default branch or /releases/latest would offer the wrong package.
            $selected = $this->selectCompatibleRelease($repo, $forceRefresh);
            $manifest = $selected ? $selected['vxml'] : $vxml;

            // Extract product name from the manifest we will actually offer
            $product = (string)$manifest->application;

            // Skip bulkPluginManager itself (safety check)
            if ($product === 'bulkPluginManager') continue;

            // Extract category from <type> (e.g., "plugins.generic" → "generic")
            $category = 'generic';
            if (isset($manifest->type)) {
                $typeParts = explode('.', (string)$manifest->type);
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
                'repoUrl' => 'https://github.com/ojs-services/' . $repo,
                'controls' => null
            );

            // Version + compatibility come from the manifest we will actually offer.
            $pluginData['repoVersion'] = isset($manifest->release) ? (string)$manifest->release : null;

            if ($selected) {
                // selectCompatibleRelease() only returns compatible releases.
                $pluginData['compatible'] = true;
            } elseif ($this->_lastSelectReason === 'otherLine') {
                // Releases exist, but every one targets another OJS line.
                $pluginData['compatible'] = false;
            } else {
                // No release at all — fall back to the default branch manifest.
                // A missing <compatibility> block keeps the historical "assume compatible";
                // with no package to download the card says "No package for this OJS version".
                $compat = $this->xmlCompatibility($manifest);
                $pluginData['compatible'] = ($compat === null) ? true : $compat;
            }

            // Download URL comes from the SELECTED (compatible) release, never from
            // /releases/latest — that would hand an OJS 3.5 package to an OJS 3.3 site.
            $releaseData = $selected ? $selected['release'] : null;

            if ($releaseData && !empty($releaseData['assets']) && is_array($releaseData['assets'])) {
                $pluginData['downloadUrl'] = $this->pickReleaseAsset($releaseData['assets']);
            }

            // No fallback to GitHub's source tarball: it is not an installable
            // package (and may hold code for another OJS line). Without a matching
            // release asset downloadUrl stays empty and the card says so.

            // Check if installed locally
            $info = $this->getInstalledInfo($category, $product);
            $pluginData['filesExist'] = $info['filesExist'];
            if ($info['fileVersion']) {
                $pluginData['installedVersion'] = $info['fileVersion'];
            } elseif ($info['dbVersion']) {
                $pluginData['installedVersion'] = $info['dbVersion'];
            }

            // Enable/disable + settings for plugins that are installed on disk
            if ($pluginData['filesExist']) {
                $pluginData['controls'] = $this->describePluginControls($category, $product);
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
        ob_start(); // swallow any stray warnings/notices so they can't corrupt the JSON
        $this->requireCSRF($request);

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

        // Security (SSRF guard): strictly validate the download URL with parse_url.
        // A substring check is insufficient — e.g. https://evil.com/github.com/ojs-services/
        // would pass. Require HTTPS, a GitHub host, and an /ojs-services/ path.
        if (!$this->isAllowedGithubUrl($downloadUrl)) {
            $this->jsonResponse('error', 'Invalid download URL: must be an HTTPS ojs-services GitHub URL');
        }
        // Source archives (tarball/zipball) are not installable release packages.
        if (preg_match('#/(tarball|zipball)/#i', (string) parse_url($downloadUrl, PHP_URL_PATH))) {
            $this->jsonResponse('error', 'No release package exists for this OJS version (source archives are not installed).');
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

    /**
     * Optional GitHub API token from config.inc.php to raise the anonymous rate limit.
     * Section [bulk_plugin_manager], key github_token. Returns '' when unset.
     */
    private function getGithubToken()
    {
        $token = Config::getVar('bulk_plugin_manager', 'github_token', '');
        return is_string($token) ? trim($token) : '';
    }

    /**
     * SSRF guard: return true only for HTTPS URLs on a trusted GitHub host whose
     * path targets the ojs-services organization.
     */
    private function isAllowedGithubUrl($url)
    {
        $parsed = parse_url((string) $url);
        if (!$parsed || !isset($parsed['scheme'], $parsed['host'], $parsed['path'])) {
            return false;
        }
        if (strtolower($parsed['scheme']) !== 'https') {
            return false;
        }
        $host = strtolower($parsed['host']);
        $allowedHosts = array('github.com', 'api.github.com', 'codeload.github.com', 'objects.githubusercontent.com');
        if (!in_array($host, $allowedHosts, true)) {
            return false;
        }
        // Path must reference the ojs-services org (e.g. /ojs-services/... or /repos/ojs-services/...).
        // objects.githubusercontent.com serves opaque asset paths from a github.com release, so
        // it is allowed by host alone.
        if ($host === 'objects.githubusercontent.com') {
            return true;
        }
        return (strpos($parsed['path'], '/ojs-services/') !== false
            || strpos($parsed['path'], '/repos/ojs-services/') !== false);
    }

    /**
     * Per-request cache of loaded plugins by category (see describePluginControls).
     */
    private $_categoryPlugins = array();

    /**
     * Describe how an installed plugin can be enabled/disabled and configured, so
     * the OJS Services tab can offer the same controls as OJS's own plugin list.
     *
     * Every action goes through OJS core's own plugin grid endpoints
     * (grid.settings.plugins.SettingsPluginGridHandler: enable / disable / manage),
     * so authorization, CSRF, notifications and plugin hooks behave exactly as in
     * Website Settings > Plugins. Nothing is re-implemented here.
     *
     * @return array|null null when the plugin cannot be loaded
     */
    private function describePluginControls($category, $product)
    {
        try {
            $request = Application::get()->getRequest();
            $dispatcher = $request->getDispatcher();

            if (!isset($this->_categoryPlugins[$category])) {
                // loadCategory() returns the registered plugins as a flat
                // name => Plugin map (via getPlugins()).
                $loaded = array();
                $registered = PluginRegistry::loadCategory($category);
                foreach ((is_array($registered) ? $registered : array()) as $plugin) {
                    if (is_object($plugin) && method_exists($plugin, 'getPluginPath')) {
                        $loaded[strtolower(basename($plugin->getPluginPath()))] = $plugin;
                    }
                }
                $this->_categoryPlugins[$category] = $loaded;
            }
            $key = strtolower($product);
            if (!isset($this->_categoryPlugins[$category][$key])) {
                return null;
            }
            $plugin = $this->_categoryPlugins[$category][$key];
            $pluginName = $plugin->getName();

            $gridUrl = function ($op, $extra = array()) use ($dispatcher, $request, $pluginName, $category) {
                return $dispatcher->url(
                    $request, ROUTE_COMPONENT, null,
                    'grid.settings.plugins.SettingsPluginGridHandler', $op, null,
                    array_merge(array('plugin' => $pluginName, 'category' => $category), $extra)
                );
            };

            $controls = array(
                'pluginName' => $pluginName,
                'canEnable' => (bool) $plugin->getCanEnable(),
                'canDisable' => (bool) $plugin->getCanDisable(),
                'enabled' => (bool) $plugin->getEnabled(),
                'enableUrl' => $gridUrl('enable'),
                'disableUrl' => $gridUrl('disable'),
                'settings' => null,
            );

            // Settings: reuse the plugin's own actions. OJS offers them only while
            // the plugin is enabled (import/export plugins are always enabled).
            import('lib.pkp.classes.linkAction.request.RedirectAction');
            import('lib.pkp.classes.linkAction.request.AjaxModal');
            $actions = array();
            try {
                $actions = (array) $plugin->getActions($request, array('plugin' => $pluginName, 'category' => $category));
            } catch (Throwable $e) {
                error_log('BulkPluginManager: getActions failed for ' . $pluginName . ': ' . $e->getMessage());
            }

            // Prefer the action with id "settings", else the first usable one.
            usort($actions, function ($a, $b) {
                $as = (is_object($a) && method_exists($a, 'getId') && $a->getId() === 'settings') ? 0 : 1;
                $bs = (is_object($b) && method_exists($b, 'getId') && $b->getId() === 'settings') ? 0 : 1;
                return $as - $bs;
            });

            foreach ($actions as $action) {
                if (!is_object($action) || !method_exists($action, 'getActionRequest')) {
                    continue;
                }
                $actionRequest = $action->getActionRequest();
                $label = method_exists($action, 'getTitle') ? (string) $action->getTitle() : '';

                if ($actionRequest instanceof RedirectAction) {
                    // Own settings page (e.g. import/export screen, plugin dashboard)
                    $controls['settings'] = array('type' => 'page', 'url' => $actionRequest->getUrl(), 'label' => $label);
                    break;
                }
                if ($actionRequest instanceof AjaxModal) {
                    // The plugin built this URL with whatever router handled the
                    // current request; under our page router it would point at the
                    // wrong handler. Keep its "verb" and rebuild the URL on OJS
                    // core's plugin grid, exactly like Website Settings > Plugins.
                    $verb = 'settings';
                    $query = parse_url(html_entity_decode((string) $actionRequest->getUrl()), PHP_URL_QUERY);
                    if ($query) {
                        parse_str($query, $queryArgs);
                        if (!empty($queryArgs['verb']) && preg_match('/^[A-Za-z0-9_]+$/', $queryArgs['verb'])) {
                            $verb = $queryArgs['verb'];
                        }
                    }
                    $title = method_exists($actionRequest, 'getTitle') ? (string) $actionRequest->getTitle() : '';
                    $controls['settings'] = array(
                        'type' => 'modal',
                        'url' => $gridUrl('manage', array('verb' => $verb)),
                        'title' => $title !== '' ? $title : $plugin->getDisplayName(),
                        'label' => $label,
                    );
                    break;
                }
            }

            return $controls;
        } catch (Throwable $e) {
            error_log('BulkPluginManager: describePluginControls failed for ' . $category . '/' . $product . ': ' . $e->getMessage());
            return null;
        }
    }

    private function jsonResponse($status, $message, $product = null)
    {
        $response = array('status' => $status, 'message' => $message);
        if ($product)
            $response['product'] = $product;
        $this->sendJson($response);
    }

    /**
     * Emit a JSON response and stop. Any output produced before this point —
     * PHP notices/deprecations printed by servers with display_errors=On (e.g.
     * the bundled Guzzle on PHP 8.1 during downloads) — is discarded first, so
     * it can never corrupt the JSON and make a successful action look failed.
     */
    private function sendJson($data)
    {
        while (ob_get_level() > 0) {
            ob_end_clean();
        }
        header('Content-Type: application/json');
        echo json_encode($data);
        exit;
    }

    public function setupTemplate($request)
    {
        AppLocale::requireComponents(LOCALE_COMPONENT_PKP_ADMIN);
        parent::setupTemplate($request);
    }
}
