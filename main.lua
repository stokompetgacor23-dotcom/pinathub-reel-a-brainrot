-- =======================================================
-- PINATHUB - REEL A BRAINROT (WINDUI v2)
-- Complete Fishing Automation | Mobile/Desktop Friendly
-- TikTok: @viunze
-- =======================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local Player = Players.LocalPlayer
local UIS = UserInputService

-- =======================================================
-- ANTI AFK
-- =======================================================
Player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- =======================================================
-- BRAINROT GLOBALS & REMOTES
-- =======================================================
local GLOBAL_ENV = (getgenv and getgenv()) or _G
if GLOBAL_ENV.__RAB_STOP then
    pcall(GLOBAL_ENV.__RAB_STOP)
end
local RUN_TOKEN = tostring(os.clock())
GLOBAL_ENV.__RAB_TOKEN = RUN_TOKEN
local function isRunActive()
    return GLOBAL_ENV.__RAB_TOKEN == RUN_TOKEN
end

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local oldGui = PlayerGui:FindFirstChild("ReelABrainrotMenu")
if oldGui then
    oldGui:Destroy()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteHandler = ReplicatedStorage:WaitForChild("RemoteHandler")
local FishingEvent = RemoteHandler:WaitForChild("Fishing")
local SellEvent = RemoteHandler:WaitForChild("SellMultiple")
local PlotEvent = RemoteHandler:WaitForChild("Plot")
local RebirthEvent = RemoteHandler:WaitForChild("Rebirth")
local UpgradeEvent = RemoteHandler:WaitForChild("Upgrade")
local BrainrotEvent = RemoteHandler:WaitForChild("Brainrot")
local CollectEvent = RemoteHandler:WaitForChild("Collect")
local FishingRodEvent = RemoteHandler:WaitForChild("FishingRod")
local RodMutationEvent = RemoteHandler:WaitForChild("RodMutation")

local function fireServer(remote, ...)
    local args = { ... }
    pcall(function()
        remote:FireServer(table.unpack(args))
    end)
end

-- Plot instance names
local PLOT_IDS = {}
for i = 1, 30 do
    PLOT_IDS[i] = "Plot" .. i
end

-- Rarities used by SellMultiple
local RARITY_ORDER = {
    "Uncommon",
    "Rare",
    "Epic",
    "Legendary",
    "Mythic",
    "Godly",
    "Secret",
    "Divine",
}

local state = {
    fishOn = false,
    plotOn = false,
    rebirthAuto = false,
    autoUpgradeOn = false,
    autoBuyRodOn = false,
    autoRodMutationOn = false,
    collectOn = false,
    collectInterval = 0.08,
    collectPerPlotDelay = 0.005,
    collectBurst = 1,
    collectRequireCash = false,
    collectReactive = false,
    collectOnlyMyBasePlots = true,
}

local FISH_INTERVAL = 0.1
local FISH_VALUE = 9999999
local EQUIP_WAIT = 3
local SELL_WAIT = 13
local REBIRTH_INTERVAL = 8
local AUTO_UPGRADE_INTERVAL = 0.35
local AUTO_BUY_ROD_INTERVAL = 0.45
local AUTO_ROD_MUTATION_INTERVAL = 0.45

-- Upgrade Info
local UPGRADE_INFO = {
    MaxPowerLevel = 295,
    MaxCarryLevel = 9,
    PowerBaseCost = 500,
    PowerCostGrowth = 1.17,
    CarryBaseCost = 10000000,
    CarryCostGrowth = {
        1,
        50,
        2000,
        1000000,
        20000000,
        500000000,
        20000000000,
        500000000000,
        20000000000000,
    },
}

local function playerCash()
    local v = LocalPlayer:GetAttribute("Cash")
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" then
        return tonumber(v) or 0
    end
    return 0
end

local function compactNumber(n)
    if type(n) ~= "number" then
        return tostring(n)
    end
    local abs = math.abs(n)
    if abs >= 1e15 then
        return string.format("%.2fQa", n / 1e15)
    elseif abs >= 1e12 then
        return string.format("%.2fT", n / 1e12)
    elseif abs >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif abs >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif abs >= 1e3 then
        return string.format("%.2fK", n / 1e3)
    end
    return tostring(math.floor(n))
end

local function getPowerPackCost(requestLevels)
    local pl = tonumber(LocalPlayer:GetAttribute("PowerLevel")) or 0
    if pl >= UPGRADE_INFO.MaxPowerLevel then
        return nil
    end
    local buy = math.min(requestLevels, UPGRADE_INFO.MaxPowerLevel - pl)
    if buy <= 0 then
        return nil
    end
    local v4 = UPGRADE_INFO.PowerBaseCost
    local v6 = UPGRADE_INFO.PowerCostGrowth
    local v1 = pl + 1
    local v3 = buy
    return math.ceil(v4 * v6 ^ (v1 - 1) * (v6 ^ v3 - 1) / (v6 - 1))
end

local function getCarryNextCost()
    local cl = tonumber(LocalPlayer:GetAttribute("CarryLevel")) or 0
    if cl >= UPGRADE_INFO.MaxCarryLevel then
        return nil
    end
    local v1 = cl + 1
    local mult = UPGRADE_INFO.CarryCostGrowth[v1]
    if not mult then
        return nil
    end
    return math.ceil(mult * UPGRADE_INFO.CarryBaseCost)
end

local function fireSmartUpgradeOnce()
    local cash = playerCash()
    local order = {
        { "power10", getPowerPackCost(10) },
        { "power5", getPowerPackCost(5) },
        { "power1", getPowerPackCost(1) },
        { "carry1", getCarryNextCost() },
    }
    for _, row in ipairs(order) do
        local pack, cost = row[1], row[2]
        if cost and cash >= cost then
            fireServer(UpgradeEvent, pack)
            return
        end
    end
end

local BUYABLE_RODS = {
    { key = "FishingRod2", index = 2, cost = 50000 },
    { key = "FishingRod3", index = 3, cost = 250000 },
    { key = "FishingRod4", index = 4, cost = 1000000 },
    { key = "FishingRod6", index = 6, cost = 5000000 },
    { key = "FishingRod7", index = 7, cost = 25000000 },
    { key = "FishingRod8", index = 8, cost = 100000000 },
    { key = "FishingRod9", index = 9, cost = 250000000 },
    { key = "FishingRod10", index = 10, cost = 750000000 },
    { key = "FishingRod11", index = 11, cost = 2000000000 },
    { key = "FishingRod12", index = 12, cost = 10000000000 },
    { key = "FishingRod13", index = 13, cost = 50000000000 },
    { key = "FishingRod14", index = 14, cost = 250000000000 },
    { key = "FishingRod15", index = 15, cost = 1000000000000 },
    { key = "FishingRod16", index = 16, cost = 10000000000000 },
    { key = "FishingRod17", index = 17, cost = 100000000000000 },
    { key = "FishingRod18", index = 18, cost = 1000000000000000 },
}

local function getRodIndexByKey(key)
    for _, r in ipairs(BUYABLE_RODS) do
        if r.key == key then
            return r.index
        end
    end
    if key == "FishingRod1" then
        return 1
    end
    return nil
end

local function isRodUnlocked(index)
    local bits = tonumber(LocalPlayer:GetAttribute("FishingRodsUnlocked")) or 0
    return math.floor(bits / (2 ^ (index - 1))) % 2 == 1
end

local function getHighestOwnedRodIndex()
    local best = 1
    for _, r in ipairs(BUYABLE_RODS) do
        if isRodUnlocked(r.index) and r.index > best then
            best = r.index
        end
    end
    local current = getRodIndexByKey(tostring(LocalPlayer:GetAttribute("FishingRod") or ""))
    if current and current > best then
        best = current
    end
    return best
end

local function getNextBuyableRod()
    local currentIdx = getHighestOwnedRodIndex()
    for _, r in ipairs(BUYABLE_RODS) do
        if r.index > currentIdx then
            return r
        end
    end
    return nil
end

local function autoBuyNextRodOnce()
    local nextRod = getNextBuyableRod()
    if not nextRod then
        return
    end
    local cash = playerCash()
    if cash < nextRod.cost then
        return
    end
    fireServer(FishingRodEvent, "Buy", nextRod.key)
    task.wait(0.08)
    fireServer(FishingRodEvent, "Equip", nextRod.key)
end

local ROD_MUTATIONS = {
    { key = "RodMutation1", index = 1, cost = 10000000, rebirths = 1 },
    { key = "RodMutation2", index = 2, cost = 250000000, rebirths = 2 },
    { key = "RodMutation3", index = 3, cost = 10000000000, rebirths = 3 },
    { key = "RodMutation4", index = 4, cost = 100000000000, rebirths = 4 },
    { key = "RodMutation5", index = 5, cost = 5000000000000, rebirths = 5 },
    { key = "RodMutation6", index = 6, cost = 500000000000000, rebirths = 8 },
    { key = "RodMutation7", index = 7, cost = 5000000000000000, rebirths = 10 },
}

local function getMutationIndexByKey(key)
    for _, m in ipairs(ROD_MUTATIONS) do
        if m.key == key then
            return m.index
        end
    end
    return nil
end

local function isMutationUnlocked(index)
    local bits = tonumber(LocalPlayer:GetAttribute("RodMutationsUnlocked")) or 0
    return math.floor(bits / (2 ^ (index - 1))) % 2 == 1
end

local function getBestUnlockedMutation()
    local best = nil
    for _, m in ipairs(ROD_MUTATIONS) do
        if isMutationUnlocked(m.index) then
            best = m
        end
    end
    return best
end

local function getNextBuyableMutation()
    local best = getBestUnlockedMutation()
    local currentIdx = best and best.index or 0
    for _, m in ipairs(ROD_MUTATIONS) do
        if m.index > currentIdx then
            return m
        end
    end
    return nil
end

local function autoRodMutationStep()
    local cash = playerCash()
    local rebirths = tonumber(LocalPlayer:GetAttribute("Rebirths")) or 0

    local nextMutation = getNextBuyableMutation()
    if nextMutation and rebirths >= nextMutation.rebirths and cash >= nextMutation.cost then
        fireServer(RodMutationEvent, "Buy", nextMutation.key)
    end

    local bestUnlocked = getBestUnlockedMutation()
    if bestUnlocked then
        local current = tostring(LocalPlayer:GetAttribute("RodMutation") or "")
        if current ~= bestUnlocked.key then
            fireServer(RodMutationEvent, "Equip", bestUnlocked.key)
        end
    end
end

local sellFlags = {}
for _, r in ipairs(RARITY_ORDER) do
    sellFlags[r] = true
end

local fishThread = nil
local plotThread = nil
local rebirthThread = nil
local autoUpgradeThread = nil
local autoBuyRodThread = nil
local autoRodMutationThread = nil
local collectThread = nil
local collectReactiveConns = {}
local collectDebounce = {}
local collectStatusLabel = nil
local baseObjectsListenerConns = {}
local runtimeConnections = {}

local function connectTracked(signal, handler)
    local conn = signal:Connect(handler)
    table.insert(runtimeConnections, conn)
    return conn
end

local function disconnectTrackedConnections()
    for _, c in ipairs(runtimeConnections) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(runtimeConnections)
end

local function discoverPlotsInMyBase()
    local baseName = LocalPlayer:GetAttribute("Base")
    if not baseName or type(baseName) ~= "string" or baseName == "" then
        return nil, "Base attribute not set yet"
    end
    local bases = workspace:FindFirstChild("Bases")
    if not bases then
        return nil, "workspace.Bases not found"
    end
    local baseFolder = bases:FindFirstChild(baseName)
    if not baseFolder then
        return nil, "Bases." .. baseName .. " not found"
    end
    local objects = baseFolder:FindFirstChild("Objects")
    if not objects then
        return nil, "Objects folder missing"
    end
    local ids = {}
    for _, child in ipairs(objects:GetChildren()) do
        if child:GetAttribute("type") == "Plot" then
            table.insert(ids, child.Name)
        end
    end
    table.sort(ids)
    return ids, nil
end

local function getPlotIdsList()
    if not state.collectOnlyMyBasePlots then
        return PLOT_IDS
    end
    local ids, err = discoverPlotsInMyBase()
    if ids == nil then
        return {}
    end
    return ids
end

local function updateCollectStatusText()
    if not collectStatusLabel then
        return
    end
    if not state.collectOnlyMyBasePlots then
        collectStatusLabel.Text = "Scope: all Plot1…Plot30 (not limited to your base)"
        collectStatusLabel.TextColor3 = Color3.fromRGB(200, 180, 120)
        return
    end
    local baseName = LocalPlayer:GetAttribute("Base")
    local ids, err = discoverPlotsInMyBase()
    if ids == nil then
        collectStatusLabel.Text = "My base: " .. tostring(baseName) .. " — " .. (err or "?")
        collectStatusLabel.TextColor3 = Color3.fromRGB(255, 160, 120)
        return
    end
    local preview = table.concat(ids, ", ")
    if #preview > 120 then
        preview = preview:sub(1, 117) .. "…"
    end
    collectStatusLabel.Text = string.format(
        "My base: %s — %d plot(s)%s",
        tostring(baseName),
        #ids,
        #ids > 0 and (" — " .. preview) or " (empty Objects?)"
    )
    collectStatusLabel.TextColor3 = Color3.fromRGB(140, 200, 160)
end

local function plotCash(plotId)
    local v = LocalPlayer:GetAttribute(plotId .. "Cash")
    if type(v) == "number" then
        return v
    end
    if type(v) == "string" then
        return tonumber(v) or 0
    end
    return 0
end

local function tryCollectPlot(plotId, minInterval)
    if state.collectRequireCash and plotCash(plotId) <= 0 then
        return
    end
    local now = tick()
    local last = collectDebounce[plotId] or 0
    local gap = minInterval or 0.1
    if now - last < gap then
        return
    end
    collectDebounce[plotId] = now
    fireServer(CollectEvent, plotId)
end

local function disconnectReactiveCollect()
    for _, c in ipairs(collectReactiveConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(collectReactiveConns)
end

local function refreshCollectReactive()
    disconnectReactiveCollect()
    if state.collectOn and state.collectReactive then
        for _, plotId in ipairs(getPlotIdsList()) do
            local attr = plotId .. "Cash"
            local conn = LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
                if not state.collectOn or not state.collectReactive then
                    return
                end
                if state.collectRequireCash and plotCash(plotId) <= 0 then
                    return
                end
                tryCollectPlot(plotId, 0.12)
            end)
            table.insert(collectReactiveConns, conn)
        end
    end
end

local function disconnectBaseObjectsListener()
    for _, c in ipairs(baseObjectsListenerConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    table.clear(baseObjectsListenerConns)
end

local function connectBaseObjectsListener()
    disconnectBaseObjectsListener()
    if not state.collectOnlyMyBasePlots then
        return
    end
    local baseName = LocalPlayer:GetAttribute("Base")
    if not baseName or type(baseName) ~= "string" then
        return
    end
    local objects = workspace:FindFirstChild("Bases")
        and workspace.Bases:FindFirstChild(baseName)
        and workspace.Bases[baseName]:FindFirstChild("Objects")
    if not objects then
        return
    end
    local function bump()
        task.defer(function()
            updateCollectStatusText()
            if state.collectOn then
                refreshCollectReactive()
            end
        end)
    end
    table.insert(baseObjectsListenerConns, objects.ChildAdded:Connect(bump))
    table.insert(baseObjectsListenerConns, objects.ChildRemoved:Connect(bump))
end

local function stopCollectLoop()
    state.collectOn = false
    disconnectReactiveCollect()
    disconnectBaseObjectsListener()
end

local function startCollectLoop()
    if collectThread then
        return
    end
    state.collectOn = true
    updateCollectStatusText()
    connectBaseObjectsListener()
    refreshCollectReactive()
    collectThread = task.spawn(function()
        while state.collectOn and isRunActive() do
            for _, plotId in ipairs(getPlotIdsList()) do
                if not state.collectOn then
                    break
                end
                local allowed = (not state.collectRequireCash) or plotCash(plotId) > 0
                if allowed then
                    local burst = math.max(1, math.floor(tonumber(state.collectBurst) or 1))
                    for _ = 1, burst do
                        if not state.collectOn then
                            break
                        end
                        fireServer(CollectEvent, plotId)
                        collectDebounce[plotId] = tick()
                        if state.collectPerPlotDelay > 0 then
                            task.wait(state.collectPerPlotDelay)
                        end
                    end
                end
            end
            task.wait(math.max(0, state.collectInterval))
        end
        collectThread = nil
    end)
end

local function doRebirth()
    fireServer(RebirthEvent)
end

local function stopRebirthLoop()
    state.rebirthAuto = false
end

local function startRebirthLoop()
    if rebirthThread then
        return
    end
    state.rebirthAuto = true
    rebirthThread = task.spawn(function()
        while state.rebirthAuto and isRunActive() do
            doRebirth()
            task.wait(REBIRTH_INTERVAL)
        end
        rebirthThread = nil
    end)
end

local function stopAutoUpgradeLoop()
    state.autoUpgradeOn = false
end

local function startAutoUpgradeLoop()
    if autoUpgradeThread then
        return
    end
    state.autoUpgradeOn = true
    autoUpgradeThread = task.spawn(function()
        while state.autoUpgradeOn and isRunActive() do
            fireSmartUpgradeOnce()
            task.wait(AUTO_UPGRADE_INTERVAL)
        end
        autoUpgradeThread = nil
    end)
end

local function stopAutoBuyRodLoop()
    state.autoBuyRodOn = false
end

local function startAutoBuyRodLoop()
    if autoBuyRodThread then
        return
    end
    state.autoBuyRodOn = true
    autoBuyRodThread = task.spawn(function()
        while state.autoBuyRodOn and isRunActive() do
            autoBuyNextRodOnce()
            task.wait(AUTO_BUY_ROD_INTERVAL)
        end
        autoBuyRodThread = nil
    end)
end

local function stopAutoRodMutationLoop()
    state.autoRodMutationOn = false
end

local function startAutoRodMutationLoop()
    if autoRodMutationThread then
        return
    end
    state.autoRodMutationOn = true
    autoRodMutationThread = task.spawn(function()
        while state.autoRodMutationOn and isRunActive() do
            autoRodMutationStep()
            task.wait(AUTO_ROD_MUTATION_INTERVAL)
        end
        autoRodMutationThread = nil
    end)
end

local function buildSellTable()
    local t = {}
    for _, r in ipairs(RARITY_ORDER) do
        t[r] = sellFlags[r] == true
    end
    return t
end

local function stopFishLoop()
    state.fishOn = false
    fishThread = nil
end

local function startFishLoop()
    if fishThread then
        return
    end
    state.fishOn = true
    fishThread = task.spawn(function()
        while state.fishOn and isRunActive() do
            fireServer(FishingEvent, "Caught", FISH_VALUE)
            task.wait(FISH_INTERVAL)
        end
        fishThread = nil
    end)
end

local function stopPlotLoop()
    state.plotOn = false
    plotThread = nil
end

local function startPlotLoop()
    if plotThread then
        return
    end
    state.plotOn = true
    plotThread = task.spawn(function()
        while state.plotOn and isRunActive() do
            fireServer(PlotEvent, "EquipBest", "String", "String")
            task.wait(EQUIP_WAIT)
            if not state.plotOn then
                break
            end
            fireServer(SellEvent, buildSellTable())
            task.wait(SELL_WAIT)
        end
        plotThread = nil
    end)
end

-- =======================================================
-- NOTIFICATION SYSTEM
-- =======================================================
local notifHolder = Instance.new("ScreenGui")
notifHolder.Name = "PinatHubNotifications"
notifHolder.ResetOnSpawn = false
notifHolder.Parent = Player:WaitForChild("PlayerGui")

local notifFrame = Instance.new("Frame")
notifFrame.Name = "NotificationHolder"
notifFrame.Size = UDim2.new(0, 350, 1, -20)
notifFrame.Position = UDim2.new(1, -370, 0, 10)
notifFrame.BackgroundTransparency = 1
notifFrame.Parent = notifHolder

local notifList = Instance.new("UIListLayout")
notifList.Name = "NotifList"
notifList.Padding = UDim.new(0, 8)
notifList.HorizontalAlignment = Enum.HorizontalAlignment.Right
notifList.VerticalAlignment = Enum.VerticalAlignment.Top
notifList.SortOrder = Enum.SortOrder.LayoutOrder
notifList.Parent = notifFrame

local function ShowNotification(title, message, duration)
    duration = duration or 3
    
    local notif = Instance.new("Frame")
    notif.Name = "Notification"
    notif.Size = UDim2.new(0, 330, 0, 70)
    notif.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    notif.BackgroundTransparency = 1
    notif.BorderSizePixel = 0
    notif.ClipsDescendants = true
    notif.Parent = notifFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = notif
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(80, 80, 90)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = notif
    
    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
    accent.BorderSizePixel = 0
    accent.Parent = notif
    
    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(0, 4)
    accentCorner.Parent = accent
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -20, 0, 20)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.Parent = notif
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Name = "Message"
    messageLabel.Size = UDim2.new(1, -20, 0, 18)
    messageLabel.Position = UDim2.new(0, 14, 0, 32)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextSize = 14
    messageLabel.Parent = notif
    
    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -20, 0, 3)
    progressBg.Position = UDim2.new(0, 10, 1, -8)
    progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = notif
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(1, 0)
    progressCorner.Parent = progressBg
    
    local progress = Instance.new("Frame")
    progress.Name = "Progress"
    progress.Size = UDim2.new(1, 0, 1, 0)
    progress.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
    progress.BorderSizePixel = 0
    progress.Parent = progressBg
    
    local progressCorner2 = Instance.new("UICorner")
    progressCorner2.CornerRadius = UDim.new(1, 0)
    progressCorner2.Parent = progress
    
    notif.Position = UDim2.new(1, 50, 0, 0)
    
    local fadeIn = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -340, 0, 0),
        BackgroundTransparency = 0
    })
    
    local fadeOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(1, 50, 0, 0),
        BackgroundTransparency = 1
    })
    
    local progressTween = TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 1, 0)
    })
    
    fadeIn:Play()
    progressTween:Play()
    
    task.delay(duration, function()
        if notif and notif.Parent then
            fadeOut:Play()
            task.wait(0.3)
            pcall(function() notif:Destroy() end)
        end
    end)
    
    return notif
end

-- =======================================================
-- LOGO LAUNCHER
-- =======================================================
local logoGui = Instance.new("ScreenGui")
logoGui.Name = "PinatHubLogo"
logoGui.ResetOnSpawn = false
logoGui.Parent = Player:WaitForChild("PlayerGui", 5)

local logoButton = Instance.new("ImageButton")
logoButton.Name = "LogoButton"
logoButton.Size = UDim2.new(0, 50, 0, 50)
logoButton.Position = UDim2.new(0.5, -25, 0.5, -25)
logoButton.BackgroundTransparency = 1
logoButton.Image = "rbxassetid://118264723961739"
logoButton.ImageColor3 = Color3.fromRGB(180, 0, 255)
logoButton.ScaleType = Enum.ScaleType.Fit
logoButton.Parent = logoGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(1, 0)
uiCorner.Parent = logoButton

local hoverTween = TweenService:Create(logoButton, TweenInfo.new(0.2), {Size = UDim2.new(0, 60, 0, 60)})
local unhoverTween = TweenService:Create(logoButton, TweenInfo.new(0.2), {Size = UDim2.new(0, 50, 0, 50)})

logoButton.MouseEnter:Connect(function() hoverTween:Play() end)
logoButton.MouseLeave:Connect(function() unhoverTween:Play() end)

local dragging = false
local dragInput, dragStart, startPos

logoButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = logoButton.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

logoButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        logoButton.Position = newPos
    end
end)

-- =======================================================
-- LOAD WINDUI v2
-- =======================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "PinatHub",
    Author = "@viunze on tiktok",
    Folder = "pinathub",
    Size = UDim2.fromOffset(500, 350),
    Transparent = true,
    Theme = "Dark",
    IsOpenButtonEnabled = false,
    UserEnabled = true,
    HasOutline = true,
    SideBarWidth = 150,
})

Window:Tag({ Title = "@viunze on tiktok", Icon = "star", Color = Color3.fromHex("#BA00FF"), Border = true })

local guiVisible = true
logoButton.MouseButton1Click:Connect(function()
    guiVisible = not guiVisible
    if Window then
        pcall(function()
            if guiVisible then
                Window:Open()
            else
                Window:Minimize()
            end
        end)
    end
end)

-- =======================================================
-- CREATE TABS
-- =======================================================
local FishingTab = Window:Tab({ Title = "Fishing", Icon = "fish" })
local FarmingTab = Window:Tab({ Title = "Farming", Icon = "chart-line" })
local UpgradesTab = Window:Tab({ Title = "Upgrades", Icon = "arrow-up" })
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })
local CommunityTab = Window:Tab({ Title = "Community", Icon = "users" })

-- =======================================================
-- FISHING TAB
-- =======================================================
local AutoFishSection = FishingTab:Section({ Title = "Auto Fishing" })

AutoFishSection:Toggle({
    Title = "Auto Spam Caught",
    Desc = "Automatically catches fish with max value",
    Value = false,
    Callback = function(value)
        if value then
            startFishLoop()
            ShowNotification("Auto Fishing", "Enabled - Catching fish...", 2)
        else
            stopFishLoop()
            ShowNotification("Auto Fishing", "Disabled", 2)
        end
    end
})

FishingTab:Space()

local RodSection = FishingTab:Section({ Title = "Fishing Rod Automation" })

RodSection:Toggle({
    Title = "Auto Buy Fishing Rod",
    Desc = "Automatically buys the next best rod when affordable",
    Value = false,
    Callback = function(value)
        if value then
            startAutoBuyRodLoop()
            ShowNotification("Auto Rod", "Enabled - Buying best rod", 2)
        else
            stopAutoBuyRodLoop()
            ShowNotification("Auto Rod", "Disabled", 2)
        end
    end
})

RodSection:Toggle({
    Title = "Auto Rod Mutation",
    Desc = "Automatically buys and equips rod mutations",
    Value = false,
    Callback = function(value)
        if value then
            startAutoRodMutationLoop()
            ShowNotification("Auto Mutation", "Enabled", 2)
        else
            stopAutoRodMutationLoop()
            ShowNotification("Auto Mutation", "Disabled", 2)
        end
    end
})

-- =======================================================
-- FARMING TAB
-- =======================================================
local SellSection = FarmingTab:Section({ Title = "Plot & Sell" })

SellSection:Toggle({
    Title = "Equip Best + Sell Loop",
    Desc = "Equips best plot and sells fish",
    Value = false,
    Callback = function(value)
        if value then
            startPlotLoop()
            ShowNotification("Auto Sell", "Enabled", 2)
        else
            stopPlotLoop()
            ShowNotification("Auto Sell", "Disabled", 2)
        end
    end
})

FarmingTab:Space()

local CollectSection = FarmingTab:Section({ Title = "Auto Collect" })

CollectSection:Toggle({
    Title = "Auto Collect Plots",
    Desc = "Automatically collects cash from plots",
    Value = false,
    Callback = function(value)
        if value then
            startCollectLoop()
            ShowNotification("Auto Collect", "Enabled", 2)
        else
            stopCollectLoop()
            ShowNotification("Auto Collect", "Disabled", 2)
        end
    end
})

-- =======================================================
-- UPGRADES TAB
-- =======================================================
local RebirthSection = UpgradesTab:Section({ Title = "Rebirth" })

RebirthSection:Toggle({
    Title = "Auto Rebirth",
    Desc = "Automatically performs rebirth when available",
    Value = false,
    Callback = function(value)
        if value then
            startRebirthLoop()
            ShowNotification("Auto Rebirth", "Enabled", 2)
        else
            stopRebirthLoop()
            ShowNotification("Auto Rebirth", "Disabled", 2)
        end
    end
})

UpgradesTab:Space()

local PowerSection = UpgradesTab:Section({ Title = "Power & Carry Upgrades" })

PowerSection:Toggle({
    Title = "Auto Upgrades",
    Desc = "Automatically buys power and carry upgrades",
    Value = false,
    Callback = function(value)
        if value then
            startAutoUpgradeLoop()
            ShowNotification("Auto Upgrades", "Enabled", 2)
        else
            stopAutoUpgradeLoop()
            ShowNotification("Auto Upgrades", "Disabled", 2)
        end
    end
})

-- =======================================================
-- SETTINGS TAB
-- =======================================================
local CollectSettings = SettingsTab:Section({ Title = "Collect Settings" })

CollectSettings:Slider({
    Title = "Collect Interval",
    Desc = "Time between full collect sweeps (seconds)",
    Value = { Min = 0.02, Max = 1, Default = 0.08 },
    Rounding = 2,
    Callback = function(value)
        state.collectInterval = value
    end,
})

CollectSettings:Slider({
    Title = "Per Plot Delay",
    Desc = "Delay between each plot collect (seconds)",
    Value = { Min = 0.001, Max = 0.1, Default = 0.005 },
    Rounding = 3,
    Callback = function(value)
        state.collectPerPlotDelay = value
    end,
})

CollectSettings:Slider({
    Title = "Collect Burst",
    Desc = "Number of collects per plot before moving",
    Value = { Min = 1, Max = 10, Default = 1 },
    Rounding = 0,
    Callback = function(value)
        state.collectBurst = value
    end,
})

CollectSettings:Toggle({
    Title = "Require Cash to Collect",
    Desc = "Only collect plots that have cash available",
    Value = false,
    Callback = function(value)
        state.collectRequireCash = value
    end,
})

CollectSettings:Toggle({
    Title = "Reactive Collection",
    Desc = "Collect instantly when cash increases",
    Value = false,
    Callback = function(value)
        state.collectReactive = value
        if state.collectOn then
            refreshCollectReactive()
        end
    end,
})

CollectSettings:Toggle({
    Title = "Only My Base Plots",
    Desc = "Only collect plots from your own base",
    Value = true,
    Callback = function(value)
        state.collectOnlyMyBasePlots = value
        if state.collectOn then
            connectBaseObjectsListener()
            refreshCollectReactive()
        end
        updateCollectStatusText()
    end,
})

SettingsTab:Space()

local SellRaritySection = SettingsTab:Section({ Title = "Sell Rarity Filter" })

-- Create rarity toggle grid
local rarityGrid = Instance.new("Frame")
rarityGrid.Size = UDim2.new(1, 0, 0, 0)
rarityGrid.BackgroundTransparency = 1
rarityGrid.AutomaticSize = Enum.AutomaticSize.Y
rarityGrid.Parent = SellRaritySection.Container

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 100, 0, 30)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 6)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = 2
gridLayout.Parent = rarityGrid

for _, r in ipairs(RARITY_ORDER) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0)
    b.BackgroundColor3 = sellFlags[r] and Color3.fromRGB(0, 110, 70) or Color3.fromRGB(45, 48, 58)
    b.Text = r
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.AutoButtonColor = false
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    b.MouseButton1Click:Connect(function()
        sellFlags[r] = not sellFlags[r]
        b.BackgroundColor3 = sellFlags[r] and Color3.fromRGB(0, 110, 70) or Color3.fromRGB(45, 48, 58)
        ShowNotification("Rarity Filter", r .. ": " .. (sellFlags[r] and "ON" or "OFF"), 1)
    end)
    b.Parent = rarityGrid
end

-- =======================================================
-- COMMUNITY TAB
-- =======================================================
local WhatsAppSection = CommunityTab:Section({ Title = "WhatsApp Group" })

WhatsAppSection:Button({
    Title = "Join WhatsApp Group",
    Desc = "Click to copy WhatsApp group link",
    Callback = function()
        if setclipboard then
            setclipboard("https://chat.whatsapp.com/I8hG44FLgrRAwQcS3lvEft")
            ShowNotification("Success", "WhatsApp link copied to clipboard!", 3)
        else
            ShowNotification("Error", "Clipboard not supported!", 2)
        end
    end
})

CommunityTab:Space()

local DiscordSection = CommunityTab:Section({ Title = "Discord Server" })

DiscordSection:Button({
    Title = "Join Discord Server",
    Desc = "Click to copy Discord server link",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/eDbaHKEf7G")
            ShowNotification("Success", "Discord link copied to clipboard!", 3)
        else
            ShowNotification("Error", "Clipboard not supported!", 2)
        end
    end
})

CommunityTab:Space()

local TikTokSection = CommunityTab:Section({ Title = "TikTok" })

TikTokSection:Button({
    Title = "Follow @viunze",
    Desc = "Click to copy TikTok username",
    Callback = function()
        if setclipboard then
            setclipboard("@viunze")
            ShowNotification("Success", "TikTok username copied: @viunze", 3)
        else
            ShowNotification("Error", "Clipboard not supported!", 2)
        end
    end
})

CommunityTab:Space()

local CreditSection = CommunityTab:Section({ Title = "Credits" })

CreditSection:Paragraph({
    Title = "PinatHub",
    Desc = "Reel a Brainrot Automation Script\nVersion 2.0\nCreated by @viunze"
})

-- =======================================================
-- STATUS UPDATE LOOP
-- =======================================================
local function refreshBottomStatus()
    local currentRod = tostring(LocalPlayer:GetAttribute("FishingRod") or "FishingRod1")
    local nextRod = getNextBuyableRod()
    local nextRodText = "MAX"
    local nextCostText = "-"
    if nextRod then
        nextRodText = nextRod.key
        nextCostText = "$" .. compactNumber(nextRod.cost)
    end
    local cashText = "$" .. compactNumber(playerCash())
    
    -- Update window title with status
    pcall(function()
        Window:SetTitle("PinatHub | Cash: " .. cashText .. " | Rod: " .. currentRod)
    end)
end

task.spawn(function()
    while isRunActive() do
        refreshBottomStatus()
        task.wait(0.4)
    end
end)

-- Attribute listeners
for _, attr in ipairs({ "Cash", "FishingRod", "PowerLevel", "CarryLevel", "FishingRodsUnlocked", "Base" }) do
    connectTracked(LocalPlayer:GetAttributeChangedSignal(attr), function()
        if isRunActive() then
            task.defer(refreshBottomStatus)
        end
    end)
end

connectTracked(LocalPlayer:GetAttributeChangedSignal("Base"), function()
    task.defer(updateCollectStatusText)
    if state.collectOn then
        connectBaseObjectsListener()
        refreshCollectReactive()
    end
end)

-- =======================================================
-- CLEANUP FUNCTION
-- =======================================================
GLOBAL_ENV.__RAB_STOP = function()
    state.fishOn = false
    state.plotOn = false
    state.collectOn = false
    state.rebirthAuto = false
    state.autoUpgradeOn = false
    state.autoBuyRodOn = false
    state.autoRodMutationOn = false
    disconnectReactiveCollect()
    disconnectBaseObjectsListener()
    disconnectTrackedConnections()
    if logoGui and logoGui.Parent then
        logoGui:Destroy()
    end
    if notifHolder and notifHolder.Parent then
        notifHolder:Destroy()
    end
    if Window then
        pcall(function() Window:Destroy() end)
    end
end

-- =======================================================
-- INITIAL NOTIFICATION
-- =======================================================
task.wait(1)
ShowNotification("PinatHub", "Loaded", 5)

print("PinatHub Loaded")
