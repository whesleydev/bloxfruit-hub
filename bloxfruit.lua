-- Blox Fruits | hub v4
-- executor: Delta, Xeno, Solara, Fluxus, Wave

local BASE = "https://raw.githubusercontent.com/whesleydev/bloxfruit-hub/main"
local SCRIPT_VERSION = 11
local CONFIG_PATH = "bloxfruit_config.json"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local previous = _G.__bloxHub
if previous then
    pcall(function()
        if previous.window and previous.window.Destroy then
            previous.window:Destroy()
        end
        for _, key in ipairs({"bubble", "statusGui", "espFolder", "tracerFolder"}) do
            if previous[key] then
                previous[key]:Destroy()
            end
        end
        if previous.stopFly then
            previous.stopFly()
        end
        for _, conn in ipairs(previous.connections or {}) do
            pcall(function()
                conn:Disconnect()
            end)
        end
    end)
end

local session = {version = SCRIPT_VERSION, connections = {}}
_G.__bloxHub = session

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local state = {
    speed = 16,
    jump = 50,
    flySpeed = 150,
    fly = false,
    jumpFly = true,
    maxFlyHeight = 300,
    moveMode = "rig",
    travelSpeed = 150,

    autoFarm = false,
    autoFruit = false,
    autoChest = false,
    autoEquip = true,
    fastAttack = false,
    killAura = false,
    auraRange = 40,
    attackDelay = 0.08,
    farmRange = 1000,
    targetName = "auto",
    hitbox = false,
    hitboxSize = 14,
    questSeconds = 45,
    autoQuestFly = false,

    espFruit = true,
    espChest = true,
    espPlayer = false,
    espMob = false,
    espName = true,
    espHealth = true,
    espDistance = true,
    espTracer = false,
    espFill = false,
    espOnlySelected = false,
    espRange = 1200,
    selectedPlayer = nil,
    selectedIsland = nil,
    spectate = false,
    colorFruit = {255, 200, 60},
    colorChest = {60, 220, 120},
    colorMob = {255, 80, 80},
    colorPlayer = {80, 160, 255},

    verboseLogs = true,
    showLogPanel = false,
    antiAfk = true,
    noClip = false,
    fpsPack = false,
    noFog = false,
    noEffects = false,
    lowQuality = false,
}

local FRUITS = {
    Rocket = true, Spin = true, Blade = true, Spring = true, Bomb = true,
    Smoke = true, Spike = true, Flame = true, Falcon = true, Ice = true,
    Sand = true, Dark = true, Diamond = true, Light = true, Rubber = true,
    Barrier = true, Ghost = true, Magma = true, Quake = true, Buddha = true,
    Love = true, Spider = true, Sound = true, Phoenix = true, Portal = true,
    Rumble = true, Paw = true, Gravity = true, Dough = true, Shadow = true,
    Venom = true, Control = true, Spirit = true, Dragon = true, Leopard = true,
    Kitsune = true, Yeti = true, Gas = true, Blizzard = true, Pain = true,
}

local NUMBER_KEYS = {"speed", "jump", "flySpeed", "maxFlyHeight", "travelSpeed",
                      "auraRange", "attackDelay", "farmRange", "hitboxSize",
                      "espRange"}
local BOOL_KEYS = {"jumpFly", "espFruit", "espChest", "espPlayer", "espMob",
                   "espName", "espHealth", "espDistance", "espTracer",
                   "autoEquip", "antiAfk"}

local function hasFileApi()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function loadConfig()
    if not hasFileApi() then
        return nil
    end
    local ok, raw = pcall(function()
        if type(isfile) == "function" and not isfile(CONFIG_PATH) then
            return nil
        end
        return readfile(CONFIG_PATH)
    end)
    if not ok or type(raw) ~= "string" or #raw == 0 then
        return nil
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not decoded or type(data) ~= "table" then
        return nil
    end
    return data
end

local saved = loadConfig()
if saved then
    for _, key in ipairs(NUMBER_KEYS) do
        state[key] = tonumber(saved[key]) or state[key]
    end
    for _, key in ipairs(BOOL_KEYS) do
        if type(saved[key]) == "boolean" then
            state[key] = saved[key]
        end
    end
    if type(saved.waypoints) == "table" then
        state.waypoints = saved.waypoints
    end
end
state.waypoints = state.waypoints or {}

local dirty = false

local function markDirty()
    dirty = true
end

local function saveConfig()
    if not hasFileApi() then
        return false
    end
    local data = {version = SCRIPT_VERSION, waypoints = state.waypoints}
    for _, key in ipairs(NUMBER_KEYS) do
        data[key] = state[key]
    end
    for _, key in ipairs(BOOL_KEYS) do
        data[key] = state[key]
    end
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return false
    end
    return pcall(function()
        writefile(CONFIG_PATH, encoded)
    end)
end

session.saveConfig = saveConfig

local statusLabel = nil

local function status(text)
    if statusLabel then
        statusLabel.Text = text
    end
    if Log then
        Log.add("INFO", text)
    end
end


-- ===== log =====
local LOG_PATH = "bloxfruit_log.txt"
local LOG_MAX = 500

local Log = {
    lines = {},
    entries = {},
    verbose = true,
    dirtyPanel = false,
    panelLines = {},
}

local function stamp()
    local ok, value = pcall(function()
        return os.date("%H:%M:%S")
    end)
    return ok and value or "??:??:??"
end

function Log.add(level, text)
    local line = string.format("[%s] %-5s %s", stamp(), level, tostring(text))
    Log.lines[#Log.lines + 1] = line
    if #Log.lines > LOG_MAX then
        table.remove(Log.lines, 1)
    end
    Log.entries[#Log.entries + 1] = {level = level, text = tostring(text), time = stamp()}
    if #Log.entries > LOG_MAX then
        table.remove(Log.entries, 1)
    end
    Log.dirtyPanel = true
    if state.verboseLogs then
        print(line)
    end
end

function Log.dump()
    return table.concat(Log.lines, "\n")
end

function Log.clear()
    Log.lines = {}
    Log.entries = {}
    Log.dirtyPanel = true
end

function Log.guard(name, fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            Log.add("ERRO", name .. ": " .. tostring(err))
        end
        return ok
    end
end

session.Log = Log

local function humanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ===== voo / deslocamento =====
local flyRig = {
    lock = 0,
    active = false,
    align = nil,
    orient = nil,
    attach = nil,
    target = nil,
    holdTimer = 0,
    pressedUntil = 0,
}

session.connections[#session.connections + 1] = UserInputService.JumpRequest:Connect(function()
    flyRig.pressedUntil = os.clock() + 0.35
end)

local function destroyRig()
    for _, key in ipairs({"align", "orient", "attach"}) do
        local object = flyRig[key]
        if object then
            pcall(function()
                object:Destroy()
            end)
            flyRig[key] = nil
        end
    end
    flyRig.active = false
    flyRig.target = nil
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = state.speed
    end
end

session.stopFly = destroyRig

local function buildRig()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        return false
    end

    flyRig.attach = Instance.new("Attachment")
    flyRig.attach.Name = "hubFlyAttach"
    flyRig.attach.Parent = root

    flyRig.align = Instance.new("AlignPosition")
    flyRig.align.Name = "hubFlyAlign"
    flyRig.align.Attachment0 = flyRig.attach
    flyRig.align.Mode = Enum.PositionAlignmentMode.OneAttachment
    flyRig.align.MaxForce = 1e6
    flyRig.align.MaxVelocity = 1e4
    flyRig.align.Responsiveness = 45
    flyRig.align.Position = root.Position
    flyRig.align.Parent = root

    flyRig.orient = Instance.new("AlignOrientation")
    flyRig.orient.Attachment0 = flyRig.attach
    flyRig.orient.Mode = Enum.OrientationAlignmentMode.OneAttachment
    flyRig.orient.MaxTorque = 1e6
    flyRig.orient.Responsiveness = 45
    flyRig.orient.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
    flyRig.orient.Parent = root

    flyRig.target = root.Position
    flyRig.active = true
    hum.WalkSpeed = 0
    return true
end

local function updateFly(dt)
    local hum = humanoid()
    local root = rootPart()
    if not hum or not root then
        if flyRig.active then
            destroyRig()
        end
        return
    end
    if flyRig.lock > 0 then
        return
    end
    if flyRig.active and (not flyRig.align or not flyRig.align.Parent) then
        destroyRig()
    end

    local held = UserInputService:IsKeyDown(Enum.KeyCode.Space)
            or os.clock() < flyRig.pressedUntil

    if held then
        flyRig.holdTimer = math.min(flyRig.holdTimer + dt, 4)
    else
        flyRig.holdTimer = math.max(flyRig.holdTimer - dt * 3, 0)
    end

    local wantFly = state.fly or (state.jumpFly and flyRig.holdTimer > 0.45)
    if not wantFly then
        if flyRig.active then
            destroyRig()
        end
        return
    end
    if not flyRig.active and not buildRig() then
        return
    end
    if not flyRig.align or not flyRig.target then
        return
    end

    local speed = state.flySpeed
    local move = hum.MoveDirection
    local step = Vector3.new(move.X, 0, move.Z) * speed * dt
    local rise = 0
    if held and root.Position.Y < state.maxFlyHeight then
        rise = speed * 0.7 * dt
    end

    flyRig.target = flyRig.target + step + Vector3.new(0, rise, 0)
    flyRig.align.Position = flyRig.target
    if flyRig.orient then
        flyRig.orient.CFrame = CFrame.new(flyRig.target)
                * CFrame.Angles(0, math.rad(root.Orientation.Y), 0)
    end
end

local function cframeTravel(target, speed)
    if flyRig.active then
        destroyRig()
    end
    local deadline = os.clock() + 15
    while os.clock() < deadline do
        if _G.__bloxHub ~= session then
            break
        end
        local root = rootPart()
        if not root then
            break
        end
        local delta = target - root.Position
        if delta.Magnitude < 6 then
            return true
        end
        local dt = RunService.Heartbeat:Wait()
        if dt > 0.2 then
            dt = 0.2
        end
        local step = math.min(speed * dt, delta.Magnitude)
        root.CFrame = CFrame.new(root.Position + delta.Unit * step)
    end
    return false
end

local function travelTo(target, speed)
    if state.moveMode == "cframe" then
        return cframeTravel(target, speed)
    end
    local root = rootPart()
    if not root or not target then
        return false
    end

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return cframeTravel(target, speed)
        end
        owned = true
    end

    flyRig.lock = flyRig.lock + 1

    local ok, reached = pcall(function()
        flyRig.target = root.Position
        if not flyRig.align then
            return false
        end
        flyRig.align.Position = flyRig.target

        local maxSpeed = math.min(speed, 220)
        local deadline = os.clock() + 15
        local arrived = false
        local watchdog = os.clock()
        local watchPos = root.Position

        while os.clock() < deadline do
            if _G.__bloxHub ~= session then
                break
            end
            if not rootPart() or not flyRig.align or not flyRig.target then
                break
            end
            local dt = RunService.Heartbeat:Wait()
            if dt > 0.25 then
                dt = 0.25
            end
            local current = flyRig.target
            if not current then
                break
            end
            local delta = target - current
            if delta.Magnitude < 6 then
                arrived = true
                break
            end
            local flat = Vector3.new(delta.X, 0, delta.Z)
            local direction = flat.Magnitude > 0.1 and flat.Unit or Vector3.zero
            local lift = 0
            if delta.Y > 3 then
                lift = 1
            elseif delta.Y < -3 then
                lift = -1
            end
            local move = direction + Vector3.new(0, lift, 0)
            if move.Magnitude > 0.01 then
                flyRig.target = flyRig.target + move.Unit * maxSpeed * dt
            end
            flyRig.align.Position = flyRig.target

            if os.clock() - watchdog > 1.2 then
                local now = rootPart()
                if now and (now.Position - watchPos).Magnitude < 8 then
                    return "stuck"
                end
                if now then
                    watchPos = now.Position
                end
                watchdog = os.clock()
            end
        end
        return arrived
    end)

    flyRig.lock = math.max(0, flyRig.lock - 1)

    if not ok then
        Log.add("ERRO", "travelTo: " .. tostring(reached))
        if owned then
            destroyRig()
        end
        return false
    end

    if reached == "stuck" then
        if owned then
            destroyRig()
        end
        state.moveMode = "cframe"
        status("movimento: CFrame")
        return cframeTravel(target, speed)
    end

    if owned then
        destroyRig()
    end

    Log.add(reached and "ACAO" or "AVISO",
            string.format("deslocamento %s | modo %s", reached and "ok" or "incompleto", state.moveMode))
    return reached == true
end

local function touchSweep(seconds)
    if not flyRig.active or not flyRig.align then
        return
    end
    local center = flyRig.target
    local start = os.clock()
    while (os.clock() - start) < seconds and _G.__bloxHub == session do
        RunService.Heartbeat:Wait()
        local angle = (os.clock() - start) * 9
        flyRig.target = center + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
        flyRig.align.Position = flyRig.target
    end
    flyRig.target = center
    flyRig.align.Position = center
end

-- ===== alvos =====
local descendantCache = {at = 0, list = {}}

local function descendants()
    if os.clock() - descendantCache.at < 3 then
        return descendantCache.list
    end
    descendantCache.at = os.clock()
    descendantCache.list = Workspace:GetDescendants()
    return descendantCache.list
end

local function isPlayerCharacter(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function aliveRoot(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
            or model:FindFirstChild("Humanoid", true)
    if not hum or hum.Health <= 0 then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("HumanoidRootPart", true)
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChildWhichIsA("BasePart")
            or model:FindFirstChildWhichIsA("BasePart", true)
end

local function collectEnemies()
    local out = {}
    local seen = {}
    local function consider(model)
        if seen[model] or model == LocalPlayer.Character then
            return
        end
        seen[model] = true
        if isPlayerCharacter(model) or Players:FindFirstChild(model.Name) then
            return
        end
        local root = aliveRoot(model)
        if root then
            out[#out + 1] = {model = model, part = root}
        end
    end

    local enemies = Workspace:FindFirstChild("Enemies")
    if enemies then
        for _, model in ipairs(enemies:GetChildren()) do
            if model:IsA("Model") then
                consider(model)
            end
        end
        if #out == 0 then
            for _, model in ipairs(enemies:GetDescendants()) do
                if model:IsA("Model") then
                    consider(model)
                end
            end
        end
    end
    if #out == 0 then
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") then
                consider(model)
            end
        end
    end
    return out
end

local function collectFruits()
    local out = {}
    local function consider(object)
        local handle = object:FindFirstChild("Handle")
                or object:FindFirstChildWhichIsA("BasePart")
        if handle then
            out[#out + 1] = {model = object, part = handle}
        end
    end
    for _, object in ipairs(Workspace:GetChildren()) do
        if object:IsA("Model") or object:IsA("Tool") then
            local lower = string.lower(object.Name)
            if FRUITS[object.Name] or string.find(lower, "fruit", 1, true) then
                consider(object)
            end
        end
    end
    local folder = Workspace:FindFirstChild("Fruits")
    if folder then
        for _, object in ipairs(folder:GetChildren()) do
            consider(object)
        end
    end
    return out
end

local function collectChests()
    local out = {}
    local function consider(object)
        local part = object:FindFirstChildWhichIsA("BasePart") or object
        if part and part:IsA("BasePart") then
            out[#out + 1] = {model = object, part = part}
        end
    end
    for _, object in ipairs(Workspace:GetChildren()) do
        if string.find(string.lower(object.Name), "chest", 1, true) then
            consider(object)
        end
    end
    local folder = Workspace:FindFirstChild("Chests")
    if folder then
        for _, object in ipairs(folder:GetChildren()) do
            consider(object)
        end
    end
    if #out == 0 then
        for _, object in ipairs(descendants()) do
            if string.find(string.lower(object.Name), "chest", 1, true) then
                consider(object)
            end
        end
    end
    return out
end

-- ===== ESP =====
local function uiRoot()
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok and value then
            return value
        end
    end
    return game:GetService("CoreGui")
end

local espFolder = Instance.new("Folder")
espFolder.Name = "BloxEsp"
pcall(function()
    espFolder.Parent = uiRoot()
end)
session.espFolder = espFolder

local espItems = {}
local tracers = {}

local function removeEsp(model)
    local item = espItems[model]
    if item then
        for _, object in pairs(item) do
            if typeof(object) == "Instance" then
                pcall(function()
                    object:Destroy()
                end)
            end
        end
        espItems[model] = nil
    end
    local line = tracers[model]
    if line then
        pcall(function()
            line:Remove()
        end)
        tracers[model] = nil
    end
end

local function ensureEsp(model, part, color, title)
    local item = espItems[model]
    if item and item.highlight and item.highlight.Parent then
        return item
    end

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = state.espFill and 0.65 or 1
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0.25
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(150, 34)
    billboard.StudsOffset = Vector3.new(0, 3.4, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = state.espRange
    billboard.Adornee = part
    billboard.Parent = espFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0.55
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLabel.Text = title
    nameLabel.Parent = billboard

    local barBack = Instance.new("Frame")
    barBack.Size = UDim2.new(0.8, 0, 0.14, 0)
    barBack.Position = UDim2.new(0.1, 0, 0.62, 0)
    barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    barBack.BorderSizePixel = 0
    barBack.Parent = billboard

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.fromScale(1, 1)
    barFill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBack

    item = {highlight = highlight, billboard = billboard, label = nameLabel,
            barBack = barBack, barFill = barFill}
    espItems[model] = item

    if state.espTracer and Drawing then
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Color = color
        line.Transparency = 0.6
        tracers[model] = line
    end
    return item
end

local function screenPoint(part)
    local camera = Workspace.CurrentCamera
    if not camera then
        return nil
    end
    local point, onScreen = camera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return nil
    end
    return Vector2.new(point.X, point.Y)
end

local function refreshEsp()
    local active = {}
    local mine = rootPart()

    local function handle(entry, color, title)
        active[entry.model] = true
        local item = ensureEsp(entry.model, entry.part, color, title)
        if not item or not item.highlight or not item.highlight.Parent then
            return
        end
        local distance = mine and (entry.part.Position - mine.Position).Magnitude or 0
        if distance > state.espRange then
            item.billboard.Enabled = false
            item.highlight.Enabled = false
            return
        end
        item.highlight.Enabled = true
        item.billboard.Enabled = true

        local pieces = {}
        if state.espName then
            pieces[#pieces + 1] = title
        end
        if state.espDistance then
            pieces[#pieces + 1] = string.format("[%d]", math.floor(distance))
        end
        item.label.Text = table.concat(pieces, " ")
        item.barBack.Visible = state.espHealth

        local hum = entry.model:FindFirstChildOfClass("Humanoid")
        if hum and hum.MaxHealth > 0 then
            local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            item.barFill.Size = UDim2.fromScale(ratio, 1)
            item.barFill.BackgroundColor3 = Color3.fromRGB(220 * (1 - ratio) + 90 * ratio,
                    90 + 130 * ratio, 90)
        end

        local line = tracers[entry.model]
        if line then
            if state.espTracer then
                local point = screenPoint(entry.part)
                if point then
                    line.From = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2,
                            Workspace.CurrentCamera.ViewportSize.Y)
                    line.To = point
                    line.Visible = true
                else
                    line.Visible = false
                end
            else
                line.Visible = false
            end
        end
    end

    local function rgb(t)
        return Color3.fromRGB(t[1], t[2], t[3])
    end

    if state.espFruit then
        for _, fruit in ipairs(collectFruits()) do
            handle(fruit, rgb(state.colorFruit), fruit.model.Name)
        end
    end
    if state.espChest then
        for _, chest in ipairs(collectChests()) do
            handle(chest, rgb(state.colorChest), "bau")
        end
    end
    if state.espMob then
        for _, enemy in ipairs(collectEnemies()) do
            handle(enemy, rgb(state.colorMob), enemy.model.Name)
        end
    end
    if state.espPlayer then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root and (not state.espOnlySelected or player.Name == state.selectedPlayer) then
                    handle({model = player.Character, part = root},
                            rgb(state.colorPlayer), player.Name)
                end
            end
        end
    end

    for model in pairs(espItems) do
        if not active[model] or not model.Parent then
            removeEsp(model)
        end
    end
    for model in pairs(tracers) do
        if not active[model] then
            local line = tracers[model]
            pcall(function()
                line:Remove()
            end)
            tracers[model] = nil
        end
    end
end


-- ===== combate =====
local function currentTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function equipTool()
    if not state.autoEquip then
        return
    end
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack or char:FindFirstChildOfClass("Tool") then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and hum then
            pcall(function()
                hum:EquipTool(tool)
            end)
            return
        end
    end
end

local function serverTouch(part)
    local hrp = rootPart()
    if not hrp or not part then
        return false
    end
    local ok = pcall(function()
        firetouchinterest(part, hrp, 0)
        task.wait(0.05)
        firetouchinterest(part, hrp, 1)
    end)
    Log.add(ok and "ACAO" or "ERRO", "touch em " .. tostring(part and part:GetFullName()))
    return ok
end

local function serverPrompts(radius)
    local hrp = rootPart()
    if not hrp then
        return 0
    end
    local fired = 0
    for _, object in ipairs(descendants()) do
        if object:IsA("ProximityPrompt") and object.Enabled then
            local parent = object.Parent
            local part = parent and (parent:IsA("BasePart") and parent
                    or parent:FindFirstChildWhichIsA("BasePart"))
            if part and (part.Position - hrp.Position).Magnitude <= radius then
                pcall(function()
                    fireproximityprompt(object)
                end)
                fired = fired + 1
            end
        end
    end
    Log.add("ACAO", "prompts disparados: " .. fired)
    return fired
end

local function activateTool()
    equipTool()
    local tool = currentTool()
    if not tool then
        return false
    end
    pcall(function()
        tool:Activate()
    end)
    return true
end

local function pickTarget()
    local enemies = collectEnemies()
    if #enemies == 0 then
        return nil, math.huge
    end
    local mine = rootPart()
    if not mine then
        return nil, math.huge
    end
    local best, bestDistance = nil, math.huge
    for _, enemy in ipairs(enemies) do
        if state.targetName == "auto" or enemy.model.Name == state.targetName then
            local distance = (enemy.part.Position - mine.Position).Magnitude
            if distance < bestDistance then
                best, bestDistance = enemy, distance
            end
        end
    end
    return best, bestDistance
end

local function farmCycle()
    local enemy, distance = pickTarget()
    if not enemy or distance > state.farmRange then
        status("farm: sem alvo")
        return false
    end
    status(string.format("farm: %s | %d", enemy.model.Name, math.floor(distance)))
    Log.add("ACAO", string.format("farm alvo %s a %d studs", enemy.model.Name, math.floor(distance)))

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    travelTo(enemy.part.Position + Vector3.new(0, 3, 0), state.flySpeed)

    local started = os.clock()
    local killed = false
    while os.clock() - started < 3 and _G.__bloxHub == session do
        if not enemy.model.Parent or not aliveRoot(enemy.model) then
            killed = true
            break
        end
        local mine = rootPart()
        if mine and (enemy.part.Position - mine.Position).Magnitude > 14 then
            flyRig.target = enemy.part.Position + Vector3.new(0, 3, 0)
            if flyRig.align then
                flyRig.align.Position = flyRig.target
            end
        end
        activateTool()
        task.wait(state.attackDelay)
    end

    Log.add(killed and "ACAO" or "AVISO", string.format("farm: %s %s | arma %s",
            killed and "matou" or "nao matou", enemy.model.Name,
            currentTool() and currentTool().Name or "NENHUMA"))

    if owned then
        destroyRig()
    end
    return true
end

-- ===== missoes =====

local questCache = {at = 0, value = nil}

local function readQuest()
    if os.clock() - questCache.at < 0.4 then
        return questCache.value
    end
    questCache.at = os.clock()
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if not gui then
        return nil
    end
    for _, object in ipairs(gui:GetDescendants()) do
        if object:IsA("TextLabel") and object.Visible then
            local text = object.Text or ""
            local lower = string.lower(text)
            if string.find(lower, "defeat", 1, true) or string.find(lower, "derrote", 1, true)
                    or string.find(lower, "derrotar", 1, true) then
                local current, total = string.match(text, "(%d+)%s*/%s*(%d+)")
                questCache.value = {
                    current = tonumber(current) or 0,
                    total = tonumber(total) or 0,
                    text = text,
                }
                return questCache.value
            end
        end
    end
    questCache.value = nil
    return nil
end

local questRun = {npc = nil, index = 1, lastAccept = 0, lastLog = 0, lastStart = 0}

local function playerLevel()
    local ok, value = pcall(function()
        return LocalPlayer.Data.Level.Value
    end)
    if ok and type(value) == "number" then
        return value
    end
    return 1
end

local function collectQuestPrompts()
    local out = {}
    for _, object in ipairs(descendants()) do
        if object:IsA("ProximityPrompt") then
            local action = string.lower(object.ActionText or "")
            local label = string.lower(object.ObjectText or "")
            local text = action .. " " .. label
            if string.find(text, "quest", 1, true)
                    or string.find(text, "miss", 1, true)
                    or string.find(action, "talk", 1, true) then
                local parent = object.Parent
                local part = parent and (parent:IsA("BasePart") and parent
                        or parent:FindFirstChildWhichIsA("BasePart"))
                if part then
                    out[#out + 1] = {
                        prompt = object,
                        part = part,
                        action = object.ActionText or "",
                        label = object.ObjectText or "",
                        path = part:GetFullName(),
                    }
                end
            end
        end
    end
    return out
end

local function nearestQuest()
    local mine = rootPart()
    if not mine then
        return nil, math.huge
    end
    local best, bestDistance = nil, math.huge
    for _, entry in ipairs(collectQuestPrompts()) do
        local distance = (entry.part.Position - mine.Position).Magnitude
        if distance < bestDistance then
            best, bestDistance = entry, distance
        end
    end
    return best, bestDistance
end


-- ===== ilhas / destinos =====
local ISLAND_NAMES = {
    Bandit = true, Jungle = true, Marine = true, Pirate = true, Desert = true,
    Snow = true, Volcano = true, Sky = true, Fountain = true, Colosseum = true,
    Prison = true, Magma = true, Underwater = true, Kingdom = true, Ice = true,
    Cursed = true, Hydra = true, Castle = true, Dressrosa = true, Zou = true,
    Wano = true, Fishman = true, Rumble = true, Cafe = true, Mansion = true,
}

local function collectIslands()
    local out = {}
    local seen = {}
    local function add(name, position)
        if not name or name == "" or seen[name] or not position then
            return
        end
        seen[name] = true
        out[#out + 1] = {name = name, position = position}
    end

    local folder = Workspace:FindFirstChild("Islands")
            or Workspace:FindFirstChild("Island")
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            local part = model:FindFirstChildWhichIsA("BasePart")
                    or model:FindFirstChild("HumanoidRootPart", true)
            if part then
                add(model.Name, part.Position)
            end
        end
    end

    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and ISLAND_NAMES[model.Name] then
            local part = model:FindFirstChildWhichIsA("BasePart")
                    or model:FindFirstChild("HumanoidRootPart", true)
            if part then
                add(model.Name, part.Position)
            end
        end
    end

    for _, entry in ipairs(collectQuestPrompts()) do
        local label = entry.label ~= "" and entry.label or entry.path
        add("Missao: " .. label, entry.part.Position)
    end

    table.sort(out, function(a, b)
        return a.name < b.name
    end)
    return out
end

local islandCache = {}

local function refreshIslands()
    islandCache = collectIslands()
    return islandCache
end

local function findIsland(name)
    for _, island in ipairs(islandCache) do
        if island.name == name then
            return island
        end
    end
    for _, island in ipairs(refreshIslands()) do
        if island.name == name then
            return island
        end
    end
    return nil
end

local function questCycle()
    local level = playerLevel()
    local info = readQuest()
    if os.clock() - questRun.lastStart > 15 then
        questRun.lastStart = os.clock()
        Log.add("INFO", string.format("quest: ciclo | nivel %d | missao %s", level,
                info and (info.current .. "/" .. info.total) or "nenhuma"))
    end

    if info then
        if info.current > 0 then
            status(string.format("missao: faltam %d", info.current))
            if os.clock() - questRun.lastLog > 5 then
                questRun.lastLog = os.clock()
                Log.add("INFO", string.format("missao nivel %d: %d de %d restantes",
                        level, info.current, info.total))
            end
            local enemy = pickTarget()
            if enemy then
                local mine = rootPart()
                if mine and (enemy.part.Position - mine.Position).Magnitude > 18 then
                    travelTo(enemy.part.Position + Vector3.new(0, 3, 0), state.flySpeed)
                end
                local untilTime = os.clock() + 2
                while os.clock() < untilTime and _G.__bloxHub == session do
                    if not aliveRoot(enemy.model) then
                        break
                    end
                    activateTool()
                    task.wait(state.attackDelay)
                end
            else
                task.wait(0.3)
            end
            return true
        end

        if questRun.npc and questRun.npc.part then
            status("missao: entregando")
            Log.add("ACAO", "missao: voltando para entregar em " .. questRun.npc.path)
            travelTo(questRun.npc.part.Position + Vector3.new(0, 3, 0), state.travelSpeed)
            pcall(function()
                fireproximityprompt(questRun.npc.prompt)
            end)
            task.wait(2)
            questRun.npc = nil
            return true
        end
    end

    if os.clock() - questRun.lastAccept < 6 then
        task.wait(0.5)
        return false
    end

    local prompts = collectQuestPrompts()
    if #prompts == 0 then
        status("missao: nenhum NPC no mapa")
        return false
    end
    local mine = rootPart()
    if not mine then
        return false
    end
    table.sort(prompts, function(a, b)
        return (a.part.Position - mine.Position).Magnitude < (b.part.Position - mine.Position).Magnitude
    end)

    questRun.lastAccept = os.clock()
    local index = ((questRun.index - 1) % #prompts) + 1
    local npc = prompts[index]
    questRun.index = index + 1

    status("missao: indo aceitar " .. (npc.label ~= "" and npc.label or npc.path))
    Log.add("ACAO", string.format("missao: tentando NPC %s (%d studs)", npc.path,
            math.floor((npc.part.Position - mine.Position).Magnitude)))

    travelTo(npc.part.Position + Vector3.new(0, 3, 0), state.travelSpeed)
    pcall(function()
        fireproximityprompt(npc.prompt)
    end)
    task.wait(1.5)

    local after = readQuest()
    if after then
        questRun.npc = npc
        Log.add("ACAO", string.format("missao aceita: %s | %d/%d",
                npc.label ~= "" and npc.label or npc.path, after.current, after.total))
        status("missao aceita")
    else
        Log.add("AVISO", "jogo recusou: " .. npc.path)
    end
    return true
end

local function fruitCycle()
    local fruits = collectFruits()
    Log.add("INFO", "frutas no mapa: " .. #fruits)
    if #fruits == 0 then
        status("fruta: nenhuma")
        return false
    end
    local fruit = fruits[1]
    status("fruta: " .. fruit.model.Name)

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end
    local ok = travelTo(fruit.part.Position + Vector3.new(0, 3, 0), state.travelSpeed)
    if ok then
        touchSweep(0.6)
        serverTouch(fruit.part)
        serverPrompts(20)
    end
    if owned then
        destroyRig()
    end
    return ok
end

local function chestCycle()
    local chests = collectChests()
    Log.add("INFO", "baus no mapa: " .. #chests)
    if #chests == 0 then
        status("bau: nenhum")
        return false
    end
    local chest = chests[1]
    status("bau: indo")

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end
    local ok = travelTo(chest.part.Position + Vector3.new(0, 3, 0), state.travelSpeed)
    if ok then
        touchSweep(0.5)
        serverTouch(chest.part)
        serverPrompts(25)
    end
    if owned then
        destroyRig()
    end
    return ok
end

-- hitbox
local hitboxOriginal = {}

local function applyHitbox()
    for _, enemy in ipairs(collectEnemies()) do
        local part = enemy.part
        if state.hitbox then
            if not hitboxOriginal[part] then
                hitboxOriginal[part] = {size = part.Size, transparency = part.Transparency,
                                        collide = part.CanCollide}
            end
            part.Size = Vector3.new(state.hitboxSize, state.hitboxSize, state.hitboxSize)
            part.Transparency = 0.75
            part.CanCollide = false
        end
    end
    if not state.hitbox then
        for part, original in pairs(hitboxOriginal) do
            pcall(function()
                part.Size = original.size
                part.Transparency = original.transparency
                part.CanCollide = original.collide
            end)
        end
        hitboxOriginal = {}
    end
end

local function applyMovement()
    local hum = humanoid()
    if hum then
        hum.WalkSpeed = flyRig.active and 0 or state.speed
        hum.UseJumpPower = true
        hum.JumpPower = state.jump
    end
end

-- ===== interface =====
local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    or LocalPlayer:WaitForChild("PlayerGui", 10)

local function makeGui(name, order)
    local gui = Instance.new("ScreenGui")
    gui.Name = name
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = order
    local placed = pcall(function()
        gui.Parent = playerGui
    end)
    if not placed or not gui.Parent then
        pcall(function()
            gui.Parent = game:GetService("CoreGui")
        end)
    end
    if not gui.Parent then
        pcall(function()
            gui.Parent = uiRoot()
        end)
    end
    return gui
end


-- ===== preview 3D do jogador =====
local previewGui = makeGui("BloxPreview", 999997)
previewGui.Enabled = false

local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.fromOffset(260, 320)
previewFrame.Position = UDim2.new(1, -290, 0, 120)
previewFrame.BackgroundColor3 = Color3.fromRGB(14, 17, 23)
previewFrame.BorderSizePixel = 0
previewFrame.Active = true
previewFrame.Parent = previewGui

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 12)
previewCorner.Parent = previewFrame

local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.fromRGB(220, 130, 40)
previewStroke.Thickness = 2
previewStroke.Transparency = 0.3
previewStroke.Parent = previewFrame

local previewTitle = Instance.new("TextLabel")
previewTitle.Size = UDim2.new(1, -40, 0, 30)
previewTitle.Position = UDim2.fromOffset(12, 6)
previewTitle.BackgroundTransparency = 1
previewTitle.Font = Enum.Font.GothamBold
previewTitle.TextSize = 14
previewTitle.TextColor3 = Color3.fromRGB(255, 190, 120)
previewTitle.TextXAlignment = Enum.TextXAlignment.Left
previewTitle.Text = "preview"
previewTitle.Parent = previewFrame

local previewClose = Instance.new("TextButton")
previewClose.Size = UDim2.fromOffset(26, 26)
previewClose.Position = UDim2.new(1, -34, 0, 6)
previewClose.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
previewClose.Text = "x"
previewClose.TextColor3 = Color3.fromRGB(255, 120, 120)
previewClose.Font = Enum.Font.GothamBold
previewClose.TextSize = 14
previewClose.BorderSizePixel = 0
previewClose.Parent = previewFrame

local previewCorner2 = Instance.new("UICorner")
previewCorner2.CornerRadius = UDim.new(0, 8)
previewCorner2.Parent = previewClose

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, -20, 1, -50)
viewport.Position = UDim2.fromOffset(10, 40)
viewport.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
viewport.BorderSizePixel = 0
viewport.Ambient = Color3.fromRGB(200, 200, 200)
viewport.LightColor = Color3.fromRGB(255, 255, 255)
viewport.Parent = previewFrame

local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 10)
viewportCorner.Parent = viewport

local world = Instance.new("WorldModel")
world.Parent = viewport

local previewCamera = Instance.new("Camera")
previewCamera.CFrame = CFrame.new(Vector3.new(0, 3, -12), Vector3.new(0, 3, 0))
previewCamera.Parent = viewport
viewport.CurrentCamera = previewCamera

local previewAngle = 0
local previewTarget = nil
local previewPlayer = nil

local function hidePreview()
    previewGui.Enabled = false
    previewPlayer = nil
    world:ClearAllChildren()
end

previewClose.MouseButton1Click:Connect(hidePreview)

local function showPreview(player)
    if not player or not player.Character then
        return false
    end
    local clone = player.Character:Clone()
    if not clone then
        return false
    end
    for _, object in ipairs(clone:GetDescendants()) do
        if object:IsA("Script") or object:IsA("LocalScript") then
            object:Destroy()
        end
    end
    world:ClearAllChildren()
    clone.Parent = world

    local primary = clone.PrimaryPart or clone:FindFirstChild("HumanoidRootPart")
    if primary then
        clone.PrimaryPart = primary
        clone:PivotTo(CFrame.new(0, 0, 0))
    end
    for _, part in ipairs(clone:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
        end
    end

    previewAngle = 0
    previewPlayer = player
    previewTitle.Text = player.Name
    previewGui.Enabled = true
    return true
end

local function updatePreview(dt)
    if not previewGui.Enabled or not previewPlayer then
        return
    end
    previewAngle = previewAngle + dt * 0.7
    local radius = 13
    previewCamera.CFrame = CFrame.new(
            Vector3.new(math.sin(previewAngle) * radius, 4.5, math.cos(previewAngle) * radius),
            Vector3.new(0, 2.5, 0))
end

local previewDrag = false
local previewStart = nil
local previewOrigin = nil

previewFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        previewDrag = true
        previewStart = input.Position
        previewOrigin = previewFrame.Position
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not previewDrag then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - previewStart
        previewFrame.Position = UDim2.new(previewOrigin.X.Scale, previewOrigin.X.Offset + delta.X,
                previewOrigin.Y.Scale, previewOrigin.Y.Offset + delta.Y)
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        previewDrag = false
    end
end)

session.showPreview = showPreview
session.hidePreview = hidePreview


-- ===== painel de log =====
local logGui = makeGui("BloxLogPanel", 999996)
logGui.Enabled = false

local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.fromOffset(560, 280)
logFrame.Position = UDim2.new(0, 18, 1, -310)
logFrame.BackgroundColor3 = Color3.fromRGB(10, 12, 17)
logFrame.BackgroundTransparency = 0.08
logFrame.BorderSizePixel = 0
logFrame.Active = true
logFrame.Parent = logGui

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 12)
logCorner.Parent = logFrame

local logStroke = Instance.new("UIStroke")
logStroke.Color = Color3.fromRGB(60, 90, 140)
logStroke.Thickness = 1.5
logStroke.Transparency = 0.4
logStroke.Parent = logFrame

local logTitle = Instance.new("TextLabel")
logTitle.Size = UDim2.new(1, -50, 0, 26)
logTitle.Position = UDim2.fromOffset(12, 4)
logTitle.BackgroundTransparency = 1
logTitle.Font = Enum.Font.GothamBold
logTitle.TextSize = 13
logTitle.TextColor3 = Color3.fromRGB(150, 190, 255)
logTitle.TextXAlignment = Enum.TextXAlignment.Left
logTitle.Text = "log do hub"
logTitle.Parent = logFrame

local logClose = Instance.new("TextButton")
logClose.Size = UDim2.fromOffset(24, 24)
logClose.Position = UDim2.new(1, -30, 0, 3)
logClose.BackgroundColor3 = Color3.fromRGB(40, 25, 25)
logClose.Text = "x"
logClose.TextColor3 = Color3.fromRGB(255, 120, 120)
logClose.Font = Enum.Font.GothamBold
logClose.TextSize = 13
logClose.BorderSizePixel = 0
logClose.Parent = logFrame

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, -16, 1, -36)
logScroll.Position = UDim2.fromOffset(8, 30)
logScroll.BackgroundTransparency = 1
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 4
logScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 180)
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.Parent = logFrame

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 1)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = logScroll

local logColors = {
    INFO = Color3.fromRGB(170, 180, 200),
    ACAO = Color3.fromRGB(120, 230, 150),
    AVISO = Color3.fromRGB(255, 210, 110),
    ERRO = Color3.fromRGB(255, 110, 110),
}

local function rebuildLogPanel()
    for _, child in ipairs(logScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    local entries = Log.entries
    local first = math.max(1, #entries - 120)
    for index = first, #entries do
        local entry = entries[index]
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -6, 0, 15)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Code
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = logColors[entry.level] or logColors.INFO
        label.Text = string.format("%s %s", entry.time, entry.text)
        label.LayoutOrder = index
        label.Parent = logScroll
    end
    logScroll.CanvasSize = UDim2.new(0, 0, 0, #entries * 16)
    logScroll.CanvasPosition = Vector2.new(0, math.max(0, #entries * 16 - 240))
end

logClose.MouseButton1Click:Connect(function()
    state.showLogPanel = false
    logGui.Enabled = false
end)

local logDrag = false
local logStart = nil
local logOrigin = nil

logFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        logDrag = true
        logStart = input.Position
        logOrigin = logFrame.Position
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not logDrag then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - logStart
        logFrame.Position = UDim2.new(logOrigin.X.Scale, logOrigin.X.Offset + delta.X,
                logOrigin.Y.Scale, logOrigin.Y.Offset + delta.Y)
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        logDrag = false
    end
end)

session.logGui = logGui

local function setLogPanel(show)
    state.showLogPanel = show
    logGui.Enabled = show
    if show then
        rebuildLogPanel()
    end
end

local function uploadLogs()
    local body = Log.dump()
    if #body < 5 then
        return nil, "log vazio"
    end
    local ok, result = pcall(function()
        return game:HttpPost("https://paste.rs", body, "text/plain")
    end)
    if ok and type(result) == "string" then
        local url = string.match(result, "https?://%S+")
        if url then
            return url
        end
    end
    local ok2, result2 = pcall(function()
        return HttpService:PostAsync("https://paste.rs", body, Enum.HttpContentType.TextPlain)
    end)
    if ok2 and type(result2) == "string" then
        local url = string.match(result2, "https?://%S+")
        if url then
            return url
        end
    end
    return nil, tostring(result)
end

local bubbleGui = makeGui("BloxBubble", 999999)

local bubble = Instance.new("TextButton")
bubble.Size = UDim2.fromOffset(58, 58)
bubble.Position = UDim2.new(0, 18, 0.45, 0)
bubble.BackgroundColor3 = Color3.fromRGB(14, 17, 23)
bubble.BorderSizePixel = 0
bubble.AutoButtonColor = false
bubble.Text = "B"
bubble.Font = Enum.Font.GothamBold
bubble.TextSize = 24
bubble.TextColor3 = Color3.fromRGB(255, 170, 60)
bubble.Parent = bubbleGui

local bubbleCorner = Instance.new("UICorner")
bubbleCorner.CornerRadius = UDim.new(1, 0)
bubbleCorner.Parent = bubble

local bubbleStroke = Instance.new("UIStroke")
bubbleStroke.Color = Color3.fromRGB(220, 130, 40)
bubbleStroke.Thickness = 2
bubbleStroke.Transparency = 0.15
bubbleStroke.Parent = bubble

session.bubble = bubbleGui

local statusGui = makeGui("BloxStatus", 999998)

local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.fromOffset(340, 30)
statusText.Position = UDim2.new(0.5, -170, 1, -70)
statusText.BackgroundColor3 = Color3.fromRGB(14, 17, 23)
statusText.BackgroundTransparency = 0.2
statusText.BorderSizePixel = 0
statusText.Text = "pronto"
statusText.TextColor3 = Color3.fromRGB(255, 200, 140)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 13
statusText.Parent = statusGui

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 10)
statusCorner.Parent = statusText

statusLabel = statusText
session.statusGui = statusGui

local function findWindow()
    local places = {uiRoot(), playerGui}
    for _, place in ipairs(places) do
        if place then
            for _, child in ipairs(place:GetChildren()) do
                if child:IsA("ScreenGui") and string.find(string.lower(child.Name), "rayfield") then
                    local main = child:FindFirstChild("Main")
                    if main then
                        return child, main
                    end
                    for _, item in ipairs(child:GetDescendants()) do
                        if item:IsA("Frame") and item.Name == "Main" then
                            return child, item
                        end
                    end
                    return child, nil
                end
            end
        end
    end
    return nil, nil
end

local function showWindow(show)
    local gui, main = findWindow()
    if gui then
        if main then
            main.Visible = show
        else
            gui.Enabled = show
        end
    end
    local size = show and 42 or 58
    TweenService:Create(bubble, TweenInfo.new(0.2, Enum.EasingStyle.Back),
            {Size = UDim2.fromOffset(size, size)}):Play()
    bubble.TextTransparency = show and 0.45 or 0
    bubble.BackgroundTransparency = show and 0.45 or 0
    return gui ~= nil
end

local dragging = false
local dragStart = nil
local startPosition = nil
local moved = false

bubble.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        moved = false
        dragStart = input.Position
        startPosition = bubble.Position
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        if delta.Magnitude > 6 then
            moved = true
        end
        bubble.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
    end
end)

session.connections[#session.connections + 1] = UserInputService.InputEnded:Connect(function(input)
    if not dragging then
        return
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
        if not moved then
            showWindow(true)
        end
    end
end)

-- ===== FPS =====
local function disablePostEffects()
    for _, object in ipairs(Lighting:GetChildren()) do
        if object:IsA("PostEffect") or object:IsA("Atmosphere") then
            pcall(function()
                object.Enabled = false
            end)
        end
    end
end

local function applyFpsPack()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 1
    end)
    disablePostEffects()
    pcall(function()
        Workspace.Terrain.WaterWaveSize = 0
        Workspace.Terrain.WaterWaveSpeed = 0
        Workspace.Terrain.WaterReflectance = 0
        Workspace.Terrain.WaterTransparency = 1
    end)
    if type(setfpscap) == "function" then
        pcall(function()
            setfpscap(240)
        end)
    end
    status("fps: pacote aplicado")
end

local function killParticles()
    local count = 0
    for _, object in ipairs(Workspace:GetDescendants()) do
        if object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Smoke")
                or object:IsA("Fire") or object:IsA("Sparkles") then
            pcall(function()
                object.Enabled = false
            end)
            count = count + 1
        end
    end
    return count
end

-- ===== atualizacao =====
local function fetchRemoteVersion()
    local ok, text = pcall(function()
        return game:HttpGet(BASE .. "/version.txt?t=" .. tostring(os.time()))
    end)
    if not ok then
        return nil
    end
    return tonumber(string.match(tostring(text), "%d+"))
end

local function applyUpdate()
    local ok, source = pcall(function()
        return game:HttpGet(BASE .. "/bloxfruit.lua?v=" .. tostring(os.time()))
    end)
    if not ok or type(source) ~= "string" or #source < 1500 then
        return false
    end
    local chunk = loadstring(source)
    if not chunk then
        return false
    end
    return pcall(chunk)
end

-- ===== UI =====
local Window = Rayfield:CreateWindow({
    Name = "Blox Fruits",
    LoadingTitle = "carregando hub",
    ConfigurationSaving = {Enabled = false},
})

session.window = Window

local refs = {}

local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateToggle({
    Name = "Auto farm",
    CurrentValue = false,
    Callback = function(value)
        state.autoFarm = value
    end,
})

FarmTab:CreateToggle({
    Name = "Kill aura",
    CurrentValue = false,
    Callback = function(value)
        state.killAura = value
    end,
})

FarmTab:CreateSlider({
    Name = "Raio da aura",
    Range = {10, 200},
    Increment = 5,
    Suffix = "studs",
    CurrentValue = state.auraRange,
    Callback = function(value)
        state.auraRange = value
        markDirty()
    end,
})

FarmTab:CreateToggle({
    Name = "Fast attack",
    CurrentValue = false,
    Callback = function(value)
        state.fastAttack = value
    end,
})

FarmTab:CreateSlider({
    Name = "Intervalo de ataque",
    Range = {0.02, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = state.attackDelay,
    Callback = function(value)
        state.attackDelay = value
        markDirty()
    end,
})

FarmTab:CreateToggle({
    Name = "Hitbox expandida",
    CurrentValue = false,
    Callback = function(value)
        state.hitbox = value
        applyHitbox()
    end,
})

FarmTab:CreateSlider({
    Name = "Tamanho da hitbox",
    Range = {6, 30},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = state.hitboxSize,
    Callback = function(value)
        state.hitboxSize = value
        markDirty()
    end,
})

FarmTab:CreateToggle({
    Name = "Auto pegar fruta",
    CurrentValue = false,
    Callback = function(value)
        state.autoFruit = value
    end,
})

FarmTab:CreateToggle({
    Name = "Auto abrir bau",
    CurrentValue = false,
    Callback = function(value)
        state.autoChest = value
    end,
})

FarmTab:CreateSlider({
    Name = "Alcance do farm",
    Range = {50, 5000},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = state.farmRange,
    Callback = function(value)
        state.farmRange = value
        markDirty()
    end,
})

FarmTab:CreateToggle({
    Name = "Auto missao (automatico)",
    CurrentValue = false,
    Callback = function(value)
        state.autoQuestFly = value
        Log.add("INFO", "auto missao automatico = " .. tostring(value))
    end,
})

FarmTab:CreateSlider({
    Name = "Segundos farmando por missao",
    Range = {10, 180},
    Increment = 5,
    Suffix = "s",
    CurrentValue = state.questSeconds,
    Callback = function(value)
        state.questSeconds = value
        markDirty()
    end,
})

FarmTab:CreateButton({
    Name = "Atacar o mais proximo agora",
    Callback = function()
        farmCycle()
    end,
})

local MoveTab = Window:CreateTab("Movimento", 4483362458)

MoveTab:CreateToggle({
    Name = "Voo: segurar pulo",
    CurrentValue = state.jumpFly,
    Callback = function(value)
        state.jumpFly = value
        if not value then
            destroyRig()
        end
        markDirty()
    end,
})

MoveTab:CreateToggle({
    Name = "Voo continuo",
    CurrentValue = false,
    Callback = function(value)
        state.fly = value
        if not value then
            destroyRig()
        end
    end,
})

MoveTab:CreateSlider({
    Name = "Velocidade do voo",
    Range = {20, 500},
    Increment = 10,
    Suffix = "studs/s",
    CurrentValue = state.flySpeed,
    Callback = function(value)
        state.flySpeed = value
        markDirty()
    end,
})

MoveTab:CreateSlider({
    Name = "Velocidade no chao",
    Range = {16, 300},
    Increment = 2,
    Suffix = "studs/s",
    CurrentValue = state.speed,
    Callback = function(value)
        state.speed = value
        applyMovement()
        markDirty()
    end,
})

MoveTab:CreateSlider({
    Name = "Pulo",
    Range = {50, 200},
    Increment = 5,
    CurrentValue = state.jump,
    Callback = function(value)
        state.jump = value
        applyMovement()
        markDirty()
    end,
})

MoveTab:CreateSlider({
    Name = "Altura maxima",
    Range = {50, 800},
    Increment = 25,
    Suffix = "studs",
    CurrentValue = state.maxFlyHeight,
    Callback = function(value)
        state.maxFlyHeight = value
        markDirty()
    end,
})

MoveTab:CreateButton({
    Name = "Pousar",
    Callback = function()
        state.fly = false
        destroyRig()
    end,
})

MoveTab:CreateButton({
    Name = "Voltar para o spawn",
    Callback = function()
        local spawn = Workspace:FindFirstChild("SpawnLocation")
        if spawn then
            travelTo(spawn.Position + Vector3.new(0, 5, 0), state.travelSpeed)
        end
    end,
})

local EspTab = Window:CreateTab("ESP", 4483362458)

local espToggles = {}

espToggles.fruit = EspTab:CreateToggle({
    Name = "Frutas",
    CurrentValue = state.espFruit,
    Callback = function(value)
        state.espFruit = value
        refreshEsp()
        markDirty()
    end,
})

espToggles.chest = EspTab:CreateToggle({
    Name = "Baus",
    CurrentValue = state.espChest,
    Callback = function(value)
        state.espChest = value
        refreshEsp()
        markDirty()
    end,
})

espToggles.mob = EspTab:CreateToggle({
    Name = "Mobs",
    CurrentValue = state.espMob,
    Callback = function(value)
        state.espMob = value
        refreshEsp()
        markDirty()
    end,
})

espToggles.player = EspTab:CreateToggle({
    Name = "Jogadores",
    CurrentValue = state.espPlayer,
    Callback = function(value)
        state.espPlayer = value
        refreshEsp()
        markDirty()
    end,
})

EspTab:CreateToggle({
    Name = "Mostrar nome",
    CurrentValue = state.espName,
    Callback = function(value)
        state.espName = value
        markDirty()
    end,
})

EspTab:CreateToggle({
    Name = "Mostrar vida",
    CurrentValue = state.espHealth,
    Callback = function(value)
        state.espHealth = value
        markDirty()
    end,
})

EspTab:CreateToggle({
    Name = "Mostrar distancia",
    CurrentValue = state.espDistance,
    Callback = function(value)
        state.espDistance = value
        markDirty()
    end,
})

EspTab:CreateToggle({
    Name = "Linha ate o alvo (tracer)",
    CurrentValue = state.espTracer,
    Callback = function(value)
        state.espTracer = value
        for model in pairs(espItems) do
            removeEsp(model)
        end
        refreshEsp()
        markDirty()
    end,
})

EspTab:CreateSlider({
    Name = "Alcance do ESP",
    Range = {100, 5000},
    Increment = 100,
    Suffix = "studs",
    CurrentValue = state.espRange,
    Callback = function(value)
        state.espRange = value
        markDirty()
    end,
})

local function resetEspVisuals()
    for model in pairs(espItems) do
        removeEsp(model)
    end
    refreshEsp()
end

local playerDropdown = nil

playerDropdown = EspTab:CreateDropdown({
    Name = "Jogador (lista)",
    Options = {"(vazio)"},
    CurrentOption = {"(vazio)"},
    MultipleOptions = false,
    Callback = function(option)
        local name = type(option) == "table" and option[1] or option
        if name and name ~= "(vazio)" then
            state.selectedPlayer = name
        end
    end,
})

EspTab:CreateButton({
    Name = "Ver jogador em 3D",
    Callback = function()
        local name = state.selectedPlayer
        local player = name and Players:FindFirstChild(name)
        if not player then
            Rayfield:Notify({Title = "Preview", Content = "Escolhe um jogador na lista.", Duration = 4})
            return
        end
        if session.showPreview and session.showPreview(player) then
            Rayfield:Notify({Title = "Preview", Content = player.Name .. " em 3D.", Duration = 3})
        else
            Rayfield:Notify({Title = "Preview", Content = "Jogador sem personagem.", Duration = 4})
        end
    end,
})

EspTab:CreateButton({
    Name = "Atualizar lista de jogadores",
    Callback = function()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                names[#names + 1] = player.Name
            end
        end
        if #names == 0 then
            names = {"(vazio)"}
        end
        if playerDropdown then
            playerDropdown:Refresh(names)
        end
        Rayfield:Notify({Title = "Lista", Content = #names .. " jogador(es).", Duration = 3})
    end,
})

EspTab:CreateToggle({
    Name = "Espectar jogador selecionado",
    CurrentValue = false,
    Callback = function(value)
        state.spectate = value
        if not value then
            local camera = Workspace.CurrentCamera
            local hum = humanoid()
            if camera and hum then
                camera.CameraSubject = hum
            end
        end
    end,
})

EspTab:CreateToggle({
    Name = "ESP so do jogador selecionado",
    CurrentValue = false,
    Callback = function(value)
        state.espOnlySelected = value
        resetEspVisuals()
    end,
})

EspTab:CreateToggle({
    Name = "Preenchimento (fill)",
    CurrentValue = state.espFill,
    Callback = function(value)
        state.espFill = value
        resetEspVisuals()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor: jogadores",
    Color = Color3.fromRGB(80, 160, 255),
    Callback = function(color)
        state.colorPlayer = {math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)}
        resetEspVisuals()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor: mobs",
    Color = Color3.fromRGB(255, 80, 80),
    Callback = function(color)
        state.colorMob = {math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)}
        resetEspVisuals()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor: frutas",
    Color = Color3.fromRGB(255, 200, 60),
    Callback = function(color)
        state.colorFruit = {math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)}
        resetEspVisuals()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor: baus",
    Color = Color3.fromRGB(60, 220, 120),
    Callback = function(color)
        state.colorChest = {math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)}
        resetEspVisuals()
    end,
})

EspTab:CreateButton({
    Name = "Limpar ESP",
    Callback = function()
        state.espFruit = false
        state.espChest = false
        state.espMob = false
        state.espPlayer = false
        for model in pairs(espItems) do
            removeEsp(model)
        end
    end,
})

local TpTab = Window:CreateTab("Teleporte", 4483362458)

TpTab:CreateInput({
    Name = "Nome do ponto",
    CurrentValue = "",
    PlaceholderText = "ex: ilha 2",
    RemoveTextAfterFocusLost = false,
    Callback = function(text)
        state.newWaypoint = text
    end,
})

TpTab:CreateButton({
    Name = "Salvar ponto aqui",
    Callback = function()
        local root = rootPart()
        local name = state.newWaypoint
        if not root or not name or name == "" then
            Rayfield:Notify({Title = "Ponto", Content = "Precisa de nome e personagem.", Duration = 4})
            return
        end
        state.waypoints[name] = {x = root.Position.X, y = root.Position.Y, z = root.Position.Z}
        markDirty()
        Rayfield:Notify({Title = "Ponto", Content = name .. " salvo.", Duration = 3})
    end,
})

TpTab:CreateButton({
    Name = "Ir flutuando (sem teleporte)",
    Callback = function()
        local name = state.newWaypoint
        local point = name and state.waypoints[name]
        if not point then
            Rayfield:Notify({Title = "Ponto", Content = "Nome nao encontrado.", Duration = 4})
            return
        end
        task.spawn(function()
            status("indo flutuando para " .. name)
            travelTo(Vector3.new(point.x, point.y, point.z), state.travelSpeed)
            status("chegou em " .. name)
        end)
    end,
})

TpTab:CreateButton({
    Name = "Listar pontos salvos",
    Callback = function()
        print("=== PONTOS ===")
        for name, point in pairs(state.waypoints) do
            print(string.format("%s  (%.0f, %.0f, %.0f)", name, point.x, point.y, point.z))
        end
    end,
})

TpTab:CreateSlider({
    Name = "Velocidade do deslocamento",
    Range = {50, 400},
    Increment = 10,
    Suffix = "studs/s",
    CurrentValue = state.travelSpeed,
    Callback = function(value)
        state.travelSpeed = value
        markDirty()
    end,
})

local islandDropdown = nil
local playerTpDropdown = nil

islandDropdown = TpTab:CreateDropdown({
    Name = "Ilha / missao (lista)",
    Options = {"(atualize a lista)"},
    CurrentOption = {"(atualize a lista)"},
    MultipleOptions = false,
    Callback = function(option)
        local name = type(option) == "table" and option[1] or option
        if name then
            state.selectedIsland = name
        end
    end,
})

TpTab:CreateButton({
    Name = "Atualizar lista de ilhas",
    Callback = function()
        local list = refreshIslands()
        local names = {}
        for _, island in ipairs(list) do
            names[#names + 1] = island.name
        end
        if #names == 0 then
            names = {"(nenhuma encontrada)"}
        end
        if islandDropdown then
            islandDropdown:Refresh(names)
        end
        Log.add("INFO", "ilhas encontradas: " .. #list)
        for _, island in ipairs(list) do
            Log.add("INFO", string.format("  %s | %.0f, %.0f, %.0f", island.name,
                    island.position.X, island.position.Y, island.position.Z))
        end
        Rayfield:Notify({Title = "Ilhas", Content = #list .. " destino(s).", Duration = 4})
    end,
})

TpTab:CreateButton({
    Name = "Viajar flutuando para a ilha",
    Callback = function()
        local name = state.selectedIsland
        local island = name and findIsland(name)
        if not island then
            Rayfield:Notify({Title = "Viagem", Content = "Escolhe uma ilha na lista.", Duration = 4})
            return
        end
        task.spawn(function()
            status("viajando para " .. island.name)
            Log.add("ACAO", "viagem para " .. island.name)
            local ok, err = pcall(function()
                travelTo(island.position + Vector3.new(0, 6, 0), state.travelSpeed)
            end)
            if ok then
                status("chegou em " .. island.name)
                Log.add("ACAO", "chegou em " .. island.name)
            else
                Log.add("ERRO", "viagem: " .. tostring(err))
            end
        end)
    end,
})

playerTpDropdown = TpTab:CreateDropdown({
    Name = "Jogador (lista)",
    Options = {"(vazio)"},
    CurrentOption = {"(vazio)"},
    MultipleOptions = false,
    Callback = function(option)
        local name = type(option) == "table" and option[1] or option
        if name and name ~= "(vazio)" then
            state.selectedPlayer = name
        end
    end,
})

TpTab:CreateButton({
    Name = "Ir ate o jogador selecionado",
    Callback = function()
        local name = state.selectedPlayer
        local player = name and Players:FindFirstChild(name)
        local root = player and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then
            Rayfield:Notify({Title = "Viagem", Content = "Jogador sem personagem.", Duration = 4})
            return
        end
        task.spawn(function()
            status("indo ate " .. player.Name)
            Log.add("ACAO", "indo ate o jogador " .. player.Name)
            travelTo(root.Position + Vector3.new(0, 6, 0), state.travelSpeed)
        end)
    end,
})

TpTab:CreateButton({
    Name = "Atualizar lista de jogadores",
    Callback = function()
        local names = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                names[#names + 1] = player.Name
            end
        end
        if #names == 0 then
            names = {"(vazio)"}
        end
        if playerTpDropdown then
            playerTpDropdown:Refresh(names)
        end
        Rayfield:Notify({Title = "Jogadores", Content = #names .. " na lista.", Duration = 3})
    end,
})

TpTab:CreateButton({
    Name = "Ir para o spawn flutuando",
    Callback = function()
        local spawn = Workspace:FindFirstChild("SpawnLocation")
        if spawn then
            task.spawn(function()
                travelTo(spawn.Position + Vector3.new(0, 5, 0), state.travelSpeed)
            end)
        end
    end,
})

local FpsTab = Window:CreateTab("FPS", 4483362458)

FpsTab:CreateButton({
    Name = "Aplicar pacote FPS",
    Callback = function()
        applyFpsPack()
        Rayfield:Notify({Title = "FPS", Content = "Qualidade baixa, sombras off, teto 240.", Duration = 4})
    end,
})

FpsTab:CreateButton({
    Name = "Desligar particulas do mapa",
    Callback = function()
        local count = killParticles()
        Rayfield:Notify({Title = "FPS", Content = count .. " efeitos desligados.", Duration = 4})
    end,
})

FpsTab:CreateButton({
    Name = "Desligar efeitos de luz",
    Callback = function()
        disablePostEffects()
        Rayfield:Notify({Title = "FPS", Content = "Bloom, blur e afins desligados.", Duration = 4})
    end,
})

FpsTab:CreateToggle({
    Name = "Sem nevoa",
    CurrentValue = false,
    Callback = function(value)
        state.noFog = value
        pcall(function()
            Lighting.FogEnd = value and 1000000 or 1000
        end)
    end,
})

FpsTab:CreateButton({
    Name = "Teto de FPS 240",
    Callback = function()
        if type(setfpscap) == "function" then
            pcall(function()
                setfpscap(240)
            end)
            Rayfield:Notify({Title = "FPS", Content = "Teto em 240.", Duration = 3})
        else
            Rayfield:Notify({Title = "FPS", Content = "Executor sem setfpscap.", Duration = 4})
        end
    end,
})

FpsTab:CreateButton({
    Name = "Mostrar FPS atual",
    Callback = function()
        Rayfield:Notify({Title = "FPS",
                         Content = "atual: " .. math.floor(1 / RunService.RenderStepped:Wait()), Duration = 3})
    end,
})

local MiscTab = Window:CreateTab("Misc", 4483362458)

MiscTab:CreateToggle({
    Name = "Anti AFK",
    CurrentValue = state.antiAfk,
    Callback = function(value)
        state.antiAfk = value
        markDirty()
    end,
})

MiscTab:CreateToggle({
    Name = "No clip",
    CurrentValue = false,
    Callback = function(value)
        state.noClip = value
        if not value then
            for _, part in ipairs(LocalPlayer.Character and LocalPlayer.Character:GetDescendants() or {}) do
                if part:IsA("BasePart") then
                    pcall(function()
                        part.CanCollide = true
                    end)
                end
            end
        end
    end,
})

MiscTab:CreateToggle({
    Name = "Auto equipar arma",
    CurrentValue = state.autoEquip,
    Callback = function(value)
        state.autoEquip = value
        markDirty()
    end,
})

MiscTab:CreateButton({
    Name = "Reentrar no servidor",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        if type(queue_on_teleport) == "function" then
            pcall(function()
                queue_on_teleport([[loadstring(game:HttpGet("https://is.gd/jP48vV"))()]])
            end)
        end
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end,
})

MiscTab:CreateButton({
    Name = "Servidor novo (hop)",
    Callback = function()
        local TeleportService = game:GetService("TeleportService")
        local HttpService2 = game:GetService("HttpService")
        local ok, servers = pcall(function()
            return HttpService2:JSONDecode(game:HttpGet(
                    "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=50"))
        end)
        if ok and servers and servers.data then
            for _, server in ipairs(servers.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                    end)
                    return
                end
            end
        end
        Rayfield:Notify({Title = "Hop", Content = "Nenhum servidor livre.", Duration = 4})
    end,
})

MiscTab:CreateButton({
    Name = "Salvar configuracoes",
    Callback = function()
        if saveConfig() then
            Rayfield:Notify({Title = "Config", Content = "Salvo.", Duration = 3})
        else
            Rayfield:Notify({Title = "Config", Content = "Sem permissao de arquivo.", Duration = 4})
        end
    end,
})

MiscTab:CreateButton({
    Name = "Verificar atualizacao",
    Callback = function()
        local remote = fetchRemoteVersion()
        if not remote then
            Rayfield:Notify({Title = "Atualizacao", Content = "Nao consegui checar.", Duration = 4})
            return
        end
        if remote <= SCRIPT_VERSION then
            Rayfield:Notify({Title = "Atualizacao", Content = "Ja esta na v" .. SCRIPT_VERSION, Duration = 4})
            return
        end
        if applyUpdate() then
            Rayfield:Notify({Title = "Atualizado", Content = "v" .. remote, Duration = 5})
        else
            Rayfield:Notify({Title = "Falhou", Content = "Tenta de novo.", Duration = 4})
        end
    end,
})

MiscTab:CreateButton({
    Name = "Minimizar em bolinha",
    Callback = function()
        showWindow(false)
    end,
})

local LogTab = Window:CreateTab("Logs", 4483362458)

LogTab:CreateToggle({
    Name = "Painel de log na tela",
    CurrentValue = false,
    Callback = function(value)
        setLogPanel(value)
    end,
})

LogTab:CreateToggle({
    Name = "Log verboso (console)",
    CurrentValue = state.verboseLogs,
    Callback = function(value)
        state.verboseLogs = value
    end,
})

LogTab:CreateButton({
    Name = "Copiar logs",
    Callback = function()
        local text = Log.dump()
        if type(setclipboard) == "function" then
            pcall(function()
                setclipboard(text)
            end)
            Rayfield:Notify({Title = "Logs", Content = #Log.lines .. " linhas copiadas.", Duration = 4})
        else
            print(text)
            Rayfield:Notify({Title = "Logs", Content = "Sem clipboard. Imprimi no console.", Duration = 5})
        end
    end,
})

LogTab:CreateButton({
    Name = "Enviar logs (gera link)",
    Callback = function()
        Rayfield:Notify({Title = "Logs", Content = "Enviando...", Duration = 2})
        task.spawn(function()
            local url, err = uploadLogs()
            if url then
                if type(setclipboard) == "function" then
                    pcall(function()
                        setclipboard(url)
                    end)
                end
                Log.add("ACAO", "logs enviados: " .. url)
                Rayfield:Notify({Title = "Logs", Content = url, Duration = 12})
            else
                Log.add("ERRO", "envio falhou: " .. tostring(err))
                Rayfield:Notify({Title = "Logs",
                                 Content = "Falhou. Usa Copiar logs.", Duration = 6})
            end
        end)
    end,
})

LogTab:CreateButton({
    Name = "Salvar logs em arquivo",
    Callback = function()
        if type(writefile) ~= "function" then
            Rayfield:Notify({Title = "Logs", Content = "Executor sem writefile.", Duration = 4})
            return
        end
        local ok = pcall(function()
            writefile(LOG_PATH, Log.dump())
        end)
        Rayfield:Notify({Title = "Logs",
                         Content = ok and ("salvo em " .. LOG_PATH) or "falhou", Duration = 4})
    end,
})

LogTab:CreateButton({
    Name = "Limpar logs",
    Callback = function()
        Log.clear()
        rebuildLogPanel()
    end,
})

LogTab:CreateButton({
    Name = "Resumo do estado",
    Callback = function()
        Log.add("INFO", string.format(
                "estado: farm=%s aura=%s fast=%s hitbox=%s voo=%s esp(f=%s c=%s m=%s p=%s) modo=%s",
                tostring(state.autoFarm), tostring(state.killAura), tostring(state.fastAttack),
                tostring(state.hitbox), tostring(state.fly or state.jumpFly),
                tostring(state.espFruit), tostring(state.espChest), tostring(state.espMob),
                tostring(state.espPlayer), state.moveMode))
        Log.add("INFO", string.format("inimigos=%d frutas=%d baus=%d ferramenta=%s",
                #collectEnemies(), #collectFruits(), #collectChests(),
                currentTool() and currentTool().Name or "nenhuma"))
        setLogPanel(true)
    end,
})

local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateButton({
    Name = "Diagnostico do mapa",
    Callback = function()
        print("=== DIAGNOSTICO ===")
        print("versao:", SCRIPT_VERSION)
        print("ferramenta:", currentTool() and currentTool().Name or "NENHUMA")
        print("modo movimento:", state.moveMode)
        local folders = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            if child:IsA("Folder") then
                folders[#folders + 1] = child.Name .. "(" .. #child:GetChildren() .. ")"
            end
        end
        print("pastas:", table.concat(folders, ", "))
        local enemies = collectEnemies()
        print("inimigos:", #enemies)
        local counted = {}
        for _, enemy in ipairs(enemies) do
            counted[enemy.model.Name] = (counted[enemy.model.Name] or 0) + 1
        end
        for name, count in pairs(counted) do
            print("   ", name, "x" .. count)
        end
        print("frutas:", #collectFruits())
        print("baus:", #collectChests())
    end,
})

InfoTab:CreateButton({
    Name = "Teste rapido",
    Callback = function()
        print("=== TESTE ===")
        print("ferramenta:", currentTool() and currentTool().Name or "NENHUMA")
        local enemy, distance = pickTarget()
        if not enemy then
            print("alvo: nenhum")
            return
        end
        print("alvo:", enemy.model.Name, math.floor(distance))
        local before = rootPart() and rootPart().Position
        local built = buildRig()
        print("rig:", built)
        if built then
            local ok = travelTo(enemy.part.Position + Vector3.new(0, 3, 0), 150)
            local after = rootPart() and rootPart().Position
            print("chegou:", ok, "| andou:",
                    (before and after) and math.floor((after - before).Magnitude) or -1)
            destroyRig()
        end
    end,
})

InfoTab:CreateButton({
    Name = "Perfil recomendado",
    Callback = function()
        state.speed = 18
        state.jump = 50
        state.flySpeed = 150
        state.maxFlyHeight = 300
        state.travelSpeed = 150
        state.farmRange = 1500
        state.attackDelay = 0.05
        state.hitbox = true
        state.hitboxSize = 14
        state.jumpFly = true
        state.espFruit = true
        state.espChest = true
        state.espName = true
        state.espHealth = true
        state.espDistance = true
        state.antiAfk = true
        applyMovement()
        applyHitbox()
        applyFpsPack()
        markDirty()
        Rayfield:Notify({Title = "Perfil",
                         Content = "Voo 150, hitbox 14, FPS pacote, farm 1500.", Duration = 5})
    end,
})

-- ===== loops =====
session.connections[#session.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    updateFly(dt)
    updatePreview(dt)
    if state.spectate and state.selectedPlayer then
        local player = Players:FindFirstChild(state.selectedPlayer)
        local hum = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local camera = Workspace.CurrentCamera
        if hum and camera and camera.CameraSubject ~= hum then
            camera.CameraSubject = hum
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    Log.add("INFO", "personagem carregado")
    destroyRig()
    task.wait(1)
    applyMovement()
    refreshEsp()
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.5)
        pcall(function()
        refreshEsp()
        applyMovement()
        if state.hitbox then
            applyHitbox()
        end
        if state.noClip then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function()
                            part.CanCollide = false
                        end)
                    end
                end
            end
        end
        end)
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.05)
        if state.fastAttack then
            activateTool()
        end
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.4)
        if state.killAura then
            local mine = rootPart()
            if mine then
                for _, enemy in ipairs(collectEnemies()) do
                    if (enemy.part.Position - mine.Position).Magnitude <= state.auraRange then
                        activateTool()
                        break
                    end
                end
            end
        end
    end
end)

local lastCycleAt = os.clock()

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.5)
        if os.clock() - lastCycleAt > 30 then
            lastCycleAt = os.clock()
            Log.add("AVISO", "loop parado ha 30s (nenhum ciclo concluido)")
        end
        lastCycleAt = os.clock()
        if flyRig.active and flyRig.holdTimer > 0.45 then
            status("voo manual")
        elseif state.autoQuestFly then
            local ok, err = pcall(questCycle)
            if not ok then
                Log.add("ERRO", "questCycle: " .. tostring(err))
            end
        elseif state.autoFarm then
            local ok, err = pcall(farmCycle)
            if not ok then
                Log.add("ERRO", "farmCycle: " .. tostring(err))
            end
        elseif state.autoFruit then
            local ok, err = pcall(fruitCycle)
            if not ok then
                Log.add("ERRO", "fruitCycle: " .. tostring(err))
            end
        elseif state.autoChest then
            local ok, err = pcall(chestCycle)
            if not ok then
                Log.add("ERRO", "chestCycle: " .. tostring(err))
            end
        end
    end
end)



task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.4)
        if state.showLogPanel and Log.dirtyPanel then
            Log.dirtyPanel = false
            pcall(rebuildLogPanel)
        end
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(1)
        if dirty then
            dirty = false
            saveConfig()
        end
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(60)
        if state.antiAfk then
            pcall(function()
                local vu = game:GetService("VirtualUser")
                vu:CaptureController()
                vu:ClickButton2(Vector2.new())
            end)
        end
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(10)
        pcall(function()
            local list = refreshIslands()
            if islandDropdown and #list > 0 then
                local names = {}
                for _, island in ipairs(list) do
                    names[#names + 1] = island.name
                end
                islandDropdown:Refresh(names)
            end
        end)
        if playerTpDropdown then
            local names = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    names[#names + 1] = player.Name
                end
            end
            if #names > 0 then
                pcall(function()
                    playerTpDropdown:Refresh(names)
                end)
            end
        end
    end
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(6)
        if playerDropdown then
            local names = {}
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    names[#names + 1] = player.Name
                end
            end
            if #names > 0 then
                pcall(function()
                    playerDropdown:Refresh(names)
                end)
            end
        end
    end
end)

task.spawn(function()
    task.wait(3)
    local remote = fetchRemoteVersion()
    if remote and remote > SCRIPT_VERSION then
        Rayfield:Notify({Title = "Atualizacao",
                         Content = "v" .. remote .. ". Misc > Verificar.", Duration = 8})
    end
end)

applyMovement()
refreshEsp()
Log.add("INFO", "hub v" .. SCRIPT_VERSION .. " carregado")
Log.add("INFO", string.format("executor: %s | place: %s",
        tostring(identifyexecutor and identifyexecutor() or "?"), tostring(game.PlaceId)))
Log.add("INFO", string.format("inimigos=%d frutas=%d baus=%d",
        #collectEnemies(), #collectFruits(), #collectChests()))
print("blox hub v" .. SCRIPT_VERSION .. " carregado")
