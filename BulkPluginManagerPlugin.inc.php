<?php
/**
 * @file plugins/generic/bulkPluginManager/BulkPluginManagerPlugin.inc.php
 *
 * @class BulkPluginManagerPlugin
 * @brief Bulk Plugin Manager for OJS 3.3.x
 */

import('lib.pkp.classes.plugins.GenericPlugin');

class BulkPluginManagerPlugin extends GenericPlugin {

    /**
     * @copydoc Plugin::register()
     */
    public function register($category, $path, $mainContextId = null) {
        $ojsVersion = Application::get()->getCurrentVersion()->getVersionString();
        if (version_compare($ojsVersion, '3.4.0.0', '>=')) {
            error_log('Bulk Plugin Manager: Incompatible OJS version ' . $ojsVersion . '. Requires 3.3.x.');
            return false;
        }

        $success = parent::register($category, $path, $mainContextId);
        if ($success && $this->getEnabled()) {
            HookRegistry::register('LoadHandler', array($this, 'loadHandler'));
            HookRegistry::register('TemplateManager::display', array($this, 'addSidebarLink'));
        }
        return $success;
    }

    /**
     * @copydoc PKPHandler::loadHandler()
     */
    public function loadHandler($hookName, $params) {
        $page = $params[0];
        if ($page === 'bulkPluginManager') {
            require_once($this->getPluginPath() . '/BulkPluginManagerHandler.inc.php');
            define('HANDLER_CLASS', 'BulkPluginManagerHandler');
            return true;
        }
        return false;
    }

    /**
     * Add a "Bulk Plugin Manager" entry to the OJS backend navigation menu.
     *
     * The entry is added to the Vue 'menu' state that setupBackendPage()
     * builds for every backend handler, so it renders exactly like the
     * core menu items (no icons, no custom styles, native active state).
     */
    public function addSidebarLink($hookName, $args) {
        $templateMgr = $args[0];

        // Backend detection: the 'menu' state only exists on backend pages.
        // The isset() guard keeps the hook idempotent across the multiple
        // display calls of a single request.
        $menu = $templateMgr->getState('menu');
        if (!is_array($menu) || empty($menu) || isset($menu['bulkPluginManager'])) {
            return false;
        }

        $request = Application::get()->getRequest();
        $user = $request->getUser();
        if (!$user) {
            return false;
        }

        // Component (AJAX) requests use a router without page URLs
        $router = $request->getRouter();
        if (strpos(get_class($router), 'PageRouter') === false) {
            return false;
        }

        $contextId = $request->getContext() ? $request->getContext()->getId() : CONTEXT_SITE;
        $userRoles = $user->getRoles($contextId);
        $isAdmin = false;
        foreach ($userRoles as $role) {
            if (in_array($role->getRoleId(), array(ROLE_ID_SITE_ADMIN, ROLE_ID_MANAGER))) {
                $isAdmin = true;
                break;
            }
        }
        if (!$isAdmin) {
            return false;
        }

        $dispatcher = $request->getDispatcher();
        $menu['bulkPluginManager'] = array(
            'name' => __('plugins.generic.bulkPluginManager.displayName'),
            'url' => $dispatcher->url($request, ROUTE_PAGE, null, 'bulkPluginManager'),
            'isCurrent' => ($router->getRequestedPage($request) === 'bulkPluginManager'),
        );
        $templateMgr->setState(array('menu' => $menu));

        return false;
    }

    /**
     * @copydoc Plugin::getDisplayName()
     */
    public function getDisplayName() {
        return __('plugins.generic.bulkPluginManager.displayName');
    }

    /**
     * @copydoc Plugin::getDescription()
     */
    public function getDescription() {
        return __('plugins.generic.bulkPluginManager.description');
    }

    /**
     * @copydoc Plugin::isSitePlugin()
     */
    public function isSitePlugin() {
        return false;
    }

    /**
     * @copydoc Plugin::getActions()
     */
    public function getActions($request, $actionArgs) {
        import('lib.pkp.classes.linkAction.request.RedirectAction');
        import('lib.pkp.classes.linkAction.LinkAction');

        $actions = parent::getActions($request, $actionArgs);

        if ($this->getEnabled()) {
            $dispatcher = $request->getDispatcher();
            $url = $dispatcher->url($request, ROUTE_PAGE, null, 'bulkPluginManager');
            array_unshift(
                $actions,
                new LinkAction(
                    'updater',
                    new RedirectAction($url),
                    __('plugins.generic.bulkPluginManager.openManager')
                )
            );
        }

        return $actions;
    }
}
