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
     * Inject sidebar link into OJS backend navigation via JavaScript.
     */
    public function addSidebarLink($hookName, $args) {
        $templateMgr = $args[0];
        $template = $args[1];

        $backendTemplates = array(
            'management/', 'admin/', 'dashboard/', 'submissions',
            'authorDashboard', 'workflow/', 'stats/', 'statistics/',
            'tools/', 'settings/', 'users/', 'manageIssues/',
            'editorialActivity', 'reports/', 'article'
        );

        $isBackend = false;
        foreach ($backendTemplates as $tpl) {
            if (strpos($template, $tpl) !== false) {
                $isBackend = true;
                break;
            }
        }

        $request = Application::get()->getRequest();
        $router = $request->getRouter();
        if ($router && method_exists($router, 'getRequestedPage')) {
            $page = $router->getRequestedPage($request);
            $backendPages = array(
                'management', 'manageIssues', 'stats', 'submissions',
                'workflow', 'settings', 'tools', 'admin', 'user',
                'bulkPluginManager', 'submitai-settings', 'mailSettings', 'certificatepro'
            );
            if (in_array($page, $backendPages)) {
                $isBackend = true;
            }
        }

        if ($isBackend) {
            $dispatcher = $request->getDispatcher();
            $url = $dispatcher->url($request, ROUTE_PAGE, null, 'bulkPluginManager');

            $user = $request->getUser();
            if ($user) {
                $contextId = $request->getContext() ? $request->getContext()->getId() : CONTEXT_SITE;
                $userRoles = $user->getRoles($contextId);
                $isAdmin = false;
                foreach ($userRoles as $role) {
                    if (in_array($role->getRoleId(), array(ROLE_ID_SITE_ADMIN, ROLE_ID_MANAGER))) {
                        $isAdmin = true;
                        break;
                    }
                }

                if ($isAdmin) {
                    $templateMgr->addJavaScript(
                        'bulkPluginManagerSidebar',
                        '
                        document.addEventListener("DOMContentLoaded", function() {
                            var nav = document.querySelector(".pkp_nav_list, .app__nav, nav[role=navigation] ul, .pkpNav__list");
                            if (!nav) nav = document.querySelector("#navigationPrimary ul, .pkp_navigation_primary ul");
                            if (!nav || document.getElementById("bulkPluginManagerLink")) return;

                            var li = document.createElement("li");
                            li.id = "bulkPluginManagerLink";
                            li.className = nav.children[0] ? nav.children[0].className : "";
                            li.style.cssText = "border-top: 1px solid rgba(255,255,255,0.1); margin-top: 10px; padding-top: 10px;";

                            var a = document.createElement("a");
                            a.href = "' . $url . '";
                            a.innerHTML = "\uD83D\uDD0C Bulk Plugin Manager";
                            a.style.cssText = "display: flex; align-items: center; gap: 8px; color: inherit; text-decoration: none;";
                            a.className = nav.querySelector("a") ? nav.querySelector("a").className : "";

                            li.appendChild(a);
                            nav.appendChild(li);
                        });
                        ',
                        array('inline' => true, 'contexts' => array('backend'))
                    );
                }
            }
        }

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
