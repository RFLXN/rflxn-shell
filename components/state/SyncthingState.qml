pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: root

    readonly property string defaultBaseUrl: "http://127.0.0.1:8384"
    readonly property string eventFilter: "FolderSummary,StateChanged,FolderWatchStateChanged,ConfigSaved"
    readonly property bool monitoringRequested: monitoringConsumerCount > 0
    readonly property bool visible: monitoringRequested && serviceRunning

    property int monitoringConsumerCount: 0
    property int generation: 0
    property int configCandidateIndex: 0
    property int networkStartGeneration: 0
    property int pendingSnapshotCount: 0
    property int lastEventId: 0
    property int retryDelayMs: 2000

    property bool serviceRunning: false
    property bool apiAvailable: false
    property bool loading: false
    property bool bootstrapped: false
    property bool configReady: false
    property bool configSearchActive: false
    property bool retryKeepsServiceRunning: false

    property string apiKey: ""
    property string baseUrl: defaultBaseUrl
    property string configPath: ""
    property string lastError: ""

    property var configCandidates: []
    property var activeRequests: []
    property var eventRequest: null
    property var folderConfigsById: ({})
    property var folderSummariesById: ({})
    property var folders: []

    function acquireMonitoring() {
        root.monitoringConsumerCount += 1;

        if (root.monitoringConsumerCount !== 1)
            return;

        root.serviceRunning = false;
        root.retryDelayMs = 2000;
        root.beginSession(false);
    }

    function releaseMonitoring() {
        root.monitoringConsumerCount = Math.max(0, root.monitoringConsumerCount - 1);

        if (root.monitoringConsumerCount === 0)
            root.stopSession();
    }

    function environmentValue(name) {
        return String(Quickshell.env(name) ?? "").trim();
    }

    function appendUniquePath(paths, path) {
        const value = String(path ?? "").replace(/\/+$/, "");

        if (value && !paths.includes(value))
            paths.push(value);
    }

    function buildConfigCandidates() {
        const candidates = [];
        const home = root.environmentValue("HOME");
        const syncthingConfigDir = root.environmentValue("STCONFDIR");
        const syncthingHome = root.environmentValue("STHOMEDIR");
        const stateHome = root.environmentValue("XDG_STATE_HOME") || (home ? `${home}/.local/state` : "");
        const configHome = root.environmentValue("XDG_CONFIG_HOME") || (home ? `${home}/.config` : "");

        if (syncthingConfigDir)
            root.appendUniquePath(candidates, `${syncthingConfigDir}/config.xml`);

        if (syncthingHome)
            root.appendUniquePath(candidates, `${syncthingHome}/config.xml`);

        if (stateHome)
            root.appendUniquePath(candidates, `${stateHome}/syncthing/config.xml`);

        if (configHome)
            root.appendUniquePath(candidates, `${configHome}/syncthing/config.xml`);

        return candidates;
    }

    function normalizeBaseUrl(address, useTls) {
        let value = String(address ?? "").trim().replace(/\/+$/, "");

        if (!value)
            return root.defaultBaseUrl;

        if (value.startsWith("/"))
            return "";

        if (/^https?:\/\//i.test(value))
            return value;

        if (value.startsWith("0.0.0.0:"))
            value = `127.0.0.1:${value.slice("0.0.0.0:".length)}`;
        else if (value.startsWith("[::]:"))
            value = `[::1]:${value.slice("[::]:".length)}`;
        else if (value.startsWith(":"))
            value = `127.0.0.1${value}`;

        return `${useTls ? "https" : "http"}://${value}`;
    }

    function parseConfig(text) {
        const source = String(text ?? "");
        const guiMatch = source.match(/<gui\b([^>]*)>([\s\S]*?)<\/gui>/i);

        if (!guiMatch)
            return {
                apiKey: "",
                baseUrl: root.defaultBaseUrl
            };

        const attributes = guiMatch[1] ?? "";
        const body = guiMatch[2] ?? "";
        const addressMatch = body.match(/<address>\s*([^<]*?)\s*<\/address>/i);
        const apiKeyMatch = body.match(/<apikey>\s*([^<]*?)\s*<\/apikey>/i);
        const address = String(addressMatch?.[1] ?? "").trim();
        const apiKey = String(apiKeyMatch?.[1] ?? "").trim();
        const useTls = /\btls\s*=\s*["']true["']/i.test(attributes);

        return {
            apiKey,
            baseUrl: root.normalizeBaseUrl(address, useTls)
        };
    }

    function beginSession(keepServiceRunning) {
        if (!root.monitoringRequested)
            return;

        retryTimer.stop();
        rebootstrapTimer.stop();

        root.generation += 1;
        root.abortActiveRequests();

        if (!keepServiceRunning)
            root.serviceRunning = false;

        root.apiAvailable = false;
        root.loading = true;
        root.bootstrapped = false;
        root.lastError = "";
        root.lastEventId = 0;
        root.pendingSnapshotCount = 0;
        root.folderConfigsById = {};
        root.folderSummariesById = {};
        root.folders = [];
        root.networkStartGeneration = 0;
        configReloadTimer.stop();

        if (root.configReady && root.apiKey) {
            root.startConfiguredSession(root.generation);

            if (root.configPath) {
                configFile.reload();
            } else {
                root.ensureConfigSearch();
            }
        } else {
            if (root.configReady)
                root.configReady = false;

            root.ensureConfigSearch();
        }
    }

    function stopSession() {
        root.generation += 1;
        retryTimer.stop();
        rebootstrapTimer.stop();
        root.abortActiveRequests();

        root.loading = false;
        root.bootstrapped = false;
        root.apiAvailable = false;
        root.serviceRunning = false;
        root.networkStartGeneration = 0;
        root.folderConfigsById = {};
        root.folderSummariesById = {};
        root.folders = [];
        root.lastError = "";
    }

    function ensureConfigSearch() {
        if (root.configSearchActive)
            return;

        configReloadTimer.stop();
        configCandidateTimer.stop();
        root.configCandidates = root.buildConfigCandidates();
        root.configCandidateIndex = 0;
        root.configReady = false;
        root.configSearchActive = true;
        root.loadConfigCandidate();
    }

    function loadConfigCandidate() {
        if (!root.configSearchActive)
            return;

        if (root.configCandidateIndex >= root.configCandidates.length) {
            root.configSearchActive = false;
            root.configReady = true;
            root.configPath = "";

            if (!root.apiKey)
                root.baseUrl = root.defaultBaseUrl;

            if (root.monitoringRequested)
                root.startConfiguredSession(root.generation);

            return;
        }

        const nextPath = root.configCandidates[root.configCandidateIndex];

        if (root.configPath === nextPath) {
            configFile.reload();
        } else {
            root.configPath = nextPath;
        }
    }

    function handleConfigLoaded(text) {
        const config = root.parseConfig(text);
        const nextApiKey = config.apiKey;
        const nextBaseUrl = config.baseUrl || root.defaultBaseUrl;
        const credentialsChanged = root.apiKey !== nextApiKey || root.baseUrl !== nextBaseUrl;

        if (!nextApiKey) {
            if (root.configSearchActive) {
                root.configCandidateIndex += 1;
                configCandidateTimer.restart();
            } else {
                root.configReady = false;
                configReloadTimer.restart();
            }

            return;
        }

        root.apiKey = nextApiKey;
        root.baseUrl = nextBaseUrl;
        root.configReady = true;
        root.configSearchActive = false;

        if (!root.monitoringRequested)
            return;

        if (credentialsChanged && root.networkStartGeneration === root.generation) {
            root.beginSession(true);
            return;
        }

        root.startConfiguredSession(root.generation);
    }

    function handleConfigLoadFailed() {
        if (!root.configSearchActive) {
            root.configReady = false;
            configReloadTimer.restart();
            return;
        }

        root.configCandidateIndex += 1;
        configCandidateTimer.restart();
    }

    function startConfiguredSession(sessionGeneration) {
        if (!root.monitoringRequested || sessionGeneration !== root.generation)
            return;

        if (root.networkStartGeneration === sessionGeneration)
            return;

        root.networkStartGeneration = sessionGeneration;
        root.checkHealth(sessionGeneration);
    }

    function registerRequest(request, timeoutMs, sessionGeneration, callback) {
        const entry = {
            request,
            deadline: Date.now() + Math.max(1000, Number(timeoutMs ?? 15000)),
            sessionGeneration,
            callback,
            completed: false
        };

        root.activeRequests = root.activeRequests.concat([entry]);
        root.scheduleRequestWatchdog();
        return entry;
    }

    function unregisterRequest(entry) {
        root.activeRequests = root.activeRequests.filter(candidate => candidate !== entry);
        root.scheduleRequestWatchdog();
    }

    function scheduleRequestWatchdog() {
        requestWatchdog.stop();

        if (root.activeRequests.length === 0)
            return;

        let earliestDeadline = root.activeRequests[0].deadline;

        for (const entry of root.activeRequests)
            earliestDeadline = Math.min(earliestDeadline, entry.deadline);

        requestWatchdog.interval = Math.max(1, Math.round(earliestDeadline - Date.now()));
        requestWatchdog.start();
    }

    function expireRequests() {
        const now = Date.now();
        const expired = root.activeRequests.filter(entry => entry.deadline <= now);

        if (expired.length === 0) {
            root.scheduleRequestWatchdog();
            return;
        }

        root.activeRequests = root.activeRequests.filter(entry => entry.deadline > now);

        for (const entry of expired) {
            entry.completed = true;

            if (root.eventRequest === entry)
                root.eventRequest = null;

            try {
                entry.request.abort();
            } catch (_error) {
                // The request may have completed just before the deadline fired.
            }
        }

        for (const entry of expired) {
            if (root.monitoringRequested && entry.sessionGeneration === root.generation)
                entry.callback(false, 0, null);
        }

        root.scheduleRequestWatchdog();
    }

    function abortActiveRequests() {
        const entries = root.activeRequests;

        root.activeRequests = [];
        root.eventRequest = null;
        requestWatchdog.stop();

        for (const entry of entries) {
            entry.completed = true;

            try {
                entry.request.abort();
            } catch (_error) {
                // The request may already have completed between snapshotting and aborting.
            }
        }
    }

    function requestJson(path, authenticated, sessionGeneration, callback, timeoutMs) {
        const request = new XMLHttpRequest();
        const entry = root.registerRequest(request, timeoutMs, sessionGeneration, callback);

        request.onreadystatechange = function () {
            if (request.readyState !== XMLHttpRequest.DONE || entry.completed)
                return;

            entry.completed = true;
            root.unregisterRequest(entry);

            if (!root.monitoringRequested || sessionGeneration !== root.generation)
                return;

            const status = Number(request.status ?? 0);

            if (status < 200 || status >= 300) {
                callback(false, status, null);
                return;
            }

            try {
                const responseText = String(request.responseText ?? "");
                const data = responseText ? JSON.parse(responseText) : null;

                callback(true, status, data);
            } catch (_error) {
                callback(false, status, null);
            }
        };

        try {
            request.open("GET", `${root.baseUrl}${path}`, true);
            request.setRequestHeader("Accept", "application/json");

            if (authenticated && root.apiKey)
                request.setRequestHeader("X-API-Key", root.apiKey);

            request.send();
        } catch (_error) {
            if (!entry.completed) {
                entry.completed = true;
                root.unregisterRequest(entry);

                if (root.monitoringRequested && sessionGeneration === root.generation)
                    callback(false, 0, null);
            }

            return null;
        }

        return entry;
    }

    function checkHealth(sessionGeneration) {
        root.requestJson("/rest/noauth/health", false, sessionGeneration, function (ok, _status, data) {
            if (!ok || String(data?.status ?? "").toUpperCase() !== "OK") {
                root.scheduleRetry("Syncthing is not running", false);
                return;
            }

            root.serviceRunning = true;

            if (!root.apiKey) {
                root.scheduleRetry("Syncthing API credentials were not found", true);
                return;
            }

            root.primeEventStream(sessionGeneration);
        });
    }

    function primeEventStream(sessionGeneration) {
        const path = `/rest/events?events=${encodeURIComponent(root.eventFilter)}&since=0&limit=1&timeout=0`;

        root.requestJson(path, true, sessionGeneration, function (ok, status, data) {
            if (!ok || !Array.isArray(data)) {
                root.handleApiFailure(status, "Unable to initialize Syncthing events");
                return;
            }

            root.apiAvailable = true;
            root.lastError = "";
            root.lastEventId = 0;

            if (data.length > 0) {
                const id = Number(data[data.length - 1]?.id ?? 0);

                if (Number.isFinite(id) && id > 0)
                    root.lastEventId = id;
            }

            root.fetchFolderConfigs(sessionGeneration);
        });
    }

    function handleApiFailure(status, message) {
        const authenticated = status === 401 || status === 403;

        root.apiAvailable = false;
        root.loading = false;
        root.lastError = authenticated ? "Unable to authenticate with the Syncthing API" : message;
        root.scheduleRetry(root.lastError, status !== 0);
    }

    function fetchFolderConfigs(sessionGeneration) {
        root.requestJson("/rest/config/folders", true, sessionGeneration, function (ok, status, data) {
            if (!ok || !Array.isArray(data)) {
                root.handleApiFailure(status, "Unable to load Syncthing folders");
                return;
            }

            const configs = {};
            const activeFolderIds = [];

            for (const source of data) {
                const id = String(source?.id ?? "").trim();

                if (!id)
                    continue;

                const devices = Array.isArray(source?.devices) ? source.devices : [];

                configs[id] = {
                    id,
                    label: String(source?.label ?? "").trim(),
                    type: String(source?.type ?? "").trim().toLowerCase(),
                    paused: Boolean(source?.paused),
                    deviceCount: devices.length
                };

                if (!configs[id].paused)
                    activeFolderIds.push(id);
            }

            root.folderConfigsById = configs;
            root.folderSummariesById = {};
            root.pendingSnapshotCount = activeFolderIds.length;

            if (activeFolderIds.length === 0) {
                root.finishBootstrap(sessionGeneration);
                return;
            }

            for (const folderId of activeFolderIds)
                root.fetchFolderStatus(folderId, sessionGeneration);
        });
    }

    function fetchFolderStatus(folderId, sessionGeneration, attempt) {
        const path = `/rest/db/status?folder=${encodeURIComponent(folderId)}`;
        const currentAttempt = Number(attempt ?? 0);

        root.requestJson(path, true, sessionGeneration, function (ok, status, data) {
            if (ok && data && typeof data === "object") {
                root.setFolderSummary(folderId, data, false);
            } else {
                if (currentAttempt === 0 && status !== 401 && status !== 403) {
                    root.fetchFolderStatus(folderId, sessionGeneration, 1);
                    return;
                }

                root.setFolderSummary(folderId, {
                    statusUnavailable: true,
                    error: status === 401 || status === 403 ? "API authentication failed" : "Status unavailable"
                }, false);
            }

            root.pendingSnapshotCount = Math.max(0, root.pendingSnapshotCount - 1);

            if (root.pendingSnapshotCount === 0)
                root.finishBootstrap(sessionGeneration);
        });
    }

    function finishBootstrap(sessionGeneration) {
        if (!root.monitoringRequested || sessionGeneration !== root.generation)
            return;

        root.loading = false;
        root.bootstrapped = true;
        root.apiAvailable = true;
        root.lastError = "";
        root.retryDelayMs = 2000;
        root.rebuildFolders();
        root.startEventLoop(sessionGeneration);
    }

    function numberValue(value) {
        const number = Number(value ?? 0);

        return Number.isFinite(number) ? number : 0;
    }

    function sanitizeSummary(source) {
        const summary = source && typeof source === "object" ? source : {};

        return {
            statusUnavailable: Boolean(summary.statusUnavailable),
            state: String(summary.state ?? "").trim().toLowerCase(),
            stateChanged: String(summary.stateChanged ?? ""),
            error: String(summary.error ?? "").trim(),
            watchError: String(summary.watchError ?? "").trim(),
            errors: root.numberValue(summary.errors),
            pullErrors: root.numberValue(summary.pullErrors),
            globalBytes: root.numberValue(summary.globalBytes),
            inSyncBytes: root.numberValue(summary.inSyncBytes),
            needBytes: root.numberValue(summary.needBytes),
            needDeletes: root.numberValue(summary.needDeletes),
            needTotalItems: root.numberValue(summary.needTotalItems),
            receiveOnlyTotalItems: root.numberValue(summary.receiveOnlyTotalItems)
        };
    }

    function setFolderSummary(folderId, source, rebuild) {
        const id = String(folderId ?? "").trim();

        if (!id)
            return;

        const next = Object.assign({}, root.folderSummariesById);

        next[id] = root.sanitizeSummary(source);
        root.folderSummariesById = next;

        if (rebuild)
            root.rebuildFolders();
    }

    function mergeFolderSummary(folderId, values) {
        const current = root.folderSummariesById[folderId] ?? {};

        root.setFolderSummary(folderId, Object.assign({}, current, values), false);
    }

    function rebuildFolders() {
        const next = [];

        for (const id of Object.keys(root.folderConfigsById)) {
            const config = root.folderConfigsById[id];
            const summary = root.folderSummariesById[id];

            next.push({
                id,
                label: config.label || id,
                type: config.type,
                paused: config.paused,
                deviceCount: config.deviceCount,
                statusAvailable: config.paused || (summary !== undefined && !summary.statusUnavailable),
                state: String(summary?.state ?? ""),
                stateChanged: String(summary?.stateChanged ?? ""),
                error: String(summary?.error ?? ""),
                watchError: String(summary?.watchError ?? ""),
                errors: root.numberValue(summary?.errors),
                pullErrors: root.numberValue(summary?.pullErrors),
                globalBytes: root.numberValue(summary?.globalBytes),
                inSyncBytes: root.numberValue(summary?.inSyncBytes),
                needBytes: root.numberValue(summary?.needBytes),
                needDeletes: root.numberValue(summary?.needDeletes),
                needTotalItems: root.numberValue(summary?.needTotalItems),
                receiveOnlyTotalItems: root.numberValue(summary?.receiveOnlyTotalItems)
            });
        }

        next.sort((left, right) => left.label.localeCompare(right.label));
        root.folders = next;
    }

    function startEventLoop(sessionGeneration) {
        if (!root.monitoringRequested || !root.bootstrapped || sessionGeneration !== root.generation)
            return;

        const path = `/rest/events?events=${encodeURIComponent(root.eventFilter)}&since=${root.lastEventId}&timeout=60`;
        let request = null;

        request = root.requestJson(path, true, sessionGeneration, function (ok, status, data) {
            if (root.eventRequest === request)
                root.eventRequest = null;

            if (!ok || !Array.isArray(data)) {
                root.handleApiFailure(status, "Syncthing event connection was interrupted");
                return;
            }

            if (!root.applyEvents(data))
                return;

            root.startEventLoop(sessionGeneration);
        }, 75000);

        root.eventRequest = request;
    }

    function applyEvents(events) {
        let cursor = root.lastEventId;
        let changed = false;

        for (const event of events) {
            const id = Number(event?.id ?? 0);

            if (!Number.isFinite(id) || id <= 0)
                continue;

            if (id <= cursor)
                continue;

            if (cursor > 0 && id !== cursor + 1) {
                root.requestRebootstrap();
                return false;
            }

            cursor = id;

            if (event.type === "ConfigSaved") {
                root.lastEventId = cursor;
                root.requestRebootstrap();
                return false;
            }

            changed = root.applyEvent(event) || changed;
        }

        root.lastEventId = cursor;

        if (changed)
            root.rebuildFolders();

        return true;
    }

    function applyEvent(event) {
        const data = event?.data ?? {};
        const type = String(event?.type ?? "");

        if (type === "FolderSummary") {
            const folderId = String(data.folder ?? "");

            if (!root.folderConfigsById[folderId])
                return false;

            root.setFolderSummary(folderId, data.summary ?? {}, false);
            return true;
        }

        if (type === "StateChanged") {
            const folderId = String(data.folder ?? "");

            if (!root.folderConfigsById[folderId])
                return false;

            const nextState = String(data.to ?? "").trim().toLowerCase();
            const values = {
                state: nextState,
                stateChanged: String(event.time ?? ""),
                error: String(data.error ?? "").trim()
            };

            root.mergeFolderSummary(folderId, values);
            return true;
        }

        if (type === "FolderWatchStateChanged") {
            const folderId = String(data.folder ?? "");

            if (!root.folderConfigsById[folderId])
                return false;

            root.mergeFolderSummary(folderId, {
                watchError: String(data.to ?? "").trim()
            });
            return true;
        }

        return false;
    }

    function requestRebootstrap() {
        if (!root.monitoringRequested)
            return;

        rebootstrapTimer.restart();
    }

    function scheduleRetry(message, keepServiceRunning) {
        if (!root.monitoringRequested)
            return;

        root.loading = false;
        root.bootstrapped = false;
        root.apiAvailable = false;
        root.lastError = String(message ?? "");
        root.retryKeepsServiceRunning = Boolean(keepServiceRunning);

        if (!root.retryKeepsServiceRunning)
            root.serviceRunning = false;

        retryTimer.interval = root.retryDelayMs;
        root.retryDelayMs = Math.min(30000, root.retryDelayMs < 5000 ? 5000 : (root.retryDelayMs < 15000 ? 15000 : 30000));
        retryTimer.restart();
    }

    FileView {
        id: configFile

        path: root.configPath
        preload: root.configPath !== ""
        printErrors: false
        watchChanges: true

        onLoaded: root.handleConfigLoaded(configFile.text())
        onLoadFailed: _error => root.handleConfigLoadFailed()
        onFileChanged: configFile.reload()
    }

    Timer {
        id: configReloadTimer

        interval: 250
        repeat: false

        onTriggered: root.ensureConfigSearch()
    }

    Timer {
        id: configCandidateTimer

        interval: 0
        repeat: false

        onTriggered: root.loadConfigCandidate()
    }

    Timer {
        id: requestWatchdog

        repeat: false

        onTriggered: root.expireRequests()
    }

    Timer {
        id: retryTimer

        repeat: false

        onTriggered: root.beginSession(root.retryKeepsServiceRunning)
    }

    Timer {
        id: rebootstrapTimer

        interval: 0
        repeat: false

        onTriggered: root.beginSession(true)
    }

    Component.onDestruction: root.stopSession()
}
