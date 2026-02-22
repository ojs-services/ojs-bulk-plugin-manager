<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bulk Plugin Manager</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        html, body { height: 100%; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f0f2f5; display: flex; flex-direction: row; min-height: 100vh; }

        /* OJS-style Sidebar */
        .ojs-sidebar { width: 220px; min-width: 220px; background: #002b5c; color: #fff; display: flex; flex-direction: column; min-height: 100vh; position: fixed; top: 0; left: 0; bottom: 0; z-index: 200; overflow-y: auto; }
        .ojs-sidebar-header { padding: 18px 16px 12px; border-bottom: 1px solid rgba(255,255,255,0.1); }
        .ojs-sidebar-header .context-name { font-size: 14px; font-weight: 600; color: #fff; text-decoration: none; display: block; line-height: 1.3; }
        .ojs-sidebar-header .context-name:hover { color: #90caf9; }
        .ojs-sidebar-nav { flex: 1; padding: 8px 0; }
        .ojs-sidebar-nav ul { list-style: none; margin: 0; padding: 0; }
        .ojs-sidebar-nav li { margin: 0; }
        .ojs-sidebar-nav .nav-group-label { display: block; padding: 10px 20px 4px; font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.5); text-transform: uppercase; letter-spacing: 0.5px; }
        .ojs-sidebar-nav a { display: block; padding: 9px 20px; color: rgba(255,255,255,0.85); text-decoration: none; font-size: 13px; transition: all 0.15s; border-left: 3px solid transparent; }
        .ojs-sidebar-nav a:hover { background: rgba(255,255,255,0.08); color: #fff; border-left-color: rgba(255,255,255,0.3); }
        .ojs-sidebar-nav a.active { background: rgba(255,255,255,0.12); color: #fff; border-left-color: #90caf9; font-weight: 600; }
        .ojs-sidebar-nav a .nav-icon { margin-right: 8px; font-size: 14px; opacity: 0.8; }
        .ojs-sidebar-nav .nav-divider { height: 1px; background: rgba(255,255,255,0.08); margin: 8px 16px; }
        .ojs-sidebar-nav .nav-submenu { list-style: none; margin: 0; padding: 0; }
        .ojs-sidebar-nav .nav-submenu a { padding: 7px 20px 7px 40px; font-size: 12px; color: rgba(255,255,255,0.65); }
        .ojs-sidebar-nav .nav-submenu a:hover { color: rgba(255,255,255,0.9); background: rgba(255,255,255,0.05); }
        .ojs-sidebar-toggle { display: none; position: fixed; top: 10px; left: 10px; z-index: 300; background: #002b5c; color: #fff; border: none; padding: 8px 12px; border-radius: 5px; cursor: pointer; font-size: 16px; }

        @media (max-width: 900px) {
            .ojs-sidebar { transform: translateX(-100%); transition: transform 0.3s; }
            .ojs-sidebar.open { transform: translateX(0); }
            .ojs-sidebar-toggle { display: block; }
            .page-wrapper { margin-left: 0 !important; }
        }

        .page-wrapper { margin-left: 220px; flex: 1; display: flex; flex-direction: column; min-height: 100vh; width: calc(100% - 220px); }

        .main-content { flex: 1; display: flex; flex-direction: column; max-width: 1200px; width: 100%; margin: 0 auto; padding: 15px; }
        
        /* Header */
        .header-bar { background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%); color: white; padding: 12px 20px; border-radius: 10px; margin-bottom: 15px; flex-shrink: 0; }
        .back-link { margin-bottom: 8px; }
        .back-link a { color: rgba(255,255,255,0.8); text-decoration: none; font-size: 12px; display: inline-flex; align-items: center; gap: 5px; }
        .back-link a:hover { color: white; }
        .header-top { display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; }
        .header-title { font-size: 18px; font-weight: 600; display: flex; align-items: center; gap: 10px; }
        .header-actions { display: flex; gap: 8px; align-items: center; }
        .lang-btn { padding: 5px 12px; border: 1px solid rgba(255,255,255,0.4); background: transparent; color: white; cursor: pointer; font-size: 12px; border-radius: 4px; transition: all 0.2s; font-weight: 500; }
        .lang-btn:hover { background: rgba(255,255,255,0.15); }
        .lang-btn.active { background: rgba(255,255,255,0.25); border-color: white; }
        .btn { padding: 8px 16px; border: none; border-radius: 5px; cursor: pointer; font-size: 12px; font-weight: 500; transition: all 0.2s; display: inline-flex; align-items: center; gap: 5px; }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; }
        .btn-light { background: rgba(255,255,255,0.9); color: #1e3c72; }
        .btn-light:hover:not(:disabled) { background: white; }
        .btn-success { background: #28a745; color: white; }
        .btn-success:hover:not(:disabled) { background: #218838; }
        .btn-warning { background: #ffc107; color: #333; }
        .btn-info { background: #17a2b8; color: white; }
        .btn-info:hover { background: #138496; }
        
        /* Dashboard Cards */
        .dashboard { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 10px; margin-bottom: 15px; flex-shrink: 0; }
        .dash-card { background: white; border-radius: 10px; padding: 12px; text-align: center; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        .dash-card .icon { font-size: 20px; margin-bottom: 3px; }
        .dash-card .value { font-size: 24px; font-weight: 700; color: #333; }
        .dash-card .label { font-size: 10px; color: #666; margin-top: 2px; }
        .dash-card.sync { border-left: 4px solid #17a2b8; }
        .dash-card.dbfix { border-left: 4px solid #6f42c1; }
        .dash-card.missing { border-left: 4px solid #ff9800; }
        .dash-card.update { border-left: 4px solid #2196f3; }
        .dash-card.available { border-left: 4px solid #4caf50; }
        .dash-card.downgrade { border-left: 4px solid #f44336; }
        .dash-card.info { border-left: 4px solid #607d8b; }
        .dash-card.installed { border-left: 4px solid #3f51b5; }
        .dash-card.active { border-left: 4px solid #009688; }
        .dash-card.inactive { border-left: 4px solid #9e9e9e; }
        
        /* Alert */
        .alert { padding: 10px 15px; border-radius: 8px; margin-bottom: 12px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; flex-shrink: 0; }
        .alert-warning { background: #fff3cd; border: 1px solid #ffc107; }
        .alert-text { font-size: 12px; color: #856404; }
        
        /* Tabs Container - fills remaining space */
        .tabs-container { background: white; border-radius: 10px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); display: flex; flex-direction: column; flex: 1; min-height: 0; overflow: hidden; }
        
        /* Tab Headers - Two-row design */
        .tabs-header {
            background: #f8f9fa;
            border-bottom: 3px solid #e9ecef;
            flex-shrink: 0;
            padding: 0;
        }
        .tab-row {
            display: flex;
            flex-wrap: wrap;
            align-items: stretch;
            justify-content: center;
            gap: 0;
        }
        .tab-row-main {
            border-bottom: 1px solid #e2e6ea;
        }
        .tab-row-secondary {
            background: #f0f2f5;
        }
        .tab-row-secondary:empty {
            display: none;
        }
        .tab-row-label {
            padding: 5px 10px;
            font-size: 9px;
            font-weight: 700;
            color: #9e9e9e;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            display: flex;
            align-items: center;
            user-select: none;
        }
        .tab-btn {
            padding: 10px 14px;
            border: none;
            background: transparent;
            cursor: pointer;
            font-size: 12.5px;
            font-weight: 600;
            color: #6c757d;
            white-space: nowrap;
            display: flex;
            align-items: center;
            gap: 5px;
            transition: all 0.2s;
            border-bottom: 3px solid transparent;
            margin-bottom: -3px;
            position: relative;
        }
        .tab-row-secondary .tab-btn {
            padding: 7px 12px;
            font-size: 11.5px;
            font-weight: 500;
            margin-bottom: -1px;
            border-bottom-width: 2px;
        }
        .tab-btn:hover {
            background: #e9ecef;
            color: #495057;
        }
        .tab-btn.active {
            color: #1e3c72;
            background: white;
            border-bottom-color: #1e3c72;
        }
        .tab-btn .badge {
            background: #dee2e6;
            color: #495057;
            padding: 1px 7px;
            border-radius: 10px;
            font-size: 10px;
            font-weight: 700;
            min-width: 18px;
            text-align: center;
        }
        .tab-btn .badge.badge-zero {
            background: #c8e6c9;
            color: #2e7d32;
        }
        .tab-btn .badge.badge-alert {
            background: #f44336;
            color: white;
        }
        .tab-btn.active .badge {
            background: #1e3c72;
            color: white;
        }
        .tab-btn.active .badge.badge-zero {
            background: #4caf50;
            color: white;
        }

        /* Mobile responsive tabs */
        @media (max-width: 768px) {
            .tab-btn {
                padding: 8px 8px;
                font-size: 11px;
            }
            .tab-row-secondary .tab-btn {
                padding: 6px 8px;
                font-size: 10px;
            }
            .tab-btn .badge {
                padding: 1px 5px;
                font-size: 9px;
            }
        }
        
        /* Tab Content - scrollable */
        .tabs-content-wrapper { flex: 1; overflow: hidden; display: flex; flex-direction: column; min-height: 0; }
        .tab-content { display: none; flex-direction: column; height: 100%; overflow: hidden; }
        .tab-content.active { display: flex; }
        
        /* Table */
        .table-controls { padding: 10px 15px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; background: #fafafa; flex-shrink: 0; }
        .search-input { padding: 8px 12px; border: 1px solid #ddd; border-radius: 5px; font-size: 13px; width: 220px; max-width: 100%; }
        .search-input:focus { outline: none; border-color: #1e3c72; }
        .select-all { font-size: 12px; display: flex; align-items: center; gap: 6px; cursor: pointer; }
        .select-all input { width: 16px; height: 16px; }
        
        .filter-btns { display: flex; gap: 5px; }
        .filter-btn { padding: 5px 12px; border: 1px solid #ddd; background: white; cursor: pointer; font-size: 11px; border-radius: 4px; transition: all 0.2s; }
        .filter-btn:hover { background: #f0f0f0; }
        .filter-btn.active { background: #1e3c72; color: white; border-color: #1e3c72; }
        
        .status-text.gray { color: #757575; }
        
        /* DB Fix Tab */
        .dbfix-info { background: #fff3cd; border: 1px solid #ffc107; padding: 10px 15px; border-radius: 6px; margin-bottom: 12px; font-size: 12px; color: #856404; }
        .tab-description { background: #e3f2fd; border: 1px solid #90caf9; padding: 10px 15px; border-radius: 6px; margin: 10px 15px; font-size: 12px; color: #1565c0; line-height: 1.5; }
        .btn-fix { background: #6f42c1; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 11px; font-weight: 500; transition: all 0.2s; }
        .btn-fix:hover { background: #5a32a3; }
        .btn-fix:disabled { opacity: 0.7; cursor: not-allowed; }
        .btn-fix.btn-success { background: #28a745; }
        .btn-fix.btn-danger { background: #dc3545; }
        .btn-install { background: #17a2b8; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 11px; font-weight: 500; transition: all 0.2s; }
        .btn-install:hover { background: #138496; }
        .btn-install:disabled { opacity: 0.7; cursor: not-allowed; }
        .btn-install.btn-success { background: #28a745; }
        .btn-danger-sm { background: #dc3545; color: white; border: none; padding: 6px 14px; border-radius: 4px; cursor: pointer; font-size: 11px; font-weight: 500; transition: all 0.2s; }
        .btn-danger-sm:hover { background: #c82333; }
        .btn-danger-sm:disabled { opacity: 0.7; cursor: not-allowed; }
        .badge-red { background: #dc3545; color: white; }
        .badge-orange { background: #fd7e14; color: white; }
        .col-action { width: 100px; text-align: center; }
        
        /* Sync issue row highlight */
        .sync-issue-row { background: #fff3cd !important; }
        .sync-issue-row:hover { background: #ffe8a1 !important; }
        .missing-file-row { background: #f8d7da !important; }
        .missing-file-row:hover { background: #f1b0b7 !important; }
        .status-text.orange { color: #fd7e14; }
        
        .table-wrapper { flex: 1; overflow: auto; min-height: 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid #eee; font-size: 12px; }
        th { background: #f8f9fa; font-weight: 600; color: #333; position: sticky; top: 0; z-index: 1; }
        tr:hover { background: #f8f9fa; }
        tr.updating { background: #fff3cd; animation: pulse 1s infinite; }
        tr.updated { background: #d4edda; }
        tr.error { background: #f8d7da; }
        
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.7; } }
        
        .col-check { width: 40px; text-align: center; }
        .col-plugin { min-width: 140px; }
        .col-cat { width: 80px; }
        .col-ver { width: 70px; }
        .col-desc { min-width: 180px; }
        .col-status { width: 100px; }
        
        .plugin-name { font-weight: 600; color: #333; display: block; }
        .plugin-id { font-size: 10px; color: #888; }
        .plugin-desc { font-size: 11px; color: #666; display: block; max-width: 280px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        
        .badge { display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 10px; font-weight: 600; font-family: monospace; }
        .badge-purple { background: #f3e5f5; color: #7b1fa2; }
        .badge-orange { background: #fff3e0; color: #e65100; }
        .badge-blue { background: #e3f2fd; color: #1565c0; }
        .badge-green { background: #e8f5e9; color: #2e7d32; }
        .badge-red { background: #ffebee; color: #c62828; }
        .badge-gray { background: #eceff1; color: #546e7a; }
        
        .status-text { font-size: 11px; }
        .status-text.purple { color: #7b1fa2; }
        .status-text.orange { color: #e65100; }
        .status-text.green { color: #2e7d32; }
        .status-text.red { color: #c62828; }
        .status-text.blue { color: #1565c0; }
        
        .spinner { display: inline-block; width: 14px; height: 14px; border: 2px solid #ddd; border-top-color: #1e3c72; border-radius: 50%; animation: spin 0.8s linear infinite; }
        @keyframes spin { to { transform: rotate(360deg); } }
        
        /* Progress Modal */
        .progress-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0,0,0,0.7); display: none; justify-content: center; align-items: center; z-index: 1000; }
        .progress-overlay.show { display: flex; }
        .progress-modal { background: white; border-radius: 15px; padding: 30px; width: 90%; max-width: 400px; text-align: center; }
        .progress-title { font-size: 16px; font-weight: 600; margin-bottom: 20px; color: #333; }
        .progress-bar-bg { background: #e0e0e0; border-radius: 10px; height: 20px; overflow: hidden; margin-bottom: 12px; }
        .progress-bar { height: 100%; background: linear-gradient(90deg, #1e3c72, #2a5298); transition: width 0.3s; display: flex; align-items: center; justify-content: center; color: white; font-size: 11px; font-weight: 600; }
        .progress-info { font-size: 13px; color: #666; margin-bottom: 8px; }
        .progress-current { font-size: 11px; color: #999; }
        .progress-counters { display: flex; justify-content: center; gap: 30px; margin-top: 15px; }
        .counter { text-align: center; }
        .counter-value { font-size: 24px; font-weight: 700; }
        .counter-value.success { color: #4caf50; }
        .counter-value.error { color: #f44336; }
        .counter-label { font-size: 10px; color: #666; }
        
        /* Completed Section - Üstte */
        .completed-section { margin-bottom: 12px; background: white; border-radius: 10px; overflow: hidden; display: none; flex-shrink: 0; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        .completed-section.show { display: block; }
        .completed-header { padding: 10px 15px; background: #e8f5e9; font-weight: 600; font-size: 12px; color: #2e7d32; display: flex; align-items: center; gap: 8px; }
        .completed-list { max-height: 120px; overflow-y: auto; padding: 8px; }
        .completed-item { display: flex; align-items: center; gap: 8px; padding: 6px 10px; border-radius: 4px; margin-bottom: 4px; font-size: 11px; }
        .completed-item.success { background: #f1f8e9; }
        .completed-item.error { background: #ffebee; }
        .completed-item .name { font-weight: 500; flex: 1; }
        .completed-item .result { font-size: 10px; color: #666; }
        
        /* Empty / Loading */
        .empty-state { padding: 50px 20px; text-align: center; color: #666; }
        .empty-state .icon { font-size: 40px; margin-bottom: 10px; }
        .empty-state h3 { color: #333; margin-bottom: 5px; }
        .loading-state { padding: 50px 20px; text-align: center; }
        .loading-state .spinner { width: 35px; height: 35px; border-width: 3px; margin-bottom: 10px; }
        
        /* Sticky Footer */
        .footer { position: fixed; bottom: 0; left: 220px; right: 0; background: white; border-top: 1px solid #e0e0e0; padding: 8px; text-align: center; font-size: 11px; color: #888; z-index: 100; }
        .footer a { color: #1e3c72; text-decoration: none; font-weight: 500; }
        .footer a:hover { text-decoration: underline; }
        @media (max-width: 900px) { .footer { left: 0; } }
        
        /* Body padding for fixed footer */
        body { padding-bottom: 40px; }
        
        /* Info Page Styles */
        .info-page { padding: 20px; max-width: 900px; margin: 0 auto; }
        .info-header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0; }
        .info-header h2 { color: #1e3c72; margin: 0 0 10px 0; font-size: 24px; }
        .info-subtitle { color: #666; font-size: 14px; margin: 0; }
        
        .info-section { margin-bottom: 30px; background: #f8f9fa; border-radius: 10px; padding: 20px; }
        .info-section h3 { color: #1e3c72; margin: 0 0 15px 0; font-size: 16px; padding-bottom: 10px; border-bottom: 1px solid #e0e0e0; }
        
        .info-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(250px, 1fr)); gap: 15px; }
        .info-item { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
        .info-item .info-icon { font-size: 20px; margin-right: 8px; }
        .info-item strong { color: #333; font-size: 14px; }
        .info-item p { margin: 8px 0 0 0; font-size: 12px; color: #666; line-height: 1.5; }
        
        .info-list { display: flex; flex-direction: column; gap: 12px; }
        .info-list-item { display: flex; align-items: flex-start; gap: 15px; background: white; padding: 12px 15px; border-radius: 8px; }
        .info-list-item .info-badge { min-width: 140px; padding: 6px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; background: #e3f2fd; color: #1565c0; white-space: nowrap; }
        .info-list-item .filter-badge { background: #fff3e0; color: #e65100; }
        .info-list-item p { margin: 0; font-size: 13px; color: #555; line-height: 1.5; flex: 1; }
        
        .info-btn { display: inline-block; padding: 6px 14px; border-radius: 4px; font-size: 11px; font-weight: 500; color: white; }
        .info-btn.btn-fix { background: #6f42c1; }
        .info-btn.btn-danger-sm { background: #dc3545; }
        .info-btn.btn-install { background: #17a2b8; }
        .info-btn.btn-update { background: #28a745; }
        
        .info-problems { display: flex; flex-direction: column; gap: 15px; }
        .info-problem { background: white; padding: 15px; border-radius: 8px; border-left: 4px solid #ff9800; }
        .info-problem h4 { margin: 0 0 10px 0; color: #e65100; font-size: 14px; }
        .info-problem p { margin: 5px 0; font-size: 12px; color: #555; line-height: 1.5; }
        .info-problem strong { color: #333; }
        
        .info-tech { background: white; padding: 15px; border-radius: 8px; }
        .info-tech p { margin: 8px 0; font-size: 12px; color: #555; line-height: 1.6; padding-left: 20px; position: relative; }
        .info-tech p:before { content: "•"; position: absolute; left: 5px; color: #1e3c72; }
        
        .tab-info { background: #e8f5e9 !important; color: #2e7d32 !important; border-right: none !important; }
        .tab-info:hover { background: #c8e6c9 !important; }
        .tab-info.active { background: #4caf50 !important; color: white !important; }

        /* OJS Services Tab */
        .tab-ojs-services { background: #fff3e0 !important; color: #e65100 !important; }
        .tab-ojs-services:hover { background: #ffe0b2 !important; }
        .tab-ojs-services.active { background: #ff9800 !important; color: white !important; border-bottom-color: #ff9800 !important; }
        .tab-ojs-services.active .badge { background: white !important; color: #e65100 !important; }

        .ojs-services-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 16px; padding: 16px; overflow-y: auto; }
        .ojs-service-card { background: white; border-radius: 10px; border: 1px solid #e0e0e0; padding: 18px; transition: all 0.2s; display: flex; flex-direction: column; }
        .ojs-service-card:hover { box-shadow: 0 4px 12px rgba(0,0,0,0.1); border-color: #ff9800; }
        .ojs-service-card .card-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px; }
        .ojs-service-card .card-title { font-size: 14px; font-weight: 700; color: #333; }
        .ojs-service-card .card-product { font-size: 11px; color: #888; font-family: monospace; }
        .ojs-service-card .card-status { padding: 3px 10px; border-radius: 12px; font-size: 10px; font-weight: 600; white-space: nowrap; }
        .ojs-service-card .card-status.available { background: #e3f2fd; color: #1565c0; }
        .ojs-service-card .card-status.installed { background: #e8f5e9; color: #2e7d32; }
        .ojs-service-card .card-status.update { background: #fff3e0; color: #e65100; }
        .ojs-service-card .card-status.incompatible { background: #ffebee; color: #c62828; }
        .ojs-service-card .card-desc { font-size: 12px; color: #555; line-height: 1.5; flex: 1; margin-bottom: 12px; }
        .ojs-service-card .card-versions { display: flex; gap: 8px; margin-bottom: 12px; flex-wrap: wrap; }
        .ojs-service-card .card-ver { font-size: 10px; padding: 3px 8px; border-radius: 4px; }
        .ojs-service-card .card-ver.repo { background: #e8f5e9; color: #2e7d32; }
        .ojs-service-card .card-ver.local { background: #e3f2fd; color: #1565c0; }
        .ojs-service-card .card-actions { display: flex; gap: 8px; align-items: center; }
        .ojs-service-card .card-actions a { font-size: 11px; color: #1e3c72; text-decoration: none; }
        .ojs-service-card .card-actions a:hover { text-decoration: underline; }
        .btn-ojs-install { background: #ff9800; color: white; border: none; padding: 7px 16px; border-radius: 5px; cursor: pointer; font-size: 12px; font-weight: 600; transition: all 0.2s; }
        .btn-ojs-install:hover:not(:disabled) { background: #f57c00; }
        .btn-ojs-install:disabled { opacity: 0.6; cursor: not-allowed; }
        .btn-ojs-install.success { background: #4caf50; }
        .btn-ojs-update { background: #2196f3; color: white; border: none; padding: 7px 16px; border-radius: 5px; cursor: pointer; font-size: 12px; font-weight: 600; transition: all 0.2s; }
        .btn-ojs-update:hover:not(:disabled) { background: #1976d2; }
        .btn-ojs-update:disabled { opacity: 0.6; cursor: not-allowed; }
        .ojs-services-header { padding: 16px; background: linear-gradient(135deg, #ff9800 0%, #f57c00 100%); color: white; border-radius: 8px; margin: 12px 16px; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px; }
        .ojs-services-header h3 { margin: 0; font-size: 15px; font-weight: 600; }
        .ojs-services-header p { margin: 4px 0 0; font-size: 12px; opacity: 0.9; }
        .ojs-services-loading { padding: 40px; text-align: center; color: #666; }
    </style>
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
                        <li><a href="{url page="stats" op="articles"}"><span class="nav-icon">📊</span> <span data-i18n="navStatsArticles">Articles</span></a></li>
                        <li><a href="{url page="stats" op="editorial"}"><span class="nav-icon">✏️</span> <span data-i18n="navStatsEditorial">Editorial Activity</span></a></li>
                        <li><a href="{url page="stats" op="users"}"><span class="nav-icon">👤</span> <span data-i18n="navStatsUsers">Users</span></a></li>
                        <li><a href="{url page="stats" op="reports"}"><span class="nav-icon">📋</span> <span data-i18n="navStatsReports">Reports</span></a></li>
                    </ul>
                </li>

                <li><a href="{url page="management" op="tools"}"><span class="nav-icon">🔨</span> <span data-i18n="navTools">Tools</span></a></li>
                <li><a href="{url page="admin"}"><span class="nav-icon">🛡️</span> <span data-i18n="navAdministration">Administration</span></a></li>

                <li><div class="nav-divider"></div></li>
                <li><a href="{url page="certificatepro" op="manageCertificates"}"><span class="nav-icon">📄</span> Certificates Pro</a></li>
                <li><a href="{url page="bulkPluginManager"}" class="active"><span class="nav-icon">🔌</span> Bulk Plugin Manager</a></li>
                <li><a href="{url page="submitai-settings"}"><span class="nav-icon">🤖</span> SubmitAI</a></li>
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
        <span data-i18n="version">Version</span> 1.8.0 ·
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
            infoTabMissing: 'Plugins that exist in database but their files are deleted from server. Choose "Install" to re-download or "Clean DB" to remove database entries.',
            infoTabUpdate: 'Plugins that have newer versions available in the Gallery. Select and click "Process Selected" to update.',
            infoTabAvailable: 'New plugins from PKP Gallery that are compatible with your OJS version and not yet installed.',
            infoTabDowngrade: 'Your installed version is newer than Gallery version. Usually safe to ignore - you might have a beta/dev version.',
            infoTabNotInGallery: 'Custom or third-party plugins not found in PKP Gallery. These might be manually installed or from other sources.',
            infoFiltersTitle: 'Installed Tab Filters',
            infoFilterAll: 'Shows all installed plugins without any filter.',
            infoFilterActive: 'Shows only plugins that are currently enabled.',
            infoFilterInactive: 'Shows only plugins that are currently disabled.',
            infoFilterSync: 'Shows plugins where DB version doesn\'t match File version. These need to be fixed.',
            infoFilterMissing: 'Shows plugins that have database records but no files on server. Need reinstall or cleanup.',
            infoButtonsTitle: 'Action Buttons',
            infoButtonFix: 'Updates the database version to match the file version. Use when DB and File versions are different. This fixes "current=0" issues and OJS plugin page crashes.',
            infoButtonClean: 'Removes all database entries for the plugin (versions table and plugin_settings). Use when plugin files are deleted but database records remain.',
            infoButtonInstall: 'Downloads the plugin from PKP Gallery and installs it. Use for missing files or new plugins.',
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
            tabDesc_installedList: 'Shows all plugins registered in your database. Displays DB version, File version, and status (active/inactive). You can filter by status or find sync issues.',
            tabDesc_dbFix: 'Lists plugins where DB version is higher than Gallery. Usually happens after failed updates or manual DB edits. Click "Fix DB" to sync.',
            tabDesc_syncIssue: 'Plugins where DB version differs from File version. This can prevent OJS plugin page from loading. Requires synchronization.',
            tabDesc_missing: 'Plugins exist in database but files are deleted from server. Choose "Install" to re-download or "Clean DB" to remove database entries.',
            tabDesc_updatable: 'Plugins with newer versions available in Gallery. Select and click "Process Selected" to update.',
            tabDesc_available: 'New plugins from PKP Gallery compatible with your OJS version and not yet installed.',
            tabDesc_downgrade: 'Your installed version is newer than Gallery version. Usually safe to ignore - you might have a beta/dev version.',
            tabDesc_notInGallery: 'Custom or third-party plugins not found in PKP Gallery. These might be manually installed or from other sources.',
            noItemsDesc_downgrade: 'No plugins have newer versions than the Gallery. Everything is normal.',
            noItemsDesc_notInGallery: 'All installed plugins are available in the PKP Gallery.',
            tabOjsServices: 'OJS Services',
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
            tabDesc_notInGallery: 'PKP Gallery\'de bulunamayan özel veya üçüncü taraf eklentiler. Manuel olarak kurulmuş veya başka kaynaklardan gelmiş olabilir.',
            
            // New Translations
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
            infoTabMissing: 'Veritabanı var ama dosyaları sunucudan silinmiş eklentiler. Yeniden indirmek için "Yükle" veya DB kayıtlarını silmek için "DB Temizle" seçin.',
            infoTabUpdate: 'Gallery\'de daha yeni versiyonları bulunan eklentiler. Seçip "Seçilenleri İşle" ile güncelleyin.',
            infoTabAvailable: 'PKP Gallery\'den OJS versiyonunuzla uyumlu ve henüz kurulmamış yeni eklentiler.',
            infoTabDowngrade: 'Kurulu versiyonunuz Gallery versiyonundan daha yeni. Genellikle güvenle göz ardı edilebilir - beta/geliştirme versiyonunuz olabilir.',
            infoTabNotInGallery: 'PKP Gallery\'de bulunamayan özel veya üçüncü taraf eklentiler. Manuel olarak kurulmuş veya başka kaynaklardan gelmiş olabilir.',
            infoFiltersTitle: 'Kurulu Tab Filtreleri',
            infoFilterAll: 'Tüm kurulu eklentileri filtresiz gösterir.',
            infoFilterActive: 'Sadece şu anda etkin olan eklentileri gösterir.',
            infoFilterInactive: 'Sadece şu anda devre dışı olan eklentileri gösterir.',
            infoFilterSync: 'DB versiyonu Dosya versiyonuyla eşleşmeyen eklentileri gösterir. Bunların düzeltilmesi gerekir.',
            infoFilterMissing: 'Veritabanı kaydı olan ama sunucuda dosyası olmayan eklentileri gösterir. Yeniden kurulum veya temizlik gerekir.',
            infoButtonsTitle: 'İşlem Butonları',
            infoButtonFix: 'Veritabanı versiyonunu dosya versiyonuyla eşitler. DB ve Dosya versiyonları farklı olduğunda kullanın. "current=0" sorunlarını ve OJS eklenti sayfası çökmelerini düzeltir.',
            infoButtonClean: 'Eklentinin tüm veritabanı kayıtlarını siler (versions tablosu ve plugin_settings). Eklenti dosyaları silinmiş ama veritabanı kayıtları kalmışsa kullanın.',
            infoButtonInstall: 'Eklentiyi PKP Gallery\'den indirir ve kurar. Eksik dosyalar veya yeni eklentiler için kullanın.',
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
            tabDesc_installedList: 'Veritabanınızda kayıtlı tüm eklentileri gösterir. DB versiyonu, Dosya versiyonu ve durum (aktif/pasif) bilgilerini içerir. Duruma göre filtreleyebilir veya senkron sorunlarını bulabilirsiniz.',
            tabDesc_dbFix: 'DB versiyonu Gallery versiyonundan yüksek olan eklentileri listeler. Bu genellikle başarısız güncellemeler veya manuel DB değişikliklerinden sonra olur. "DB Düzelt" ile senkronize edin.',
            tabDesc_syncIssue: 'DB versiyonu Dosya versiyonundan farklı olan eklentiler. Bu durum OJS eklenti sayfasının yüklenmesini engelleyebilir. Senkronizasyon gerektirir.',
            tabDesc_missing: 'Veritabanında var ama dosyaları sunucudan silinmiş eklentiler. Yeniden indirmek için "Yükle" veya DB kayıtlarını silmek için "DB Temizle" seçin.',
            tabDesc_updatable: 'Gallery\'de daha yeni versiyonları bulunan eklentiler. Seçip "Seçilenleri İşle" ile güncelleyin.',
            tabDesc_available: 'PKP Gallery\'den OJS versiyonunuzla uyumlu ve henüz kurulmamış yeni eklentiler.',
            tabDesc_downgrade: 'Kurulu versiyonunuz Gallery versiyonundan daha yeni. Genellikle güvenle göz ardı edilebilir - beta/geliştirme versiyonunuz olabilir.',
            tabDesc_notInGallery: 'PKP Gallery\'de bulunamayan özel veya üçüncü taraf eklentiler. Manuel olarak kurulmuş veya başka kaynaklardan gelmiş olabilir.',
            
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
            tabOjsServices: 'OJS Services',
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
    var data = {};
    var processing = false;
    var processedProducts = {};
    var activeTab = '';
    var ojsVersion = '';
    var galleryCount = 0;
    var installed = { total: 0, active: 0, inactive: 0 };
    
    function t(key) { return i18n[currentLang][key] || key; }
    
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
                        document.getElementById('tabsContent').innerHTML = '<div class="empty-state"><p style="color:red;">Error: ' + result.message + '</p></div>';
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
                    document.getElementById('tabsContent').innerHTML = '<div class="empty-state"><p style="color:red;">JSON Error: ' + e.message + '</p></div>';
                }
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
            { key: 'notInGallery', icon: '❓', label: 'tabNotInGallery', selectable: false, group: 'other' },
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

            var tabExtraClass = tab.key === 'ojsServices' ? ' tab-ojs-services' : '';
            var btnHtml = '<button class="tab-btn' + tabExtraClass + '" data-tab="' + tab.key + '" onclick="setActiveTab(\'' + tab.key + '\')">' +
                tab.icon + ' ' + t(tab.label) + ' <span class="badge ' + badgeClass + '">' + count + '</span></button>';

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
            if (xhr.readyState === 4) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('fixed');
                        btn.classList.add('btn-success');
                        row.style.background = '#d4edda';
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
                }
            }
        };
        xhr.send('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=dbfix');
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
        
        h += '<div class="table-wrapper"><table><thead><tr>';
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
            
            if (p.fileVersion === '-') {
                fileBadgeClass = 'badge-orange';
                rowClass = 'missing-file-row';
            }
            
            h += '<tr id="installed-row-' + escapeHtml(p.product) + '" class="' + rowClass + '" data-search="' + escapeHtml((p.displayName + ' ' + p.product).toLowerCase()) + '" data-status="' + (p.enabled ? 'active' : 'inactive') + '" data-sync="' + (hasSyncIssue ? 'yes' : 'no') + '" data-missing="' + (p.fileVersion === '-' ? 'yes' : 'no') + '">';
            h += '<td class="col-plugin"><span class="plugin-name">' + escapeHtml(p.displayName) + '</span><span class="plugin-id">' + escapeHtml(p.product) + '</span></td>';
            h += '<td class="col-cat"><span class="badge badge-gray">' + escapeHtml(p.category) + '</span></td>';
            h += '<td class="col-ver"><span class="badge ' + dbBadgeClass + '">' + escapeHtml(p.dbVersion) + '</span></td>';
            h += '<td class="col-ver"><span class="badge ' + fileBadgeClass + '">' + escapeHtml(p.fileVersion) + '</span></td>';
            h += '<td class="col-status"><span class="status-text ' + statusClass + '">' + statusIcon + ' ' + statusText + '</span></td>';
            
            // Fix button for sync issues
            if (hasSyncIssue && p.fileVersion !== '-') {
                h += '<td class="col-action"><button class="btn btn-fix" onclick="fixInstalledDbVersion(\'' + escapeHtml(p.product) + '\', \'' + escapeHtml(p.category) + '\', \'' + escapeHtml(p.fileVersion) + '\')">' + t('btnFix') + '</button></td>';
            } else if (p.fileVersion === '-') {
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
    
    function fixInstalledDbVersion(product, category, fileVersion) {
        var btn = event.target;
        var row = document.getElementById('installed-row-' + product);
        btn.disabled = true;
        btn.innerHTML = '⏳ ' + t('fixing');
        
        var xhr = new XMLHttpRequest();
        xhr.open('POST', '{url page="bulkPluginManager" op="updatePlugin"}', true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('fixed');
                        btn.classList.remove('btn-fix');
                        btn.classList.add('btn-success');
                        row.classList.remove('sync-issue-row');
                        row.style.background = '#d4edda';
                        // Update DB version cell to show file version
                        var cells = row.querySelectorAll('td');
                        if (cells[2]) {
                            cells[2].innerHTML = '<span class="badge badge-blue">' + fileVersion + '</span>';
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
                }
            }
        };
        xhr.send('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=dbfix');
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
            if (xhr.readyState === 4) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('installed');
                        btn.classList.remove('btn-install');
                        btn.classList.add('btn-success');
                        row.classList.remove('missing-file-row');
                        row.style.background = '#d4edda';
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.classList.add('btn-danger');
                        btn.disabled = false;
                        alert(result.message || 'Install failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                }
            }
        };
        xhr.send('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=install');
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
            if (xhr.readyState === 4) {
                try {
                    var result = JSON.parse(xhr.responseText);
                    if (result.status === 'success') {
                        btn.innerHTML = '✅ ' + t('cleaned');
                        btn.classList.remove('btn-danger-sm');
                        btn.classList.add('btn-success');
                        row.style.opacity = '0.5';
                        row.style.background = '#d4edda';
                    } else {
                        btn.innerHTML = '❌ ' + t('error');
                        btn.disabled = false;
                        alert(result.message || 'Clean failed');
                    }
                } catch(e) {
                    btn.innerHTML = '❌ ' + t('error');
                    btn.disabled = false;
                }
            }
        };
        xhr.send('product=' + encodeURIComponent(product) + '&category=' + encodeURIComponent(category) + '&action=cleandb');
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
                else p._action = 'update';
                selected.push(p);
            }
        });
        return selected;
    }
    
    function processSelected() {
        var selected = getSelectedPlugins();
        if (selected.length === 0) return;
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
                // Refresh list if backup was restored or deleted
                if (currentAction === 'restore' || currentAction === 'delete_backup') {
                    setTimeout(function() { loadPlugins(); }, 1000);
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
                if (xhr.readyState === 4) {
                    done++;
                    var success = false, errorMsg = '';
                    
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
                            if (st) st.innerHTML = '<span class="status-text red">✗ ' + errorMsg + '</span>';
                        }
                    } catch(e) {
                        fail++; errorMsg = 'Error';
                        if (row) { row.classList.remove('updating'); row.classList.add('error'); }
                        if (st) st.innerHTML = '<span class="status-text red">✗ Error</span>';
                    }
                    
                    addToCompleted(p, success, errorMsg);
                    updateProgress();
                    setTimeout(function() { next(i + 1); }, 300);
                }
            };
            
            var params = 'product=' + encodeURIComponent(p.product) + '&category=' + encodeURIComponent(p.category) + '&action=' + encodeURIComponent(p._action || 'update');
            if (p.backupId) params += '&backupId=' + encodeURIComponent(p.backupId);
            
            xhr.send(params);
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
                        if (badge) badge.textContent = ojsServicesData.length;
                    } else {
                        content.innerHTML = '<div class="ojs-services-loading"><p style="color:red;">Error: ' + escapeHtml(result.message || 'Unknown error') + '</p></div>';
                    }
                } catch(e) {
                    content.innerHTML = '<div class="ojs-services-loading"><p style="color:red;">JSON Error: ' + escapeHtml(e.message) + '</p></div>';
                }
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
            if (xhr.readyState === 4) {
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
                    btn.textContent = '❌ Error';
                    btn.disabled = false;
                    setTimeout(function() { btn.textContent = origText; btn.disabled = false; }, 3000);
                }
            }
        };
        xhr.send('product=' + encodeURIComponent(product) + '&downloadUrl=' + encodeURIComponent(downloadUrl) + '&action=' + encodeURIComponent(action) + '&category=' + encodeURIComponent(category || 'generic'));
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
