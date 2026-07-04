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
                'bulkPluginManager', 'submitai-settings', 'mailSettings', 'certificatepro', 'advancedUserManager'
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
                        '(function(){' .
                        'var S=window.OJS_SIDEBAR_ITEMS=window.OJS_SIDEBAR_ITEMS||[];' .
                        'S.push({id:"bpmNavLink",icon:"\uD83D\uDD0C",text:"Bulk Plugin Manager",url:' . json_encode($url) . ',pg:"bulkPluginManager",p:20});' .
                        'if(!window._ojsSbRender){window._ojsSbRender=function(){' .
                        'var items=window.OJS_SIDEBAR_ITEMS;if(!items||!items.length)return;' .
                        'var nav=document.querySelector(".pkp_nav_list,.app__nav,nav[role=navigation] ul,.pkpNav__list");' .
                        'if(!nav)nav=document.querySelector("#navigationPrimary ul,.pkp_navigation_primary ul");' .
                        'if(!nav){if(!window._ojsSbR)window._ojsSbR=0;if(window._ojsSbR++<30)setTimeout(window._ojsSbRender,200);return;}' .
                        'window._ojsSbR=0;if(nav.tagName==="NAV"){var ul=nav.querySelector("ul");if(ul)nav=ul;}' .
                        'var old=nav.querySelectorAll("[data-ojs-sidebar]");for(var i=0;i<old.length;i++)old[i].parentNode.removeChild(old[i]);' .
                        'items.sort(function(a,b){return(a.p||99)-(b.p||99);});' .
                        'var sep=document.createElement("li");sep.setAttribute("data-ojs-sidebar","1");' .
                        'sep.style.cssText="border-top:1px solid rgba(255,255,255,0.15);margin:12px 0 6px;padding:0;list-style:none;";nav.appendChild(sep);' .
                        'var u=window.location.href;items.forEach(function(it){' .
                        'var li=document.createElement("li");li.id=it.id;li.setAttribute("data-ojs-sidebar","1");' .
                        'var a=document.createElement("a");a.className="app__navItem";a.href=it.url;a.innerHTML=it.icon+" "+it.text;' .
                        'a.style.cssText="display:flex;align-items:center;gap:8px;padding:8px 16px;color:inherit;text-decoration:none;font-size:0.9em;font-weight:600;";' .
                        'if(u.indexOf(it.pg)>-1){a.classList.add("app__navItem--isCurrent");a.style.opacity="1";}' .
                        'li.appendChild(a);nav.appendChild(li);});};}' .
                        'clearTimeout(window._ojsSbT);window._ojsSbT=setTimeout(window._ojsSbRender,100);' .
                        'if(document.readyState==="loading"){document.addEventListener("DOMContentLoaded",function(){clearTimeout(window._ojsSbT);window._ojsSbT=setTimeout(window._ojsSbRender,100);});}' .
                        '})();',
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
