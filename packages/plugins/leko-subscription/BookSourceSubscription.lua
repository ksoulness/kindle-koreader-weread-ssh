-- Self-made KOReader Leko subscription refresher.
-- Fetches the owned Legado source feed once per day while KOReader is running.
local UIManager = require("ui/uimanager")
local Storage = require("Leko/Storage")
local AsyncSourceImport = require("Leko/AsyncSourceImport")

local BookSourceSubscription = {
    url = "https://jlmon.ccwu.cc/booksource.json",
    settings_key = "leko_book_source_subscription",
    start_delay_seconds = 120,
    refresh_interval_seconds = 24 * 60 * 60,
    retry_interval_seconds = 6 * 60 * 60,
}

local function now()
    return os.time()
end

local function normalize_counter(state, key)
    local value = state[key]
    if value == nil then
        state[key] = 0
        return true
    end
    if type(value) ~= "number" or value ~= value or value < 0 or value % 1 ~= 0 then
        return false
    end
    return true
end

function BookSourceSubscription:_loadState()
    local settings = Storage:getSettings()
    local state = settings:readSetting(self.settings_key)

    if state == nil then
        state = {}
    elseif type(state) ~= "table" then
        return nil, settings, "invalid_subscription_state"
    end

    if state.version ~= nil and state.version ~= 1 then
        return nil, settings, "unsupported_subscription_state_version"
    end
    if state.url ~= nil and type(state.url) ~= "string" then
        return nil, settings, "invalid_subscription_url"
    end
    if state.url ~= self.url then
        state.url = self.url
        state.last_success_at = 0
        state.next_run_at = 0
    end

    state.version = 1
    if not normalize_counter(state, "last_attempt_at")
        or not normalize_counter(state, "last_success_at")
        or not normalize_counter(state, "next_run_at")
        or not normalize_counter(state, "last_source_count")
        or not normalize_counter(state, "failure_count") then
        return nil, settings, "invalid_subscription_state"
    end
    -- Initial device state is backed up before deployment; scheduled imports
    -- do not create raw-feed snapshots.
    state.initial_backup_attempted = nil

    return state, settings
end

function BookSourceSubscription:_saveState(settings, state)
    local ok = pcall(function()
        settings:saveSetting(self.settings_key, state)
        settings:flush()
    end)
    return ok
end

function BookSourceSubscription:_schedule(delay_seconds)
    if self.scheduled then
        return
    end

    self.scheduled = true
    UIManager:scheduleIn(math.max(1, math.floor(delay_seconds)), function()
        self.scheduled = false
        self:_refreshIfDue()
    end)
end

function BookSourceSubscription:_recordCompletion(ok, payload)
    self.running = false

    local state, settings = self:_loadState()
    if not state then
        self:_schedule(self.retry_interval_seconds)
        return
    end

    local completed_at = now()
    local count = payload and tonumber(payload.catalog_count)
    if ok and count and count > 0 then
        state.last_success_at = completed_at
        state.last_source_count = math.floor(count)
        state.failure_count = 0
        state.last_result = "success"
        state.next_run_at = completed_at + self.refresh_interval_seconds
    else
        state.failure_count = state.failure_count + 1
        state.last_result = "failed"
        state.next_run_at = completed_at + self.retry_interval_seconds
    end

    if not self:_saveState(settings, state) then
        self:_schedule(self.retry_interval_seconds)
        return
    end

    self:_schedule(state.next_run_at - completed_at)
end

function BookSourceSubscription:_startImport(state, settings, started_at)
    state.last_attempt_at = started_at
    state.next_run_at = started_at + self.retry_interval_seconds
    state.last_result = "started"

    if not self:_saveState(settings, state) then
        self:_schedule(self.retry_interval_seconds)
        return
    end

    self.running = true
    local options = {
        kind = "url",
        url = state.url,
        backup = false,
        return_summary_only = true,
        suppress_sensitive_log = true,
    }

    local started, worker = pcall(function()
        return AsyncSourceImport:start(options, function(ok, _err, _worker, payload)
            self:_recordCompletion(ok, payload)
        end)
    end)

    if not started or not worker then
        self.running = false
        state.failure_count = state.failure_count + 1
        state.last_result = "start_failed"
        state.next_run_at = now() + self.retry_interval_seconds
        self:_saveState(settings, state)
        self:_schedule(self.retry_interval_seconds)
    end
end

function BookSourceSubscription:_refreshIfDue()
    if self.running then
        return
    end

    local state, settings = self:_loadState()
    if not state then
        self:_schedule(self.retry_interval_seconds)
        return
    end

    local current_time = now()
    local remaining = state.next_run_at - current_time
    if remaining > 0 then
        self:_schedule(remaining)
        return
    end

    self:_startImport(state, settings, current_time)
end

function BookSourceSubscription:start()
    if self.started then
        return
    end

    self.started = true
    self:_schedule(self.start_delay_seconds)
end

return BookSourceSubscription
