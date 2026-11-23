-- Blox Fruits | hub v2
-- executor: Delta, Xeno, Solara, Fluxus, Wave
-- sem webhook, sem HttpPost.

local BASE = "https://raw.githubusercontent.com/whesleydev/bloxfruit-hub/main"
local SCRIPT_VERSION = 2
local CONFIG_PATH = "bloxfruit_config.json"

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local previous = _G.__bloxHub
if previous then
    pcall(function()
        if previous.window and previous.window.Destroy then
            previous.window:Destroy()
        end
        if previous.bubble then
            previous.bubble:Destroy()
        end
        if previous.statusGui then
            previous.statusGui:Destroy()
        end
        if previous.espFolder then
            previous.espFolder:Destroy()
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
    flySpeed = 120,
    fly = false,
    jumpFly = true,
    maxFlyHeight = 250,
    autoFarm = false,
    autoFruit = false,
    autoChest = false,
    fastAttack = false,
    attackDelay = 0.08,
    farmRange = 800,
    espFruit = true,
    espChest = true,
    espPlayer = false,
    espMob = false,
    targetName = "auto",
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
    for _, key in ipairs({"speed", "jump", "flySpeed", "maxFlyHeight",
                          "farmRange", "attackDelay"}) do
        state[key] = tonumber(saved[key]) or state[key]
    end
    for _, key in ipairs({"jumpFly", "espFruit", "espChest", "espPlayer", "espMob"}) do
        if type(saved[key]) == "boolean" then
            state[key] = saved[key]
        end
    end
end

local dirty = false

local function markDirty()
    dirty = true
end

local function saveConfig()
    if not hasFileApi() then
        return false
    end
    local data = {
        version = SCRIPT_VERSION,
        speed = state.speed,
        jump = state.jump,
        flySpeed = state.flySpeed,
        maxFlyHeight = state.maxFlyHeight,
        farmRange = state.farmRange,
        attackDelay = state.attackDelay,
        jumpFly = state.jumpFly,
        espFruit = state.espFruit,
        espChest = state.espChest,
        espPlayer = state.espPlayer,
        espMob = state.espMob,
    }
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
end

local function humanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function rootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ===== voo: AlignPosition =====
local flyRig = {
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
    if flyRig.active and (not flyRig.align or not flyRig.align.Parent) then
        destroyRig()
    end

    local held = UserInputService:IsKeyDown(Enum.KeyCode.Space)
            or hum.Jump
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

local function travelTo(target, speed)
    local root = rootPart()
    if not root or not target then
        return false
    end
    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    flyRig.target = root.Position
    flyRig.align.Position = flyRig.target

    local maxSpeed = math.min(speed, 200)
    local deadline = os.clock() + 12
    local reached = false

    while os.clock() < deadline do
        if _G.__bloxHub ~= session then
            break
        end
        if not rootPart() or not flyRig.align then
            break
        end
        local dt = RunService.Heartbeat:Wait()
        if dt > 0.25 then
            dt = 0.25
        end
        local delta = target - flyRig.target
        if delta.Magnitude < 6 then
            reached = true
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
    end

    if owned then
        destroyRig()
    end
    return reached
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

-- ===== descoberta de alvos =====
local function isPlayerCharacter(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function aliveRoot(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return nil
    end
    return model:FindFirstChild("HumanoidRootPart")
            or model:FindFirstChild("UpperTorso")
            or model:FindFirstChildWhichIsA("BasePart")
end

local function collectEnemies()
    local out = {}
    local seen = {}
    local function consider(model)
        if seen[model] or model == LocalPlayer.Character then
            return
        end
        seen[model] = true
        if isPlayerCharacter(model) then
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
    return out
end

-- ===== ESP limpo =====
local espFolder = nil

local function uiRoot()
    if type(gethui) == "function" then
        local ok, value = pcall(gethui)
        if ok and value then
            return value
        end
    end
    return game:GetService("CoreGui")
end

espFolder = Instance.new("Folder")
espFolder.Name = "BloxEsp"
pcall(function()
    espFolder.Parent = uiRoot()
end)
session.espFolder = espFolder

local espItems = {}

local function removeEsp(model)
    local item = espItems[model]
    if not item then
        return
    end
    for _, object in ipairs(item) do
        pcall(function()
            object:Destroy()
        end)
    end
    espItems[model] = nil
end

local function ensureEsp(model, part, color, text)
    local item = espItems[model]
    if item and item[1] and item[1].Parent then
        if item[3] then
            local distance = (rootPart() and (part.Position - rootPart().Position).Magnitude) or 0
            item[3].Text = string.format("%s  [%d]", text, math.floor(distance))
        end
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.FillTransparency = 1
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = model
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(160, 26)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 2000
    billboard.Adornee = part
    billboard.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.4
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = text
    label.Parent = billboard

    espItems[model] = {highlight, billboard, label}
end

local function refreshEsp()
    local active = {}
    if state.espFruit then
        for _, fruit in ipairs(collectFruits()) do
            active[fruit.model] = true
            ensureEsp(fruit.model, fruit.part, Color3.fromRGB(255, 200, 60), fruit.model.Name)
        end
    end
    if state.espChest then
        for _, chest in ipairs(collectChests()) do
            active[chest.model] = true
            ensureEsp(chest.model, chest.part, Color3.fromRGB(60, 220, 120), "bau")
        end
    end
    if state.espMob then
        for _, enemy in ipairs(collectEnemies()) do
            active[enemy.model] = true
            ensureEsp(enemy.model, enemy.part, Color3.fromRGB(255, 80, 80), enemy.model.Name)
        end
    end
    if state.espPlayer then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    active[player.Character] = true
                    ensureEsp(player.Character, root, Color3.fromRGB(80, 160, 255), player.Name)
                end
            end
        end
    end

    for model in pairs(espItems) do
        if not active[model] or not model.Parent then
            removeEsp(model)
        end
    end
end

-- ===== combate =====
local function currentTool()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Tool")
end

local function activateTool()
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
        status("farm: sem alvo em " .. math.floor(state.farmRange) .. " studs")
        return false
    end
    status(string.format("farm: %s | %d studs", enemy.model.Name, math.floor(distance)))

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    local target = enemy.part.Position + Vector3.new(0, 3, 0)
    travelTo(target, state.flySpeed)

    local started = os.clock()
    while os.clock() - started < 3 and _G.__bloxHub == session do
        if not enemy.model.Parent or not aliveRoot(enemy.model) then
            break
        end
        local mine = rootPart()
        if mine and (enemy.part.Position - mine.Position).Magnitude > 14 then
            flyRig.target = enemy.part.Position + Vector3.new(0, 3, 0)
            flyRig.align.Position = flyRig.target
        end
        activateTool()
        task.wait(state.attackDelay)
    end

    if owned then
        destroyRig()
    end
    return true
end

local function fruitCycle()
    local fruits = collectFruits()
    if #fruits == 0 then
        status("fruta: nenhuma no mapa")
        return false
    end
    local fruit = fruits[1]
    status("fruta: indo em " .. fruit.model.Name)

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    local ok = travelTo(fruit.part.Position + Vector3.new(0, 3, 0), state.flySpeed)
    if ok then
        touchSweep(1.0)
        status("fruta: " .. fruit.model.Name .. " ao alcance")
    end

    if owned then
        destroyRig()
    end
    return ok
end

local function chestCycle()
    local chests = collectChests()
    if #chests == 0 then
        status("bau: nenhum no mapa")
        return false
    end
    local chest = chests[1]
    status("bau: indo abrir")

    local owned = false
    if not flyRig.active then
        if not buildRig() then
            return false
        end
        owned = true
    end

    local ok = travelTo(chest.part.Position + Vector3.new(0, 3, 0), state.flySpeed)
    if ok then
        touchSweep(0.8)
    end

    if owned then
        destroyRig()
    end
    return ok
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
statusGui.Enabled = true

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

local speedSlider, jumpSlider, flySlider, rangeSlider, delaySlider
local jumpFlyToggle

local MainTab = Window:CreateTab("Farm", 4483362458)

MainTab:CreateToggle({
    Name = "Auto farm",
    CurrentValue = false,
    Flag = "autofarm",
    Callback = function(value)
        state.autoFarm = value
    end,
})

MainTab:CreateToggle({
    Name = "Fast attack",
    CurrentValue = false,
    Flag = "fastattack",
    Callback = function(value)
        state.fastAttack = value
    end,
})

MainTab:CreateToggle({
    Name = "Auto pegar fruta",
    CurrentValue = false,
    Flag = "autofruit",
    Callback = function(value)
        state.autoFruit = value
    end,
})

MainTab:CreateToggle({
    Name = "Auto abrir bau",
    CurrentValue = false,
    Flag = "autochest",
    Callback = function(value)
        state.autoChest = value
    end,
})

MainTab:CreateButton({
    Name = "Atacar o mais proximo agora",
    Callback = function()
        farmCycle()
    end,
})

rangeSlider = MainTab:CreateSlider({
    Name = "Alcance do farm",
    Range = {50, 3000},
    Increment = 50,
    Suffix = "studs",
    CurrentValue = state.farmRange,
    Flag = "farmrange",
    Callback = function(value)
        state.farmRange = value
        markDirty()
    end,
})

delaySlider = MainTab:CreateSlider({
    Name = "Intervalo de ataque",
    Range = {0.02, 0.5},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = state.attackDelay,
    Flag = "attackdelay",
    Callback = function(value)
        state.attackDelay = value
        markDirty()
    end,
})

MainTab:CreateButton({
    Name = "Minimizar em bolinha",
    Callback = function()
        showWindow(false)
    end,
})

MainTab:CreateButton({
    Name = "Salvar configuracoes",
    Callback = function()
        if saveConfig() then
            Rayfield:Notify({Title = "Config", Content = "Salvo.", Duration = 3})
        else
            Rayfield:Notify({Title = "Config", Content = "Executor sem permissao de arquivo.", Duration = 4})
        end
    end,
})

MainTab:CreateButton({
    Name = "Verificar atualizacao",
    Callback = function()
        local remote = fetchRemoteVersion()
        if not remote then
            Rayfield:Notify({Title = "Atualizacao", Content = "Nao consegui checar agora.", Duration = 4})
            return
        end
        if remote <= SCRIPT_VERSION then
            Rayfield:Notify({Title = "Atualizacao",
                             Content = "Voce ja esta na v" .. SCRIPT_VERSION .. ".", Duration = 4})
            return
        end
        if applyUpdate() then
            Rayfield:Notify({Title = "Atualizado", Content = "v" .. remote .. " no ar.", Duration = 5})
        else
            Rayfield:Notify({Title = "Falhou", Content = "Tenta de novo em instantes.", Duration = 5})
        end
    end,
})

local MoveTab = Window:CreateTab("Movimento", 4483362458)

jumpFlyToggle = MoveTab:CreateToggle({
    Name = "Voo: segurar pulo",
    CurrentValue = state.jumpFly,
    Flag = "jumpfly",
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
    Flag = "fly",
    Callback = function(value)
        state.fly = value
        if not value then
            destroyRig()
        end
    end,
})

speedSlider = MoveTab:CreateSlider({
    Name = "Velocidade",
    Range = {16, 200},
    Increment = 2,
    Suffix = "studs/s",
    CurrentValue = state.speed,
    Flag = "speed",
    Callback = function(value)
        state.speed = value
        applyMovement()
        markDirty()
    end,
})

jumpSlider = MoveTab:CreateSlider({
    Name = "Pulo",
    Range = {50, 150},
    Increment = 5,
    Suffix = "power",
    CurrentValue = state.jump,
    Flag = "jump",
    Callback = function(value)
        state.jump = value
        applyMovement()
        markDirty()
    end,
})

flySlider = MoveTab:CreateSlider({
    Name = "Velocidade do voo",
    Range = {20, 400},
    Increment = 10,
    Suffix = "studs/s",
    CurrentValue = state.flySpeed,
    Flag = "flyspeed",
    Callback = function(value)
        state.flySpeed = value
        markDirty()
    end,
})

MoveTab:CreateSlider({
    Name = "Altura maxima",
    Range = {50, 600},
    Increment = 25,
    Suffix = "studs",
    CurrentValue = state.maxFlyHeight,
    Flag = "maxheight",
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

local VisualTab = Window:CreateTab("Visual", 4483362458)

VisualTab:CreateToggle({
    Name = "ESP frutas",
    CurrentValue = state.espFruit,
    Flag = "espfruit",
    Callback = function(value)
        state.espFruit = value
        refreshEsp()
        markDirty()
    end,
})

VisualTab:CreateToggle({
    Name = "ESP baus",
    CurrentValue = state.espChest,
    Flag = "espchest",
    Callback = function(value)
        state.espChest = value
        refreshEsp()
        markDirty()
    end,
})

VisualTab:CreateToggle({
    Name = "ESP mobs",
    CurrentValue = state.espMob,
    Flag = "espmob",
    Callback = function(value)
        state.espMob = value
        refreshEsp()
        markDirty()
    end,
})

VisualTab:CreateToggle({
    Name = "ESP jogadores",
    CurrentValue = state.espPlayer,
    Flag = "espplayer",
    Callback = function(value)
        state.espPlayer = value
        refreshEsp()
        markDirty()
    end,
})

VisualTab:CreateButton({
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

VisualTab:CreateButton({
    Name = "Forcar bolinha visivel",
    Callback = function()
        pcall(function()
            bubbleGui.Parent = playerGui
        end)
        bubbleGui.Enabled = true
        bubble.Visible = true
        bubble.Size = UDim2.fromOffset(58, 58)
    end,
})

local InfoTab = Window:CreateTab("Info", 4483362458)

InfoTab:CreateButton({
    Name = "Diagnostico do mapa",
    Callback = function()
        print("=== BLOX HUB DIAGNOSTICO ===")
        print("versao:", SCRIPT_VERSION)
        print("personagem:", LocalPlayer.Character and "sim" or "nao")
        print("ferramenta:", currentTool() and currentTool().Name or "nenhuma")

        local children = Workspace:GetChildren()
        print("workspace filhos:", #children)
        local names = {}
        for _, child in ipairs(children) do
            if child:IsA("Folder") then
                names[#names + 1] = child.Name .. "(" .. #child:GetChildren() .. ")"
            end
        end
        print("pastas:", table.concat(names, ", "))

        local enemies = collectEnemies()
        print("inimigos vivos:", #enemies)
        local counted = {}
        for _, enemy in ipairs(enemies) do
            counted[enemy.model.Name] = (counted[enemy.model.Name] or 0) + 1
        end
        for name, count in pairs(counted) do
            print("   ", name, "x" .. count)
        end

        local fruits = collectFruits()
        print("frutas:", #fruits)
        for _, fruit in ipairs(fruits) do
            print("   ", fruit.model.Name, fruit.model.ClassName)
        end

        local chests = collectChests()
        print("baus:", #chests)
        for _, chest in ipairs(chests) do
            print("   ", chest.model:GetFullName())
        end
    end,
})

InfoTab:CreateButton({
    Name = "Listar nomes de mobs (para escolher)",
    Callback = function()
        local enemies = collectEnemies()
        local counted = {}
        for _, enemy in ipairs(enemies) do
            counted[enemy.model.Name] = (counted[enemy.model.Name] or 0) + 1
        end
        local list = {}
        for name, count in pairs(counted) do
            list[#list + 1] = name .. " x" .. count
        end
        table.sort(list)
        print("=== MOBS ===")
        for _, line in ipairs(list) do
            print(line)
        end
        print("total:", #enemies)
    end,
})

InfoTab:CreateButton({
    Name = "Perfil recomendado",
    Callback = function()
        state.speed = 18
        state.jump = 50
        state.flySpeed = 150
        state.maxFlyHeight = 300
        state.farmRange = 1000
        state.attackDelay = 0.05
        state.jumpFly = true
        state.espFruit = true
        state.espChest = true
        pcall(function()
            speedSlider:Set(18)
            jumpSlider:Set(50)
            flySlider:Set(150)
            rangeSlider:Set(1000)
            delaySlider:Set(0.05)
            jumpFlyToggle:Set(true)
        end)
        applyMovement()
        markDirty()
        Rayfield:Notify({Title = "Perfil",
                         Content = "Voo 150, farm 1000, ataque 0.05s.", Duration = 5})
    end,
})

-- ===== loops =====
session.connections[#session.connections + 1] = RunService.Heartbeat:Connect(function(dt)
    updateFly(dt)
end)

LocalPlayer.CharacterAdded:Connect(function()
    destroyRig()
    task.wait(1)
    applyMovement()
    refreshEsp()
end)

task.spawn(function()
    while _G.__bloxHub == session do
        task.wait(0.5)
        refreshEsp()
        applyMovement()
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
        task.wait(0.5)
        if flyRig.holdTimer > 0.45 then
            status("voo manual")
        elseif state.autoFarm then
            farmCycle()
        elseif state.autoFruit then
            fruitCycle()
        elseif state.autoChest then
            chestCycle()
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
    task.wait(3)
    local remote = fetchRemoteVersion()
    if remote and remote > SCRIPT_VERSION then
        Rayfield:Notify({Title = "Atualizacao disponivel",
                         Content = "v" .. remote .. ". Aba Farm > Verificar.", Duration = 8})
    end
end)

applyMovement()
refreshEsp()
print("blox hub v" .. SCRIPT_VERSION .. " carregado")
