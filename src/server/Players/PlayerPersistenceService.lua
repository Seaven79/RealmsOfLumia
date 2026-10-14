-- REALMS OF LUMIA
-- STEP 12.1: PERSISTENT PLAYER DATA
-- Session locking, safe release and shutdown synchronization.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Lumia"):WaitForChild("Shared")
local Validator = require(shared:WaitForChild("Players"):WaitForChild("PlayerProfileValidator"))

local Persistence = {}

-- Preserve the existing development data.
-- ===================================================
-- REALMS OF LUMIA - DYNAMIC DATASTORE SELECTION
-- Each Roblox experience has its own profile store.
-- Unknown experiences are intentionally blocked.
-- ===================================================

-- =========================================================
-- REALMS OF LUMIA
-- AUTOMATIC DATASTORE PER ROBLOX EXPERIENCE
-- =========================================================

local EXPERIENCE_ID = game.GameId

assert(
    type(EXPERIENCE_ID) == "number"
        and EXPERIENCE_ID > 0
        and EXPERIENCE_ID % 1 == 0,
    "[Lumia] Invalid GameId. DataStore access blocked."
)

local STORE_NAME = "RealmsOfLumia_Profiles_"
    .. tostring(EXPERIENCE_ID)

print("[Lumia] Automatic DataStore selected: " .. STORE_NAME)
-- Persistence configuration restored from original backup.
local KEY_PREFIX = "Player_"
local AUTOSAVE_INTERVAL = 180
local LOCK_TIMEOUT = 600
local MAX_ATTEMPTS = 4
local store = DataStoreService:GetDataStore(STORE_NAME)
local sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)

local sessions = {}
local loading = {}
local shuttingDown = false

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local result = {}

    for key, child in pairs(value) do
        result[deepCopy(key)] = deepCopy(child)
    end

    return result
end

local function keyFor(userId)
    return KEY_PREFIX .. tostring(userId)
end

local function retry(operation)
    local lastError

    for attempt = 1, MAX_ATTEMPTS do
        local ok, result = pcall(operation)

        if ok then
            return true, result
        end

        lastError = tostring(result)

        warn(
            "[Lumia] DataStore attempt "
            .. attempt
            .. " failed: "
            .. lastError
        )

        if attempt < MAX_ATTEMPTS then
            task.wait(math.min(2 ^ attempt, 8))
        end
    end

    return false, lastError
end

local function validRecord(record)
    if record == nil then
        return true
    end

    if type(record) ~= "table"
        or type(record.Profile) ~= "table" then
        return false
    end

    local valid = Validator.Validate(record.Profile)
    return valid == true
end

local function ownedByOther(record)
    if not record or type(record.Lock) ~= "table" then
        return false
    end

    local lock = record.Lock

    if lock.SessionId == sessionId then
        return false
    end

    -- Malformed locks are not automatically stolen.
    if type(lock.Timestamp) ~= "number" then
        return true
    end

    local age = os.time() - lock.Timestamp

    -- Future timestamps are treated conservatively.
    if age < 0 then
        return true
    end

    return age < LOCK_TIMEOUT
end

function Persistence:Init()
    print("[Lumia] Persistence initialized: " .. STORE_NAME)
end

function Persistence:Start()
    print("[Lumia] Persistence service ready")
end

function Persistence:Load(userId)
    if shuttingDown then
        return nil, "Server shutting down"
    end

    if sessions[userId] or loading[userId] then
        return nil, "Profile already loading or loaded"
    end

    loading[userId] = true

    local conflict = false
    local invalid = false

    local ok, result = retry(function()
        return store:UpdateAsync(keyFor(userId), function(old)
            conflict = false
            invalid = false

            if not validRecord(old) then
                invalid = true
                return nil
            end

            if ownedByOther(old) then
                conflict = true
                return nil
            end

            local profile

            if old then
                profile = deepCopy(old.Profile)
            else
                profile = Validator.CreateDefault()
            end

            return {
                Profile = profile,
                Revision = old and (old.Revision or 0) or 0,
                Lock = {
                    SessionId = sessionId,
                    Timestamp = os.time()
                }
            }
        end)
    end)

    loading[userId] = nil

    if not ok then
        return nil, "DataStore load failed: " .. tostring(result)
    end

    if invalid then
        return nil, "Stored profile failed validation"
    end

    if conflict then
        return nil, "Profile is active on another server"
    end

    if not result
        or type(result.Profile) ~= "table"
        or type(result.Lock) ~= "table"
        or result.Lock.SessionId ~= sessionId then
        return nil, "Could not acquire profile ownership"
    end

    local valid, reason = Validator.Validate(result.Profile)

    if not valid then
        return nil, "Invalid loaded profile: " .. tostring(reason)
    end

    local state = {
        Profile = result.Profile,
        Busy = false,
        Releasing = false,
        Released = false,
        Lost = false,
        NextSave = os.clock()
            + AUTOSAVE_INTERVAL
            + math.random(0, 30)
    }

    sessions[userId] = state

    print("[Lumia] Profile loaded: " .. userId)

    task.spawn(function()
        while sessions[userId] == state
            and not state.Released
            and not state.Lost
            and not shuttingDown do

            task.wait(5)

            if sessions[userId] ~= state
                or state.Released
                or state.Lost
                or shuttingDown then
                break
            end

            if os.clock() >= state.NextSave then
                state.NextSave = os.clock() + AUTOSAVE_INTERVAL

                local saved, saveReason = self:Save(userId, false)

                if not saved then
                    warn(
                        "[Lumia] Autosave failed for "
                        .. userId
                        .. ": "
                        .. tostring(saveReason)
                    )
                end
            end
        end
    end)

    return state.Profile
end

function Persistence:Save(userId, release)
    local state = sessions[userId]

    if not state then
        return false, "No active persistence session"
    end

    if state.Released then
        return true
    end

    if state.Lost then
        return false, "Session ownership lost"
    end

    local deadline = os.clock() + 20

    -- Only one DataStore write per profile at a time.
    while state.Busy do
        if os.clock() >= deadline then
            return false, "Timed out waiting for previous save"
        end

        task.wait(0.1)

        if state.Released then
            return true
        end

        if state.Lost then
            return false, "Session ownership lost"
        end
    end

    if state.Released then
        return true
    end

    if state.Lost then
        return false, "Session ownership lost"
    end

    -- Once release starts, no new autosave may begin.
    if state.Releasing and not release then
        return false, "Profile is being released"
    end

    if release then
        state.Releasing = true
    end

    state.Busy = true

    local valid, reason = Validator.Validate(state.Profile)

    if not valid then
        state.Busy = false

        return false,
            "Refusing to save invalid profile: " .. tostring(reason)
    end

    local snapshot = deepCopy(state.Profile)
    local ownershipLost = false
    local invalidStored = false

    local ok, result = retry(function()
        return store:UpdateAsync(keyFor(userId), function(old)
            ownershipLost = false
            invalidStored = false

            if not validRecord(old) then
                invalidStored = true
                return nil
            end

            if not old
                or type(old.Lock) ~= "table"
                or old.Lock.SessionId ~= sessionId then
                ownershipLost = true
                return nil
            end

            -- Explicit assignment fixes the old Lua and/or bug.
            local newLock = nil

            if not release then
                newLock = {
                    SessionId = sessionId,
                    Timestamp = os.time()
                }
            end

            return {
                Profile = deepCopy(snapshot),
                Revision = (old.Revision or 0) + 1,
                Lock = newLock
            }
        end)
    end)

    state.Busy = false

    if not ok then
        return false, tostring(result)
    end

    if invalidStored then
        state.Lost = true

        warn(
            "[Lumia] CRITICAL: Stored profile invalid for "
            .. userId
        )

        task.defer(function()
            local player = Players:GetPlayerByUserId(userId)

            if player then
                player:Kick(
                    "Your character data requires a safe reload. "
                    .. "Please reconnect later."
                )
            end
        end)

        return false, "Stored record failed validation"
    end

    if ownershipLost or not result then
        state.Lost = true

        warn(
            "[Lumia] CRITICAL: Persistence ownership lost for "
            .. userId
        )

        task.defer(function()
            local player = Players:GetPlayerByUserId(userId)

            if player then
                player:Kick(
                    "Your character's save session is no longer safe. "
                    .. "Please reconnect shortly."
                )
            end
        end)

        return false, "Session ownership lost"
    end

    if release then
        state.Released = true
        sessions[userId] = nil

        print(
            "[Lumia] Profile saved and lock released: "
            .. userId
        )
    else
        print("[Lumia] Profile autosaved: " .. userId)
    end

    return true
end

function Persistence:IsUsable(userId)
    local state = sessions[userId]

    return state ~= nil
        and not state.Lost
        and not state.Released
end

function Persistence:Release(userId)
    local state = sessions[userId]

    if not state then
        -- Already released or no active session.
        return true
    end

    -- Stop new autosaves while release is underway.
    state.Releasing = true

    -- Coordinate PlayerRemoving and BindToClose.
    if state.ReleaseBusy then
        local deadline = os.clock() + 25

        while state.ReleaseBusy do
            if os.clock() >= deadline then
                return false, "Timed out waiting for profile release"
            end

            task.wait(0.1)
        end

        if state.Released then
            return true
        end

        -- If the first release failed, the caller may retry.
    end

    if state.Lost then
        return false, "Session ownership lost"
    end

    if state.Released then
        return true
    end

    state.ReleaseBusy = true

    local saved, reason = self:Save(userId, true)

    state.ReleaseBusy = false

    return saved, reason
end

function Persistence:Shutdown()
    if shuttingDown then
        return
    end

    shuttingDown = true

    local remaining = 0

    for userId in pairs(sessions) do
        remaining += 1

        task.spawn(function()
            local saved = false
            local reason = nil

            for attempt = 1, 2 do
                saved, reason = self:Release(userId)

                if saved then
                    break
                end

                warn(
                    "[Lumia] Shutdown release attempt "
                    .. attempt
                    .. " failed for "
                    .. userId
                    .. ": "
                    .. tostring(reason)
                )

                if reason == "Session ownership lost" then
                    break
                end

                if attempt < 2 then
                    task.wait(1)
                end
            end

            if not saved then
                warn(
                    "[Lumia] CRITICAL: Shutdown could not "
                    .. "confirm profile save for "
                    .. userId
                )
            end

            remaining -= 1
        end)
    end

    local deadline = os.clock() + 25

    while remaining > 0 and os.clock() < deadline do
        task.wait(0.1)
    end

    if remaining > 0 then
        warn(
            "[Lumia] Shutdown has unfinished saves: "
            .. remaining
        )
    end
end

return Persistence