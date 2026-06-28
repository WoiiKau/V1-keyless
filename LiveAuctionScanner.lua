--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  STORAGE HUNTERS — HORIZONTAL MOBILE AUCTION SCANNER (DELTA FIX)     ║
    ║  Real-time scanner · Auto-Bid (FULLY RESTORED & OPTIMIZED)           ║
    ║  PERFECT AUTO-SCALING, TOUCH FIXES, AND REAL ITEM NAMES INCLUDED     ║
    ╚══════════════════════════════════════════════════════════════════════╝
--]]

if not game:IsLoaded() then game.Loaded:Wait() end

-- ═════════════════════════════════════════════════════
-- SERVICES
-- ═════════════════════════════════════════════════════
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- DELTA MOBILE BYPASS: Safely get the secure UI container
local TargetGui
pcall(function() TargetGui = gethui and gethui() end)
if not TargetGui then pcall(function() TargetGui = game:GetService("CoreGui") end) end
if not TargetGui then TargetGui = LocalPlayer:WaitForChild("PlayerGui") end

-- CLEANUP PREVIOUS RUN
if _G.AHScanner_CleanUp then
    pcall(_G.AHScanner_CleanUp)
end

local cleanUpSignals = {}

-- TOUCH SUPPORT HELPER
local function isTouchOrClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local statusLbl = nil
local doScan = nil
local updateToggleBtn = nil

-- ═════════════════════════════════════════════════════
-- LOAD LIVE MODULES & SCREEN CONTROLLERS
-- ═════════════════════════════════════════════════════
local Modules = ReplicatedStorage:FindFirstChild("Modules")

local ItemsData   = {}
local GaragesData = {}
local RarityData  = {}

if Modules then
    pcall(function() ItemsData   = require(Modules:WaitForChild("Items",    3)) end)
    pcall(function() GaragesData = require(Modules:WaitForChild("Garages",  3)) end)
    pcall(function() RarityData  = require(Modules:WaitForChild("Rarities", 3)) end)
end

-- ═════════════════════════════════════════════════════
-- RARITY / MUTATOR MULTIPLIERS
-- ═════════════════════════════════════════════════════
local RARITY_MULT = { Common = 1.0, Uncommon = 1.3, Rare = 2.0, Epic = 4.0, Legendary = 8.0, Mythical = 15.0, Exclusive = 25.0 }
local MUTATOR_MULT = { None = 1, Silver = 2, Gold = 4, Corrupted = 6, Diamond = 8, Gem = 12, Rainbow = 20 }
local GRADE_MULT = { [0] = 0.6, [1] = 0.8, [2] = 1.0, [3] = 1.25 }
local CONDITION_MULT = { Broken = 0.3, Poor = 0.55, Fair = 0.75, Good = 0.9, Excellent = 1.0, Mint = 1.15 }

-- ═════════════════════════════════════════════════════
-- GARAGE CATALOGUE
-- ═════════════════════════════════════════════════════
local GARAGE_CATALOG = {
    ["Scrap Garage 2"]          = { name="Scrap Garage",          tier=1, area="Junk Yard",  mascot="Billy", minNW=0,       minBid=0,   minProfit=-5,    maxProfit=100,  items=6, entMin=0,   entMax=0,    col=Color3.fromRGB(120,140,150) },
    ["Scrap Garage 3"]          = { name="Scrap Garage",          tier=1, area="Junk Yard",  mascot="Billy", minNW=0,       minBid=0,   minProfit=-5,    maxProfit=100,  items=6, entMin=0,   entMax=0,    col=Color3.fromRGB(120,140,150) },
    ["Shop Front"]              = { name="Shop Front",            tier=2, area="Back Alley", mascot="Sal",   minNW=750,     minBid=40,  minProfit=-20,   maxProfit=200,  items=6, entMin=5,   entMax=60,   col=Color3.fromRGB(80,200,120)  },
    ["Camo Shop Front"]         = { name="Camo Shop Front",       tier=2, area="Back Alley", mascot="Sal",   minNW=3000,    minBid=0,   minProfit=-50,   maxProfit=500,  items=6, entMin=5,   entMax=60,   col=Color3.fromRGB(130,200,80)  },
    ["Stable Garage"]           = { name="Stable Garage",         tier=3, area="Farmyard",   mascot="Ted",   minNW=10000,   minBid=100, minProfit=-50,   maxProfit=500,  items=6, entMin=15,  entMax=100,  col=Color3.fromRGB(100,160,255) },
    ["Barn Garage"]             = { name="Barn Garage",           tier=4, area="Farmyard",   mascot="Ted",   minNW=50000,   minBid=100, minProfit=-100,  maxProfit=750,  items=6, entMin=25,  entMax=250,  col=Color3.fromRGB(200,130,255) },
    ["Small Container Garage"]  = { name="Small Container",       tier=5, area="Shipyard",   mascot="Steve", minNW=125000,  minBid=300, minProfit=-200,  maxProfit=1500, items=6, entMin=50,  entMax=400,  col=Color3.fromRGB(255,185,60)  },
    ["Large Container Garage"]  = { name="Large Container",       tier=6, area="Shipyard",   mascot="Steve", minNW=400000,  minBid=400, minProfit=-300,  maxProfit=2000, items=6, entMin=100, entMax=700,  col=Color3.fromRGB(255,130,50)  },
    ["Warehouse Garage"]        = { name="Warehouse",             tier=7, area="Shipyard",   mascot="Steve", minNW=1250000, minBid=500, minProfit=-1000, maxProfit=5000, items=6, entMin=150, entMax=1500, col=Color3.fromRGB(255,80,90)   },
}

for id, gConfig in pairs(GARAGE_CATALOG) do
    local live = GaragesData[id]
    if live then
        gConfig.minNW     = tonumber(live.MinNetWorth)     or gConfig.minNW
        gConfig.minBid    = tonumber(live.MinAuctionValue) or gConfig.minBid
        gConfig.minProfit = tonumber(live.MinProfit)       or gConfig.minProfit
        gConfig.maxProfit = tonumber(live.MaxProfit)       or gConfig.maxProfit
        gConfig.items     = tonumber(live.NumItems)        or gConfig.items
    end
end

-- ═════════════════════════════════════════════════════
-- THEME & PALETTES
-- ═════════════════════════════════════════════════════
local C = {
    bg        = Color3.fromRGB(9,  11, 17),
    panel     = Color3.fromRGB(14, 18, 28),
    card      = Color3.fromRGB(19, 24, 38),
    cardHov   = Color3.fromRGB(27, 34, 54),
    border    = Color3.fromRGB(38, 48, 72),
    accent    = Color3.fromRGB(82, 162, 255),
    green     = Color3.fromRGB(60, 210, 120),
    gold      = Color3.fromRGB(255, 198, 55),
    red       = Color3.fromRGB(255, 80,  80),
    orange    = Color3.fromRGB(255, 155, 60),
    purple    = Color3.fromRGB(160, 90, 255),
    t1        = Color3.fromRGB(120, 140, 150),
    t2        = Color3.fromRGB(80, 200, 120),
    t3        = Color3.fromRGB(100, 160, 255),
    t4        = Color3.fromRGB(200, 130, 255),
    t5        = Color3.fromRGB(255, 185, 60),
    t6        = Color3.fromRGB(255, 130, 50),
    t7        = Color3.fromRGB(255, 80,  90),
    text      = Color3.fromRGB(228, 234, 255),
    text2     = Color3.fromRGB(130, 148, 185),
    textMuted = Color3.fromRGB(68,  85,  120),
    mutNone   = Color3.fromRGB(130, 148, 185),
    mutSilver = Color3.fromRGB(195, 210, 225),
    mutGold   = Color3.fromRGB(255, 198, 55),
    mutCorr   = Color3.fromRGB(155, 75,  255),
    mutDia    = Color3.fromRGB(90,  220, 255),
    mutGem    = Color3.fromRGB(255, 100, 180),
    mutRainbow= Color3.fromRGB(255, 255, 80),
}

local TIER_COL = {[0]=C.textMuted,[1]=C.t1,[2]=C.t2,[3]=C.t3,[4]=C.t4,[5]=C.t5,[6]=C.t6,[7]=C.t7}
local MUT_COL  = { None=C.mutNone, Silver=C.mutSilver, Gold=C.mutGold, Corrupted=C.mutCorr,
                   Diamond=C.mutDia, Gem=C.mutGem, Rainbow=C.mutRainbow }
local RARITY_COL = {
    Common=C.textMuted, Uncommon=C.green, Rare=C.accent,
    Epic=C.purple, Legendary=C.gold, Mythical=C.orange, Exclusive=C.red
}

-- ═════════════════════════════════════════════════════
-- AUTO-BID ENGINE SETUP
-- ═════════════════════════════════════════════════════
local AuctionEvents = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Auction")
local BidRemote              = AuctionEvents and AuctionEvents:FindFirstChild("Bid")
local UpdateWinningBidEvent  = AuctionEvents and AuctionEvents:FindFirstChild("UpdateWinningBid")

local AB = {
    enabled = false, maxBid = 2000, speed = 0.3,
    currentBid = 0, predictedVal = 0, bidsThisRound = 0, auctionOpen = false,
    activeLot = nil, activeLotData = nil,
    logLines = {}, onLog = nil
}

local SPEED_PRESETS = { { label="Safe 0.5s", val=0.50 }, { label="Normal 0.3s",val=0.30 }, { label="Fast 0.1s", val=0.10 } }

local function abLog(msg, col)
    local t = os.date("%H:%M:%S")
    table.insert(AB.logLines, 1, { text="["..t.."] "..msg, col=col or C.text2 })
    if #AB.logLines > 10 then table.remove(AB.logLines) end
    if AB.onLog then AB.onLog() end
end

local bidThread = nil
local function stopBidLoop(reason)
    if bidThread then task.cancel(bidThread) bidThread = nil end
    if reason then abLog("⚠️ Stopped: "..reason, C.red) end
end

local function startBidLoop()
    stopBidLoop()
    if not BidRemote then abLog("❌ Bid remote not found", C.red); AB.enabled = false; if updateToggleBtn then updateToggleBtn() end; return end
    abLog("🤖 BidLoop: max=$" .. AB.maxBid .. " spd=" .. AB.speed .. "s", C.green)
    bidThread = task.spawn(function()
        while AB.enabled and AB.auctionOpen do
            if AB.currentBid >= AB.maxBid then
                abLog("💸 Max bid reached", C.orange); AB.enabled = false; if updateToggleBtn then updateToggleBtn() end; break
            end
            -- Bidding proceeds purely based on Max Bid constraints
            local ok = pcall(function() BidRemote:FireServer() end)
            if ok then AB.bidsThisRound = AB.bidsThisRound + 1 else abLog("❌ Bid failed", C.red) end
            task.wait(AB.speed)
        end
    end)
end

-- ═════════════════════════════════════════════════════
-- VALUE CALCULATION (FIXED REVERSE LOOKUP FOR NAMES)
-- ═════════════════════════════════════════════════════
local function getItemData(identifier)
    if not ItemsData or type(ItemsData) ~= "table" then return "Unknown", 0 end
    
    local identifierStr = tostring(identifier)
    
    -- 1. Try direct lookup (if identifier is a name)
    if ItemsData[identifierStr] then
        local d = ItemsData[identifierStr]
        return (d.Name or d.name or identifierStr), tonumber(d.BasePrice or d.basePrice or d.Value or d.value) or 0
    end
    
    -- 2. Reverse lookup (if identifier is an ID)
    for id, v in pairs(ItemsData) do
        if type(v) == "table" then
            if tostring(id) == identifierStr or tostring(v.Id or v.id) == identifierStr then
                return (v.Name or v.name or "Unknown"), tonumber(v.BasePrice or v.basePrice or v.Value or v.value) or 0
            end
        end
    end
    
    return identifierStr, 0
end

local function calcItemValue(itemName, rarity, mutator, grade, condition)
    local realName, base = getItemData(itemName)
    if base <= 0 then
        local rarityFallbacks = { Common=15, Uncommon=35, Rare=80, Epic=200, Legendary=500, Mythical=1200, Exclusive=3000 }
        base = rarityFallbacks[rarity] or 15
    end
    
    local mMult     = MUTATOR_MULT[mutator]  or 1
    local gMult     = GRADE_MULT[tonumber(grade)] or 1.0
    local cMult     = CONDITION_MULT[condition]    or 1.0
    
    return realName, math.floor(base * mMult * gMult * cMult)
end

-- ═════════════════════════════════════════════════════
-- WORKSPACE SCANNER
-- ═════════════════════════════════════════════════════
local SCAN_RADIUS = 50
local function getSpawnPos(spawnInst)
    if spawnInst:IsA("BasePart") then return spawnInst.Position end
    local bp = spawnInst:FindFirstChildWhichIsA("BasePart")
    if bp then return bp.Position end
    return nil
end

local function isItemModel(model)
    if not model:IsA("Model") then return false end
    local base = model.PrimaryPart or model:FindFirstChild("Base")
    if not base then return false end
    local itemName = model:GetAttribute("ItemName") or model:GetAttribute("Name") or model.Name
    
    -- Exclude garage structures
    local nameLower = itemName:lower()
    if nameLower:find("garage") or nameLower == "right" or nameLower == "left" or nameLower == "door" or nameLower == "blocker" or nameLower == "button" or nameLower == "entrysquare" or nameLower == "npcspawns" then
        return false
    end
    
    local blacklist = { "Terrain", "Camera", "GarageSpawn", "AreaBoundary", "LostAndFoundBox", "Lost and Found Box", "Billy", "Sal", "Ted", "Steve", "Parts", "Part", "Model" }
    for _, b in ipairs(blacklist) do if itemName == b then return false end end
    return true
end

local function readItemAttributes(model)
    local attrs = {
        itemName  = model:GetAttribute("ItemName")  or model.Name,
        rarity    = model:GetAttribute("Rarity")    or "Common",
        mutator   = model:GetAttribute("Mutator")   or "None",
        grade     = model:GetAttribute("Grade"),
        condition = model:GetAttribute("Condition"),
        value     = model:GetAttribute("Value"),
        baseValue = model:GetAttribute("BaseValue"),
    }
    
    local basePart = model.PrimaryPart or model:FindFirstChild("Base")
    if basePart then
        attrs.itemName  = attrs.itemName  or basePart:GetAttribute("ItemName")
        attrs.rarity    = attrs.rarity    or basePart:GetAttribute("Rarity")
        attrs.mutator   = attrs.mutator   or basePart:GetAttribute("Mutator")
        attrs.value     = attrs.value     or basePart:GetAttribute("Value")
        attrs.grade     = attrs.grade     or basePart:GetAttribute("Grade")
        attrs.condition = attrs.condition or basePart:GetAttribute("Condition")
    end
    
    local realName, calcPrice = calcItemValue(attrs.itemName, attrs.rarity, attrs.mutator, attrs.grade, attrs.condition)
    attrs.displayName = realName
    
    local serverValue = tonumber(attrs.value or attrs.baseValue)
    if serverValue and serverValue > 0 then 
        attrs.calcValue = serverValue 
    else
        attrs.calcValue = calcPrice
    end
    return attrs
end

local function scanLot(spawnInst)
    local pos = getSpawnPos(spawnInst)
    if not pos then return {} end
    local items = {}
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Model") and isItemModel(desc) then
            local bp = desc.PrimaryPart or desc:FindFirstChild("Base")
            if bp and bp:IsA("BasePart") then
                local dist = (bp.Position - pos).Magnitude
                if dist <= SCAN_RADIUS then
                    local info = readItemAttributes(desc)
                    info.distance = math.floor(dist)
                    info.model = desc
                    table.insert(items, info)
                end
            end
        end
    end
    table.sort(items, function(a, b) return (a.calcValue or 0) > (b.calcValue or 0) end)
    return items
end

local function scanAllAreas()
    local results = {}
    local areasFolder = workspace:FindFirstChild("Areas")
    if not areasFolder then return results end

    for _, areaFolder in ipairs(areasFolder:GetChildren()) do
        local areaName = areaFolder.Name
        local gsFolder = areaFolder:FindFirstChild("GarageSpawns")
        if gsFolder then
            local areaResult = { name = areaName, lots = {} }
            for i, spawn in ipairs(gsFolder:GetChildren()) do
                local garageId    = spawn:GetAttribute("GarageType") or spawn.Name
                local garageConf  = GARAGE_CATALOG[garageId]
                if not garageConf then
                    for id, conf in pairs(GARAGE_CATALOG) do
                        if string.find(spawn.Name:lower(), conf.name:lower()) then garageConf = conf; garageId = id; break end
                    end
                end
                
                local conf = garageConf or { name="Unknown", tier=0, area=areaName, mascot="?", minNW=0, minBid=0, minProfit=0, maxProfit=0, items=6, entMin=0, entMax=0, col=Color3.fromRGB(100,100,100) }

                local scannedItems = scanLot(spawn)
                local totalVal = 0
                for _, it in ipairs(scannedItems) do totalVal = totalVal + (it.calcValue or 0) end

                local predictedAvg = conf.minBid + ((conf.minProfit + conf.maxProfit) / 2)
                local entCost = (conf.entMin + conf.entMax) / 2
                local useValue = (#scannedItems > 0) and totalVal or predictedAvg
                local roi = entCost > 0 and ((useValue - entCost) / entCost * 100) or 0

                table.insert(areaResult.lots, {
                    spawnName = spawn.Name, lotIndex = i, garageId = garageId, conf = conf,
                    items = scannedItems, scannedTotal = totalVal, predictedAvg = math.max(0, predictedAvg),
                    liveScan = #scannedItems > 0, entCostMid = entCost, roi = roi,
                    verdict = useValue > entCost and "Profitable" or useValue > 0 and "Break-Even" or "Loss Risk",
                })
            end
            table.insert(results, areaResult)
        end
    end
    return results
end

-- ═════════════════════════════════════════════════════
-- UI CONSTRUCTORS
-- ═════════════════════════════════════════════════════
local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function pad(px, p) return make("UIPadding", {PaddingTop=UDim.new(0,px), PaddingBottom=UDim.new(0,px), PaddingLeft=UDim.new(0,px), PaddingRight=UDim.new(0,px)}, p) end
local function corner(r, p) return make("UICorner", {CornerRadius=UDim.new(0,r)}, p) end
local function stroke(th, col, p) return make("UIStroke", {Thickness=th, Color=col, ApplyStrokeMode=Enum.ApplyStrokeMode.Border}, p) end
local function list(align, spacing, p) return make("UIListLayout", {HorizontalAlignment=align or Enum.HorizontalAlignment.Left, VerticalAlignment=Enum.VerticalAlignment.Top, Padding=UDim.new(0, spacing or 6), SortOrder=Enum.SortOrder.LayoutOrder}, p) end
local function tw(inst, sec, props) 
    local info = TweenInfo.new(sec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) 
    pcall(function() local t = TweenService:Create(inst, info, props); t:Play() end)
end
local function fm(num) return num >= 1000 and string.format("$%.1fk", num/1000) or string.format("$%d", num) end

-- Clean previous instances safely
pcall(function()
    for _, v in ipairs(TargetGui:GetChildren()) do
        if v.Name == "AHScanner" then v:Destroy() end
    end
end)

-- ═════════════════════════════════════════════════════
-- SCREEN GUI & MAGIC AUTO-SCALER
-- ═════════════════════════════════════════════════════
local ScreenGui = make("ScreenGui", {
    Name="AHScanner", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true,
}, TargetGui)

local ToggleBtn = make("TextButton", {
    Name = "AHToggle",
    Size = UDim2.new(0, 36, 0, 36),
    Position = UDim2.new(0.02, 0, 0.15, 0),
    BackgroundColor3 = Color3.fromRGB(15, 12, 28),
    Text = "🔍",
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    TextColor3 = C.accent,
    ZIndex = 99999,
    Active = true,
    Draggable = true,
}, ScreenGui)
corner(18, ToggleBtn); stroke(1.5, C.accent, ToggleBtn)

ToggleBtn.MouseButton1Click:Connect(function()
    Win.Visible = not Win.Visible
end)

local BASE_WIDTH = 840
local BASE_HEIGHT = 460

local Win = make("Frame", {
    Name="Win", AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),
    Size=UDim2.new(0,BASE_WIDTH,0,BASE_HEIGHT),
    BackgroundColor3=C.bg, ClipsDescendants=true,
}, ScreenGui)
corner(12, Win)
stroke(1.5, C.border, Win)

-- The magic scaler that zooms the UI to fit perfectly on any phone screen
local uiScale = Instance.new("UIScale", Win)

local function updateScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    -- Zoom out to leave a 5% margin around the screen
    local scaleX = (viewport.X * 0.95) / BASE_WIDTH
    local scaleY = (viewport.Y * 0.95) / BASE_HEIGHT
    uiScale.Scale = math.min(scaleX, scaleY, 1)
end

updateScale()
table.insert(cleanUpSignals, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

local WinGrad = make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 17, 28)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(9, 11, 17)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 7, 11)),
    }),
    Rotation = 45,
}, Win)

local topBar = make("Frame", {Size=UDim2.new(1,0,0,3), BackgroundColor3=C.accent, BorderSizePixel=0}, Win)
make("UIGradient", { Color=ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(60,140,255)), ColorSequenceKeypoint.new(0.4,Color3.fromRGB(120,60,255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255,90,150)) }) }, topBar)

-- ── HEADER ───────────────────────────────────────────
local Hdr = make("Frame", { Size=UDim2.new(1,0,0,44), Position=UDim2.new(0,0,0,3), BackgroundColor3=C.panel, BorderSizePixel=0, }, Win)
make("TextLabel", { Text="🔍", TextSize=18, BackgroundTransparency=1, Position=UDim2.new(0,10,0,0), Size=UDim2.new(0,24,1,0), TextYAlignment=Enum.TextYAlignment.Center, Font=Enum.Font.GothamBold, }, Hdr)
make("TextLabel", { Text="<b>LIVE SCANNER</b>", TextSize=12, TextColor3=C.text, BackgroundTransparency=1, RichText=true, Position=UDim2.new(0,38,0,5), Size=UDim2.new(0,180,0,18), Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left, }, Hdr)
make("TextLabel", { Text="Storage Hunters: Open World", TextSize=9, TextColor3=C.text2, BackgroundTransparency=1, Position=UDim2.new(0,38,0,21), Size=UDim2.new(0,180,0,14), Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left, }, Hdr)

local ScanBadge = make("Frame", { Position=UDim2.new(1,-254,0.5,-12), Size=UDim2.new(0,78,0,24), BackgroundColor3=Color3.fromRGB(12,22,12), BorderSizePixel=0, }, Hdr)
corner(6, ScanBadge); stroke(1, C.green, ScanBadge)
local ScanDot = make("Frame", { Size=UDim2.new(0,6,0,6), Position=UDim2.new(0,7,0.5,-3), BackgroundColor3=C.green, BorderSizePixel=0, }, ScanBadge)
corner(99, ScanDot)
local ScanTxt = make("TextLabel", { Text="LIVE SCAN", TextSize=8, TextColor3=C.green, BackgroundTransparency=1, Font=Enum.Font.GothamBold, Position=UDim2.new(0,16,0,0), Size=UDim2.new(1,-18,1,0), TextXAlignment=Enum.TextXAlignment.Left, }, ScanBadge)

local BindBtn = make("TextButton", { Text="Bind: RShift", TextSize=9, TextColor3=C.text2, BackgroundColor3=Color3.fromRGB(24,28,40), Position=UDim2.new(1,-170,0.5,-12), Size=UDim2.new(0,86,0,24), Font=Enum.Font.GothamBold, AutoButtonColor=false, }, Hdr)
corner(6, BindBtn); stroke(1.2, C.border, BindBtn)

local listeningForKeybind = false
local currentKeybind = Enum.KeyCode.RightShift
BindBtn.MouseButton1Click:Connect(function() listeningForKeybind = true; BindBtn.Text = "Press Key..."; tw(BindBtn, 0.1, {BackgroundColor3=Color3.fromRGB(38,32,60), TextColor3=C.purple}) end)

UserInputService.InputBegan:Connect(function(input, processed)
    if listeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
        listeningForKeybind = false; currentKeybind = input.KeyCode; BindBtn.Text = "Bind: " .. input.KeyCode.Name; tw(BindBtn, 0.1, {BackgroundColor3=Color3.fromRGB(24,28,40), TextColor3=C.text2})
    elseif not processed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKeybind then
        Win.Visible = not Win.Visible
    end
end)

local function hdrBtn(icon, xOff, bgCol, hoverCol)
    local b = make("TextButton", { Text=icon, TextSize=11, TextColor3=C.text2, BackgroundColor3=bgCol, Position=UDim2.new(1,xOff,0.5,-12), Size=UDim2.new(0,24,0,24), Font=Enum.Font.GothamBold, AutoButtonColor=false, }, Hdr)
    corner(6, b); b.MouseEnter:Connect(function() tw(b,0.12,{BackgroundColor3=hoverCol, TextColor3=C.text}) end); b.MouseLeave:Connect(function() tw(b,0.12,{BackgroundColor3=bgCol, TextColor3=C.text2}) end)
    return b
end

local CloseBtn = hdrBtn("✕", -32,  Color3.fromRGB(48,25,30), Color3.fromRGB(200,55,75))
local MinBtn   = hdrBtn("—", -62,  Color3.fromRGB(25,28,42), C.border)

CloseBtn.MouseButton1Click:Connect(function() tw(Win, 0.25, {Size=UDim2.new(0,BASE_WIDTH,0,0), BackgroundTransparency=1}); task.delay(0.3, function() ScreenGui:Destroy() end) end)
local minned = false
MinBtn.MouseButton1Click:Connect(function() minned = not minned; tw(Win, 0.22, {Size=UDim2.new(0,BASE_WIDTH,0, minned and 50 or BASE_HEIGHT)}) end)

-- ─────────────────────────────────────────────────────
-- SIDEBAR
-- ─────────────────────────────────────────────────────
local Sidebar = make("Frame", { Size = UDim2.new(0, 300, 1, -67), Position = UDim2.new(0, 6, 0, 47), BackgroundColor3 = C.panel, BackgroundTransparency = 0.4, BorderSizePixel = 0, }, Win)
corner(10, Sidebar); stroke(1.2, C.border, Sidebar)

local StatsGrid = make("Frame", { Size = UDim2.new(1, -12, 0, 80), Position = UDim2.new(0, 6, 0, 6), BackgroundTransparency = 1, }, Sidebar)

local function statPill(labelTxt, valInit, col, x, y)
    local pill = make("Frame", { Size = UDim2.new(0.5, -4, 0, 36), Position = UDim2.new(x, x == 0 and 0 or 4, y, y == 0 and 0 or 4), BackgroundColor3 = C.card, }, StatsGrid)
    corner(6, pill); stroke(1, col:Lerp(Color3.fromRGB(0,0,0),0.55), pill)
    make("TextLabel", { Text=labelTxt, TextSize=8, TextColor3=C.textMuted, Font=Enum.Font.Gotham, BackgroundTransparency=1, Position=UDim2.new(0,6,0,2), Size=UDim2.new(1,-6,0,12), TextXAlignment=Enum.TextXAlignment.Left, }, pill)
    return make("TextLabel", { Text=valInit, TextSize=11, TextColor3=col, Font=Enum.Font.GothamBold, BackgroundTransparency=1, Position=UDim2.new(0,6,0,14), Size=UDim2.new(1,-6,0,18), TextXAlignment=Enum.TextXAlignment.Left, RichText=true, }, pill)
end

local statLots    = statPill("LOTS FOUND",    "—",  C.accent, 0, 0)
local statItems   = statPill("ITEMS SCANNED", "—",  C.green,  0.5, 0)
local statTotal   = statPill("TOTAL VALUE",   "—",  C.gold,   0, 0.5)
local statBestLot = statPill("BEST LOT",      "—",  C.purple, 0.5, 0.5)

local ControlsRow = make("Frame", { Size = UDim2.new(1, -12, 0, 118), Position = UDim2.new(0, 6, 0, 92), BackgroundTransparency = 1, }, Sidebar)
local SORTS = {"Value ↓", "Value ↑", "Tier ↓", "Tier ↑", "Area"}
local currentSort = 1; local onSortChange = nil

local SortCycleBtn = make("TextButton", { Text = "Sort: Value ↓", TextSize = 10, Font = Enum.Font.GothamMedium, TextColor3 = C.accent, BackgroundColor3 = C.card, Size = UDim2.new(0.6, -4, 0, 26), AutoButtonColor = false, }, ControlsRow)
corner(6, SortCycleBtn); stroke(1, C.accent:Lerp(Color3.fromRGB(0,0,0), 0.5), SortCycleBtn)
SortCycleBtn.MouseButton1Click:Connect(function() currentSort = currentSort % #SORTS + 1; SortCycleBtn.Text = "Sort: " .. SORTS[currentSort]; if onSortChange then onSortChange() end end)

local RefreshBtn = make("TextButton", { Text = "⟳ Refresh", TextSize = 10, Font = Enum.Font.GothamBold, TextColor3 = C.text, BackgroundColor3 = C.accent:Lerp(C.bg, 0.4), Size = UDim2.new(0.4, 0, 0, 26), Position = UDim2.new(0.6, 4, 0, 0), AutoButtonColor = false, }, ControlsRow)
corner(6, RefreshBtn); stroke(1, C.accent, RefreshBtn)

local espActive = false; local espHighlights = {}; local scanData = {}
local function clearESP() for _, h in ipairs(espHighlights) do if h and h.Parent then h:Destroy() end end; espHighlights = {} end
local function applyESP()
    clearESP(); if not espActive or not scanData then return end
    for _, area in ipairs(scanData) do
        if area and type(area) == "table" and area.lots then
            for _, lot in ipairs(area.lots) do
                if type(lot) == "table" and lot.liveScan then
                    for _, item in ipairs(lot.items) do
                        if item.model and item.model.Parent then
                            local h = make("Highlight", { FillColor = RARITY_COL[item.rarity] or C.textMuted, FillTransparency = 0.45, OutlineColor = Color3.fromRGB(255,255,255), OutlineTransparency = 0.15, Adornee = item.model, }, ScreenGui)
                            table.insert(espHighlights, h)
                        end
                    end
                end
            end
        end
    end
end

local EspBtn = make("TextButton", { Text = "📦 ESP: OFF", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.textMuted, BackgroundColor3 = C.card, Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0, 0, 0, 32), AutoButtonColor = false, }, ControlsRow)
corner(6, EspBtn); stroke(1, C.border, EspBtn)
EspBtn.MouseButton1Click:Connect(function() espActive = not espActive; if espActive then EspBtn.Text = "📦 ESP: ON"; tw(EspBtn, 0.1, {BackgroundColor3 = C.green:Lerp(Color3.fromRGB(0,0,0), 0.8), TextColor3 = C.green}); stroke(1.2, C.green, EspBtn); applyESP() else EspBtn.Text = "📦 ESP: OFF"; tw(EspBtn, 0.1, {BackgroundColor3 = C.card, TextColor3 = C.textMuted}); stroke(1, C.border, EspBtn); clearESP() end end)

local merchantIndex = 1
local MERCHANTS = { { name = "Billy", area = "Junk Yard" }, { name = "Sal", area = "Back Alley" }, { name = "Ted", area = "Farmyard" }, { name = "Steve", area = "Shipyard" } }
local TpMerchantBtn = make("TextButton", { Text = "📍 TP: Billy", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 160, 255), BackgroundColor3 = Color3.fromRGB(30, 22, 45), Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0.5, 4, 0, 32), AutoButtonColor = false, }, ControlsRow)
corner(6, TpMerchantBtn); stroke(1, Color3.fromRGB(150, 100, 230), TpMerchantBtn)
TpMerchantBtn.MouseButton1Click:Connect(function()
    pcall(function()
        local data = MERCHANTS[merchantIndex]; local npc = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild(data.area) and workspace.Areas[data.area]:FindFirstChild(data.name)
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if root and npc then local bp = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart"); if bp then root.CFrame = bp.CFrame + Vector3.new(0, 3, 0); statusLbl.Text = "⚡ Teleported to Merchant " .. data.name; statusLbl.TextColor3 = C.green end end
        merchantIndex = merchantIndex % #MERCHANTS + 1; TpMerchantBtn.Text = "📍 TP: " .. MERCHANTS[merchantIndex].name
    end)
end)

local speedActive = false; local defaultSpeed = 16; local hackSpeed = 32
local SpeedBtn = make("TextButton", { Text = "🏃 Speed: OFF", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.textMuted, BackgroundColor3 = C.card, Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0, 0, 0, 62), AutoButtonColor = false, }, ControlsRow)
corner(6, SpeedBtn); stroke(1, C.border, SpeedBtn)
SpeedBtn.MouseButton1Click:Connect(function()
    speedActive = not speedActive
    if speedActive then SpeedBtn.Text = "🏃 Speed: ON"; tw(SpeedBtn, 0.1, {BackgroundColor3 = C.green:Lerp(Color3.fromRGB(0,0,0), 0.8), TextColor3 = C.green}); stroke(1.2, C.green, SpeedBtn); pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = hackSpeed end)
    else SpeedBtn.Text = "🏃 Speed: OFF"; tw(SpeedBtn, 0.1, {BackgroundColor3 = C.card, TextColor3 = C.textMuted}); stroke(1, C.border, SpeedBtn); pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = defaultSpeed end) end
end)

local infJumpActive = false
table.insert(cleanUpSignals, UserInputService.JumpRequest:Connect(function() if infJumpActive then local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"); if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end end))
local JumpBtn = make("TextButton", { Text = "🦘 InfJump: OFF", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.textMuted, BackgroundColor3 = C.card, Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0.5, 4, 0, 62), AutoButtonColor = false, }, ControlsRow)
corner(6, JumpBtn); stroke(1, C.border, JumpBtn)
JumpBtn.MouseButton1Click:Connect(function()
    infJumpActive = not infJumpActive
    if infJumpActive then JumpBtn.Text = "🦘 InfJump: ON"; tw(JumpBtn, 0.1, {BackgroundColor3 = C.green:Lerp(Color3.fromRGB(0,0,0), 0.8), TextColor3 = C.green}); stroke(1.2, C.green, JumpBtn)
    else JumpBtn.Text = "🦘 InfJump: OFF"; tw(JumpBtn, 0.1, {BackgroundColor3 = C.card, TextColor3 = C.textMuted}); stroke(1, C.border, JumpBtn) end
end)

local QuickSaleBtn = make("TextButton", { Text = "💰 Sell All Items", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 185, 60), BackgroundColor3 = Color3.fromRGB(40, 28, 12), Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0, 0, 0, 92), AutoButtonColor = false, }, ControlsRow)
corner(6, QuickSaleBtn); stroke(1, Color3.fromRGB(200, 130, 30), QuickSaleBtn)
QuickSaleBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        pcall(function()
            local getRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("GetSellableItems")
            local sellRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("SellItems")
            if not getRemote or not sellRemote then statusLbl.Text = "❌ Remotes not found!"; statusLbl.TextColor3 = C.red; return end
            statusLbl.Text = "⏳ Fetching sellable items..."; statusLbl.TextColor3 = C.gold
            local items = getRemote:InvokeServer()
            if not items or not next(items) then statusLbl.Text = "💰 Nothing to sell!"; statusLbl.TextColor3 = C.orange; return end
            local guids = {}
            for guid, data in pairs(items) do table.insert(guids, guid) end
            statusLbl.Text = "💰 Selling " .. #guids .. " items..."; statusLbl.TextColor3 = C.gold
            local res = sellRemote:InvokeServer(guids)
            if res and res.success then statusLbl.Text = string.format("💰 Sold %d items for $%d!", res.sold or #guids, res.totalEarned or 0); statusLbl.TextColor3 = C.green
            else statusLbl.Text = "❌ Sale failed!"; statusLbl.TextColor3 = C.red end
        end)
    end)
end)

local noclipActive = false
table.insert(cleanUpSignals, RunService.Stepped:Connect(function() if noclipActive and LocalPlayer.Character then for _, desc in ipairs(LocalPlayer.Character:GetDescendants()) do if desc:IsA("BasePart") and desc.CanCollide then desc.CanCollide = false end end end end))
local NoclipBtn = make("TextButton", { Text = "🧱 Noclip: OFF", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.textMuted, BackgroundColor3 = C.card, Size = UDim2.new(0.5, -4, 0, 26), Position = UDim2.new(0.5, 4, 0, 92), AutoButtonColor = false, }, ControlsRow)
corner(6, NoclipBtn); stroke(1, C.border, NoclipBtn)
NoclipBtn.MouseButton1Click:Connect(function()
    noclipActive = not noclipActive
    if noclipActive then NoclipBtn.Text = "🧱 Noclip: ON"; tw(NoclipBtn, 0.1, {BackgroundColor3 = C.green:Lerp(Color3.fromRGB(0,0,0), 0.8), TextColor3 = C.green}); stroke(1.2, C.green, NoclipBtn)
    else NoclipBtn.Text = "🧱 Noclip: OFF"; tw(NoclipBtn, 0.1, {BackgroundColor3 = C.card, TextColor3 = C.textMuted}); stroke(1, C.border, NoclipBtn) end
end)

local ABPanel = make("Frame", { Size = UDim2.new(1, 0, 1, -216), Position = UDim2.new(0, 0, 0, 216), BackgroundColor3 = Color3.fromRGB(12, 14, 22), BorderSizePixel = 0, ClipsDescendants = true, }, Sidebar)
corner(8, ABPanel); stroke(1, C.border, ABPanel)
local abHdr = make("Frame", { Size=UDim2.new(1,0,0,32), BackgroundColor3=Color3.fromRGB(16,12,28), BorderSizePixel=0, }, ABPanel)
pad(6, abHdr); list(nil, 6, abHdr); abHdr.UIListLayout.FillDirection = Enum.FillDirection.Horizontal; abHdr.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
make("TextLabel", { Text="🤖 AUTO-BID", TextSize=10, TextColor3=C.purple, Font=Enum.Font.GothamBold, BackgroundTransparency=1, Size=UDim2.new(0,80,1,0), TextXAlignment=Enum.TextXAlignment.Left, }, abHdr)

local toggleBtn = make("TextButton", { Text="OFF", TextSize=9, Font=Enum.Font.GothamBold, TextColor3=C.textMuted, BackgroundColor3=Color3.fromRGB(20,14,14), Size=UDim2.new(0,42,0,20), AutoButtonColor=false, }, abHdr)
corner(5, toggleBtn); stroke(1, C.red, toggleBtn)

local function updateToggleBtn_impl()
    if AB.enabled then tw(toggleBtn, 0.15, {BackgroundColor3=C.green:Lerp(Color3.fromRGB(0,0,0),0.7), TextColor3=C.green}); toggleBtn.Text = "ON"; for _, c in ipairs(toggleBtn:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end; stroke(1, C.green, toggleBtn)
    else tw(toggleBtn, 0.15, {BackgroundColor3=Color3.fromRGB(20,10,10), TextColor3=C.textMuted}); toggleBtn.Text = "OFF"; for _, c in ipairs(toggleBtn:GetChildren()) do if c:IsA("UIStroke") then c:Destroy() end end; stroke(1, C.red, toggleBtn) end
end
updateToggleBtn = updateToggleBtn_impl

toggleBtn.MouseButton1Click:Connect(function()
    AB.enabled = not AB.enabled; updateToggleBtn_impl()
    if AB.enabled then
        AB.auctionOpen = true
        abLog("✅ Auto-Bid STARTED", C.green)
        startBidLoop()
    else
        stopBidLoop("Manually Disabled"); abLog("❌ Auto‑Bid disabled", C.red)
    end
end)

make("TextLabel", { Text = (BidRemote ~= nil) and "✅ Remote OK" or "❌ Offline", TextSize=8, TextColor3=(BidRemote ~= nil) and C.green or C.red, BackgroundTransparency=1, Font=Enum.Font.GothamMedium, Size=UDim2.new(1,-142,1,0), TextXAlignment=Enum.TextXAlignment.Right, }, abHdr)

local ctrlRow = make("Frame", { Size=UDim2.new(1,-12,0,26), Position=UDim2.new(0,6,0,38), BackgroundTransparency=1, }, ABPanel)
list(nil, 6, ctrlRow); ctrlRow.UIListLayout.FillDirection = Enum.FillDirection.Horizontal; ctrlRow.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
make("TextLabel", { Text="Max:", TextSize=9, TextColor3=C.text2, Font=Enum.Font.GothamMedium, BackgroundTransparency=1, Size=UDim2.new(0,25,1,0), TextXAlignment=Enum.TextXAlignment.Left, }, ctrlRow)

local maxBidBox = make("TextBox", { Text=tostring(AB.maxBid), TextSize=11, TextColor3=C.gold, Font=Enum.Font.GothamBold, BackgroundColor3=C.card, Size=UDim2.new(0,50,0,20), TextXAlignment=Enum.TextXAlignment.Center, ClearTextOnFocus=false, }, ctrlRow)
corner(5, maxBidBox); stroke(1, C.gold:Lerp(Color3.fromRGB(0,0,0),0.4), maxBidBox)
maxBidBox.FocusLost:Connect(function() local v = tonumber(maxBidBox.Text); if v and v > 0 then AB.maxBid = v; abLog("💰 Max Bid: $"..v, C.gold) else maxBidBox.Text = tostring(AB.maxBid) end end)

-- Profit Guard removed by request

local speedRow = make("Frame", { Size=UDim2.new(1,-12,0,24), Position=UDim2.new(0,6,0,68), BackgroundTransparency=1, }, ABPanel)
list(nil, 4, speedRow); speedRow.UIListLayout.FillDirection = Enum.FillDirection.Horizontal; speedRow.UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
make("TextLabel", { Text="Spd:", TextSize=9, TextColor3=C.text2, Font=Enum.Font.GothamMedium, BackgroundTransparency=1, Size=UDim2.new(0,25,1,0), TextXAlignment=Enum.TextXAlignment.Left, }, speedRow)

local speedPresetBtns = {}; local customSpeedLbl = nil
local function selectPreset(idx)
    local preset = SPEED_PRESETS[idx]; AB.speed = preset.val; abLog("⚡ Speed: "..preset.val.."s", C.accent)
    for i, sb in ipairs(speedPresetBtns) do
        local active = (i == idx)
        tw(sb, 0.1, {BackgroundColor3 = active and Color3.fromRGB(130,80,255):Lerp(C.card,0.5) or C.card})
        for _, c in ipairs(sb:GetChildren()) do if c:IsA("TextLabel") then tw(c, 0.1, {TextColor3 = active and Color3.fromRGB(210,140,255) or C.textMuted}) end end
    end
    if customSpeedLbl then customSpeedLbl.Text = string.format("%.2fs", AB.speed) end
end

for i, preset in ipairs(SPEED_PRESETS) do
    local sb = make("Frame", { Size=UDim2.new(0,46,0,20), BackgroundColor3=C.card, }, speedRow)
    corner(5, sb)
    make("TextLabel", { Text=preset.label, TextSize=8, TextColor3=C.textMuted, Font=Enum.Font.GothamBold, BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), TextXAlignment=Enum.TextXAlignment.Center, }, sb)
    table.insert(speedPresetBtns, sb)
    local ibtn = make("TextButton", {Text="", BackgroundTransparency=1, Size=UDim2.new(1,0,1,0), AutoButtonColor=false}, sb)
    local iCopy = i
    ibtn.MouseButton1Click:Connect(function() selectPreset(iCopy) end)
end

local sliderBox = make("Frame", { Size=UDim2.new(0,102,0,20), BackgroundColor3=C.card, }, speedRow)
corner(5, sliderBox); stroke(1, C.border, sliderBox)
local sliderTrack = make("Frame", { Size=UDim2.new(1,-38,0,4), Position=UDim2.new(0,5,0.5,-2), BackgroundColor3=C.border, BorderSizePixel=0, }, sliderBox)
corner(2, sliderTrack)
local sliderFill = make("Frame", { Size=UDim2.new(0.3,0,1,0), BackgroundColor3=C.purple, BorderSizePixel=0, }, sliderTrack)
corner(2, sliderFill)
local sliderKnob = make("Frame", { Size=UDim2.new(0,8,0,8), AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new(0.3,0,0.5,0), BackgroundColor3=Color3.fromRGB(210,140,255), BorderSizePixel=0, }, sliderTrack)
corner(99, sliderKnob)
customSpeedLbl = make("TextLabel", { Text="0.30s", TextSize=7, TextColor3=Color3.fromRGB(210,140,255), Font=Enum.Font.GothamBold, BackgroundTransparency=1, Position=UDim2.new(1,-32,0,0), Size=UDim2.new(0,30,1,0), TextXAlignment=Enum.TextXAlignment.Right, }, sliderBox)

local sliderDragging = false
local MIN_SPD, MAX_SPD = 0.02, 2.0
local function applySliderAt(ratio)
    ratio = math.clamp(ratio, 0, 1)
    AB.speed = math.floor((MIN_SPD * (MAX_SPD / MIN_SPD) ^ ratio) * 100) / 100
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0); sliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
    customSpeedLbl.Text = string.format("%.2fs", AB.speed)
    for _, sb2 in ipairs(speedPresetBtns) do tw(sb2, 0.05, {BackgroundColor3=C.card}) end
end

sliderTrack.InputBegan:Connect(function(inp) if isTouchOrClick(inp) then sliderDragging = true; applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)) end end)
UserInputService.InputChanged:Connect(function(inp) if sliderDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)) end end)
UserInputService.InputEnded:Connect(function(inp) if isTouchOrClick(inp) then sliderDragging = false end end)

selectPreset(2)

local logOuter = make("Frame", { Size=UDim2.new(1,-12,1,-100), Position=UDim2.new(0,6,0,94), BackgroundColor3=Color3.fromRGB(8,10,16), BorderSizePixel=0, ClipsDescendants=true, }, ABPanel)
corner(6, logOuter); pad(4, logOuter)
local logLabels = {}
for i = 1, 6 do logLabels[i] = make("TextLabel", { Text="", TextSize=8, TextColor3=C.textMuted, Font=Enum.Font.Gotham, BackgroundTransparency=1, Position=UDim2.new(0,0,0,(i-1)*13), Size=UDim2.new(1,0,0,12), TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd, }, logOuter) end

local clearLogBtn = make("TextButton", { Text="Clear", TextSize=8, TextColor3=C.textMuted, BackgroundColor3=Color3.fromRGB(16,18,28), Position=UDim2.new(1,-36,1,-14), Size=UDim2.new(0,32,0,14), Font=Enum.Font.Gotham, AutoButtonColor=false, }, logOuter)
corner(3, clearLogBtn); clearLogBtn.MouseButton1Click:Connect(function() AB.logLines = {}; if AB.onLog then AB.onLog() end end)

AB.onLog = function() for i, lbl in ipairs(logLabels) do local entry = AB.logLines[i]; if entry then lbl.Text = entry.text; lbl.TextColor3 = entry.col else lbl.Text = "" end end end

-- ─────────────────────────────────────────────────────
-- CONTENT PANEL
-- ─────────────────────────────────────────────────────
local ContentPanel = make("Frame", { Size = UDim2.new(1, -320, 1, -67), Position = UDim2.new(0, 314, 0, 47), BackgroundTransparency = 1, }, Win)
local TabHeader = make("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, }, ContentPanel)
local ScrollTab = make("ScrollingFrame", { Size=UDim2.new(1,0,1,-28), Position=UDim2.new(0,0,0,28), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, ScrollBarImageColor3=C.accent, ScrollBarImageTransparency=0.3, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, }, ContentPanel)
pad(4, ScrollTab); list(nil, 6, ScrollTab)

local activeTab = "wash"
local selectedItems = { Wash=nil, Repair=nil, Grading=nil, Locksmith=nil }
local tabButtons = {}

local function createTabBtn(name, id, size, pos)
    local b = make("TextButton", { Text = name, TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.textMuted, BackgroundColor3 = C.card, Size = size, Position = pos, AutoButtonColor = false, }, TabHeader)
    corner(5, b); stroke(1, C.border, b); tabButtons[id] = b
    b.MouseButton1Click:Connect(function() activeTab = id; updateTabs() end)
end

local tabW = 0.20
createTabBtn("🏪 Lots",      "lots",      UDim2.new(tabW, -4, 1, 0), UDim2.new(0, 0, 0, 0))
createTabBtn("🛁 Wash",      "wash",      UDim2.new(tabW, -4, 1, 0), UDim2.new(tabW, 0, 0, 0))
createTabBtn("🔧 Repair",    "repair",    UDim2.new(tabW, -4, 1, 0), UDim2.new(tabW * 2, 0, 0, 0))
createTabBtn("🔬 Grade",     "grade",     UDim2.new(tabW, -4, 1, 0), UDim2.new(tabW * 3, 0, 0, 0))
createTabBtn("🔑 Locksmith", "locksmith", UDim2.new(tabW, -4, 1, 0), UDim2.new(tabW * 4, 0, 0, 0))

local StatusBar = make("Frame", { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 1, -24), BackgroundTransparency = 1, }, Win)
statusLbl = make("TextLabel", { Text = "🟢 Scanner & Remote workshops active.", TextSize = 9, TextColor3 = C.text2, Font = Enum.Font.GothamMedium, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, }, StatusBar)

local function renderLots(flatLots)
    for _, c in ipairs(ScrollTab:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
    local flat, totalItems, totalVal, bestVal, bestName = {}, 0, 0, 0, "—"
    for _, area in ipairs(flatLots) do if type(area) == "table" and area.lots then for _, lot in ipairs(area.lots) do if type(lot) == "table" and lot.conf then lot._area = area.name or "Unknown"; table.insert(flat, lot) end end end end
    for _, lot in ipairs(flat) do
        if lot.conf then
            local v = lot.liveScan and lot.scannedTotal or lot.predictedAvg
            totalItems = totalItems + (lot.items and #lot.items or 0)
            totalVal = totalVal + (v or 0)
            if (v or 0) > bestVal then bestVal = v; bestName = lot.conf.name.." #"..lot.lotIndex end
        end
    end
    statLots.Text = tostring(#flat); statItems.Text = totalItems > 0 and tostring(totalItems) or "—"; statTotal.Text = fm(totalVal); statBestLot.Text = bestName == "—" and "—" or (bestName .. " (" .. fm(bestVal) .. ")")
    make("TextLabel", { Text = "🚧 Auction List Coming Soon 🚧", TextSize = 16, TextColor3 = C.text2, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, }, ScrollTab)
end

-- ─────────────────────────────────────────────────────
-- RENDER SHOP WORKSHOPS TAB (Wash, Repair, Grade, Locksmith)
-- ─────────────────────────────────────────────────────
local activeTimersList = {} 

local EventsObj = ReplicatedStorage:WaitForChild("Events", 10)

local SHOPS = {
    Wash = {
        title = "🛁 Wash Station", itemLabel = "Select a Dirty Item", itemEmpty = "No dirty items to wash", maxSlots = 3,
        getEligible = function() return EventsObj:WaitForChild("Wash"):WaitForChild("GetWashableItems"):InvokeServer() end,
        getSlots    = function() return EventsObj:WaitForChild("Wash"):WaitForChild("GetSlotState"):InvokeServer() end,
        startWork   = function(slot, guid, src, vguid) return EventsObj:WaitForChild("Wash"):WaitForChild("StartWash"):InvokeServer(slot, guid, src, vguid) end,
        claimWork   = function(slot) return EventsObj:WaitForChild("Wash"):WaitForChild("ClaimWashedItem"):InvokeServer(slot) end,
        unlockSlot  = function(slot) return EventsObj:WaitForChild("Wash"):WaitForChild("UnlockSlot"):InvokeServer(slot) end,
        speedUp     = function(slot) return EventsObj:WaitForChild("Wash"):WaitForChild("SpeedUpWash"):InvokeServer(slot) end,
    },
    Repair = {
        title = "🔧 Repair Shop", itemLabel = "Select a Broken Item", itemEmpty = "No broken items to repair", maxSlots = 3,
        getEligible = function() return EventsObj:WaitForChild("Repair"):WaitForChild("GetRepairableItems"):InvokeServer() end,
        getSlots    = function() return EventsObj:WaitForChild("Repair"):WaitForChild("GetSlotState"):InvokeServer() end,
        startWork   = function(slot, guid, src, vguid) return EventsObj:WaitForChild("Repair"):WaitForChild("StartRepair"):InvokeServer(slot, guid, src, vguid) end,
        claimWork   = function(slot) return EventsObj:WaitForChild("Repair"):WaitForChild("ClaimRepairedItem"):InvokeServer(slot) end,
        unlockSlot  = function(slot) return EventsObj:WaitForChild("Repair"):WaitForChild("UnlockSlot"):InvokeServer(slot) end,
        speedUp     = function(slot) return EventsObj:WaitForChild("Repair"):WaitForChild("SpeedUpRepair"):InvokeServer(slot) end,
    },
    Grading = {
        title = "🔬 Grading Office", itemLabel = "Select an ungraded Item", itemEmpty = "No items eligible for grading", maxSlots = 3,
        getEligible = function() return EventsObj:WaitForChild("Grading"):WaitForChild("GetGradableItems"):InvokeServer() end,
        getSlots    = function() return EventsObj:WaitForChild("Grading"):WaitForChild("GetSlotState"):InvokeServer() end,
        startWork   = function(slot, guid, src, vguid) return EventsObj:WaitForChild("Grading"):WaitForChild("StartGrading"):InvokeServer(slot, guid, src, vguid) end,
        claimWork   = function(slot) return EventsObj:WaitForChild("Grading"):WaitForChild("ClaimGradedItem"):InvokeServer(slot) end,
        unlockSlot  = function(slot) return EventsObj:WaitForChild("Grading"):WaitForChild("UnlockSlot"):InvokeServer(slot) end,
        speedUp     = function(slot) return EventsObj:WaitForChild("Grading"):WaitForChild("SpeedUpGrading"):InvokeServer(slot) end,
        collect     = function(slot) return EventsObj:WaitForChild("Grading"):WaitForChild("CollectGrade"):InvokeServer(slot) end,
    },
    Locksmith = {
        title = "🔑 Locksmith Desk", itemLabel = "Select a Safe/Chest", itemEmpty = "No locked chests or safes", maxSlots = 3,
        getEligible = function()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            if root then root.CFrame = CFrame.new(395, 1726, -16.6) end
            local ok, res = pcall(function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("GetLockableItems"):InvokeServer() end)
            if root and oldCF then root.CFrame = oldCF end
            if ok then return res else error(res) end
        end,
        getSlots    = function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("GetSlotState"):InvokeServer() end,
        startWork   = function(slot, guid, src, vguid)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            if root then root.CFrame = CFrame.new(395, 1726, -16.6) end
            local ok, res = pcall(function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("StartLocksmith"):InvokeServer(slot, guid, src, vguid) end)
            if root and oldCF then root.CFrame = oldCF end
            if ok then return res else error(res) end
        end,
        claimWork   = function(slot)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            if root then root.CFrame = CFrame.new(395, 1726, -16.6) end
            local ok, res = pcall(function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("ClaimItem"):InvokeServer(slot) end)
            if root and oldCF then root.CFrame = oldCF end
            if ok then return res else error(res) end
        end,
        unlockSlot  = function(slot) return EventsObj:WaitForChild("Locksmith"):WaitForChild("UnlockSlot"):InvokeServer(slot) end,
        speedUp     = function(slot)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            if root then root.CFrame = CFrame.new(395, 1726, -16.6) end
            local ok, res = pcall(function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("SpeedUp"):InvokeServer(slot) end)
            if root and oldCF then root.CFrame = oldCF end
            if ok then return res else error(res) end
        end,
        openSafe    = function(slot)
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            if root then root.CFrame = CFrame.new(395, 1726, -16.6) end
            local ok, res = pcall(function() return EventsObj:WaitForChild("Locksmith"):WaitForChild("OpenSafe"):InvokeServer(slot) end)
            if root and oldCF then root.CFrame = oldCF end
            if ok then return res else error(res) end
        end,
    }
}

local function renderWorkshop(shopKey)
    for _, c in ipairs(ScrollTab:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
    activeTimersList = {}
    
    local cfg = SHOPS[shopKey]
    if not cfg then return end
    
    local SplitContainer = make("Frame", { Size = UDim2.new(1, 0, 0, 340), BackgroundTransparency = 1, }, ScrollTab)
    local LeftCol = make("Frame", { Size = UDim2.new(0.44, -6, 1, 0), BackgroundColor3 = C.panel, }, SplitContainer)
    corner(8, LeftCol); stroke(1.2, C.border, LeftCol); pad(6, LeftCol)
    
    make("TextLabel", { Text = cfg.itemLabel, TextSize = 10, TextColor3 = C.accent, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, }, LeftCol)
    
    local ItemScroll = make("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -22), Position = UDim2.new(0, 0, 0, 22), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, }, LeftCol)
    list(nil, 4, ItemScroll)
    
    local RightCol = make("Frame", { Size = UDim2.new(0.56, -6, 1, 0), Position = UDim2.new(0.44, 6, 0, 0), BackgroundColor3 = C.panel, }, SplitContainer)
    corner(8, RightCol); stroke(1.2, C.border, RightCol); pad(6, RightCol)
    
    make("TextLabel", { Text = "🛠️ Workshop Slots", TextSize = 10, TextColor3 = C.purple, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, }, RightCol)
    
    local SlotsScroll = make("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -22), Position = UDim2.new(0, 0, 0, 22), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, }, RightCol)
    list(nil, 6, SlotsScroll)
    
    local function refreshWorkshopView()
        if activeTab == shopKey:lower() or (activeTab == "grade" and shopKey == "Grading") then renderWorkshop(shopKey) end
    end
    
    task.spawn(function()
        local ok, res = pcall(cfg.getEligible)
        if not ok or not res or not res.items then make("TextLabel", { Text = "Failed to load inventory items.", TextSize = 9, TextColor3 = C.red, Font = Enum.Font.Gotham, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), }, ItemScroll); return end
        local items = res.items
        if #items == 0 then make("TextLabel", { Text = cfg.itemEmpty, TextSize = 9, TextColor3 = C.textMuted, Font = Enum.Font.Gotham, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 80), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, }, ItemScroll); return end
        
        local selectedStroke = nil
        for idx, item in ipairs(items) do
            local data = item.data
            local rawName = data.ItemId or "Unknown"
            local rar = data.Rarity or "Common"
            local mut = data.Mutator or "None"
            local grade = data.Grade or 0
            local cond = data.Condition or 100
            local realName, calcVal = calcItemValue(rawName, rar, mut, grade, cond)
            
            local card = make("TextButton", { Size = UDim2.new(1, -6, 0, 36), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, LayoutOrder = idx, }, ItemScroll)
            corner(6, card); stroke(1, C.border, card)
            
            make("TextLabel", { Text = realName, TextSize = 9, TextColor3 = C.text, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(0.65, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, }, card)
            make("TextLabel", { Text = rar .. (mut ~= "None" and (" • " .. mut) or ""), TextSize = 8, TextColor3 = RARITY_COL[rar] or C.textMuted, Font = Enum.Font.GothamMedium, BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 16), Size = UDim2.new(0.65, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, }, card)
            make("TextLabel", { Text = fm(calcVal), TextSize = 10, TextColor3 = C.gold, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0.65, 0, 0, 0), Size = UDim2.new(0.35, -6, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, }, card)
            
            if selectedItems[shopKey] and selectedItems[shopKey].guid == item.guid then card.UIStroke.Color = C.purple; card.UIStroke.Thickness = 1.5; selectedStroke = card.UIStroke end
            card.MouseButton1Click:Connect(function()
                if selectedStroke then selectedStroke.Color = C.border; selectedStroke.Thickness = 1 end
                card.UIStroke.Color = C.purple; card.UIStroke.Thickness = 1.5; selectedStroke = card.UIStroke; selectedItems[shopKey] = item
                statusLbl.Text = "👉 Selected item: " .. realName; statusLbl.TextColor3 = C.accent
            end)
        end
    end)
    
    task.spawn(function()
        local ok, res = pcall(cfg.getSlots)
        if not ok or not res then make("TextLabel", { Text = "Failed to load shop slots data.", TextSize = 9, TextColor3 = C.red, Font = Enum.Font.Gotham, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), }, SlotsScroll); return end
        
        local unlockedCount = res.unlockedCount or 1
        local slots = res.slots or {}
        
        for slotIndex = 1, cfg.maxSlots do
            local slotData = slots[tostring(slotIndex)]
            local card = make("Frame", { Size = UDim2.new(1, -6, 0, 80), BackgroundColor3 = C.card, LayoutOrder = slotIndex, }, SlotsScroll)
            corner(8, card); stroke(1, C.border, card)
            make("TextLabel", { Text = "Slot #" .. slotIndex, TextSize = 8, TextColor3 = C.textMuted, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 6), Size = UDim2.new(0.5, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, }, card)
            
            if slotIndex > unlockedCount then
                make("TextLabel", { Text = "🔒 LOCKED", TextSize = 10, TextColor3 = C.red, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(0.5, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, }, card)
                local unlockBtn = make("TextButton", { Text = "🔑 Unlock", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.gold, BackgroundColor3 = Color3.fromRGB(35, 25, 15), Position = UDim2.new(0.65, 0, 0.5, -11), Size = UDim2.new(0.35, -8, 0, 22), AutoButtonColor = false, }, card)
                corner(5, unlockBtn); stroke(1.2, C.gold:Lerp(Color3.fromRGB(0,0,0), 0.5), unlockBtn)
                unlockBtn.MouseButton1Click:Connect(function() task.spawn(function() pcall(function() if cfg.unlockSlot(slotIndex) then statusLbl.Text = "🔓 Unlocked Slot #" .. slotIndex; statusLbl.TextColor3 = C.green; refreshWorkshopView() else statusLbl.Text = "❌ Unlock slot failed."; statusLbl.TextColor3 = C.red end end) end) end)
            elseif not slotData then
                make("TextLabel", { Text = "EMPTY", TextSize = 10, TextColor3 = C.textMuted, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 24), Size = UDim2.new(0.5, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, }, card)
                local startBtn = make("TextButton", { Text = "⚡ Start", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.green, BackgroundColor3 = Color3.fromRGB(15, 30, 20), Position = UDim2.new(0.65, 0, 0.5, -11), Size = UDim2.new(0.35, -8, 0, 22), AutoButtonColor = false, }, card)
                corner(5, startBtn); stroke(1.2, C.green:Lerp(Color3.fromRGB(0,0,0), 0.5), startBtn)
                startBtn.MouseButton1Click:Connect(function()
                    local chosen = selectedItems[shopKey]
                    if not chosen then statusLbl.Text = "❌ Select an eligible item on the left first!"; statusLbl.TextColor3 = C.red; return end
                    startBtn.Text = "Invoking..."
                    task.spawn(function() pcall(function() local res = cfg.startWork(slotIndex, chosen.guid, chosen.source, chosen.vehicleGUID); if res and res.success then statusLbl.Text = "✅ Process started successfully!"; statusLbl.TextColor3 = C.green; selectedItems[shopKey] = nil; refreshWorkshopView() else statusLbl.Text = "❌ Failed: " .. (res and res.error or "unknown"); statusLbl.TextColor3 = C.red; startBtn.Text = "⚡ Start" end end) end)
                end)
            else
                local itemEntry = slotData.Item or slotData.ItemData or slotData.Entry or {}
                local rawItemName = itemEntry.ItemName or itemEntry.Name or "Processing Item"
                local realItemName, _ = calcItemValue(rawItemName, "Common", "None", 0, 100)
                
                make("TextLabel", { Text = realItemName, TextSize = 10, TextColor3 = C.text, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(0.6, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, }, card)
                
                local elapsed = workspace:GetServerTimeNow() - (slotData.StartTime or workspace:GetServerTimeNow())
                local remaining = (slotData.Duration or 0) - elapsed
                
                if remaining > 0 and not slotData.Repaired and not slotData.Washed and not slotData.Grade and not slotData.Opened then
                    local tBarBg = make("Frame", { Size = UDim2.new(0.55, 0, 0, 4), Position = UDim2.new(0, 8, 0, 48), BackgroundColor3 = Color3.fromRGB(15, 20, 32), BorderSizePixel = 0, }, card); corner(2, tBarBg)
                    local tBarFill = make("Frame", { Size = UDim2.fromScale(math.clamp(elapsed / (slotData.Duration or 1), 0, 1), 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, }, tBarBg); corner(2, tBarFill)
                    local timeLbl = make("TextLabel", { Text = "0:00", TextSize = 11, TextColor3 = C.gold, Font = Enum.Font.GothamBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 56), Size = UDim2.new(0.55, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, }, card)
                    
                    table.insert(activeTimersList, { bar = tBarFill, lbl = timeLbl, startTime = slotData.StartTime or workspace:GetServerTimeNow(), duration = slotData.Duration or 30, card = card, onComplete = refreshWorkshopView })
                    
                    local skipBtn = make("TextButton", { Text = "⚡ Skip", TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = C.purple, BackgroundColor3 = Color3.fromRGB(28, 16, 40), Position = UDim2.new(0.65, 0, 0.5, -11), Size = UDim2.new(0.35, -8, 0, 22), AutoButtonColor = false, }, card)
                    corner(5, skipBtn); stroke(1.2, C.purple:Lerp(Color3.fromRGB(0,0,0), 0.5), skipBtn)
                    skipBtn.MouseButton1Click:Connect(function() task.spawn(function() pcall(function() cfg.speedUp(slotIndex) end); refreshWorkshopView() end) end)
                else
                    local btnText, btnColor, btnBg, action = "Claim", C.green, Color3.fromRGB(15, 30, 20), "claim"
                    if shopKey == "Wash" and not slotData.Washed then btnText, btnColor, btnBg, action = "🛁 Collect Wash", C.purple, Color3.fromRGB(25, 15, 35), "collectWash"
                    elseif shopKey == "Repair" and not slotData.Repaired then btnText, btnColor, btnBg, action = "🔧 Collect Repair", C.purple, Color3.fromRGB(25, 15, 35), "collectRepair"
                    elseif shopKey == "Grading" and not slotData.Grade then btnText, btnColor, btnBg, action = "🔬 Roll Grade", C.purple, Color3.fromRGB(25, 15, 35), "rollGrade"
                    elseif shopKey == "Locksmith" and not slotData.Opened then btnText, btnColor, btnBg, action = "🔓 Open Safe", C.orange, Color3.fromRGB(35, 20, 15), "openSafe" end
                    
                    if slotData.Grade then realItemName = realItemName .. " (Grade: " .. tostring(slotData.Grade) .. ")" elseif slotData.CleanMutation then realItemName = realItemName .. " (" .. tostring(slotData.CleanMutation) .. ")" end
                    
                    local actionBtn = make("TextButton", { Text = btnText, TextSize = 9, Font = Enum.Font.GothamBold, TextColor3 = btnColor, BackgroundColor3 = btnBg, Position = UDim2.new(0.65, 0, 0.5, -11), Size = UDim2.new(0.35, -8, 0, 22), AutoButtonColor = false, }, card)
                    corner(5, actionBtn); stroke(1.2, btnColor:Lerp(Color3.fromRGB(0,0,0), 0.5), actionBtn)
                    actionBtn.MouseButton1Click:Connect(function()
                        actionBtn.Text = "Invoking..."
                        task.spawn(function()
                            local success, err = pcall(function()
                                if action == "claim" then
                                    cfg.claimWork(slotIndex)
                                    statusLbl.Text = "✅ Claimed!"
                                    statusLbl.TextColor3 = C.green
                                elseif action == "collectWash" then
                                    EventsObj:WaitForChild("Wash"):WaitForChild("CollectWash"):InvokeServer(slotIndex)
                                    statusLbl.Text = "🛁 Wash collected!"
                                    statusLbl.TextColor3 = C.green
                                elseif action == "collectRepair" then
                                    EventsObj:WaitForChild("Repair"):WaitForChild("CollectRepair"):InvokeServer(slotIndex)
                                    statusLbl.Text = "🔧 Repair collected!"
                                    statusLbl.TextColor3 = C.green
                                elseif action == "rollGrade" then
                                    cfg.collect(slotIndex)
                                    statusLbl.Text = "🔬 Grade completed!"
                                    statusLbl.TextColor3 = C.purple
                                elseif action == "openSafe" then
                                    cfg.openSafe(slotIndex)
                                    task.wait(0.3)
                                    cfg.claimWork(slotIndex)
                                    statusLbl.Text = "🔓 Safe opened & claimed!"
                                    statusLbl.TextColor3 = C.green
                                end
                            end)
                            if not success then
                                statusLbl.Text = "❌ Error: " .. tostring(err or "Unknown")
                                statusLbl.TextColor3 = C.red
                                actionBtn.Text = btnText
                            end
                            refreshWorkshopView()
                        end)
                    end)
                end
            end
        end
    end)
end

table.insert(cleanUpSignals, RunService.Heartbeat:Connect(function()
    pcall(function()
        local now = workspace:GetServerTimeNow()
        for i = #activeTimersList, 1, -1 do
            local session = activeTimersList[i]
            local rem = (session.duration or 30) - (now - (session.startTime or now))
            if rem <= 0 then
                session.lbl.Text = "COMPLETED"; session.lbl.TextColor3 = C.green; session.bar.Size = UDim2.fromScale(1, 1)
                table.remove(activeTimersList, i); task.delay(0.5, session.onComplete)
            else
                session.bar.Size = UDim2.fromScale(math.clamp((now - session.startTime) / session.duration, 0, 1), 1)
                session.lbl.Text = string.format("Processing... %d:%02d", math.floor(rem / 60), math.floor(rem) % 60)
            end
        end
        

    end)
end))

function updateTabs()
    for _, c in ipairs(ScrollTab:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end
    for id, btn in pairs(tabButtons) do
        local active = (activeTab == id)
        tw(btn, 0.12, { TextColor3 = active and C.accent or C.textMuted, BackgroundColor3 = active and C.panel or C.card, })
        btn.UIStroke.Color = active and C.accent or C.border; btn.UIStroke.Thickness = active and 1.5 or 1
    end
    if activeTab == "lots" then renderLots(scanData) elseif activeTab == "wash" then renderWorkshop("Wash") elseif activeTab == "repair" then renderWorkshop("Repair") elseif activeTab == "grade" then renderWorkshop("Grading") elseif activeTab == "locksmith" then renderWorkshop("Locksmith") else renderLots(scanData) end
end

local scanning = false
doScan = function()
    if scanning then return end; scanning = true; ScanTxt.Text = "SCANNING"; tw(ScanDot, 0.5, {BackgroundColor3=C.gold})
    task.spawn(function()
        local ok, result = pcall(scanAllAreas); scanning = false
        if ok and result then scanData = result; if statusLbl then statusLbl.Text = "🟢 Scan succeeded"; statusLbl.TextColor3 = C.green end; if activeTab == "lots" then renderLots(scanData) end; applyESP() else if statusLbl then statusLbl.Text = "❌ Scan failed"; statusLbl.TextColor3 = C.red end end
        ScanTxt.Text = "LIVE SCAN"; tw(ScanDot, 0.3, {BackgroundColor3=C.green})
    end)
end

onSortChange = function() if activeTab == "lots" and #scanData > 0 then renderLots(scanData) end end
RefreshBtn.MouseButton1Click:Connect(function() doScan(); if activeTab ~= "lots" then updateTabs() end end)
doScan(); updateTabs()

-- Hook Auction State Events
local StartAuctionEvent = AuctionEvents and AuctionEvents:FindFirstChild("StartAuction")
if StartAuctionEvent then
    table.insert(cleanUpSignals, StartAuctionEvent.OnClientEvent:Connect(function(isOpen, data)
        AB.auctionOpen = isOpen
        if isOpen then
            AB.bidsThisRound = 0
            AB.currentBid = 0
            local lotName = data and data.LotName or "Unknown"
            abLog("🔔 Started: " .. tostring(lotName), C.accent)
            if AB.enabled then startBidLoop() end
        else
            abLog("🔔 Auction closed", C.textMuted)
            stopBidLoop()
        end
        if activeTab == "lots" then
            renderLots(scanData)
        end
    end))
end

if UpdateWinningBidEvent then
    table.insert(cleanUpSignals, UpdateWinningBidEvent.OnClientEvent:Connect(function(amount, winnerId)
        AB.currentBid = tonumber(amount) or AB.currentBid
        local isUs = (winnerId == LocalPlayer.UserId)
        if isUs then
            abLog("👑 WE'RE WINNING: $"..AB.currentBid, C.gold)
        end
    end))
end

-- ═════════════════════════════════════════════════════
-- RESIZE HANDLE & TOUCH DRAG SUPPORT (SCALED)
-- ═════════════════════════════════════════════════════
local ResizeHandle = make("ImageLabel", { Name = "ResizeHandle", Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1, Image = "rbxassetid://6031094067", ImageColor3 = C.textMuted, ZIndex = 10, Active = true, }, Win)

local dragActive, dragStart, startPos = false, nil, nil
local resizeActive, resizeStart, startSize = false, nil, nil

Hdr.InputBegan:Connect(function(inp) if isTouchOrClick(inp) then dragActive = true; dragStart = inp.Position; startPos = Win.Position end end)
ResizeHandle.InputBegan:Connect(function(inp) if isTouchOrClick(inp) then resizeActive = true; resizeStart = inp.Position; startSize = Win.Size; inp.Processed = true end end)

table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        local currentScale = uiScale.Scale
        if dragActive and dragStart and startPos then
            local d = inp.Position - dragStart
            Win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (d.X / currentScale), startPos.Y.Scale, startPos.Y.Offset + (d.Y / currentScale))
        elseif resizeActive and resizeStart and startSize then
            local d = inp.Position - resizeStart
            local targetW = math.clamp(startSize.X.Offset + (d.X / currentScale), 480, 1200)
            local targetH = math.clamp(startSize.Y.Offset + (d.Y / currentScale), 280, 800)
            Win.Size = UDim2.new(0, targetW, 0, targetH)
            Sidebar.Size = UDim2.new(0, 300, 1, -67)
            ContentPanel.Size = UDim2.new(1, -320, 1, -67)
        end
    end
end))

table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp) if isTouchOrClick(inp) then dragActive = false; resizeActive = false end end))

-- Opening animation
Win.BackgroundTransparency = 1
task.wait(0.05)
tw(Win, 0.4, {BackgroundTransparency=0})

_G.AHScanner_CleanUp = function()
    -- Stop autobid
    if AB then
        AB.enabled = false
        AB.auctionOpen = false
        stopBidLoop()
    end
    -- Disconnect all events
    for _, conn in ipairs(cleanUpSignals) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(cleanUpSignals)
    -- Destroy GUI
    pcall(function()
        for _, v in ipairs(TargetGui:GetChildren()) do
            if v.Name == "AHScanner" then v:Destroy() end
        end
    end)
end

print("✅ [LiveAuctionScanner v10.2] Scaled Perfectly for Delta Mobile!")
