

--[[
    ╔══════════════════════════════════════════════════════════════════════╗
    ║  NexWorks — STORAGE HUNTERS OPEN WORLD                               ║
    ╚══════════════════════════════════════════════════════════════════════╝
--]]
-- Configuration for webhooks (Disabled)
local BUG_REPORT_WEBHOOK = ""
local EXECUTION_WEBHOOK = ""

if not game:IsLoaded() then game.Loaded:Wait() end


-- ═════════════════════════════════════════════════════
-- EXECUTOR DETECTOR & COMPATIBILITY CHECK
-- ═════════════════════════════════════════════════════
local execName = "Unknown"
pcall(function()
    if identifyexecutor then
        local res = identifyexecutor()
        if res and res ~= "" then execName = tostring(res) end
    end
end)
local execLower = string.lower(execName)

local lowLevelExecutors = {"xeno", "solara", "celery", "incognito", "lunar", "zorara", "awp", "jjsploit", "valyse", "nihon", "swift", "apple", "macsploit"}
local isKnownLowLevel = false
for _, v in ipairs(lowLevelExecutors) do
    if string.find(execLower, v) then
        isKnownLowLevel = true
        break
    end
end
-- ═════════════════════════════════════════════════════
-- SERVICES
-- ═════════════════════════════════════════════════════
local isSyncingToggles = false
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemsData = nil
local LocalPlayer = Players.LocalPlayer
local lp = LocalPlayer

-- Global Cached Services and States
_G.AHUserInventoryCache = _G.AHUserInventoryCache or {}
task.spawn(function()
    while true do
        pcall(function()
            local events = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
            local getInv = events and events:FindFirstChild("Inventory") and events.Inventory:FindFirstChild("GetPlayerInventory")
            if getInv then
                local res = getInv:InvokeServer()
                if res then
                    _G.AHUserInventoryCache = res
                end
            end
        end)
        task.wait(4)
    end
end)
local currentKeybind = Enum.KeyCode.RightShift
-- DELTA MOBILE BYPASS: Safely get the secure UI container
local TargetGui
pcall(function() TargetGui = gethui and gethui() end)
if not TargetGui then
    local coreGui
    local success = pcall(function() coreGui = game:GetService("CoreGui") end)
    if success and coreGui then
        -- Run a capability check to see if we can parent to CoreGui
        local testFrame = Instance.new("Frame")
        local parentSuccess = pcall(function() testFrame.Parent = coreGui end)
        pcall(function() testFrame:Destroy() end)
        if parentSuccess then
            TargetGui = coreGui
        end
    end
end
if not TargetGui then TargetGui = LocalPlayer:WaitForChild("PlayerGui") end
local showWorkshopPopup, COLORS

_G.gConfig = _G.gConfig or {}
local gConfig = _G.gConfig

-- [Shield] ANTI-ARREST GODMODE HOOK
local pMouse = nil
pcall(function() pMouse = LocalPlayer:GetMouse() end)

pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and not checkcaller() then
                local sName = tostring(self.Name):lower()
                if sName == "policechase" then
                    local arg1 = ...
                    if arg1 == "Arrest" then return end
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)
-- CLEANUP PREVIOUS RUN
pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(true) end)
if _G.AHAutoPlaceThread then pcall(task.cancel, _G.AHAutoPlaceThread); _G.AHAutoPlaceThread = nil end
if _G.AHCollectorThread then pcall(task.cancel, _G.AHCollectorThread); _G.AHCollectorThread = nil end
if _G.AuctionRush_Thread then pcall(task.cancel, _G.AuctionRush_Thread); _G.AuctionRush_Thread = nil end
if _G.CameraWatchdogThread then pcall(task.cancel, _G.CameraWatchdogThread); _G.CameraWatchdogThread = nil end

_G.AHScanner_RunID = (_G.AHScanner_RunID or 0) + 1
local myRunID = _G.AHScanner_RunID
if _G.AHScanner_CleanUp then
    pcall(_G.AHScanner_CleanUp)
end

-- Persistent Camera Watchdog Guard: Reverts rogue Scriptable camera states
_G.CameraWatchdogThread = task.spawn(function()
    while true do
        task.wait(0.3)
        if _G.AHScanner_RunID ~= myRunID then break end
        pcall(function()
            local cam = workspace.CurrentCamera
            if not cam then return end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hum then return end

            local isAuctionCinematic = AB and (AB.auctionOpen or AB.startingAuction)
            if not isAuctionCinematic and cam.CameraType == Enum.CameraType.Scriptable then
                cam.CameraType = Enum.CameraType.Custom
                cam.CameraSubject = hum
            end
        end)
    end
end)
-- Teleport helper function
local function fastTP(cf)
    if _G.questTpInProgress then return end
    local char = game:GetService("Players").LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        if typeof(cf) == "Vector3" then
            cf = CFrame.new(cf)
        end
        root.CFrame = cf
    end
end

local function safeTP(cf, includeVehicle)
    local ok = pcall(function()
        local char = game:GetService("Players").LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        
        local rawPos = typeof(cf) == "Vector3" and cf or cf.Position
        
        -- Check if player is driving a vehicle AND includeVehicle is requested
        local vehicle = nil
        local seat = hum.SeatPart
        if includeVehicle and seat then
            local v = seat:FindFirstAncestorWhichIsA("Model")
            if v and (v:GetAttribute("VehicleGUID") or v:GetAttribute("OwnerUserId") == game:GetService("Players").LocalPlayer.UserId or (getMyVehicle and v == getMyVehicle())) then
                vehicle = v
            end
        end
        
        -- Raycast from 40 studs above down to detect true ground surface (never clip into terrain!)
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { char, vehicle }
        rayParams.RespectCanCollide = true
        
        -- Request streaming for target position so terrain & models load before placement
        pcall(function()
            game:GetService("Players").LocalPlayer:RequestStreamAroundAsync(rawPos)
        end)
        
        -- Raycast from 120 studs above down to detect true ground surface (never clip into terrain!)
        local rayHit = workspace:Raycast(rawPos + Vector3.new(0, 120, 0), Vector3.new(0, -250, 0), rayParams)
        local groundY = rayHit and rayHit.Position.Y or rawPos.Y
        -- Elevate safely above ground so legs never clip into terrain
        local finalY = groundY + (vehicle and 6.0 or 4.5)
        local targetPos = Vector3.new(rawPos.X, finalY, rawPos.Z)
        local targetCF = CFrame.new(targetPos)
        
        -- Create a temporary platform directly under feet (groundY - 0.2) to prevent falling through unstreamed terrain
        local platform = Instance.new("Part")
        platform.Size = Vector3.new(24, 1.0, 24)
        platform.Anchored = true
        platform.CanCollide = true
        platform.Transparency = 1
        platform.Position = Vector3.new(targetPos.X, groundY - 0.2, targetPos.Z)
        platform.Parent = workspace
        
        if vehicle and seat then
            -- Teleport vehicle WITH the player firmly seated in it (DO NOT unseat, so player can drive!)
            vehicle:PivotTo(targetCF)
            for _, part in ipairs(vehicle:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    part.AssemblyAngularVelocity = Vector3.zero
                end
            end
            if not hum.Sit or hum.SeatPart ~= seat then
                pcall(function() seat:Sit(hum) end)
            end
        else
            -- Teleport the PLAYER character!
            if hum.SeatPart then
                hum.Sit = false
                task.wait(0.03)
            end
            
            -- Reset physics state and recover from ragdoll / falling down
            if hum.PlatformStand then hum.PlatformStand = false end
            hum.Sit = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.CFrame = targetCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            
            task.delay(0.1, function()
                if hum and hum.Health > 0 then
                    hum.PlatformStand = false
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end
        
        task.delay(4, function()
            pcall(function() platform:Destroy() end)
        end)
    end)
    return ok
end
_G.safeTP = safeTP


-- Global Cleanup of previous script instances to prevent dead coroutine errors
if _G.AHCleanUpSignals then
    for _, sig in ipairs(_G.AHCleanUpSignals) do
        pcall(function() sig:Disconnect() end)
    end
end
pcall(function()
    if getconnections and UserInputService and UserInputService.InputEnded then
        for _, c in ipairs(getconnections(UserInputService.InputEnded)) do
            if c.Disconnect then pcall(function() c:Disconnect() end) end
        end
    end
end)
_G.AHCleanUpSignals = {}
local cleanUpSignals = _G.AHCleanUpSignals

-- TOUCH SUPPORT HELPER
local function isTouchOrClick(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end
local statusLbl = nil
local asToggleBtn = nil
local acToggleBtn = nil
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
local MUTATOR_MULT = {
    None = 1, Silver = 2, Gold = 4, Corrupted = 6, Diamond = 8, Gem = 12, Rainbow = 20,
    Dusty = 0.9, ["Saloon Sparkle"] = 2.1, Tumbleweed = 3.5, Gunsmoked = 11.0, Goldrush = 25.0,
    -- [Train] Cargo Train Mutators
    ["Polished Brass"] = 3.5, Steam = 10.0, Clockwork = 25.0,
    -- [Mine] The Mines Mutators
    Titanium = 7.0, Morganite = 9.0, Citrine = 11.0, Lapis = 13.0, Carnelian = 15.0,
    Aquamarine = 17.0, Amethyst = 20.0, Emerald = 40.0, Sapphire = 60.0, Ruby = 110.0,
    -- [Military] Military Base & Carnival Mutators
    Bulletproof = 3.0, Fortified = 4.0, Jestered = 5.0, Vaulted = 7.0, Camo = 16.0, Warforged = 30.0, Encrypted = 35.0
}
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
    ["Beach Hut Garage"]        = { name="Beach Hut",             tier=8, area="Lucky Beach", mascot="Sam",   minNW=2500000, minBid=300, minProfit=-200,  maxProfit=1500, items=6, entMin=300,  entMax=300,  col=Color3.fromRGB(0,200,220)  },
    ["Surf Shack Garage"]       = { name="Surf Shack",            tier=9, area="Lucky Beach", mascot="Sam",   minNW=5000000, minBid=450, minProfit=-300,  maxProfit=2000, items=6, entMin=450,  entMax=450,  col=Color3.fromRGB(0,180,255)  },
    ["Boat House Garage"]        = { name="Boat House",            tier=10, area="Lucky Beach", mascot="Sam",   minNW=10000000,minBid=1000,minProfit=-1000, maxProfit=10000,items=6, entMin=1000, entMax=1000, col=Color3.fromRGB(0,100,255)  },
    ["Power Plant Tier 1 Garage"] = { name="Power Plant T1",       tier=11, area="Power Plant", mascot="Mad Scientist", minNW=7500,    minBid=100, minProfit=-100,  maxProfit=1000, items=6, entMin=150,  entMax=150,  col=Color3.fromRGB(200,255,100) },
    ["Power Plant Tier 2 Garage"] = { name="Power Plant T2",       tier=12, area="Power Plant", mascot="Mad Scientist", minNW=65000,   minBid=200, minProfit=-200,  maxProfit=2000, items=6, entMin=250,  entMax=250,  col=Color3.fromRGB(150,255,100) },
    ["Power Plant Tier 3 Garage"] = { name="Power Plant T3",       tier=13, area="Power Plant", mascot="Mad Scientist", minNW=600000,  minBid=300, minProfit=-300,  maxProfit=3000, items=6, entMin=350,  entMax=350,  col=Color3.fromRGB(100,255,100) },
    ["Power Plant Tier 4 Garage"] = { name="Power Plant T4",       tier=14, area="Power Plant", mascot="Mad Scientist", minNW=3500000, minBid=500, minProfit=-500,  maxProfit=5000, items=6, entMin=500,  entMax=500,  col=Color3.fromRGB(50,255,100)  },
    ["Wooden Cargo Container"]    = { name="Wooden Container",     tier=15, area="Cargo Ship",  mascot="Engineer", minNW=7000,    minBid=100, minProfit=-100,  maxProfit=1000, items=6, entMin=150,  entMax=150,  col=Color3.fromRGB(150,110,80)  },
    ["Cargo Container"]           = { name="Cargo Container",      tier=16, area="Cargo Ship",  mascot="Engineer", minNW=65000,   minBid=200, minProfit=-200,  maxProfit=2000, items=6, entMin=250,  entMax=250,  col=Color3.fromRGB(200,80,80)   },
    ["Steel Cargo Container"]     = { name="Steel Container",      tier=17, area="Cargo Ship",  mascot="Engineer", minNW=275000,  minBid=300, minProfit=-300,  maxProfit=3000, items=6, entMin=350,  entMax=350,  col=Color3.fromRGB(150,150,150) },
    ["Luxury Cargo Container"]    = { name="Luxury Container",     tier=18, area="Cargo Ship",  mascot="Engineer", minNW=2000000, minBid=500, minProfit=-500,  maxProfit=5000, items=6, entMin=500,  entMax=500,  col=Color3.fromRGB(220,180,60)  },
    ["High End Apartment"]        = { name="High End Apartment",   tier=23, area="Business Bay", mascot="Michael", minNW=17500000, minBid=1500, minProfit=-1500, maxProfit=15000, items=6, entMin=1500, entMax=1500, col=Color3.fromRGB(100,180,255) },
    ["Luxury Hotel"]              = { name="Luxury Hotel",         tier=24, area="Business Bay", mascot="Michael", minNW=25000000, minBid=2500, minProfit=-2500, maxProfit=25000, items=6, entMin=2500, entMax=2500, col=Color3.fromRGB(255,215,0)   },
    ["The Pointer"]               = { name="The Pointer",          tier=25, area="Business Bay", mascot="Michael", minNW=50000000, minBid=5000, minProfit=-5000, maxProfit=50000, items=6, entMin=500,  entMax=5000, col=Color3.fromRGB(220,100,255) },
    -- [Mine] The Mines Garages
    ["Prospector's Shack"]      = { name="Prospector's Shack",   tier=30, area="The Mines", mascot="Mining Supervisor", minNW=30000,    minBid=500,  minProfit=-500,  maxProfit=5000,  items=6, entMin=50,  entMax=50,  col=Color3.fromRGB(180, 140, 100) },
    ["Mine Bunker"]             = { name="Mine Bunker",          tier=31, area="The Mines", mascot="Mining Supervisor", minNW=100000,   minBid=1000, minProfit=-1000, maxProfit=10000, items=6, entMin=100, entMax=100, col=Color3.fromRGB(150, 120, 80) },
    ["Ore Hopper Depot"]        = { name="Ore Hopper Depot",     tier=32, area="The Mines", mascot="Mining Supervisor", minNW=500000,   minBid=2500, minProfit=-2500, maxProfit=25000, items=6, entMin=250, entMax=250, col=Color3.fromRGB(130, 100, 70) },
    ["Twin Drill Rig"]          = { name="Twin Drill Rig",       tier=33, area="The Mines", mascot="Mining Supervisor", minNW=2500000,  minBid=5000, minProfit=-5000, maxProfit=50000, items=6, entMin=500, entMax=500, col=Color3.fromRGB(110, 80,  60) },
    -- [Train] Cargo Train Garages
    ["Train Container 1"]       = { name="Train Container 1",    tier=34, area="Cargo Train", mascot="Conductor", minNW=550000,   minBid=1000, minProfit=-1000, maxProfit=10000, items=4, entMin=1,   entMax=1,   col=Color3.fromRGB(200, 160, 80),  event=true },
    ["Train Container 2"]       = { name="Train Container 2",    tier=35, area="Cargo Train", mascot="Conductor", minNW=3500000,  minBid=2500, minProfit=-2500, maxProfit=25000, items=4, entMin=1,   entMax=1,   col=Color3.fromRGB(210, 140, 60),  event=true },
    ["Train Container 3"]       = { name="Train Container 3",    tier=36, area="Cargo Train", mascot="Conductor", minNW=15000000, minBid=5000, minProfit=-5000, maxProfit=50000, items=4, entMin=1,   entMax=1,   col=Color3.fromRGB(220, 120, 40),  event=true },
    -- [Military] Military Base Garages
    ["Military Tent"]           = { name="Military Tent",        tier=40, area="Military Base", mascot="Soldier", minNW=80000000,  minBid=10000, minProfit=-10000, maxProfit=100000, items=6, entMin=1000, entMax=1000, col=Color3.fromRGB(150, 170, 90) },
    ["Barrack"]                 = { name="Barrack",              tier=41, area="Military Base", mascot="Soldier", minNW=125000000, minBid=15000, minProfit=-15000, maxProfit=150000, items=6, entMin=1300, entMax=1300, col=Color3.fromRGB(120, 140, 80) },
    ["Enforced Barrack"]        = { name="Enforced Barrack",     tier=42, area="Military Base", mascot="Soldier", minNW=200000000, minBid=25000, minProfit=-25000, maxProfit=250000, items=6, entMin=1700, entMax=1700, col=Color3.fromRGB(90, 110, 60) },
    ["Bunker Garage"]           = { name="Bunker Garage",        tier=43, area="Military Base", mascot="Soldier", minNW=400000000, minBid=50000, minProfit=-50000, maxProfit=500000, items=6, entMin=2200, entMax=2200, col=Color3.fromRGB(70, 90, 50), event=true },
    ["Camo Airdrop"]            = { name="Camo Airdrop",         tier=44, area="Military Base", mascot="Soldier", minNW=80000000,  minBid=20000, minProfit=-20000, maxProfit=200000, items=3, entMin=2000, entMax=2000, col=Color3.fromRGB(110, 116, 84), event=true },
    ["Train Container 4"]       = { name="Train Container 4",    tier=37, area="Cargo Train", mascot="Conductor", minNW=60000000, minBid=10000,minProfit=-10000,maxProfit=100000,items=4, entMin=1,   entMax=1,   col=Color3.fromRGB(240, 90,  30),  event=true },
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
    cardHover = Color3.fromRGB(27, 34, 54),
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
    mutRedacted = Color3.fromRGB(150, 160, 185),
    mutSeized   = Color3.fromRGB(255, 215, 0),
    mutDusty    = Color3.fromRGB(185, 146, 101),
    mutSaloonSparkle = Color3.fromRGB(224, 238, 103),
    mutTumbleweed = Color3.fromRGB(186, 163, 100),
    mutGunsmoked = Color3.fromRGB(155, 151, 150),
    mutGoldrush = Color3.fromRGB(255, 181, 61),
}
local TIER_COL = {[0]=C.textMuted,[1]=C.t1,[2]=C.t2,[3]=C.t3,[4]=C.t4,[5]=C.t5,[6]=C.t6,[7]=C.t7}
local MUT_COL  = { None=C.mutNone, Silver=C.mutSilver, Gold=C.mutGold, Corrupted=C.mutCorr,
                   Diamond=C.mutDia, Gem=C.mutGem, Rainbow=C.mutRainbow, Redacted=C.mutRedacted, Seized=C.mutSeized,
                   Dusty=C.mutDusty, ["Saloon Sparkle"]=C.mutSaloonSparkle, Tumbleweed=C.mutTumbleweed, Gunsmoked=C.mutGunsmoked, Goldrush=C.mutGoldrush }
local RARITY_COL = {
    Common=C.textMuted, Uncommon=C.green, Rare=C.accent,
    Epic=C.purple, Legendary=C.gold, Mythical=C.orange, Exclusive=C.red
}
-- ═════════════════════════════════════════════════════
-- GLOBAL CONFIGURATION FOR AUTO-FARM
-- -----------------------------------------------------
local HttpService = game:GetService("HttpService")
local configBaseFolder = "NexHub/StorageHunters"
local configSettingsFolder = "NexHub/StorageHunters/settings"
local autoloadFile = "NexHub/StorageHunters/settings/autoload.txt"

local currentProfileName = "default"

local function getAutoloadInfo()
    local name = "default"
    local enabled = true
    pcall(function()
        if isfile and isfile(autoloadFile) then
            local raw = readfile(autoloadFile)
            if raw then
                local trimmed = raw:match("^%s*(.-)%s*$")
                if trimmed and (trimmed:lower() == "none" or trimmed:lower() == "false" or trimmed == "") then
                    name = "default"
                    enabled = false
                elseif trimmed and trimmed ~= "" then
                    name = trimmed
                    enabled = true
                end
            end
        else
            name = "default"
            enabled = true
        end
    end)
    return name, enabled
end

local function setAutoloadInfo(name, enabled)
    pcall(function()
        if not isfolder("NexHub") then makefolder("NexHub") end
        if not isfolder(configBaseFolder) then makefolder(configBaseFolder) end
        if not isfolder(configSettingsFolder) then makefolder(configSettingsFolder) end
        if enabled and name and name ~= "" and name:lower() ~= "none" then
            writefile(autoloadFile, name)
        else
            writefile(autoloadFile, "none")
        end
    end)
end

_G.gConfig = _G.gConfig or {
    seizedGarageSniping = false,
    seizedAreas = { ["Business Bay"] = true, ["Lucky Beach"] = true, ["Shipyard"] = true, ["Power Plant"] = true },
    seizedGarages = {},
    autoBankHeist = false,
    heistEscapeLocation = "Plot",
    autoJailbreak = true,
    autoWarehouseOrders = false,
    targetOrderDifficulty = "Hard",
    autoBuyStorages = false,
    autoPlaceStoreItems = false,
    
    autoCollectWon = true,
    minPickupValue = 0,
    minAutoPlaceValue = 0,
    maxAutoPlaceValue = 0,
    autoPawnInventoryPercent = 100,
    autoPawnMaxItemValue = 0,
    autoPawnMinItemValue = 0,
    autoPawnFull = false,
    autoPawnRateEnabled = false,
    autoBuyArea = "Any Area",
    selectedGarages = nil,
    garages = GARAGE_CATALOG,
    excludedItems = {},
    autoUnloadThreshold = 80,
    autoBuyDrinks = false,
    autoConsumeDrinks = false,
    buyLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false },
    consumeLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false },
    autoAcceptQuests = false,
    autoClaimQuests = false,
    autoEngineerQuest = false,
    allowedQuestNpcs = {},
    disable3DRendering = false,
    capFPS15 = false,
    autoCollectMuseumGifts = false,
    autoClaimIndexRewards = false,
    autoClaimDiamondCharm = false,
    autoSwapGavelLoadout = false,
    mainGavelLoadout = 1,
    charmGavelLoadout = 2,
    lastDiamondCharmClaim = 0,
    autoCollectTimeCapsules = false,
    targetCapsuleMutators = {["Antique"] = true, ["Ancient"] = true, ["Timeless"] = true},
    walkSpeedEnabled = false,
    customWalkSpeed = 30,
    flightEnabled = false,
    flightSpeed = 50,
    }
gConfig = _G.gConfig
if gConfig.autoClaimDiamondCharm == nil then gConfig.autoClaimDiamondCharm = false end
if gConfig.autoSwapGavelLoadout == nil then gConfig.autoSwapGavelLoadout = false end
if gConfig.mainGavelLoadout == nil then gConfig.mainGavelLoadout = 1 end
if gConfig.charmGavelLoadout == nil then gConfig.charmGavelLoadout = 2 end
if gConfig.lastDiamondCharmClaim == nil then gConfig.lastDiamondCharmClaim = 0 end
if gConfig.quickWinAuction == nil then gConfig.quickWinAuction = false end
if gConfig.quickWinMinStartBid == nil then gConfig.quickWinMinStartBid = 0 end
if gConfig.seizedGarageSniping == nil then gConfig.seizedGarageSniping = false end
if not gConfig.seizedAreas then gConfig.seizedAreas = { ["Business Bay"] = true, ["Lucky Beach"] = true, ["Shipyard"] = true, ["Power Plant"] = true } end
if not gConfig.seizedGarages then gConfig.seizedGarages = {} end
if gConfig.autoBankHeist == nil then gConfig.autoBankHeist = false end
if gConfig.heistEscapeLocation == nil then gConfig.heistEscapeLocation = "Plot" end
if gConfig.autoJailbreak == nil then gConfig.autoJailbreak = true end
if gConfig.antiArrest == nil then gConfig.antiArrest = true end
if gConfig.autoResetAfterSeized == nil then gConfig.autoResetAfterSeized = false end
if gConfig.autoWarehouseOrders == nil then gConfig.autoWarehouseOrders = false end
if gConfig.targetOrderDifficulty == nil then gConfig.targetOrderDifficulty = "Hard" end
if gConfig.autoPlaceThreshold == nil then gConfig.autoPlaceThreshold = 80 end
if gConfig.mutePlacingSounds == nil then gConfig.mutePlacingSounds = false end
if gConfig.enablePlotPitStop == nil then gConfig.enablePlotPitStop = false end
if gConfig.targetExcludedMutators == nil then gConfig.targetExcludedMutators = {} end
if gConfig.protectQuestParts == nil then gConfig.protectQuestParts = true end
_G.protectQuestParts = gConfig.protectQuestParts

-- [Mine] The Mines Config Defaults
if gConfig.autoMineNodes == nil then gConfig.autoMineNodes = false end
if gConfig.miningTargetNode == nil then gConfig.miningTargetNode = "Auto" end
if gConfig.miningSwingDelay == nil then gConfig.miningSwingDelay = 0.28 end
if gConfig.autoBrewCauldron == nil then gConfig.autoBrewCauldron = false end
if gConfig.autoBuyMiningDrinks == nil then gConfig.autoBuyMiningDrinks = false end
if gConfig.buyMiningDrinks == nil or type(gConfig.buyMiningDrinks) ~= "table" then
    gConfig.buyMiningDrinks = { ["18"] = true, ["19"] = true }
end
if gConfig.autoUseMiningDrinks == nil then gConfig.autoUseMiningDrinks = false end
if gConfig.useMiningDrinks == nil or type(gConfig.useMiningDrinks) ~= "table" then
    gConfig.useMiningDrinks = { ["18"] = true, ["19"] = true }
end

if gConfig.auctionRush == nil then gConfig.auctionRush = true end
if gConfig.minUraniumWeightKg == nil then gConfig.minUraniumWeightKg = 0 end
if gConfig.continuousMiningDuringAuctions == nil then gConfig.continuousMiningDuringAuctions = true end

-- [Train] Cargo Train & Freight Config Defaults
if gConfig.autoCollectMissingFreight == nil then gConfig.autoCollectMissingFreight = false end
if gConfig.autoClaimDailyTickets == nil then gConfig.autoClaimDailyTickets = true end
if gConfig.autoHandInConductor == nil then gConfig.autoHandInConductor = false end

-- [Military] Military Base & Carnival QoL Defaults
if gConfig.tpOnNavigate == nil then gConfig.tpOnNavigate = false end
if gConfig.clickTpEnabled == nil then gConfig.clickTpEnabled = false end
if gConfig.alwaysCollectAirdrop == nil then gConfig.alwaysCollectAirdrop = true end
if gConfig.autoOpenBunker == nil then gConfig.autoOpenBunker = false end
if gConfig.autoRollCarnival == nil then gConfig.autoRollCarnival = false end
if gConfig.autoPlayCarnival == nil then gConfig.autoPlayCarnival = false end
if gConfig.carnivalTargetGame == nil then gConfig.carnivalTargetGame = "Token Drop" end
if gConfig.noNPCCollision == nil then gConfig.noNPCCollision = true end
if gConfig.showFloatingCollect == nil then gConfig.showFloatingCollect = false end
if gConfig.manualCollectDelay == nil then gConfig.manualCollectDelay = 15 end

_G.uiToggles = _G.uiToggles or {}
_G.uiUpdaters = _G.uiUpdaters or {}
_G.inputFlushers = _G.inputFlushers or {}
local isSyncingUI = false
local isLoadingConfig = false
local isSavingConfig = false

local function resetConfigToDefaults()
    local defaults = {
        quickWinAuction = false,
        quickWinMinStartBid = 0,
        seizedGarageSniping = false,
        seizedAreas = { ["Business Bay"] = true, ["Lucky Beach"] = true, ["Shipyard"] = true, ["Power Plant"] = true },
        seizedGarages = {},
        autoBankHeist = false,
        heistEscapeLocation = "Plot",
        autoJailbreak = true,
        antiArrest = true,
        autoResetAfterSeized = false,
        autoWarehouseOrders = false,
        targetOrderDifficulty = "Hard",
        autoBuyStorages = false,
        autoPlaceStoreItems = false,
        autoCollectWon = true,
        manualCollectDelay = 15,
        minPickupValue = 0,
        minAutoPlaceValue = 0,
        maxAutoPlaceValue = 0,
        autoPawnInventoryPercent = 100,
        autoPawnMaxItemValue = 0,
        autoPawnMinItemValue = 0,
        autoPawnFull = false,
        autoPawnRateEnabled = false,
        autoBuyArea = "Any Area",
        autoBuyAreas = { ["Any Area"] = true },
        afAutoBuyArea = "Any Area",
        afAutoBuyAreas = { ["Any Area"] = true },
        afAutoUnload = false,
        selectedGarages = {},
        afSelectedGarages = {},
        excludedItems = {},
        targetExcludedMutators = {},
        itemRules = {},
        itemLists = {
            Pickup = {
                items = {},
                categories = {},
                rarities = {},
                mutations = {},
                limitedItems = false,
                vaultItems = false,
            },
            Shelves = {
                items = {},
                vaultItems = false,
                limitedItems = false,
                eventExclusives = false,
                mutations = {},
                categories = {},
                rarities = {},
            },
            AutoSell = {
                items = {},
                vaultItems = false,
                energyDrinks = false,
                eventExclusives = false,
                limitedItems = false,
                mutations = {},
                categories = {},
                rarities = {},
            },
            Grading = {
                rarities = {},
                energyDrinks = false,
            },
            Auction = {
                mutations = {},
                items = {},
                rarities = {},
            },
        },
        autoUnloadThreshold = 80,
        autoPlaceThreshold = 80,
        pickupDelay = 0.65,
        autoBuyDrinks = false,
        autoConsumeDrinks = false,
        buyLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false },
        consumeLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false },
        autoBuyMiningDrinks = false,
        buyMiningDrinks = { ["18"] = true, ["19"] = true },
        autoUseMiningDrinks = false,
        useMiningDrinks = { ["18"] = true, ["19"] = true },
        autoMineNodes = false,
        miningTargetNode = "Auto",
        tpOnNavigate = false,
        clickTpEnabled = false,
        alwaysCollectAirdrop = true,
        autoOpenBunker = false,
        autoRollCarnival = false,
        autoPlayCarnival = false,
        carnivalTargetGame = "Token Drop",
        autoAcceptQuests = false,
        autoClaimQuests = false,
        autoEngineerQuest = false,
        protectQuestParts = true,
        allowedQuestNpcs = {},
        disable3DRendering = false,
        capFPS15 = false,
        autoCollectMuseumGifts = false,
        autoClaimIndexRewards = false,
        autoClaimDiamondCharm = false,
        autoSwapGavelLoadout = false,
        mainGavelLoadout = 1,
        charmGavelLoadout = 2,
        lastDiamondCharmClaim = 0,
        autoCollectTimeCapsules = false,
        targetCapsuleMutators = {["Antique"] = true, ["Ancient"] = true, ["Timeless"] = true},
        walkSpeedEnabled = false,
        customWalkSpeed = 30,
        flightEnabled = false,
        flightSpeed = 50,
        mutePlacingSounds = false,
        enablePlotPitStop = false,
        autoBidEnabled = false,
        autoBidSpeed = 0.3,
        minStartBid = 0,
        targetPawnRate = 100,
        targetItemsList = {},
        disableGameNotifications = false,
        autoLockpick = false,
        autoWash = false,
        seatedAutofarm = false,
        targetItemOverrideBid = true,
        targetScannerOnly = false,
    }
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            gConfig[k] = {}
            for subK, subV in pairs(v) do gConfig[k][subK] = subV end
        else
            gConfig[k] = v
        end
    end
end

local function saveConfig(customProfile)
    if isSyncingUI or isLoadingConfig or isSavingConfig then return true end
    isSavingConfig = true
    if _G.flushInputValues then
        pcall(_G.flushInputValues)
    end
    local function deepCopyTable(orig)
        if type(orig) ~= "table" then return orig end
        local copy = {}
        for k, v in pairs(orig) do
            if type(v) == "table" then
                copy[k] = deepCopyTable(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
    local profile = customProfile or currentProfileName or "default"
    local success, err = pcall(function()
        if not isfolder("NexHub") then makefolder("NexHub") end
        if not isfolder(configBaseFolder) then makefolder(configBaseFolder) end
        if not isfolder(configSettingsFolder) then makefolder(configSettingsFolder) end
        
        local data = {}
        for k, v in pairs(gConfig) do
            if k ~= "garages" and type(v) ~= "function" then
                if k == "savedPlotDriveway" and typeof(v) == "CFrame" then
                    data[k] = { v:GetComponents() }
                elseif type(v) == "table" then
                    data[k] = deepCopyTable(v)
                else
                    data[k] = v
                end
            end
        end
        
        local json = HttpService:JSONEncode(data)
        writefile(configSettingsFolder .. "/" .. profile .. ".json", json)
        if isfile and not isfile(autoloadFile) then
            setAutoloadInfo(profile, true)
        end
        currentProfileName = profile
    end)
    isSavingConfig = false
    if not success then
        warn("[NexHub] Failed to save config: " .. tostring(err))
    end
    return success, err
end


local function saveFurnitureCacheDisk(slots)
    pcall(function()
        if not isfolder("NexHub") then makefolder("NexHub") end
        if not isfolder("NexHub/StorageHunters") then makefolder("NexHub/StorageHunters") end
        if not isfolder("NexHub/StorageHunters/settings") then makefolder("NexHub/StorageHunters/settings") end
        
        local serializable = {}
        for _, s in ipairs(slots) do
            local cf = s.targetCFrame or s.cf
            local comp = cf and { cf:GetComponents() } or nil
            table.insert(serializable, {
                shelfName = s.shelfName,
                shelfGuid = s.shelfGuid,
                snapName = s.snapName,
                cfComponents = comp,
                slotWidth = s.slotWidth,
                slotDepth = s.slotDepth,
                isPodium = s.isPodium,
                isLargeFloorPodium = s.isLargeFloorPodium,
            })
        end
        local json = HttpService:JSONEncode(serializable)
        writefile("NexHub/StorageHunters/settings/furniture_cache.json", json)
    end)
end

local function loadFurnitureCacheDisk()
    local loaded = nil
    pcall(function()
        local f = "NexHub/StorageHunters/settings/furniture_cache.json"
        if isfile(f) then
            local json = readfile(f)
            local raw = HttpService:JSONDecode(json)
            if type(raw) == "table" and #raw > 0 then
                loaded = {}
                for _, s in ipairs(raw) do
                    if type(s) == "table" and s.shelfGuid and s.snapName and type(s.cfComponents) == "table" and #s.cfComponents == 12 then
                        local cf = CFrame.new(unpack(s.cfComponents))
                        table.insert(loaded, {
                            shelfName = s.shelfName,
                            shelfGuid = s.shelfGuid,
                            snapName = s.snapName,
                            targetCFrame = cf,
                            cf = cf,
                            slotWidth = s.slotWidth,
                            slotDepth = s.slotDepth,
                            isPodium = s.isPodium,
                            isLargeFloorPodium = s.isLargeFloorPodium,
                        })
                    end
                end
            end
        end
    end)
    return loaded
end

local function loadConfig(customProfile)
    isLoadingConfig = true
    local wasAutoload = false
    local loadedProfileName = "default"
    local success, err = pcall(function()
        if not isfolder("NexHub") then makefolder("NexHub") end
        if not isfolder(configBaseFolder) then makefolder(configBaseFolder) end
        if not isfolder(configSettingsFolder) then makefolder(configSettingsFolder) end
        
        local profile = customProfile
        if not profile or profile == "" then
            local autoName, autoEnabled = getAutoloadInfo()
            if autoEnabled and autoName and autoName ~= "" then
                profile = autoName
                wasAutoload = true
            else
                profile = "default"
            end
        end
        if not profile or profile == "" then profile = "default" end
        currentProfileName = profile
        loadedProfileName = profile
        
        -- Clean slate: wipe old profile settings so they never leak into this profile
        resetConfigToDefaults()
        
        local filePath = configSettingsFolder .. "/" .. profile .. ".json"
        if isfile(filePath) then
            local json = readfile(filePath)
            local data = HttpService:JSONDecode(json)
            if data and type(data) == "table" then
                if not gConfig.excludedItems then gConfig.excludedItems = {} end
                table.clear(gConfig.excludedItems)
                if type(data.excludedItems) == "table" then
                    for item, val in pairs(data.excludedItems) do
                        gConfig.excludedItems[item] = val
                    end
                end

                if not gConfig.targetExcludedMutators then gConfig.targetExcludedMutators = {} end
                table.clear(gConfig.targetExcludedMutators)
                if type(data.targetExcludedMutators) == "table" then
                    for mut, val in pairs(data.targetExcludedMutators) do
                        gConfig.targetExcludedMutators[mut] = val
                    end
                end

                for k, v in pairs(data) do
                    if k ~= "excludedItems" and k ~= "targetExcludedMutators" and k ~= "garages" then
                        if k == "savedPlotDriveway" and type(v) == "table" and #v == 12 then
                            gConfig[k] = CFrame.new(unpack(v))
                        elseif type(v) == "table" then
                            gConfig[k] = {}
                            for subK, subV in pairs(v) do gConfig[k][subK] = subV end
                        else
                            gConfig[k] = v
                        end
                    end
                end
            end
        end
        if not gConfig.excludedItems then gConfig.excludedItems = {} end
        if not gConfig.targetExcludedMutators then gConfig.targetExcludedMutators = {} end
        
        -- Ensure required sub-tables exist
        if not gConfig.afSelectedGarages then gConfig.afSelectedGarages = {} end
        if not gConfig.selectedGarages then gConfig.selectedGarages = {} end
        if not gConfig.afAutoBuyAreas then gConfig.afAutoBuyAreas = { ["Any Area"] = true } end
        if not gConfig.autoBuyAreas then gConfig.autoBuyAreas = { ["Any Area"] = true } end
        if not gConfig.seizedAreas then gConfig.seizedAreas = { ["Business Bay"] = true, ["Lucky Beach"] = true, ["Shipyard"] = true, ["Power Plant"] = true } end
        if not gConfig.seizedGarages then gConfig.seizedGarages = {} end
        if not gConfig.buyLuckDrinks then gConfig.buyLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false } end
        if not gConfig.consumeLuckDrinks then gConfig.consumeLuckDrinks = { ["1"] = false, ["2"] = false, ["3"] = false } end
        if not gConfig.buyMiningDrinks or type(gConfig.buyMiningDrinks) ~= "table" then gConfig.buyMiningDrinks = { ["18"] = true, ["19"] = true } end
        if not gConfig.useMiningDrinks or type(gConfig.useMiningDrinks) ~= "table" then gConfig.useMiningDrinks = { ["18"] = true, ["19"] = true } end
        if not gConfig.targetCapsuleMutators then gConfig.targetCapsuleMutators = { ["Antique"] = true, ["Ancient"] = true, ["Timeless"] = true } end
        if not gConfig.itemRules or type(gConfig.itemRules) ~= "table" then gConfig.itemRules = {} end
        if not gConfig.itemLists or type(gConfig.itemLists) ~= "table" then
            gConfig.itemLists = {
                Pickup = { items = {}, categories = {}, rarities = {}, mutations = {}, limitedItems = false, vaultItems = false },
                Shelves = { items = {}, vaultItems = false, limitedItems = false, eventExclusives = false, mutations = {}, categories = {}, rarities = {} },
                AutoSell = { items = {}, vaultItems = false, energyDrinks = false, eventExclusives = false, limitedItems = false, mutations = {}, categories = {}, rarities = {} },
                Grading = { rarities = {}, energyDrinks = false },
                Auction = { mutations = {}, items = {}, rarities = {} },
            }
        end

        if gConfig.quickWinAuction == true then gConfig.autoBidEnabled = false end
        if AB then
            AB.enabled = (gConfig.autoBidEnabled == true)
            AB.speed = gConfig.autoBidSpeed or 0.3
            AB.minStartBid = gConfig.minStartBid or 0
            AB.autoPawnFull = gConfig.autoPawnFull
            AB.autoPawnRateEnabled = gConfig.autoPawnRateEnabled
            AB.targetPawnRate = gConfig.targetPawnRate or 100
        end
        if _G.AB and _G.AB.biddingModes and _G.AB.modeRunID == _G.AHScanner_RunID then
            _G.AB.biddingModes:ApplySaved()
        end
        local diskSlots = loadFurnitureCacheDisk()
        if diskSlots and #diskSlots > 0 then _G.PlotFurnitureCache = diskSlots end
    end)
    task.delay(0.5, function()
        isLoadingConfig = false
    end)
    if not success then
        warn("[NexHub] Failed to load config: " .. tostring(err))
    else
        pcall(function()
            if wasAutoload and abLog then
                abLog("* Autoloaded profile: " .. loadedProfileName .. ".json", C.gold)
            end
        end)
    end
    return success
end

-- Immediately load configuration from disk on startup!
loadConfig()

local function syncUI()
    isSyncingUI = true
    pcall(function()
        for key, updater in pairs(_G.uiToggles) do
            if type(updater) == "function" and gConfig[key] ~= nil then
                pcall(updater, gConfig[key])
            end
        end
        for key, updater in pairs(_G.uiUpdaters or {}) do
            if type(updater) == "function" and gConfig[key] ~= nil then
                pcall(updater, gConfig[key])
            end
        end
        if _G.afGarageUpdaters then
            for _, upd in ipairs(_G.afGarageUpdaters) do pcall(upd) end
        end
        if _G.autoGarageUpdaters then
            for _, upd in ipairs(_G.autoGarageUpdaters) do pcall(upd) end
        end
        if _G.seizedGaragesUpdaters then
            for _, upd in ipairs(_G.seizedGaragesUpdaters) do pcall(upd) end
        end
        if _G.rebuildExclusionChips then pcall(_G.rebuildExclusionChips) end
        if _G.refreshExclusionItemList then pcall(_G.refreshExclusionItemList) end
        if _G.refreshMutDropdown then pcall(_G.refreshMutDropdown) end
    end)
    isSyncingUI = false
end

local function getSpawnPos(spawnInst)
    if not spawnInst then return nil end
    if spawnInst:IsA('BasePart') then return spawnInst.Position end
    if spawnInst.PrimaryPart then return spawnInst.PrimaryPart.Position end
    local bp = spawnInst:FindFirstChildWhichIsA('BasePart') or spawnInst:FindFirstChildWhichIsA('BasePart', true)
    if bp then return bp.Position end
    return nil
end
local function getMyVehicle()
    local player = LocalPlayer or game:GetService("Players").LocalPlayer
    local char = player and player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.SeatPart then
        local model = hum.SeatPart:FindFirstAncestorOfClass("Model")
        if model then return model end
    end

    local vehicleId = tostring(player:GetAttribute("EquippedVehicle") or "")
    local myUserId = tostring(player.UserId)
    
    for _, v in ipairs(workspace:GetChildren()) do
        if v:IsA("Model") then
            local guid = tostring(v:GetAttribute("VehicleGUID") or v:GetAttribute("VehicleId") or "")
            local owner = tostring(v:GetAttribute("OwnerUserId") or v:GetAttribute("Owner") or "")
            if (vehicleId ~= "" and guid == vehicleId) or (owner ~= "" and owner == myUserId) then
                if v:FindFirstChild("DriveSeat") or v:FindFirstChildWhichIsA("VehicleSeat") then
                    return v
                end
            end
        end
    end
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("Model") then
            local seat = v:FindFirstChild("DriveSeat") or v:FindFirstChildWhichIsA("VehicleSeat")
            if seat then
                local guid = tostring(v:GetAttribute("VehicleGUID") or v:GetAttribute("VehicleId") or "")
                local owner = tostring(v:GetAttribute("OwnerUserId") or v:GetAttribute("Owner") or "")
                if (vehicleId ~= "" and guid == vehicleId) or (owner ~= "" and owner == myUserId) then
                    return v
                end
            end
        end
    end
    return nil
end

-- local gConfig removed (already defined at top)
local autoUnloadFull = false

-- Default: all garages selected
if not gConfig.selectedGarages then
    gConfig.selectedGarages = {}
    for id, _ in pairs(GARAGE_CATALOG) do gConfig.selectedGarages[id] = false end
end
if not gConfig.afSelectedGarages then
    gConfig.afSelectedGarages = {}
    for id, _ in pairs(GARAGE_CATALOG) do gConfig.afSelectedGarages[id] = false end
end

-- Ensure excludedItems exists even if _G.gConfig was created by an older run
if gConfig.excludedItems == nil then
    gConfig.excludedItems = {}
end

local defaultConfigFile = configSettingsFolder .. "/default.json"
local hasConfigFile = (isfile and isfile(defaultConfigFile)) or (isfile and isfile(autoloadFile))
if not hasConfigFile and not next(gConfig.excludedItems) then
    -- Pre-populate default excluded items matching traditional hardcoded skips
    pcall(function()
        for id, data in pairs(ItemsData) do
            if type(data) == "table" then
                local name = data.Name or data.name or ""
                local category = (data.Category or data.category or data.Type or ""):lower()
                local lowerName = name:lower()
                
                -- Skip trophies and gavel items
                local isTrophy = lowerName:find("trophy") or category:find("trophy") or lowerName:find("gavel")
                -- Skip accessories
                local isAccessory = category:find("accessory") or category:find("accessories")
                -- Skip safes and lockboxes
                local isSafe = lowerName:find("safe") or lowerName:find("lockbox")
                -- Skip wheels, certificates, and car parts (except wheelbarrow)
                local isWheel = (lowerName:find("wheel") or category:find("wheel")) and not lowerName:find("wheelbarrow")
                local isCert = lowerName:find("certificate") or category:find("certificate") or lowerName:find("authenticity")
                local isPart = (lowerName:find("part") or category:find("part")) and not lowerName:find("particle")

                local isLucky = lowerName:find("luck drink") or lowerName:find("luck_drink") or lowerName:find("luckdrink")
                local isBrewOrQuestTool = lowerName:find("cauldron skull") or lowerName:find("cauldron bag") or lowerName:find("gravedigger shovel") or lowerName:find("uranium ore") or category == "tool"
                if isTrophy or isAccessory or isSafe or isWheel or isCert or isPart or isLucky or isBrewOrQuestTool then
                    gConfig.excludedItems[name] = true
                end
            end
        end
    end)
end

-- Always ensure Luck Drinks, Cauldron Skull Brew, and Quest Tools are excluded (even on existing configs)
pcall(function()
    for id, data in pairs(ItemsData) do
        if type(data) == "table" then
            local name = data.Name or data.name or ""
            local lower = name:lower()
            local cat = (data.Category or data.category or ""):lower()
            if lower:find("luck drink") or lower:find("cauldron skull") or lower:find("cauldron bag") or lower:find("gravedigger shovel") or cat == "tool" then
                if gConfig.excludedItems[name] == nil then
                    gConfig.excludedItems[name] = true
                end
            end
        end
    end
end)

local seizedGarageGuids = {}
local SeizedGarageRemote = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Misc") and ReplicatedStorage.Events.Misc:FindFirstChild("SeizedGarage")
if SeizedGarageRemote then
    table.insert(cleanUpSignals, SeizedGarageRemote.OnClientEvent:Connect(function(seizedTable)
        if type(seizedTable) == "table" then
            seizedGarageGuids = seizedTable
        end
    end))
end

local function isGarageSeized(garageModel)
    if not garageModel then return false end
    local guid = garageModel:GetAttribute("GUID")
    return (guid and seizedGarageGuids[guid] == true) 
        or garageModel:FindFirstChild("SeizedDressing") ~= nil 
        or garageModel:FindFirstChild("PoliceWarning", true) ~= nil
        or garageModel:GetAttribute("Seized") == true
end
_G.isGarageSeized = isGarageSeized
local currentGarageIsSeized = false
_G.AHIsCurrentGarageSeized = false
local lastAuctionWasSeized = false
_G.AHLastAuctionWasSeized = false

local function hasWantedStars()
    local player = LocalPlayer or game:GetService("Players").LocalPlayer
    local pg = player and player:FindFirstChild("PlayerGui")
    local hud = pg and pg:FindFirstChild("PoliceChaseHUD")
    if hud and hud.Enabled then
        local wanted = hud:FindFirstChild("Wanted")
        if wanted and wanted.Visible then
            return true
        end
    end
    return false
end
_G.hasWantedStars = hasWantedStars

local abLog
abLog = function(msg, col)
    local t = os.date("%H:%M:%S")
    local plainText = tostring(msg):gsub("<[^>]+>", "")
    print("[NexWorks] " .. plainText)
    local abTarget = AB or _G.AB
    if abTarget and abTarget.logLines then
        table.insert(abTarget.logLines, 1, { text="["..t.."] "..msg, col=col or (C and C.text2) })
        if #abTarget.logLines > 10 then table.remove(abTarget.logLines) end
        if abTarget.onLog then abTarget.onLog() end
    end
end

local resetStartTime = 0
local function doPoliceClearReset()
    -- Auto-dead completely removed; reset tracking flags without killing character
    lastAuctionWasSeized = false
    _G.AHLastAuctionWasSeized = false
    currentGarageIsSeized = false
    _G.AHIsCurrentGarageSeized = false
    resetStartTime = 0
end
_G.doPoliceClearReset = doPoliceClearReset

local function isGarageSeizedAllowed(lotName, garageModel)
    if not gConfig.seizedGarageSniping then return false end
    if not isGarageSeized(garageModel) then return false end
    
    local cat = GARAGE_CATALOG[lotName]
    local myNetWorth = LocalPlayer:GetAttribute("MaxNetWorth") or LocalPlayer:GetAttribute("NetWorth") or 0
    local myCash = LocalPlayer:GetAttribute("Cash") or 0
    
    -- Net worth check
    if cat and (cat.minNW or 0) > myNetWorth then return false end
    -- Entry fee check
    if cat and (cat.entMin or 0) > myCash then return false end
    
    -- Seized Area whitelist check
    if gConfig.seizedAreas then
        local areaName = (cat and cat.area) or (garageModel:GetAttribute("AreaName") or "")
        local areaOk = false
        if gConfig.seizedAreas["Any Area"] or gConfig.seizedAreas[areaName] then
            areaOk = true
        else
            for selArea, isEn in pairs(gConfig.seizedAreas) do
                if isEn and string.find(areaName, selArea) then
                    areaOk = true
                    break
                end
            end
        end
        if not areaOk then return false end
    end
    
    -- Seized Garage whitelist check
    local selTable = gConfig.seizedGarages
    if selTable and next(selTable) then
        local hasAny = false
        for _, v in pairs(selTable) do
            if v == true then hasAny = true; break end
        end
        if hasAny then
            return (selTable[lotName] == true)
        end
    end
    return true
end

local _garagesDataCache = nil
local function getGaragesDataModule()
    if not _garagesDataCache then
        local RS = game:GetService("ReplicatedStorage")
        local gModule = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Garages")
        if gModule then
            pcall(function() _garagesDataCache = require(gModule) end)
        end
    end
    return _garagesDataCache
end

local function isGaragePrereqMet(lotName)
    if not lotName then return true end
    local gData = getGaragesDataModule()
    if not gData then return true end
    
    local gInfo = gData[lotName]
    if not gInfo or type(gInfo) ~= "table" then return true end
    
    local lp = LocalPlayer or game:GetService("Players").LocalPlayer
    if not lp then return true end
    
    -- 1. Check RequiredGarageWins
    if gInfo.RequiredGarageWins and type(gInfo.RequiredGarageWins) == "table" then
        local req = gInfo.RequiredGarageWins
        local reqGId = req.GarageId
        local reqCount = tonumber(req.Count) or 0
        if reqGId and reqCount > 0 then
            local reqInfo = gData[reqGId]
            local winStat = (reqInfo and reqInfo.WinStat) or (reqGId:gsub("%s+", "") .. "Wins")
            local currentWins = tonumber(lp:GetAttribute(winStat)) or 0
            if currentWins < reqCount then
                return false
            end
        end
    end
    
    -- 2. Check EntryCurrency & EntryCost
    if gInfo.EntryCurrency and gInfo.EntryCost then
        local cur = gInfo.EntryCurrency
        local minCost = (type(gInfo.EntryCost) == "table" and tonumber(gInfo.EntryCost.Min)) or tonumber(gInfo.EntryCost) or 0
        if minCost > 0 then
            local playerAmount = tonumber(lp:GetAttribute(cur)) or 0
            if playerAmount < minCost then
                return false
            end
        end
    end
    
    -- 3. Check MinNetWorth
    if gInfo.MinNetWorth and tonumber(gInfo.MinNetWorth) and tonumber(gInfo.MinNetWorth) > 0 then
        local playerNetWorth = tonumber(lp:GetAttribute("NetWorth")) or 0
        if playerNetWorth > 0 and playerNetWorth < tonumber(gInfo.MinNetWorth) then
            return false
        end
    end
    
    return true
end

local function isGarageAllowed(lotName, isAutofarm)
    if not lotName then return false end
    
    local canonicalKey = lotName
    local cat = GARAGE_CATALOG[lotName]
    local baseName = cat and cat.name
    local area = cat and cat.area
    
    local selTable = isAutofarm and gConfig.afSelectedGarages or gConfig.selectedGarages
    if selTable then
        local hasAny = false
        for _, v in pairs(selTable) do
            if v == true then hasAny = true; break end
        end
        if hasAny then
            local isSelected = (selTable[canonicalKey] == true) 
                or (selTable[lotName] == true)
                or (baseName and selTable[baseName] == true)
            if not isSelected and baseName then
                for k, v in pairs(selTable) do
                    if v == true then
                        local kCat = GARAGE_CATALOG[k]
                        if kCat and kCat.name == baseName then
                            isSelected = true
                            break
                        end
                    end
                end
            end
            -- If user explicitly selected this garage, allow it! (Explicit selection overrides prereq)
            if isSelected then
                return true
            end
            return false
        end
    end

    -- If user selected an Area filter (e.g. "Power Plant"), strictly enforce area selection!
    if isAutofarm and gConfig.afAutoBuyAreas and not gConfig.afAutoBuyAreas["Any Area"] then
        local matchedArea = false
        if area and gConfig.afAutoBuyAreas[area] then
            matchedArea = true
        else
            for selArea, isEn in pairs(gConfig.afAutoBuyAreas) do
                if isEn and ((area and (string.find(area, selArea) or string.find(selArea, area))) or string.find(lotName, selArea)) then
                    matchedArea = true
                    break
                end
            end
        end
        if not matchedArea then
            return false
        end
        return true
    end

    -- If no specific garage or area is selected, check prereqs for routine browsing
    if isAutofarm and not isGaragePrereqMet(lotName) then
        return false
    end
    return true
end

-- Helper to extract all mutators from item inventory data or displayName bracket tags
local function getItemMutators(itemData, displayName)
    local muts = {}
    if itemData and type(itemData.Mutators) == "table" then
        for _, m in ipairs(itemData.Mutators) do
            local mName = type(m) == "table" and (m.name or m.Name) or tostring(m)
            if mName and mName ~= "" then muts[mName] = true end
        end
    end
    if itemData and itemData.CleanMutation and itemData.CleanMutation ~= "None" then
        muts[tostring(itemData.CleanMutation)] = true
    end
    if itemData and itemData.Mutator and itemData.Mutator ~= "None" then
        muts[tostring(itemData.Mutator)] = true
    end
    -- Roblox Instance support (Attributes)
    if itemData and typeof and typeof(itemData) == "Instance" then
        local m = itemData:GetAttribute("Mutator") or itemData:GetAttribute("CleanMutation")
        if m and m ~= "None" then muts[tostring(m)] = true end
        local bp = itemData:FindFirstChild("Base") or itemData.PrimaryPart
        if bp and bp:IsA("BasePart") then
            local bm = bp:GetAttribute("Mutator") or bp:GetAttribute("CleanMutation")
            if bm and bm ~= "None" then muts[tostring(bm)] = true end
        end
    end
    if displayName then
        for tag in tostring(displayName):gmatch("%[(.-)%]") do
            local cleanTag = tag:gsub("%s*%+.*", ""):match("^%s*(.-)%s*$")
            if cleanTag and cleanTag ~= "" then
                muts[cleanTag] = true
            end
        end
    end
    return muts
end
_G.getItemMutators = getItemMutators

local _lastQuestCacheUpdate = 0
local function getEngineerNeededPartsCache()
    local now = os.clock()
    if not _G.engineerNeededPartsCache or (now - _lastQuestCacheUpdate > 4) then
        _lastQuestCacheUpdate = now
        local pp = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("Power Plant")
        local partsToFind = pp and pp:FindFirstChild("PartsToFind")
        local needed = {}
        if partsToFind then
            local orderedTiers = {"Tier1", "Tier2", "Tier3", "Tier4", "Weather Machine"}
            for _, tName in ipairs(orderedTiers) do
                local tier = partsToFind:FindFirstChild(tName)
                if tier then
                    for _, part in ipairs(tier:GetDescendants()) do
                        if part:IsA("ProximityPrompt") and part.Name == "PowerPlantPartPrompt" and part.Enabled then
                            local targetName = (part.ObjectText and part.ObjectText ~= "") and part.ObjectText or (part.Parent and part.Parent.Parent and part.Parent.Parent.Name)
                            if targetName then
                                needed[targetName] = true
                            end
                        end
                    end
                    if next(needed) ~= nil then break end
                end
            end
        end
        _G.engineerNeededPartsCache = needed
    end
    return _G.engineerNeededPartsCache
end
_G.getEngineerNeededPartsCache = getEngineerNeededPartsCache

local _stockSaleRulesCache = nil
local function getStockSaleRulesModule()
    if not _stockSaleRulesCache then
        local RS = game:GetService("ReplicatedStorage")
        local mod = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("StockSaleRules")
        if mod then
            pcall(function() _stockSaleRulesCache = require(mod) end)
        end
    end
    return _stockSaleRulesCache
end

-- ═════════════════════════════════════════════════════
-- 🛡️ NEXWORKS ITEM RULES LIFECYCLE ENGINE
-- ═════════════════════════════════════════════════════

local evaluateItemRule
do
local function resolveItemAttributes(target)
    local attr = {
        name = "",
        cleanName = "",
        itemId = nil,
        mutations = {},
        category = "Misc",
        rarity = "Common",
        price = 0,
        weight = 0,
        isVault = false,
        isDrink = false,
        isLimited = false,
        isEvent = false,
    }
    
    if type(target) == "string" then
        attr.name = target
        attr.cleanName = target:gsub("%[.-%]%s*", ""):gsub("%s*%(.-%)%s*$", ""):match("^%s*(.-)%s*$") or target
        if target:find("%[") then
            for tag in target:gmatch("%[(.-)%]") do
                local cleanTag = tag:gsub("%s*[%+%-]%d+%%", ""):match("^%s*(.-)%s*$")
                if cleanTag and cleanTag ~= "" then attr.mutations[cleanTag] = true end
            end
        end
        if ItemsData then
            for id, data in pairs(ItemsData) do
                if type(data) == "table" and (data.Name == attr.cleanName or data.Name == attr.name) then
                    attr.itemId = tonumber(id) or id
                    attr.category = tostring(data.Category or data.category or data.Type or "Misc")
                    attr.rarity = tostring(data.Rarity or data.rarity or "Common")
                    attr.price = tonumber(data.BasePrice or data.Price or 0) or 0
                    attr.weight = tonumber(data.Weight or 0) or 0
                    break
                end
            end
        end
    elseif typeof(target) == "Instance" then
        attr.name = target.Name
        local attrName = target:GetAttribute("ItemName") or target:GetAttribute("Name") or target.Name
        attr.cleanName = tostring(attrName):gsub("%[.-%]%s*", ""):gsub("%s*%(.-%)%s*$", ""):match("^%s*(.-)%s*$") or tostring(attrName)
        local rawId = target:GetAttribute("ItemId") or target:GetAttribute("ID")
        if rawId then attr.itemId = tonumber(rawId) or rawId end
        
        local mutAttr = target:GetAttribute("Mutator") or target:GetAttribute("Mutation")
        if mutAttr and tostring(mutAttr) ~= "" and tostring(mutAttr) ~= "None" then
            attr.mutations[tostring(mutAttr)] = true
        end
        if target.Name:find("%[") then
            for tag in target.Name:gmatch("%[(.-)%]") do
                local cleanTag = tag:gsub("%s*[%+%-]%d+%%", ""):match("^%s*(.-)%s*$")
                if cleanTag and cleanTag ~= "" then attr.mutations[cleanTag] = true end
            end
        end
        
        if (not attr.itemId or attr.category == "Misc") and ItemsData then
            for id, data in pairs(ItemsData) do
                if type(data) == "table" and (data.Name == attr.cleanName or data.Name == attr.name) then
                    attr.itemId = attr.itemId or tonumber(id) or id
                    attr.category = tostring(data.Category or data.category or data.Type or attr.category)
                    attr.rarity = tostring(data.Rarity or data.rarity or attr.rarity)
                    attr.price = attr.price > 0 and attr.price or (tonumber(data.BasePrice or data.Price or 0) or 0)
                    attr.weight = attr.weight > 0 and attr.weight or (tonumber(data.Weight or 0) or 0)
                    break
                end
            end
        end
        if getSafeTier and getSafeTier(target) ~= nil then attr.isVault = true end
        if target:GetAttribute("Weight") then attr.weight = tonumber(target:GetAttribute("Weight")) or attr.weight end
        if target:GetAttribute("Price") or target:GetAttribute("Value") then attr.price = tonumber(target:GetAttribute("Price") or target:GetAttribute("Value")) or attr.price end
    elseif type(target) == "table" then
        attr.itemId = target.ItemId or target.itemId or target.id
        local itemConf = nil
        if attr.itemId and ItemsData then
            itemConf = ItemsData[tostring(attr.itemId)] or ItemsData[tonumber(attr.itemId)]
        end
        local rawName = target.Name or (itemConf and itemConf.Name) or ""
        attr.name = rawName
        attr.cleanName = tostring(rawName):gsub("%[.-%]%s*", ""):gsub("%s*%(.-%)%s*$", ""):match("^%s*(.-)%s*$") or tostring(rawName)
        if itemConf then
            attr.category = tostring(itemConf.Category or itemConf.category or itemConf.Type or "Misc")
            attr.rarity = tostring(itemConf.Rarity or itemConf.rarity or "Common")
            attr.price = tonumber(itemConf.BasePrice or itemConf.Price or 0) or 0
            attr.weight = tonumber(itemConf.Weight or 0) or 0
            if itemConf.SafeTier or itemConf.Tier or (attr.category:lower():find("safe") or attr.category:lower():find("vault")) then
                attr.isVault = true
            end
        end
        if target.Mutator and tostring(target.Mutator) ~= "" and tostring(target.Mutator) ~= "None" then
            attr.mutations[tostring(target.Mutator)] = true
        end
        if target.Mutations and type(target.Mutations) == "table" then
            for m, _ in pairs(target.Mutations) do attr.mutations[tostring(m)] = true end
        end
        if target.Price then attr.price = tonumber(target.Price) or attr.price end
        if target.Weight then attr.weight = tonumber(target.Weight) or attr.weight end
    end
    
    local lowerClean = attr.cleanName:lower()
    local lowerCat = attr.category:lower()
    if lowerClean:find("safe") or lowerClean:find("vault") or lowerClean:find("lockbox") or lowerCat:find("safe") or lowerCat:find("vault") then
        attr.isVault = true
    end
    if lowerClean:find("drink") or lowerClean:find("potion") or lowerClean:find("brew") or lowerCat:find("drink") or lowerCat:find("potion") then
        attr.isDrink = true
    end
    if lowerClean:find("alien") or lowerClean:find("saucer") or lowerClean:find("meteor") or lowerCat:find("limited") then
        attr.isLimited = true
    end
    if lowerClean:find("sandstorm") or lowerClean:find("police") or lowerClean:find("camo") or lowerClean:find("military") or lowerClean:find("carnival") or lowerClean:find("jester") or lowerCat:find("event") then
        attr.isEvent = true
    end
    return attr
end

evaluateItemRule = function(target, actionPhase)
    local attr = resolveItemAttributes(target)
    if not attr or attr.cleanName == "" then return nil end
    
    -- 1. Custom Rules (Evaluated top-to-bottom: First match wins)
    local rules = gConfig.itemRules or {}
    for idx, rule in ipairs(rules) do
        if rule and rule.enabled ~= false then
            local qualifies = false
            local appliesTo = rule.appliesTo or "ALL"
            local condMatches = {}
            
            -- Condition: Item Names / IDs (Strict Clean Name or Numeric ID match)
            if rule.items and next(rule.items) then
                local m = false
                if attr.itemId and (rule.items[tostring(attr.itemId)] or rule.items[tonumber(attr.itemId)]) then
                    m = true
                elseif rule.items[attr.cleanName] or rule.items[attr.name] then
                    m = true
                end
                table.insert(condMatches, m)
            end
            
            -- Condition: Mutations
            if rule.mutations and next(rule.mutations) then
                local m = false
                for mName, _ in pairs(rule.mutations) do
                    if attr.mutations[mName] then m = true break end
                end
                table.insert(condMatches, m)
            end
            
            -- Condition: Category
            if rule.categories and next(rule.categories) then
                table.insert(condMatches, rule.categories[attr.category] == true)
            end
            
            -- Condition: Rarity
            if rule.rarities and next(rule.rarities) then
                table.insert(condMatches, rule.rarities[attr.rarity] == true)
            end
            
            -- Condition: Is Types
            if rule.isTypes and next(rule.isTypes) then
                local m = false
                if rule.isTypes["Vault items"] and attr.isVault then m = true end
                if rule.isTypes["Energy drinks"] and attr.isDrink then m = true end
                if rule.isTypes["Limited items"] and attr.isLimited then m = true end
                if rule.isTypes["Event exclusives"] and attr.isEvent then m = true end
                table.insert(condMatches, m)
            end
            
            -- Condition: Worth Range
            if rule.worthMin and rule.worthMin > 0 then
                table.insert(condMatches, attr.price >= rule.worthMin)
            end
            if rule.worthMax and rule.worthMax > 0 then
                table.insert(condMatches, attr.price <= rule.worthMax)
            end
            
            -- Condition: Weight Range
            if rule.weightMin and rule.weightMin > 0 then
                table.insert(condMatches, attr.weight >= rule.weightMin)
            end
            if rule.weightMax and rule.weightMax > 0 then
                table.insert(condMatches, attr.weight <= rule.weightMax)
            end
            
            if #condMatches > 0 then
                if appliesTo == "ANY" then
                    for _, res in ipairs(condMatches) do
                        if res then qualifies = true break end
                    end
                else
                    qualifies = true
                    for _, res in ipairs(condMatches) do
                        if not res then qualifies = false break end
                    end
                end
            end
            
            if qualifies and rule.effects then
                local eff = rule.effects
                local rName = rule.name or ("Rule #" .. idx)
                if actionPhase == "pickup" then
                    if eff.never_pickup then return "deny", rName end
                    if eff.always_pickup then return "allow", rName end
                elseif actionPhase == "sell" then
                    if eff.never_sell then return "deny", rName end
                    if eff.allow_selling then return "allow", rName end
                elseif actionPhase == "place" then
                    if eff.never_place then return "deny", rName end
                    if eff.allow_placing then return "allow", rName end
                elseif actionPhase == "grade" then
                    if eff.never_grade then return "deny", rName end
                    if eff.allow_grading then return "allow", rName end
                elseif actionPhase == "wash" then
                    if eff.never_wash then return "deny", rName end
                elseif actionPhase == "auction" then
                    if eff.ignore_min_bid then return "allow", rName end
                elseif actionPhase == "general" then
                    if eff.never_sell or eff.never_place then return "deny", rName end
                    if eff.allow_selling or eff.allow_placing then return "allow", rName end
                end
            end
        end
    end
    
    -- 2. Lane Lists (If no custom rule matched)
    local lists = gConfig.itemLists or {}
    local function matchesLane(laneCfg)
        if not laneCfg then return false end
        if laneCfg.items and next(laneCfg.items) then
            if (attr.itemId and (laneCfg.items[tostring(attr.itemId)] or laneCfg.items[tonumber(attr.itemId)]))
                or laneCfg.items[attr.cleanName] or laneCfg.items[attr.name] then
                return true
            end
        end
        if laneCfg.mutations and next(laneCfg.mutations) then
            for mName, _ in pairs(laneCfg.mutations) do
                if attr.mutations[mName] then return true end
            end
        end
        if laneCfg.categories and next(laneCfg.categories) and laneCfg.categories[attr.category] then
            return true
        end
        if laneCfg.rarities and next(laneCfg.rarities) and laneCfg.rarities[attr.rarity] then
            return true
        end
        if laneCfg.vaultItems and attr.isVault then return true end
        if laneCfg.energyDrinks and attr.isDrink then return true end
        if laneCfg.limitedItems and attr.isLimited then return true end
        if laneCfg.eventExclusives and attr.isEvent then return true end
        return false
    end
    
    if actionPhase == "pickup" then
        if matchesLane(lists.Pickup) then return "deny", "Pickup List" end
    elseif actionPhase == "sell" then
        if matchesLane(lists.AutoSell) then return "deny", "AutoSell List" end
    elseif actionPhase == "place" then
        if matchesLane(lists.Shelves) then return "deny", "Shelves List" end
    elseif actionPhase == "grade" then
        local gList = lists.Grading
        if gList then
            if gList.energyDrinks and attr.isDrink then return "allow", "Grading Energy Drinks" end
            if gList.rarities and next(gList.rarities) then
                if gList.rarities[attr.rarity] then return "allow", "Grading List" else return "deny", "Grading List" end
            end
        end
    elseif actionPhase == "auction" then
        if matchesLane(lists.Auction) then return "allow", "Auction List" end
    elseif actionPhase == "general" then
        if matchesLane(lists.AutoSell) or matchesLane(lists.Shelves) then return "deny", "AutoSell/Shelves List" end
    end
    
    return nil, nil
end
end
_G.evaluateItemRule = evaluateItemRule

-- Returns true if an item is excluded from auto-place and auto-pawn
local function isItemExcluded(displayName, itemData, actionPhase)
    if not displayName and not itemData then return false end

    -- Strip bracketed tags (e.g. "[Gold +50%] Gavel" -> "Gavel") and trailing parenthesized weight/info tags
    local cleanName = tostring(displayName):gsub("%[.-%]%s*", ""):gsub("%s*%(.-%)%s*$", ""):match("^%s*(.-)%s*$")

    -- [Shield] QUEST & UNSELLABLE ITEM EXCLUSION: Never auto-place or auto-pawn [Quest] items, tools, or items blocked by StockSaleRules
    local itemMuts = getItemMutators(itemData, displayName)
    if itemMuts["Quest"] then
        return true
    end
    if type(itemData) == "table" then
        local saleRules = getStockSaleRulesModule()
        if saleRules then
            local okBlock, blockReason = pcall(function() return saleRules.GetSellBlockReason(itemData) end)
            if okBlock and blockReason ~= nil then
                return true
            end
        end
        if itemData.ItemId and ItemsData then
            local itemConf = ItemsData[tostring(itemData.ItemId)] or ItemsData[tonumber(itemData.ItemId)]
            if type(itemConf) == "table" then
                -- Only exclude actual equipped tools (Candy Bag, Grave Shovel, Pickaxes) - NOT generic sellable junk like Propane Tanks
                if itemConf.CandyBagTier or itemConf.GraveShovel or (itemConf.PickaxeDamage and tonumber(itemConf.PickaxeDamage) and tonumber(itemConf.PickaxeDamage) > 0) then
                    return true
                end
            end
        end
    end
    
    -- [Shield] QUEST DELIVERY EXCLUSION: Never auto-place or auto-pawn items currently needed for active Power Plant deliveries!
    if _G.protectQuestParts ~= false then
        local qCache = getEngineerNeededPartsCache()
        if qCache then
            local checkName = cleanName or displayName
            if qCache[checkName] then
                return true
            end
            local lower = tostring(checkName):lower()
            for pName, _ in pairs(qCache) do
                if tostring(pName):lower() == lower then
                    return true
                end
            end
        end
    end

    -- [Shield] ITEM RULES LIFECYCLE EVALUATION (Rules > Lists > Legacy Exclusions)
    local phase = actionPhase or "general"
    local ruleDecision, ruleName = evaluateItemRule(itemData or displayName, phase)
    if ruleDecision == "deny" then
        return true
    elseif ruleDecision == "allow" then
        return false
    end

    if not gConfig.excludedItems then return false end
    
    local isNameExcluded = (gConfig.excludedItems[displayName] == true) 
        or (cleanName and gConfig.excludedItems[cleanName] == true)
        
    -- Case-insensitive fallback lookup against gConfig.excludedItems (including Cauldron Skull <-> Cauldron Skull Brew alias)
    if not isNameExcluded then
        local targetLower = (cleanName or displayName):lower()
        for name, excl in pairs(gConfig.excludedItems) do
            if excl then
                local exLower = tostring(name):lower()
                if exLower == targetLower
                    or (targetLower == "cauldron skull brew" and exLower == "cauldron skull")
                    or (targetLower == "cauldron skull" and exLower == "cauldron skull brew") then
                    isNameExcluded = true
                    break
                end
            end
        end
    end

    if not isNameExcluded then
        return false
    end

    -- GAVEL / TROPHY MUTATOR FILTER:
    -- Only apply gConfig.targetExcludedMutators ("Protected Gavel / Trophy Mutators") to Gavels and Trophies!
    -- All other excluded items (Uranium Ore, Cauldron Skull Brew, Luck Drinks, Safes, Wheels, etc.) are unconditionally protected.
    local checkLower = tostring(cleanName or displayName):lower()
    local isGavelOrTrophy = (checkLower:find("gavel") ~= nil) or (checkLower:find("trophy") ~= nil)
    if not isGavelOrTrophy then
        return true
    end

    -- Check if user has active Gavel/Trophy mutator filters (e.g. [Timeless], [Gold], etc.)
    local filterActive = false
    if gConfig.targetExcludedMutators and next(gConfig.targetExcludedMutators) then
        for _, v in pairs(gConfig.targetExcludedMutators) do
            if v == true then filterActive = true break end
        end
    end

    -- If no mutator filter is active, protect all user-marked Gavels/Trophies by default
    if not filterActive then
        return true
    end

    -- Mutator filter is active for Gavel/Trophy: check if this item has the requested mutator!
    local hasAnyMut = false
    for mutName, _ in pairs(itemMuts) do
        hasAnyMut = true
        if gConfig.targetExcludedMutators[mutName] == true then
            return true
        end
    end

    -- Check "None" (Normal Gavel/Trophy with no mutators)
    if not hasAnyMut and gConfig.targetExcludedMutators["None"] == true then
        return true
    end

    -- If mutator filter is active and Gavel/Trophy does NOT match target mutation: allow selling/placing it
    return false
end
_G.isItemExcluded = isItemExcluded

local function calcEntryValueAndCost(itemEntry)
    if type(itemEntry) ~= "table" then return 0, 5, 0 end
    local itemId = itemEntry.ItemId and tostring(itemEntry.ItemId)
    local itemConf = (ItemsData and (ItemsData[itemId] or ItemsData[tonumber(itemId)])) or {}
    local basePrice = itemConf.BasePrice or 0
    local price = basePrice
    local MutatorModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("MutatorModule")
    if MutatorModule then
        pcall(function()
            local mm = require(MutatorModule)
            if mm and mm.CalculatePriceForEntry then
                price = mm:CalculatePriceForEntry(basePrice, itemEntry)
            end
        end)
    end
    
    local gradeMult = 1
    local g = itemEntry.Grade
    if g == 1 or g == "1" then gradeMult = 1.15
    elseif g == 2 or g == "2" then gradeMult = 1.35
    elseif g == 3 or g == "3" then gradeMult = 1.6
    elseif g == 4 or g == "4" then gradeMult = 2.0
    elseif g == 5 or g == "5" then gradeMult = 2.5 end
    
    local totalVal = math.floor(price * gradeMult)
    
    local cost = 5
    if totalVal >= 500000 then cost = 250
    elseif totalVal >= 250000 then cost = 150
    elseif totalVal >= 100000 then cost = 75
    elseif totalVal >= 50000 then cost = 50
    elseif totalVal >= 5000 then cost = 25
    elseif totalVal >= 1000 then cost = 15
    else cost = 5 end
    
    local name = tostring(itemConf.Name or ""):lower()
    if name:find("gavel") or (itemConf.Category and itemConf.Category:lower() == "trophy") or itemEntry.IsTrophy then
        cost = 100
    end
    
    local luck = math.floor(math.log10(math.max(10, totalVal)) * 5)
    
    return totalVal, cost, luck
end


-- AUTO-BID ENGINE SETUP
-- ═════════════════════════════════════════════════════
local AuctionEvents = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Auction")
local BidRemote              = AuctionEvents and AuctionEvents:FindFirstChild("Bid")
local LeaveAuctionRemote     = AuctionEvents and AuctionEvents:FindFirstChild("LeaveAuction")
-- Correct remote name confirmed via remote spy: UpdateCurrentWinningBid (not UpdateWinningBid)
local UpdateWinningBidEvent  = AuctionEvents and AuctionEvents:FindFirstChild("UpdateCurrentWinningBid")
local AB = {
    enabled = gConfig.autoBidEnabled or false, minBid = 0, speed = gConfig.autoBidSpeed or 0.3,
    autoPawnFull = gConfig.autoPawnFull,        -- Auto sell/pawn items when inventory becomes full
    autoPawnRateEnabled = gConfig.autoPawnRateEnabled, -- Auto sell/pawn items when pawn rate hits target rate %
    targetPawnRate = gConfig.targetPawnRate or 100,        -- Min target pawn rate % (e.g. 100%, 120%, 150%)
    minStartBid = gConfig.minStartBid or 0,       -- skip auctions whose starting bid is below this
    minBidBlocked = false, -- true when current auction was blocked by minStartBid
    auctionJustOpened = false, -- true from open until first bid update received
    biddingUIOpen = false, -- true only while ToggleBiddingUI(true) is active
    leavingAuction = false, -- true while LeaveAuction:InvokeServer is in-flight
    leaveStartedAt = nil,
    auctionOpenedAt = 0,
    activeGarageInstance = nil,
    weAreWinning = false, -- track if we are winning the current active auction
    currentBid = 0, predictedVal = 0, bidsThisRound = 0, auctionOpen = false,
    activeLot = nil, activeLotData = nil, startingAuction = false,
    pickupPhase = false, -- true while we are collecting won items (blocks new auctions)
    logLines = {}, onLog = nil
}
_G.AB = AB
local SPEED_PRESETS = { { label="Safe 0.5s", val=0.50 }, { label="Normal 0.3s",val=0.30 }, { label="Fast 0.1s", val=0.10 } }
abLog = function(msg, col)
    local t = os.date("%H:%M:%S")
    local plainText = tostring(msg):gsub("<[^>]+>", "")
    print("[NexWorks] " .. plainText)
    table.insert(AB.logLines, 1, { text="["..t.."] "..msg, col=col or C.text2 })
    if #AB.logLines > 10 then table.remove(AB.logLines) end
    if AB.onLog then AB.onLog() end
end
local bidThread = nil
local function stopBidLoop(reason)
    if bidThread then task.cancel(bidThread) bidThread = nil end
    if reason then abLog("[Warning] Stopped: "..reason, C.red) end
end

local function requestLeaveAuction(remote)
    local targetRemote = remote or LeaveAuctionRemote
    if not targetRemote or AB.leavingAuction then return false end
    AB.leavingAuction = true
    AB.leaveStartedAt = os.clock()
    local ok, result = pcall(function()
        return targetRemote:InvokeServer()
    end)
    local waitStart = os.clock()
    while LocalPlayer:GetAttribute("InAuction") == true and (os.clock() - waitStart < 0.8) do
        task.wait(0.05)
    end
    AB.leavingAuction = false
    AB.leaveStartedAt = nil
    return ok, result
end

local function firePrompt(prompt)
    if not prompt or not prompt.Parent then return end
    pcall(function()
        game:GetService("ProximityPromptService").Enabled = true
    end)
    if fireproximityprompt then
        local origHold = prompt.HoldDuration
        pcall(function() prompt.HoldDuration = 0 end)
        pcall(function() fireproximityprompt(prompt, 0) end)
        pcall(function() prompt.HoldDuration = origHold end)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local function getGarageEntranceCFrame(garage)
    if not garage then return nil end
    local entry = garage:FindFirstChild("EntrySquare")
    local promptPart = entry and entry:FindFirstChild("PromptPart")
    if promptPart and promptPart:IsA("BasePart") then
        return promptPart.CFrame
    end
    local auctionZone = garage:FindFirstChild("AuctionZone")
    if auctionZone and auctionZone:IsA("BasePart") then
        return auctionZone.CFrame + Vector3.new(0, 2.5, 0)
    end
    if entry and entry:IsA("Model") then
        return entry:GetPivot()
    end
    local door = garage:FindFirstChild("Door")
    if door then
        local doorPivot = door:IsA("Model") and door:GetPivot() or (door:IsA("BasePart") and door.CFrame)
        if doorPivot then
            return doorPivot * CFrame.new(0, 0, 12)
        end
    end
    local npcSpawns = garage:FindFirstChild("NPCSpawns")
    if npcSpawns then
        return npcSpawns:IsA("Model") and npcSpawns:GetPivot() or (npcSpawns:IsA("BasePart") and npcSpawns.CFrame)
    end
    return nil
end

local function parkVehicleAtGarage(vehicle, garage, targetCF)
    if not vehicle or not garage or not targetCF then return false end
    local vehicleRoot = vehicle.PrimaryPart or vehicle:FindFirstChild("Body") or vehicle:FindFirstChildWhichIsA("BasePart")
    if not vehicleRoot then return false end

    local gPivot = garage:GetPivot()
    local outDir = (targetCF.Position - gPivot.Position)
    local outFlat = (outDir.Magnitude > 0.1) and Vector3.new(outDir.X, 0, outDir.Z).Unit or targetCF.LookVector
    local roadDir = Vector3.new(-outFlat.Z, 0, outFlat.X)

    local driveSeat = vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
        or vehicle:FindFirstChild("DriveSeat", true)
        or vehicle:FindFirstChildWhichIsA("Seat", true)

    local targetSeatPos = targetCF.Position + (outFlat * 2.8)

    -- Request streaming for garage area before raycasting ground
    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(targetCF.Position)
    end)

    local ray = RaycastParams.new()
    ray.FilterDescendantsInstances = { LocalPlayer.Character, vehicle }
    ray.FilterType = Enum.RaycastFilterType.Exclude

    local hit = workspace:Raycast(targetSeatPos + Vector3.new(0, 5, 0), Vector3.new(0, -25, 0), ray)
    local groundY = hit and hit.Position.Y or (targetCF.Position.Y - 2.5)

    local alignedCF
    if driveSeat then
        local vPivot = vehicle:GetPivot()
        local seatOffset = vPivot:ToObjectSpace(driveSeat.CFrame)

        -- Evaluate both sideways orientations (parallel to garage door) so driver seat faces door and body extends outward into driveway
        local rot1 = CFrame.lookAt(Vector3.zero, roadDir)
        local rot2 = CFrame.lookAt(Vector3.zero, -roadDir)
        local seatWorld1 = rot1:VectorToWorldSpace(seatOffset.Position)
        local seatWorld2 = rot2:VectorToWorldSpace(seatOffset.Position)

        local chosenRot = rot1
        local chosenWorldSeatOffset = seatWorld1

        local testPos1 = targetSeatPos - seatWorld1
        local testPos2 = targetSeatPos - seatWorld2
        -- Prioritize rotation extending vehicle body outward into open driveway (+outFlat) rather than clipping garage wall
        if (testPos2 - targetCF.Position):Dot(outFlat) > (testPos1 - targetCF.Position):Dot(outFlat) then
            chosenRot = rot2
            chosenWorldSeatOffset = seatWorld2
        end

        -- Compute vehicle bounding box to accurately align tires to ground level
        local vCF, vSize = vehicle:GetBoundingBox()
        local pivotBottomOffset = math.max(0.5, vPivot.Position.Y - (vCF.Position.Y - vSize.Y / 2))
        local finalPivotY = groundY + pivotBottomOffset + 0.3

        local finalPivotPos = Vector3.new(
            targetSeatPos.X - chosenWorldSeatOffset.X,
            finalPivotY,
            targetSeatPos.Z - chosenWorldSeatOffset.Z
        )
        alignedCF = CFrame.new(finalPivotPos) * chosenRot.Rotation
    else
        local spawnPos = targetCF.Position + (outFlat * 3.2)
        local finalPos = Vector3.new(spawnPos.X, groundY + 2.5, spawnPos.Z)
        alignedCF = CFrame.lookAt(finalPos, finalPos + roadDir)
    end

    vehicle:PivotTo(alignedCF)
    for _, part in ipairs(vehicle:GetDescendants()) do
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
    return true
end

_G.AHGarageCooldowns = _G.AHGarageCooldowns or {}

local function handleAuctionSkip(reason, garageToCooldown)
    -- Instant skip with synchronized leave tracking
    AB.minBidBlocked = true
    AB.auctionOpen = false
    AB.biddingUIOpen = false
    AB.activeLot = nil
    AB.activeLotData = nil
    AB.activeGarageInstance = nil
    AB.startingAuction = false
    AB.weAreWinning = false
    currentGarageIsSeized = false
    _G.AHIsCurrentGarageSeized = false
    lastTargetLot = nil
    stopBidLoop()
    
    if garageToCooldown then
        _G.AHGarageCooldowns[garageToCooldown] = os.clock()
    end
    
    if LeaveAuctionRemote then
        task.spawn(requestLeaveAuction, LeaveAuctionRemote)
    end
    if reason then
        abLog("[Skipped] " .. tostring(reason), Color3.fromRGB(255, 140, 60))
    end
end

local function matchLotName(n1, n2)
    if not n1 or not n2 then return false end
    n1 = n1:lower()
    n2 = n2:lower()
    
    -- If numbers exist, they MUST match
    local num1 = n1:match("%d+")
    local num2 = n2:match("%d+")
    if num1 or num2 then
        if num1 ~= num2 then
            return false
        end
    end
    
    -- Remove common generic suffixes but KEEP main words
    local clean1 = n1:gsub("garage", ""):gsub("container", ""):gsub("shop", ""):gsub("front", ""):gsub("%s+", "")
    local clean2 = n2:gsub("garage", ""):gsub("container", ""):gsub("shop", ""):gsub("front", ""):gsub("%s+", "")
    
    -- Prevent empty matches
    if clean1 == "" or clean2 == "" then
        return false
    end
    
    return clean1:find(clean2) or clean2:find(clean1)
end

local function isVehicleOverweight()
    local vehicle = (typeof(getMyVehicle) == "function" and getMyVehicle()) or nil
    if not vehicle then
        for _, desc in ipairs(workspace:GetChildren()) do
            if desc:IsA("Model") and desc:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                vehicle = desc
                break
            end
        end
    end
    if vehicle then
        local weight = vehicle:GetAttribute("CargoWeight") or 0
        local limit = vehicle:GetAttribute("CargoWeightLimit") or 99999
        local threshold = ((gConfig and gConfig.autoUnloadThreshold) or 80) / 100
        if limit > 0 and weight >= (limit * threshold) then
            return true, vehicle, weight, limit
        end
    end
    return false
end

local function instantUnloadVehicle(targetVehicle)
    pcall(function()
        local v = targetVehicle or (typeof(getMyVehicle) == "function" and getMyVehicle()) or nil
        local vehicleId = (v and (v:GetAttribute("VehicleGUID") or v:GetAttribute("GUID"))) or LocalPlayer:GetAttribute("EquippedVehicle")
        if vehicleId and vehicleId ~= "" then
            local vEvents = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Vehicles")
            local getItemsRemote = vEvents and vEvents:FindFirstChild("GetVehicleItems")
            local transferRemote = vEvents and vEvents:FindFirstChild("TransferVehicleItemsToInventory")
            if getItemsRemote and transferRemote then
                local items = nil
                pcall(function() items = getItemsRemote:InvokeServer(vehicleId) end)
                if items and type(items) == "table" then
                    local guids = {}
                    for guid, _ in pairs(items) do
                        table.insert(guids, guid)
                    end
                    if #guids > 0 then
                        pcall(function() transferRemote:FireServer(guids) end)
                        abLog("[Freight] Vehicle Full! Instant auto-unloaded " .. #guids .. " items.", C.green)
                        task.wait(0.4)
                    end
                end
            end
        end
        if v then
            pcall(function() v:SetAttribute("CargoWeight", 0) end)
        end
    end)
end

local function triggerAutoPickup(lotName)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        AB.lastWonLot = lotName or "Unknown"
        AB.originalPosition = root.CFrame
        AB.isCollecting = true
        AB.collectionStartTime = os.clock()
        abLog("[Gift] Auto-Pickup Armed", C.green)
    end
end

local function belongsToUs(itemModel)
    if not itemModel then return false end
    local n = tostring(itemModel:GetAttribute("ItemName") or itemModel:GetAttribute("Name") or itemModel.Name):lower()
    local id = tostring(itemModel:GetAttribute("ItemId") or "")
    if n:find("zombie") or id == "1415" or id == "1063" or itemModel:GetAttribute("OutlawCorpse") or itemModel:GetAttribute("ZombieCorpse") then
        return false
    end
    local owner = itemModel:GetAttribute("Owner")
    local base = itemModel:FindFirstChild("Base")
    local baseOwner = base and base:GetAttribute("Owner")
    
    local targetOwner = owner or baseOwner
    if targetOwner then
        return tonumber(targetOwner) == LocalPlayer.UserId
    end
    return false
end

local getPickupItemValue
local runAutoPickupCycle

local function dismissDiscoveryPopups()
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local pg = lp and lp:FindFirstChild("PlayerGui")
        local uic = pg and pg:FindFirstChild("UIControllerGui")
        if uic then
            local ndo = uic:FindFirstChild("NewDiscoveryOuter")
            if ndo and ndo.Visible then
                local btn = ndo:FindFirstChild("RepairContinueButton", true)
                if btn and btn:IsA("GuiButton") and btn.Visible then
                    pcall(function()
                        for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do
                            conn:Fire()
                        end
                    end)
                end
                local dp = ndo:FindFirstChild("DiscoveryPopup", true)
                if dp then dp.Visible = false end
                ndo.Visible = false
            end
        end
    end)
end

-- Safely resolve world CFrame for any prompt or item model (handles BaseParts, Attachments, Models)
local function getItemTargetCFrame(prompt, item)
    if prompt then
        local pParent = prompt.Parent
        if pParent then
            if pParent:IsA("BasePart") then
                return pParent.CFrame
            elseif pParent:IsA("Attachment") then
                return pParent.WorldCFrame
            elseif pParent:IsA("Model") then
                return pParent:GetPivot()
            end
        end
    end
    if item then
        if item:IsA("BasePart") then
            return item.CFrame
        elseif item:IsA("Model") then
            local base = item:FindFirstChild("Base") or item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
            if base and base:IsA("BasePart") then
                return base.CFrame
            end
            return item:GetPivot()
        end
    end
    return nil
end

local function ensureNotRagdolled(char, hum)
    if not char or not hum then return end
    if hum.Sit then hum.Sit = false end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(0.08)
        hum:ChangeState(Enum.HumanoidStateType.Running)
    end
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("BallSocketConstraint") and d.Name:lower():find("ragdoll") then
            pcall(function() d:Destroy() end)
        end
    end
end

local function equipWrenchTool()
    local lp = game:GetService("Players").LocalPlayer
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("wrench") then
            return true
        end
    end

    -- 1. Try Hotbar module EquipToolId (Native Storage Hunters Hotbar System)
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local hotbar = require(RS.Modules.Screens.Hotbar)
        local targetWrench = nil
        local ws = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("WrenchShop")
        local state = ws and ws:FindFirstChild("GetState") and ws.GetState:InvokeServer()
        if state and state.equipped then
            targetWrench = state.equipped
        elseif state and state.owned then
            for i = 8, 0, -1 do
                if state.owned["Wrench" .. i] then
                    targetWrench = "Wrench" .. i
                    break
                end
            end
        end
        targetWrench = targetWrench or "Wrench3"
        if hotbar and hotbar.EquipToolId then
            hotbar.EquipToolId(targetWrench)
        end
    end)
    task.wait(0.12)
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("wrench") then
            return true
        end
    end

    -- 2. Try Backpack
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find("wrench") then
                hum:EquipTool(t)
                task.wait(0.12)
                return true
            end
        end
    end

    -- 3. Fallback to EquipWrench RemoteFunction
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local ws = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("WrenchShop")
        if ws and ws:FindFirstChild("GetState") and ws:FindFirstChild("EquipWrench") then
            local state = ws.GetState:InvokeServer()
            if state and state.equipped then
                ws.EquipWrench:InvokeServer(state.equipped)
            end
        end
    end)
    task.wait(0.15)
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find("wrench") then
            return true
        end
    end
    return false
end

-- Safecracker helpers
local function getSafeTier(item)
    if not item then return nil end
    local sId = item:GetAttribute("SafeId")
    if sId then
        sId = tostring(sId)
        if sId == "1" or sId == "2" or sId == "7" then return 0 end
        if sId == "3" then return 1 end
        if sId == "4" then return 2 end
        if sId == "5" then return 3 end
        if sId == "6" then return 4 end
    end
    local name = tostring(item:GetAttribute("ItemName") or item:GetAttribute("Name") or item.Name):lower()
    if name:find("diamond vault") then return 4 end
    if name:find("diamond safe") then return 3 end
    if name:find("code safe") then return 2 end
    if name:find("metal safe") then return 1 end
    if name:find("wooden safe") or name:find("junk safe") then return 0 end
    if name:find("safe") or name:find("vault") or name:find("lockbox") then return 0 end
    return nil
end

local function getPlayerBestLockpick()
    local bestTier = -1
    local bestToolId = nil
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local lps = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("LockpickShop")
        local getState = lps and lps:FindFirstChild("GetState")
        local state = getState and getState:InvokeServer()
        if state and state.owned then
            if state.owned["Picklock4"] then bestTier = 4; bestToolId = "Picklock4"
            elseif state.owned["Picklock3"] then bestTier = 3; bestToolId = "Picklock3"
            elseif state.owned["Picklock2"] then bestTier = 2; bestToolId = "Picklock2"
            elseif state.owned["Picklock1"] or state.owned["Lockpick"] then bestTier = 1; bestToolId = "Picklock1"
            elseif state.owned["Picklock0"] then bestTier = 0; bestToolId = "Picklock0"
            end
        end
    end)
    if bestTier == -1 then
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local getSlots = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Hotbar") and RS.Events.Hotbar:FindFirstChild("GetSlots")
            local slots = getSlots and getSlots:InvokeServer()
            if slots then
                for slotNum, data in pairs(slots) do
                    local id = tostring(data.id or ""):lower()
                    if id:find("picklock4") and bestTier < 4 then bestTier = 4; bestToolId = "Picklock4"
                    elseif id:find("picklock3") and bestTier < 3 then bestTier = 3; bestToolId = "Picklock3"
                    elseif id:find("picklock2") and bestTier < 2 then bestTier = 2; bestToolId = "Picklock2"
                    elseif (id:find("picklock1") or id:find("lockpick")) and bestTier < 1 then bestTier = 1; bestToolId = "Picklock1"
                    elseif id:find("picklock0") and bestTier < 0 then bestTier = 0; bestToolId = "Picklock0"
                    end
                end
            end
        end)
    end
    return bestTier, bestToolId
end

local function equipLockpickTool()
    local lp = game:GetService("Players").LocalPlayer
    local char = lp.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("picklock") or t.Name:lower():find("lockpick")) then
            return true
        end
    end

    -- 1. Try Hotbar module EquipToolId
    local bestTier, bestToolId = getPlayerBestLockpick()
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local hotbar = require(RS.Modules.Screens.Hotbar)
        if hotbar and hotbar.EquipToolId and bestToolId then
            hotbar.EquipToolId(bestToolId)
        end
    end)
    task.wait(0.12)
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and (t.Name:lower():find("picklock") or t.Name:lower():find("lockpick")) then
            return true
        end
    end

    -- 2. Try Backpack
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and (t.Name:lower():find("picklock") or t.Name:lower():find("lockpick")) then
                hum:EquipTool(t)
                task.wait(0.12)
                return true
            end
        end
    end
    return false
end

local function solvePicklockMinigame(timeoutSec)
    timeoutSec = timeoutSec or 5.0
    local startTime = os.clock()
    local lp = game:GetService("Players").LocalPlayer
    local vim = game:GetService("VirtualInputManager")
    local gui = nil
    while os.clock() - startTime < 1.8 do
        gui = lp.PlayerGui:FindFirstChild("PicklockMinigame")
        if gui then break end
        task.wait(0.05)
    end
    if not gui then return false end
    pcall(function() gui.Enabled = false end)
    local ring = gui:FindFirstChild("RingArea", true)
    local target = ring and ring:FindFirstChild("Target")
    local indicator = ring and ring:FindFirstChild("Indicator")
    if not target or not indicator then return false end
    local solvedPins = 0
    for pin = 1, 3 do
        local pinStart = os.clock()
        local pinHit = false
        while os.clock() - pinStart < 2.5 and (os.clock() - startTime) < timeoutSec do
            if not gui or not gui.Parent then break end
            local tRot = target.Rotation
            local iRot = indicator.Rotation
            local diff = math.abs((iRot - tRot + 180) % 360 - 180)
            if diff <= 12 then
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.wait(0.03)
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                pinHit = true
                solvedPins = solvedPins + 1
                task.wait(0.35)
                break
            end
            task.wait(0.01)
        end
        if not pinHit then break end
    end
    local waitClean = os.clock()
    while os.clock() - waitClean < 1.5 do
        if not lp.PlayerGui:FindFirstChild("PicklockMinigame") then break end
        task.wait(0.05)
    end
    return solvedPins >= 3
end

local function fireHoldPrompt(targetPrompt)
    if not targetPrompt or not targetPrompt.Parent or not targetPrompt.Enabled then return end
    local holdTime = targetPrompt.HoldDuration or 0
    if fireproximityprompt then
        pcall(function() fireproximityprompt(targetPrompt, 0) end)
    else
        pcall(function()
            targetPrompt:InputHoldBegin()
            task.wait(holdTime + 0.08)
            targetPrompt:InputHoldEnd()
        end)
    end
end

-- Unified high-performance Auto-Pickup Cycle
_G.AHPickupCycleRunning = false
runAutoPickupCycle = function(source, forceManual)
    if _G.AHPickupCycleRunning then return end

    local shouldPickup = (forceManual == true) or (gConfig.autoCollectWon == true)
    if not shouldPickup then return end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildWhichIsA("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hum then return end

    local itemFolders = {}
    if workspace:FindFirstChild("_Carryables") then table.insert(itemFolders, workspace._Carryables) end
    if workspace:FindFirstChild("Cargo Train Items") then table.insert(itemFolders, workspace["Cargo Train Items"]) end
    if #itemFolders == 0 then return end

    -- Verify there are actually items belonging to us
    local hasAny = false
    for _, folder in ipairs(itemFolders) do
        for _, it in ipairs(folder:GetChildren()) do
            if belongsToUs(it) then
                local isSkipped = _G.AHSkippedItems and _G.AHSkippedItems[it] and os.clock() < _G.AHSkippedItems[it]
                if not isSkipped then
                    local p = it:FindFirstChild("PickupPrompt", true) or it:FindFirstChildWhichIsA("ProximityPrompt", true)
                    if p and p.Enabled then
                        hasAny = true
                        break
                    end
                end
            end
        end
        if hasAny then break end
    end

    if not hasAny then return end

    _G.AHPickupCycleRunning = true
    AB.pickupPhase = true
    abLog("Auto-picking up items (" .. tostring(source or "Auto") .. ")...", C.green)

    local vehicle = getMyVehicle()

    local itemFails = {}

    -- Never move the character root while a seat weld can carry the car with it.
    local function moveToPickupTarget(targetCF)
        local deadline = os.clock() + 1.5
        hum.Sit = false
        while hum.SeatPart and os.clock() < deadline do
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.wait(0.05)
            if LocalPlayer.Character ~= char or hum.Health <= 0 then return false end
        end
        if hum.SeatPart or LocalPlayer.Character ~= char or hum.Health <= 0 then return false end
        hrp.CFrame = targetCF
        hrp.AssemblyLinearVelocity = Vector3.zero
        return true
    end

    ensureNotRagdolled(char, hum)
    if not moveToPickupTarget(hrp.CFrame) then
        abLog("Auto-Pickup: could not leave the seat; collection stopped.", C.red)
        _G.AHPickupCycleRunning = false
        AB.pickupPhase = false
        AB.weAreWinning = false
        return
    end

    local maxPasses = 50
    local pass = 0
    local consecutiveZeroChecks = 0
    local pickupStartTime = os.clock()

    while pass < maxPasses and (os.clock() - pickupStartTime < 60) do
        -- Instant user stop check
        if not forceManual and gConfig.autoCollectWon ~= true and not AB.pickupPhase then
            abLog("⏹ Auto-Pickup stopped by user.", C.textDim)
            break
        end

        dismissDiscoveryPopups()

        char = LocalPlayer.Character
        hum = char and char:FindFirstChildWhichIsA("Humanoid")
        hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not hum then break end
        ensureNotRagdolled(char, hum)

        local itemsFound = 0

        for _, folder in ipairs(itemFolders) do
            for _, item in ipairs(folder:GetChildren()) do
                if not forceManual and gConfig.autoCollectWon ~= true and not AB.pickupPhase then
                    break
                end

                if belongsToUs(item) then
                    local isSkipped = (_G.AHSkippedItems and _G.AHSkippedItems[item] and os.clock() < _G.AHSkippedItems[item]) or ((itemFails[item] or 0) >= 3)
                    if not isSkipped then
                        local prompt = item:FindFirstChild("PickupPrompt", true) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                        local targetCF = getItemTargetCFrame(prompt, item)
                        if prompt and prompt.Enabled and targetCF then
                            local promptAction = tostring(prompt.ActionText or ""):lower()
                            local promptName   = tostring(prompt.Name or ""):lower()
                            local itemNameLower = tostring(item:GetAttribute("ItemName") or item:GetAttribute("Name") or item.Name):lower()

                            local isRealOreBox = itemNameLower:find("ore box") or itemNameLower:find("orebox")
                            local isBoxOpen = (not isRealOreBox) and (promptAction:find("open") or promptAction:find("unpack") or promptAction:find("search") 
                                           or promptName:find("open") or promptName:find("unpack") or (itemNameLower:find("box") and not itemNameLower:find("parts") and not isRealOreBox) or itemNameLower:find("crate"))
                            
                            local isRepair = promptAction:find("repair") or promptAction:find("fix") or promptAction:find("restore")
                                          or promptName:find("repair") or promptName:find("fix")
                            
                            local itemVal = (getPickupItemValue and getPickupItemValue(item)) or 1
                            local isGavelTrophy = itemNameLower:find("gavel") or itemNameLower:find("trophy")
                            local activeMinPickup = gConfig.minPickupValue or 0
                            local safeTier = getSafeTier(item)
                            local isSafe = (safeTier ~= nil)

                            -- Auto unload vehicle if overweight
                            if vehicle and isVehicleOverweight and isVehicleOverweight() then
                                if instantUnloadVehicle then pcall(function() instantUnloadVehicle(vehicle) end) end
                                task.wait(0.2)
                            end

                            pcall(function()
                                -- 1. BOX OPEN / UNPACK PROMPTS
                                if isBoxOpen and not isSafe then
                                    if not moveToPickupTarget(targetCF * CFrame.new(0, 1.5, 0)) then error("Pickup movement blocked: character still seated or unavailable") end
                                    task.wait(0.12)
                                    abLog("[Freight] Opening container box: " .. item.Name .. "...", Color3.fromRGB(255, 200, 80))
                                    if fireproximityprompt then
                                        fireproximityprompt(prompt, 0)
                                    else
                                        fireHoldPrompt(prompt)
                                    end
                                    itemsFound = itemsFound + 1
                                    dismissDiscoveryPopups()
                                    task.wait(math.max((prompt.HoldDuration or 0.4) + 0.3, 0.7))
                                    dismissDiscoveryPopups()

                                -- 2. REPAIR PROMPTS
                                elseif isRepair and not isSafe then
                                    equipWrenchTool()
                                    if not moveToPickupTarget(targetCF * CFrame.new(0, 1.5, 0)) then error("Pickup movement blocked: character still seated or unavailable") end
                                    task.wait(0.12)
                                    abLog("[Repair] Repairing item: " .. item.Name .. "...", Color3.fromRGB(150, 200, 255))
                                    if fireproximityprompt then
                                        fireproximityprompt(prompt, 0)
                                    else
                                        fireHoldPrompt(prompt)
                                    end
                                    task.wait(math.max((prompt.HoldDuration or 0.4) + 0.3, 0.7))
                                    dismissDiscoveryPopups()

                                    -- Unequip wrench so hands are free
                                    if hum then hum:UnequipTools() end
                                    task.wait(0.12)

                                    -- Prompt may update to 'Add to Vehicle' or 'Pickup'
                                    local p2 = item:FindFirstChild("PickupPrompt", true) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    if p2 and p2.Enabled then
                                        local a2 = tostring(p2.ActionText or ""):lower()
                                        if a2:find("vehicle") or a2:find("pickup") or a2:find("collect") or a2:find("add") or a2:find("take") then
                                            abLog("[Freight] Loading repaired item: " .. item.Name .. " into vehicle...", C.green)
                                            if fireproximityprompt then fireproximityprompt(p2, 0) else fireHoldPrompt(p2) end
                                            task.wait(gConfig.pickupDelay or 0.3)
                                        end
                                    end
                                    itemsFound = itemsFound + 1

                                    local stillPrompt = item:FindFirstChild("PickupPrompt", true) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    if stillPrompt and stillPrompt.Enabled and tostring(stillPrompt.ActionText or ""):lower():find("repair") then
                                        itemFails[item] = (itemFails[item] or 0) + 1
                                        if itemFails[item] >= 3 then
                                            abLog("[Warning] Could not repair " .. item.Name .. " (missing wrench or level). Skipping.", COLORS.Orange)
                                            _G.AHSkippedItems = _G.AHSkippedItems or {}
                                            _G.AHSkippedItems[item] = os.clock() + 25
                                        end
                                    end

                                -- 3. SAFES
                                elseif isSafe then
                                    local bestPlayerTier, bestToolId = getPlayerBestLockpick()
                                    local canCrack = (bestPlayerTier >= safeTier)
                                    if not moveToPickupTarget(targetCF * CFrame.new(0, 1.5, 0)) then error("Pickup movement blocked: character still seated or unavailable") end
                                    task.wait(0.12)

                                    if canCrack then
                                        abLog("Safecracker: Compatible lockpick found for " .. item.Name .. " (Tier " .. safeTier .. "). Cracking safe...", Color3.fromRGB(255, 215, 0))
                                        equipLockpickTool()
                                        task.wait(0.1)
                                        fireHoldPrompt(prompt)
                                        local cracked = solvePicklockMinigame(5.0)
                                        if cracked then
                                            itemsFound = itemsFound + 1
                                            abLog("Safecracker: " .. item.Name .. " unlocked! Rewards claimed.", C.green)
                                            if showWorkshopPopup then showWorkshopPopup("Safe Unlocked! Rewards Claimed.", C.green) end
                                        else
                                            abLog("[Warning] Safecracker: Lockpick attempt timed out for " .. item.Name .. ", stashing safe box.", COLORS.Orange)
                                            if hum then hum:UnequipTools() end
                                            task.wait(0.15)
                                            fireHoldPrompt(prompt)
                                            itemsFound = itemsFound + 1
                                        end
                                        if hum then hum:UnequipTools() end
                                        task.wait(gConfig.pickupDelay or 0.4)
                                    else
                                        if hum then hum:UnequipTools() end
                                        task.wait(0.1)
                                        abLog("[Freight] Stashing locked safe " .. item.Name .. " into vehicle (requires Tier " .. safeTier .. " lockpick).", Color3.fromRGB(255, 181, 61))
                                        itemsFound = itemsFound + 1
                                        if fireproximityprompt then fireproximityprompt(prompt, 0) else fireHoldPrompt(prompt) end
                                        task.wait(gConfig.pickupDelay or 0.4)
                                    end

                                -- 4. STANDARD LOOT (including Gavels & Item Rules)
                                elseif (function()
                                    local pickDec = evaluateItemRule and evaluateItemRule(item, "pickup")
                                    if pickDec == "deny" then return false end
                                    if pickDec == "allow" then return true end
                                    return isGavelTrophy or activeMinPickup <= 0 or itemVal >= activeMinPickup
                                end)() then
                                    -- Free hands if holding a tool so prompt isn't blocked
                                    for _, t in ipairs(char:GetChildren()) do
                                        if t:IsA("Tool") then
                                            hum:UnequipTools()
                                            task.wait(0.08)
                                            break
                                        end
                                    end
                                    if not moveToPickupTarget(targetCF * CFrame.new(0, 1.5, 0)) then error("Pickup movement blocked: character still seated or unavailable") end
                                    task.wait(0.1)
                                    itemsFound = itemsFound + 1
                                    abLog("Picking up: " .. item.Name, C.green)
                                    if fireproximityprompt then
                                        fireproximityprompt(prompt, 0)
                                    else
                                        fireHoldPrompt(prompt)
                                    end
                                    dismissDiscoveryPopups()
                                    task.wait(gConfig.pickupDelay or 0.3)
                                    dismissDiscoveryPopups()

                                    -- Check if item is still present and prompt enabled (pickup failed)
                                    local stillPrompt = item:FindFirstChild("PickupPrompt", true) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                    if stillPrompt and stillPrompt.Enabled then
                                        itemFails[item] = (itemFails[item] or 0) + 1
                                        if itemFails[item] >= 3 then
                                            abLog("[Warning] Pickup failed for " .. item.Name .. " (inaccessible). Skipping.", COLORS.Orange)
                                            _G.AHSkippedItems = _G.AHSkippedItems or {}
                                            _G.AHSkippedItems[item] = os.clock() + 25
                                        end
                                    end
                                else
                                    abLog("[Skip] Auto-Pickup: Skip cheap item " .. item.Name .. " ($" .. itemVal .. ")", C.textMuted)
                                end
                            end)
                        end
                    end
                end
            end
        end

        if itemsFound == 0 then
            consecutiveZeroChecks = consecutiveZeroChecks + 1
            if consecutiveZeroChecks >= 2 then
                abLog("All items picked up! Loot secured.", C.green)
                break
            else
                task.wait(0.5) -- grace delay for crate unpack animations
            end
        else
            consecutiveZeroChecks = 0
            task.wait(0.15)
        end
        pass = pass + 1
    end

    dismissDiscoveryPopups()

    if gConfig.seatedAutofarm then
        local finishedGarage = _G.AHLastTargetLot or lastTargetLot
        local wasSeized = (lastAuctionWasSeized == true)
            or (_G.AHLastAuctionWasSeized == true)
            or (currentGarageIsSeized == true) 
            or (_G.AHIsCurrentGarageSeized == true) 
            or (finishedGarage ~= nil and isGarageSeized and isGarageSeized(finishedGarage))
            or (hasWantedStars and hasWantedStars())
        
        if finishedGarage then
            local gKey = finishedGarage:GetAttribute("GUID") or finishedGarage.Name
            _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
            _G.AHGarageCooldowns[gKey] = os.clock() + (wasSeized and 180 or 120)
            abLog("⏱ Garage cooldown set: moving to next garage!", C.green)
            _G.AHLastTargetLot = nil
            lastTargetLot = nil
        end
        
        lastAuctionWasSeized = false
        _G.AHLastAuctionWasSeized = false
        currentGarageIsSeized = false
        _G.AHIsCurrentGarageSeized = false
    end

    _G.AHPickupCycleRunning = false
    AB.pickupPhase = false
    AB.weAreWinning = false
end
_G.runAutoPickupCycle = runAutoPickupCycle
_G.manualCollectWonItems = function()
    task.spawn(function()
        if runAutoPickupCycle then
            runAutoPickupCycle("Manual", true)
        end
    end)
end

-- Continuous background detector for won items sitting on the ground
if _G.AHCollectorThread then
    pcall(function() task.cancel(_G.AHCollectorThread) end)
end
_G.AHCollectorThread = task.spawn(function()
    while true do
        task.wait(1.5)
        if not _G.questTpInProgress and not _G.AHPickupCycleRunning and not AB.auctionOpen then
            if (gConfig.autoCollectWon == true) then
                local carryables = workspace:FindFirstChild("_Carryables")
                local hasOurItem = false
                if carryables then
                    for _, item in ipairs(carryables:GetChildren()) do
                        if belongsToUs(item) then
                            local isSkipped = _G.AHSkippedItems and _G.AHSkippedItems[item] and os.clock() < _G.AHSkippedItems[item]
                            if not isSkipped then
                                local prompt = item:FindFirstChild("PickupPrompt", true) or item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if prompt and prompt.Enabled then
                                    hasOurItem = true
                                    break
                                end
                            end
                        end
                    end
                end
                if hasOurItem then
                    task.spawn(function()
                        if runAutoPickupCycle then
                            runAutoPickupCycle("AutoDetector")
                        end
                    end)
                end
            end
        end
    end
end)
local function getMyLivePlot()
    local player = game:GetService("Players").LocalPlayer
    local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:GetAttribute("OwnerUserId") or p:GetAttribute("Owner") or p:GetAttribute("PlayerId") or p:GetAttribute("OwnerName") or p.Name
            if owner == player.UserId or tonumber(owner) == player.UserId or tostring(owner) == player.Name or tostring(owner):lower():find(player.Name:lower()) then
                return p
            end
        end
    end
    return nil
end

local function isNearMyPlot(maxDist)
    maxDist = maxDist or 150
    local player = game:GetService("Players").LocalPlayer
    local char = player and player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    -- Use plot origin attributes (always available, no forward reference needed)
    local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:GetAttribute("OwnerUserId") or p:GetAttribute("OwnerName")
            if owner == player.UserId or tonumber(owner) == player.UserId or tostring(owner) == player.Name then
                local ox = p:GetAttribute("OriginX")
                local oy = p:GetAttribute("OriginY")
                local oz = p:GetAttribute("OriginZ")
                if ox and oy and oz then
                    local pos = Vector3.new(tonumber(ox), tonumber(oy), tonumber(oz))
                    return (root.Position - pos).Magnitude <= maxDist
                end
                -- Fallback: try getMyLivePlotDrivewayCF if it exists
                if getMyLivePlotDrivewayCF then
                    local cf = getMyLivePlotDrivewayCF()
                    if cf then return (root.Position - cf.Position).Magnitude <= maxDist end
                end
                break
            end
        end
    end
    return false
end
_G.isNearMyPlot = isNearMyPlot

local cachedPlotCFrames = {}
local cachedMyPlotCF = nil

local function resolvePlotDrivewayCF(p)
    if not p then return nil end

    -- 0. Streaming-Proof Plot Origin Attributes (Guaranteed to exist on Plot Folder/Model)
    local ox = p:GetAttribute("OriginX")
    local oy = p:GetAttribute("OriginY")
    local oz = p:GetAttribute("OriginZ")
    local rotY = p:GetAttribute("RotationY") or 0
    if ox and oy and oz then
        return CFrame.new(tonumber(ox), tonumber(oy) + 4.5, tonumber(oz)) * CFrame.Angles(0, math.rad(tonumber(rotY) or 0), 0)
    end

    -- 1. Check Parking Space / Driveway Pad
    local parking = p:FindFirstChild("Parking Space", true) 
        or p:FindFirstChild("ParkingSpace", true) 
        or p:FindFirstChild("Driveway", true)
        or p:FindFirstChild("Parking", true)
    if parking then
        local pad = parking:FindFirstChild("Pad") or parking:FindFirstChild("Base") or parking.PrimaryPart or parking:FindFirstChildWhichIsA("BasePart")
        if pad then
            return pad.CFrame + Vector3.new(0, 4.5, 0)
        end
    end

    -- 2. Check UnpackZone (located on the front driveway)
    local unpackZone = p:FindFirstChild("UnpackZone", true)
    if unpackZone then
        local uzCF = unpackZone:IsA("Model") and unpackZone:GetPivot() or unpackZone.CFrame
        return uzCF + Vector3.new(0, 4.5, 0)
    end

    -- 3. Check Front Spawn / Entrance
    local spawnPart = p:FindFirstChild("Spawn", true) 
        or p:FindFirstChild("SpawnLocation", true) 
        or p:FindFirstChild("FrontDoor", true)
        or p:FindFirstChild("Entrance", true)
    if spawnPart and spawnPart:IsA("BasePart") then
        return spawnPart.CFrame + Vector3.new(0, 4.5, 0)
    end

    -- 4. Calculate Front from Base Floor (+75 studs forward in front of the building)
    local base = p:FindFirstChild("Base")
    local floor = base and (base:FindFirstChild("Floor") or base:FindFirstChildWhichIsA("BasePart")) or p:FindFirstChildWhichIsA("BasePart", true)
    if floor then
        return floor.CFrame * CFrame.new(0, 5, 75)
    end

    return nil
end

local function updatePlotCache()
    pcall(function()
        local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
        if plots then
            for _, p in ipairs(plots:GetChildren()) do
                local frontCF = resolvePlotDrivewayCF(p)
                if frontCF then
                    local num = tonumber(p.Name:match("%d+"))
                    if num then
                        cachedPlotCFrames[num] = frontCF
                    end
                    local owner = p:GetAttribute("OwnerUserId") or p:GetAttribute("Owner") or p:GetAttribute("PlayerId") or p:GetAttribute("OwnerName") or p.Name
                    if owner == LocalPlayer.UserId or tonumber(owner) == LocalPlayer.UserId or tostring(owner) == LocalPlayer.Name or tostring(owner):lower():find(LocalPlayer.Name:lower()) then
                        -- Only auto-fill cachedMyPlotCF if the user has NOT manually saved a driveway
                        -- Once savedPlotDriveway is set by the user, respect it and don't overwrite
                        if not gConfig.savedPlotDriveway then
                            cachedMyPlotCF = frontCF
                            _G.AHScanner_UnpackCF = frontCF
                            gConfig.savedPlotDriveway = frontCF
                            gConfig.savedPlotName = p.Name
                        end
                    end
                end
            end
        end
    end)
end

task.spawn(function()
    updatePlotCache()
    while true do
        task.wait(2.0)
        if _G.AHScanner_RunID ~= myRunID then break end
        updatePlotCache()
    end
end)

local function getMyLivePlotDrivewayCF()
    -- 1. ALWAYS prefer the user's manually saved driveway position
    if gConfig.savedPlotDriveway then
        if typeof(gConfig.savedPlotDriveway) == "CFrame" then
            cachedMyPlotCF = gConfig.savedPlotDriveway
            _G.AHScanner_UnpackCF = gConfig.savedPlotDriveway
            return gConfig.savedPlotDriveway
        elseif type(gConfig.savedPlotDriveway) == "table" and #gConfig.savedPlotDriveway == 12 then
            local cf = CFrame.new(unpack(gConfig.savedPlotDriveway))
            gConfig.savedPlotDriveway = cf
            cachedMyPlotCF = cf
            _G.AHScanner_UnpackCF = cf
            return cf
        end
    end

    -- 2. Fall back to the auto-resolved cache from updatePlotCache()
    updatePlotCache()
    if cachedMyPlotCF then
        return cachedMyPlotCF
    end

    -- 3. Last resort: scan workspace directly
    local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
    local myPlot = nil
    if plots then
        for _, p in ipairs(plots:GetChildren()) do
            local owner = p:GetAttribute("OwnerUserId") or p:GetAttribute("Owner") or p:GetAttribute("PlayerId") or p:GetAttribute("OwnerName") or p.Name
            if owner == LocalPlayer.UserId or tonumber(owner) == LocalPlayer.UserId or tostring(owner) == LocalPlayer.Name or tostring(owner):lower():find(LocalPlayer.Name:lower()) then
                myPlot = p
                break
            end
        end
    end

    if myPlot then
        local frontCF = resolvePlotDrivewayCF(myPlot)
        if frontCF then
            cachedMyPlotCF = frontCF
            _G.AHScanner_UnpackCF = frontCF
            -- Only auto-save if there's still no manual save
            if not gConfig.savedPlotDriveway then
                gConfig.savedPlotDriveway = frontCF
                gConfig.savedPlotName = myPlot.Name
            end
            return frontCF
        end
    end

    return cachedMyPlotCF
end

local function teleportToMyPlot()
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local targetCF = getMyLivePlotDrivewayCF()
        if targetCF then
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            local vehicle = seat and seat.Parent
            if vehicle and vehicle:IsA("Model") then
                vehicle:PivotTo(targetCF + Vector3.new(0, 2, 0))
                task.wait(0.2)
                if hum and seat and hum.SeatPart ~= seat then
                    seat:Sit(hum)
                end
            else
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    root.CFrame = targetCF + Vector3.new(0, 2, 0)
                end
            end
        end
    end)
end

-- [Target] TARGET ITEM & COW SCANNER HELPER
-- MeshId lookup cache: built by preloading ALL items from ItemsData
local gMeshIdToName = nil   -- set once ItemPreviewCache is populated
local gItemPreloadDone = false

local function ensureItemsPreloaded()
    if gItemPreloadDone then return end
    gItemPreloadDone = true -- prevent double-run
    task.spawn(function()
        local ok, ItemLoader = pcall(function()
            return require(ReplicatedStorage.Modules.ItemLoader)
        end)
        if not ok or not ItemLoader then return end
        
        -- Collect all item names from ItemsData
        local names = {}
        if ItemsData then
            for _, data in pairs(ItemsData) do
                if data.Name and data.Category ~= "Vehicles" and data.Category ~= "Furniture" then
                    table.insert(names, data.Name)
                end
            end
        end
        
        -- Preload all items (yields until server responds)
        if #names > 0 then
            pcall(function() ItemLoader:PreloadItems(names) end)
        end
        
        -- Build MeshId → name lookup from ItemPreviewCache
        local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
        local cache = pg and pg:FindFirstChild("ItemPreviewCache")
        if cache then
            local lookup = {}
            for _, model in ipairs(cache:GetChildren()) do
                for _, desc in ipairs(model:GetDescendants()) do
                    if desc:IsA("MeshPart") and desc.MeshId ~= "" then
                        local stripped = desc.MeshId:gsub("rbxassetid://", "")
                        if not lookup[stripped] then
                            lookup[stripped] = model.Name
                        end
                    end
                end
            end
            gMeshIdToName = lookup
        end
    end)
end

-- Start preloading immediately when script runs
ensureItemsPreloaded()

local function isValidGarageItem(obj)
    if not obj or not obj.Parent then return false end
    if not (obj:IsA("Model") or obj:IsA("BasePart")) then return false end
    
    local name = obj.Name
    local class = obj.ClassName
    
    if class == "WeldConstraint" or class == "Weld" or class == "Attachment" or class == "Motor6D" or class == "Highlight" or class == "SurfaceLight" or class == "PointLight" or class == "SpotLight" then
        return false
    end
    if name == "Floorspace" or name == "Base" or name == "Parts" or name == "Blocker" or name == "EntrySquare" or name == "NPCSpawns" or name == "Auctioneer" then
        return false
    end
    if name == "Door" or name == "Left" or name == "Right" or name == "DoorBase" or name == "Button" or name:find("Weld") or name:find("Constraint") or name:find("Light") then
        return false
    end
    
    return true
end

local function resolveGarageItemName(itemModel)
    if not itemModel then return "Storage Item" end
    
    local rawName = itemModel.Name
    
    -- 1. If model already has an actual item name (not "Model"), use it directly
    if rawName ~= "Model" and rawName ~= "Part" and rawName ~= "MeshPart" and rawName ~= "Base" and rawName ~= "Parts" and not rawName:find("Weld") then
        return rawName
    end
    
    -- 2. Check ItemId attribute → look up in ItemsData
    local itemId = itemModel:GetAttribute("ItemId")
    if itemId and ItemsData then
        local conf = ItemsData[tostring(itemId)] or ItemsData[tonumber(itemId)]
        if conf and conf.Name then return conf.Name end
    end
    
    -- 3. Use MeshId → name lookup from ItemPreviewCache
    if gMeshIdToName then
        for _, desc in ipairs(itemModel:GetDescendants()) do
            if desc:IsA("MeshPart") and desc.MeshId ~= "" then
                local stripped = desc.MeshId:gsub("rbxassetid://", "")
                local found = gMeshIdToName[stripped]
                if found then return found end
            end
        end
    end
    
    -- 4. Check descendants for any known item name
    if ItemsData then
        for _, desc in ipairs(itemModel:GetDescendants()) do
            local dName = desc.Name
            if dName ~= "Model" and dName ~= "Part" and dName ~= "MeshPart" and dName ~= "Base" and dName ~= "Parts" and not dName:find("Weld") and not dName:find("Meshes/") and not dName:find("Cube") and not dName:find("Cylinder") then
                for id, it in pairs(ItemsData) do
                    if it.Name and it.Name:lower() == dName:lower() then
                        return it.Name
                    end
                end
            end
        end
    end
    
    return "Storage Item"
end

local function findAuctionTargetItem()
    local targetList = gConfig.targetItemsList or { ["Cow"] = true }
    
    local debris = workspace:FindFirstChild("_Debris")
    local garages = debris and debris:FindFirstChild("Garages")
    local activeGarage = nil
    
    if garages then
        for _, g in ipairs(garages:GetChildren()) do
            if g:GetAttribute("InAuction") == true then
                activeGarage = g
                break
            end
        end
    end
    
    if not activeGarage and garages then
        local lp = Players.LocalPlayer
        local char = lp and lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root then
            local closestDist = 70
            for _, g in ipairs(garages:GetChildren()) do
                local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
                if p then
                    local d = (p.Position - root.Position).Magnitude
                    if d < closestDist then
                        closestDist = d
                        activeGarage = g
                    end
                end
            end
        end
    end
    
    if activeGarage then
        local floor = activeGarage:FindFirstChild("Floorspace")
        local rawItems = floor and floor:GetChildren() or {}
        for _, item in ipairs(rawItems) do
            if isValidGarageItem(item) then
                local itemId = item:GetAttribute("ItemId")
                local resolvedName = resolveGarageItemName(item)
                
                -- Cow detection (ID 765 or name match)
                if itemId == 765 or resolvedName:lower():find("cow") or (targetList["Cow"] and resolvedName:lower() == "cow") then
                    return true, "Cow", item
                end
                
                -- Custom targets
                for targetName, isEn in pairs(targetList) do
                    if isEn and targetName ~= "" and targetName ~= "Cow" then
                        if resolvedName:lower():find(targetName:lower()) or (itemId and tostring(itemId) == tostring(targetName)) then
                            return true, targetName, item
                        end
                    end
                end
            end
        end
    end
    
    return false, nil, nil
end
local function startBidLoop()
    if gConfig.quickWinAuction and AB.quickWinHandled ~= false then return end
    local isAllowedToBid = (AB.enabled == true and gConfig.autoBidEnabled == true)
    if not isAllowedToBid then return end
    stopBidLoop()
    if not BidRemote then abLog("[X] Bid remote not found", C.red); AB.enabled = false; if updateToggleBtn then updateToggleBtn() end; return end
    
    if AB.minBidBlocked then
        abLog("Bid blocked: below min $" .. AB.minStartBid, Color3.fromRGB(255,140,60))
        return
    end

    AB.bidsThisRound = 0
    abLog("BidLoop armed: spd=" .. AB.speed .. "s", C.green)
    bidThread = task.spawn(function()
        local isExplicitlySelected = gConfig.afSelectedGarages and AB.activeLot and (gConfig.afSelectedGarages[AB.activeLot] == true)
        local isAirdrop = AB.activeLot and (string.find(AB.activeLot, "Airdrop") or AB.activeLot == "Camo Airdrop")
        local bypassMinBid = isAirdrop and (gConfig.alwaysCollectAirdrop == true)
        if AB.minStartBid > 0 and not isExplicitlySelected and not bypassMinBid then
            local waited = 0
            while AB.auctionJustOpened and waited < 1.0 do
                task.wait(0.05)
                waited = waited + 0.05
            end
            if AB.currentBid > 0 and AB.currentBid < AB.minStartBid then
                AB.minBidBlocked = true
                AB.auctionOpen  = false
                AB.biddingUIOpen = false
                AB.activeLot = nil
                AB.activeLotData = nil
                AB.activeGarageInstance = nil
                if LeaveAuctionRemote then task.spawn(requestLeaveAuction, LeaveAuctionRemote) end
                abLog(string.format("[Skipped] opening $%d < min $%d", AB.currentBid, AB.minStartBid), Color3.fromRGB(255,140,60))
                return
            end
        end

        while (AB.enabled == true and gConfig.autoBidEnabled == true) and AB.auctionOpen do
            if gConfig.quickWinAuction and AB.quickWinHandled ~= false then return end
            -- Smart Bid Guard: Only bid if we are NOT currently winning
            if not AB.weAreWinning then
                local ok = pcall(function() BidRemote:FireServer() end)
                if ok then 
                    AB.bidsThisRound = AB.bidsThisRound + 1 
                else 
                    abLog("[X] Bid failed", C.red) 
                end
            end
            task.wait(AB.speed)
        end
    end)
end
-- ═════════════════════════════════════════════════════
-- Mutually exclusive bid modes, shared by UI and saved-profile loading.
do
    local installBiddingModes = (function()
-- One place for user clicks, profile loads and programmatic mode changes.
return function(context)
    local config, state = context.config, context.state
    local controller = {visuals = {}, quick = false, auto = false}

    function controller.ParseMinimum(value)
        local text = tostring(value or ""):gsub("[,%s]", "")
        local number = tonumber(text)
        if not number or number ~= number or number == math.huge or number == -math.huge or number < 0 then return nil end
        return number
    end

    local function paint()
        local quick = controller.visuals.quickWinAuction
        local auto = controller.visuals.autoBidEnabled
        if quick then quick(config.quickWinAuction == true) end
        if auto then auto(config.autoBidEnabled == true) end
    end

    local function apply(persist)
        local quick = config.quickWinAuction == true
        local auto = config.autoBidEnabled == true
        if quick then auto = false end
        config.quickWinAuction, config.autoBidEnabled = quick, auto
        config.quickWinMinStartBid = controller.ParseMinimum(config.quickWinMinStartBid) or 0
        local changed = quick ~= controller.quick or auto ~= controller.auto
        local wasQuick = controller.quick
        controller.quick, controller.auto = quick, auto
        state.enabled = auto

        if changed then
            if context.stopBidding then context.stopBidding() end
            -- Release any pause and return inside before allowing the other bid mode to run.
            if wasQuick and not quick and state.quickWinController then
                state.quickWinController:Cancel("Quick Win disabled; pause released.", false)
            end
            state.quickWinActive = false
            state.quickWinMinBidBlocked = false
            state.minBidBlocked = false
            if quick then state.quickWinHandled = nil end
        end
        paint()
        if changed and auto and state.auctionOpen and context.startBidding then context.startBidding() end
        if persist and context.save then context.save() end
    end

    function controller:Set(mode, enabled, persist)
        assert(mode == "quickWinAuction" or mode == "autoBidEnabled", "Unknown bidding mode")
        config[mode] = enabled == true
        if enabled then
            if mode == "quickWinAuction" then config.autoBidEnabled = false
            else config.quickWinAuction = false end
        end
        apply(persist ~= false)
    end

    function controller:RegisterVisual(mode, updater)
        self.visuals[mode] = updater
        paint()
    end

    function controller:ApplySaved()
        -- Deterministic migration if an older profile has both modes enabled.
        if config.quickWinAuction == true then config.autoBidEnabled = false end
        apply(false)
    end

    controller:ApplySaved()
    return controller
end

    end)()
    AB.modeRunID = myRunID
    AB.biddingModes = installBiddingModes({
        state = AB, config = gConfig, stopBidding = stopBidLoop, startBidding = startBidLoop, save = saveConfig,
    })
end

-- VALUE CALCULATION (FIXED REVERSE LOOKUP FOR NAMES)
-- ═════════════════════════════════════════════════════
local function getItemData(identifier)
    if not ItemsData or type(ItemsData) ~= "table" then return "Unknown", 0, "Common" end
    
    local identifierStr = tostring(identifier)
    
    -- 1. Try direct lookup
    if ItemsData[identifierStr] then
        local d = ItemsData[identifierStr]
        return (d.Name or d.name or identifierStr), tonumber(d.BasePrice or d.basePrice or d.Value or d.value) or 0, (d.Rarity or d.rarity or "Common")
    end
    
    -- 2. Reverse lookup by ID or Name
    for id, v in pairs(ItemsData) do
        if type(v) == "table" then
            local name = v.Name or v.name or ""
            if tostring(id) == identifierStr or tostring(v.Id or v.id) == identifierStr or name == identifierStr or name:lower() == identifierStr:lower() then
                return name, tonumber(v.BasePrice or v.basePrice or v.Value or v.value) or 0, (v.Rarity or v.rarity or "Common")
            end
        end
    end
    
    return identifierStr, 0, "Common"
end

local function calcItemValue(itemName, rarity, mutator, grade, condition)
    local realName, base, baseRar = getItemData(itemName)
    
    -- Override missing/default rarity with the actual module rarity
    if (not rarity or rarity == "Common") and baseRar and baseRar ~= "Common" then
        rarity = baseRar
    end
    
    if base <= 0 then
        local rarityFallbacks = { Common=15, Uncommon=35, Rare=80, Epic=200, Legendary=500, Mythical=1200, Exclusive=3000 }
        base = rarityFallbacks[rarity] or 15
    end
    
    local mMult     = MUTATOR_MULT[mutator]  or 1
    local gMult     = GRADE_MULT[tonumber(grade)] or 1.0
    local cMult     = CONDITION_MULT[condition]    or 1.0
    
    return realName, math.floor(base * mMult * gMult * cMult), rarity
end

getPickupItemValue = function(itemModel)
    -- Floor items in _Carryables only have ItemId and Condition attributes.
    -- Rarity, Grade, Mutators are assigned SERVER-SIDE at pickup and are NOT
    -- available on the physical model. So we use catalog BasePrice as the
    -- estimate to correctly filter cheap junk vs. valuable items.
    if not itemModel then return 0 end
    
    local itemId = itemModel:GetAttribute("ItemId")
    local basePart = itemModel.PrimaryPart or itemModel:FindFirstChild("Base")
    if basePart and not itemId then
        itemId = basePart:GetAttribute("ItemId")
    end
    
    -- If ItemId is present, look it up directly in the catalog
    if itemId and ItemsData then
        local idStr = tostring(itemId)
        local entry = ItemsData[idStr]
        if entry and type(entry) == "table" then
            local base = tonumber(entry.BasePrice or entry.basePrice or 0)
            if base and base > 0 then
                return base
            end
        end
        -- Also try numeric key
        local entry2 = ItemsData[tonumber(itemId)]
        if entry2 and type(entry2) == "table" then
            local base = tonumber(entry2.BasePrice or entry2.basePrice or 0)
            if base and base > 0 then
                return base
            end
        end
    end
    
    -- Fallback: look up by model name
    local itemName = itemModel.Name
    local _, calcPrice = calcItemValue(itemName, "Common", "None", nil, nil)
    return calcPrice or 0
end

-- ═════════════════════════════════════════════════════
-- WORKSPACE SCANNER
-- ═════════════════════════════════════════════════════
local SCAN_RADIUS = 50
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
    
    local realName, calcPrice, finalRarity = calcItemValue(attrs.itemName, attrs.rarity, attrs.mutator, attrs.grade, attrs.condition)
    attrs.displayName = realName
    attrs.rarity = finalRarity
    
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
                    -- Skip user-excluded items
                    if not isItemExcluded(info.displayName) then
                        info.distance = math.floor(dist)
                        info.model = desc
                        table.insert(items, info)
                    end
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
                local hasUranium = false
        for _, it in ipairs(scannedItems) do
            if it.displayName and string.find(it.displayName:lower(), "uranium") then
                hasUranium = true
                break
            end
        end
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
-- ═════════════════════════════════════════════════════
-- RAYFIELD STYLE UI IMPLEMENTATION (NO EMOJIS, NO SCANNER)
-- ═════════════════════════════════════════════════════

COLORS = {
    BG           = Color3.fromRGB(19, 19, 21),
    Sidebar      = Color3.fromRGB(23, 23, 26),
    TabBtnActive = Color3.fromRGB(30, 30, 35),
    Card         = Color3.fromRGB(26, 26, 30),
    CardHover    = Color3.fromRGB(33, 33, 38),
    Border       = Color3.fromRGB(38, 38, 42),
    Accent       = Color3.fromRGB(0, 125, 255), -- Rayfield Neon Blue
    Text         = Color3.fromRGB(240, 240, 240),
    TextDim      = Color3.fromRGB(160, 160, 165),
    Green        = Color3.fromRGB(46, 204, 113),
    Red          = Color3.fromRGB(231, 76, 60),
    Gold         = Color3.fromRGB(245, 190, 70),
    Purple       = Color3.fromRGB(150, 100, 255),
    Orange       = Color3.fromRGB(240, 140, 60),
}

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
local function tw(inst, sec, props, style, dir) 
    local info = TweenInfo.new(sec, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out) 
    pcall(function() local t = TweenService:Create(inst, info, props); t:Play() end)
end

local function makeHoverable(card, defaultBg, hoverBg, defaultStrokeCol, hoverStrokeCol)
    defaultBg = defaultBg or C.card
    hoverBg = hoverBg or Color3.fromRGB(28, 42, 68)
    defaultStrokeCol = defaultStrokeCol or C.border
    hoverStrokeCol = hoverStrokeCol or Color3.fromRGB(90, 200, 255)

    card.Active = true
    local cardStroke = card:FindFirstChildOfClass("UIStroke") or stroke(1, defaultStrokeCol, card)

    local hoverCount = 0
    local function onEnter()
        hoverCount = hoverCount + 1
        if hoverCount == 1 then
            tw(cardStroke, 0.16, { Color = hoverStrokeCol, Thickness = 1.8 })
            tw(card, 0.16, { BackgroundColor3 = hoverBg })
        end
    end

    local function onLeave()
        hoverCount = math.max(0, hoverCount - 1)
        if hoverCount == 0 then
            tw(cardStroke, 0.16, { Color = defaultStrokeCol, Thickness = 1 })
            tw(card, 0.16, { BackgroundColor3 = defaultBg })
        end
    end

    card.MouseEnter:Connect(onEnter)
    card.MouseLeave:Connect(onLeave)

    local function attachChild(child)
        if child:IsA("GuiButton") or child:IsA("TextBox") then
            child.MouseEnter:Connect(onEnter)
            child.MouseLeave:Connect(onLeave)
        end
    end

    for _, child in ipairs(card:GetDescendants()) do attachChild(child) end
    card.DescendantAdded:Connect(attachChild)

    return cardStroke
end
local function fm(num) return num >= 1000 and string.format("$%.1fk", num/1000) or string.format("$%d", num) end

-- Clean previous instances safely
pcall(function()
    for _, v in ipairs(TargetGui:GetChildren()) do
        if v.Name == "AHScanner" then v:Destroy() end
    end
end)

-- ScreenGui Setup
local ScreenGui = make("ScreenGui", {
    Name="AHScanner", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling, IgnoreGuiInset=true,
}, TargetGui)

-- ── FLOATING PILL TOGGLE BAR (NexWorks Authentic Style - Concept 1 Crystal N) ──
local FloatingPill = make("TextButton", {
    Name = "FloatingPill",
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.new(0, 138, 0, 34),
    Position = UDim2.new(0.5, 0, 0, 15),
    BackgroundColor3 = Color3.fromRGB(10, 14, 22),
    BackgroundTransparency = 0.15,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 999999,
    Active = true,
}, ScreenGui)
corner(17, FloatingPill)
local pillStroke = stroke(1.5, Color3.fromRGB(0, 200, 255), FloatingPill)
local pillGrad = make("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 215, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 135, 255))
    }),
    Rotation = 45,
}, pillStroke)

-- Drag Handle Container (Left side)
local DragGrip = make("Frame", {
    Name = "DragGrip",
    Size = UDim2.new(0, 34, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 1000000,
}, FloatingPill)

-- 4-Way Move Icon (Electric Blue Arrow, perfectly centered)
local MoveIcon = make("ImageLabel", {
    Name = "MoveIcon",
    Size = UDim2.new(0, 16, 0, 16),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundTransparency = 1,
    Image = "rbxassetid://116138709011735",
    ImageColor3 = Color3.fromRGB(0, 185, 255),
    ZIndex = 1000001,
}, DragGrip)

-- Vertical Divider Line (centered)
local Divider = make("Frame", {
    Name = "Divider",
    Size = UDim2.new(0, 1, 0, 16),
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 34, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.8,
    BorderSizePixel = 0,
    ZIndex = 1000000,
}, FloatingPill)

-- Brand Container (Right side, auto-aligned with UIListLayout)
local BrandContainer = make("Frame", {
    Name = "BrandContainer",
    Size = UDim2.new(1, -42, 1, 0),
    Position = UDim2.new(0, 42, 0, 0),
    BackgroundTransparency = 1,
    ZIndex = 1000000,
}, FloatingPill)

local brandLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 7),
}, BrandContainer)

-- NexWorks Official Concept 1 Crystal 'N' Logo (Prominent 20x20px tightly cropped)
local BrandIcon = make("ImageLabel", {
    Name = "BrandIcon",
    LayoutOrder = 1,
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundTransparency = 1,
    Image = "rbxassetid://10723374276", -- Sleek tech fallback
    ImageColor3 = Color3.fromRGB(0, 185, 255),
    ZIndex = 1000001,
}, BrandContainer)

-- Auto-load custom NexWorks Crystal N asset if present in executor workspace
do
local crystalPaths = {
    "NexHub/nexworks_crystal_tight_v2.png",
    "nexworks_crystal_tight_v2.png",
    "NexHub/nexworks_crystal_tight.png",
    "nexworks_crystal_tight.png",
    "NexHub/nexworks_crystal_n.png",
    "nexworks_crystal_n.png",
    "NexHub/nexworks_icon.png",
    "nexworks_icon.png",
}
if getcustomasset and isfile then
    for _, cPath in ipairs(crystalPaths) do
        if isfile(cPath) then
            pcall(function()
                BrandIcon.Image = getcustomasset(cPath)
                BrandIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            end)
            break
        end
    end
end

-- Title Label ("NexWorks", cleanly spaced with zero kerning overlap)
local PillTitleLabel = make("TextLabel", {
    Name = "PillTitleLabel",
    LayoutOrder = 2,
    AutomaticSize = Enum.AutomaticSize.X,
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "NexWorks",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 14,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1000001,
}, BrandContainer)
end

local MobileToggle = FloatingPill

local NextGarageToggle = make("TextButton", {
    Name = "NextGarageToggle",
    AnchorPoint = Vector2.new(0.5, 0),
    Size = UDim2.new(0, 48, 0, 48),
    Position = UDim2.new(0.5, 0, 0, 55),
    BackgroundColor3 = COLORS.Sidebar,
    Text = "Next",
    TextSize = 12,
    Font = Enum.Font.MontserratBold,
    TextColor3 = C.green,
    ZIndex = 999999,
    Active = true,
    AutoButtonColor = false,
    Visible = gConfig.autoBuyStorages,
}, ScreenGui)
corner(99, NextGarageToggle); stroke(2, C.green, NextGarageToggle)
local NextGarageScale = Instance.new("UIScale", NextGarageToggle)
NextGarageScale.Scale = gConfig.autoBuyStorages and 1 or 0

-- ── GARAGE SCANNER HELPER (POPUP REMOVED) ───────────────────
local function updateGarageScannerHUD(garageName, itemsList, hasTargetItem)
    -- GUI Popup disabled per user request
end

local function animateNextButton(visible)
    if visible then
        NextGarageToggle.Visible = true
        tw(NextGarageScale, 0.5, {Scale = 1}, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    else
        tw(NextGarageScale, 0.5, {Scale = 0}, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
        task.delay(0.5, function()
            if not gConfig.autoBuyStorages then
                NextGarageToggle.Visible = false
            end
        end)
    end
end

do
    local FloatingCollectBtn = make("TextButton", {
        Name = "FloatingCollectBtn",
        AnchorPoint = Vector2.new(0.5, 0),
        Size = UDim2.new(0, 82, 0, 34),
        Position = UDim2.new(0.5, 78, 0, 58),
        BackgroundColor3 = COLORS.Sidebar,
        Text = "Collect",
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextColor3 = C.green,
        ZIndex = 999999,
        Active = true,
        AutoButtonColor = false,
        Visible = (gConfig.showFloatingCollect == true),
    }, ScreenGui)
    corner(17, FloatingCollectBtn); stroke(2, C.green, FloatingCollectBtn)
    local FloatingCollectScale = Instance.new("UIScale", FloatingCollectBtn)
    FloatingCollectScale.Scale = (gConfig.showFloatingCollect == true) and 1 or 0

    local function animateCollectButton(visible)
        if visible then
            FloatingCollectBtn.Visible = true
            tw(FloatingCollectScale, 0.35, {Scale = 1}, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        else
            tw(FloatingCollectScale, 0.3, {Scale = 0}, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
            task.delay(0.3, function()
                if gConfig.showFloatingCollect ~= true then
                    FloatingCollectBtn.Visible = false
                end
            end)
        end
    end
    _G.animateCollectButton = animateCollectButton
    local UserInputService = game:GetService("UserInputService")
    local fcDragging, fcDragged, fcDragStart, fcStartPos = false, false, nil, nil
    FloatingCollectBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            fcDragging = true
            fcDragged = false
            fcDragStart = inp.Position
            fcStartPos = FloatingCollectBtn.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    fcDragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if fcDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            local delta = inp.Position - fcDragStart
            if delta.Magnitude > 5 then
                fcDragged = true
                FloatingCollectBtn.Position = UDim2.new(fcStartPos.X.Scale, fcStartPos.X.Offset + delta.X, fcStartPos.Y.Scale, fcStartPos.Y.Offset + delta.Y)
            end
        end
    end)
    FloatingCollectBtn.MouseButton1Click:Connect(function()
        if fcDragged then return end
        tw(FloatingCollectBtn, 0.1, {Size = UDim2.new(0, 90, 0, 30)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        task.delay(0.1, function()
            tw(FloatingCollectBtn, 0.3, {Size = UDim2.new(0, 82, 0, 34)}, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
        end)
        FloatingCollectBtn.Text = "Collecting..."
        FloatingCollectBtn.TextColor3 = C.gold
        task.spawn(function()
            if _G.runAutoPickupCycle then
                _G.runAutoPickupCycle("Manual", true)
            end
            FloatingCollectBtn.Text = "Collect"
            FloatingCollectBtn.TextColor3 = C.green
        end)
    end)
end

-- Teleport Logic for Next Button
local lastVisitedGarage = nil
NextGarageToggle.MouseButton1Click:Connect(function()
    tw(NextGarageToggle, 0.12, {Size = UDim2.new(0, 58, 0, 34)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    task.delay(0.12, function()
        tw(NextGarageToggle, 0.45, {Size = UDim2.new(0, 48, 0, 48)}, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
    end)
    
    pcall(function()
        local hasAnySelected = false
        if gConfig.selectedGarages then
            for _, v in pairs(gConfig.selectedGarages) do
                if v == true then hasAnySelected = true; break end
            end
        end
        
        local targetGarages = {}
        for name, conf in pairs(GARAGE_CATALOG) do
            local selectedOk = (not hasAnySelected) or (gConfig.selectedGarages and gConfig.selectedGarages[name] == true)
            local areaOk = true
            if not hasAnySelected then
                local targetArea = gConfig.autoBuyArea
                local targetAreas = gConfig.autoBuyAreas
                if targetAreas and not targetAreas["Any Area"] then
                    areaOk = targetAreas[conf.area] == true
                elseif targetArea and targetArea ~= "Any Area" then
                    areaOk = (conf.area == targetArea)
                end
            end
            if areaOk and selectedOk then
                targetGarages[name] = conf
            end
        end
        
        local debris = workspace:FindFirstChild("_Debris")
        local garagesFolder = debris and debris:FindFirstChild("Garages")
        if not garagesFolder then return end
        
        local list = {}
        for _, garage in ipairs(garagesFolder:GetChildren()) do
            local matched = false
            for gName, conf in pairs(targetGarages) do
                if garage.Name == gName then
                    matched = true
                    break
                end
            end
            if matched then
                table.insert(list, garage)
            end
        end
        
        table.sort(list, function(a, b) return a.Name < b.Name end)
        if #list == 0 then return end
        
        local nextIndex = 1
        if lastVisitedGarage then
            for i, g in ipairs(list) do
                if g == lastVisitedGarage then
                    nextIndex = (i % #list) + 1
                    break
                end
            end
        end
        
        local targetGarage = list[nextIndex]
        if targetGarage then
            local isTrainGarage = (targetGarage:GetAttribute("AreaName") == "Cargo Train") or string.find(targetGarage.Name, "Train")
            if isTrainGarage then
                local Lighting = game:GetService("Lighting")
                local trainPhase = Lighting:GetAttribute("CargoTrainPhase")
                if trainPhase ~= "Stopped" then
                    abLog("[Train] Cargo Train is in transit (" .. tostring(trainPhase or "Moving") .. "). Wait for train to stop at station!", C.orange)
                    showWorkshopPopup("Cargo Train is moving! Wait for it to stop.", C.orange)
                    return
                end
            end

            lastVisitedGarage = targetGarage
            
            local targetCF = getGarageEntranceCFrame(targetGarage)
            if targetCF then
                safeTP(targetCF)
                abLog("TP: " .. targetGarage.Name, C.green)
            
            task.spawn(function()
                local foundPrompt = nil
                for attempt = 1, 10 do
                    task.wait(0.3)
                    local pPart = (targetGarage:FindFirstChild("EntrySquare") and targetGarage.EntrySquare:FindFirstChild("PromptPart"))
                        or targetGarage:FindFirstChild("PromptPart", true)
                    local prompt = (pPart and pPart:FindFirstChild("EnterAuction")) or targetGarage:FindFirstChild("EnterAuction", true)
                    if prompt and prompt.Enabled then
                        foundPrompt = prompt
                        break
                    end
                end
                if foundPrompt then
                    pcall(function()
                        foundPrompt.RequiresLineOfSight = false
                        foundPrompt.MaxActivationDistance = 30
                    end)
                    if fireproximityprompt then
                        pcall(function() fireproximityprompt(foundPrompt, 0) end)
                    end
                end
            end)
            end
        end
    end)
end)

-- Floating Pill Dragging & UI Visibility
local togDragActive, togDragStart, togStartPos, togMoved = false, nil, nil, false
FloatingPill.InputBegan:Connect(function(inp)
    if isTouchOrClick(inp) then 
        togDragActive = true
        togDragStart = inp.Position
        togStartPos = FloatingPill.Position
        togMoved = false
    end
end)
table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
    if togDragActive and (inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = inp.Position - togDragStart
        if delta.Magnitude > 5 then togMoved = true end
        FloatingPill.Position = UDim2.new(togStartPos.X.Scale, togStartPos.X.Offset + delta.X, togStartPos.Y.Scale, togStartPos.Y.Offset + delta.Y)
        NextGarageToggle.Position = UDim2.new(FloatingPill.Position.X.Scale, FloatingPill.Position.X.Offset, FloatingPill.Position.Y.Scale, FloatingPill.Position.Y.Offset + 42)
    end
end))
-- Global InputEnded handler to ensure drag stops even if mouse/finger leaves the button boundary
table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        togDragActive = false
    end
end))

local uiIsVisible = true
local lastSize = UDim2.new(0, 520, 0, 360)
local function toggleUI(targetWin, state)
    if state == nil then state = not uiIsVisible end
    if state == uiIsVisible then return end
    uiIsVisible = state
    if not state then
        if targetWin.Size.X.Offset > 100 then
            lastSize = targetWin.Size
        end
        tw(targetWin, 0.35, {Size = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.delay(0.35, function() targetWin.Visible = false; targetWin.Active = false; targetWin.BackgroundTransparency = 1 end)
    else
        if lastSize.X.Offset < 100 then
            lastSize = UDim2.new(0, 520, 0, 360)
        end
        targetWin.Visible = true
        targetWin.Active = true
        tw(targetWin, 0.45, {Size = lastSize}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        task.delay(0.1, function() targetWin.BackgroundTransparency = 0 end)
    end
end

-- RAYFIELD FRAME (520x360)
local Win = make("Frame", {
    Name="Win", AnchorPoint=Vector2.new(0.5,0.5),
    Position=UDim2.new(0.5,0,0.5,0),
    Size=UDim2.new(0, 520, 0, 360),
    BackgroundColor3=Color3.fromRGB(12, 14, 20), ClipsDescendants=true,
    Active=true,
}, ScreenGui)
corner(9, Win)
stroke(1.2, C.border, Win)

local uiScale = Instance.new("UIScale", Win)
local function updateScale()
    local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
    local scaleX = (viewport.X * 0.95) / 520
    local scaleY = (viewport.Y * 0.95) / 360
    uiScale.Scale = math.min(scaleX, scaleY, 1)
    if Win and Win.AbsoluteSize.X > 0 and Win.Position.X.Scale == 0 then
        local halfW = Win.AbsoluteSize.X / 2
        local halfH = Win.AbsoluteSize.Y / 2
        local minX = math.min(halfW, viewport.X / 2)
        local maxX = math.max(halfW, viewport.X - halfW)
        local minY = math.min(halfH, viewport.Y / 2)
        local maxY = math.max(halfH, viewport.Y - halfH)
        local curCenterX = Win.AbsolutePosition.X + halfW
        local curCenterY = Win.AbsolutePosition.Y + halfH
        Win.Position = UDim2.new(0, math.clamp(curCenterX, minX, maxX), 0, math.clamp(curCenterY, minY, maxY))
    end
end
updateScale()
table.insert(cleanUpSignals, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))

local pillBaseSize = UDim2.new(0, 138, 0, 34)
FloatingPill.InputEnded:Connect(function(inp)
    if isTouchOrClick(inp) then
        if not togMoved then
            tw(FloatingPill, 0.08, {Size = UDim2.new(0, 132, 0, 32)})
            task.delay(0.08, function() 
                tw(FloatingPill, 0.12, {Size = pillBaseSize}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) 
            end)
            toggleUI(Win)
        end
        togDragActive = false
    end
end)

-- TITLE / BANNER BAR
local TitleBar = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = COLORS.Sidebar,
    BorderSizePixel = 0,
}, Win)
corner(9, TitleBar)

-- Bottom patch so TitleBar only curves at the top corners, matching Win's curve smoothly
make("Frame", {
    Size = UDim2.new(1, 0, 0, 10),
    Position = UDim2.new(0, 0, 1, -10),
    BackgroundColor3 = COLORS.Sidebar,
    BorderSizePixel = 0,
    ZIndex = TitleBar.ZIndex,
}, TitleBar)

-- RESIZE HANDLE (Bottom-Right Drag Grip)
local ResizeHandle = make("TextButton", {
    Name = "ResizeHandle",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -2, 1, -2),
    Size = UDim2.new(0, 16, 0, 16),
    BackgroundColor3 = Color3.fromRGB(30, 38, 54),
    BackgroundTransparency = 0.5,
    Text = "◢",
    TextColor3 = C.accent,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    ZIndex = 9999,
    AutoButtonColor = false,
}, Win)
corner(4, ResizeHandle)

local resizingMain, resizeStartPos, startWinSize = false, nil, nil
ResizeHandle.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        resizingMain = true
        resizeStartPos = inp.Position
        startWinSize = Win.AbsoluteSize
    end
end)
table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        resizingMain = false
    end
end))
table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
    if resizingMain and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - resizeStartPos
        local scale = uiScale and uiScale.Scale or 1
        local newW = math.clamp(startWinSize.X + (delta.X / scale), 480, 1200)
        local newH = math.clamp(startWinSize.Y + (delta.Y / scale), 320, 850)
        Win.Size = UDim2.new(0, newW, 0, newH)
        lastSize = Win.Size
    end
end))

local TitleLabel = make("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 14, 0, 0),
    BackgroundTransparency = 1,
    Text = "NexWorks v16.1 Beta",
    TextColor3 = C.text,
    TextSize = 13,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, TitleBar)

-- Version build badge
local BuildBadge = make("TextLabel", {
    Size = UDim2.new(0, 90, 0, 18),
    Position = UDim2.new(0.5, 0, 0.5, -9),
    BackgroundColor3 = Color3.fromRGB(0, 100, 200),
    BackgroundTransparency = 0.3,
    Text = "High UNC Build",
    TextColor3 = Color3.fromRGB(200, 230, 255),
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
}, TitleBar)
corner(4, BuildBadge)

local function createHeaderBtn(text, offset, bg, hover, clickCallback)
    local b = make("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, offset, 0.5, -12),
        BackgroundColor3 = bg,
        Text = text,
        TextColor3 = C.text2,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, TitleBar)
    corner(5, b)
    b.MouseEnter:Connect(function() tw(b, 0.12, {BackgroundColor3 = hover, TextColor3 = C.text}) end)
    b.MouseLeave:Connect(function() tw(b, 0.12, {BackgroundColor3 = bg, TextColor3 = C.text2}) end)
    b.MouseButton1Click:Connect(clickCallback)
    return b
end

-- Close and Min Buttons
local CloseBtn = createHeaderBtn("X", -32, Color3.fromRGB(48, 25, 30), Color3.fromRGB(200, 55, 75), function()
    local overlay = make("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(10, 10, 12),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 9999,
    }, ScreenGui)
    
    local popup = make("Frame", {
        Size = UDim2.new(0, 260, 0, 110),
        Position = UDim2.new(0.5, -130, 0.5, -55),
        BackgroundColor3 = COLORS.BG,
        BorderSizePixel = 0,
        ZIndex = 10000,
    }, overlay)
    corner(8, popup)
    stroke(1.2, C.border, popup)
    
    local title = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 45),
        Position = UDim2.new(0, 0, 0, 5),
        BackgroundTransparency = 1,
        Text = "Destroy GUI?\nThis will close the menu permanently.",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        ZIndex = 10001,
    }, popup)
    
    local yesBtn = make("TextButton", {
        Size = UDim2.new(0, 105, 0, 28),
        Position = UDim2.new(0, 20, 1, -40),
        BackgroundColor3 = Color3.fromRGB(64, 24, 28),
        Text = "Yes, Destroy",
        TextColor3 = C.red,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        ZIndex = 10001,
    }, popup)
    corner(6, yesBtn)
    stroke(1, C.red, yesBtn)
    
    local noBtn = make("TextButton", {
        Size = UDim2.new(0, 105, 0, 28),
        Position = UDim2.new(1, -125, 1, -40),
        BackgroundColor3 = C.card,
        Text = "No, Cancel",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        ZIndex = 10001,
    }, popup)
    corner(6, noBtn)
    stroke(1, C.border, noBtn)
    
    yesBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        if _G.AHScanner_CleanUp then _G.AHScanner_CleanUp() end
    end)
    
    noBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)
end)

local minned = false
local MinBtn = createHeaderBtn("-", -62, Color3.fromRGB(25, 28, 42), C.border, function()
    minned = not minned
    tw(Win, 0.22, {Size = UDim2.new(0, 520, 0, minned and 38 or 360)})
end)

local keybindBtn = make("TextButton", {
    Size = UDim2.new(0, 55, 0, 24),
    Position = UDim2.new(1, -122, 0.5, -12),
    BackgroundColor3 = Color3.fromRGB(25, 28, 42),
    Text = "RShift",
    TextColor3 = C.text2,
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
}, TitleBar)
corner(5, keybindBtn)
stroke(1.2, C.border, keybindBtn)

keybindBtn.MouseEnter:Connect(function() tw(keybindBtn, 0.12, {BackgroundColor3 = C.border, TextColor3 = C.text}) end)
keybindBtn.MouseLeave:Connect(function() tw(keybindBtn, 0.12, {BackgroundColor3 = Color3.fromRGB(25, 28, 42), TextColor3 = C.text2}) end)

local listeningForKey = false
keybindBtn.MouseButton1Click:Connect(function()
    if listeningForKey then return end
    listeningForKey = true
    keybindBtn.Text = "..."
    local conn
    conn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            currentKeybind = input.KeyCode
            local name = input.KeyCode.Name
            if name == "RightShift" then name = "RShift"
            elseif name == "LeftShift" then name = "LShift"
            elseif name == "RightControl" then name = "RCtrl"
            elseif name == "LeftControl" then name = "LCtrl"
            elseif name == "RightAlt" then name = "RAlt"
            elseif name == "LeftAlt" then name = "LAlt"
            end
            keybindBtn.Text = name
            listeningForKey = false
            conn:Disconnect()
        end
    end)
end)

-- Sidebar Navigation Setup
local Sidebar = make("ScrollingFrame", {
    Size = UDim2.new(0, 130, 1, -38),
    Position = UDim2.new(0, 0, 0, 38),
    BackgroundColor3 = COLORS.Sidebar,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.accent,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Active = true,
    ElasticBehavior = Enum.ElasticBehavior.Never,
    ScrollingEnabled = true,
}, Win)
list(Enum.HorizontalAlignment.Center, 4, Sidebar)
pad(10, Sidebar)

local Container = make("Frame", {
    Size = UDim2.new(1, -140, 1, -48),
    Position = UDim2.new(0, 135, 0, 43),
    BackgroundTransparency = 1,
}, Win)

local tabs = {}
local activeTab = nil

local function createTab(name, icon, isPlainFrame)
    local tabBtn = make("TextButton", {
        Size = UDim2.new(0, 114, 0, 30),
        BackgroundColor3 = Color3.fromRGB(0,0,0),
        BackgroundTransparency = 1,
        Text = name,
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, Sidebar)
    corner(6, tabBtn)

    local tabFrame
    if isPlainFrame then
        tabFrame = make("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
        }, Container)
    else
        tabFrame = make("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.accent,
            Visible = false,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0,0,0,0),
            Active = true,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, Container)
        list(nil, 6, tabFrame)
        pad(4, tabFrame)
    end

    local tabData = { btn = tabBtn, frame = tabFrame, name = name }
    tabs[name] = tabData

    tabBtn.MouseButton1Click:Connect(function()
        if activeTab then
            activeTab.frame.Visible = false
            tw(activeTab.btn, 0.15, { BackgroundColor3 = COLORS.Sidebar, TextColor3 = C.text2 })
            activeTab.btn.BackgroundTransparency = 1
        end
        activeTab = tabData
        tabFrame.Visible = true
        if tabFrame:IsA("ScrollingFrame") then
            tabFrame.CanvasPosition = Vector2.new(0, 0)
        end
        tabBtn.BackgroundTransparency = 0
        tw(tabBtn, 0.15, { BackgroundColor3 = COLORS.TabBtnActive, TextColor3 = C.accent })
        if tabData.onOpen then
            pcall(tabData.onOpen)
        end
    end)

    return tabFrame
end

local function createSubTabs(parentFrame, subTabNames, defaultName)
    local nav = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
    }, parentFrame)
    local subLayout = list(Enum.HorizontalAlignment.Left, 6, nav)
    subLayout.FillDirection = Enum.FillDirection.Horizontal
    pad(2, nav)

    local frames = {}
    local btns = {}

    for _, name in ipairs(subTabNames) do
        local btn = make("TextButton", {
            Size = UDim2.new(0, 0, 0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = C.card,
            Text = "  " .. name .. "  ",
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            TextWrapped = false,
            ClipsDescendants = false,
        }, nav)
        corner(5, btn)
        stroke(1, C.border, btn)

        local sf = make("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -36),
            Position = UDim2.new(0, 0, 0, 36),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = C.accent,
            Visible = false,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Active = true,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, parentFrame)
        list(nil, 6, sf)
        pad(4, sf)

        frames[name] = sf
        btns[name] = btn

        btn.MouseButton1Click:Connect(function()
            for k, f in pairs(frames) do
                local isCur = (k == name)
                f.Visible = isCur
                if isCur then
                    f.CanvasPosition = Vector2.new(0, 0)
                end
                tw(btns[k], 0.15, {
                    BackgroundColor3 = isCur and COLORS.TabBtnActive or C.card,
                    TextColor3 = isCur and C.accent or C.text2
                })
            end
            if name == "Exclusions" then
                if _G.rebuildExclusionChips then pcall(_G.rebuildExclusionChips) end
                if _G.refreshExclusionItemList then pcall(_G.refreshExclusionItemList) end
                if _G.refreshMutDropdown then pcall(_G.refreshMutDropdown) end
            end
        end)
    end

    if defaultName and frames[defaultName] then
        frames[defaultName].Visible = true
        tw(btns[defaultName], 0.15, {
            BackgroundColor3 = COLORS.TabBtnActive,
            TextColor3 = C.accent
        })
    end

    return frames
end

-- Create the sleek Rayfield-style Toggles & Buttons
local function createToggle(tabFrame, label, initVal, onChange)
    local card = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabFrame)
    corner(6, card)
    makeHoverable(card)

    local lbl = make("TextLabel", {
        Size = UDim2.new(0.7, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, card)

    local switch = make("Frame", {
        Size = UDim2.new(0, 42, 0, 22),
        Position = UDim2.new(1, -54, 0.5, -11),
        BackgroundColor3 = initVal and C.accent or Color3.fromRGB(45, 45, 50),
        BorderSizePixel = 0,
    }, card)
    corner(11, switch)

    local knob = make("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = initVal and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, switch)
    corner(7, knob)

    local btn = make("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 10,
        Active = true,
    }, card)

    local state = (initVal == true)
    local isToggling = false
    local function doToggle()
        if isToggling then return end
        isToggling = true
        state = not state
        tw(switch, 0.15, { BackgroundColor3 = state and C.accent or Color3.fromRGB(45, 45, 50) })
        tw(knob, 0.15, { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) })
        if onChange then pcall(onChange, state) end
        saveConfig()
        task.delay(0.1, function() isToggling = false end)
    end
    btn.MouseButton1Click:Connect(doToggle)
    btn.Activated:Connect(doToggle)

    return card, function(newState)
        state = (newState == true)
        tw(switch, 0.15, { BackgroundColor3 = state and C.accent or Color3.fromRGB(45, 45, 50) })
        tw(knob, 0.15, { Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) })
    end
end

local function createButton(tabFrame, label, onClick)
    local card = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundColor3 = C.card,
        Text = label,
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, tabFrame)
    corner(6, card)
    makeHoverable(card)

    card.MouseButton1Click:Connect(onClick)
    card.MouseEnter:Connect(function() tw(card, 0.15, { BackgroundColor3 = C.cardHover }) end)
    card.MouseLeave:Connect(function() tw(card, 0.15, { BackgroundColor3 = C.card }) end)
    return card
end

local function setupUI()
    loadConfig()

-- ── 1. TABS INITIALIZATION ───────────────────────────
local tabMain       = createTab("Main", "", true)
local tabChangelog  = createTab("Changelog", "")
local tabFarming    = createTab("Farming", "", true)
local tabItemRules  = createTab("Item Rules", "", true)
local tabCharms     = createTab("Charms", "")
local tabTeleports  = createTab("Teleports", "")
local tabWorkshop   = createTab("Workshops", "")
local tabEvents     = createTab("Events", "", true)

local tabManagement = createTab("Management", "", true)
local tabPerformance = createTab("Performance", "", true)
local tabProfile     = createTab("Profiles", "")

-- Farming Subtabs: Main Farm, Semi Farm, Auto-Bid
-- Populate Main Tab (Dashboard)
do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    
    -- Main Container Size is 100% of parent plain frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1
    mainFrame.Parent = tabMain
    
    -- 1. Player Info Banner (Top)
    local playerBanner = Instance.new("Frame")
    playerBanner.Size = UDim2.new(0.96, 0, 0, 54)
    playerBanner.Position = UDim2.new(0.02, 0, 0.02, 0)
    playerBanner.BackgroundColor3 = C.panel
    playerBanner.BorderSizePixel = 0
    playerBanner.Parent = mainFrame
    corner(8, playerBanner)
    
    local avatarImg = Instance.new("ImageLabel")
    avatarImg.Size = UDim2.new(0, 44, 0, 44)
    avatarImg.Position = UDim2.new(0.02, 0, 0.5, -22)
    avatarImg.BackgroundColor3 = C.card
    avatarImg.BorderSizePixel = 0
    avatarImg.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(LocalPlayer.UserId) .. "&w=150&h=150"
    avatarImg.Parent = playerBanner
    corner(22, avatarImg) -- Circle avatar!
    
    local welcomeLbl = Instance.new("TextLabel")
    welcomeLbl.Size = UDim2.new(0.8, 0, 0.5, 0)
    welcomeLbl.Position = UDim2.new(0.16, 0, 0.1, 0)
    welcomeLbl.BackgroundTransparency = 1
    welcomeLbl.Text = "Hello, " .. LocalPlayer.DisplayName
    welcomeLbl.TextColor3 = C.text
    welcomeLbl.TextSize = 14
    welcomeLbl.Font = Enum.Font.MontserratBold
    welcomeLbl.TextXAlignment = Enum.TextXAlignment.Left
    welcomeLbl.Parent = playerBanner
    
    local subWelcomeLbl = Instance.new("TextLabel")
    subWelcomeLbl.Size = UDim2.new(0.8, 0, 0.4, 0)
    subWelcomeLbl.Position = UDim2.new(0.16, 0, 0.5, 0)
    subWelcomeLbl.BackgroundTransparency = 1
    subWelcomeLbl.Text = LocalPlayer.Name .. " — Active — Storage Hunters"
    subWelcomeLbl.TextColor3 = C.text2
    subWelcomeLbl.TextSize = 11
    subWelcomeLbl.Font = Enum.Font.SourceSans
    subWelcomeLbl.TextXAlignment = Enum.TextXAlignment.Left
    subWelcomeLbl.Parent = playerBanner

    -- 2. Server Information Card (Left-Middle)
    local serverCard = Instance.new("Frame")
    serverCard.Size = UDim2.new(0.53, 0, 0, 160)
    serverCard.Position = UDim2.new(0.02, 0, 0.22, 0)
    serverCard.BackgroundColor3 = C.panel
    serverCard.BorderSizePixel = 0
    serverCard.Parent = mainFrame
    corner(8, serverCard)

    local serverTitle = Instance.new("TextLabel")
    serverTitle.Size = UDim2.new(0.9, 0, 0, 24)
    serverTitle.Position = UDim2.new(0.05, 0, 0.03, 0)
    serverTitle.BackgroundTransparency = 1
    serverTitle.Text = "Server Information"
    serverTitle.TextColor3 = C.gold
    serverTitle.TextSize = 13
    serverTitle.Font = Enum.Font.MontserratBold
    serverTitle.TextXAlignment = Enum.TextXAlignment.Left
    serverTitle.Parent = serverCard

    local serverGrid = Instance.new("Frame")
    serverGrid.Size = UDim2.new(0.9, 0, 0.75, 0)
    serverGrid.Position = UDim2.new(0.05, 0, 0.2, 0)
    serverGrid.BackgroundTransparency = 1
    serverGrid.Parent = serverCard

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize = UDim2.new(0.48, -4, 0.3, -4)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.Parent = serverGrid

    local function makeStatBox(title, val, parent)
        local box = Instance.new("Frame")
        box.BackgroundColor3 = C.card
        box.BorderSizePixel = 0
        box.Parent = parent
        corner(4, box)

        local t = Instance.new("TextLabel")
        t.Size = UDim2.new(0.9, 0, 0.4, 0)
        t.Position = UDim2.new(0.05, 0, 0.1, 0)
        t.BackgroundTransparency = 1
        t.Text = title
        t.TextColor3 = C.text2
        t.TextSize = 9
        t.Font = Enum.Font.MontserratBold
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.Parent = box

        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0.9, 0, 0.45, 0)
        v.Position = UDim2.new(0.05, 0, 0.45, 0)
        v.BackgroundTransparency = 1
        v.Text = val
        v.TextColor3 = C.text
        v.TextSize = 10
        v.Font = Enum.Font.SourceSansBold
        v.TextXAlignment = Enum.TextXAlignment.Left
        v.Parent = box
        return box, v
    end

    local _, playersVal = makeStatBox("Players", "Loading...", serverGrid)
    local _, maxPlayersVal = makeStatBox("Max Players", tostring(Players.MaxPlayers), serverGrid)
    local _, pingVal = makeStatBox("Latency", "Calculating...", serverGrid)
    local _, regionVal = makeStatBox("Server Region", "US", serverGrid)
    local _, sessionVal = makeStatBox("In server for", "00:00:00", serverGrid)
    local _, fpsVal = makeStatBox("FPS", "Calculating...", serverGrid)



    -- 3. Executor Info Card (Right-Top)
    local executorCard = Instance.new("Frame")
    executorCard.Size = UDim2.new(0.41, 0, 0, 60)
    executorCard.Position = UDim2.new(0.57, 0, 0.22, 0)
    executorCard.BackgroundColor3 = C.panel
    executorCard.BorderSizePixel = 0
    executorCard.Parent = mainFrame
    corner(8, executorCard)

    -- Detect Executor Name
    local execName = "Unknown Executor"
    if identifyexecutor then
        local name, ver = identifyexecutor()
        execName = tostring(name)
    elseif getexecutorname then
        execName = tostring(getexecutorname())
    end

    local execTitle = Instance.new("TextLabel")
    execTitle.Size = UDim2.new(0.9, 0, 0.4, 0)
    execTitle.Position = UDim2.new(0.05, 0, 0.1, 0)
    execTitle.BackgroundTransparency = 1
    execTitle.Text = execName
    execTitle.TextColor3 = C.accent
    execTitle.TextSize = 13
    execTitle.Font = Enum.Font.MontserratBold
    execTitle.TextXAlignment = Enum.TextXAlignment.Left
    execTitle.Parent = executorCard

    local execSub = Instance.new("TextLabel")
    execSub.Size = UDim2.new(0.9, 0, 0.4, 0)
    execSub.Position = UDim2.new(0.05, 0, 0.5, 0)
    execSub.BackgroundTransparency = 1
    execSub.Text = "Executor is compatible with NexWorks."
    execSub.TextColor3 = C.text2
    execSub.TextSize = 10
    execSub.Font = Enum.Font.SourceSans
    execSub.TextXAlignment = Enum.TextXAlignment.Left
    execSub.Parent = executorCard

    -- 4. Friends List Card (Right-Bottom)
    local friendsCard = Instance.new("Frame")
    friendsCard.Size = UDim2.new(0.41, 0, 0, 90)
    friendsCard.Position = UDim2.new(0.57, 0, 0.44, 0)
    friendsCard.BackgroundColor3 = C.panel
    friendsCard.BorderSizePixel = 0
    friendsCard.Parent = mainFrame
    corner(8, friendsCard)

    local friendsTitle = Instance.new("TextLabel")
    friendsTitle.Size = UDim2.new(0.9, 0, 0.25, 0)
    friendsTitle.Position = UDim2.new(0.05, 0, 0.05, 0)
    friendsTitle.BackgroundTransparency = 1
    friendsTitle.Text = "Friends"
    friendsTitle.TextColor3 = C.gold
    friendsTitle.TextSize = 11
    friendsTitle.Font = Enum.Font.MontserratBold
    friendsTitle.TextXAlignment = Enum.TextXAlignment.Left
    friendsTitle.Parent = friendsCard

    local friendsGrid = Instance.new("Frame")
    friendsGrid.Size = UDim2.new(0.9, 0, 0.65, 0)
    friendsGrid.Position = UDim2.new(0.05, 0, 0.3, 0)
    friendsGrid.BackgroundTransparency = 1
    friendsGrid.Parent = friendsCard

    local fGridLayout = Instance.new("UIGridLayout")
    fGridLayout.CellSize = UDim2.new(0.48, -4, 0.45, -4)
    fGridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    fGridLayout.Parent = friendsGrid

    local _, fInServer = makeStatBox("In Server", "0 friends", friendsGrid)
    local _, fOnline   = makeStatBox("Online", "0 friends", friendsGrid)
    local _, fOffline  = makeStatBox("Offline", "0 friends", friendsGrid)
    local _, fAll      = makeStatBox("All", "0 friends", friendsGrid)

    -- 5. Discord Large Card (Bottom-Left)
    local discordCard = Instance.new("TextButton")
    discordCard.Size = UDim2.new(0.96, 0, 0, 46)
    discordCard.Position = UDim2.new(0.02, 0, 0.77, 0)
    discordCard.BackgroundColor3 = Color3.fromRGB(88, 101, 242) -- Discord Blue
    discordCard.BorderSizePixel = 0
    discordCard.Text = "" -- FIX: Remove default "Button" overlay text
    discordCard.Parent = mainFrame
    corner(8, discordCard)

    local discordTitle = Instance.new("TextLabel")
    discordTitle.Size = UDim2.new(0.9, 0, 0.5, 0)
    discordTitle.Position = UDim2.new(0.05, 0, 0.1, 0)
    discordTitle.BackgroundTransparency = 1
    discordTitle.Text = "Join our Discord Community"
    discordTitle.TextColor3 = C.text
    discordTitle.TextSize = 12
    discordTitle.Font = Enum.Font.MontserratBold
    discordTitle.TextXAlignment = Enum.TextXAlignment.Left
    discordTitle.Parent = discordCard

    local discordSub = Instance.new("TextLabel")
    discordSub.Size = UDim2.new(0.9, 0, 0.4, 0)
    discordSub.Position = UDim2.new(0.05, 0, 0.5, 0)
    discordSub.BackgroundTransparency = 1
    discordSub.Text = "Tap to copy invite link to your clipboard"
    discordSub.TextColor3 = Color3.fromRGB(220, 220, 220)
    discordSub.TextSize = 10
    discordSub.Font = Enum.Font.SourceSans
    discordSub.TextXAlignment = Enum.TextXAlignment.Left
    discordSub.Parent = discordCard

    discordCard.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard("https://discord.gg/xAvT9euuFu")
            discordSub.Text = "Link copied! Paste it in browser or Discord app."
            task.delay(2, function() discordSub.Text = "Tap to copy invite link to your clipboard" end)
        else
            discordSub.Text = "Clipboard access failed"
        end
    end)

    -- Dynamic Live Updates Thread
    local startTime = os.time()
    local lastTime = os.clock()
    local frameCount = 0
    local fps = 60
    
    game:GetService("RunService").Heartbeat:Connect(function()
        frameCount = frameCount + 1
        local now = os.clock()
        if now - lastTime >= 1 then
            fps = math.round(frameCount / (now - lastTime))
            frameCount = 0
            lastTime = now
        end
    end)

    task.spawn(function()
        while task.wait(1) do
            if mainFrame and mainFrame.Parent and mainFrame.Parent.Visible then
            
            -- Session Timer
            local elapsed = os.time() - startTime
            local hrs = math.floor(elapsed / 3600)
            local mins = math.floor((elapsed % 3600) / 60)
            local secs = elapsed % 60
            sessionVal.Text = string.format("%02d:%02d:%02d", hrs, mins, secs)

            -- Ping
            local ping = 0
            pcall(function() ping = math.round(LocalPlayer:GetNetworkPing() * 1000) end)
            pingVal.Text = tostring(ping) .. " ms"

            -- Players
            playersVal.Text = tostring(#Players:GetPlayers()) .. " playing"
            
            -- FPS
            fpsVal.Text = tostring(fps) .. " FPS"

            -- Friends counts
            local inServerCount = 0
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local ok, isF = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
                    if ok and isF then
                        inServerCount = inServerCount + 1
                    end
                end
            end
            fInServer.Text = tostring(inServerCount) .. " friends"

            -- Friend limits info
            pcall(function()
                local onlineInfo = LocalPlayer:GetFriendsOnline()
                local totalFriends = 0
                local onlineCount = 0
                if onlineInfo then
                    onlineCount = #onlineInfo
                end
                
                -- Note: retrieving full friend list count can sometimes be limited, 
                -- but we will represent online count dynamically
                fOnline.Text = tostring(onlineCount) .. " friends"
                fOffline.Text = "Offline"
                fAll.Text = "All Friends"
            end)
            end
        end
    end)
end

local farmingSubtabs = createSubTabs(tabFarming, {"Main Farm", "Semi Farm", "Auto-Bid"}, "Main Farm")
local tabAutofarm   = farmingSubtabs["Main Farm"]
local tabAuto       = farmingSubtabs["Semi Farm"]
local tabBidding    = farmingSubtabs["Auto-Bid"]

-- Events Subtabs: Cargo Ship, Power Plant, Acid Rain, Museum, Time Capsule

-- ═════════════════════════════════════════════════════
-- [Alert] POLICE, BANK HEIST & JAILBREAK CONTROLLERS
-- ═════════════════════════════════════════════════════
local isBankHeistRunning = false
local function doBankHeist(manualNotify)
    if isBankHeistRunning then
        if manualNotify then abLog("[Warning] Bank Heist already in progress!", COLORS.Orange) end
        return
    end
    
    local bank = workspace:FindFirstChild("BBOW Builder Assets") and workspace["BBOW Builder Assets"]:FindFirstChild("Bank")
    local anchor = bank and bank:FindFirstChild("VaultDoor") and bank.VaultDoor:FindFirstChild("BankHeistPromptAnchor")
    local c4Prompt = anchor and anchor:FindFirstChild("BankHeistC4Prompt")
    
    if not bank or not anchor then
        if manualNotify then abLog("[X] Bank Vault not found in workspace!", C.red) end
        return
    end
    
    isBankHeistRunning = true
    task.spawn(function()
        local success, err = pcall(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            abLog("Bank Heist: Teleporting to Vault...", C.green)
            safeTP(anchor.CFrame * CFrame.new(0, 0, 3.5))
            task.wait(0.8)
            
            -- 1. Plant all 4 C4 charges
            for i = 1, 4 do
                if c4Prompt and c4Prompt.Enabled then
                    abLog(string.format("Planting C4 charge %d/4...", i), C.gold)
                    if fireproximityprompt then
                        pcall(function() fireproximityprompt(c4Prompt) end)
                    else
                        c4Prompt:InputHoldBegin()
                        task.wait(c4Prompt.HoldDuration + 0.05)
                        c4Prompt:InputHoldEnd()
                    end
                    task.wait(1.1)
                end
            end
            
            -- Step back safely from blast
            safeTP(anchor.CFrame * CFrame.new(0, 0, 25))
            abLog("[Waiting] C4 Planted! Stepping back for detonation...", C.gold)
            
            -- Wait for vault breach
            local waitTime = 0
            while waitTime < 20 do
                task.wait(1.0)
                waitTime = waitTime + 1
                local debrisLoot = workspace:FindFirstChild("_LocalBankHeistLoot")
                if debrisLoot and #debrisLoot:GetChildren() > 0 then
                    break
                end
            end
            
            -- 2. Teleport inside Vault & Vacuum Loot
            abLog("[Profit] Vault Breached! Vacuum-looting Cash & Diamonds...", C.green)
            local debrisLoot = workspace:FindFirstChild("_LocalBankHeistLoot")
            if debrisLoot then
                for pass = 1, 3 do
                    for _, lootItem in ipairs(debrisLoot:GetChildren()) do
                        local prompt = lootItem:FindFirstChildWhichIsA("ProximityPrompt", true)
                        local base = lootItem:FindFirstChild("Base") or (prompt and prompt.Parent) or (lootItem:IsA("BasePart") and lootItem)
                        if base and prompt and prompt.Enabled then
                            safeTP(base.CFrame * CFrame.new(0, 1.5, 0))
                            task.wait(0.15)
                            if fireproximityprompt then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end
            abLog("[Gem] Loot secured! Escaping 3-star pursuit...", C.green)
            task.wait(0.5)
            
            -- 3. Escape pursuit
            if gConfig.heistEscapeLocation == "Sky" then
                safeTP(anchor.CFrame + Vector3.new(0, 150, 0))
            else
                local myPlot = getMyLivePlot()
                local driveway = myPlot and resolvePlotDrivewayCF(myPlot)
                if driveway then
                    safeTP(driveway)
                else
                    safeTP(anchor.CFrame + Vector3.new(0, 150, 0))
                end
            end
            abLog("Escaped pursuit safely!", C.green)
        end)
        
        isBankHeistRunning = false
        if not success and manualNotify then
            abLog("[X] Bank Heist error: " .. tostring(err), C.red)
        end
    end)
end

local function doJailbreak(notify)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    local ps = workspace:FindFirstChild("BBOW Builder Assets") and workspace["BBOW Builder Assets"]:FindFirstChild("Other Buildings and  Decoration") and workspace["BBOW Builder Assets"]["Other Buildings and  Decoration"]:FindFirstChild("Police Station")
    local tunnel = ps and ps:FindFirstChild("Tunnel")
    
    local digEvent = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Misc") and ReplicatedStorage.Events.Misc:FindFirstChild("JailbreakDig")
    local cellAction = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Misc") and ReplicatedStorage.Events.Misc:FindFirstChild("JailCellDoorAction")
    
    if digEvent then
        pcall(function() digEvent:FireServer() end)
    end
    if cellAction then
        pcall(function() cellAction:InvokeServer("Escape") end)
    end
    
    -- Rapid trigger tunnel prompts if nearby
    if tunnel then
        for _, slab in ipairs(tunnel:GetDescendants()) do
            if slab:IsA("ProximityPrompt") and slab.Enabled then
                if fireproximityprompt then
                    pcall(function() fireproximityprompt(slab) end)
                end
            end
        end
    end
    
    -- Safe TP outside to Release spawn
    local releaseSpawn = ps and ps:FindFirstChild("ReleaseFromJailSpawn")
    if releaseSpawn then
        safeTP(releaseSpawn.CFrame + Vector3.new(0, 3, 0))
    else
        safeTP(CFrame.new(169.9, 1726.0, -210.0))
    end
    
    if notify then
        abLog("[Spoon] Escaped Jail cell successfully!", C.green)
    end
end

local function acceptWarehouseOrder(difficulty)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local tim = workspace:FindFirstChild("Tim")
    local oldCF = hrp and hrp.CFrame
    
    if tim and hrp then
        safeTP(tim:GetPivot() * CFrame.new(0, 0, -4))
        task.wait(0.4)
    end
    
    local wo = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("WarehouseOrders")
    local accept = wo and wo:FindFirstChild("AcceptOrder")
    
    if accept then
        local ok, res = pcall(function() return accept:InvokeServer(difficulty or "Hard") end)
        if ok and type(res) == "table" then
            if res.Success == true then
                local act = res.State and res.State.Active
                local name = act and act.ItemName or "Item"
                local cnt = act and act.Count or 1
                local dia = act and act.Diamonds or 10
                abLog(string.format("[Freight] Accepted %s Order: Bring %dx %s (+%d )", difficulty or "Hard", cnt, name, dia), C.green)
                showWorkshopPopup(string.format("Accepted %s Order: %dx %s (+%d )", difficulty or "Hard", cnt, name, dia), C.green)
            else
                local errMsg = tostring(res.Error or "Could not accept")
                abLog("[X] Order status: " .. errMsg, COLORS.Orange)
                showWorkshopPopup(errMsg, COLORS.Orange)
            end
        else
            abLog("[X] Accept order failed: " .. tostring(res), C.red)
        end
    end
    
    if oldCF and tim then
        task.wait(0.3)
        safeTP(oldCF)
    end
end

local function deliverWarehouseOrder()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local tim = workspace:FindFirstChild("Tim")
    local oldCF = hrp and hrp.CFrame
    
    if tim and hrp then
        safeTP(tim:GetPivot() * CFrame.new(0, 0, -4))
        task.wait(0.4)
    end
    
    local wo = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("WarehouseOrders")
    local deliver = wo and wo:FindFirstChild("DeliverOrder")
    local deliverPkg = wo and wo:FindFirstChild("DeliverPackage")
    
    if deliver then
        local ok, res = pcall(function() return deliver:InvokeServer() end)
        if ok and type(res) == "table" then
            if res.Success == true then
                abLog("Warehouse Order packaged! Delivering to customer...", C.green)
                -- If customer Trevor spawned in workspace, auto hand over package
                local customer = workspace:FindFirstChild("Trevor")
                if customer then
                    safeTP(customer:GetPivot() * CFrame.new(0, 0, -3.5))
                    task.wait(0.5)
                    if deliverPkg then
                        pcall(function() deliverPkg:InvokeServer() end)
                    end
                end
                abLog("[Gem] Warehouse Order completed! Diamonds claimed.", C.green)
                showWorkshopPopup("Warehouse Order Delivered! Diamonds Claimed.", C.green)
            else
                local errMsg = tostring(res.Error or "Items not in inventory/truck")
                abLog("[Warning] " .. errMsg, COLORS.Orange)
                showWorkshopPopup(errMsg, COLORS.Orange)
            end
        else
            abLog("[X] Delivery error: " .. tostring(res), C.red)
        end
    end
    
    if oldCF and tim then
        task.wait(0.3)
        safeTP(oldCF)
    end
end

local eventsSubtabs  = createSubTabs(tabEvents, {"Military Base", "Carnival", "Cargo Train", "The Mines", "Police & Heists", "Cargo Ship", "Power Plant", "Acid Rain", "Museum", "Time Capsule"}, "Military Base")
local tabCarnival    = eventsSubtabs["Carnival"]

local triggerAuctionRush
triggerAuctionRush = function(garageOrLot)
    if not gConfig.auctionRush then return end
    local RS = game:GetService("ReplicatedStorage")
    local aEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Auction")
    if not aEvents then return end

    local rushRemote = aEvents:FindFirstChild("RushProc")
    local cinematicComplete = aEvents:FindFirstChild("CinematicSequenceComplete")

    local lotName = nil
    local garageModel = nil
    if typeof(garageOrLot) == "Instance" then
        garageModel = garageOrLot
        lotName = garageModel:GetAttribute("GarageId") or garageModel.Name
    elseif type(garageOrLot) == "string" then
        lotName = garageOrLot
    end

    task.spawn(function()
        for i = 1, 6 do
            if rushRemote then
                pcall(function() rushRemote:FireServer() end)
                pcall(function() rushRemote:FireServer(true) end)
                if lotName then pcall(function() rushRemote:FireServer(lotName) end) end
                if garageModel then pcall(function() rushRemote:FireServer(garageModel) end) end
            end
            if cinematicComplete then
                pcall(function() cinematicComplete:FireServer() end)
                pcall(function() cinematicComplete:FireServer(true) end)
                if lotName then pcall(function() cinematicComplete:FireServer(lotName) end) end
                if garageModel then pcall(function() cinematicComplete:FireServer(garageModel) end) end
            end
            task.wait(0.1)
        end
    end)
end
_G.triggerAuctionRush = triggerAuctionRush

-- Loop E: Auction Rush (Instant Skip 3-2-1 Countdown Suite)
pcall(function()
    local RS = game:GetService("ReplicatedStorage")
    local aEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Auction")
    local ProximityPromptService = game:GetService("ProximityPromptService")

    -- 1. Intercept ProximityPrompt on EnterAuction (Manual or Auto interaction)
    ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
        if player == LocalPlayer and gConfig.auctionRush then
            local pName = prompt.Name
            local actText = tostring(prompt.ActionText or ""):lower()
            if pName == "EnterAuction" or actText:find("auction") or actText:find("enter") then
                local gModel = prompt:FindFirstAncestorWhichIsA("Model")
                triggerAuctionRush(gModel)
                abLog("[Power] Auction Rush triggered via ProximityPrompt!", C.gold)
            end
        end
    end)

    if aEvents then
        -- 2. Intercept Cinematic Sequence Event
        local playCinematicEv = aEvents:FindFirstChild("PlayCinematicSequence")
        if playCinematicEv then
            playCinematicEv.OnClientEvent:Connect(function(...)
                local args = {...}
                if gConfig.auctionRush then
                    abLog("[Power] Auction Rush: Intercepted Cinematic Sequence, skipping countdown!", C.gold)
                    local rushRemote = aEvents:FindFirstChild("RushProc")
                    local cinematicComplete = aEvents:FindFirstChild("CinematicSequenceComplete")
                    task.spawn(function()
                        for i = 1, 8 do
                            if rushRemote then
                                pcall(function() rushRemote:FireServer(unpack(args)) end)
                                pcall(function() rushRemote:FireServer() end)
                                pcall(function() rushRemote:FireServer(true) end)
                            end
                            if cinematicComplete then
                                pcall(function() cinematicComplete:FireServer(unpack(args)) end)
                                pcall(function() cinematicComplete:FireServer() end)
                                pcall(function() cinematicComplete:FireServer(true) end)
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end

        -- 3. Intercept ToggleAuctionArea / StartAuction
        local startAuctionEv = aEvents:FindFirstChild("ToggleAuctionArea") or aEvents:FindFirstChild("StartAuction")
        if startAuctionEv then
            startAuctionEv.OnClientEvent:Connect(function(isOpen, data)
                if isOpen and gConfig.auctionRush then
                    local lName = (type(data) == "table" and data.LotName) or (typeof(data) == "Instance" and data.Name) or tostring(data or "")
                    triggerAuctionRush(lName)
                    abLog("[Power] Auction Rush triggered via ToggleAuctionArea!", C.gold)
                end
            end)
        end
    end

    -- 4. Active Watcher Loop: Continuously skips countdown whenever player is at a garage or near an Auctioneer
    if _G.AuctionRush_Thread then pcall(task.cancel, _G.AuctionRush_Thread); _G.AuctionRush_Thread = nil end
    _G.AuctionRush_Thread = task.spawn(function()
        while true do
            task.wait(0.25)
            if _G.AHScanner_RunID ~= myRunID then break end
            if gConfig.auctionRush then
                pcall(function()
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if not root then return end

                    local rootPos = root.Position
                    local debris = workspace:FindFirstChild("_Debris")
                    local garages = debris and debris:FindFirstChild("Garages")
                    if not garages then return end

                    for _, g in ipairs(garages:GetChildren()) do
                        local gPos = nil
                        local az = g:FindFirstChild("AuctionZone")
                        local asp = g:FindFirstChild("AuctioneerSpawn")
                        local es = g:FindFirstChild("EntrySquare")
                        local aucNpc = g:FindFirstChild("Auctioneer")

                        if az and az:IsA("BasePart") then
                            gPos = az.Position
                        elseif asp and asp:IsA("BasePart") then
                            gPos = asp.Position
                        elseif aucNpc and aucNpc:IsA("Model") then
                            gPos = aucNpc:GetPivot().Position
                        elseif es then
                            gPos = es:GetPivot().Position
                        else
                            gPos = g:GetPivot().Position
                        end

                        if gPos and (rootPos - gPos).Magnitude < 45 then
                            -- Player is at this garage!
                            -- Only skip if bidding has not opened yet
                            if not AB.auctionOpen or (AB.bidsThisRound or 0) == 0 then
                                local aEvs = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Auction")
                                if aEvs then
                                    local rRemote = aEvs:FindFirstChild("RushProc")
                                    local cComplete = aEvs:FindFirstChild("CinematicSequenceComplete")
                                    local lName = g:GetAttribute("GarageId") or g.Name
                                    if rRemote then
                                        pcall(function() rRemote:FireServer() end)
                                        pcall(function() rRemote:FireServer(true) end)
                                        pcall(function() rRemote:FireServer(lName) end)
                                        pcall(function() rRemote:FireServer(g) end)
                                    end
                                    if cComplete then
                                        pcall(function() cComplete:FireServer() end)
                                        pcall(function() cComplete:FireServer(true) end)
                                        pcall(function() cComplete:FireServer(lName) end)
                                        pcall(function() cComplete:FireServer(g) end)
                                    end
                                end
                            end
                            break
                        end
                    end
                end)
            end
        end
    end)
end)

-- Loop F: Auto Claim Collection Rewards
if _G.HallowLoopF_Thread then pcall(task.cancel, _G.HallowLoopF_Thread); _G.HallowLoopF_Thread = nil end
_G.HallowLoopF_Thread = task.spawn(function()
    while true do
        task.wait(15.0)
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoClaimHalloweenIndex or gConfig.autoClaimCollectionRewards then
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local colEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Collections")
                if colEvents then
                    local claimMilestone = colEvents:FindFirstChild("ClaimMilestoneReward")
                    local claimTier = colEvents:FindFirstChild("ClaimTierReward")
                    if claimMilestone then
                        for i = 1, 30 do pcall(function() claimMilestone:InvokeServer(i) end) end
                    end
                    if claimTier then
                        for i = 1, 10 do pcall(function() claimTier:InvokeServer(i) end) end
                    end
                end
            end)
        end
    end
end)

local tabPoliceHeists = eventsSubtabs["Police & Heists"]

-- POLICE & HEISTS SUBTAB
do
    -- 1. Seized Garage Sniper Card
    local seizedCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabPoliceHeists)
    corner(7, seizedCard); stroke(1, Color3.fromRGB(255, 215, 0), seizedCard)
    list(Enum.HorizontalAlignment.Left, 6, seizedCard); pad(8, seizedCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "POLICE SEIZURES & 15x SNIPING",
        TextColor3 = Color3.fromRGB(255, 215, 0),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, seizedCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "Standalone farm: Only hunts and bids on 15x Seized lots. Idles safely when none active. Works independently without Main Autofarm!",
        TextColor3 = Color3.fromRGB(150, 165, 185),
        TextSize = 9,
        Font = Enum.Font.MontserratMedium,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, seizedCard)
    
    local seizedToggleCard, updateSeizedToggle = createToggle(seizedCard, "Enable Seized Garage Autofarm (15x Only)", gConfig.seizedGarageSniping, function(state)
        gConfig.seizedGarageSniping = state
        saveConfig()
        if state then
            abLog("Seized Garage Autofarm enabled: will automatically hunt & bid on 15x Seized Garages!", C.green)
        else
            abLog("Seized Garage Autofarm disabled", C.textMuted)
        end
    end)
    _G.uiToggles["seizedGarageSniping"] = updateSeizedToggle


    createButton(seizedCard, "Clear Stars (Instant Reset Character)", function()
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
            showWorkshopPopup("Character reset! Stars cleared.", C.green)
        end
    end)
    
    -- Seized Areas Dropdown
    local seizedAreasList = {"Any Area", "Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
    local seizedAreaDropdownBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(26, 32, 46),
        Text = "Target Seized Areas v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, seizedCard)
    corner(4, seizedAreaDropdownBtn); stroke(1, C.border, seizedAreaDropdownBtn)
    
    local seizedDdContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, seizedCard)
    list(nil, 4, seizedDdContainer)
    
    local seizedDdOpen = false
    local seizedBtns = {}
    local function updateSeizedDropdownText()
        if gConfig.seizedAreas["Any Area"] then
            seizedAreaDropdownBtn.Text = "Target Areas: Any Area" .. (seizedDdOpen and " ^" or " v")
            seizedAreaDropdownBtn.TextColor3 = C.gold
        else
            local selected = {}
            for _, area in ipairs(seizedAreasList) do
                if area ~= "Any Area" and gConfig.seizedAreas[area] then
                    table.insert(selected, area)
                end
            end
            if #selected == 0 then
                seizedAreaDropdownBtn.Text = "Target Areas: None" .. (seizedDdOpen and " ^" or " v")
                seizedAreaDropdownBtn.TextColor3 = C.text2
            elseif #selected == 1 then
                seizedAreaDropdownBtn.Text = "Target Area: " .. selected[1] .. (seizedDdOpen and " ^" or " v")
                seizedAreaDropdownBtn.TextColor3 = C.gold
            else
                seizedAreaDropdownBtn.Text = "Target Areas: Multi (" .. #selected .. ")" .. (seizedDdOpen and " ^" or " v")
                seizedAreaDropdownBtn.TextColor3 = C.gold
            end
        end
        for aName, btn in pairs(seizedBtns) do
            if gConfig.seizedAreas[aName] then
                btn.TextColor3 = C.gold
                btn.BackgroundColor3 = COLORS.BG
            else
                btn.TextColor3 = C.text2
                btn.BackgroundColor3 = C.card
            end
        end
    end
    
    seizedAreaDropdownBtn.MouseButton1Click:Connect(function()
        seizedDdOpen = not seizedDdOpen
        seizedDdContainer.Visible = seizedDdOpen
        updateSeizedDropdownText()
    end)
    
    for _, aName in ipairs(seizedAreasList) do
        local abtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = C.card,
            Text = aName,
            TextColor3 = C.text2,
            TextSize = 9,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, seizedDdContainer)
        corner(4, abtn); stroke(1, C.border, abtn)
        seizedBtns[aName] = abtn
        
        abtn.MouseButton1Click:Connect(function()
            if aName == "Any Area" then
                gConfig.seizedAreas = { ["Any Area"] = true }
            else
                gConfig.seizedAreas["Any Area"] = nil
                gConfig.seizedAreas[aName] = not gConfig.seizedAreas[aName]
                local anyChecked = false
                for _, a in ipairs(seizedAreasList) do
                    if a ~= "Any Area" and gConfig.seizedAreas[a] then anyChecked = true; break end
                end
                if not anyChecked then gConfig.seizedAreas = { ["Any Area"] = true } end
            end
            updateSeizedDropdownText()
            saveConfig()
        end)
    end
    updateSeizedDropdownText()
    _G.uiUpdaters["seizedAreas"] = updateSeizedDropdownText

    -- Seized Garage Types Checklist Dropdown
    local seizedGarageDropdownBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(26, 32, 46),
        Text = "Seized Garage Types Filter v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, seizedCard)
    corner(4, seizedGarageDropdownBtn); stroke(1, C.border, seizedGarageDropdownBtn)
    
    local seizedGaragesContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, seizedCard)
    list(nil, 4, seizedGaragesContainer)
    
    local seizedGaragesDdOpen = false
    local function updateSeizedGaragesDdText()
        local count = 0
        for _, v in pairs(gConfig.seizedGarages) do
            if v == true then count = count + 1 end
        end
        if count == 0 then
            seizedGarageDropdownBtn.Text = "Seized Garage Types: All Allowed" .. (seizedGaragesDdOpen and " ^" or " v")
            seizedGarageDropdownBtn.TextColor3 = C.gold
        else
            seizedGarageDropdownBtn.Text = "Seized Garage Types: Custom (" .. count .. ")" .. (seizedGaragesDdOpen and " ^" or " v")
            seizedGarageDropdownBtn.TextColor3 = C.gold
        end
    end
    
    seizedGarageDropdownBtn.MouseButton1Click:Connect(function()
        seizedGaragesDdOpen = not seizedGaragesDdOpen
        seizedGaragesContainer.Visible = seizedGaragesDdOpen
        updateSeizedGaragesDdText()
    end)
    updateSeizedGaragesDdText()
    _G.uiUpdaters["seizedGarages"] = updateSeizedGaragesDdText
    
    local seizedGaragesUpdaters = {}
    local seizedAreaOrder = {"Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
    local seizedAreaGarages = {}
    for _, a in ipairs(seizedAreaOrder) do seizedAreaGarages[a] = {} end
    for id, conf in pairs(GARAGE_CATALOG) do
        local area = conf.area
        if seizedAreaGarages[area] then
            table.insert(seizedAreaGarages[area], { id = id, conf = conf })
        end
    end
    for _, a in ipairs(seizedAreaOrder) do
        table.sort(seizedAreaGarages[a], function(x, y) return x.conf.tier < y.conf.tier end)
    end
    
    for _, aName in ipairs(seizedAreaOrder) do
        local gList = seizedAreaGarages[aName]
        if gList and #gList > 0 then
            local header = make("Frame", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = Color3.fromRGB(15, 20, 30),
                BorderSizePixel = 0,
            }, seizedGaragesContainer)
            corner(4, header)
            make("TextLabel", {
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = aName,
                TextColor3 = C.accent,
                TextSize = 9,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, header)
            
            for _, item in ipairs(gList) do
                local gConf = item.conf
                local gId = item.id
                local isChecked = gConfig.seizedGarages[gId] == true
                
                local gBtn = make("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundColor3 = isChecked and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(18, 22, 32),
                    Text = (isChecked and "  [] " or "  [  ] ") .. gConf.name,
                    TextColor3 = isChecked and Color3.fromRGB(255, 215, 0) or C.text2,
                    TextSize = 8,
                    Font = Enum.Font.MontserratMedium,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BorderSizePixel = 0,
                }, seizedGaragesContainer)
                corner(3, gBtn)
                
                local function updateVisual()
                    local nowChecked = (gConfig.seizedGarages[gId] == true)
                    gBtn.Text = (nowChecked and "  [] " or "  [  ] ") .. gConf.name
                    gBtn.TextColor3 = nowChecked and Color3.fromRGB(255, 215, 0) or C.text2
                    gBtn.BackgroundColor3 = nowChecked and Color3.fromRGB(35, 45, 65) or Color3.fromRGB(18, 22, 32)
                end
                table.insert(seizedGaragesUpdaters, updateVisual)

                gBtn.MouseButton1Click:Connect(function()
                    gConfig.seizedGarages[gId] = not gConfig.seizedGarages[gId]
                    updateVisual()
                    updateSeizedGaragesDdText()
                    saveConfig()
                end)
            end
        end
    end
    _G.seizedGaragesUpdaters = seizedGaragesUpdaters

    -- 2. Bank Heist Controller Card
    local heistCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabPoliceHeists)
    corner(7, heistCard); stroke(1, Color3.fromRGB(255, 80, 80), heistCard)
    list(Enum.HorizontalAlignment.Left, 6, heistCard); pad(8, heistCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "BANK HEIST AUTOMATION",
        TextColor3 = Color3.fromRGB(255, 100, 100),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, heistCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "Auto C4 planting (4 charges), vault vacuum-looting (Cash & Diamonds), and 3-star escape.",
        TextColor3 = Color3.fromRGB(150, 165, 185),
        TextSize = 9,
        Font = Enum.Font.MontserratMedium,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, heistCard)
    
    local heistBtnRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, heistCard)
    
    local robNowBtn = make("TextButton", {
        Size = UDim2.new(0.55, -3, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        Text = "Rob Bank Now (1-Click)",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, heistBtnRow)
    corner(5, robNowBtn)
    robNowBtn.MouseButton1Click:Connect(function()
        tw(robNowBtn, 0.1, {BackgroundColor3 = Color3.fromRGB(255, 80, 80)})
        task.delay(0.15, function() tw(robNowBtn, 0.2, {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}) end)
        doBankHeist(true)
    end)
    
    local tpVaultBtn = make("TextButton", {
        Size = UDim2.new(0.45, -3, 1, 0),
        Position = UDim2.new(0.55, 3, 0, 0),
        BackgroundColor3 = Color3.fromRGB(30, 35, 48),
        Text = "Teleport to Vault",
        TextColor3 = C.text,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, heistBtnRow)
    corner(5, tpVaultBtn); stroke(1, C.border, tpVaultBtn)
    tpVaultBtn.MouseButton1Click:Connect(function()
        safeTP(CFrame.new(187.6, 1727.2, -12.5))
    end)
    
    local heistToggleCard, updateHeistToggle = createToggle(heistCard, "Auto Bank Heist (Loop on Cooldown)", gConfig.autoBankHeist, function(state)
        gConfig.autoBankHeist = state
        saveConfig()
        if state then
            abLog("Auto Bank Heist enabled: will rob bank whenever off cooldown!", C.green)
        else
            abLog("Auto Bank Heist disabled", C.textMuted)
        end
    end)
    _G.uiToggles["autoBankHeist"] = updateHeistToggle

    -- 3. Police Station & Auto-Jailbreak Card
    local jailCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabPoliceHeists)
    corner(7, jailCard); stroke(1, C.border, jailCard)
    list(Enum.HorizontalAlignment.Left, 6, jailCard); pad(8, jailCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "POLICE STATION & INSTANT JAILBREAK",
        TextColor3 = Color3.fromRGB(100, 200, 255),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, jailCard)
    
    local antiArrestToggleCard, updateAntiArrestToggle = createToggle(jailCard, "Anti-Arrest Shield (Godmode vs Police)", gConfig.antiArrest, function(state)
        gConfig.antiArrest = state
        saveConfig()
        if state then
            abLog("Anti-Arrest Shield enabled: Police cannot bust you!", C.green)
        else
            abLog("Anti-Arrest Shield disabled", C.textMuted)
        end
    end)
    _G.uiToggles["antiArrest"] = updateAntiArrestToggle

    local jailToggleCard, updateJailToggle = createToggle(jailCard, "Auto Jailbreak (Instant Escape on Arrest)", gConfig.autoJailbreak, function(state)
        gConfig.autoJailbreak = state
        saveConfig()
        if state then
            abLog("Auto Jailbreak enabled: will escape jail cells automatically!", C.green)
        else
            abLog("Auto Jailbreak disabled", C.textMuted)
        end
    end)
    _G.uiToggles["autoJailbreak"] = updateJailToggle
    
    local jailBtnRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, jailCard)
    
    local breakOutBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 150, 180),
        Text = "Instant Jailbreak",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, jailBtnRow)
    corner(5, breakOutBtn)
    breakOutBtn.MouseButton1Click:Connect(function()
        doJailbreak(true)
    end)
    
    local tpPoliceBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        Position = UDim2.new(0.5, 3, 0, 0),
        BackgroundColor3 = Color3.fromRGB(30, 35, 48),
        Text = "Teleport to Station",
        TextColor3 = C.text,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, jailBtnRow)
    corner(5, tpPoliceBtn); stroke(1, C.border, tpPoliceBtn)
    tpPoliceBtn.MouseButton1Click:Connect(function()
        safeTP(CFrame.new(169.9, 1726.0, -210.0))
    end)
    
    createButton(jailCard, "Teleport to Mike (Luck Quest NPC)", function()
        safeTP(CFrame.new(165.5, 1724.8, -195.0))
    end)

    -- 4. Warehouse Delivery Orders Card
    local woCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabPoliceHeists)
    corner(7, woCard); stroke(1, Color3.fromRGB(0, 200, 160), woCard)
    list(Enum.HorizontalAlignment.Left, 6, woCard); pad(8, woCard)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "WAREHOUSE DELIVERY ORDERS (DIAMONDS)",
        TextColor3 = Color3.fromRGB(0, 220, 180),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, woCard)
    
    local woBtnRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
    }, woCard)
    
    local acceptHardBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 140, 110),
        Text = "Accept Hard (10 Diamonds)",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, woBtnRow)
    corner(5, acceptHardBtn)
    acceptHardBtn.MouseButton1Click:Connect(function()
        acceptWarehouseOrder("Hard")
    end)
    
    local deliverBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        Position = UDim2.new(0.5, 3, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 100, 160),
        Text = "Deliver Order (Remote)",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = false,
    }, woBtnRow)
    corner(5, deliverBtn)
    deliverBtn.MouseButton1Click:Connect(function()
        deliverWarehouseOrder()
    end)
    
    createButton(woCard, "Teleport to Tim (Warehouse Orders Terminal)", function()
        local tim = workspace:FindFirstChild("Tim")
        if tim then
            safeTP(tim:GetPivot() * CFrame.new(0, 0, -4))
            showWorkshopPopup("Teleported to Warehouse Terminal (Tim)!", C.green)
        else
            safeTP(CFrame.new(171.5, 1723.1, 682.9))
        end
    end)
end

local tabMilitaryBase = eventsSubtabs["Military Base"]
local tabCargoShip  = eventsSubtabs["Cargo Ship"]
local tabPowerPlant = eventsSubtabs["Power Plant"]
local tabAcidRain   = eventsSubtabs["Acid Rain"]
local tabMuseum     = eventsSubtabs["Museum"]
local tabTimeCapsule = eventsSubtabs["Time Capsule"]
local tabCargoTrain = eventsSubtabs["Cargo Train"]
local tabMines      = eventsSubtabs["The Mines"]

-- Populate Events Subtabs
do
    -- Military Base Subtab (DEFCON & Camo Airdrop)
    local defconCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabMilitaryBase)
    pad(10, defconCard)
    list(Enum.HorizontalAlignment.Left, 6, defconCard)

    local defconHeader = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "DEFCON Level & Camo Airdrops",
        TextColor3 = C.gold,
        TextSize = 13,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, defconCard)

    local defconLevelLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "DEFCON Level: DEFCON 5",
        TextColor3 = Color3.fromRGB(95, 200, 120),
        TextSize = 12,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, defconCard)

    local defconWinsLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Server Wins: 0 / 10 (10 wins to DEFCON 4)",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, defconCard)

    local defconMutatorLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Active Mutator: None",
        TextColor3 = C.textMuted,
        TextSize = 11,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, defconCard)

    local defconAirdropLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Camo Airdrops: Standby (Unlocks at DEFCON 1)",
        TextColor3 = C.textMuted,
        TextSize = 11,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, defconCard)

    local function getActiveCamoAirdrops()
        local drops = {}
        local CollectionService = game:GetService("CollectionService")
        pcall(function()
            for _, inst in ipairs(CollectionService:GetTagged("MilitaryAirdrop")) do
                if inst and inst.Parent then
                    table.insert(drops, inst)
                end
            end
        end)
        local debrisGarages = workspace:FindFirstChild("_Debris") and workspace._Debris:FindFirstChild("Garages")
        if debrisGarages then
            for _, g in ipairs(debrisGarages:GetChildren()) do
                if g.Name == "Camo Airdrop" and not table.find(drops, g) then
                    table.insert(drops, g)
                end
            end
        end
        return drops
    end
    _G.getActiveCamoAirdrops = getActiveCamoAirdrops

    local function getNearestCamoAirdrop()
        local drops = getActiveCamoAirdrops()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil, math.huge end
        local myPos = root.Position

        local nearest, nearestDist = nil, math.huge
        for _, drop in ipairs(drops) do
            local cf = drop:GetPivot()
            local dist = (cf.Position - myPos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = drop
            end
        end
        return nearest, nearestDist
    end
    _G.getNearestCamoAirdrop = getNearestCamoAirdrop

    local function teleportToNearestCamoAirdrop()
        local nearest, dist = getNearestCamoAirdrop()
        if not nearest then
            showWorkshopPopup("No active Camo Airdrops on the map! (Requires DEFCON 1)", C.orange)
            return false
        end
        safeTP(nearest:GetPivot() * CFrame.new(0, 0, -5))
        showWorkshopPopup(string.format("Teleported to Camo Airdrop! (%.0fm away)", dist), C.green)
        return true
    end
    _G.teleportToNearestCamoAirdrop = teleportToNearestCamoAirdrop

    local function instantClaimCamoAirdrop()
        local nearest, dist = getNearestCamoAirdrop()
        if not nearest then
            showWorkshopPopup("No active Camo Airdrops on the map! (Requires DEFCON 1)", C.orange)
            return false
        end

        safeTP(nearest:GetPivot() * CFrame.new(0, 0, -5))
        task.wait(0.3)

        local prompt = nearest:FindFirstChild("EnterAuction", true) or nearest:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function()
                if fireproximityprompt then
                    fireproximityprompt(prompt, prompt.HoldDuration or 0)
                end
                if prompt.InputHoldBegin and prompt.InputHoldEnd then
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration or 0.1)
                    prompt:InputHoldEnd()
                end
            end)
            showWorkshopPopup(string.format("Claimed Camo Airdrop! (%.0fm away)", dist), C.green)
            return true
        else
            showWorkshopPopup("Airdrop reached, but prompt not ready yet!", C.orange)
            return false
        end
    end
    _G.instantClaimCamoAirdrop = instantClaimCamoAirdrop

    createButton(tabMilitaryBase, "Instant Claim Nearest Camo Airdrop", function()
        instantClaimCamoAirdrop()
    end)

    createButton(tabMilitaryBase, "Teleport to Nearest Camo Airdrop", function()
        teleportToNearestCamoAirdrop()
    end)

    local autoClaimCard, updateAutoClaimToggle = createToggle(tabMilitaryBase, "Auto Claim Airdrops on DEFCON 1", gConfig.autoClaimAirdrop or false, function(state)
        gConfig.autoClaimAirdrop = state
        saveConfig()
    end)
    _G.uiToggles["autoClaimAirdrop"] = updateAutoClaimToggle

    local alwaysAirdropCard, updateAlwaysAirdropToggle = createToggle(tabMilitaryBase, "Always Bid / Claim All Camo Airdrops", gConfig.alwaysCollectAirdrop ~= false, function(state)
        gConfig.alwaysCollectAirdrop = state
        saveConfig()
    end)
    _G.uiToggles["alwaysCollectAirdrop"] = updateAlwaysAirdropToggle

    -- ═════════════════════════════════════════════════════
    -- [Military] MILITARY BASE BUNKER AUTOMATION
    -- ═════════════════════════════════════════════════════
    local bunkerCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabMilitaryBase)
    pad(10, bunkerCard)
    list(Enum.HorizontalAlignment.Left, 6, bunkerCard)

    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "Military Bunker (Padlock Breach)",
        TextColor3 = C.gold,
        TextSize = 13,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bunkerCard)

    local bunkerStatusLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Bunker Door: Checking...",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bunkerCard)

    local bunkerExplosivesLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Explosives: Thermite: 0/1 | Shaped: 0/1 | Demo: 0/1",
        TextColor3 = C.textMuted,
        TextSize = 10,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, bunkerCard)

    local function getBunkerPadlockCFrame()
        local bi = workspace:FindFirstChild("Bunker Interior")
        local door = bi and bi:FindFirstChild("Bunker Entrance Door")
        local lock = door and door:FindFirstChild("Bunker Padlock")
        if lock then
            return (lock:IsA("Model") and lock:GetPivot()) or (lock:IsA("BasePart") and lock.CFrame) or CFrame.new(351.4, 1875.8, -5529.1), door
        end
        return CFrame.new(351.4, 1875.8, -5529.1), door
    end

    local function tpToBunkerDoor()
        local lp = game:GetService("Players").LocalPlayer
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return nil end

        local lockCF, doorModel = getBunkerPadlockCFrame()
        local lockPos = lockCF.Position
        local standXZ = Vector3.new(lockPos.X + 3.5, lockPos.Y, lockPos.Z + 3.5)

        pcall(function() lp:RequestStreamAroundAsync(lockPos) end)
        task.wait(0.15)
        lockCF, doorModel = getBunkerPadlockCFrame()
        lockPos = lockCF.Position

        -- Raycast from JUST above padlock height (never +120 Y!) so we hit Bunker Interior floor, NEVER the mountain cliff above!
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = { char, doorModel }
        rayParams.RespectCanCollide = true

        local floorHit = workspace:Raycast(Vector3.new(standXZ.X, lockPos.Y + 2, standXZ.Z), Vector3.new(0, -16, 0), rayParams)
        local floorY = floorHit and floorHit.Position.Y or (lockPos.Y - 6.95)
        local targetPos = Vector3.new(standXZ.X, floorY + 3.5, standXZ.Z)

        local platform = Instance.new("Part")
        platform.Size = Vector3.new(20, 1, 20)
        platform.Anchored = true
        platform.CanCollide = true
        platform.Transparency = 1
        platform.Position = Vector3.new(targetPos.X, floorY - 0.5, targetPos.Z)
        platform.Parent = workspace
        task.delay(2.0, function() if platform then pcall(function() platform:Destroy() end) end end)

        if hum.SeatPart then
            hum.Sit = false
            task.wait(0.05)
        end
        if hum.PlatformStand then hum.PlatformStand = false end
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(targetPos, Vector3.new(lockPos.X, targetPos.Y, lockPos.Z))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        return lockPos
    end

    local function blowOpenBunker()
        local RS = game:GetService("ReplicatedStorage")
        local evMisc = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Misc")
        local bRemote = evMisc and evMisc:FindFirstChild("BunkerRaid")
        local blowRemote = bRemote and bRemote:FindFirstChild("Blow")
        if not blowRemote then
            showWorkshopPopup("Bunker remotes not found!", C.red)
            return false
        end

        local lockPos = tpToBunkerDoor()
        local char = game:GetService("Players").LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and lockPos then
            local waitStart = os.clock()
            while (hrp.Position - lockPos).Magnitude > 18 and (os.clock() - waitStart < 0.7) do
                tpToBunkerDoor()
                task.wait(0.1)
            end
        end
        task.wait(0.25)

        local ok, res = pcall(function() return blowRemote:InvokeServer() end)
        if ok and type(res) == "table" and res.Ok then
            showWorkshopPopup("Bunker padlock breached! Door is OPEN!", C.green)
            abLog("[Bunker] Door breached with explosive charges!", C.green)
            return true
        else
            local msg = (type(res) == "table" and res.Message) or "Failed to blow bunker (need all 3 charges!)"
            showWorkshopPopup(tostring(msg), C.orange)
            abLog("[Warning] Bunker: " .. tostring(msg), C.orange)
            return false
        end
    end
    _G.blowOpenBunker = blowOpenBunker

    createButton(tabMilitaryBase, "Blow Open Bunker Door", function()
        blowOpenBunker()
    end)

    createButton(tabMilitaryBase, "Teleport to Bunker Entrance", function()
        tpToBunkerDoor()
        showWorkshopPopup("Teleported to Military Bunker Entrance!", C.green)
    end)

    local autoBunkerCard, updateAutoBunkerToggle = createToggle(tabMilitaryBase, "Auto Open Bunker When 3 Charges Ready", gConfig.autoOpenBunker or false, function(state)
        gConfig.autoOpenBunker = state
        saveConfig()
    end)
    _G.uiToggles["autoOpenBunker"] = updateAutoBunkerToggle

    -- Background loop: check explosives & bunker status
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local RS = game:GetService("ReplicatedStorage")
                local evMisc = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Misc")
                local bRemote = evMisc and evMisc:FindFirstChild("BunkerRaid")
                local getStateRemote = bRemote and bRemote:FindFirstChild("GetState")
                if getStateRemote then
                    local st = getStateRemote:InvokeServer()
                    if st and type(st) == "table" then
                        local now = os.time()
                        local openUntil = tonumber(st.OpenUntil) or tonumber(workspace:GetAttribute("BunkerOpenUntil")) or 0
                        local isOpen = openUntil > now
                        if isOpen then
                            local left = math.max(0, math.floor(openUntil - now))
                            bunkerStatusLbl.Text = string.format("Bunker Door: OPEN (%dm %ds left)", math.floor(left / 60), left % 60)
                            bunkerStatusLbl.TextColor3 = C.green
                        else
                            bunkerStatusLbl.Text = "Bunker Door: CLOSED"
                            bunkerStatusLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
                        end

                        local owned = st.Owned or {}
                        local tCount = tonumber(owned["1650"]) or 0
                        local sCount = tonumber(owned["1651"]) or 0
                        local dCount = tonumber(owned["1652"]) or 0

                        bunkerExplosivesLbl.Text = string.format("Explosives: Thermite: %d/1 | Shaped: %d/1 | Demo: %d/1", tCount, sCount, dCount)
                        local hasAll = (tCount >= 1 and sCount >= 1 and dCount >= 1)
                        bunkerExplosivesLbl.TextColor3 = hasAll and C.green or C.textMuted

                        if hasAll and not isOpen and gConfig.autoOpenBunker then
                            if not _G._lastAutoBunkerAttempt or (os.clock() - _G._lastAutoBunkerAttempt >= 12) then
                                _G._lastAutoBunkerAttempt = os.clock()
                                abLog("[Bunker] All 3 explosives ready! Breaching bunker door...", C.gold)
                                blowOpenBunker()
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- Live DEFCON status updater function
    local defconColors = {
        [5] = Color3.fromRGB(95, 200, 120),
        [4] = Color3.fromRGB(165, 210, 75),
        [3] = Color3.fromRGB(255, 200, 60),
        [2] = Color3.fromRGB(255, 140, 40),
        [1] = Color3.fromRGB(235, 65, 55),
    }

    local defconMutators = {
        [5] = "None",
        [4] = "[Bulletproof] (3.0x)",
        [3] = "[Fortified] (4.0x)",
        [2] = "[Vaulted] (7.0x)",
        [1] = "[Warforged] (30.0x)",
    }

    local defconWinsNeeded = {
        [5] = 10,
        [4] = 30,
        [3] = 55,
        [2] = 85,
        [1] = 85,
    }

    local currentDefconLevel = 5
    local currentDefconWins = 0

    local function updateDefconDisplay(lvl, wins)
        lvl = tonumber(lvl) or currentDefconLevel
        wins = tonumber(wins) or currentDefconWins
        currentDefconLevel = lvl
        currentDefconWins = wins

        local color = defconColors[lvl] or C.text
        local mutator = defconMutators[lvl] or "None"
        local targetWins = defconWinsNeeded[lvl] or 85

        defconLevelLbl.Text = string.format("DEFCON Level: DEFCON %d", lvl)
        defconLevelLbl.TextColor3 = color

        if lvl == 1 then
            defconWinsLbl.Text = string.format("Server Wins: %d (DEFCON 1 ACTIVE!)", wins)
            defconWinsLbl.TextColor3 = Color3.fromRGB(235, 65, 55)
        else
            local remaining = math.max(0, targetWins - wins)
            defconWinsLbl.Text = string.format("Server Wins: %d / %d (%d wins to DEFCON %d)", wins, targetWins, remaining, lvl - 1)
            defconWinsLbl.TextColor3 = C.text
        end

        defconMutatorLbl.Text = string.format("Active Mutator: %s", mutator)
        defconMutatorLbl.TextColor3 = (lvl <= 4) and color or C.textMuted

        local activeDrops = #getActiveCamoAirdrops()
        if lvl == 1 or activeDrops > 0 then
            defconAirdropLbl.Text = string.format("Camo Airdrops: ACTIVE (%d crate%s on map!)", activeDrops, activeDrops == 1 and "" or "s")
            defconAirdropLbl.TextColor3 = Color3.fromRGB(235, 65, 55)
        else
            defconAirdropLbl.Text = "Camo Airdrops: Standby (Unlocks at DEFCON 1)"
            defconAirdropLbl.TextColor3 = C.textMuted
        end
    end
    _G.updateDefconDisplay = updateDefconDisplay

    -- Listen to server DefconStatus RemoteEvent
    local RS = game:GetService("ReplicatedStorage")
    local defconEvent = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("UI") and RS.Events.UI:FindFirstChild("DefconStatus")
    if defconEvent then
        defconEvent.OnClientEvent:Connect(function(data)
            if type(data) == "table" then
                local lvl = data.Level
                local wins = data.Wins
                updateDefconDisplay(lvl, wins)

                if data.Level == 1 and gConfig.autoClaimAirdrop then
                    task.delay(1, function()
                        instantClaimCamoAirdrop()
                    end)
                end
            end
        end)
    end

    -- Initial state check from in-game panel
    pcall(function()
        local panel = LocalPlayer.PlayerGui:FindFirstChild("UIControllerGui") and LocalPlayer.PlayerGui.UIControllerGui:FindFirstChild("DefconProgressPanel")
        if panel and panel:FindFirstChild("LevelChip") then
            local text = panel.LevelChip.Text
            local lvlNum = tonumber(string.match(text, "%d+")) or 5
            local cntText = panel:FindFirstChild("Count") and panel.Count.Text or ""
            local winsNum = tonumber(string.match(cntText, "%d+")) or 0
            updateDefconDisplay(lvlNum, winsNum)
        end
    end)

    -- Auto-claim listener for dropped crates via CollectionService
    local CollectionService = game:GetService("CollectionService")
    CollectionService:GetInstanceAddedSignal("MilitaryAirdrop"):Connect(function(inst)
        if gConfig.autoClaimAirdrop then
            task.delay(1.5, function()
                instantClaimCamoAirdrop()
            end)
        end
    end)

    -- Cargo Ship Subtab

    createButton(tabCargoShip, "Teleport to Cargo Ship (Ocean Port)", function()
        safeTP(CFrame.new(-818.9, 1728.5, 613.5))
    end)



    -- ═════════════════════════════════════════════════════
    -- [Carnival] CARNIVAL AUTOMATION SUBTAB
    -- ═════════════════════════════════════════════════════
    local carnivalCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabCarnival)
    pad(10, carnivalCard)
    list(Enum.HorizontalAlignment.Left, 6, carnivalCard)

    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "Carnival Games & Prize Machine",
        TextColor3 = C.gold,
        TextSize = 13,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, carnivalCard)

    local carnivalTicketsLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Carnival Tickets: 0",
        TextColor3 = Color3.fromRGB(255, 150, 210),
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, carnivalCard)

    local carnivalTokensLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "Carnival Tokens: 0",
        TextColor3 = Color3.fromRGB(255, 215, 100),
        TextSize = 11,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, carnivalCard)

    local carnivalStatusLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "Status: Idle",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, carnivalCard)

    local function redeemCarnivalPrizes(count)
        count = count or 5
        local RS = game:GetService("ReplicatedStorage")
        local pEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("CarnivalPrizes")
        local redeemRemote = pEvents and pEvents:FindFirstChild("Redeem")
        if not redeemRemote then
            showWorkshopPopup("Carnival Prize remote not found!", C.red)
            return false
        end

        local ok, res = pcall(function() return redeemRemote:InvokeServer(count) end)
        if ok and type(res) == "table" and res.ok then
            showWorkshopPopup(string.format("Rolled %dx Carnival Prizes! Won %s items!", count, tostring(#(res.items or {}))), C.green)
            abLog(string.format("[Carnival] Rolled %dx Carnival Prizes!", count), C.green)
            return true
        else
            local err = (type(res) == "table" and res.error) or "Not enough tickets (25 per roll)!"
            showWorkshopPopup(tostring(err), C.orange)
            return false
        end
    end
    _G.redeemCarnivalPrizes = redeemCarnivalPrizes

    createButton(tabCarnival, "Roll Carnival Prizes (x5 Multi - 125 Tickets)", function()
        redeemCarnivalPrizes(5)
    end)

    createButton(tabCarnival, "Roll Carnival Prize (x1 - 25 Tickets)", function()
        redeemCarnivalPrizes(1)
    end)

    local autoRollCard, updateAutoRollToggle = createToggle(tabCarnival, "Auto Roll Carnival Prizes (When Tickets >= 25)", gConfig.autoRollCarnival or false, function(state)
        gConfig.autoRollCarnival = state
        saveConfig()
    end)
    _G.uiToggles["autoRollCarnival"] = updateAutoRollToggle

    local CARNIVAL_GAMES = {
        { label = "Token Drop (40 Max Tickets)",     key = "Token Drop",      machineId = "TokenDrop",     fallbackPos = Vector3.new(214.4, 1723.0, -1960.6) },
        { label = "Hook a Duck (30 Max Tickets)",    key = "Hook a Duck",     machineId = "LuckyDuck",     fallbackPos = Vector3.new(299.5, 1723.2, -1976.2) },
        { label = "Bowling (25 Max Tickets)",        key = "Bowling",         machineId = "Bowling",       fallbackPos = Vector3.new(239.4, 1723.2, -1984.7) },
        { label = "Hoop Shot (20 Max Tickets)",      key = "Hoop Shot",       machineId = "HoopShot",      fallbackPos = Vector3.new(327.4, 1723.2, -1970.3) },
        { label = "Shoot the Clown (20 Max, Gun)",   key = "Shoot the Clown", machineId = "ShootTheClown", fallbackPos = Vector3.new(268.4, 1723.2, -1975.8) },
        { label = "Rotate All 5 Games (Tour Quest)", key = "Rotate All 5" },
    }

    local carnivalGameDdBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(26, 32, 46),
        Text = "Target Game: " .. tostring(gConfig.carnivalTargetGame or "Token Drop") .. " v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, tabCarnival)
    corner(6, carnivalGameDdBtn); stroke(1, C.border, carnivalGameDdBtn)

    local carnivalGameContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, tabCarnival)
    list(nil, 4, carnivalGameContainer)

    local carnivalDdOpen = false
    local carnivalOptionBtns = {}
    local function updateCarnivalGameDropdownText()
        local cur = tostring(gConfig.carnivalTargetGame or "Token Drop")
        carnivalGameDdBtn.Text = "Target Game: " .. cur .. (carnivalDdOpen and " ^" or " v")
        for key, btn in pairs(carnivalOptionBtns) do
            btn.TextColor3 = (key == cur) and C.accent or C.text2
        end
    end
    _G.uiUpdaters["carnivalTargetGame"] = updateCarnivalGameDropdownText

    carnivalGameDdBtn.MouseButton1Click:Connect(function()
        carnivalDdOpen = not carnivalDdOpen
        carnivalGameContainer.Visible = carnivalDdOpen
        updateCarnivalGameDropdownText()
    end)

    for _, opt in ipairs(CARNIVAL_GAMES) do
        local optBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = C.card,
            Text = opt.label,
            TextColor3 = ((gConfig.carnivalTargetGame or "Token Drop") == opt.key) and C.accent or C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, carnivalGameContainer)
        corner(4, optBtn)
        carnivalOptionBtns[opt.key] = optBtn
        optBtn.MouseButton1Click:Connect(function()
            gConfig.carnivalTargetGame = opt.key
            saveConfig()
            carnivalDdOpen = false
            carnivalGameContainer.Visible = false
            updateCarnivalGameDropdownText()
            abLog("[Carnival] Target Game: " .. opt.key, C.accent)
        end)
    end
    updateCarnivalGameDropdownText()

    local syncCarnivalNativeHandlers -- forward declared below
    local autoPlayCard, updateAutoPlayToggle = createToggle(tabCarnival, "Auto Play Selected Target", gConfig.autoPlayCarnival or false, function(state)
        gConfig.autoPlayCarnival = state
        saveConfig()
        if syncCarnivalNativeHandlers then syncCarnivalNativeHandlers() end
        if not state then
            carnivalStatusLbl.Text = "Status: Idle"
            carnivalStatusLbl.TextColor3 = C.text2
        end
    end)
    _G.uiToggles["autoPlayCarnival"] = updateAutoPlayToggle

    createButton(tabCarnival, "Teleport to Carnival Hub", function()
        safeTP(CFrame.new(263.5, 1745.0, -1975.5))
        showWorkshopPopup("Teleported to Carnival Hub!", C.green)
    end)

    -- Isolated scope to keep setupUI local count well below Luau's limit
    do
        local RS = game:GetService("ReplicatedStorage")
        local CS = game:GetService("CollectionService")
        local WS = game:GetService("Workspace")
        local Players = game:GetService("Players")

        local function setCarnivalStatus(msg, color)
            pcall(function()
                carnivalStatusLbl.Text = "Status: " .. tostring(msg)
                carnivalStatusLbl.TextColor3 = color or C.text2
            end)
        end

        local function reqMod(name)
            local modules = RS:FindFirstChild("Modules")
            local mod = modules and modules:FindFirstChild(name)
            if not mod then return nil end
            local ok, res = pcall(require, mod)
            return ok and res or nil
        end

        local function solveSweepTime(targetPos, phase, speed, minDt)
            local t = math.clamp(targetPos or 0.5, 0.0005, 0.9995)
            local p = phase or 0
            local s = (speed and speed > 0) and speed or 1
            local dtMin = math.max(0, minDt or 0)
            local minU = dtMin * s + p
            local u1 = t + 2 * math.ceil((minU - t) / 2)
            local tDesc = 2 - t
            local u2 = tDesc + 2 * math.ceil((minU - tDesc) / 2)
            local uBest = math.min(u1, u2)
            return math.max(dtMin, (uBest - p) / s)
        end

        local function findMachineAnchor(machineId, fallbackPos)
            for _, part in ipairs(CS:GetTagged("CarnivalMachine")) do
                if part:IsA("BasePart") and part:GetAttribute("CarnivalMachineId") == machineId then
                    return part
                end
            end
            if fallbackPos then
                local lp = LocalPlayer or Players.LocalPlayer
                if lp then
                    pcall(function() lp:RequestStreamAroundAsync(fallbackPos) end)
                    task.wait(0.35)
                    for _, part in ipairs(CS:GetTagged("CarnivalMachine")) do
                        if part:IsA("BasePart") and part:GetAttribute("CarnivalMachineId") == machineId then
                            return part
                        end
                    end
                end
            end
            return nil
        end

        local function findValidGunTool(equipIfFound)
            local lp = LocalPlayer or Players.LocalPlayer
            local char = lp and lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local bp = lp and lp:FindFirstChildOfClass("Backpack")
            local gunCfg = reqMod("GunConfig")
            local clownCfg = reqMod("CarnivalShootTheClownConfig")
            local excluded = (clownCfg and clownCfg.ExcludedGuns) or { ["1500"] = true }
            if not gunCfg or not char then return nil end

            local function isValidGun(inst)
                if not inst or not inst:IsA("Tool") then return false end
                local id = tostring(inst:GetAttribute("ItemId") or "")
                return gunCfg[id] ~= nil and not excluded[id]
            end

            for _, c in ipairs(char:GetChildren()) do
                if isValidGun(c) then return c end
            end
            if bp then
                for _, c in ipairs(bp:GetChildren()) do
                    if isValidGun(c) then
                        if equipIfFound and hum then
                            pcall(function() hum:EquipTool(c) end)
                            local deadline = os.clock() + 1.2
                            while c.Parent ~= char and os.clock() < deadline do
                                task.wait(0.05)
                            end
                        end
                        return c
                    end
                end
            end
            return nil
        end

        local activeRound = nil -- { game = string, id = any, startedAt = number }
        local activeClownRound = nil
        local outOfTokensUntil = 0
        local ourRemoteFns = {}
        local ourScriptConns = {}
        local nativeListenerRefs = nil

        local function isNativeGameConn(conn)
            local fn = conn and conn.Function
            if not fn or ourRemoteFns[fn] then return false end
            local ok, env = pcall(getfenv, fn)
            local scr = ok and type(env) == "table" and rawget(env, "script") or nil
            return typeof(scr) == "Instance" and scr:IsDescendantOf(game)
        end

        local function ensureCarnivalRemotes()
            local ev = RS:FindFirstChild("Events")
            local cEv = ev and ev:FindFirstChild("Carnival")
            if not cEv then return nil end
            local map = {
                TokenDropStart = cEv:FindFirstChild("TokenDropStart"),
                TokenDropDrop  = cEv:FindFirstChild("TokenDropDrop"),
                BowlingStart   = cEv:FindFirstChild("BowlingStart"),
                BowlingRoll    = cEv:FindFirstChild("BowlingRoll"),
                HoopShotStart  = cEv:FindFirstChild("HoopShotStart"),
                HoopShotShoot  = cEv:FindFirstChild("HoopShotShoot"),
                HookDuckStart  = cEv:FindFirstChild("HookDuckStart"),
                HookDuckHook   = cEv:FindFirstChild("HookDuckHook"),
                HookDuckFinish = cEv:FindFirstChild("HookDuckFinish"),
                ClownStart     = cEv:FindFirstChild("ClownStart"),
                ClownEnd       = cEv:FindFirstChild("ClownEnd"),
                OutOfTokens    = cEv:FindFirstChild("OutOfTokens"),
            }
            return map
        end

        local function finishRound(id)
            if activeRound and (id == nil or activeRound.id == id) then
                activeRound = nil
            end
        end

        syncCarnivalNativeHandlers = function()
            if not getconnections then return end
            local remotes = ensureCarnivalRemotes()
            if not remotes then return end
            local shouldSuppress = (gConfig.autoPlayCarnival == true)
            local suppressSet = {
                TokenDropStart = true,
                BowlingStart = true,
                HoopShotStart = true,
                HookDuckStart = true,
                ClownStart = true,
            }
            for _, rName in ipairs({ "TokenDropStart", "BowlingStart", "HoopShotStart", "HookDuckStart", "ClownStart", "OutOfTokens", "ClownEnd" }) do
                local ev = remotes[rName]
                if ev then
                    for _, conn in ipairs(getconnections(ev.OnClientEvent)) do
                        if conn.Function and ourRemoteFns[conn.Function] then
                            pcall(function() conn:Enable() end)
                        elseif isNativeGameConn(conn) then
                            if suppressSet[rName] and shouldSuppress then
                                pcall(function() conn:Disable() end)
                            else
                                pcall(function() conn:Enable() end)
                            end
                        else
                            -- Stale leaked connection from an older script run (script == nil and not in ourRemoteFns)
                            pcall(function() conn:Disable() end)
                            pcall(function() conn:Disconnect() end)
                        end
                    end
                end
            end
        end

        local function restoreSafetyState()
            local skillUI = reqMod("CarnivalSkillGameUI")
            if skillUI then
                pcall(function()
                    for _, k in ipairs({ "TokenDrop", "HoopShot", "HookDuck" }) do
                        skillUI.RestoreHud(k)
                    end
                    skillUI.FreezeMovement(false)
                    skillUI.HideCharacter(false)
                end)
            end
            local cam = WS.CurrentCamera
            if cam and cam.CameraType == Enum.CameraType.Scriptable then
                cam.CameraType = Enum.CameraType.Custom
            end
        end

        local function solveHoopShotAim(cfg, t, phase, simSpeedups)
            local okL, _, _, _, estFlight = pcall(cfg.Launch, 0, cfg.AimHeight)
            local dtFlight = (okL and type(estFlight) == "number" and estFlight > 0) and estFlight or 0.65
            local centerX = cfg.HoopOffset(t + dtFlight, phase, simSpeedups)
            local offsets = { 0, 0.12, -0.12, 0.25, -0.25, 0.4, -0.4, 0.6, -0.6, 0.85, -0.85, 1.1, -1.1 }
            local fallbackScore = nil
            local function tryAim(x)
                local ax, ay = cfg.ClampAim(x, cfg.AimHeight)
                local ok, simRes = pcall(cfg.Simulate, ax, ay, t, phase, simSpeedups, false)
                if ok and type(simRes) == "table" then
                    if simRes.Kind == "Swish" then
                        return ax, ay, "Swish"
                    elseif simRes.Kind == "Score" and not fallbackScore then
                        fallbackScore = { ax, ay, "Score" }
                    end
                end
                return nil
            end
            for _, dx in ipairs(offsets) do
                local ax, ay, k = tryAim(centerX + dx)
                if ax then return ax, ay, k end
            end
            local travel = cfg.HoopTravel or 3.4
            for x = -travel, travel, 0.25 do
                local ax, ay, k = tryAim(x)
                if ax then return ax, ay, k end
            end
            if fallbackScore then
                return fallbackScore[1], fallbackScore[2], fallbackScore[3]
            end
            local ax, ay = cfg.ClampAim(centerX, cfg.AimHeight)
            return ax, ay, "Fallback"
        end

        local function installCarnivalStartListeners()
            if nativeListenerRefs then return end
            local remotes = ensureCarnivalRemotes()
            if not remotes then return end
            nativeListenerRefs = true

            local function regConn(remote, fn)
                if not remote then return nil end
                ourRemoteFns[fn] = true
                local conn = remote.OnClientEvent:Connect(fn)
                table.insert(ourScriptConns, conn)
                table.insert(cleanUpSignals, conn)
                return conn
            end

            table.insert(cleanUpSignals, {
                Disconnect = function()
                    for _, c in ipairs(ourScriptConns) do
                        pcall(function() c:Disconnect() end)
                    end
                    table.clear(ourScriptConns)
                    if getconnections then
                        local rMap = ensureCarnivalRemotes()
                        if rMap then
                            for _, rName in ipairs({ "TokenDropStart", "BowlingStart", "HoopShotStart", "HookDuckStart", "ClownStart" }) do
                                local ev = rMap[rName]
                                if ev then
                                    for _, conn in ipairs(getconnections(ev.OnClientEvent)) do
                                        if isNativeGameConn(conn) then
                                            pcall(function() conn:Enable() end)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            })

            if remotes.OutOfTokens then
                regConn(remotes.OutOfTokens, function()
                    if gConfig.autoPlayCarnival then
                        outOfTokensUntil = os.clock() + 4
                        activeRound = nil
                        setCarnivalStatus("Out of Tokens!", C.orange)
                    end
                end)
            end

            if remotes.ClownEnd then
                regConn(remotes.ClownEnd, function(data)
                    if type(data) ~= "table" then return end
                    if activeClownRound and activeClownRound.id == data.Id then
                        activeClownRound.ended = true
                        activeClownRound.tickets = tonumber(data.Tickets) or 0
                        activeClownRound.hits = tonumber(data.Hits) or 0
                    end
                end)
            end

            -- 1. Token Drop Solver
            regConn(remotes.TokenDropStart, function(data)
                if not gConfig.autoPlayCarnival or type(data) ~= "table" then return end
                activeRound = { game = "Token Drop", id = data.Id, startedAt = os.clock() }
                task.spawn(function()
                    local cfg = reqMod("CarnivalTokenDropConfig")
                    local delay = (cfg and cfg.StartDelay or 0.7) + 0.12
                    local gate = cfg and math.floor((cfg.Slots + 1) / 2) or 5
                    setCarnivalStatus("Token Drop: dropping gate " .. tostring(gate) .. "...", C.accent)
                    task.wait(delay)
                    local ok, res = pcall(function()
                        return remotes.TokenDropDrop:InvokeServer(data.Id, gate)
                    end)
                    local tix = (ok and type(res) == "table" and tonumber(res.Tickets)) or 0
                    setCarnivalStatus(string.format("Token Drop done (+%d tickets)", tix), C.green)
                    abLog(string.format("[Carnival] Token Drop -> +%d tickets", tix), C.green)
                    finishRound(data.Id)
                end)
            end)

            -- 2. Bowling Solver (fires once per roll, 3 rolls total -> 25 tickets)
            regConn(remotes.BowlingStart, function(data)
                if not gConfig.autoPlayCarnival or type(data) ~= "table" then return end
                local rollNum = tonumber(data.Roll) or 1
                activeRound = { game = "Bowling", id = data.Id, startedAt = os.clock() }
                task.spawn(function()
                    local t0 = os.clock()
                    local cfg = reqMod("CarnivalBowlingConfig")
                    if not cfg then finishRound(data.Id) return end

                    local anchor = findMachineAnchor(data.MachineId or "Bowling")
                    local booth = anchor and anchor.Parent
                    local aimPos = 0.5
                    if booth then
                        local okSort, _, pinXs = pcall(cfg.SortPins, booth)
                        if okSort and type(pinXs) == "table" and #pinXs > 0 then
                            local pStart, pWidth = cfg.PocketRange(pinXs)
                            aimPos = pStart + pWidth / 2
                        end
                    end

                    local minAimDt = (cfg.AimPressAfter or 0.5) + 0.05
                    local aimDt = solveSweepTime(aimPos, tonumber(data.AimPhase) or 0, cfg.AimSpeed or 2.4, minAimDt)
                    local aimTime = (cfg.AimDelay or 0.8) + aimDt

                    local zoneStart = tonumber(data.ZoneStart) or 0.4
                    local pTarget = zoneStart + (cfg.PowerZoneWidth or 0.23) / 2
                    local pDt = solveSweepTime(pTarget, tonumber(data.PowerPhase) or 0, cfg.PowerSpeed or 1.3, 0.05)
                    local powerTime = aimTime + (cfg.PowerDelay or 0.45) + pDt

                    local totalRolls = tonumber(data.Rolls) or cfg.Rolls or 3
                    setCarnivalStatus(string.format("Bowling Roll %d/%d (Perfect Solve)...", rollNum, totalRolls), C.accent)
                    local waitNeeded = (powerTime + 0.08) - (os.clock() - t0)
                    if waitNeeded > 0 then task.wait(waitNeeded) end

                    local ok, res = pcall(function()
                        return remotes.BowlingRoll:InvokeServer(data.Id, data.Roll, aimTime, powerTime)
                    end)
                    if ok and type(res) == "table" then
                        if res.Done then
                            local tix = tonumber(res.Tickets) or 0
                            setCarnivalStatus(string.format("Bowling done (%d strikes, +%d tickets)", tonumber(res.Strikes) or 0, tix), C.green)
                            abLog(string.format("[Carnival] Bowling -> %d strikes (+%d tickets)", tonumber(res.Strikes) or 0, tix), C.green)
                            finishRound(data.Id)
                        else
                            if activeRound and activeRound.id == data.Id then
                                activeRound.startedAt = os.clock()
                            end
                            setCarnivalStatus(string.format("Bowling Roll %d/%d done, waiting next roll...", rollNum, totalRolls), C.accent)
                        end
                    else
                        finishRound(data.Id)
                    end
                end)
            end)

            -- 3. Hoop Shot Solver (6 balls simulated to Swish -> 20 tickets)
            regConn(remotes.HoopShotStart, function(data)
                if not gConfig.autoPlayCarnival or type(data) ~= "table" then return end
                activeRound = { game = "Hoop Shot", id = data.Id, startedAt = os.clock() }
                task.spawn(function()
                    local t0 = os.clock()
                    local cfg = reqMod("CarnivalHoopShotConfig")
                    if not cfg then finishRound(data.Id) return end
                    local speedups = {}
                    local phase = tonumber(data.Phase) or 0
                    local balls = cfg.BallsPerPlay or 6
                    local finalRes = nil
                    local nextAllowedT = (cfg.StartDelay or 1) + 0.12

                    for shot = 1, balls do
                        if not gConfig.autoPlayCarnival then break end
                        local dtWait = nextAllowedT - (os.clock() - t0)
                        if dtWait > 0 then task.wait(dtWait) end
                        local t = math.max(nextAllowedT, os.clock() - t0)
                        nextAllowedT = t + (cfg.ShotCooldown or 0.85) + 0.08
                        local simSpeedups = table.clone(speedups)
                        table.insert(simSpeedups, t + (cfg.SpeedUpAfter or 0.8))

                        local ax, ay, kind = solveHoopShotAim(cfg, t, phase, simSpeedups)
                        table.insert(speedups, t + (cfg.SpeedUpAfter or 0.8))
                        setCarnivalStatus(string.format("Hoop Shot %d/%d (%s)...", shot, balls, kind), C.accent)

                        local ok, res = pcall(function()
                            return remotes.HoopShotShoot:InvokeServer(data.Id, t, ax, ay)
                        end)
                        if activeRound and activeRound.id == data.Id then
                            activeRound.startedAt = os.clock()
                        end
                        if ok and type(res) == "table" then
                            finalRes = res
                            if res.Done then break end
                        end
                    end

                    local tix = (finalRes and tonumber(finalRes.Tickets)) or 0
                    setCarnivalStatus(string.format("Hoop Shot done (+%d tickets)", tix), C.green)
                    abLog(string.format("[Carnival] Hoop Shot -> +%d tickets", tix), C.green)
                    finishRound(data.Id)
                end)
            end)

            -- 4. Hook a Duck Solver (12 ducks + Gold Duck #7 -> 30 tickets)
            regConn(remotes.HookDuckStart, function(data)
                if not gConfig.autoPlayCarnival or type(data) ~= "table" then return end
                activeRound = { game = "Hook a Duck", id = data.Id, startedAt = os.clock() }
                task.spawn(function()
                    local cfg = reqMod("CarnivalHookDuckConfig")
                    if not cfg then finishRound(data.Id) return end
                    local endsAt = tonumber(data.EndsAt) or (WS:GetServerTimeNow() + (cfg.StartDelay or 1) + (cfg.RoundTime or 25))
                    local anchor = findMachineAnchor(data.MachineId or "LuckyDuck")
                    local booth = anchor and anchor.Parent
                    local ring = booth and booth:FindFirstChild(cfg.RingMarkerName or "DuckRing")
                    local caught = {}
                    local caughtCount = 0
                    local duckCount = cfg.DuckCount or 12
                    local lastX, lastZ = 0, 0

                    setCarnivalStatus("Hook a Duck: waiting start...", C.accent)
                    task.wait((cfg.StartDelay or 1) + (cfg.DipTime or 0.22) + 0.12)

                    while gConfig.autoPlayCarnival and caughtCount < duckCount do
                        local now = WS:GetServerTimeNow()
                        if now >= endsAt - 0.35 then break end
                        local planStr = ring and ring:GetAttribute(cfg.PlanAttribute or "DuckPlan")
                        local plan = type(planStr) == "string" and cfg.DecodePlan(planStr) or nil
                        if plan then
                            local poses = cfg.DuckPoses(plan, now)
                            local bestIdx, bestX, bestZ, bestDipIdx, bestDist = nil, nil, nil, nil, math.huge

                            if not caught[7] and poses and poses[7] then
                                local gx, gz = cfg.ClampReach(poses[7].X, poses[7].Z)
                                local gKind, gDipIdx = cfg.DipResult(plan, now, gx, gz, caught)
                                if gKind ~= "Miss" then
                                    bestIdx, bestX, bestZ, bestDipIdx = 7, gx, gz, gDipIdx
                                    bestDist = math.hypot(gx - lastX, gz - lastZ)
                                end
                            end

                            if not bestIdx and poses then
                                for idx = 1, duckCount do
                                    if not caught[idx] and poses[idx] then
                                        local dx, dz = cfg.ClampReach(poses[idx].X, poses[idx].Z)
                                        local d = math.hypot(dx - lastX, dz - lastZ)
                                        if d < bestDist then
                                            local kind, dipIdx = cfg.DipResult(plan, now, dx, dz, caught)
                                            if kind ~= "Miss" then
                                                bestIdx, bestX, bestZ, bestDipIdx, bestDist = idx, dx, dz, dipIdx, d
                                            end
                                        end
                                    end
                                end
                            end

                            if bestIdx then
                                setCarnivalStatus(string.format("Hook a Duck: catching #%d (%d/%d)...", bestIdx, caughtCount + 1, duckCount), C.accent)
                                local ok, res = pcall(function()
                                    return remotes.HookDuckHook:InvokeServer(data.Id, now, bestX, bestZ)
                                end)
                                local markIdx = bestDipIdx or bestIdx
                                caught[markIdx] = true
                                caughtCount = caughtCount + 1
                                lastX, lastZ = bestX, bestZ
                                if activeRound and activeRound.id == data.Id then
                                    activeRound.startedAt = os.clock()
                                end
                                if ok and type(res) == "table" then
                                    endsAt = tonumber(res.EndsAt) or endsAt
                                end
                                local waitSec = math.max((cfg.DipTime or 0.22) + (cfg.CatchRecover or 0.6) + 0.08, bestDist / 28)
                                task.wait(waitSec)
                            else
                                task.wait(0.05)
                            end
                        else
                            task.wait(0.05)
                        end
                    end

                    local okF, fRes = pcall(function()
                        return remotes.HookDuckFinish:InvokeServer(data.Id)
                    end)
                    local tix = (okF and type(fRes) == "table" and tonumber(fRes.Tickets)) or 0
                    setCarnivalStatus(string.format("Hook a Duck done (+%d tickets)", tix), C.green)
                    abLog(string.format("[Carnival] Hook a Duck -> +%d tickets", tix), C.green)
                    finishRound(data.Id)
                end)
            end)

            -- 5. Shoot the Clown Solver (12 clowns -> 20 tickets, requires non-excluded Gun)
            regConn(remotes.ClownStart, function(data)
                if not gConfig.autoPlayCarnival or type(data) ~= "table" then return end
                local state = { id = data.Id, ended = false, tickets = 0, hits = 0 }
                activeClownRound = state
                activeRound = { game = "Shoot the Clown", id = data.Id, startedAt = os.clock() }
                task.spawn(function()
                    local cfg = reqMod("CarnivalShootTheClownConfig")
                    local gunCfg = reqMod("GunConfig")
                    local anchor = findMachineAnchor(data.MachineId or "ShootTheClown")
                    local booth = anchor and anchor.Parent
                    local targetFolder = booth and booth:FindFirstChild((cfg and cfg.TargetFolder) or "Target")
                    local evMisc = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Misc")
                    local gunAction = evMisc and evMisc:FindFirstChild("GunAction")
                    local gunTool = findValidGunTool(true)
                    if not gunAction then
                        gunAction = evMisc and evMisc:WaitForChild("GunAction", 2)
                    end

                    task.wait((tonumber(data.StartDelay) or (cfg and cfg.StartDelay) or 1.5) + 0.1)

                    local firedAt = {}
                    local deadline = os.clock() + 45
                    while gConfig.autoPlayCarnival and not state.ended and os.clock() < deadline do
                        if not gunTool or not gunTool.Parent then
                            gunTool = findValidGunTool(true)
                        end
                        if not gunAction then
                            gunAction = evMisc and evMisc:FindFirstChild("GunAction")
                        end
                        if gunTool and gunAction and targetFolder then
                            local ammo = gunTool:GetAttribute("GunAmmo")
                            if ammo == 0 and not gunTool:GetAttribute("GunReloading") then
                                pcall(function() gunAction:FireServer(gunTool, "Reload") end)
                                task.wait(0.35)
                            elseif not gunTool:GetAttribute("GunReloading") then
                                for _, clown in ipairs(targetFolder:GetChildren()) do
                                    if clown:IsA("Model") and clown:GetAttribute("CarnivalClown") == true
                                        and clown:GetAttribute("ClownUp") == true
                                        and clown:GetAttribute("ClownHit") ~= true
                                        and (not firedAt[clown] or os.clock() - firedAt[clown] > 0.45) then
                                        local parts = clown:FindFirstChild("Parts")
                                        local face = parts and parts:FindFirstChild("TargetFace")
                                        local restPose = face and face:GetAttribute("ClownRestPose")
                                        local hitPos = (typeof(restPose) == "CFrame" and restPose.Position)
                                            or (face and face:IsA("BasePart") and face.Position)
                                            or clown:GetPivot().Position
                                        local lp = LocalPlayer or Players.LocalPlayer
                                        local hrp = lp and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                                        if hrp and (Vector3.new(hitPos.X - hrp.Position.X, 0, hitPos.Z - hrp.Position.Z)).Magnitude > 0.1 then
                                            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(hitPos.X, hrp.Position.Y, hitPos.Z))
                                        end
                                        firedAt[clown] = os.clock()
                                        pcall(function() gunAction:FireServer(gunTool, "Fire", hitPos) end)
                                        setCarnivalStatus(string.format("Shoot Clown: hitting %s...", clown.Name), C.accent)
                                        local gData = gunCfg and gunCfg[tostring(gunTool:GetAttribute("ItemId") or "")]
                                        task.wait(math.max((gData and gData.FireCooldown) or 0.25, 0.25) + 0.04)
                                        break
                                    end
                                end
                            end
                        end
                        task.wait(0.05)
                    end

                    if state.ended then
                        setCarnivalStatus(string.format("Shoot the Clown done (%d hits, +%d tickets)", state.hits, state.tickets), C.green)
                        abLog(string.format("[Carnival] Shoot the Clown -> %d hits (+%d tickets)", state.hits, state.tickets), C.green)
                    end
                    if activeClownRound == state then activeClownRound = nil end
                    finishRound(data.Id)
                end)
            end)
        end

        local GAME_BY_KEY = {}
        local ROTATION_LIST = {}
        for _, g in ipairs(CARNIVAL_GAMES) do
            if g.machineId then
                GAME_BY_KEY[g.key] = g
                table.insert(ROTATION_LIST, g)
            end
        end

        _G.CarnivalBot = {
            solveSweepTime = solveSweepTime,
            solveHoopShotAim = solveHoopShotAim,
            findMachineAnchor = findMachineAnchor,
            findValidGunTool = findValidGunTool,
            syncNative = syncCarnivalNativeHandlers,
        }

        -- Initialize remote listeners and sync suppression state cleanly
        task.spawn(function()
            installCarnivalStartListeners()
            syncCarnivalNativeHandlers()
        end)

        -- Main Background Loop: Live Carnival Stats, Auto-Roll & Auto-Play All 5 Games
        local rotateIdx = 1
        task.spawn(function()
            while task.wait(0.4) do
                pcall(function()
                    local lp = LocalPlayer or Players.LocalPlayer
                    if not lp then return end

                    local tickets = tonumber(lp:GetAttribute("CarnivalTickets")) or 0
                    local tokens = tonumber(lp:GetAttribute("CarnivalTokenCount")) or 0
                    carnivalTicketsLbl.Text = string.format("Carnival Tickets: %d", tickets)
                    carnivalTokensLbl.Text = string.format("Carnival Tokens: %d", tokens)

                    if gConfig.autoRollCarnival and tickets >= 25 then
                        local rollCount = tickets >= 125 and 5 or 1
                        redeemCarnivalPrizes(rollCount)
                        task.wait(1.2)
                    end

                    if not gConfig.autoPlayCarnival then
                        return
                    end

                    installCarnivalStartListeners()
                    syncCarnivalNativeHandlers()

                    if os.clock() < outOfTokensUntil then
                        return
                    end

                    if tokens <= 0 then
                        setCarnivalStatus("Waiting for Tokens (0 tokens)", C.orange)
                        return
                    end

                    if activeRound then
                        if os.clock() - activeRound.startedAt > 45 then
                            activeRound = nil
                            restoreSafetyState()
                        else
                            return
                        end
                    end

                    local chosen = nil
                    local sel = gConfig.carnivalTargetGame or "Token Drop"
                    if sel == "Rotate All 5" then
                        for _ = 1, #ROTATION_LIST do
                            local cand = ROTATION_LIST[rotateIdx]
                            rotateIdx = (rotateIdx % #ROTATION_LIST) + 1
                            if cand.machineId ~= "ShootTheClown" or findValidGunTool(false) ~= nil then
                                chosen = cand
                                break
                            end
                        end
                    else
                        chosen = GAME_BY_KEY[sel] or GAME_BY_KEY["Token Drop"]
                    end

                    if not chosen then return end

                    if chosen.machineId == "ShootTheClown" then
                        local gun = findValidGunTool(true)
                        if not gun then
                            setCarnivalStatus("Need a valid Gun (not Mech) for Shoot the Clown", C.orange)
                            task.wait(1.5)
                            return
                        end
                    end

                    local anchor = findMachineAnchor(chosen.machineId, chosen.fallbackPos)
                    if not anchor then
                        setCarnivalStatus("Streaming Carnival area...", C.accent)
                        if chosen.fallbackPos then
                            safeTP(CFrame.new(chosen.fallbackPos + Vector3.new(0, 2, 0)))
                            task.wait(0.8)
                            anchor = findMachineAnchor(chosen.machineId)
                        end
                        if not anchor then
                            setCarnivalStatus("Machine not found: " .. chosen.key, C.red)
                            task.wait(1.5)
                            return
                        end
                    end

                    local char = lp.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end

                    if (hrp.Position - anchor.Position).Magnitude > 9 then
                        setCarnivalStatus("Moving to " .. chosen.key .. "...", C.accent)
                        safeTP(CFrame.new(anchor.Position + Vector3.new(0, 1.5, 0)))
                        task.wait(0.35)
                    end

                    local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt then
                        syncCarnivalNativeHandlers()
                        setCarnivalStatus("Starting " .. chosen.key .. "...", C.accent)
                        firePrompt(prompt)
                        local waitStart = os.clock()
                        while gConfig.autoPlayCarnival and not activeRound and os.clock() - waitStart < 3.5 do
                            task.wait(0.1)
                        end
                        while gConfig.autoPlayCarnival and activeRound and os.clock() - activeRound.startedAt < 45 do
                            task.wait(0.15)
                        end
                        local mCfg = reqMod("CarnivalMachineConfig")
                        task.wait((mCfg and mCfg.PlayCooldown or 1.2) + 0.35)
                    else
                        task.wait(0.8)
                    end
                end)
            end
        end)
    end

    -- Cargo Ship Subtab overrides
    -- Replace Cargo Ship teleport action with safeTP
    -- (We don't need to redeclare createButton but let's redefine the buttons below)

    -- Power Plant Subtab
    local ppToggleCard, updatePPToggle = createToggle(tabPowerPlant, "Auto Engineer Quest Deliveries", gConfig.autoEngineerQuest, function(state)
        gConfig.autoEngineerQuest = state
        saveConfig()
    end)
    _G.uiToggles["autoEngineerQuest"] = updatePPToggle

    local protectCard, updateProtectToggle = createToggle(tabPowerPlant, "Protect Quest Parts from Auto-Place", gConfig.protectQuestParts ~= false, function(state)
        gConfig.protectQuestParts = state
        _G.protectQuestParts = state
        saveConfig()
    end)
    _G.uiToggles["protectQuestParts"] = updateProtectToggle
    createButton(tabPowerPlant, "Teleport to Engineer", function()
        safeTP(CFrame.new(-2067.65, 1724.77, -857.52))
    end)

    -- [Power] ENGINEER QUEST LIVE STATUS & PARTS CHECKLIST CARD
    local statusCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabPowerPlant)
    corner(8, statusCard)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
    }, statusCard)

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, statusCard)

    -- Header Row: Title + Refresh Button
    local headerRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    }, statusCard)

    make("TextLabel", {
        Size = UDim2.new(0.68, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "ENGINEER QUEST STATUS",
        TextColor3 = C.accent,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, headerRow)

    local refreshBtn = make("TextButton", {
        Size = UDim2.new(0.32, 0, 1, 0),
        Position = UDim2.new(0.68, 0, 0, 0),
        BackgroundColor3 = C.panel,
        Text = "Refresh",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, headerRow)
    corner(4, refreshBtn)

    -- Tier & Placed Summary
    local tierSummaryLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "Scanning active tier...",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 2,
    }, statusCard)

    -- Progress Bar
    local pBarBg = make("Frame", {
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(30, 36, 52),
        BorderSizePixel = 0,
        LayoutOrder = 3,
    }, statusCard)
    corner(3, pBarBg)

    local pBarFill = make("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = C.green,
        BorderSizePixel = 0,
    }, pBarBg)
    corner(3, pBarFill)

    -- Bag Ready Summary
    local bagReadyLbl = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14),
        BackgroundTransparency = 1,
        Text = "Checking backpack...",
        TextColor3 = C.text2,
        TextSize = 9,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 4,
    }, statusCard)

    -- Deliver Now Button
    local deliverNowBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = Color3.fromRGB(0, 120, 90),
        Text = "Deliver Available Parts Now",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        LayoutOrder = 5,
    }, statusCard)
    corner(5, deliverNowBtn)

    -- Parts Checklist Header
    local listHeader = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "PARTS NEEDED FOR ACTIVE TIER:",
        TextColor3 = Color3.fromRGB(200, 210, 235),
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 6,
    }, statusCard)

    -- Container for dynamic part rows
    local itemsContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 7,
    }, statusCard)

    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
    }, itemsContainer)

    local function updateEngineerUI()
        local pp = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("Power Plant")
        local partsToFind = pp and pp:FindFirstChild("PartsToFind")
        if not partsToFind then
            tierSummaryLbl.Text = "Power Plant not loaded"
            return
        end

        local invRemote = ReplicatedStorage:FindFirstChild("Events")
            and ReplicatedStorage.Events:FindFirstChild("Inventory")
            and ReplicatedStorage.Events.Inventory:FindFirstChild("GetPlayerInventory")
        local inv = invRemote and invRemote:InvokeServer() or {}

        local userItems = {}
        for _, it in pairs(inv) do
            local d = ItemsData and (ItemsData[tostring(it.ItemId)] or ItemsData[tonumber(it.ItemId)])
            local name = d and d.Name
            if name then
                userItems[name] = (userItems[name] or 0) + 1
            end
        end

        local activeTier = nil
        local activeTierPlaced = 0
        local activeTierTotal = 0
        local activeTierMissing = 0
        local missingPartsMap = {}

        local orderedTiers = {"Tier1", "Tier2", "Tier3", "Tier4", "Weather Machine"}
        for _, tName in ipairs(orderedTiers) do
            local tier = partsToFind:FindFirstChild(tName)
            if tier then
                local tTotal = 0
                local tPlaced = 0
                local tMissing = 0
                local tMissingMap = {}
                for _, d in ipairs(tier:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Name == "PowerPlantPartPrompt" then
                        tTotal = tTotal + 1
                        local partName = (d.ObjectText and d.ObjectText ~= "") and d.ObjectText or (d.Parent and d.Parent.Parent and d.Parent.Parent.Name) or "Unknown Part"
                        if d.Enabled then
                            tMissing = tMissing + 1
                            tMissingMap[partName] = (tMissingMap[partName] or 0) + 1
                        else
                            tPlaced = tPlaced + 1
                        end
                    end
                end

                if tMissing > 0 and not activeTier then
                    activeTier = tName
                    activeTierPlaced = tPlaced
                    activeTierTotal = tTotal
                    activeTierMissing = tMissing
                    missingPartsMap = tMissingMap
                end
            end
        end

        -- Clear existing items
        for _, child in ipairs(itemsContainer:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        if not activeTier then
            tierSummaryLbl.Text = "All Power Plant Tiers Completed!"
            pBarFill.Size = UDim2.new(1, 0, 1, 0)
            bagReadyLbl.Text = "Every single part has been installed."
            return
        end

        local friendlyTierName = activeTier
        if activeTier == "Tier1" then friendlyTierName = "Tier 1"
        elseif activeTier == "Tier2" then friendlyTierName = "Tier 2"
        elseif activeTier == "Tier3" then friendlyTierName = "Tier 3"
        elseif activeTier == "Tier4" then friendlyTierName = "Tier 4" end

        tierSummaryLbl.Text = string.format("Active: %s • %d/%d Placed (%d Needed)", friendlyTierName, activeTierPlaced, activeTierTotal, activeTierMissing)
        local progressRatio = math.clamp(activeTierPlaced / math.max(1, activeTierTotal), 0, 1)
        pBarFill.Size = UDim2.new(progressRatio, 0, 1, 0)

        local itemsList = {}
        local readyDeliverCount = 0
        for name, neededCount in pairs(missingPartsMap) do
            local inBag = userItems[name] or 0
            if inBag > 0 then
                readyDeliverCount = readyDeliverCount + math.min(inBag, neededCount)
            end
            table.insert(itemsList, {
                name = name,
                needed = neededCount,
                inBag = inBag
            })
        end

        table.sort(itemsList, function(a, b)
            if (a.inBag > 0) ~= (b.inBag > 0) then
                return a.inBag > 0
            end
            return a.needed > b.needed
        end)

        if readyDeliverCount > 0 then
            bagReadyLbl.Text = string.format("%d parts ready in your bag to deliver!", readyDeliverCount)
            bagReadyLbl.TextColor3 = C.green
            deliverNowBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            deliverNowBtn.Text = string.format("Deliver %d Ready Parts Now", readyDeliverCount)
        else
            bagReadyLbl.Text = "No matching parts in bag. Farm or buy missing items below."
            bagReadyLbl.TextColor3 = C.text2
            deliverNowBtn.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
            deliverNowBtn.Text = "Deliver Available Parts Now (0 in bag)"
        end

        for idx, item in ipairs(itemsList) do
            local itemRow = make("Frame", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = item.inBag > 0 and Color3.fromRGB(22, 38, 35) or Color3.fromRGB(15, 18, 28),
                BorderSizePixel = 0,
                LayoutOrder = idx,
            }, itemsContainer)
            corner(4, itemRow)

            make("TextLabel", {
                Size = UDim2.new(0.68, 0, 1, 0),
                Position = UDim2.new(0, 6, 0, 0),
                BackgroundTransparency = 1,
                Text = string.format("%s (Need %d)", item.name, item.needed),
                TextColor3 = item.inBag > 0 and Color3.fromRGB(235, 255, 245) or C.text,
                TextSize = 9,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, itemRow)

            local badgeText = (item.inBag > 0) and string.format("%d IN BAG", item.inBag) or "0 in bag"
            local badgeCol = (item.inBag > 0) and C.green or C.textMuted
            make("TextLabel", {
                Size = UDim2.new(0.3, -6, 1, 0),
                Position = UDim2.new(0.7, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = badgeText,
                TextColor3 = badgeCol,
                TextSize = 9,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Right,
            }, itemRow)
        end
    end

    refreshBtn.MouseButton1Click:Connect(function()
        pcall(updateEngineerUI)
    end)

    local function performEngineerDeliveries()
        if _G.questTpInProgress or _G.isMiningActive or _G.isFreightCollecting or AB.quickWinActive then return false end

        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return false end

        -- 1. Scan player inventory for Power Plant items
        local invRemote = ReplicatedStorage:FindFirstChild("Events")
            and ReplicatedStorage.Events:FindFirstChild("Inventory")
            and ReplicatedStorage.Events.Inventory:FindFirstChild("GetPlayerInventory")
        local inv = invRemote and invRemote:InvokeServer()
        if not inv or type(inv) ~= "table" or next(inv) == nil then
            return false
        end

        local ownedParts = {}
        for _, it in pairs(inv) do
            local itemConf = ItemsData and (ItemsData[tostring(it.ItemId)] or ItemsData[tonumber(it.ItemId)])
            local name = itemConf and itemConf.Name
            if name and name ~= "" then
                ownedParts[name] = (ownedParts[name] or 0) + 1
            end
        end

        local pp = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("Power Plant")
        local partsToFind = pp and pp:FindFirstChild("PartsToFind")
        if not partsToFind then return false end

        local hasAnyMatch = false
        local orderedTiers = {"Tier1", "Tier2", "Tier3", "Tier4", "Weather Machine"}
        for _, tName in ipairs(orderedTiers) do
            local tier = partsToFind:FindFirstChild(tName)
            if tier then
                for _, part in ipairs(tier:GetDescendants()) do
                    if part:IsA("ProximityPrompt") and part.Name == "PowerPlantPartPrompt" and part.Enabled then
                        local targetName = (part.ObjectText and part.ObjectText ~= "") and part.ObjectText or (part.Parent and part.Parent.Parent and part.Parent.Parent.Name)
                        if targetName and ownedParts[targetName] and ownedParts[targetName] > 0 then
                            hasAnyMatch = true
                            break
                        end
                    end
                end
                if hasAnyMatch then break end
            end
        end

        if not hasAnyMatch then return false end

        -- 2. Lock and begin delivery
        _G.questTpInProgress = true
        abLog("[Power] Power Plant Quest: Found matching parts in bag! Focusing on deliveries first...", C.green)
        showWorkshopPopup("Focusing on Power Plant deliveries...", C.green)

        local vehicle = getMyVehicle()
        local vRoot = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("Body") or vehicle:FindFirstChildWhichIsA("BasePart"))
        local oldCF = root.CFrame
        local wasSeated = hum.Sit

        -- Step out of vehicle seat so vehicle isn't dragged into tight building corridors
        if hum.Sit then
            if vRoot then
                oldCF = vRoot.CFrame
            end
            hum.Sit = false
            task.wait(0.25)
        end

        local deliveredCount = 0
        local maxPasses = 30
        local pass = 0

        while pass < maxPasses do
            pass = pass + 1

            local curPrompt = nil
            local curItemName = nil

            for _, tName in ipairs(orderedTiers) do
                local tier = partsToFind:FindFirstChild(tName)
                if tier then
                    for _, part in ipairs(tier:GetDescendants()) do
                        if part:IsA("ProximityPrompt") and part.Name == "PowerPlantPartPrompt" and part.Enabled then
                            local targetName = (part.ObjectText and part.ObjectText ~= "") and part.ObjectText or (part.Parent and part.Parent.Parent and part.Parent.Parent.Name)
                            if targetName and ownedParts[targetName] and ownedParts[targetName] > 0 then
                                curPrompt = part
                                curItemName = targetName
                                break
                            end
                        end
                    end
                    if curPrompt then break end
                end
            end

            if not curPrompt then break end

            deliveredCount = deliveredCount + 1
            abLog(string.format("[Power] Auto-Quest: Delivering (%d) %s...", deliveredCount, tostring(curItemName)), C.green)

            local promptPart = curPrompt.Parent
            safeTP(promptPart.CFrame + Vector3.new(0, 2, 0))
            task.wait(1.5)

            if fireproximityprompt then
                pcall(function() fireproximityprompt(curPrompt) end)
            else
                pcall(function()
                    curPrompt:InputHoldBegin()
                    task.wait((curPrompt.HoldDuration or 0.8) + 0.1)
                    curPrompt:InputHoldEnd()
                end)
            end
            task.wait(2.0)

            ownedParts[curItemName] = (ownedParts[curItemName] or 1) - 1
            pcall(updateEngineerUI)
        end

        -- Return safely to original location
        abLog("[Power] Auto-Quest: Finished deliveries. Returning to previous location...", C.green)
        safeTP(oldCF + Vector3.new(0, 3, 0))
        task.wait(1.0)

        -- Re-sit in vehicle if player was seated originally
        if wasSeated and vehicle and hum and hum.Health > 0 then
            local seat = vehicle:FindFirstChild("DriveSeat") or vehicle:FindFirstChildWhichIsA("VehicleSeat")
            if seat then
                pcall(function() seat:Sit(hum) end)
                task.wait(0.3)
            end
        end

        _G.questTpInProgress = false
        pcall(updateEngineerUI)

        if deliveredCount > 0 then
            abLog(string.format("[Power] Auto-Quest: Delivered %d Power Plant parts! Resuming autofarm.", deliveredCount), C.green)
            showWorkshopPopup(string.format("Delivered %d parts! Resuming autofarm.", deliveredCount), C.green)
        end

        return deliveredCount > 0
    end
    _G.performEngineerDeliveries = performEngineerDeliveries

    deliverNowBtn.MouseButton1Click:Connect(function()
        if _G.questTpInProgress then
            showWorkshopPopup("A quest delivery is already in progress!", C.orange)
            return
        end
        task.spawn(function()
            local success = performEngineerDeliveries()
            if not success then
                showWorkshopPopup("No matching parts in bag to deliver!", C.orange)
            end
        end)
    end)

    -- Initial load & live hook
    task.spawn(function()
        task.wait(1.5)
        pcall(updateEngineerUI)
    end)
    _G.refreshEngineerQuestUI = updateEngineerUI




    -- Acid Rain Subtab
    createButton(tabAcidRain, "Teleport to Mad Scientist", function()
        safeTP(CFrame.new(-2085.58, 1724.85, -1105.5))
    end)

    -- Museum Subtab - Remote Controller UI
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local museumFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Museum")
    local MuseumConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MuseumConfig"))
    local ItemsModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))

    -- Title header / teleport panel (parented directly to tabMuseum)
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(0.95, 0, 0, 50)
    headerFrame.BackgroundColor3 = C.panel
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = tabMuseum

    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = headerFrame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(0.6, 0, 1, 0)
    titleLbl.Position = UDim2.new(0.02, 0, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = "Museum Remote Controller"
    titleLbl.TextColor3 = C.text
    titleLbl.TextSize = 18
    titleLbl.Font = Enum.Font.SourceSansBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = headerFrame

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0.32, 0, 0.7, 0)
    tpBtn.Position = UDim2.new(0.66, 0, 0.15, 0)
    tpBtn.BackgroundColor3 = C.border
    tpBtn.Text = "Teleport to Museum"
    tpBtn.TextColor3 = C.text
    tpBtn.TextSize = 13
    tpBtn.Font = Enum.Font.SourceSansBold
    tpBtn.Parent = headerFrame

    local tpCorner = Instance.new("UICorner")
    tpCorner.CornerRadius = UDim.new(0, 6)
    tpCorner.Parent = tpBtn

    tpBtn.MouseButton1Click:Connect(function()
        safeTP(CFrame.new(540.99, 1728.87, -188.22))
    end)
    
    local autoCollectCard, updateAutoCollect = createToggle(tabMuseum, "Auto Collect Museum Gifts", gConfig.autoCollectMuseumGifts, function(state)
        gConfig.autoCollectMuseumGifts = state
        saveConfig()
    end)
    _G.uiToggles["autoCollectMuseumGifts"] = updateAutoCollect

    -- Dynamic Slots Frame Holder (parented directly to tabMuseum)
    local slotsHolder = Instance.new("Frame")
    slotsHolder.Size = UDim2.new(0.95, 0, 0, 140) -- Auto adjusts later based on maxSlots
    slotsHolder.BackgroundTransparency = 1
    slotsHolder.Parent = tabMuseum

    local slotsLayout = Instance.new("UIListLayout")
    slotsLayout.Padding = UDim.new(0, 10)
    slotsLayout.Parent = slotsHolder

    -- Items Drawer Panel (parented directly to tabMuseum)
    local drawerFrame = Instance.new("Frame")
    drawerFrame.Size = UDim2.new(0.95, 0, 0, 300)
    drawerFrame.BackgroundColor3 = C.panel
    drawerFrame.BorderSizePixel = 0
    drawerFrame.Visible = false
    drawerFrame.Parent = tabMuseum

    local drawerCorner = Instance.new("UICorner")
    drawerCorner.CornerRadius = UDim.new(0, 8)
    drawerCorner.Parent = drawerFrame

    local drawerTitle = Instance.new("TextLabel")
    drawerTitle.Size = UDim2.new(1, 0, 0, 35)
    drawerTitle.BackgroundTransparency = 1
    drawerTitle.Text = "  Select Inventory Item to Display"
    drawerTitle.TextColor3 = C.gold
    drawerTitle.TextSize = 15
    drawerTitle.Font = Enum.Font.SourceSansBold
    drawerTitle.TextXAlignment = Enum.TextXAlignment.Left
    drawerTitle.Parent = drawerFrame

    local drawerCloseBtn = Instance.new("TextButton")
    drawerCloseBtn.Size = UDim2.new(0, 50, 0, 30)
    drawerCloseBtn.Position = UDim2.new(1, -55, 0, 2.5)
    drawerCloseBtn.BackgroundTransparency = 1
    drawerCloseBtn.Text = "X"
    drawerCloseBtn.TextColor3 = C.red
    drawerCloseBtn.TextSize = 16
    drawerCloseBtn.Font = Enum.Font.SourceSansBold
    drawerCloseBtn.Parent = drawerFrame

    drawerCloseBtn.MouseButton1Click:Connect(function()
        drawerFrame.Visible = false
    end)

    local drawerScroll = Instance.new("ScrollingFrame")
    drawerScroll.Size = UDim2.new(0.96, 0, 0.8, 0)
    drawerScroll.Position = UDim2.new(0.02, 0, 0.15, 0)
    drawerScroll.BackgroundTransparency = 1
    drawerScroll.BorderSizePixel = 0
    drawerScroll.ScrollBarThickness = 4
    drawerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    drawerScroll.Parent = drawerFrame

    local drawerListLayout = Instance.new("UIListLayout")
    drawerListLayout.Padding = UDim.new(0, 8)
    drawerListLayout.Parent = drawerScroll

    local selectedSlotForDrawer = nil

    local function refreshMuseumUI()
        slotsHolder:ClearAllChildren()
        local sListLayout = Instance.new("UIListLayout")
        sListLayout.Padding = UDim.new(0, 10)
        sListLayout.Parent = slotsHolder

        local ok, state = pcall(function() return museumFolder.GetState:InvokeServer() end)
        if not ok or not state then
            local errLbl = Instance.new("TextLabel")
            errLbl.Size = UDim2.new(1, 0, 0, 50)
            errLbl.BackgroundTransparency = 1
            errLbl.Text = "Failed to load Museum state. Reconnecting..."
            errLbl.TextColor3 = C.red
            errLbl.TextSize = 14
            errLbl.Font = Enum.Font.SourceSans
            errLbl.Parent = slotsHolder
            return
        end

        local slotsData = state.Slots or {}
        local unlocked = state.Unlocked or 1
        local maxSlots = state.MaxSlots or 3
        local costs = state.Costs or {}

        slotsHolder.Size = UDim2.new(0.95, 0, 0, maxSlots * 140)

        for i = 1, maxSlots do
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 130)
            card.BackgroundColor3 = C.card
            card.BorderSizePixel = 0
            card.Parent = slotsHolder

            local cardCorner = Instance.new("UICorner")
            cardCorner.CornerRadius = UDim.new(0, 6)
            cardCorner.Parent = card

            local slotTitle = Instance.new("TextLabel")
            slotTitle.Size = UDim2.new(0.5, 0, 0, 30)
            slotTitle.Position = UDim2.new(0.03, 0, 0.05, 0)
            slotTitle.BackgroundTransparency = 1
            slotTitle.Text = "Slot " .. tostring(i)
            slotTitle.TextColor3 = C.text2
            slotTitle.TextSize = 14
            slotTitle.Font = Enum.Font.SourceSansBold
            slotTitle.TextXAlignment = Enum.TextXAlignment.Left
            slotTitle.Parent = card

            if i <= unlocked then
                local slotKey = tostring(i)
                local displayData = slotsData[slotKey]
                if displayData then
                    -- Active Slot
                    local itemData = displayData.ItemData or {}
                    local itemId = tostring(itemData.ItemId or "")
                    local itemConf = ItemsModule[itemId]
                    local itemName = itemConf and itemConf.Name or "Unknown Item"
                    local itemVal = displayData.Value or 0
                    local luckBonus = displayData.LuckPoints or 5
                    local nextReward = displayData.NextRewardIn or 3600

                    slotTitle.Text = "Slot " .. tostring(i) .. ": [ACTIVE - " .. itemName .. "]"
                    slotTitle.TextColor3 = C.accent

                    local infoLbl = Instance.new("TextLabel")
                    infoLbl.Size = UDim2.new(0.6, 0, 0, 50)
                    infoLbl.Position = UDim2.new(0.03, 0, 0.35, 0)
                    infoLbl.BackgroundTransparency = 1
                    infoLbl.Text = string.format("Value: $%s\nLuck Bonus: +%d%% Luck\nNext Gift in: %s", 
                        tostring(math.floor(itemVal)), 
                        luckBonus, 
                        (nextReward <= 0 and "READY TO COLLECT!" or string.format("%dm %ds", math.floor(nextReward/60), math.floor(nextReward%60)))
                    )
                    infoLbl.TextColor3 = (nextReward <= 0 and C.green or C.text)
                    infoLbl.TextSize = 13
                    infoLbl.Font = Enum.Font.SourceSans
                    infoLbl.TextXAlignment = Enum.TextXAlignment.Left
                    infoLbl.Parent = card

                    if nextReward <= 0 then
                        local claimBtn = Instance.new("TextButton")
                        claimBtn.Size = UDim2.new(0.3, 0, 0.35, 0)
                        claimBtn.Position = UDim2.new(0.67, 0, 0.15, 0)
                        claimBtn.BackgroundColor3 = C.green
                        claimBtn.Text = "Claim Gift"
                        claimBtn.TextColor3 = C.text
                        claimBtn.TextSize = 13
                        claimBtn.Font = Enum.Font.SourceSansBold
                        claimBtn.Parent = card

                        local claimCorner = Instance.new("UICorner")
                        claimCorner.CornerRadius = UDim.new(0, 6)
                        claimCorner.Parent = claimBtn

                        claimBtn.MouseButton1Click:Connect(function()
                            claimBtn.Text = "Claiming..."
                            pcall(function() museumFolder.Collect:InvokeServer(i) end)
                            task.wait(0.5)
                            refreshMuseumUI()
                        end)
                    end

                    local withdrawBtn = Instance.new("TextButton")
                    withdrawBtn.Size = UDim2.new(0.3, 0, 0.35, 0)
                    withdrawBtn.Position = UDim2.new(0.67, 0, 0.55, 0)
                    withdrawBtn.BackgroundColor3 = C.red
                    withdrawBtn.Text = "Withdraw Item"
                    withdrawBtn.TextColor3 = C.text
                    withdrawBtn.TextSize = 13
                    withdrawBtn.Font = Enum.Font.SourceSansBold
                    withdrawBtn.Parent = card

                    local withdrawCorner = Instance.new("UICorner")
                    withdrawCorner.CornerRadius = UDim.new(0, 6)
                    withdrawCorner.Parent = withdrawBtn

                    withdrawBtn.MouseButton1Click:Connect(function()
                        withdrawBtn.Text = "Withdrawing..."
                        pcall(function() museumFolder.Withdraw:InvokeServer(i) end)
                        task.wait(0.5)
                        refreshMuseumUI()
                    end)
                else
                    -- Empty Slot
                    slotTitle.Text = "Slot " .. tostring(i) .. ": [EMPTY]"
                    slotTitle.TextColor3 = C.text2

                    local selectBtn = Instance.new("TextButton")
                    selectBtn.Size = UDim2.new(0.94, 0, 0.45, 0)
                    selectBtn.Position = UDim2.new(0.03, 0, 0.35, 0)
                    selectBtn.BackgroundColor3 = C.border
                    selectBtn.Text = "Select Item to Display"
                    selectBtn.TextColor3 = C.text
                    selectBtn.TextSize = 14
                    selectBtn.Font = Enum.Font.SourceSansBold
                    selectBtn.Parent = card

                    local selectCorner = Instance.new("UICorner")
                    selectCorner.CornerRadius = UDim.new(0, 6)
                    selectCorner.Parent = selectBtn

                    selectBtn.MouseButton1Click:Connect(function()
                        selectedSlotForDrawer = i
                        drawerScroll:ClearAllChildren()
                        local dLayout = Instance.new("UIListLayout")
                        dLayout.Padding = UDim.new(0, 8)
                        dLayout.Parent = drawerScroll

                        local eligibleList = state.Eligible or {}
                        local count = 0
                        for guid, itemEntry in pairs(eligibleList) do
                            count = count + 1
                            local itemId = tostring(itemEntry.ItemId or "")
                            local itemConf = ItemsModule[itemId]
                            local itemName = itemConf and itemConf.Name or "Unknown Item"
                            
                            local itemVal, cost, luckPoints = calcEntryValueAndCost(itemEntry)

                            local itemCard = Instance.new("Frame")
                            itemCard.Size = UDim2.new(0.98, 0, 0, 55)
                            itemCard.BackgroundColor3 = C.card
                            itemCard.BorderSizePixel = 0
                            itemCard.Parent = drawerScroll

                            local icCorner = Instance.new("UICorner")
                            icCorner.CornerRadius = UDim.new(0, 5)
                            icCorner.Parent = itemCard

                            local nameLbl = Instance.new("TextLabel")
                            nameLbl.Size = UDim2.new(0.65, 0, 0.5, 0)
                            nameLbl.Position = UDim2.new(0.02, 0, 0.05, 0)
                            nameLbl.BackgroundTransparency = 1
                            nameLbl.Text = itemName .. " ($" .. tostring(math.floor(itemVal)) .. ")"
                            nameLbl.TextColor3 = C.text
                            nameLbl.TextSize = 13
                            nameLbl.Font = Enum.Font.SourceSansBold
                            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                            nameLbl.Parent = itemCard

                            local detailsLbl = Instance.new("TextLabel")
                            detailsLbl.Size = UDim2.new(0.65, 0, 0.45, 0)
                            detailsLbl.Position = UDim2.new(0.02, 0, 0.5, 0)
                            detailsLbl.BackgroundTransparency = 1
                            detailsLbl.Text = string.format("Luck: +%d%% | Cost: %d ", luckPoints, cost)
                            detailsLbl.TextColor3 = C.text2
                            detailsLbl.TextSize = 12
                            detailsLbl.Font = Enum.Font.SourceSans
                            detailsLbl.TextXAlignment = Enum.TextXAlignment.Left
                            detailsLbl.Parent = itemCard

                            local dispBtn = Instance.new("TextButton")
                            dispBtn.Size = UDim2.new(0.28, 0, 0.7, 0)
                            dispBtn.Position = UDim2.new(0.7, 0, 0.15, 0)
                            dispBtn.BackgroundColor3 = C.accent
                            dispBtn.Text = "Display"
                            dispBtn.TextColor3 = C.text
                            dispBtn.TextSize = 12
                            dispBtn.Font = Enum.Font.SourceSansBold
                            dispBtn.Parent = itemCard

                            local dispCorner = Instance.new("UICorner")
                            dispCorner.CornerRadius = UDim.new(0, 4)
                            dispCorner.Parent = dispBtn

                            dispBtn.MouseButton1Click:Connect(function()
                                dispBtn.Text = "Wait..."
                                pcall(function() museumFolder.Donate:InvokeServer(selectedSlotForDrawer, guid) end)
                                task.wait(0.5)
                                drawerFrame.Visible = false
                                refreshMuseumUI()
                            end)
                        end

                        if count == 0 then
                            local emptyLbl = Instance.new("TextLabel")
                            emptyLbl.Size = UDim2.new(1, 0, 0, 50)
                            emptyLbl.BackgroundTransparency = 1
                            emptyLbl.Text = "No eligible items in inventory to display!"
                            emptyLbl.TextColor3 = C.text2
                            emptyLbl.TextSize = 13
                            emptyLbl.Font = Enum.Font.SourceSansItalic
                            emptyLbl.Parent = drawerScroll
                        end

                        drawerScroll.CanvasSize = UDim2.new(0, 0, 0, count * 63)
                        drawerFrame.Visible = true
                    end)
                end
            else
                -- Locked Slot
                slotTitle.Text = "Slot " .. tostring(i) .. ": [LOCKED]"
                slotTitle.TextColor3 = C.red

                local cost = costs[tostring(i)] or 75
                local unlockBtn = Instance.new("TextButton")
                unlockBtn.Size = UDim2.new(0.94, 0, 0.45, 0)
                unlockBtn.Position = UDim2.new(0.03, 0, 0.35, 0)
                unlockBtn.BackgroundColor3 = C.red
                unlockBtn.Text = "Unlock Slot (Cost: " .. tostring(cost) .. " Diamonds)"
                unlockBtn.TextColor3 = C.text
                unlockBtn.TextSize = 14
                unlockBtn.Font = Enum.Font.SourceSansBold
                unlockBtn.Parent = card

                local unlockCorner = Instance.new("UICorner")
                unlockCorner.CornerRadius = UDim.new(0, 6)
                unlockCorner.Parent = unlockBtn

                unlockBtn.MouseButton1Click:Connect(function()
                    unlockBtn.Text = "Unlocking..."
                    pcall(function() museumFolder.UnlockSlot:InvokeServer(i) end)
                    task.wait(0.5)
                    refreshMuseumUI()
                end)
            end
        end
    end

    -- Static gifts guide panel
    local guideFrame = Instance.new("Frame")
    guideFrame.Size = UDim2.new(0.95, 0, 0, 160)
    guideFrame.BackgroundColor3 = C.panel
    guideFrame.BorderSizePixel = 0
    guideFrame.Parent = tabMuseum

    local guideCorner = Instance.new("UICorner")
    guideCorner.CornerRadius = UDim.new(0, 8)
    guideCorner.Parent = guideFrame

    local guideTitle = Instance.new("TextLabel")
    guideTitle.Size = UDim2.new(1, 0, 0, 30)
    guideTitle.Position = UDim2.new(0.03, 0, 0.05, 0)
    guideTitle.BackgroundTransparency = 1
    guideTitle.Text = "Hourly Visitor Gifts Guide"
    guideTitle.TextColor3 = C.gold
    guideTitle.TextSize = 14
    guideTitle.Font = Enum.Font.SourceSansBold
    guideTitle.TextXAlignment = Enum.TextXAlignment.Left
    guideTitle.Parent = guideFrame

    local guideList = Instance.new("TextLabel")
    guideList.Size = UDim2.new(0.94, 0, 0.7, 0)
    guideList.Position = UDim2.new(0.03, 0, 0.25, 0)
    guideList.BackgroundTransparency = 1
    guideList.Text = "- [75%] 5 Diamonds\n- [10%] 10 Diamonds\n- [10%] Luck Drink 1\n- [4%] 20 Diamonds\n- [1%] Luck Drink 2\n- [0.25%] [Showcased] Bonus Mutator Roll"
    guideList.TextColor3 = C.text2
    guideList.TextSize = 12
    guideList.Font = Enum.Font.SourceSans
    guideList.TextXAlignment = Enum.TextXAlignment.Left
    guideList.TextYAlignment = Enum.TextYAlignment.Top
    guideList.Parent = guideFrame

    -- Run refresh when tab opens
    task.spawn(function()
        while task.wait(5) do
            if tabMuseum and tabMuseum.Visible then
                refreshMuseumUI()
            end
        end
    end)

    -- Force initial refresh
    task.spawn(refreshMuseumUI)
end

    -- ⌛ Time Capsule Subtab Setup
    do
        list(nil, 6, tabTimeCapsule)

        local tcFolder = ReplicatedStorage:WaitForChild("Events"):WaitForChild("TimeCapsule")
        local TimeCapsuleConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("TimeCapsuleConfig"))
        local ItemsModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Items"))

        -- 1. Header Panel
        local headerFrame = Instance.new("Frame")
        headerFrame.Size = UDim2.new(0.95, 0, 0, 50)
        headerFrame.BackgroundColor3 = C.panel
        headerFrame.BorderSizePixel = 0
        headerFrame.Parent = tabTimeCapsule

        local headerCorner = Instance.new("UICorner")
        headerCorner.CornerRadius = UDim.new(0, 8)
        headerCorner.Parent = headerFrame

        local titleLbl = Instance.new("TextLabel")
        titleLbl.Size = UDim2.new(0.6, 0, 1, 0)
        titleLbl.Position = UDim2.new(0.02, 0, 0, 0)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = "⌛ Time Capsule Controller"
        titleLbl.TextColor3 = C.text
        titleLbl.TextSize = 18
        titleLbl.Font = Enum.Font.SourceSansBold
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.Parent = headerFrame

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0.32, 0, 0.7, 0)
        tpBtn.Position = UDim2.new(0.66, 0, 0.15, 0)
        tpBtn.BackgroundColor3 = C.border
        tpBtn.Text = "Teleport to Capsule"
        tpBtn.TextColor3 = C.text
        tpBtn.TextSize = 13
        tpBtn.Font = Enum.Font.SourceSansBold
        tpBtn.Parent = headerFrame

        local tpCorner = Instance.new("UICorner")
        tpCorner.CornerRadius = UDim.new(0, 6)
        tpCorner.Parent = tpBtn

        tpBtn.MouseButton1Click:Connect(function()
            safeTP(CFrame.new(576.34, 1726, -494.82))
        end)

        -- Time Capsule Auto-Collect Options
        local tcAutoCollectCard, updateTCAutoCollect = createToggle(tabTimeCapsule, "Auto Collect Time Capsule Items", gConfig.autoCollectTimeCapsules, function(state)
            gConfig.autoCollectTimeCapsules = state
            saveConfig()
        end)
        _G.uiToggles["autoCollectTimeCapsules"] = updateTCAutoCollect

        -- Multi-selection dropdown for Target Mutators
        local tcMutatorsDropdownCard = make("Frame", {
            Size = UDim2.new(0.95, 0, 0, 38),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            ZIndex = 15,
        }, tabTimeCapsule)
        corner(6, tcMutatorsDropdownCard)

        make("TextLabel", {
            Size = UDim2.new(0.4, 0, 1, 0),
            Position = UDim2.new(0.03, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Target Mutation Tiers",
            TextColor3 = C.text,
            TextSize = 13,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, tcMutatorsDropdownCard)

        local tcDropdownBtn = make("TextButton", {
            Size = UDim2.new(0.5, 0, 0.7, 0),
            Position = UDim2.new(0.47, 0, 0.15, 0),
            BackgroundColor3 = C.border,
            Text = "Antique / Ancient / Timeless",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.SourceSansBold,
        }, tcMutatorsDropdownCard)
        corner(4, tcDropdownBtn)

        -- Quick selection toggle options list overlay
        local tcDropdownList = make("Frame", {
            Size = UDim2.new(0.5, 0, 0, 110),
            Position = UDim2.new(0.47, 0, 0.9, 0),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 1,
            BorderColor3 = C.border,
            Visible = false,
            ZIndex = 20,
        }, tcMutatorsDropdownCard)
        corner(4, tcDropdownList)

        local mutatorOptBtns = {}
        local function updateDropdownBtnText()
            local selected = {}
            if gConfig.targetCapsuleMutators["Cobwebbed"] then table.insert(selected, "Cob") end
            if gConfig.targetCapsuleMutators["Antique"] then table.insert(selected, "Ant") end
            if gConfig.targetCapsuleMutators["Ancient"] then table.insert(selected, "Anc") end
            if gConfig.targetCapsuleMutators["Timeless"] then table.insert(selected, "Time") end
            if #selected == 0 then
                tcDropdownBtn.Text = "None Selected"
            else
                tcDropdownBtn.Text = table.concat(selected, " / ")
            end
        end

        local function refreshCapsuleMutatorsUI()
            if not gConfig.targetCapsuleMutators then
                gConfig.targetCapsuleMutators = { ["Antique"] = true, ["Ancient"] = true, ["Timeless"] = true }
            end
            for name, optBtn in pairs(mutatorOptBtns) do
                local on = gConfig.targetCapsuleMutators[name] == true
                optBtn.Text = string.format("[%s] %s", on and "X" or " ", name)
                optBtn.TextColor3 = on and C.gold or C.text2
            end
            updateDropdownBtnText()
        end
        _G.uiUpdaters["targetCapsuleMutators"] = refreshCapsuleMutatorsUI

        local function createMutatorOption(name, yPos)
            local optBtn = make("TextButton", {
                Size = UDim2.new(0.9, 0, 0, 22),
                Position = UDim2.new(0.05, 0, 0, yPos),
                BackgroundTransparency = 1,
                Text = string.format("[%s] %s", gConfig.targetCapsuleMutators[name] and "X" or " ", name),
                TextColor3 = gConfig.targetCapsuleMutators[name] and C.gold or C.text2,
                TextSize = 12,
                Font = Enum.Font.SourceSansBold,
                ZIndex = 21,
            }, tcDropdownList)
            mutatorOptBtns[name] = optBtn
            
            optBtn.MouseButton1Click:Connect(function()
                gConfig.targetCapsuleMutators[name] = not gConfig.targetCapsuleMutators[name]
                optBtn.Text = string.format("[%s] %s", gConfig.targetCapsuleMutators[name] and "X" or " ", name)
                optBtn.TextColor3 = gConfig.targetCapsuleMutators[name] and C.gold or C.text2
                updateDropdownBtnText()
                saveConfig()
            end)
        end

        createMutatorOption("Cobwebbed", 5)
        createMutatorOption("Antique", 30)
        createMutatorOption("Ancient", 55)
        createMutatorOption("Timeless", 80)
        updateDropdownBtnText()

        tcDropdownBtn.MouseButton1Click:Connect(function()
            tcDropdownList.Visible = not tcDropdownList.Visible
        end)

        -- 2. Dynamic Slots Frame Holder
        local slotsHolder = Instance.new("Frame")
        slotsHolder.Size = UDim2.new(0.95, 0, 0, 160)
        slotsHolder.BackgroundTransparency = 1
        slotsHolder.Parent = tabTimeCapsule

-- Grid layout removed for single centered card

        -- 3. Items Drawer Panel (Overlay)
        local drawerFrame = Instance.new("Frame")
        drawerFrame.Size = UDim2.new(0.95, 0, 0, 160)
        drawerFrame.BackgroundColor3 = C.panel
        drawerFrame.BorderSizePixel = 0
        drawerFrame.Visible = false
        drawerFrame.Parent = tabTimeCapsule

        local drCorner = Instance.new("UICorner")
        drCorner.CornerRadius = UDim.new(0, 8)
        drCorner.Parent = drawerFrame

        local drawerTitle = Instance.new("TextLabel")
        drawerTitle.Size = UDim2.new(0.7, 0, 0, 25)
        drawerTitle.Position = UDim2.new(0.02, 0, 0.02, 0)
        drawerTitle.BackgroundTransparency = 1
        drawerTitle.Text = "Select Item to Bury"
        drawerTitle.TextColor3 = C.accent
        drawerTitle.TextSize = 14
        drawerTitle.Font = Enum.Font.SourceSansBold
        drawerTitle.TextXAlignment = Enum.TextXAlignment.Left
        drawerTitle.Parent = drawerFrame

        local closeDrawer = Instance.new("TextButton")
        closeDrawer.Size = UDim2.new(0.2, 0, 0, 20)
        closeDrawer.Position = UDim2.new(0.78, 0, 0.03, 0)
        closeDrawer.BackgroundColor3 = C.red
        closeDrawer.Text = "Close"
        closeDrawer.TextColor3 = C.text
        closeDrawer.TextSize = 12
        closeDrawer.Font = Enum.Font.SourceSansBold
        closeDrawer.Parent = drawerFrame

        local cdCorner = Instance.new("UICorner")
        cdCorner.CornerRadius = UDim.new(0, 4)
        cdCorner.Parent = closeDrawer

        closeDrawer.MouseButton1Click:Connect(function()
            drawerFrame.Visible = false
        end)

        local drawerScroll = Instance.new("ScrollingFrame")
        drawerScroll.Size = UDim2.new(0.96, 0, 0.78, 0)
        drawerScroll.Position = UDim2.new(0.02, 0, 0.18, 0)
        drawerScroll.BackgroundTransparency = 1
        drawerScroll.BorderSizePixel = 0
        drawerScroll.ScrollBarThickness = 4
        drawerScroll.ScrollBarImageColor3 = C.accent
        drawerScroll.Parent = drawerFrame

        local dsList = Instance.new("UIListLayout")
        dsList.Padding = UDim.new(0, 6)
        dsList.SortOrder = Enum.SortOrder.LayoutOrder
        dsList.Parent = drawerScroll

        local selectedSlotForDrawer = 1

        -- 4. Main Refresh Function
        local function refreshTimeCapsuleUI()
            local success, res = pcall(function() return tcFolder.GetSlotStates:InvokeServer() end)
            if not success or not res then return end

            for _, child in ipairs(slotsHolder:GetChildren()) do
                if true then
                    child:Destroy()
                end
            end

            local maxSlots = res.unlockedCount or 1
            local slots = res.slots or {}
            local costs = res.costs or {}

            for i = 1, 1 do
                local card = Instance.new("Frame")
                card.Size = UDim2.new(0.48, 0, 0.95, 0)
                card.Position = UDim2.new(0.26, 0, 0.025, 0)
                card.BackgroundColor3 = C.card
                card.BorderSizePixel = 0
                card.Parent = slotsHolder

                local cr = Instance.new("UICorner")
                cr.CornerRadius = UDim.new(0, 8)
                cr.Parent = card

                local slotTitle = Instance.new("TextLabel")
                slotTitle.Size = UDim2.new(0.94, 0, 0, 25)
                slotTitle.Position = UDim2.new(0.03, 0, 0.03, 0)
                slotTitle.BackgroundTransparency = 1
                slotTitle.Font = Enum.Font.SourceSansBold
                slotTitle.TextSize = 13
                slotTitle.TextXAlignment = Enum.TextXAlignment.Center
                slotTitle.Parent = card

                if i <= maxSlots then
                    slotTitle.Text = "" -- Hidden for single centered slot
                    slotTitle.TextColor3 = C.gold

                    local slotData = slots[tostring(i)] or slots[i]
                    if slotData and slotData.ItemData then
                        -- Occupied Slot
                        local item = slotData.ItemData
                        local itemName = ItemsModule[item.ItemId] and ItemsModule[item.ItemId].Name or "Unknown Item"
                        local baseVal = calcEntryValueAndCost(item)
                        local cycComp = slotData.CyclesCompleted or 0
                        local timeProg = slotData.CycleProgress or 0
                        local remSec = math.max(0, 300 - math.floor(timeProg))

                        local mutatorText = "None"
                        if item.Mutators and type(item.Mutators) == "table" then
                            local list = {}
                            for name, _ in pairs(item.Mutators) do
                                table.insert(list, tostring(name))
                            end
                            if #list > 0 then
                                mutatorText = table.concat(list, ", ")
                            end
                        end

                        -- Item Name Label (Larger, Bold)
                        local nameLabel = Instance.new("TextLabel")
                        nameLabel.Size = UDim2.new(0.94, 0, 0, 20)
                        nameLabel.Position = UDim2.new(0.03, 0, 0.04, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Text = itemName
                        nameLabel.TextColor3 = C.text
                        nameLabel.TextSize = 14
                        nameLabel.Font = Enum.Font.SourceSansBold
                        nameLabel.Parent = card

                        -- Value / Cycle Info Label
                        local valLabel = Instance.new("TextLabel")
                        valLabel.Size = UDim2.new(0.94, 0, 0, 16)
                        valLabel.Position = UDim2.new(0.03, 0, 0.18, 0)
                        valLabel.BackgroundTransparency = 1
                        valLabel.Text = string.format("Value: $%d | Cycle: %d", baseVal, cycComp)
                        valLabel.TextColor3 = C.text2
                        valLabel.TextSize = 11
                        valLabel.Font = Enum.Font.SourceSans
                        valLabel.Parent = card

                        -- Mutator Label (Color highlighted)
                        local mutLabel = Instance.new("TextLabel")
                        mutLabel.Size = UDim2.new(0.94, 0, 0, 16)
                        mutLabel.Position = UDim2.new(0.03, 0, 0.28, 0)
                        mutLabel.BackgroundTransparency = 1
                        mutLabel.Text = "Mutator: " .. mutatorText
                        mutLabel.TextColor3 = (mutatorText ~= "None") and C.gold or C.text2
                        mutLabel.TextSize = 11
                        mutLabel.Font = (mutatorText ~= "None") and Enum.Font.SourceSansBold or Enum.Font.SourceSans
                        mutLabel.Parent = card

                        -- Mutation Chances Label Title
                        local chanceTitle = Instance.new("TextLabel")
                        chanceTitle.Size = UDim2.new(0.94, 0, 0, 14)
                        chanceTitle.Position = UDim2.new(0.03, 0, 0.38, 0)
                        chanceTitle.BackgroundTransparency = 1
                        chanceTitle.Text = "── Mutation Chances ──"
                        chanceTitle.TextColor3 = C.border
                        chanceTitle.TextSize = 10
                        chanceTitle.Font = Enum.Font.SourceSansBold
                        chanceTitle.Parent = card

                        -- Left Column Chances Label
                        local leftChances = Instance.new("TextLabel")
                        leftChances.Size = UDim2.new(0.48, 0, 0, 32)
                        leftChances.Position = UDim2.new(0.06, 0, 0.45, 0)
                        leftChances.BackgroundTransparency = 1
                        leftChances.Text = "• Cob 2.5%\n• Anc 0.1%"
                        leftChances.TextColor3 = C.text2
                        leftChances.TextSize = 10
                        leftChances.Font = Enum.Font.SourceSansBold
                        leftChances.TextXAlignment = Enum.TextXAlignment.Left
                        leftChances.Parent = card

                        -- Right Column Chances Label
                        local rightChances = Instance.new("TextLabel")
                        rightChances.Size = UDim2.new(0.48, 0, 0, 32)
                        rightChances.Position = UDim2.new(0.53, 0, 0.45, 0)
                        rightChances.BackgroundTransparency = 1
                        rightChances.Text = "• Ant 0.5%\n• Time 0.025%"
                        rightChances.TextColor3 = C.text2
                        rightChances.TextSize = 10
                        rightChances.Font = Enum.Font.SourceSansBold
                        rightChances.TextXAlignment = Enum.TextXAlignment.Left
                        rightChances.Parent = card

                        -- Countdown Timer (Smooth Client-Side Ticker Loop)
                        local timerLabel = Instance.new("TextLabel")
                        timerLabel.Size = UDim2.new(0.94, 0, 0, 20)
                        timerLabel.Position = UDim2.new(0.03, 0, 0.64, 0)
                        timerLabel.BackgroundTransparency = 1
                        timerLabel.Text = string.format("Next Roll in: %ds", remSec)
                        timerLabel.TextColor3 = C.accent
                        timerLabel.TextSize = 13
                        timerLabel.Font = Enum.Font.SourceSansBold
                        timerLabel.Parent = card

                        -- Local Ticker Thread for smooth 1s updates
                        task.spawn(function()
                            local timeLeft = remSec
                            while timeLeft > 0 and card.Parent ~= nil do
                                task.wait(1)
                                timeLeft = timeLeft - 1
                                if timerLabel.Parent == nil then break end
                                timerLabel.Text = string.format("Next Roll in: %ds", timeLeft)
                            end
                        end)

                        local collectBtn = Instance.new("TextButton")
                        collectBtn.Size = UDim2.new(0.94, 0, 0.16, 0)
                        collectBtn.Position = UDim2.new(0.03, 0, 0.79, 0)
                        collectBtn.BackgroundColor3 = C.green
                        collectBtn.Text = "Collect"
                        collectBtn.TextColor3 = C.text
                        collectBtn.TextSize = 12
                        collectBtn.Font = Enum.Font.SourceSansBold
                        collectBtn.Parent = card

                        local cbCorner = Instance.new("UICorner")
                        cbCorner.CornerRadius = UDim.new(0, 6)
                        cbCorner.Parent = collectBtn

                        collectBtn.MouseButton1Click:Connect(function()
                            collectBtn.Text = "Collecting..."
                            pcall(function() tcFolder.CollectItem:InvokeServer(i) end)
                            task.wait(0.5)
                            refreshTimeCapsuleUI()
                        end)
                    else
                        -- Empty Slot
                        local emptyLbl = Instance.new("TextLabel")
                        emptyLbl.Size = UDim2.new(0.94, 0, 0.4, 0)
                        emptyLbl.Position = UDim2.new(0.03, 0, 0.2, 0)
                        emptyLbl.BackgroundTransparency = 1
                        emptyLbl.Text = "Empty Slot"
                        emptyLbl.TextColor3 = C.text2
                        emptyLbl.TextSize = 12
                        emptyLbl.Font = Enum.Font.SourceSansItalic
                        emptyLbl.Parent = card

                        local buryBtn = Instance.new("TextButton")
                        buryBtn.Size = UDim2.new(0.94, 0, 0.24, 0)
                        buryBtn.Position = UDim2.new(0.03, 0, 0.60, 0)
                        buryBtn.BackgroundColor3 = C.accent
                        buryBtn.Text = "Bury Item"
                        buryBtn.TextColor3 = C.text
                        buryBtn.TextSize = 12
                        buryBtn.Font = Enum.Font.SourceSansBold
                        buryBtn.Parent = card

                        local bbCorner = Instance.new("UICorner")
                        bbCorner.CornerRadius = UDim.new(0, 6)
                        bbCorner.Parent = buryBtn

                        buryBtn.MouseButton1Click:Connect(function()
                            selectedSlotForDrawer = i
                            for _, child in ipairs(drawerScroll:GetChildren()) do
                                if not child:IsA("UIListLayout") then child:Destroy() end
                            end

                            local successItems, itemsList = pcall(function() return tcFolder.GetCapsuleableItems:InvokeServer() end)
                            if successItems and type(itemsList) == "table" then
                                local count = 0
                                for guid, itemEntry in pairs(itemsList) do
                                    count = count + 1
                                    local itemVal, diaCost = calcEntryValueAndCost(itemEntry)
                                    local itemConfig = (ItemsModule and ItemsModule[itemEntry.ItemId]) or (ItemsData and ItemsData[tostring(itemEntry.ItemId)]) or {}
                                    local itemName = itemConfig.Name or "Unknown Item"

                                    local itemCard = Instance.new("Frame")
                                    itemCard.Size = UDim2.new(0.98, 0, 0, 42)
                                    itemCard.BackgroundColor3 = C.card
                                    itemCard.BorderSizePixel = 0
                                    itemCard.Parent = drawerScroll

                                    local icCorner = Instance.new("UICorner")
                                    icCorner.CornerRadius = UDim.new(0, 5)
                                    icCorner.Parent = itemCard

                                    local nameLbl = Instance.new("TextLabel")
                                    nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
                                    nameLbl.Position = UDim2.new(0.02, 0, 0, 0)
                                    nameLbl.BackgroundTransparency = 1
                                    nameLbl.Text = itemName .. " ($" .. tostring(math.floor(itemVal)) .. ") | [Gem] " .. tostring(diaCost)
                                    nameLbl.TextColor3 = C.text
                                    nameLbl.TextSize = 12
                                    nameLbl.Font = Enum.Font.SourceSansBold
                                    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                                    nameLbl.Parent = itemCard

                                    local dispBtn = Instance.new("TextButton")
                                    dispBtn.Size = UDim2.new(0.28, 0, 0.7, 0)
                                    dispBtn.Position = UDim2.new(0.7, 0, 0.15, 0)
                                    dispBtn.BackgroundColor3 = C.accent
                                    dispBtn.Text = "Bury"
                                    dispBtn.TextColor3 = C.text
                                    dispBtn.TextSize = 12
                                    dispBtn.Font = Enum.Font.SourceSansBold
                                    dispBtn.Parent = itemCard

                                    local dispCorner = Instance.new("UICorner")
                                    dispCorner.CornerRadius = UDim.new(0, 4)
                                    dispCorner.Parent = dispBtn

                                    dispBtn.MouseButton1Click:Connect(function()
                                        dispBtn.Text = "Burying..."
                                        pcall(function() tcFolder.PlaceItem:InvokeServer(selectedSlotForDrawer, guid) end)
                                        task.wait(0.5)
                                        drawerFrame.Visible = false
                                        refreshTimeCapsuleUI()
                                    end)
                                end
                                drawerScroll.CanvasSize = UDim2.new(0, 0, 0, count * 48)
                            end
                            drawerFrame.Visible = true
                        end)
                    end
                else
                    -- Locked Slot
                    slotTitle.Text = "Slot " .. tostring(i) .. ": [LOCKED]"
                    slotTitle.TextColor3 = C.red

                    local cost = costs[tostring(i)] or 75
                    local unlockBtn = Instance.new("TextButton")
                    unlockBtn.Size = UDim2.new(0.94, 0, 0.45, 0)
                    unlockBtn.Position = UDim2.new(0.03, 0, 0.35, 0)
                    unlockBtn.BackgroundColor3 = C.red
                    unlockBtn.Text = "Unlock (Cost: " .. tostring(cost) .. " Diamonds)"
                    unlockBtn.TextColor3 = C.text
                    unlockBtn.TextSize = 13
                    unlockBtn.Font = Enum.Font.SourceSansBold
                    unlockBtn.Parent = card

                    local unlockCorner = Instance.new("UICorner")
                    unlockCorner.CornerRadius = UDim.new(0, 6)
                    unlockCorner.Parent = unlockBtn

                    unlockBtn.MouseButton1Click:Connect(function()
                        unlockBtn.Text = "Unlocking..."
                        pcall(function() tcFolder.UnlockSlot:InvokeServer(i) end)
                        task.wait(0.5)
                        refreshTimeCapsuleUI()
                    end)
                end
            end
        end

        -- Run refresh when tab opens
        task.spawn(function()
            while task.wait(5) do
                if tabTimeCapsule and tabTimeCapsule.Visible then
                    refreshTimeCapsuleUI()
                end
            end
        end)

        task.spawn(refreshTimeCapsuleUI)
    end

    -- [Train] CARGO TRAIN & FREIGHT SUBTAB
    do
        list(nil, 6, tabCargoTrain)

        local RS = game:GetService("ReplicatedStorage")
        local ws = game:GetService("Workspace")

        local function getTrainTicketsAmount()
            local hud = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("CurrencyHud")
            if hud then
                local amt = hud:FindFirstChild("TrainTicketAmount", true)
                if amt and amt.Text then
                    return amt.Text
                end
            end
            return "0 Tickets"
        end

        local function getFreightWorldCount()
            local mf = ws:FindFirstChild("_MissingFreight")
            if mf then
                return #mf:GetChildren()
            end
            return 0
        end

        local ctHeader = make("Frame", {
            Size = UDim2.new(1, 0, 0, 68),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabCargoTrain)
        corner(6, ctHeader)
        stroke(1, Color3.fromRGB(80, 180, 240), ctHeader)

        make("TextLabel", {
            Text = "CARGO TRAIN & FREIGHT HUB",
            TextSize = 12,
            TextColor3 = Color3.fromRGB(100, 200, 255),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 6),
            Size = UDim2.new(0.55, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, ctHeader)

        make("TextLabel", {
            Text = "Hourly Train, Conductor Tasks, Missing Freight Parcels",
            TextSize = 8,
            TextColor3 = C.text2,
            Font = Enum.Font.MontserratMedium,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 24),
            Size = UDim2.new(0.55, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, ctHeader)

        local ticketsBadge = make("TextLabel", {
            Text = "Tickets: ...",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 215, 0),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.55, 0, 0, 6),
            Size = UDim2.new(0.45, -10, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, ctHeader)

        local freightBadge = make("TextLabel", {
            Text = "World Freight: ...",
            TextSize = 9,
            TextColor3 = C.text,
            Font = Enum.Font.MontserratMedium,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.55, 0, 0, 24),
            Size = UDim2.new(0.45, -10, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, ctHeader)

        local function refreshTrainHeader()
            pcall(function()
                if ticketsBadge and ticketsBadge.Parent then
                    ticketsBadge.Text = "Tickets: " .. getTrainTicketsAmount()
                end
                if freightBadge and freightBadge.Parent then
                    freightBadge.Text = "World Freight: " .. tostring(getFreightWorldCount()) .. " Parcels"
                end
            end)
        end

        task.spawn(function()
            while ctHeader and ctHeader.Parent do
                refreshTrainHeader()
                task.wait(2)
            end
        end)

        -- 1. CARGO TRAIN TRACKER & EVENT CARD
        local trainCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabCargoTrain)
        corner(6, trainCard); pad(8, trainCard); list(nil, 6, trainCard)

        make("TextLabel", {
            Text = "CARGO TRAIN TRACKER",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(100, 200, 255),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, trainCard)

        local trainStatusLbl = make("TextLabel", {
            Text = "Train Status: Checking...",
            TextSize = 9,
            TextColor3 = C.text2,
            Font = Enum.Font.MontserratMedium,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, trainCard)

        task.spawn(function()
            while trainStatusLbl and trainStatusLbl.Parent do
                pcall(function()
                    local Lighting = game:GetService("Lighting")
                    local phase = Lighting:GetAttribute("CargoTrainPhase") or "Away"
                    local nextAt = Lighting:GetAttribute("CargoTrainNextAt")
                    local stationIdx = Lighting:GetAttribute("CargoTrainStation") or 1
                    local now = workspace:GetServerTimeNow()
                    local stationNames = {[1] = "Ship Yard", [2] = "Before Bridge", [3] = "After Bridge"}
                    local stName = stationNames[stationIdx] or "Station"

                    if phase == "Stopped" then
                        local left = nextAt and math.max(0, math.floor(nextAt - now)) or 0
                        trainStatusLbl.Text = "Train Status: Stopped @ " .. stName .. string.format(" (Leaves in %d:%02d)", math.floor(left / 60), left % 60)
                        trainStatusLbl.TextColor3 = C.green
                    elseif phase == "Moving" then
                        local left = nextAt and math.max(0, math.floor(nextAt - now)) or 0
                        trainStatusLbl.Text = string.format("Train Status: Moving to %s (Arrives in %d:%02d)", stName, math.floor(left / 60), left % 60)
                        trainStatusLbl.TextColor3 = Color3.fromRGB(255, 200, 60)
                    else
                        trainStatusLbl.Text = "Train Status: Away (Waiting for hourly arrival)"
                        trainStatusLbl.TextColor3 = C.text2
                    end
                end)
                task.wait(2)
            end
        end)

        local function getActiveTrainCFrame()
            local ctl = workspace:FindFirstChild("CargoTrainLocal")
            if ctl then
                local flatcar = ctl:FindFirstChild("Flatcar")
                if flatcar then
                    local p = flatcar:GetPivot().Position
                    return CFrame.new(p + Vector3.new(0, 10.5, 0))
                end
                local loco = ctl:FindFirstChild("Locomotive")
                if loco then
                    local p = loco:GetPivot().Position
                    return CFrame.new(p + Vector3.new(0, 11.0, 0))
                end
                for _, ch in ipairs(ctl:GetChildren()) do
                    if ch:IsA("Model") or ch:IsA("BasePart") then
                        local p = ch:GetPivot().Position
                        return CFrame.new(p + Vector3.new(0, 10.5, 0))
                    end
                end
            end
            local se = RS.Events:FindFirstChild("SpecialEvent")
            local getNav = se and se:FindFirstChild("GetCargoTrainNavTarget")
            if getNav then
                local target = getNav:InvokeServer()
                if type(target) == "string" then
                    local parts = string.split(target, ",")
                    if #parts >= 3 then
                        local x = tonumber(parts[1]:match("%-?%d+%.?%d*"))
                        local y = tonumber(parts[2]:match("%-?%d+%.?%d*"))
                        local z = tonumber(parts[3]:match("%-?%d+%.?%d*"))
                        if x and y and z then
                            return CFrame.new(x, y + 4, z)
                        end
                    end
                end
            end
            return nil
        end

        createButton(trainCard, "Teleport to Cargo Train (Direct onto Train)", function()
            local trainCF = getActiveTrainCFrame()
            if trainCF then
                safeTP(trainCF)
                abLog("[Train] Teleported directly onto the Cargo Train!", C.green)
                showWorkshopPopup("Teleported onto Cargo Train!", C.green)
                return
            end
            local Lighting = game:GetService("Lighting")
            local stationIdx = Lighting:GetAttribute("CargoTrainStation") or 1
            local targetPos = (stationIdx == 2 and Vector3.new(767.0, 1731.0, -1447.0))
                           or (stationIdx == 3 and Vector3.new(666.0, 1731.0, -2604.0))
                           or Vector3.new(-422.0, 1731.0, 952.0)
            safeTP(CFrame.new(targetPos))
            abLog("[Train] Train is currently Away/Despawned. Teleported to Station platform to wait.", C.orange)
            showWorkshopPopup("Train is Away (Waiting at Station)", C.orange)
        end)

        createButton(trainCard, "Station: Ship Yard", function()
            safeTP(CFrame.new(-422.0, 1731.0, 952.0))
        end)

        createButton(trainCard, "Station: Before Bridge", function()
            safeTP(CFrame.new(767.0, 1731.0, -1447.0))
        end)

        createButton(trainCard, "Station: After Bridge", function()
            safeTP(CFrame.new(666.0, 1731.0, -2604.0))
        end)

        -- 2. TRAIN CONDUCTOR NPC CARD
        local conductorCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabCargoTrain)
        corner(6, conductorCard); pad(8, conductorCard); list(nil, 6, conductorCard)

        make("TextLabel", {
            Text = "TRAIN CONDUCTOR (DAILY TICKETS & TASKS)",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 215, 0),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, conductorCard)

        local function getNearestConductor()
            local cts = ws:FindFirstChild("CargoTrainStop")
            local nearest, nearDist = nil, math.huge
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = root and root.Position or Vector3.new(-419.4, 1728, 947.8)
            if cts then
                for _, c in ipairs(cts:GetChildren()) do
                    if c.Name == "Conductor" then
                        local d = (c:GetPivot().Position - myPos).Magnitude
                        if d < nearDist then
                            nearDist = d
                            nearest = c
                        end
                    end
                end
            end
            return nearest
        end

        local function claimDailyTicketsNow(notify)
            local cond = getNearestConductor()
            if not cond then
                if notify then abLog("No Conductor found in workspace.", C.red) end
                return false
            end
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return false end
            local oldCF = root.CFrame
            safeTP(CFrame.new(cond:GetPivot().Position + Vector3.new(0, 3.5, 3.7)))
            task.wait(0.35)
            local ok, res = pcall(function()
                return RS.Events.TrainConductor.ClaimDaily:InvokeServer(cond)
            end)
            safeTP(oldCF)
            if ok and type(res) == "table" then
                if res.Ok then
                    abLog("[Train] Claimed 5 Free Daily Train Tickets!", C.green)
                    showWorkshopPopup("+5 Train Tickets Claimed!", C.green)
                    refreshTrainHeader()
                    return true
                elseif res.Line then
                    if notify then abLog("Conductor: " .. res.Line, C.orange) end
                end
            elseif notify then
                abLog("Failed to claim daily tickets: " .. tostring(res), C.red)
            end
            return false
        end
        _G.claimDailyTicketsNow = claimDailyTicketsNow

        local ticketToggle, updateTicketToggle = createToggle(conductorCard, "Auto Claim Daily Tickets (5/Day)", gConfig.autoClaimDailyTickets, function(state)
            gConfig.autoClaimDailyTickets = state
            saveConfig()
            if state then
                abLog("[Train] Auto-Claim Daily Tickets: ENABLED", C.green)
                task.spawn(function() claimDailyTicketsNow(true) end)
            else
                abLog("Auto-Claim Daily Tickets: DISABLED", C.textMuted)
            end
        end)
        _G.uiToggles["autoClaimDailyTickets"] = updateTicketToggle

        createButton(conductorCard, "Claim Daily Tickets Now (5 Free Tickets)", function()
            claimDailyTicketsNow(true)
        end)

        createButton(conductorCard, "Teleport to Train Conductor", function()
            safeTP(CFrame.new(-419.4, 1731.5, 951.5))
        end)

        -- 3. MISSING FREIGHT PARCELS CARD
        local freightCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabCargoTrain)
        corner(6, freightCard); pad(8, freightCard); list(nil, 6, freightCard)

        make("TextLabel", {
            Text = "MISSING FREIGHT PACKAGES",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(120, 220, 160),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, freightCard)

        local freightStatusLbl = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = Color3.fromRGB(30, 30, 36),
            BackgroundTransparency = 0.2,
            Text = "World Freight: 0 Spawned (Wait for Train / Map event)",
            TextColor3 = Color3.fromRGB(240, 180, 80),
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, freightCard)
        corner(4, freightStatusLbl)

        task.spawn(function()
            while task.wait(2) do
                if not freightCard or not freightCard.Parent then break end
                local count = 0
                local mf = ws:FindFirstChild("_MissingFreight")
                if mf then count = #mf:GetChildren() end
                if count > 0 then
                    freightStatusLbl.Text = "World Freight: " .. count .. " Package" .. (count > 1 and "s" or "") .. " Spawned! (Ready to collect)"
                    freightStatusLbl.TextColor3 = C.green
                else
                    freightStatusLbl.Text = "World Freight: 0 Spawned (Wait for Train / Map event)"
                    freightStatusLbl.TextColor3 = Color3.fromRGB(240, 180, 80)
                end
            end
        end)

        local freightBusy = false
        local function collectAllMissingFreight(manual)
            if freightBusy then
                if manual then abLog("Freight collection already in progress.", C.textMuted) end
                return
            end
            local mfFolder = ws:FindFirstChild("_MissingFreight")
            if not mfFolder or #mfFolder:GetChildren() == 0 then
                if manual then
                    freightStatusLbl.Text = "0 Packages active right now! Spawns with Train event."
                    freightStatusLbl.TextColor3 = Color3.fromRGB(255, 90, 90)
                    task.delay(3, function()
                        if freightStatusLbl and freightStatusLbl.Parent then
                            freightStatusLbl.Text = "World Freight: 0 Spawned (Wait for Train / Map event)"
                            freightStatusLbl.TextColor3 = Color3.fromRGB(240, 180, 80)
                        end
                    end)
                    abLog("[Freight] No Missing Freight packages in the world right now.", C.orange)
                    showWorkshopPopup("No Missing Freight packages spawned right now! (0 in server)", C.orange)
                end
                return
            end
            freightBusy = true
            _G.isFreightCollecting = true
            _G._lastFreightAttempt = os.clock()
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local oldCF = root and root.CFrame
            local collectedCount = 0

            pcall(function()
                for _, parcel in ipairs(mfFolder:GetChildren()) do
                    if not _G.isFreightCollecting then break end
                    local pPos = parcel:GetPivot().Position
                    safeTP(CFrame.new(pPos + Vector3.new(0, 2, 2)))
                    task.wait(0.35)
                    local itemId = parcel:GetAttribute("ItemId") or (parcel:FindFirstChildWhichIsA("ProximityPrompt", true) and parcel:FindFirstChildWhichIsA("ProximityPrompt", true):GetAttribute("ItemId"))
                    local claimRemote = RS.Events.MissingFreight:FindFirstChild("ClaimWorldParcel")
                    if claimRemote and itemId then
                        local ok, res = pcall(function()
                            return claimRemote:InvokeServer(tostring(itemId))
                        end)
                        if ok and res and res.Ok then
                            collectedCount = collectedCount + 1
                        end
                    end
                    for _, d in ipairs(parcel:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then
                            pcall(function() fireproximityprompt(d, 0) end)
                        end
                    end
                    task.wait(0.2)
                end
            end)

            if oldCF then safeTP(oldCF) end
            freightBusy = false
            _G.isFreightCollecting = false

            if collectedCount > 0 then
                abLog("[Freight] Collected " .. collectedCount .. " Missing Freight packages!", C.green)
                showWorkshopPopup("Collected " .. collectedCount .. " Packages!", C.green)
                refreshTrainHeader()
            elseif manual then
                abLog("Checked all freight packages in workspace.", C.textMuted)
                showWorkshopPopup("Checked workspace: 0 packages claimed.", C.textMuted)
            end
        end
        _G.collectAllMissingFreight = collectAllMissingFreight

        local freightToggle, updateFreightToggle = createToggle(freightCard, "Auto-Collect Missing Freight Parcels", gConfig.autoCollectMissingFreight, function(state)
            gConfig.autoCollectMissingFreight = state
            saveConfig()
            if state then
                abLog("[Freight] Auto-Collect Freight: ENABLED", C.green)
                task.spawn(function() collectAllMissingFreight(true) end)
            else
                abLog("Auto-Collect Freight: DISABLED", C.textMuted)
                _G.isFreightCollecting = false
            end
        end)
        _G.uiToggles["autoCollectMissingFreight"] = updateFreightToggle

        createButton(freightCard, "Collect All Missing Freight Parcels Now", function()
            task.spawn(function() collectAllMissingFreight(true) end)
        end)

        createButton(freightCard, "Teleport to Nearest Missing Freight Parcel", function()
            local mfFolder = ws:FindFirstChild("_MissingFreight")
            if not mfFolder or #mfFolder:GetChildren() == 0 then
                freightStatusLbl.Text = "0 Packages active right now! Spawns with Train event."
                freightStatusLbl.TextColor3 = Color3.fromRGB(255, 90, 90)
                task.delay(3, function()
                    if freightStatusLbl and freightStatusLbl.Parent then
                        freightStatusLbl.Text = "World Freight: 0 Spawned (Wait for Train / Map event)"
                        freightStatusLbl.TextColor3 = Color3.fromRGB(240, 180, 80)
                    end
                end)
                abLog("No Missing Freight packages currently active.", C.orange)
                showWorkshopPopup("No Missing Freight packages spawned right now!", C.orange)
                return
            end
            local nearest, nearDist = nil, math.huge
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local myPos = root and root.Position or Vector3.zero
            for _, p in ipairs(mfFolder:GetChildren()) do
                local d = (p:GetPivot().Position - myPos).Magnitude
                if d < nearDist then
                    nearDist = d
                    nearest = p
                end
            end
            if nearest then
                safeTP(CFrame.new(nearest:GetPivot().Position + Vector3.new(0, 2, 2)))
                abLog("[Freight] Teleported to " .. nearest.Name .. "!", C.green)
                showWorkshopPopup("Teleported to " .. nearest.Name .. "!", C.green)
            end
        end)
    end

    -- [Mine] THE MINES SUBTAB
    do
        list(nil, 6, tabMines)

        local RS = game:GetService("ReplicatedStorage")
        local ws = game:GetService("Workspace")

        local JEWEL_IDS = {"1231", "1230", "1229", "1228", "1227", "1226", "1225", "1224", "1223", "1222"}
        local JEWEL_NAME = {
            ["1222"] = "Titanium",
            ["1223"] = "Morganite",
            ["1224"] = "Citrine",
            ["1225"] = "Lapis",
            ["1226"] = "Carnelian",
            ["1227"] = "Aquamarine",
            ["1228"] = "Amethyst",
            ["1229"] = "Emerald",
            ["1230"] = "Sapphire",
            ["1231"] = "Ruby",
        }
        local BREW_COST = {
            ["1222"] = 15,
            ["1223"] = 14,
            ["1224"] = 13,
            ["1225"] = 12,
            ["1226"] = 11,
            ["1227"] = 10,
            ["1228"] = 9,
            ["1229"] = 8,
            ["1230"] = 7,
            ["1231"] = 5,
        }
        local NODE_POS = {
            Vector3.new(-3258.28, 1576.81, -2237.51), -- 1
            Vector3.new(-3280.18, 1577.74, -2246.94), -- 2
            Vector3.new(-3272.45, 1579.20, -2270.32), -- 3
            Vector3.new(-3283.91, 1579.84, -2290.50), -- 4
            Vector3.new(-3292.37, 1580.63, -2313.23), -- 5
            Vector3.new(-3272.88, 1582.55, -2332.96), -- 6
            Vector3.new(-3153.54, 1584.25, -2241.60), -- 7
            Vector3.new(-3150.46, 1586.59, -2274.01), -- 8
            Vector3.new(-3140.11, 1589.06, -2312.38), -- 9
            Vector3.new(-3168.37, 1591.35, -2344.33)  -- 10
        }
        local NODE_STAND = {
            CFrame.lookAt(Vector3.new(-3258.28, 1578.24, -2234.01), Vector3.new(-3258.28, 1576.81, -2237.51)),
            CFrame.lookAt(Vector3.new(-3280.18, 1579.90, -2243.44), Vector3.new(-3280.18, 1577.74, -2246.94)),
            CFrame.lookAt(Vector3.new(-3272.45, 1579.18, -2266.82), Vector3.new(-3272.45, 1579.20, -2270.32)),
            CFrame.lookAt(Vector3.new(-3283.91, 1586.36, -2287.00), Vector3.new(-3283.91, 1579.84, -2290.50)),
            CFrame.lookAt(Vector3.new(-3292.37, 1585.30, -2309.73), Vector3.new(-3292.37, 1580.63, -2313.23)),
            CFrame.lookAt(Vector3.new(-3272.88, 1588.43, -2329.46), Vector3.new(-3272.88, 1582.55, -2332.96)),
            CFrame.lookAt(Vector3.new(-3153.54, 1588.59, -2238.10), Vector3.new(-3153.54, 1584.25, -2241.60)),
            CFrame.lookAt(Vector3.new(-3150.46, 1591.16, -2270.51), Vector3.new(-3150.46, 1586.59, -2274.01)),
            CFrame.lookAt(Vector3.new(-3140.11, 1590.56, -2308.88), Vector3.new(-3140.11, 1589.06, -2312.38)),
            CFrame.lookAt(Vector3.new(-3168.37, 1592.85, -2340.83), Vector3.new(-3168.37, 1591.35, -2344.33))
        }
        local MINES_HUB = Vector3.new(-3180.33, 1578.50, -1912.78)

        local function mInv()
            local ok, inv = pcall(function()
                return RS.Events.Inventory.GetPlayerInventory:InvokeServer()
            end)
            return (ok and type(inv) == "table") and inv or nil
        end

        local function countItem(id)
            local inv = mInv()
            local n = 0
            if inv then
                for _, d in pairs(inv) do
                    if tostring(d.ItemId or "") == id then
                        n = n + (tonumber(d.Amount) or tonumber(d.Count) or 1)
                    end
                end
            end
            return n
        end

        local function totalJewels()
            local n = 0
            for id in pairs(BREW_COST) do
                n = n + countItem(id)
            end
            return n
        end

        local function equipItem(id)
            local inv = mInv()
            if not inv then return false end
            local eq = RS.Events.Inventory:FindFirstChild("EquipItem")
            if not eq then return false end
            for guid, d in pairs(inv) do
                if tostring(d.ItemId or "") == id then
                    eq:FireServer(guid)
                    task.wait(0.4)
                    return true
                end
            end
            return false
        end

        local function heldTool()
            local ch = LocalPlayer.Character
            if ch then
                for _, t in ipairs(ch:GetChildren()) do
                    if t:IsA("Tool") and (t.Name:lower():find("pickaxe") or t.Name:lower():find("crusher") or t.Name:lower():find("drill")) then
                        return t
                    end
                end
            end
            return nil
        end

        local PICKAXES = {"1221", "1220", "1219", "1218", "1217", "1216"}
        local PICKAXE_NAMES = {
            ["1221"] = "Node Crusher",
            ["1220"] = "Drill Spike",
            ["1219"] = "Diamond Pickaxe",
            ["1218"] = "Industrial Pickaxe",
            ["1217"] = "Iron Pickaxe",
            ["1216"] = "Wooden Pickaxe"
        }

        local function equipBestPickaxe()
            local lp = LocalPlayer or game.Players.LocalPlayer
            local ch = lp.Character
            local bp = lp:FindFirstChild("Backpack")
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")

            local inv = mInv()
            local bestGuid, bestId = nil, nil
            if inv then
                for _, targetId in ipairs(PICKAXES) do
                    for guid, d in pairs(inv) do
                        if tostring(d.ItemId or "") == targetId then
                            bestGuid = guid
                            bestId = targetId
                            break
                        end
                    end
                    if bestGuid then break end
                end
            end

            local held = heldTool()
            if held then
                if not bestId or held.Name:lower():find(tostring(PICKAXE_NAMES[bestId] or ""):lower()) then
                    return held.Name
                end
            end

            if bp then
                for _, targetId in ipairs(PICKAXES) do
                    local pName = PICKAXE_NAMES[targetId]
                    for _, t in ipairs(bp:GetChildren()) do
                        if t:IsA("Tool") and (t.Name == pName or t.Name:lower():find("pickaxe") or t.Name:lower():find("crusher") or t.Name:lower():find("drill")) then
                            if hum then
                                hum:EquipTool(t)
                                task.wait(0.3)
                                return t.Name
                            end
                        end
                    end
                end
            end

            if bestGuid then
                local eq = RS.Events.Inventory:FindFirstChild("EquipItem")
                if eq then
                    eq:FireServer(bestGuid)
                    task.wait(0.4)
                    if bp and hum then
                        for _, t in ipairs(bp:GetChildren()) do
                            if t:IsA("Tool") and (t.Name:lower():find("pickaxe") or t.Name:lower():find("crusher") or t.Name:lower():find("drill")) then
                                hum:EquipTool(t)
                                task.wait(0.2)
                                break
                            end
                        end
                    end
                    return PICKAXE_NAMES[bestId] or bestId
                end
            end

            return held and held.Name or nil
        end

        local function cauldronState()
            local ok, st = pcall(function()
                return RS.Events.MiningCauldron.GetState:InvokeServer()
            end)
            return (ok and type(st) == "table") and st or nil
        end

        local function brewJewel(jid)
            local ok, res = pcall(function()
                return RS.Events.MiningCauldron.Brew:InvokeServer(jid)
            end)
            return ok, res
        end

        local function bestJewel()
            for _, id in ipairs(JEWEL_IDS) do
                if countItem(id) >= (BREW_COST[id] or 1) then
                    return id
                end
            end
            return nil
        end

        local function buyDrink(kind)
            local buy = RS.Events:FindFirstChild("EnergyShop") and RS.Events.EnergyShop:FindFirstChild("BuyDrink")
            if not buy then
                abLog("EnergyShop.BuyDrink remote missing", C.red)
                return
            end
            local drinkId = (kind == "speed") and "18" or "19"
            local drinkName = (kind == "speed") and "Mining Speed Drink" or "Mining Luck Drink"
            local cost = (kind == "speed") and 20 or 30
            local ok, res = pcall(function()
                return buy:InvokeServer(drinkId)
            end)
            if ok and res and res.success then
                abLog("[Lab] Bought " .. drinkName .. " ([Gem] " .. (res.cost or cost) .. ")", C.green)
                showWorkshopPopup("Purchased " .. drinkName .. " ([Gem] " .. (res.cost or cost) .. ")!", C.green)
            else
                local errMsg = (res and res.error) or (not ok and tostring(res)) or "Out of stock / Not enough diamonds"
                abLog("Drink buy failed: " .. tostring(errMsg), C.red)
                showWorkshopPopup("Failed: " .. tostring(errMsg), C.red)
            end
        end

        local function useDrink(kind)
            local targetItemId = (kind == "speed") and 1233 or 1234
            local drinkName = (kind == "speed") and "Mining Speed Drink" or "Mining Luck Drink"
            local inv = _G.AHUserInventoryCache
            local targetGuid = nil
            if inv and type(inv) == "table" then
                for guid, item in pairs(inv) do
                    if type(item) == "table" and tonumber(item.ItemId) == targetItemId then
                        targetGuid = guid
                        break
                    end
                end
            end
            if targetGuid then
                local useRemote = RS.Events:FindFirstChild("UI") and RS.Events.UI:FindFirstChild("UseEnergyDrink")
                if useRemote then
                    useRemote:FireServer(targetGuid)
                    abLog("[Lab] Consumed " .. drinkName .. "!", C.green)
                    showWorkshopPopup("Consumed " .. drinkName .. "!", C.green)
                end
            else
                showWorkshopPopup("You don't own any " .. drinkName .. "!", C.red)
            end
        end

        local NODE_REQ = {
            [1] = { name = "Node 1", nw = 30000, label = "$30K" },
            [2] = { name = "Node 2", nw = 60000, label = "$60K" },
            [3] = { name = "Node 3", nw = 200000, label = "$200K" },
            [4] = { name = "Node 4", nw = 600000, label = "$600K" },
            [5] = { name = "Node 5", nw = 2000000, label = "$2M" },
            [6] = { name = "Node 6", nw = 6000000, label = "$6M" },
            [7] = { name = "Node 7", nw = 17500000, label = "$17.5M" },
            [8] = { name = "Node 8", nw = 50000000, label = "$50M" },
            [9] = { name = "Node 9", nw = 150000000, label = "$150M" },
            [10] = { name = "Node 10", nw = 500000000, label = "$500M" },
        }

        local function getPlayerNW()
            local nwVal = 0
            pcall(function()
                local raw = LocalPlayer.leaderstats["Net Worth"].Value
                raw = tostring(raw or ""):gsub("%$", ""):gsub(",", ""):upper()
                local num = tonumber(raw:match("[%d%.]+")) or 0
                if raw:find("B") then
                    nwVal = num * 1000000000
                elseif raw:find("M") then
                    nwVal = num * 1000000
                elseif raw:find("K") then
                    nwVal = num * 1000
                else
                    nwVal = num
                end
            end)
            return nwVal
        end

        local function getBestEligibleNode()
            local nw = getPlayerNW()
            local best = 1
            for i = 1, 10 do
                if nw >= NODE_REQ[i].nw then
                    best = i
                end
            end
            return best
        end

        local function resolveTargetNode()
            local target = gConfig.miningTargetNode or "Auto"
            if target == "Auto" or target:find("Auto") then
                return getBestEligibleNode()
            end
            local num = tonumber(target:match("%d+"))
            return num or 1
        end

        local function getRockNodePrompt(nodeIdx)
            local mines = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("The Mines")
            local rn = mines and mines:FindFirstChild("RockNodes")
            if not rn then return nil end
            local nodeModel = rn:FindFirstChild(tostring(nodeIdx))
            if not nodeModel then return nil end
            return nodeModel:FindFirstChildWhichIsA("ProximityPrompt", true)
        end

        local miningStatusLbl = nil
        local function updateMiningStatus(text, color)
            if miningStatusLbl and miningStatusLbl.Parent then
                miningStatusLbl.Text = text
                miningStatusLbl.TextColor3 = color or C.textMuted
            end
        end

        local function stopMining()
            _G.isMiningActive = false
            pcall(function()
                local mines = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("The Mines")
                local rn = mines and mines:FindFirstChild("RockNodes")
                if rn then
                    for _, m in ipairs(rn:GetChildren()) do
                        local p = m:FindFirstChildWhichIsA("ProximityPrompt", true)
                        if p and p.ActionText == "Stop Mining" then
                            fireproximityprompt(p, 0)
                            task.wait(0.2)
                            break
                        end
                    end
                end
            end)
            updateMiningStatus("Mining Status: Idle", C.textMuted)
        end
        _G.stopMining = stopMining

        local function startMiningSession(isContinuous)
            if _G.isMiningActive then
                abLog("[Mine] Mining session already active.", C.textMuted)
                return
            end
            _G.isMiningActive = true
            _G._lastMiningAttempt = os.clock()

            local ch = LocalPlayer.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            if hum and hum.Sit then
                hum.Sit = false
                task.wait(0.25)
            end

            local pickaxe = equipBestPickaxe()
            if not pickaxe then
                abLog("[Mine] No pickaxe found in character, backpack, or inventory!", C.orange)
                showWorkshopPopup("No pickaxe owned! Buy one from Miner stall.", C.orange)
                _G.isMiningActive = false
                updateMiningStatus("[Mine] Mining Status: No Pickaxe Owned", C.orange)
                return
            end
            abLog("[Mine] Holding " .. tostring(pickaxe), C.accent)

            local nodeIdx = resolveTargetNode()
            local req = NODE_REQ[nodeIdx]
            local playerNW = getPlayerNW()
            if req and playerNW < req.nw then
                local bestEligible = getBestEligibleNode()
                abLog("[Warning] Need " .. req.label .. " NW for Node " .. nodeIdx .. "! Auto-switching to Node " .. bestEligible, C.orange)
                nodeIdx = bestEligible
            end

            local targetPos = NODE_POS[nodeIdx]
            if not targetPos then
                abLog("[X] Invalid rock node target: " .. tostring(nodeIdx), C.red)
                _G.isMiningActive = false
                return
            end

            updateMiningStatus("[Mine] Traveling to Node " .. nodeIdx .. "...", C.accent)
            abLog("[Mine] Traveling to Rock Node " .. nodeIdx .. "...", C.accent)

            local standCF = (NODE_STAND and NODE_STAND[nodeIdx]) or CFrame.lookAt(targetPos + Vector3.new(0, 1.5, 3.5), targetPos)
            safeTP(standCF)

            local prompt = nil
            local startWait = os.clock()
            while os.clock() - startWait < 4 and _G.isMiningActive do
                prompt = getRockNodePrompt(nodeIdx)
                if prompt then break end
                task.wait(0.25)
            end

            if not prompt or not _G.isMiningActive then
                if not prompt then
                    abLog("[X] Rock Node " .. nodeIdx .. " prompt failed to stream in.", C.orange)
                end
                _G.isMiningActive = false
                updateMiningStatus("[Mine] Mining Status: Timeout", C.red)
                return
            end

            safeTP(standCF)
            task.wait(0.3)

            if prompt.ActionText == "Mine" then
                fireproximityprompt(prompt, 0)
                task.wait(0.6)
            end

            abLog("[Mine] Began mining Rock Node " .. nodeIdx .. "!", C.green)
            updateMiningStatus("[Mine] Mining Node " .. nodeIdx .. " (0%)", C.gold)

            local lastPct = 0
            local lastRewardTime = 0
            while _G.isMiningActive do
                _G._lastMiningAttempt = os.clock()

                local liveCh = LocalPlayer.Character
                local liveHum = liveCh and liveCh:FindFirstChildOfClass("Humanoid")
                local liveHrp = liveCh and liveCh:FindFirstChild("HumanoidRootPart")
                if not liveHum or liveHum.Health <= 0 or not liveHrp then
                    break
                end

                if (liveHrp.Position - standCF.Position).Magnitude > 7 then
                    safeTP(standCF)
                    task.wait(0.2)
                end

                prompt = getRockNodePrompt(nodeIdx)
                local action = prompt and prompt.ActionText

                local hud = LocalPlayer.PlayerGui:FindFirstChild("MiningHud")
                local panel = hud and hud:FindFirstChild("MiningPanel")
                local fill = panel and panel:FindFirstChild("Bar") and panel.Bar:FindFirstChild("Fill")
                local hint = panel and panel:FindFirstChild("Hint") and panel.Hint.Text or ""
                local progress = fill and fill.Size.X.Scale or 0
                local pct = math.floor(math.clamp(progress, 0, 1) * 100)

                if hint:lower():find("full") or hint:lower():find("free slot") then
                    abLog("Inventory full! Mining paused.", C.orange)
                    showWorkshopPopup("Inventory full! Clear space to mine.", C.orange)
                    updateMiningStatus("Inventory Full - Paused", C.orange)
                    stopMining()
                    break
                end

                updateMiningStatus(string.format("[Mine] Node %d: %d%% (%s)", nodeIdx, pct, isContinuous and "Continuous" or "1-Drop"), C.gold)

                if lastPct >= 80 and pct < 20 and (os.clock() - lastRewardTime > 2) then
                    lastRewardTime = os.clock()
                    abLog("[Gem] Completed a mining cycle on Node " .. nodeIdx .. "!", C.green)
                    showWorkshopPopup("Mined a Jewel!", C.green)
                    if not isContinuous then
                        stopMining()
                        break
                    end
                end
                lastPct = pct

                if action == "Mine" and (os.clock() - lastRewardTime > 3) and pct == 0 then
                    if isContinuous and gConfig.autoMineNodes then
                        fireproximityprompt(prompt, 0)
                        task.wait(0.5)
                    else
                        break
                    end
                end

                if (AB.startingAuction or AB.activeLot) and gConfig.seatedAutofarm and not gConfig.continuousMiningDuringAuctions then
                    abLog("Priority Auction starting! Pausing mining to bid.", C.accent)
                    stopMining()
                    break
                end

                task.wait(0.5)
            end

            stopMining()
            if not isContinuous then
                abLog("[Mine] Mining cycle complete.", C.green)
            end
        end
        _G.startMiningSession = startMiningSession
        _G.mineAllNodes = function(manual) startMiningSession(not manual) end

        -- Listen for server mining state reward events
        pcall(function()
            local msEvent = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Misc") and RS.Events.Misc:FindFirstChild("MiningState")
            if msEvent and not _G._miningStateConnected then
                _G._miningStateConnected = true
                msEvent.OnClientEvent:Connect(function(data)
                    if type(data) == "table" and type(data.Reward) == "table" then
                        local rName = data.Reward.Name or "Jewel"
                        local rRarity = data.Reward.Rarity or "Valuable"
                        abLog(string.format("[Gem] Mined [%s] (%s)!", tostring(rName), tostring(rRarity)), C.green)
                        showWorkshopPopup(string.format("Mined [%s]!", tostring(rName)), C.green)
                    end
                end)
            end
        end)

        local brewBusy = false
        local function autoBrewOnce()
            if brewBusy then return end
            brewBusy = true
            pcall(function()
                local jid = bestJewel()
                if not jid then return end
                local st = cauldronState()
                if st and ((st.Active == true) or (st.CanBrew == false) or (st.Cooldown and st.Cooldown > 0)) then
                    return
                end
                local ok, res = brewJewel(jid)
                if ok then
                    abLog("[Lab] Cauldron: Brewed " .. (JEWEL_NAME[jid] or jid) .. " - mutator event rolling!", C.green)
                    showWorkshopPopup("Cauldron brewed: " .. (JEWEL_NAME[jid] or jid) .. "!", C.green)
                end
            end)
            brewBusy = false
        end
        _G.autoBrewOnce = autoBrewOnce

        local mHeader = make("Frame", {
            Size = UDim2.new(1, 0, 0, 68),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabMines)
        corner(6, mHeader)
        stroke(1, Color3.fromRGB(120, 140, 170), mHeader)

        make("TextLabel", {
            Text = "THE MINES EVENT HUB",
            TextSize = 12,
            TextColor3 = Color3.fromRGB(140, 180, 255),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 6),
            Size = UDim2.new(0.6, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, mHeader)

        make("TextLabel", {
            Text = "Rock Nodes, Cauldron Brews, Drinks & Supervisor",
            TextSize = 8,
            TextColor3 = C.text2,
            Font = Enum.Font.MontserratMedium,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 24),
            Size = UDim2.new(0.6, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, mHeader)

        local jewelLbl = make("TextLabel", {
            Text = "Jewels: ...",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(140, 220, 255),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.6, 0, 0, 6),
            Size = UDim2.new(0.4, -10, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, mHeader)

        local cauldronLbl = make("TextLabel", {
            Text = "Cauldron: ...",
            TextSize = 9,
            TextColor3 = C.text,
            Font = Enum.Font.MontserratMedium,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.6, 0, 0, 24),
            Size = UDim2.new(0.4, -10, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
        }, mHeader)

        local function refreshMinesHeader()
            pcall(function()
                if jewelLbl and jewelLbl.Parent then
                    jewelLbl.Text = "Jewels: " .. tostring(totalJewels())
                end
                local st = cauldronState()
                if cauldronLbl and cauldronLbl.Parent then
                    local s = "Idle"
                    if st then
                        if st.Active == true then
                            s = "Event Active"
                        elseif st.CanBrew == false or (st.Cooldown and st.Cooldown > 0) then
                            s = "Cooling down"
                        else
                            s = "Ready"
                        end
                    end
                    cauldronLbl.Text = "Cauldron: " .. s
                end
            end)
        end

        task.spawn(function()
            while mHeader and mHeader.Parent do
                refreshMinesHeader()
                task.wait(2)
            end
        end)

        -- 1. ROCK NODE MINING CARD
        local mineCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabMines)
        corner(6, mineCard); pad(8, mineCard); list(nil, 6, mineCard)

        make("TextLabel", {
            Text = "ROCK NODE MINING",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(140, 180, 255),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, mineCard)

        -- Live Status Box
        local statusBox = make("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundColor3 = Color3.fromRGB(20, 24, 34),
            BorderSizePixel = 0,
        }, mineCard)
        corner(4, statusBox); stroke(1, Color3.fromRGB(45, 55, 75), statusBox)

        miningStatusLbl = make("TextLabel", {
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = "Mining Status: Idle",
            TextColor3 = C.textMuted,
            Font = Enum.Font.MontserratMedium,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, statusBox)

        -- Target Node Dropdown
        local nodeDropdownBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Color3.fromRGB(26, 32, 46),
            Text = "Target Rock Node: " .. tostring(gConfig.miningTargetNode or "Auto") .. " v",
            TextColor3 = C.gold,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, mineCard)
        corner(4, nodeDropdownBtn); stroke(1, C.border, nodeDropdownBtn)

        local nodeContainer = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
        }, mineCard)
        list(nil, 4, nodeContainer)

        local nodeDdOpen = false
        local function updateNodeDropdownText()
            local cur = gConfig.miningTargetNode or "Auto"
            nodeDropdownBtn.Text = "Target Rock Node: " .. cur .. (nodeDdOpen and " ^" or " v")
        end

        nodeDropdownBtn.MouseButton1Click:Connect(function()
            nodeDdOpen = not nodeDdOpen
            nodeContainer.Visible = nodeDdOpen
            updateNodeDropdownText()
        end)

        -- Auto button
        local autoBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundColor3 = COLORS.BG,
            Text = "Auto (Best Node for Net Worth)",
            TextColor3 = (gConfig.miningTargetNode == "Auto") and C.accent or C.text,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, nodeContainer)
        corner(4, autoBtn)
        autoBtn.MouseButton1Click:Connect(function()
            gConfig.miningTargetNode = "Auto"
            saveConfig()
            nodeDdOpen = false
            nodeContainer.Visible = false
            updateNodeDropdownText()
            abLog("[Mine] Mining Target: Auto (Best for Net Worth)", C.accent)
        end)

        -- Nodes 1-10 buttons
        for i = 1, 10 do
            local req = NODE_REQ[i]
            local nBtn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = COLORS.BG,
                Text = string.format("Node %d (%s NW)", i, req.label),
                TextColor3 = (gConfig.miningTargetNode == "Node " .. i) and C.gold or C.text2,
                TextSize = 10,
                Font = Enum.Font.MontserratMedium,
                BorderSizePixel = 0,
            }, nodeContainer)
            corner(4, nBtn)
            nBtn.MouseButton1Click:Connect(function()
                gConfig.miningTargetNode = "Node " .. i
                saveConfig()
                nodeDdOpen = false
                nodeContainer.Visible = false
                updateNodeDropdownText()
                local nw = getPlayerNW()
                if nw < req.nw then
                    abLog(string.format("[Warning] Target set to Node %d, but player Net Worth is below %s!", i, req.label), C.orange)
                else
                    abLog("[Mine] Mining Target: Node " .. i, C.green)
                end
            end)
        end

        -- Continuous Auto-Mine Toggle
        local mineToggle, updateMineToggle = createToggle(mineCard, "Auto-Mine Rock Node (Continuous Loop)", gConfig.autoMineNodes, function(state)
            gConfig.autoMineNodes = state
            saveConfig()
            if state then
                abLog("[Mine] Continuous Auto-Mine: ENABLED", C.green)
                task.spawn(function() startMiningSession(true) end)
            else
                abLog("Continuous Auto-Mine: DISABLED", C.textMuted)
                stopMining()
            end
        end)
        _G.uiToggles["autoMineNodes"] = updateMineToggle

        -- Start Mine Selected Node Button (Single Drop)
        createButton(mineCard, "Start Mining Selected Node Now", function()
            task.spawn(function() startMiningSession(false) end)
        end)

        -- Stop Mining Button
        createButton(mineCard, "Stop Mining", function()
            stopMining()
            abLog("[Mine] Mining stopped by user.", C.orange)
        end)

        -- Equip Best Pickaxe Button
        createButton(mineCard, "Equip Best Pickaxe", function()
            local name = equipBestPickaxe()
            if name then
                abLog("[Mine] Equipped: " .. tostring(name), C.green)
                showWorkshopPopup("Equipped: " .. tostring(name), C.green)
            else
                abLog("No pickaxe owned - buy one from Miner stall.", C.orange)
                showWorkshopPopup("No pickaxe owned!", C.orange)
            end
        end)

        -- 2. MIXING CAULDRON CARD
        local cauldronCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabMines)
        corner(6, cauldronCard); pad(8, cauldronCard); list(nil, 6, cauldronCard)

        make("TextLabel", {
            Text = "MIXING CAULDRON",
            TextSize = 10,
            TextColor3 = Color3.fromRGB(255, 190, 90),
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, cauldronCard)

        local brewToggle, updateBrewToggle = createToggle(cauldronCard, "Auto-Brew Cauldron (Best Jewel Owned)", gConfig.autoBrewCauldron, function(state)
            gConfig.autoBrewCauldron = state
            saveConfig()
            if state then
                abLog("[Lab] Auto-Brew: ENABLED", C.green)
                task.spawn(autoBrewOnce)
            else
                abLog("Auto-Brew: DISABLED", C.textMuted)
            end
        end)
        _G.uiToggles["autoBrewCauldron"] = updateBrewToggle

        createButton(cauldronCard, "Brew Cauldron Once (Best Jewel)", function()
            local jid = bestJewel()
            if not jid then
                abLog("No sufficient jewels to brew (check brew recipe costs).", C.orange)
                return
            end
            local ok, res = brewJewel(jid)
            if ok then
                abLog("[Lab] Brewed " .. (JEWEL_NAME[jid] or jid) .. "!", C.green)
                showWorkshopPopup("Cauldron brewed!", C.green)
            else
                abLog("Brew failed: " .. tostring(res), C.red)
            end
        end)

        createButton(cauldronCard, "Teleport to Mixing Cauldron", function()
            local ca = ws:FindFirstChild("Areas") and ws.Areas:FindFirstChild("The Mines") and ws.Areas["The Mines"]:FindFirstChild("Mixing Cauldron")
            if ca then
                local p = ca:GetPivot().Position
                -- Stand on platform directly in front of the cauldron facing it
                safeTP(CFrame.lookAt(Vector3.new(p.X, p.Y, p.Z + 6), Vector3.new(p.X, p.Y, p.Z)))
            else
                safeTP(CFrame.new(MINES_HUB + Vector3.new(0, 2, 8)))
            end
        end)

        -- 3. MINER'S DRINKS STALL CARD
        local drinksCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabMines)
        corner(6, drinksCard); pad(8, drinksCard); list(nil, 6, drinksCard)

        make("TextLabel", {
            Text = "MINER'S DRINKS STALL",
            TextSize = 10,
            TextColor3 = C.green,
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, drinksCard)

        local miningDrinkList = {
            { id = "18", name = "Mining Speed Drink ([Gem] 20)", short = "Speed" },
            { id = "19", name = "Mining Luck Drink ([Gem] 30)", short = "Luck" },
        }

        -- Row 1: Auto-Buy Mining Drinks
        local autoBuyMiningRow = make("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(20, 24, 34),
            BorderSizePixel = 0,
        }, drinksCard)
        corner(5, autoBuyMiningRow); stroke(1, C.border, autoBuyMiningRow)

        make("TextLabel", {
            Size = UDim2.new(0.42, 0, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = "Auto-Buy Drinks:",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, autoBuyMiningRow)

        local autoBuyMiningToggle = make("TextButton", {
            Size = UDim2.new(0, 50, 0, 24),
            Position = UDim2.new(0.43, 0, 0.5, -12),
            BackgroundColor3 = gConfig.autoBuyMiningDrinks and C.accent or COLORS.BG,
            Text = gConfig.autoBuyMiningDrinks and "ON" or "OFF",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, autoBuyMiningRow)
        corner(4, autoBuyMiningToggle); stroke(1, C.border, autoBuyMiningToggle)

        local selectedBuyMiningBtn = make("TextButton", {
            Size = UDim2.new(0, 105, 0, 24),
            Position = UDim2.new(1, -115, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "None v",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, autoBuyMiningRow)
        corner(4, selectedBuyMiningBtn); stroke(1, C.border, selectedBuyMiningBtn)

        local buyMiningDdContainer = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
        }, drinksCard)
        list(nil, 4, buyMiningDdContainer)

        local buyMiningDdOpen = false
        local buyMiningBtns = {}

        local function updateBuyMiningDropdownText()
            if not gConfig.buyMiningDrinks or type(gConfig.buyMiningDrinks) ~= "table" then
                gConfig.buyMiningDrinks = { ["18"] = true, ["19"] = true }
            end
            local selected = {}
            for _, d in ipairs(miningDrinkList) do
                if gConfig.buyMiningDrinks[d.id] then table.insert(selected, d.short) end
            end
            if #selected == 0 then
                selectedBuyMiningBtn.Text = "None" .. (buyMiningDdOpen and " ^" or " v")
                selectedBuyMiningBtn.TextColor3 = C.text2
            elseif #selected == #miningDrinkList then
                selectedBuyMiningBtn.Text = "All Drinks" .. (buyMiningDdOpen and " ^" or " v")
                selectedBuyMiningBtn.TextColor3 = C.gold
            else
                selectedBuyMiningBtn.Text = table.concat(selected, ", ") .. (buyMiningDdOpen and " ^" or " v")
                selectedBuyMiningBtn.TextColor3 = C.gold
            end
            for _, d in ipairs(miningDrinkList) do
                local b = buyMiningBtns[d.id]
                if b then
                    if gConfig.buyMiningDrinks[d.id] then
                        b.TextColor3 = C.gold
                        b.BackgroundColor3 = COLORS.BG
                    else
                        b.TextColor3 = C.text2
                        b.BackgroundColor3 = C.card
                    end
                end
            end
        end

        selectedBuyMiningBtn.MouseButton1Click:Connect(function()
            buyMiningDdOpen = not buyMiningDdOpen
            buyMiningDdContainer.Visible = buyMiningDdOpen
            updateBuyMiningDropdownText()
        end)

        for _, opt in ipairs(miningDrinkList) do
            local btn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = C.card,
                Text = opt.name,
                TextColor3 = C.text2,
                TextSize = 9,
                Font = Enum.Font.MontserratMedium,
                BorderSizePixel = 0,
            }, buyMiningDdContainer)
            corner(4, btn); stroke(1, C.border, btn)
            buyMiningBtns[opt.id] = btn

            btn.MouseButton1Click:Connect(function()
                if not gConfig.buyMiningDrinks or type(gConfig.buyMiningDrinks) ~= "table" then
                    gConfig.buyMiningDrinks = { ["18"] = true, ["19"] = true }
                end
                gConfig.buyMiningDrinks[opt.id] = not gConfig.buyMiningDrinks[opt.id]
                updateBuyMiningDropdownText()
                saveConfig()
            end)
        end
        updateBuyMiningDropdownText()
        _G.uiUpdaters["buyMiningDrinks"] = updateBuyMiningDropdownText

        local function updateAutoBuyMiningDrinksUI(state)
            gConfig.autoBuyMiningDrinks = state
            autoBuyMiningToggle.Text = state and "ON" or "OFF"
            autoBuyMiningToggle.BackgroundColor3 = state and C.accent or COLORS.BG
        end
        _G.uiToggles["autoBuyMiningDrinks"] = updateAutoBuyMiningDrinksUI

        autoBuyMiningToggle.MouseButton1Click:Connect(function()
            local newState = not gConfig.autoBuyMiningDrinks
            updateAutoBuyMiningDrinksUI(newState)
            saveConfig()
            if newState then
                abLog("Auto-Buy Mining Drinks: ENABLED", C.green)
            else
                abLog("Auto-Buy Mining Drinks: DISABLED", C.textMuted)
            end
        end)

        -- Row 2: Auto-Use Mining Drinks
        local autoUseMiningRow = make("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(20, 24, 34),
            BorderSizePixel = 0,
        }, drinksCard)
        corner(5, autoUseMiningRow); stroke(1, C.border, autoUseMiningRow)

        make("TextLabel", {
            Size = UDim2.new(0.42, 0, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = "Auto-Use Drinks:",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, autoUseMiningRow)

        local autoUseMiningToggle = make("TextButton", {
            Size = UDim2.new(0, 50, 0, 24),
            Position = UDim2.new(0.43, 0, 0.5, -12),
            BackgroundColor3 = gConfig.autoUseMiningDrinks and C.accent or COLORS.BG,
            Text = gConfig.autoUseMiningDrinks and "ON" or "OFF",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, autoUseMiningRow)
        corner(4, autoUseMiningToggle); stroke(1, C.border, autoUseMiningToggle)

        local selectedUseMiningBtn = make("TextButton", {
            Size = UDim2.new(0, 105, 0, 24),
            Position = UDim2.new(1, -115, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "None v",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, autoUseMiningRow)
        corner(4, selectedUseMiningBtn); stroke(1, C.border, selectedUseMiningBtn)

        local useMiningDdContainer = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
        }, drinksCard)
        list(nil, 4, useMiningDdContainer)

        local useMiningDdOpen = false
        local useMiningBtns = {}

        local function updateUseMiningDropdownText()
            if not gConfig.useMiningDrinks or type(gConfig.useMiningDrinks) ~= "table" then
                gConfig.useMiningDrinks = { ["18"] = true, ["19"] = true }
            end
            local selected = {}
            for _, d in ipairs(miningDrinkList) do
                if gConfig.useMiningDrinks[d.id] then table.insert(selected, d.short) end
            end
            if #selected == 0 then
                selectedUseMiningBtn.Text = "None" .. (useMiningDdOpen and " ^" or " v")
                selectedUseMiningBtn.TextColor3 = C.text2
            elseif #selected == #miningDrinkList then
                selectedUseMiningBtn.Text = "All Drinks" .. (useMiningDdOpen and " ^" or " v")
                selectedUseMiningBtn.TextColor3 = C.gold
            else
                selectedUseMiningBtn.Text = table.concat(selected, ", ") .. (useMiningDdOpen and " ^" or " v")
                selectedUseMiningBtn.TextColor3 = C.gold
            end
            for _, d in ipairs(miningDrinkList) do
                local b = useMiningBtns[d.id]
                if b then
                    if gConfig.useMiningDrinks[d.id] then
                        b.TextColor3 = C.gold
                        b.BackgroundColor3 = COLORS.BG
                    else
                        b.TextColor3 = C.text2
                        b.BackgroundColor3 = C.card
                    end
                end
            end
        end

        selectedUseMiningBtn.MouseButton1Click:Connect(function()
            useMiningDdOpen = not useMiningDdOpen
            useMiningDdContainer.Visible = useMiningDdOpen
            updateUseMiningDropdownText()
        end)

        for _, opt in ipairs(miningDrinkList) do
            local btn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = C.card,
                Text = opt.name,
                TextColor3 = C.text2,
                TextSize = 9,
                Font = Enum.Font.MontserratMedium,
                BorderSizePixel = 0,
            }, useMiningDdContainer)
            corner(4, btn); stroke(1, C.border, btn)
            useMiningBtns[opt.id] = btn

            btn.MouseButton1Click:Connect(function()
                if not gConfig.useMiningDrinks or type(gConfig.useMiningDrinks) ~= "table" then
                    gConfig.useMiningDrinks = { ["18"] = true, ["19"] = true }
                end
                gConfig.useMiningDrinks[opt.id] = not gConfig.useMiningDrinks[opt.id]
                updateUseMiningDropdownText()
                saveConfig()
            end)
        end
        updateUseMiningDropdownText()
        _G.uiUpdaters["useMiningDrinks"] = updateUseMiningDropdownText

        local function updateAutoUseMiningDrinksUI(state)
            gConfig.autoUseMiningDrinks = state
            autoUseMiningToggle.Text = state and "ON" or "OFF"
            autoUseMiningToggle.BackgroundColor3 = state and C.accent or COLORS.BG
        end
        _G.uiToggles["autoUseMiningDrinks"] = updateAutoUseMiningDrinksUI

        autoUseMiningToggle.MouseButton1Click:Connect(function()
            local newState = not gConfig.autoUseMiningDrinks
            updateAutoUseMiningDrinksUI(newState)
            saveConfig()
            if newState then
                abLog("[Lab] Auto-Use Mining Drinks: ENABLED", C.green)
            else
                abLog("Auto-Use Mining Drinks: DISABLED", C.textMuted)
            end
        end)

        -- Live Status indicator
        local miningDrinkStatusLbl = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Active Buffs: Loading...",
            TextColor3 = C.textMuted,
            TextSize = 9,
            Font = Enum.Font.MontserratMedium,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, drinksCard)

        task.spawn(function()
            while task.wait(1) do
                if not drinksCard or not drinksCard.Parent then break end
                local now = workspace:GetServerTimeNow()
                local sExp = tonumber(lp:GetAttribute("ActiveLuckDrinkExpireAt_18")) or 0
                local lExp = tonumber(lp:GetAttribute("ActiveLuckDrinkExpireAt_19")) or 0
                local sRem = math.max(0, math.floor(sExp - now))
                local lRem = math.max(0, math.floor(lExp - now))
                local sText = sRem > 0 and (math.floor(sRem / 60) .. ":" .. string.format("%02d", sRem % 60)) or "Inactive"
                local lText = lRem > 0 and (math.floor(lRem / 60) .. ":" .. string.format("%02d", lRem % 60)) or "Inactive"
                miningDrinkStatusLbl.Text = "Active: Speed (" .. sText .. ") | Luck (" .. lText .. ")"
                miningDrinkStatusLbl.TextColor3 = (sRem > 0 or lRem > 0) and C.gold or C.textMuted
            end
        end)

        createButton(drinksCard, "Buy Mining Speed Drink (20 Diamonds)", function()
            buyDrink("speed")
        end)

        createButton(drinksCard, "Buy Mining Luck Drink (30 Diamonds)", function()
            buyDrink("luck")
        end)

        createButton(drinksCard, "Use Mining Speed Drink (From Inventory)", function()
            useDrink("speed")
        end)

        createButton(drinksCard, "Use Mining Luck Drink (From Inventory)", function()
            useDrink("luck")
        end)

        -- 4. MINING SUPERVISOR & NPCS CARD
        local npcCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabMines)
        corner(6, npcCard); pad(8, npcCard); list(nil, 6, npcCard)

        make("TextLabel", {
            Text = "MINING SUPERVISOR & NPCS",
            TextSize = 10,
            TextColor3 = C.accent,
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Left,
        }, npcCard)

        createButton(npcCard, "Teleport to Mining Supervisor", function()
            local sup = ws:FindFirstChild("Areas") and ws.Areas:FindFirstChild("The Mines") and ws.Areas["The Mines"]:FindFirstChild("Mining Supervisor")
            if sup then
                local p = sup:GetPivot().Position
                safeTP(CFrame.lookAt(p + (sup:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
            else
                safeTP(CFrame.new(MINES_HUB + Vector3.new(0, 2, 3)))
            end
        end)

        createButton(npcCard, "Teleport to Miner's Drink Seller", function()
            local d = ws:FindFirstChild("Areas") and ws.Areas:FindFirstChild("The Mines") and ws.Areas["The Mines"]:FindFirstChild("Miner's Drink Seller")
            if d then
                local p = d:GetPivot().Position
                safeTP(CFrame.lookAt(p + (d:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
            else
                safeTP(CFrame.new(MINES_HUB + Vector3.new(0, 2, 3)))
            end
        end)
    end

-- Management Subtabs: Pawn / Sell, Exclusions, Automation, Utilities, Shop
local mgmtSubtabs    = createSubTabs(tabManagement, {"Pawn / Sell", "Exclusions", "Automation", "Utilities", "Shop"}, "Pawn / Sell")
local tabPawn       = mgmtSubtabs["Pawn / Sell"]
local tabExclusions = mgmtSubtabs["Exclusions"]
local tabConfig     = tabProfile  -- now a top-level main tab
local tabAutomation = mgmtSubtabs["Automation"]
local tabUtilities  = mgmtSubtabs["Utilities"]
local tabShop       = mgmtSubtabs["Shop"]

-- -- TABS IMPLEMENTATION ------------------------------

-- [Quest] CHANGELOG TAB
do
    local logText = "<b><font color='#00F0C8'>[v16.0 Update - Military Base & Carnival Update]</font></b>\n" ..
        "• <b>New Garages & Catalogues</b>: Added Military Tent, Barrack, Enforced Barrack, Bunker Garage, and Camo Airdrop.\n" ..
        "• <b>New Mutators</b>: Added [Bulletproof] (3.0x), [Fortified] (4.0x), [Jestered] (5.0x), [Vaulted] (7.0x), [Camo] (16.0x), [Warforged] (30.0x), and [Encrypted] (35.0x).\n" ..
        "• <b>Live DEFCON Monitor</b>: Real-time DEFCON 5 -> DEFCON 1 level monitoring with server win trackers and active mutator detection.\n" ..
        "• <b>Camo Airdrop Fast-Claim & Teleports</b>: Instant teleport & auto-claim nearest Camo Airdrop when DEFCON hits 1.\n" ..
        "• <b>Military & Carnival Teleports</b>: Added Military Base (Gate & Courtyard), General Commander, Soldier NPC, Secret Service NPC, and Carnival Hub.\n" ..
        "• <b>Halloween Code Deprecation</b>: Clean removal of obsolete Halloween event files and memory overhead for maximum FPS."
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
        Text = "NexWorks v16.1 Beta Changelog",
        TextColor3 = Color3.fromRGB(0, 240, 200),
        Font = Enum.Font.MontserratBold,
        TextSize = 15
    }, tabChangelog)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = logText,
        TextColor3 = Color3.fromRGB(220, 225, 235),
        Font = Enum.Font.Montserrat,
        TextSize = 10,
        TextWrapped = true,
        RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top
    }, tabChangelog)
end

-- AUTOFARM EXCLUSIVE TAB
do
    gConfig.seatedAutofarm = gConfig.seatedAutofarm or false
    gConfig.afAutoUnload = gConfig.afAutoUnload == nil and false or gConfig.afAutoUnload
    gConfig.afAutoPlace = gConfig.afAutoPlace == nil and false or gConfig.afAutoPlace

    gConfig.pickupDelay = gConfig.pickupDelay or 0.65


    local afToggleCard, updateAFToggle = createToggle(tabAutofarm, "Autofarm", gConfig.seatedAutofarm, function(state)
        gConfig.seatedAutofarm = state
        if state then
            AB.enabled = (gConfig.autoBidEnabled == true)
        else
            AB.pickupPhase = false
            stopBidLoop()
        end
        saveConfig()
    end)
    _G.uiToggles["seatedAutofarm"] = updateAFToggle

    local autoCollectCard, updateAutoCollectToggle = createToggle(tabAutofarm, "Auto Collect Won Items", gConfig.autoCollectWon ~= false, function(state)
        gConfig.autoCollectWon = state
        if state then
            abLog("[Pickup] Auto Collect ON.", C.green)
        else
            abLog("[Pickup] Auto Collect OFF — use 'Collect' after spraying tournament items.", C.gold)
        end
        saveConfig()
    end)
    _G.uiToggles["autoCollectWon"] = updateAutoCollectToggle

    local showFloatingCollectCard, updateFloatingCollectToggle = createToggle(tabAutofarm, "Floating Collect Button", gConfig.showFloatingCollect == true, function(state)
        gConfig.showFloatingCollect = state
        if _G.animateCollectButton then _G.animateCollectButton(state) end
        saveConfig()
    end)
    _G.uiToggles["showFloatingCollect"] = updateFloatingCollectToggle

    createButton(tabAutofarm, "Collect Won Items Now", function()
        if _G.manualCollectWonItems then
            _G.manualCollectWonItems()
            showWorkshopPopup("Collecting won items...", C.green)
        end
    end)

    local manualDelayCard = make("Frame", {
        Name = "ManualCollectDelayCard", Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.card, BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, manualDelayCard)
    make("TextLabel", {
        Size = UDim2.new(0.70, -16, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Text = "Next Garage Delay (Auto Collect Off, s):",
        TextColor3 = C.text, TextSize = 9, Font = Enum.Font.MontserratBold,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    }, manualDelayCard)
    local manualDelayBox = make("TextBox", {
        Name = "ManualCollectDelayInput", Size = UDim2.new(0.30, -12, 0, 24),
        Position = UDim2.new(0.70, 0, 0.5, -12), BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.manualCollectDelay or 15), PlaceholderText = "Seconds",
        TextColor3 = C.gold, TextSize = 10, Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, manualDelayCard)
    corner(5, manualDelayBox); stroke(1, C.border, manualDelayBox)
    local function updateManualDelayUI(val)
        local n = math.clamp(math.floor(tonumber(val) or gConfig.manualCollectDelay or 15), 0, 180)
        gConfig.manualCollectDelay = n
        manualDelayBox.Text = tostring(n)
    end
    _G.uiUpdaters["manualCollectDelay"] = updateManualDelayUI
    _G.inputFlushers["manualCollectDelayInput"] = function()
        local n = tonumber(manualDelayBox.Text)
        if n then gConfig.manualCollectDelay = math.clamp(math.floor(n), 0, 180) end
    end
    manualDelayBox.FocusLost:Connect(function()
        updateManualDelayUI(manualDelayBox.Text)
        saveConfig()
    end)

    -- Auction Rush toggle removed for public release
    local quickWinToggleCard, updateQuickWinToggle = createToggle(tabAutofarm, "Quick Win (First Bid + 10s Exit)", gConfig.quickWinAuction, function(enabled)
        AB.biddingModes:Set("quickWinAuction", enabled)
        if enabled then abLog("Quick Win enabled. AutoBid disabled. Armed for the next first bid.", C.gold) end
    end)
    quickWinToggleCard.Name = "QuickWinToggle"
    AB.biddingModes:RegisterVisual("quickWinAuction", updateQuickWinToggle)
    _G.uiToggles["quickWinAuction"] = function(enabled)
        AB.biddingModes:Set("quickWinAuction", enabled)
    end

    local noNPCToggleCard, updateNoNPCToggle = createToggle(tabAutofarm, "No NPC Collision (Pass-Through)", gConfig.noNPCCollision, function(state)
        gConfig.noNPCCollision = state
        saveConfig()
        if _G.scanAllNPCs then pcall(_G.scanAllNPCs) end
    end)
    noNPCToggleCard.Name = "NoNPCToggle"
    _G.uiToggles["noNPCCollision"] = updateNoNPCToggle

    local quickWinMinimumCard = make("Frame", {
        Name = "QuickWinMinimumCard", Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card, BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, quickWinMinimumCard)
    make("TextLabel", {
        Size = UDim2.new(0.65, -18, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1, Text = "Quick Win Min Starting Bid:",
        TextColor3 = C.text, TextSize = 10, Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, quickWinMinimumCard)
    local quickWinMinimumBox = make("TextBox", {
        Name = "QuickWinMinimumInput", Size = UDim2.new(0.35, -12, 0, 24),
        Position = UDim2.new(0.65, 0, 0.5, -12), BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.quickWinMinStartBid or 0), PlaceholderText = "0 = any price",
        TextColor3 = C.gold, TextSize = 10, Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, quickWinMinimumCard)
    corner(5, quickWinMinimumBox); stroke(1, C.border, quickWinMinimumBox)
    local function updateQuickWinMinimum(value)
        local minimum = AB.biddingModes.ParseMinimum(value)
        if minimum == nil then minimum = gConfig.quickWinMinStartBid or 0 end
        gConfig.quickWinMinStartBid = minimum
        quickWinMinimumBox.Text = tostring(minimum)
    end
    _G.uiUpdaters["quickWinMinStartBid"] = updateQuickWinMinimum
    _G.inputFlushers["quickWinMinimumInput"] = function()
        local minimum = AB.biddingModes.ParseMinimum(quickWinMinimumBox.Text)
        if minimum ~= nil then gConfig.quickWinMinStartBid = minimum end
    end
    quickWinMinimumBox.FocusLost:Connect(function()
        updateQuickWinMinimum(quickWinMinimumBox.Text)
        saveConfig()
    end)

    -- Min Pickup Value input
    local minPickupCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, minPickupCard)
    make("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Min Pickup Value ($):",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, minPickupCard)

    local minPickupBox = make("TextBox", {
        Size = UDim2.new(0, 80, 0, 24),
        Position = UDim2.new(1, -92, 0.5, -12),
        BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.minPickupValue or 0),
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, minPickupCard)
    corner(5, minPickupBox); stroke(1, C.border, minPickupBox)

    local minPickupStatusLbl = make("TextLabel", {
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(1, -150, 0, 0),
        BackgroundTransparency = 1,
        Text = (gConfig.minPickupValue == 0 and "Off (All)" or "Active"),
        TextColor3 = (gConfig.minPickupValue == 0 and C.text2 or C.gold),
        TextSize = 9,
        Font = Enum.Font.Montserrat,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, minPickupCard)

    local function updateMinPickupUI(val)
        val = tonumber(val) or gConfig.minPickupValue or 0
        minPickupBox.Text = tostring(val)
        minPickupStatusLbl.Text = (val == 0 and "Off (All)" or "Active")
        minPickupStatusLbl.TextColor3 = (val == 0 and C.text2 or C.gold)
    end
    _G.uiUpdaters["minPickupValue"] = updateMinPickupUI

    minPickupBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(minPickupBox.Text)
        if val then
            gConfig.minPickupValue = math.max(0, math.floor(val))
            minPickupStatusLbl.Text = (gConfig.minPickupValue == 0 and "Off (All)" or "Active")
            minPickupStatusLbl.TextColor3 = (gConfig.minPickupValue == 0 and C.text2 or C.gold)
        end
    end)

    minPickupBox.FocusLost:Connect(function()
        local val = tonumber(minPickupBox.Text)
        if val then
            gConfig.minPickupValue = math.max(0, math.floor(val))
            minPickupBox.Text = tostring(gConfig.minPickupValue)
            minPickupStatusLbl.Text = (gConfig.minPickupValue == 0 and "Off (All)" or "Active")
            minPickupStatusLbl.TextColor3 = (gConfig.minPickupValue == 0 and C.text2 or C.gold)
            saveConfig()
        else
            minPickupBox.Text = tostring(gConfig.minPickupValue or 0)
        end
    end)

    -- Pickup Delay Slider UI
    local pickupDelayCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, pickupDelayCard)

    make("TextLabel", {
        Size = UDim2.new(0.4, 0, 0, 20),
        Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1,
        Text = "Pickup Delay (Speed):",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, pickupDelayCard)

    local pickupDelayValLbl = make("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 20),
        Position = UDim2.new(0.7, -12, 0, 4),
        BackgroundTransparency = 1,
        Text = string.format("%.2fs", gConfig.pickupDelay or 0.65),
        TextColor3 = C.accent,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, pickupDelayCard)

    local sliderTrack = make("Frame", {
        Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0.7, -3),
        BackgroundColor3 = COLORS.BG,
        BorderSizePixel = 0,
    }, pickupDelayCard)
    corner(3, sliderTrack)

    local sliderFill = make("Frame", {
        Size = UDim2.fromScale(math.clamp(((gConfig.pickupDelay or 0.65) - 0.1) / (2.0 - 0.1), 0, 1), 1),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, sliderTrack)
    corner(3, sliderFill)

    local sliderBtn = make("ImageButton", {
        Size = UDim2.fromOffset(12, 12),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(math.clamp(((gConfig.pickupDelay or 0.65) - 0.1) / (2.0 - 0.1), 0, 1), 0.5),
        BackgroundColor3 = C.text,
        BorderSizePixel = 0,
    }, sliderTrack)
    corner(6, sliderBtn)

    local sliderDragging = false
    local function applySliderAt(ratio)
        local val = 0.1 + ratio * (2.0 - 0.1)
        val = math.floor(val * 100) / 100
        gConfig.pickupDelay = val
        saveConfig()
        pickupDelayValLbl.Text = string.format("%.2fs", val)
        sliderFill.Size = UDim2.fromScale(ratio, 1)
        sliderBtn.Position = UDim2.fromScale(ratio, 0.5)
    end

    table.insert(cleanUpSignals, sliderTrack.InputBegan:Connect(function(inp)
        if isTouchOrClick(inp) then
            sliderDragging = true
            applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1))
        end
    end))
    table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
        if sliderDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
            applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1))
        end
    end))
    table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
        if isTouchOrClick(inp) and sliderDragging then
            sliderDragging = false
            saveConfig()
        end
    end))

    local function updatePickupDelayUI(val)
        val = tonumber(val) or gConfig.pickupDelay or 0.65
        val = math.clamp(val, 0.1, 2.0)
        local ratio = math.clamp((val - 0.1) / (2.0 - 0.1), 0, 1)
        pickupDelayValLbl.Text = string.format("%.2fs", val)
        sliderFill.Size = UDim2.fromScale(ratio, 1)
        sliderBtn.Position = UDim2.fromScale(ratio, 0.5)
    end
    _G.uiUpdaters["pickupDelay"] = updatePickupDelayUI

    local afUnloadToggleCard, updateAFUnloadToggle = createToggle(tabAutofarm, "Auto Unload on Full", gConfig.afAutoUnload, function(state)
        gConfig.afAutoUnload = state
        saveConfig()
    end)
    _G.uiToggles["afAutoUnload"] = updateAFUnloadToggle

    -- Cargo Unload Threshold (%) card
    local unloadThresholdCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, unloadThresholdCard)

    make("TextLabel", {
        Text = "Unload Threshold (50-100%):",
        TextSize = 11, Font = Enum.Font.MontserratBold,
        TextColor3 = C.text,
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, unloadThresholdCard)

    local unloadThresholdBox = make("TextBox", {
        Size = UDim2.new(0, 80, 0, 24),
        Position = UDim2.new(1, -92, 0.5, -12),
        BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.autoUnloadThreshold or 80),
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, unloadThresholdCard)
    corner(5, unloadThresholdBox); stroke(1, C.border, unloadThresholdBox)

    local function updateUnloadThresholdUI(val)
        val = tonumber(val) or gConfig.autoUnloadThreshold or 80
        unloadThresholdBox.Text = tostring(math.clamp(math.floor(val), 50, 100))
    end
    _G.uiUpdaters["autoUnloadThreshold"] = updateUnloadThresholdUI

    unloadThresholdBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(unloadThresholdBox.Text)
        if val and val >= 50 and val <= 100 then
            gConfig.autoUnloadThreshold = math.floor(val)
        end
    end)

    unloadThresholdBox.FocusLost:Connect(function()
        local val = tonumber(unloadThresholdBox.Text)
        if val then
            gConfig.autoUnloadThreshold = math.clamp(math.floor(val), 50, 100)
        else
            gConfig.autoUnloadThreshold = gConfig.autoUnloadThreshold or 80
        end
        unloadThresholdBox.Text = tostring(gConfig.autoUnloadThreshold)
        saveConfig()
    end)
    
    local afPlaceToggleCard
    afPlaceToggleCard, updateAFPlaceToggle = createToggle(tabAutofarm, "Auto Place Store Items", gConfig.autoPlaceStoreItems, function(state)
        if isSyncingToggles then return end
        isSyncingToggles = true
        gConfig.autoPlaceStoreItems = state
        if updateASToggle then pcall(updateASToggle, state) end
        saveConfig()
        isSyncingToggles = false
    end)
    _G.uiToggles["autoPlaceStoreItems"] = function(state)
        if updateAFPlaceToggle then pcall(updateAFPlaceToggle, state) end
        if updateASToggle then pcall(updateASToggle, state) end
    end

    -- Backpack Auto-Place Trigger Threshold (%) card
    local placeThresholdCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, placeThresholdCard)
    make("TextLabel", {
        Text = "Backpack Trigger Threshold (50-100%):",
        TextSize = 10, Font = Enum.Font.MontserratBold,
        TextColor3 = C.text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.68, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, placeThresholdCard)
    local placeThresholdBox = make("TextBox", {
        Size = UDim2.new(0, 60, 0, 24),
        Position = UDim2.new(1, -72, 0.5, -12),
        BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.autoPlaceThreshold or 80),
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
    }, placeThresholdCard)
    corner(4, placeThresholdBox); stroke(1, C.border, placeThresholdBox)

    local function updatePlaceThresholdUI(val)
        val = tonumber(val) or gConfig.autoPlaceThreshold or 80
        placeThresholdBox.Text = tostring(math.clamp(math.floor(val), 50, 100))
    end
    _G.uiUpdaters["autoPlaceThreshold"] = updatePlaceThresholdUI

    placeThresholdBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(placeThresholdBox.Text)
        if val and val >= 50 and val <= 100 then
            gConfig.autoPlaceThreshold = math.floor(val)
        end
    end)

    placeThresholdBox.FocusLost:Connect(function()
        local val = tonumber(placeThresholdBox.Text)
        if val then
            gConfig.autoPlaceThreshold = math.clamp(math.floor(val), 50, 100)
        else
            gConfig.autoPlaceThreshold = gConfig.autoPlaceThreshold or 80
        end
        placeThresholdBox.Text = tostring(gConfig.autoPlaceThreshold)
        saveConfig()
    end)

    -- Plot Pit-Stop Teleport Toggle (OFF by default — remote placing runs without this)
    local _, updatePitStopToggle = createToggle(tabAutofarm, "Enable Plot Pit-Stop Teleport", gConfig.enablePlotPitStop, function(state)
        gConfig.enablePlotPitStop = state
        saveConfig()
        if state then
            abLog("Plot Pit-Stop enabled: script will physically TP you to stock shelves.", C.gold)
        else
            abLog("Plot Pit-Stop disabled: shelves stocked remotely (recommended).", C.green)
        end
    end)
    _G.uiToggles["enablePlotPitStop"] = updatePitStopToggle

    -- Manual Store Place Button
    local manualPlaceCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, manualPlaceCard)
    local manualPlaceBtn = make("TextButton", {
        Text = "Stock Store Shelves Now (Plot Pit-Stop)",
        TextSize = 11, Font = Enum.Font.MontserratBold,
        TextColor3 = C.gold,
        BackgroundColor3 = COLORS.BG,
        Position = UDim2.new(0, 10, 0.5, -13),
        Size = UDim2.new(1, -20, 0, 26),
        BorderSizePixel = 0,
        AutoButtonColor = true,
    }, manualPlaceCard)
    corner(4, manualPlaceBtn); stroke(1, C.gold, manualPlaceBtn)
    manualPlaceBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            manualPlaceBtn.Text = "Stocking Store..."
            local placed = _G.doManualPlotPitStop and _G.doManualPlotPitStop(true) or 0
            manualPlaceBtn.Text = "Done (" .. tostring(placed) .. " Placed)"
            task.wait(2.0)
            manualPlaceBtn.Text = "Stock Store Shelves Now (Plot Pit-Stop)"
        end)
    end)

    local savePlotCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, savePlotCard)
    local savePlotBtn = make("TextButton", {
        Text = "Save Current Plot as Pit-Stop",
        TextSize = 11, Font = Enum.Font.MontserratBold,
        TextColor3 = C.green,
        BackgroundColor3 = COLORS.BG,
        Position = UDim2.new(0, 10, 0.5, -13),
        Size = UDim2.new(1, -20, 0, 26),
        BorderSizePixel = 0,
        AutoButtonColor = true,
    }, savePlotCard)
    corner(4, savePlotBtn); stroke(1, C.green, savePlotBtn)
    savePlotBtn.MouseButton1Click:Connect(function()
        -- Always save the player's EXACT current standing position as the pit-stop target
        local char = game:GetService("Players").LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            savePlotBtn.Text = "Character not found"
            task.wait(2.0)
            savePlotBtn.Text = "Save Current Plot as Pit-Stop"
            return
        end
        local targetCF = root.CFrame
        gConfig.savedPlotDriveway = targetCF
        cachedMyPlotCF = targetCF
        _G.AHScanner_UnpackCF = targetCF
        saveConfig()
        local pos = targetCF.Position
        savePlotBtn.Text = "Plot Saved!"
        abLog(string.format("Pit-Stop saved at (%.0f, %.0f, %.0f) — Pit-Stop will TP here.", pos.X, pos.Y, pos.Z), C.green)
        task.wait(2.0)
        savePlotBtn.Text = "Save Current Plot as Pit-Stop"
    end)

    -- Min Auto-Place Value card
    local minPlaceCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, minPlaceCard)
    make("TextLabel", {
        Text = "Min Auto-Place Value ($)",
        TextSize = 11, Font = Enum.Font.MontserratBold,
        TextColor3 = C.text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, minPlaceCard)
    local minPlaceBox = make("TextBox", {
        Size = UDim2.new(0, 80, 0, 24),
        Position = UDim2.new(1, -92, 0.5, -12),
        BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.minAutoPlaceValue or 0),
        TextColor3 = C.gold,
        TextSize = 10, Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, minPlaceCard)
    corner(5, minPlaceBox); stroke(1, C.border, minPlaceBox)
    
    local function updateMinPlaceUI(val)
        minPlaceBox.Text = tostring(val or 0)
    end
    _G.uiUpdaters["minAutoPlaceValue"] = updateMinPlaceUI

    minPlaceBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(minPlaceBox.Text)
        if val then
            gConfig.minAutoPlaceValue = math.max(0, math.floor(val))
        end
    end)
    minPlaceBox.FocusLost:Connect(function()
        local val = tonumber(minPlaceBox.Text)
        if val then
            gConfig.minAutoPlaceValue = math.max(0, math.floor(val))
        else
            gConfig.minAutoPlaceValue = gConfig.minAutoPlaceValue or 0
        end
        minPlaceBox.Text = tostring(gConfig.minAutoPlaceValue)
        saveConfig()
    end)

    -- Max Auto-Place Value card (Grouped right after Min)
    local maxPlaceCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, maxPlaceCard)
    make("TextLabel", {
        Text = "Max Auto-Place Value ($)",
        TextSize = 11, Font = Enum.Font.MontserratBold,
        TextColor3 = C.text,
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
    }, maxPlaceCard)
    local maxPlaceBox = make("TextBox", {
        Size = UDim2.new(0, 80, 0, 24),
        Position = UDim2.new(1, -92, 0.5, -12),
        BackgroundColor3 = COLORS.BG,
        Text = tostring(gConfig.maxAutoPlaceValue or 0),
        TextColor3 = Color3.fromRGB(0, 240, 200),
        TextSize = 10, Font = Enum.Font.MontserratBold,
        ClearTextOnFocus = false,
    }, maxPlaceCard)
    corner(5, maxPlaceBox); stroke(1, C.border, maxPlaceBox)
    
    local function updateMaxPlaceUI(val)
        maxPlaceBox.Text = tostring(val or 0)
    end
    _G.uiUpdaters["maxAutoPlaceValue"] = updateMaxPlaceUI

    maxPlaceBox:GetPropertyChangedSignal("Text"):Connect(function()
        local val = tonumber(maxPlaceBox.Text)
        if val then
            gConfig.maxAutoPlaceValue = math.max(0, math.floor(val))
        end
    end)
    maxPlaceBox.FocusLost:Connect(function()
        local val = tonumber(maxPlaceBox.Text)
        if val then
            gConfig.maxAutoPlaceValue = math.max(0, math.floor(val))
        else
            gConfig.maxAutoPlaceValue = gConfig.maxAutoPlaceValue or 0
        end
        maxPlaceBox.Text = tostring(gConfig.maxAutoPlaceValue)
        saveConfig()
    end)

    _G.flushInputValues = function()
        pcall(function()
            if minPickupBox and tonumber(minPickupBox.Text) then
                gConfig.minPickupValue = math.max(0, math.floor(tonumber(minPickupBox.Text)))
            end
            if unloadThresholdBox and tonumber(unloadThresholdBox.Text) then
                gConfig.autoUnloadThreshold = math.clamp(math.floor(tonumber(unloadThresholdBox.Text)), 50, 100)
            end
            if placeThresholdBox and tonumber(placeThresholdBox.Text) then
                gConfig.autoPlaceThreshold = math.clamp(math.floor(tonumber(placeThresholdBox.Text)), 50, 100)
            end
            if minPlaceBox and tonumber(minPlaceBox.Text) then
                gConfig.minAutoPlaceValue = math.max(0, math.floor(tonumber(minPlaceBox.Text)))
            end
            if maxPlaceBox and tonumber(maxPlaceBox.Text) then
                gConfig.maxAutoPlaceValue = math.max(0, math.floor(tonumber(maxPlaceBox.Text)))
            end
            for _, flusher in pairs(_G.inputFlushers or {}) do
                pcall(flusher)
            end
        end)
    end

    -- Disable Game Notifications toggle (Grouped after Max Auto-Place)
    local updateDNToggleRef = nil
    local updateAF_DNToggleRef = nil

    local afDNToggleCard, updateAF_DNToggle = createToggle(tabAutofarm, "Disable Game Notifications", gConfig.disableGameNotifications, function(state)
        gConfig.disableGameNotifications = state
        saveConfig()
        pcall(function()
            local toasts = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ToastsGui")
            if toasts then toasts.Enabled = not state end
        end)
        if updateDNToggleRef then pcall(updateDNToggleRef, state) end
    end)
    updateAF_DNToggleRef = updateAF_DNToggle
    _G.uiToggles["disableGameNotifications"] = function(state)
        if updateAF_DNToggle then pcall(updateAF_DNToggle, state) end
        if updateDNToggleRef then pcall(updateDNToggleRef, state) end
    end

    local updateMuteSoundRef = nil
    local updateAF_MuteSoundRef = nil

    local afMuteSoundCard, updateAF_MuteSound = createToggle(tabAutofarm, "Mute Shelf Sounds (Place/Pick)", gConfig.mutePlacingSounds, function(state)
        gConfig.mutePlacingSounds = state
        saveConfig()
        if updateMuteSoundRef then pcall(updateMuteSoundRef, state) end
    end)
    updateAF_MuteSoundRef = updateAF_MuteSound
    _G.uiToggles["mutePlacingSounds"] = function(state)
        if updateAF_MuteSound then pcall(updateAF_MuteSound, state) end
        if updateMuteSoundRef then pcall(updateMuteSoundRef, state) end
    end



    gConfig.afAutoBuyArea = gConfig.afAutoBuyArea or "Any Area"

    -- Target Area Dropdown Selector for Autofarm
    local afAreaCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabAutofarm)
    corner(6, afAreaCard)

    make("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Target Area (Autofarm):",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, afAreaCard)

    gConfig.afAutoBuyAreas = gConfig.afAutoBuyAreas or { ["Any Area"] = true }

    local afAreaDropdownBtn = make("TextButton", {
        Size = UDim2.new(0, 120, 0, 26),
        Position = UDim2.new(1, -132, 0.5, -13),
        BackgroundColor3 = COLORS.BG,
        Text = "Any Area v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, afAreaCard)
    corner(5, afAreaDropdownBtn); stroke(1, C.border, afAreaDropdownBtn)

    local afDdContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, tabAutofarm)
    list(nil, 4, afDdContainer)

    local afDdOpen = false
    local afAreas = {"Any Area", "Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
    local afBtns = {}

    local function updateAfDropdownText()
        if gConfig.afAutoBuyAreas["Any Area"] then
            afAreaDropdownBtn.Text = "Any Area" .. (afDdOpen and " ^" or " v")
            afAreaDropdownBtn.TextColor3 = C.gold
        else
            local selected = {}
            for _, area in ipairs(afAreas) do
                if area ~= "Any Area" and gConfig.afAutoBuyAreas[area] then
                    table.insert(selected, area)
                end
            end
            if #selected == 0 then
                afAreaDropdownBtn.Text = "None" .. (afDdOpen and " ^" or " v")
                afAreaDropdownBtn.TextColor3 = C.text2
            elseif #selected == 1 then
                afAreaDropdownBtn.Text = selected[1] .. (afDdOpen and " ^" or " v")
                afAreaDropdownBtn.TextColor3 = C.gold
            else
                afAreaDropdownBtn.Text = "Multi (" .. #selected .. ")" .. (afDdOpen and " ^" or " v")
                afAreaDropdownBtn.TextColor3 = C.gold
            end
        end
        for aName, btn in pairs(afBtns) do
            if gConfig.afAutoBuyAreas[aName] then
                btn.TextColor3 = C.gold
                btn.BackgroundColor3 = COLORS.BG
            else
                btn.TextColor3 = C.text2
                btn.BackgroundColor3 = C.card
            end
        end
    end

    afAreaDropdownBtn.MouseButton1Click:Connect(function()
        afDdOpen = not afDdOpen
        afDdContainer.Visible = afDdOpen
        updateAfDropdownText()
    end)

    for _, aName in ipairs(afAreas) do
        local abtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = C.card,
            Text = aName,
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, afDdContainer)
        corner(4, abtn); stroke(1, C.border, abtn)
        afBtns[aName] = abtn
        
        abtn.MouseButton1Click:Connect(function()
            if aName == "Any Area" then
                gConfig.afAutoBuyAreas = { ["Any Area"] = true }
            else
                gConfig.afAutoBuyAreas["Any Area"] = nil
                gConfig.afAutoBuyAreas[aName] = not gConfig.afAutoBuyAreas[aName]
                
                local anyChecked = false
                for _, a in ipairs(afAreas) do
                    if a ~= "Any Area" and gConfig.afAutoBuyAreas[a] then
                        anyChecked = true
                        break
                    end
                end
                if not anyChecked then
                    gConfig.afAutoBuyAreas = { ["Any Area"] = true }
                end
            end
            updateAfDropdownText()
            saveConfig()
        end)
    end
    updateAfDropdownText()
    _G.uiUpdaters["afAutoBuyAreas"] = updateAfDropdownText

    -- Garage Type Checklist Cards for Autofarm Header Row
    local afGarageHeader = make("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
    }, tabAutofarm)

    make("TextLabel", {
        Size = UDim2.new(0.52, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "Garage Types Picker (Autofarm):",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, afGarageHeader)

    local afSelectAllBtn = make("TextButton", {
        Size = UDim2.new(0.22, -4, 0, 20),
        Position = UDim2.new(0.52, 0, 0.5, -10),
        BackgroundColor3 = C.card,
        Text = "Select All",
        TextColor3 = C.accent,
        TextSize = 8,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, afGarageHeader)
    corner(4, afSelectAllBtn); stroke(1, C.border, afSelectAllBtn)

    local afResetBtn = make("TextButton", {
        Size = UDim2.new(0.26, 0, 0, 20),
        Position = UDim2.new(0.74, 0, 0.5, -10),
        BackgroundColor3 = C.card,
        Text = "↺ Restore Default",
        TextColor3 = C.gold,
        TextSize = 8,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, afGarageHeader)
    corner(4, afResetBtn); stroke(1, C.border, afResetBtn)

    local afGarageUpdaters = {}

    afSelectAllBtn.MouseButton1Click:Connect(function()
        for id, _ in pairs(GARAGE_CATALOG) do
            gConfig.afSelectedGarages[id] = true
        end
        for _, upd in ipairs(afGarageUpdaters) do upd() end
        saveConfig()
        afSelectAllBtn.Text = "Selected!"
        task.delay(1.2, function()
            if afSelectAllBtn and afSelectAllBtn.Parent then
                afSelectAllBtn.Text = "Select All"
            end
        end)
    end)

    afResetBtn.MouseButton1Click:Connect(function()
        for id, _ in pairs(GARAGE_CATALOG) do
            gConfig.afSelectedGarages[id] = false
        end
        for _, upd in ipairs(afGarageUpdaters) do upd() end
        saveConfig()
        afResetBtn.Text = "Restored!"
        task.delay(1.2, function()
            if afResetBtn and afResetBtn.Parent then
                afResetBtn.Text = "↺ Restore Default"
            end
        end)
    end)

    local afAreaOrder = {"Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
    local afAreaGarages = {}
    for _, a in ipairs(afAreaOrder) do afAreaGarages[a] = {} end
    for id, conf in pairs(GARAGE_CATALOG) do
        local area = conf.area
        if afAreaGarages[area] then
            table.insert(afAreaGarages[area], { id = id, conf = conf })
        end
    end
    for _, a in ipairs(afAreaOrder) do
        table.sort(afAreaGarages[a], function(x, y) return x.conf.tier < y.conf.tier end)
    end

    for _, areaName in ipairs(afAreaOrder) do
        local garageList = afAreaGarages[areaName]
        if #garageList > 0 then
            local isEventArea = false
            for _, entry in ipairs(garageList) do
                if entry.conf.event then isEventArea = true; break end
            end
            local headerText = "  " .. areaName .. (isEventArea and "  (Event)" or "")
            make("TextLabel", {
                Size = UDim2.new(1, 0, 0, 16),
                BackgroundTransparency = 1,
                Text = headerText,
                TextColor3 = C.accent,
                TextSize = 9,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
            }, tabAutofarm)

            local rowFrame = make("Frame", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
            }, tabAutofarm)
            local btnCount = #garageList
            local btnW = 1 / btnCount

            for i, entry in ipairs(garageList) do
                local gId = entry.id
                local gConf = entry.conf
                local isOn = (gConfig.afSelectedGarages[gId] == true)

                local gb = make("TextButton", {
                    Text = gConf.name, TextSize = 8, Font = Enum.Font.MontserratBold,
                    TextColor3 = isOn and C.text or C.text2,
                    BackgroundColor3 = isOn and gConf.col:Lerp(C.card, 0.55) or Color3.fromRGB(18, 20, 30),
                    Size = UDim2.new(btnW, -3, 1, 0), Position = UDim2.new(btnW * (i-1), 0, 0, 0),
                    AutoButtonColor = false, TextTruncate = Enum.TextTruncate.AtEnd
                }, rowFrame)
                corner(5, gb)
                local gbStroke = stroke(1, isOn and gConf.col:Lerp(Color3.fromRGB(0,0,0),0.3) or Color3.fromRGB(30, 35, 50), gb)

                local function updateVisual()
                    local nowOn = (gConfig.afSelectedGarages[gId] == true)
                    gb.BackgroundColor3 = nowOn and gConf.col:Lerp(C.card, 0.55) or Color3.fromRGB(18, 20, 30)
                    gb.TextColor3 = nowOn and C.text or C.text2
                    gbStroke.Color = nowOn and gConf.col:Lerp(Color3.fromRGB(0,0,0),0.3) or Color3.fromRGB(30, 35, 50)
                end
                table.insert(afGarageUpdaters, updateVisual)

                gb.MouseButton1Click:Connect(function()
                    gConfig.afSelectedGarages[gId] = not gConfig.afSelectedGarages[gId]
                    updateVisual()
                    saveConfig()
                end)
            end
        end
    end
    _G.afGarageUpdaters = afGarageUpdaters
end

do
    -- [Tractor] FARM TAB (STANDARD MANUAL CONTROLS & SEMI-AUTOFARM)
    local autoUnloadToggleCard, updateAutoUnloadToggle = createToggle(tabAuto, "Auto Unload on Full", gConfig.afAutoUnload, function(state)
        gConfig.afAutoUnload = state
        saveConfig()
        if updateAFUnloadToggle then pcall(updateAFUnloadToggle, state) end
    end)
    _G.uiToggles["afAutoUnload"] = function(state)
        if updateAFUnloadToggle then pcall(updateAFUnloadToggle, state) end
        if updateAutoUnloadToggle then pcall(updateAutoUnloadToggle, state) end
    end
    

    local manualUnloadBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C.card,
        Text = "Instant Remote Unload Trunk",
        TextColor3 = C.accent,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, tabAuto)
    corner(6, manualUnloadBtn)

    manualUnloadBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local vehicleId = LocalPlayer:GetAttribute("EquippedVehicle")
            if vehicleId and vehicleId ~= "" then
                local getItemsRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Vehicles"):FindFirstChild("GetVehicleItems")
                local transferRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Vehicles"):FindFirstChild("TransferVehicleItemsToInventory")
                if getItemsRemote and transferRemote then
                    local items = getItemsRemote:InvokeServer(vehicleId)
                    if items then
                        local guids = {}
                        for guid, _ in pairs(items) do
                            table.insert(guids, guid)
                        end
                        if #guids > 0 then
                            transferRemote:FireServer(guids)
                            showWorkshopPopup("Unloaded " .. #guids .. " items from truck!", C.green)
                        else
                            showWorkshopPopup("Truck is already empty!", COLORS.Orange)
                        end
                    end
                end
            else
                showWorkshopPopup("No vehicle spawned!", COLORS.Orange)
            end
        end)
    end)

    local asToggleCard, updateASToggle = createToggle(tabAuto, "Auto Place Store Items", gConfig.autoPlaceStoreItems, function(state)
        gConfig.autoPlaceStoreItems = state
        if _G.uiToggles["autoPlaceStoreItems"] then pcall(_G.uiToggles["autoPlaceStoreItems"], state) end
        saveConfig()
    end)
    
    local dnToggleCard, updateDNToggle = createToggle(tabAuto, "Disable Game Notifications", gConfig.disableGameNotifications, function(state)
        gConfig.disableGameNotifications = state
        saveConfig()
        pcall(function()
            local toasts = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("ToastsGui")
            if toasts then toasts.Enabled = not state end
        end)
        if updateAF_DNToggleRef then pcall(updateAF_DNToggleRef, state) end
    end)
    updateDNToggleRef = updateDNToggle
    
    local muteSoundCard, updateMuteSound = createToggle(tabAuto, "Mute Shelf Sounds (Place/Pick)", gConfig.mutePlacingSounds, function(state)
        gConfig.mutePlacingSounds = state
        saveConfig()
        if updateAF_MuteSoundRef then pcall(updateAF_MuteSoundRef, state) end
    end)
    updateMuteSoundRef = updateMuteSound
    

    local abToggleCard, updateABToggle = createToggle(tabAuto, "Semi Autofarm (AutoTP to Block)", gConfig.autoBuyStorages, function(state)
        gConfig.autoBuyStorages = state
        saveConfig()
        if animateNextButton then animateNextButton(state) end
    end)
    _G.uiToggles["autoBuyStorages"] = updateABToggle

    end

-- Target Area Dropdown Selector
local areaCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabAuto)
corner(6, areaCard)

make("TextLabel", {
    Size = UDim2.new(0.4, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Target Area:",
    TextColor3 = C.text,
    TextSize = 11,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, areaCard)

gConfig.autoBuyAreas = gConfig.autoBuyAreas or { ["Any Area"] = true }

local areaDropdownBtn = make("TextButton", {
    Size = UDim2.new(0, 120, 0, 26),
    Position = UDim2.new(1, -132, 0.5, -13),
    BackgroundColor3 = COLORS.BG,
    Text = "Any Area v",
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
}, areaCard)
corner(5, areaDropdownBtn); stroke(1, C.border, areaDropdownBtn)

local ddContainer = make("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    Visible = false,
}, tabAuto)
list(nil, 4, ddContainer)

local ddOpen = false
local areas = {"Any Area", "Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
local abBtns = {}

local function updateAbDropdownText()
    if gConfig.autoBuyAreas["Any Area"] then
        areaDropdownBtn.Text = "Any Area" .. (ddOpen and " ^" or " v")
        areaDropdownBtn.TextColor3 = C.gold
    else
        local selected = {}
        for _, area in ipairs(areas) do
            if area ~= "Any Area" and gConfig.autoBuyAreas[area] then
                table.insert(selected, area)
            end
        end
        if #selected == 0 then
            areaDropdownBtn.Text = "None" .. (ddOpen and " ^" or " v")
            areaDropdownBtn.TextColor3 = C.text2
        elseif #selected == 1 then
            areaDropdownBtn.Text = selected[1] .. (ddOpen and " ^" or " v")
            areaDropdownBtn.TextColor3 = C.gold
        else
            areaDropdownBtn.Text = "Multi (" .. #selected .. ")" .. (ddOpen and " ^" or " v")
            areaDropdownBtn.TextColor3 = C.gold
        end
    end
    for aName, btn in pairs(abBtns) do
        if gConfig.autoBuyAreas[aName] then
            btn.TextColor3 = C.gold
            btn.BackgroundColor3 = COLORS.BG
        else
            btn.TextColor3 = C.text2
            btn.BackgroundColor3 = C.card
        end
    end
end

areaDropdownBtn.MouseButton1Click:Connect(function()
    ddOpen = not ddOpen
    ddContainer.Visible = ddOpen
    updateAbDropdownText()
end)

for _, aName in ipairs(areas) do
    local abtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = C.card,
        Text = aName,
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratMedium,
        BorderSizePixel = 0,
    }, ddContainer)
    corner(4, abtn); stroke(1, C.border, abtn)
    abBtns[aName] = abtn
    
    abtn.MouseButton1Click:Connect(function()
        if aName == "Any Area" then
            gConfig.autoBuyAreas = { ["Any Area"] = true }
        else
            gConfig.autoBuyAreas["Any Area"] = nil
            gConfig.autoBuyAreas[aName] = not gConfig.autoBuyAreas[aName]
            
            local anyChecked = false
            for _, a in ipairs(areas) do
                if a ~= "Any Area" and gConfig.autoBuyAreas[a] then
                    anyChecked = true
                    break
                end
            end
            if not anyChecked then
                gConfig.autoBuyAreas = { ["Any Area"] = true }
            end
        end
        updateAbDropdownText()
        saveConfig()
    end)
end
updateAbDropdownText()
_G.uiUpdaters["autoBuyAreas"] = updateAbDropdownText

-- Garage Type Checklist Cards
local autoGarageHeader = make("Frame", {
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
}, tabAuto)

make("TextLabel", {
    Size = UDim2.new(0.52, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Garage Types Picker:",
    TextColor3 = C.text2,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, autoGarageHeader)

local autoSelectAllBtn = make("TextButton", {
    Size = UDim2.new(0.22, -4, 0, 20),
    Position = UDim2.new(0.52, 0, 0.5, -10),
    BackgroundColor3 = C.card,
    Text = "Select All",
    TextColor3 = C.accent,
    TextSize = 8,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, autoGarageHeader)
corner(4, autoSelectAllBtn); stroke(1, C.border, autoSelectAllBtn)

local autoResetBtn = make("TextButton", {
    Size = UDim2.new(0.26, 0, 0, 20),
    Position = UDim2.new(0.74, 0, 0.5, -10),
    BackgroundColor3 = C.card,
    Text = "↺ Restore Default",
    TextColor3 = C.gold,
    TextSize = 8,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, autoGarageHeader)
corner(4, autoResetBtn); stroke(1, C.border, autoResetBtn)

local autoGarageUpdaters = {}

autoSelectAllBtn.MouseButton1Click:Connect(function()
    for id, _ in pairs(GARAGE_CATALOG) do
        gConfig.selectedGarages[id] = true
    end
    for _, upd in ipairs(autoGarageUpdaters) do upd() end
    saveConfig()
    autoSelectAllBtn.Text = "Selected!"
    task.delay(1.2, function()
        if autoSelectAllBtn and autoSelectAllBtn.Parent then
            autoSelectAllBtn.Text = "Select All"
        end
    end)
end)

autoResetBtn.MouseButton1Click:Connect(function()
    for id, _ in pairs(GARAGE_CATALOG) do
        gConfig.selectedGarages[id] = false
    end
    for _, upd in ipairs(autoGarageUpdaters) do upd() end
    saveConfig()
    autoResetBtn.Text = "Restored!"
    task.delay(1.2, function()
        if autoResetBtn and autoResetBtn.Parent then
            autoResetBtn.Text = "↺ Restore Default"
        end
    end)
end)

local areaOrder = {"Junk Yard", "Back Alley", "Farmyard", "Shipyard", "Lucky Beach", "Power Plant", "Cargo Ship", "Business Bay", "The Mines", "Cargo Train", "Military Base"}
local areaGarages = {}
for _, a in ipairs(areaOrder) do areaGarages[a] = {} end
for id, conf in pairs(GARAGE_CATALOG) do
    local area = conf.area
    if areaGarages[area] then
        table.insert(areaGarages[area], { id = id, conf = conf })
    end
end
for _, a in ipairs(areaOrder) do
    table.sort(areaGarages[a], function(x, y) return x.conf.tier < y.conf.tier end)
end

for _, areaName in ipairs(areaOrder) do
    local garageList = areaGarages[areaName]
    if #garageList > 0 then
        local isEventArea = false
        for _, entry in ipairs(garageList) do
            if entry.conf.event then isEventArea = true; break end
        end
        local headerText = "  " .. areaName .. (isEventArea and "  (Event)" or "")
        local sectionHeader = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = headerText,
            TextColor3 = C.accent,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, tabAuto)

        local rowFrame = make("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
        }, tabAuto)
        local btnCount = #garageList
        local btnW = 1 / btnCount

        for i, entry in ipairs(garageList) do
            local gId = entry.id
            local gConf = entry.conf
            local isOn = (gConfig.selectedGarages[gId] == true)

            local gb = make("TextButton", {
                Text = gConf.name, TextSize = 8, Font = Enum.Font.MontserratBold,
                TextColor3 = isOn and C.text or C.text2,
                BackgroundColor3 = isOn and gConf.col:Lerp(C.card, 0.55) or Color3.fromRGB(18, 20, 30),
                Size = UDim2.new(btnW, -3, 1, 0), Position = UDim2.new(btnW * (i-1), 0, 0, 0),
                AutoButtonColor = false, TextTruncate = Enum.TextTruncate.AtEnd
            }, rowFrame)
            corner(5, gb)
            local gbStroke = stroke(1, isOn and gConf.col:Lerp(Color3.fromRGB(0,0,0),0.3) or Color3.fromRGB(30, 35, 50), gb)

            local function updateVisual()
                local nowOn = (gConfig.selectedGarages[gId] == true)
                gb.BackgroundColor3 = nowOn and gConf.col:Lerp(C.card, 0.55) or Color3.fromRGB(18, 20, 30)
                gb.TextColor3 = nowOn and C.text or C.text2
                gbStroke.Color = nowOn and gConf.col:Lerp(Color3.fromRGB(0,0,0),0.3) or Color3.fromRGB(30, 35, 50)
            end
            table.insert(autoGarageUpdaters, updateVisual)

            gb.MouseButton1Click:Connect(function()
                gConfig.selectedGarages[gId] = not gConfig.selectedGarages[gId]
                updateVisual()
                saveConfig()
            end)
        end
    end
    _G.autoGarageUpdaters = autoGarageUpdaters
end


-- WORKSHOPS TAB
local selectedItems = { Wash=nil, Repair=nil, Grading=nil, Locksmith=nil }
local activeTimersList = {} 
local function getShopRemote(shopName, remoteName)
    local ev = ReplicatedStorage:FindFirstChild("Events") or ReplicatedStorage:WaitForChild("Events", 5)
    if not ev then return nil end
    local shopFolder = ev:FindFirstChild(shopName) or ev:WaitForChild(shopName, 5)
    if not shopFolder then return nil end
    return shopFolder:FindFirstChild(remoteName) or shopFolder:WaitForChild(remoteName, 5)
end

local function invokeShopRemote(shopName, remoteName, ...)
    local remote = getShopRemote(shopName, remoteName)
    if not remote then error("Remote not found: " .. tostring(shopName) .. "." .. tostring(remoteName)) end
    return remote:InvokeServer(...)
end

local SHOPS = {
    Wash = {
        title = "Wash Station", itemLabel = "Dirty Items", itemEmpty = "No dirty items to wash", maxSlots = 3,
        getEligible = function() return invokeShopRemote("Wash", "GetWashableItems") end,
        getSlots    = function() return invokeShopRemote("Wash", "GetSlotState") end,
        startWork   = function(slot, guid, src, vguid) return invokeShopRemote("Wash", "StartWash", slot, guid, src, vguid) end,
        claimWork   = function(slot) return invokeShopRemote("Wash", "ClaimWashedItem", slot) end,
        unlockSlot  = function(slot) return invokeShopRemote("Wash", "UnlockSlot", slot) end,
        speedUp     = function(slot) return invokeShopRemote("Wash", "SpeedUpWash", slot) end,
    },
    Repair = {
        title = "Repair Shop", itemLabel = "Broken Items", itemEmpty = "No broken items to repair", maxSlots = 3,
        getEligible = function() return invokeShopRemote("Repair", "GetRepairableItems") end,
        getSlots    = function() return invokeShopRemote("Repair", "GetSlotState") end,
        startWork   = function(slot, guid, src, vguid) return invokeShopRemote("Repair", "StartRepair", slot, guid, src, vguid) end,
        claimWork   = function(slot) return invokeShopRemote("Repair", "ClaimRepairedItem", slot) end,
        unlockSlot  = function(slot) return invokeShopRemote("Repair", "UnlockSlot", slot) end,
        speedUp     = function(slot) return invokeShopRemote("Repair", "SpeedUpRepair", slot) end,
    },
    Grading = {
        title = "Grading Office", itemLabel = "Ungraded Items", itemEmpty = "No items to grade", maxSlots = 3,
        getEligible = function() return invokeShopRemote("Grading", "GetGradableItems") end,
        getSlots    = function() return invokeShopRemote("Grading", "GetSlotState") end,
        startWork   = function(slot, guid, src, vguid) return invokeShopRemote("Grading", "StartGrading", slot, guid, src, vguid) end,
        claimWork   = function(slot) return invokeShopRemote("Grading", "ClaimGradedItem", slot) end,
        unlockSlot  = function(slot) return invokeShopRemote("Grading", "UnlockSlot", slot) end,
        speedUp     = function(slot) return invokeShopRemote("Grading", "SpeedUpGrading", slot) end,
        collect     = function(slot) return invokeShopRemote("Grading", "CollectGrade", slot) end,
    },
    Locksmith = {
        title = "Locksmith Desk", itemLabel = "Locked Safes", itemEmpty = "No locked safes", maxSlots = 3,
        getEligible = function() return invokeShopRemote("Locksmith", "GetLockableItems") end,
        getSlots    = function() return invokeShopRemote("Locksmith", "GetSlotState") end,
        startWork   = function(slot, guid, src, vguid) return invokeShopRemote("Locksmith", "StartLocksmith", slot, guid, src, vguid) end,
        claimWork   = function(slot)
            task.wait(0.5)
            local lastRes, lastOk
            for attempt = 1, 3 do
                lastOk, lastRes = pcall(function() return invokeShopRemote("Locksmith", "ClaimItem", slot) end)
                if lastOk and lastRes then break end
                if attempt < 3 then task.wait(0.8) end
            end
            if lastOk then return lastRes else error(lastRes) end
        end,
        unlockSlot  = function(slot) return invokeShopRemote("Locksmith", "UnlockSlot", slot) end,
        speedUp     = function(slot) return invokeShopRemote("Locksmith", "SpeedUp", slot) end,
        openSafe    = function(slot) return invokeShopRemote("Locksmith", "OpenSafe", slot) end,
    }
}

local activeShopKey = "Wash"
local updateAFPlaceToggle = nil
local updateASToggle = nil

showWorkshopPopup = function(text, color)
    local col = color or C.gold
    local popup = make("TextLabel", {
        Text = text, TextSize = 12, Font = Enum.Font.MontserratBold, TextColor3 = col,
        BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.05, Size = UDim2.new(0, 320, 0, 44),
        Position = UDim2.new(0.5, -160, 0.5, -22), ZIndex = 500, TextWrapped = true
    }, Win)
    corner(8, popup); stroke(2, col, popup)
    
    tw(popup, 0.3, { Position = UDim2.new(0.5, -160, 0.5, -45) })
    task.delay(3.5, function()
        tw(popup, 0.5, { Position = UDim2.new(0.5, -160, 0.5, -85), TextTransparency = 1, BackgroundTransparency = 1 })
        task.delay(0.5, function() pcall(function() popup:Destroy() end) end)
    end)
end

local function formatSafeClaimResult(res)
    if type(res) ~= "table" then return "Safe Opened & Claimed!" end
    
    local itemNames = {}
    local cash = res.Cash or res.Money or res.CashReward or 0
    local diamonds = res.Diamonds or res.Gems or res.DiamondReward or 0
    
    local function parseItem(it)
        if type(it) ~= "table" then return end
        local itemId = it.ItemId or it.Id or it.itemId
        local name = it.Name or it.DisplayName
        if not name and itemId then
            local n = getItemData(itemId)
            name = n
        end
        if name and name ~= "Unknown" then
            local mut = it.Mutator or it.Mutation or it.CleanMutation
            local grade = it.Grade or it.Stars
            local tag = name
            if mut and mut ~= "None" and mut ~= "" then tag = tag .. " [" .. tostring(mut) .. "]" end
            if grade and tonumber(grade) and tonumber(grade) > 0 then tag = tag .. " (" .. tostring(grade) .. "*)" end
            table.insert(itemNames, tag)
        end
    end

    if res.Item then parseItem(res.Item) end
    if res.Items and type(res.Items) == "table" then
        for _, it in pairs(res.Items) do parseItem(it) end
    end
    if res.AwardedItem then parseItem(res.AwardedItem) end
    if res.AwardedItems and type(res.AwardedItems) == "table" then
        for _, it in pairs(res.AwardedItems) do parseItem(it) end
    end
    parseItem(res)

    local details = {}
    if #itemNames > 0 then
        table.insert(details, table.concat(itemNames, ", "))
    end
    if cash > 0 then
        table.insert(details, "+$" .. tostring(cash))
    end
    if diamonds > 0 then
        table.insert(details, "+" .. tostring(diamonds) .. " Diamonds")
    end

    if #details > 0 then
        return table.concat(details, " | ")
    else
        return "Safe Opened & Claimed!"
    end
end

local function showConfirmDialog(title, message, onConfirm)
    if not Win then return end
    
    local existing = Win:FindFirstChild("ConfirmModalOverlay")
    if existing then existing:Destroy() end

    local overlay = make("TextButton", {
        Name = "ConfirmModalOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.4,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 500,
    }, Win)
    corner(8, overlay)

    local dialog = make("Frame", {
        Size = UDim2.new(0, 270, 0, 125),
        Position = UDim2.new(0.5, -135, 0.5, -62),
        BackgroundColor3 = COLORS.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 501,
    }, overlay)
    corner(8, dialog); stroke(1.5, COLORS.Purple, dialog)

    make("TextLabel", {
        Size = UDim2.new(1, -20, 0, 22),
        Position = UDim2.new(0, 10, 0, 10),
        BackgroundTransparency = 1,
        Text = title or "Confirm Action",
        TextColor3 = COLORS.Purple,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 502,
    }, dialog)

    make("TextLabel", {
        Size = UDim2.new(1, -24, 0, 38),
        Position = UDim2.new(0, 12, 0, 34),
        BackgroundTransparency = 1,
        Text = message or "Are you sure you want to speed up / skip this timer?",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratMedium,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 502,
    }, dialog)

    -- Cancel Button
    local cancelBtn = make("TextButton", {
        Size = UDim2.new(0.44, 0, 0, 26),
        Position = UDim2.new(0.04, 0, 1, -34),
        BackgroundColor3 = C.card,
        Text = "Cancel",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = true,
        BorderSizePixel = 0,
        ZIndex = 502,
    }, dialog)
    corner(5, cancelBtn); stroke(1, C.border, cancelBtn)

    -- Confirm Button
    local confirmBtn = make("TextButton", {
        Size = UDim2.new(0.44, 0, 0, 26),
        Position = UDim2.new(0.52, 0, 1, -34),
        BackgroundColor3 = COLORS.Purple,
        Text = "Confirm Skip",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        AutoButtonColor = true,
        BorderSizePixel = 0,
        ZIndex = 502,
    }, dialog)
    corner(5, confirmBtn)

    cancelBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        overlay:Destroy()
        if onConfirm then
            onConfirm()
        end
    end)
end

-- Populate Teleports Tab
do
    -- Section: Quick Travel & Cursor TP
    local labelQuickTravel = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Quick Travel & Cursor TP ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    local clickTpCard, updateClickTpToggle = createToggle(tabTeleports, "Click Teleport (Ctrl + Click)", gConfig.clickTpEnabled or false, function(state)
        gConfig.clickTpEnabled = state
        saveConfig()
        if state then
            showWorkshopPopup("Click TP Armed: Hold Left-Ctrl and click anywhere!", C.green)
        end
    end)
    _G.uiToggles["clickTpEnabled"] = updateClickTpToggle

    local tpNavCard, updateTpNavToggle = createToggle(tabTeleports, "Instant TP on Navigate (N) Click", gConfig.tpOnNavigate or false, function(state)
        gConfig.tpOnNavigate = state
        saveConfig()
        if state then
            showWorkshopPopup("Navigate TP Armed: Click any NPC or location in (N) to teleport!", C.green)
        end
    end)
    _G.uiToggles["tpOnNavigate"] = updateTpNavToggle

    local function getActiveNavDestinationCF(waitForTrail)
        local deadline = waitForTrail and (os.clock() + 0.65) or os.clock()
        repeat
            local anchor = workspace:FindFirstChild("GPSTrailAnchor")
            if anchor then
                local atts = anchor:GetChildren()
                local maxIdx = -1
                local lastAtt = nil
                for _, a in ipairs(atts) do
                    if a:IsA("Attachment") then
                        local num = tonumber(a.Name:match("%d+")) or 0
                        if num >= maxIdx then
                            maxIdx = num
                            lastAtt = a
                        end
                    end
                end
                if lastAtt and (not waitForTrail or #atts >= 2) then
                    return CFrame.new(lastAtt.WorldPosition)
                end
            end
            if waitForTrail and os.clock() < deadline then
                task.wait(0.04)
            end
        until not waitForTrail or os.clock() >= deadline

        -- 2. Try LocalPlayer GPSDestination attribute
        local destName = LocalPlayer:GetAttribute("GPSDestination")
        if destName and destName ~= "" then
            -- Check workspace.Areas first (supports both Models and Folders)
            if workspace:FindFirstChild("Areas") then
                local areaInst = workspace.Areas:FindFirstChild(destName)
                if areaInst then
                    if areaInst:IsA("Model") then
                        return areaInst:GetPivot()
                    else
                        local p = areaInst:FindFirstChildWhichIsA("BasePart", true)
                        if p then return p.CFrame + Vector3.new(0, 4, 0) end
                    end
                end
            end

            -- Check NPCs in workspace (CollectionService or NPCs folder)
            local cs = game:GetService("CollectionService")
            for _, npc in ipairs(cs:GetTagged("NPC")) do
                if npc.Name == destName or npc:GetAttribute("DisplayName") == destName then
                    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart")
                    if hrp then return hrp.CFrame end
                end
            end
            local npcsFolder = workspace:FindFirstChild("NPCs")
            if npcsFolder then
                local npc = npcsFolder:FindFirstChild(destName)
                if npc then
                    local cf = npc:IsA("Model") and npc:GetPivot() or (npc:IsA("BasePart") and npc.CFrame)
                    if cf then return cf end
                end
            end

            -- Check POIs from GPS remote (parse position string properly)
            local pPos = nil
            pcall(function()
                local res = game:GetService("ReplicatedStorage").Events.GPS.GetPOIs:InvokeServer()
                if res and res.pois then
                    for _, p in ipairs(res.pois) do
                        if p.Name == destName or p.name == destName then
                            local raw = p.position or p.Position
                            if type(raw) == "string" then
                                local x, y, z = raw:match("([%d%.%-]+)%s*,%s*([%d%.%-]+)%s*,%s*([%d%.%-]+)")
                                if x and y and z then
                                    pPos = Vector3.new(tonumber(x), tonumber(y), tonumber(z))
                                    break
                                end
                            elseif typeof(raw) == "Vector3" then
                                pPos = raw
                                break
                            end
                        end
                    end
                end
            end)
            if pPos then
                return CFrame.new(pPos)
            end
        end
        return nil
    end
    _G.getActiveNavDestinationCF = getActiveNavDestinationCF

    local _navTpToken = 0
    LocalPlayer:GetAttributeChangedSignal("GPSDestination"):Connect(function()
        if not gConfig.tpOnNavigate then return end
        local destName = LocalPlayer:GetAttribute("GPSDestination")
        if not destName or destName == "" then return end
        _navTpToken = _navTpToken + 1
        local myToken = _navTpToken
        task.spawn(function()
            task.wait(0.08)
            if myToken ~= _navTpToken or not gConfig.tpOnNavigate then return end
            local destCF = getActiveNavDestinationCF(true)
            if destCF and myToken == _navTpToken and gConfig.tpOnNavigate then
                safeTP(destCF, true)
                showWorkshopPopup("Teleported to: " .. tostring(destName), C.green)
                abLog("[GPS] Instant TP on Navigate click: " .. tostring(destName), C.green)
            end
        end)
    end)

    createButton(tabTeleports, "Teleport to Current GPS Destination", function()
        local destCF = getActiveNavDestinationCF()
        if destCF then
            safeTP(destCF, true)
            showWorkshopPopup("Teleported to GPS Destination!", C.green)
            abLog("[GPS] Teleported to GPS Destination!", C.green)
        else
            showWorkshopPopup("No active GPS destination set! (Press N to select one)", C.orange)
        end
    end)

    -- UserInputService listeners for Click TP and Navigate (N) TP
    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        -- Click Teleport (Ctrl + Click)
        -- Rule: If on foot -> ONLY teleport on foot (no car). If seated -> teleport car & player WHILE seated/driving!
        if gConfig.clickTpEnabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                local mouse = LocalPlayer:GetMouse()
                if mouse and mouse.Hit then
                    local clickPos = mouse.Hit.Position
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if root and hum and hum.Health > 0 then
                        local seat = hum.SeatPart
                        local isDriving = (hum.Sit == true) and (seat ~= nil) and (seat:IsA("VehicleSeat") or seat.Name == "DriveSeat" or seat:IsA("Seat"))
                        local vehicle = isDriving and seat:FindFirstAncestorWhichIsA("Model")

                        if isDriving and vehicle then
                            -- Seated in car: Teleport vehicle WITH player smoothly, keeping player seated/driving!
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = { char, vehicle }
                            rayParams.RespectCanCollide = true

                            local rayHit = workspace:Raycast(clickPos + Vector3.new(0, 30, 0), Vector3.new(0, -70, 0), rayParams)
                            local groundY = rayHit and rayHit.Position.Y or clickPos.Y

                            local vCF, vSize = vehicle:GetBoundingBox()
                            local vPivot = vehicle:GetPivot()
                            local pivotBottomOffset = math.max(0.5, vPivot.Position.Y - (vCF.Position.Y - vSize.Y / 2))
                            local targetPos = Vector3.new(clickPos.X, groundY + pivotBottomOffset + 0.4, clickPos.Z)
                            local targetCF = CFrame.new(targetPos) * vPivot.Rotation

                            -- Move vehicle model (SeatWeld naturally carries seated player without breaking)
                            vehicle:PivotTo(targetCF)

                            -- Zero out physics velocities so vehicle lands smoothly on all wheels with no bouncing or flinging
                            for _, part in ipairs(vehicle:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.AssemblyLinearVelocity = Vector3.zero
                                    part.AssemblyAngularVelocity = Vector3.zero
                                end
                            end

                            -- DO NOT touch root.CFrame! Touching root.CFrame breaks Roblox SeatWeld.
                            -- Ensure player stays seated:
                            if not hum.Sit or hum.SeatPart ~= seat then
                                pcall(function() seat:Sit(hum) end)
                            end
                            showWorkshopPopup("Teleported vehicle to cursor!", C.green)
                        else
                            -- On foot: ONLY teleport player on foot! ZERO vehicle interaction!
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = { char }
                            rayParams.RespectCanCollide = true

                            local rayHit = workspace:Raycast(clickPos + Vector3.new(0, 20, 0), Vector3.new(0, -50, 0), rayParams)
                            local groundY = rayHit and rayHit.Position.Y or clickPos.Y
                            local targetPos = Vector3.new(clickPos.X, groundY + 3.0, clickPos.Z)

                            hum:ChangeState(Enum.HumanoidStateType.Running)
                            if hum.PlatformStand then hum.PlatformStand = false end

                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            root.CFrame = CFrame.new(targetPos)
                            root.AssemblyLinearVelocity = Vector3.zero
                            root.AssemblyAngularVelocity = Vector3.zero
                            showWorkshopPopup("Teleported to cursor!", C.green)
                        end
                    end
                end
            end
        end

        -- Instant TP on Navigate (N) is handled via LocalPlayer:GetAttributeChangedSignal("GPSDestination") upon clicking any NPC or POI in the menu.
    end)

    -- Section: Player Plot
    local labelPlot = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Plot Teleports ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    createButton(tabTeleports, "Teleport to Your Plot (Driveway)", function()
        local targetCF = getMyLivePlotDrivewayCF()
        if targetCF then
            safeTP(targetCF + Vector3.new(0, 1.5, 0), true)
            return
        end
        showWorkshopPopup("Your plot driveway was not found!", COLORS.Orange)
    end)

    createButton(tabTeleports, "Save Current Plot as Pit-Stop", function()
        local liveCF = getMyLivePlotDrivewayCF()
        local char = game:GetService("Players").LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local targetCF = liveCF or (root and root.CFrame)
        if targetCF then
            gConfig.savedPlotDriveway = targetCF
            cachedMyPlotCF = targetCF
            _G.AHScanner_UnpackCF = targetCF
            saveConfig()
            showWorkshopPopup("Saved plot location for Auto-Place Pit-Stop!", C.green)
            abLog("Saved plot driveway for auto-place Pit-Stop!", C.green)
        else
            showWorkshopPopup("Could not determine plot location!", COLORS.Orange)
        end
    end)

    -- Section: Specific Plots (Live dynamic server resolution with StreamingEnabled support)
    for i = 1, 9 do
        createButton(tabTeleports, "Teleport to Plot " .. i, function()
            updatePlotCache()
            if cachedPlotCFrames[i] then
                safeTP(cachedPlotCFrames[i])
                return
            end

            -- If streamed out, request stream from server
            pcall(function()
                if LocalPlayer.RequestStreamAroundAsync then
                    LocalPlayer:RequestStreamAroundAsync(Vector3.new(389, 1724, -177))
                    task.wait(0.25)
                    updatePlotCache()
                end
            end)

            if cachedPlotCFrames[i] then
                safeTP(cachedPlotCFrames[i])
                return
            end

            local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
            local targetPlot = plots and (plots:FindFirstChild("Plot" .. i) or plots:FindFirstChild("Plot_" .. i))
            if targetPlot then
                local frontCF = resolvePlotDrivewayCF(targetPlot)
                if frontCF then
                    cachedPlotCFrames[i] = frontCF
                    safeTP(frontCF)
                    return
                end
            end

            showWorkshopPopup("Plot " .. i .. " is streaming in... please tap again in a second!", COLORS.Orange)
        end)
    end

    -- Section: Shops & Workshops
    local labelShops = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Shops & Workshops ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    createButton(tabTeleports, "Teleport to Shopping Mall", function()
        safeTP(CFrame.new(389.567902, 1724.33215, -177.070374))
    end)

    createButton(tabTeleports, "Teleport to Museum", function()
        safeTP(CFrame.new(540.99, 1728.87, -188.22))
    end)

    createButton(tabTeleports, "Teleport to Time Capsule", function()
        safeTP(CFrame.new(576.34, 1726, -494.82))
    end)

    createButton(tabTeleports, "Teleport to Fisherman NPC", function()
        local npc = workspace:FindFirstChild("Fisherman", true)
        if npc then
            safeTP(npc:GetPivot() * CFrame.new(0, 0, -4))
        else
            showWorkshopPopup("Fisherman NPC not found!", COLORS.Orange)
        end
    end)

    createButton(tabTeleports, "Teleport to Car Shop", function()
        safeTP(CFrame.new(-260.20, 1722.70, -188.38))
    end)

    createButton(tabTeleports, "Teleport to Car Customise", function()
        safeTP(CFrame.new(-83.41, 1722.72, 198.10))
    end)

    createButton(tabTeleports, "Teleport to Trailer Store", function()
        safeTP(CFrame.new(500.05, 1722.93, -1339.44))
    end)

    -- Section: General Map
    local labelMap = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Map Locations ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    createButton(tabTeleports, "Teleport to Junkyard (Scrap Yard)", function()
        local junk = workspace:FindFirstChild("Junk Yard", true)
        local part = junk and junk:FindFirstChildWhichIsA("BasePart", true)
        if part then
            safeTP(part.CFrame + Vector3.new(0, 5, 0))
        else
            showWorkshopPopup("Junk Yard area not found!", COLORS.Orange)
        end
    end)

    createButton(tabTeleports, "Teleport to Cargo Ship (Ocean Port)", function()
        safeTP(CFrame.new(-818.9, 1728.5, 613.5))
    end)

    createButton(tabTeleports, "Teleport to Power Plant", function()
        safeTP(CFrame.new(-2602.4936523438, 1724.6275634766, -380.77655029297, 0.99528682231903, -2.9826278336031e-08, 0.096974745392799, 2.4705149925808e-08, 1, 5.4009596794913e-08, -0.096974745392799, -5.13592652851e-08, 0.99528682231903))
    end)

    createButton(tabTeleports, "Teleport to Farmyard", function()
        safeTP(CFrame.new(-74.63, 1722.76, -1144.25))
    end)

    createButton(tabTeleports, "Teleport to Back Alley", function()
        safeTP(CFrame.new(-568.35, 1722.70, -407.34))
    end)

    createButton(tabTeleports, "Teleport to Lucky Beach", function()
        safeTP(CFrame.new(-235.67, 1700.17, -1812.51))
    end)

    createButton(tabTeleports, "Teleport to Shipyard", function()
        safeTP(CFrame.new(-582.84, 1722.72, 638.91))
    end)

    createButton(tabTeleports, "Teleport to Business Bay", function()
        safeTP(CFrame.new(1988.124, 1725.362, -3935.040, 0.117291, 0.023766, -0.992813, 0.001858, 0.999707, 0.024150, 0.993096, -0.004677, 0.117213))
    end)

    createButton(tabTeleports, "Teleport to Michael NPC", function()
        local michael = workspace:FindFirstChild("Michael", true)
        local hrp = michael and (michael:FindFirstChild("HumanoidRootPart") or michael:FindFirstChildWhichIsA("BasePart", true))
        if hrp then
            safeTP(hrp.CFrame + Vector3.new(0, 2, 4))
        else
            showWorkshopPopup("Michael NPC not found!", COLORS.Orange)
        end
    end)

    createButton(tabTeleports, "Teleport to Cargo Train (Ship Yard)", function()
        safeTP(CFrame.new(-422.0, 1731.0, 952.0))
    end)

    createButton(tabTeleports, "Teleport to Train Conductor", function()
        safeTP(CFrame.new(-419.4, 1731.5, 951.5))
    end)

    createButton(tabTeleports, "Teleport to The Mines (Entrance)", function()
        safeTP(CFrame.new(-3180.3327636719, 1578.5046386719, -1912.7799072266, 0.99691742658615, -3.3501412755044e-10, 0.078457601368427, -7.1600551876383e-11, 1, 5.1797908184881e-09, -0.078457601368427, -5.1694413194525e-09, 0.99691742658615))
    end)

    createButton(tabTeleports, "Teleport to Mining Supervisor", function()
        local sup = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("The Mines") and workspace.Areas["The Mines"]:FindFirstChild("Mining Supervisor")
        if sup then
            local p = sup:GetPivot().Position
            safeTP(CFrame.lookAt(p + (sup:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
        else
            safeTP(CFrame.new(-3161.2, 1578.0, -1950.0))
        end
    end)

    -- Section: Military Base
    local labelMilitary = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Military Base ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    createButton(tabTeleports, "Teleport to Military Base (Gate)", function()
        safeTP(CFrame.new(813.6, 1721.0, -5135.0))
    end)

    createButton(tabTeleports, "Teleport to Military Base (Courtyard)", function()
        safeTP(CFrame.new(415.0, 1797.5, -5450.0))
    end)

    createButton(tabTeleports, "Teleport to General Commander", function()
        local npc = workspace:FindFirstChild("Areas") and workspace.Areas:FindFirstChild("Military Base") and workspace.Areas["Military Base"]:FindFirstChild("General Commander")
        if npc then
            local p = npc:GetPivot().Position
            safeTP(CFrame.lookAt(p + (npc:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
        else
            safeTP(CFrame.new(350.7, 1797.6, -5515.7))
        end
    end)

    createButton(tabTeleports, "Teleport to Soldier NPC (Gate)", function()
        local npc = workspace:FindFirstChild("Soldier", true)
        if npc then
            local p = npc:GetPivot().Position
            safeTP(CFrame.lookAt(p + (npc:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
        else
            safeTP(CFrame.new(813.6, 1720.9, -5135.0))
        end
    end)

    createButton(tabTeleports, "Teleport to Secret Service NPC", function()
        local npc = workspace:FindFirstChild("Secret Service", true)
        if npc then
            local p = npc:GetPivot().Position
            safeTP(CFrame.lookAt(p + (npc:GetPivot().LookVector * 4) + Vector3.new(0, 0.5, 0), p))
        else
            safeTP(CFrame.new(373.7, 1724.2, -5469.2))
        end
    end)

    createButton(tabTeleports, "Teleport to Nearest Camo Airdrop", function()
        if _G.teleportToNearestCamoAirdrop then
            _G.teleportToNearestCamoAirdrop()
        end
    end)

    -- Section: Carnival
    local labelCarnival = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        Text = "── Carnival ──",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, tabTeleports)

    createButton(tabTeleports, "Teleport to Carnival Hub", function()
        safeTP(CFrame.new(263.5, 1722.0, -1975.5))
    end)


end

-- Horizontal list of workshop type selector buttons
-- NOTE: shopSelector sits inside tabWorkshop which has pad(4) = 4px on all sides.
-- So shopSelector width = tabWidth - 8px. Buttons use UDim2 scale so they fill correctly.
local shopSelector = make("Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    ClipsDescendants = false,
}, tabWorkshop)
-- Use UIListLayout horizontal so buttons auto-fill without clipping
local shopLayout = list(Enum.HorizontalAlignment.Left, 4, shopSelector)
shopLayout.FillDirection = Enum.FillDirection.Horizontal

local shopBtns = {}
local function setShopType(key)
    activeShopKey = key
    for k, btn in pairs(shopBtns) do
        local active = (k == key)
        tw(btn, 0.15, { BackgroundColor3 = active and COLORS.TabBtnActive or C.card, TextColor3 = active and C.accent or C.text2 })
    end
    renderWorkshop(key)
end

local shopNames = {"Wash", "Repair", "Grading", "Locksmith", "Auto"}
for _, name in ipairs(shopNames) do
    local btn = make("TextButton", {
        Size = UDim2.new(0.2, -3, 1, 0),
        BackgroundColor3 = C.card,
        Text = name,
        TextColor3 = C.text2,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    }, shopSelector)
    corner(5, btn); stroke(1, C.border, btn)
    btn.MouseButton1Click:Connect(function() setShopType(name) end)
    shopBtns[name] = btn
end

-- Workspace split columns
local splitContainer = make("Frame", {
    Size = UDim2.new(1, 0, 0, 260),
    BackgroundTransparency = 1,
}, tabWorkshop)

local leftCol = make("ScrollingFrame", {
    Size = UDim2.new(0.46, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, splitContainer)
list(nil, 6, leftCol)

local rightCol = make("ScrollingFrame", {
    Size = UDim2.new(0.54, -4, 1, 0),
    Position = UDim2.new(0.46, 4, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    ScrollBarImageColor3 = C.accent,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, splitContainer)
list(nil, 6, rightCol)

local currentWorkshopRenderID = 0
function renderWorkshop(shopKey)
    currentWorkshopRenderID = currentWorkshopRenderID + 1
    local myRenderID = currentWorkshopRenderID

    if shopKey == "Auto" then
        leftCol.Size = UDim2.new(0.56, 0, 1, 0)
        rightCol.Size = UDim2.new(0.44, -4, 1, 0)
        rightCol.Position = UDim2.new(0.56, 4, 0, 0)
    else
        leftCol.Size = UDim2.new(0.46, 0, 1, 0)
        rightCol.Size = UDim2.new(0.54, -4, 1, 0)
        rightCol.Position = UDim2.new(0.46, 4, 0, 0)
    end
    for _, c in ipairs(leftCol:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
    for _, c in ipairs(rightCol:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
    activeTimersList = {}

    if shopKey == "Auto" then
        local awCard, updateAW = createToggle(leftCol, "Auto Wash Dirty Items", gConfig.autoWash, function(state)
            gConfig.autoWash = state
            saveConfig()
        end)
        _G.uiToggles["autoWash"] = updateAW

        local alCard, updateAL = createToggle(leftCol, "Auto Lockpick Safes", gConfig.autoLockpick, function(state)
            gConfig.autoLockpick = state
            saveConfig()
        end)
        _G.uiToggles["autoLockpick"] = updateAL
        
        make("TextLabel", {
            Text = "Auto Workshops will automatically process items and safes in the background.",
            TextSize = 10,
            TextColor3 = C.text2,
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 80),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
        }, rightCol)
        return
    end
    
    local cfg = SHOPS[shopKey]
    if not cfg then return end

    local function refreshWorkshopView()
        if activeTab and activeTab.name == "Workshops" and activeShopKey == shopKey then
            renderWorkshop(shopKey)
        end
    end

    local leftLoading = make("TextLabel", {
        Text = "Loading " .. (cfg.itemLabel or "items") .. "...",
        TextSize = 9,
        TextColor3 = C.text2,
        Font = Enum.Font.MontserratMedium,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, leftCol)

    local rightLoading = make("TextLabel", {
        Text = "Loading slots...",
        TextSize = 9,
        TextColor3 = C.text2,
        Font = Enum.Font.MontserratMedium,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 30),
        TextXAlignment = Enum.TextXAlignment.Center,
    }, rightCol)

    -- Eligible Inventory items loading
    task.spawn(function()
        local ok, res = pcall(cfg.getEligible)
        if myRenderID ~= currentWorkshopRenderID then return end
        if leftLoading and leftLoading.Parent then leftLoading:Destroy() end
        if activeShopKey ~= shopKey then return end
        if not ok or not res or not res.items then 
            make("TextLabel", { Text = "Failed to load items.", TextSize = 9, TextColor3 = C.red, Font = Enum.Font.Montserrat, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20) }, leftCol)
            return 
        end
        local items = res.items
        if #items == 0 then 
            make("TextLabel", { Text = cfg.itemEmpty, TextSize = 8, TextColor3 = C.text2, Font = Enum.Font.Montserrat, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), TextWrapped = true }, leftCol)
            return 
        end
        
        local selectedStroke = nil
        for idx, item in ipairs(items) do
            local data = item.data
            local rawName = data.ItemId or "Unknown"
            local rar = data.Rarity or "Common"
            local mut = data.Mutator or "None"
            local grade = data.Grade or 0
            local cond = data.Condition or 100
            local realName, calcVal, finalRar = calcItemValue(rawName, rar, mut, grade, cond)
            
            local card = make("TextButton", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false }, leftCol)
            corner(5, card); local cStroke = stroke(1, C.border, card)
            
            make("TextLabel", { Text = realName, TextSize = 8, TextColor3 = C.text, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 2), Size = UDim2.new(1, -12, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, card)
            make("TextLabel", { Text = finalRar .. (mut ~= "None" and (" • " .. mut) or ""), TextSize = 7, TextColor3 = RARITY_COL[finalRar] or C.text2, Font = Enum.Font.MontserratMedium, BackgroundTransparency = 1, Position = UDim2.new(0, 6, 0, 14), Size = UDim2.new(1, -12, 0, 12), TextXAlignment = Enum.TextXAlignment.Left }, card)
            
            if selectedItems[shopKey] and selectedItems[shopKey].guid == item.guid then 
                cStroke.Color = C.accent
                cStroke.Thickness = 1.4
                selectedStroke = cStroke 
            end
            
            card.MouseButton1Click:Connect(function()
                if selectedStroke then selectedStroke.Color = C.border; selectedStroke.Thickness = 1 end
                cStroke.Color = C.accent; cStroke.Thickness = 1.4; selectedStroke = cStroke
                selectedItems[shopKey] = item
            end)
        end
    end)

    -- Shop Slots loading
    task.spawn(function()
        local ok, res = pcall(cfg.getSlots)
        if myRenderID ~= currentWorkshopRenderID then return end
        if rightLoading and rightLoading.Parent then rightLoading:Destroy() end
        if activeShopKey ~= shopKey then return end
        if not ok or not res then 
            make("TextLabel", { Text = "Failed to load slots.", TextSize = 9, TextColor3 = C.red, Font = Enum.Font.Montserrat, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20) }, rightCol)
            return 
        end
        
        local unlockedCount = res.unlockedCount or 1
        local slots = res.slots or {}
        
        for slotIndex = 1, cfg.maxSlots do
            local slotData = slots[tostring(slotIndex)] or slots[slotIndex] or slots[tonumber(slotIndex)]
            local card = make("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = C.card }, rightCol)
            corner(6, card); stroke(1, C.border, card)
            make("TextLabel", { Text = "Slot #" .. slotIndex, TextSize = 8, TextColor3 = C.text2, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 4), Size = UDim2.new(0.5, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Left }, card)
            
            if slotIndex > unlockedCount then
                make("TextLabel", { Text = "LOCKED", TextSize = 9, TextColor3 = C.red, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 20), Size = UDim2.new(0.5, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left }, card)
                local unlockBtn = make("TextButton", { Text = "Unlock", TextSize = 8, Font = Enum.Font.MontserratBold, TextColor3 = C.gold, BackgroundColor3 = C.card, Position = UDim2.new(0.6, 0, 0.5, -10), Size = UDim2.new(0.4, -6, 0, 20), AutoButtonColor = false }, card)
                corner(5, unlockBtn); stroke(1.2, C.gold, unlockBtn)
                unlockBtn.MouseButton1Click:Connect(function() 
                    task.spawn(function() 
                        pcall(function() 
                            if cfg.unlockSlot(slotIndex) then 
                                refreshWorkshopView() 
                            end 
                        end) 
                    end) 
                end)
            elseif not slotData then
                make("TextLabel", { Text = "EMPTY", TextSize = 9, TextColor3 = C.text2, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 20), Size = UDim2.new(0.5, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left }, card)
                local startBtn = make("TextButton", { Text = "Start", TextSize = 8, Font = Enum.Font.MontserratBold, TextColor3 = C.green, BackgroundColor3 = C.card, Position = UDim2.new(0.6, 0, 0.5, -10), Size = UDim2.new(0.4, -6, 0, 20), AutoButtonColor = false }, card)
                corner(5, startBtn); stroke(1.2, C.green, startBtn)
                startBtn.MouseButton1Click:Connect(function()
                    local chosen = selectedItems[shopKey]
                    if not chosen then return end
                    startBtn.Text = "Starting..."
                    task.spawn(function() 
                        pcall(function() 
                            local res = cfg.startWork(slotIndex, chosen.guid, chosen.source, chosen.vehicleGUID)
                            if res and res.success then 
                                selectedItems[shopKey] = nil
                                refreshWorkshopView() 
                            else 
                                startBtn.Text = "Start" 
                            end 
                        end) 
                    end)
                end)
            else
                local itemEntry = slotData.Item or slotData.ItemData or slotData.Entry or {}
                local rawItemName = itemEntry.ItemName or itemEntry.Name
                if not rawItemName and slotData.SafeId then
                    local safesModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Safes")
                    local sConf = safesModule and (pcall(require, safesModule) and require(safesModule))
                    local sData = sConf and (sConf[slotData.SafeId] or sConf[tonumber(slotData.SafeId)])
                    rawItemName = sData and sData.Name or ("Safe #" .. tostring(slotData.SafeId))
                end
                rawItemName = rawItemName or "Processing Item"
                local realItemName, _ = calcItemValue(rawItemName, "Common", "None", 0, 100)
                
                make("TextLabel", { Text = realItemName, TextSize = 9, TextColor3 = C.text, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 18), Size = UDim2.new(0.6, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, card)
                
                local elapsed = workspace:GetServerTimeNow() - (slotData.StartTime or workspace:GetServerTimeNow())
                local remaining = (slotData.Duration or 0) - elapsed
                
                if remaining > 0 and not slotData.Repaired and not slotData.Washed and not slotData.Grade and not slotData.Opened then
                    local tBarBg = make("Frame", { Size = UDim2.new(0.55, 0, 0, 4), Position = UDim2.new(0, 8, 0, 36), BackgroundColor3 = C.card, BorderSizePixel = 0 }, card); corner(2, tBarBg)
                    local tBarFill = make("Frame", { Size = UDim2.fromScale(math.clamp(elapsed / (slotData.Duration or 1), 0, 1), 1), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, tBarBg); corner(2, tBarFill)
                    local timeLbl = make("TextLabel", { Text = "0:00", TextSize = 9, TextColor3 = C.gold, Font = Enum.Font.MontserratBold, BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 44), Size = UDim2.new(0.55, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left }, card)
                    
                    table.insert(activeTimersList, { bar = tBarFill, lbl = timeLbl, startTime = slotData.StartTime or workspace:GetServerTimeNow(), duration = slotData.Duration or 30, card = card, onComplete = refreshWorkshopView })
                    
                    local skipBtn = make("TextButton", { Text = "Skip", TextSize = 8, Font = Enum.Font.MontserratBold, TextColor3 = COLORS.Purple, BackgroundColor3 = C.card, Position = UDim2.new(0.6, 0, 0.5, -10), Size = UDim2.new(0.4, -6, 0, 20), AutoButtonColor = false }, card)
                    corner(5, skipBtn); stroke(1.2, COLORS.Purple, skipBtn)
                    skipBtn.MouseButton1Click:Connect(function() 
                        showConfirmDialog(
                            "[Warning] Skip Workshop Timer",
                            "Are you sure you want to speed up " .. shopKey .. " Slot #" .. tostring(slotIndex) .. "?",
                            function()
                                task.spawn(function() 
                                    pcall(function() cfg.speedUp(slotIndex) end)
                                    refreshWorkshopView() 
                                end) 
                            end
                        )
                    end)
                else
                    local btnText, btnColor, action = "Claim", C.green, "claim"
                    if shopKey == "Wash" and not slotData.Washed then btnText, btnColor, action = "Collect", COLORS.Purple, "collectWash"
                    elseif shopKey == "Repair" and not slotData.Repaired then btnText, btnColor, action = "Collect", COLORS.Purple, "collectRepair"
                    elseif shopKey == "Grading" and not slotData.Grade then btnText, btnColor, action = "Roll", COLORS.Purple, "rollGrade"
                    elseif shopKey == "Locksmith" and not slotData.Opened then btnText, btnColor, action = "Open", COLORS.Orange, "openSafe" end
                    
                    if slotData.Grade then realItemName = realItemName .. " (" .. tostring(slotData.Grade) .. " *)" elseif slotData.CleanMutation then realItemName = realItemName .. " (" .. tostring(slotData.CleanMutation) .. ")" end
                    
                    local actionBtn = make("TextButton", { Text = btnText, TextSize = 8, Font = Enum.Font.MontserratBold, TextColor3 = btnColor, BackgroundColor3 = C.card, Position = UDim2.new(0.6, 0, 0.5, -10), Size = UDim2.new(0.4, -6, 0, 20), AutoButtonColor = false }, card)
                    corner(5, actionBtn); stroke(1.2, btnColor, actionBtn)
                    actionBtn.MouseButton1Click:Connect(function()
                        actionBtn.Text = "Claiming..."
                        task.spawn(function()
                            local success, err = pcall(function()
                                if action == "claim" then
                                    local res = cfg.claimWork(slotIndex)
                                    local function deepFind(t, keys)
                                        if type(t) ~= "table" then return nil end
                                        for k, v in pairs(t) do
                                            for _, key in ipairs(keys) do
                                                if string.lower(tostring(k)) == string.lower(key) then return v end
                                            end
                                            if type(v) == "table" then
                                                local found = deepFind(v, keys)
                                                if found then return found end
                                            end
                                        end
                                        return nil
                                    end
                                    local grade = deepFind(res, {"grade", "stars"}) or deepFind(slotData, {"grade", "stars"})
                                    local mut = deepFind(res, {"cleanmutation", "mutator", "mutation"}) or deepFind(slotData, {"cleanmutation", "mutator", "mutation"})
                                    local cond = deepFind(res, {"condition", "health", "durability"}) or deepFind(slotData, {"condition", "health", "durability"})
                                    
                                    local resultStr = ""
                                    if shopKey == "Grading" then
                                        if grade then resultStr = "\\nStars: " .. tostring(grade) .. " *" end
                                    elseif shopKey == "Wash" then
                                        if mut then resultStr = "\\nMutation: " .. tostring(mut) end
                                    elseif shopKey == "Repair" then
                                        if cond then resultStr = "\\nCondition: " .. tostring(cond) .. "%" end
                                    end
                                    showWorkshopPopup("Claimed!" .. resultStr, C.green)
                                elseif action == "collectWash" then
                                    local res = EventsObj:WaitForChild("Wash"):WaitForChild("CollectWash"):InvokeServer(slotIndex)
                                    local mut = type(res) == "table" and (res.CleanMutation or res.Mutator or res.Mutation or res.Result)
                                    showWorkshopPopup(mut and "Washed! Mutation: " .. tostring(mut) or "Washed successfully!", C.green)
                                elseif action == "collectRepair" then
                                    local res = EventsObj:WaitForChild("Repair"):WaitForChild("CollectRepair"):InvokeServer(slotIndex)
                                    local cond = type(res) == "table" and (res.Condition or res.Health or res.Durability)
                                    showWorkshopPopup(cond and "Repaired! Condition: " .. tostring(cond) .. "%" or "Repair collected!", C.green)
                                elseif action == "rollGrade" then
                                    local res = cfg.collect(slotIndex)
                                    local grade = type(res) == "table" and (res.Grade or res.Stars or res.Score)
                                    showWorkshopPopup(grade and "Graded! Stars: " .. tostring(grade) .. " *" or "Grade completed!", C.gold)
                                elseif action == "openSafe" then
                                    pcall(function() cfg.openSafe(slotIndex) end)
                                    task.wait(0.6)
                                    local res = nil
                                    pcall(function() res = cfg.claimWork(slotIndex) end)
                                    local lootText = formatSafeClaimResult(res)
                                    showWorkshopPopup(lootText, COLORS.Orange)
                                end
                            end)
                            if not success then
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

if tabs and tabs["Workshops"] then
    tabs["Workshops"].onOpen = function()
        if tabWorkshop and tabWorkshop:IsA("ScrollingFrame") then
            tabWorkshop.CanvasPosition = Vector2.new(0, 0)
        end
        setShopType(activeShopKey or "Wash")
    end
end

-- Active Heartbeat for Timers inside right column (Throttled to 10 FPS for optimal performance)
local lastTimerUpdate = 0
table.insert(cleanUpSignals, RunService.Heartbeat:Connect(function()
    if os.clock() - lastTimerUpdate < 0.1 then return end
    lastTimerUpdate = os.clock()
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



local lastAutoPawnTime = 0
local lastPawnRateCheckTime = 0

local function pawnSellAll(isAutomated, reason)
    local getRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("GetSellableItems", 3)
    local sellRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("SellItems", 3)
    if not getRemote or not sellRemote then 
        if not isAutomated then showWorkshopPopup("Pawn remotes not found!", C.red) end
        return 0, 0
    end
    
    local items = getRemote:InvokeServer()
    if not items or not next(items) then 
        if not isAutomated then showWorkshopPopup("Nothing to sell!", COLORS.Orange) end
        return 0, 0
    end
    
    local ItemsModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Items")
    local ItemsData = ItemsModule and require(ItemsModule) or {}
    
    local guids = {}
    for guid, data in pairs(items) do
        repeat
            local itemId = data.ItemId
            local itemConf = ItemsData[tostring(itemId)] or ItemsData[tonumber(itemId)]
            local rawName = (itemConf and itemConf.Name) or data.Name or data.DisplayName or ""
            local name = rawName:lower()
            local category = (itemConf and (itemConf.Category or itemConf.category) or data.Category or ""):lower()
            
            -- Safety Exclusions: Always skip valuable items and custom UI excluded items
            if isItemExcluded(rawName, data, "sell") then break end
            -- Value Range: use real price via MutatorModule (same logic as auto-store min value)
            local MutatorModule = require(ReplicatedStorage.Modules.MutatorModule)
            local basePrice = itemConf and (itemConf.BasePrice or 0) or 0
            local itemPrice = MutatorModule:CalculatePriceForEntry(basePrice, data)
            itemPrice = itemPrice or 0

            -- Value Range: OR logic when both set (pawn if under max OR over min)
            local maxActive = gConfig.autoPawnMaxItemValue and gConfig.autoPawnMaxItemValue > 0
            local minActive = gConfig.autoPawnMinItemValue and gConfig.autoPawnMinItemValue > 0
            if maxActive and minActive then
                -- Both active: pawn if price < max OR price > min (skip middle range)
                if not (itemPrice < gConfig.autoPawnMaxItemValue or itemPrice > gConfig.autoPawnMinItemValue) then
                    break
                end
            elseif maxActive then
                if itemPrice > gConfig.autoPawnMaxItemValue then break end
            elseif minActive then
                if itemPrice < gConfig.autoPawnMinItemValue then break end
            end

            table.insert(guids, guid)
        until true
    end
    
    if #guids == 0 then 
        if not isAutomated then showWorkshopPopup("Nothing to sell!", COLORS.Orange) end
        return 0, 0
    end
    
    local res = sellRemote:InvokeServer(guids)
    if res and res.success then 
        local prefix = isAutomated and string.format("[Auto-Pawn (%s)] ", reason or "Auto") or ""
        local msg = string.format("%sSold %d items for $%d!", prefix, res.sold or #guids, res.totalEarned or 0)
        showWorkshopPopup(msg, C.green)
        pcall(function() abLog("[Profit] " .. msg, C.green) end)
        return res.sold or #guids, res.totalEarned or 0
    else 
        if not isAutomated then showWorkshopPopup("Pawn sale failed!", C.red) end
        return 0, 0
    end
end

-- AUTO-BID & PAWN TAB
do
local abToggleBtn, updateBidLoopBtn = createToggle(tabBidding, "Enable Auto-Bid Loop", gConfig.autoBidEnabled or false, function(enabled)
    AB.biddingModes:Set("autoBidEnabled", enabled)
end)
abToggleBtn.Name = "AutoBidToggle"
AB.biddingModes:RegisterVisual("autoBidEnabled", updateBidLoopBtn)
_G.uiUpdaters["autoBidEnabled"] = updateBidLoopBtn
_G.uiToggles["autoBidEnabled"] = function(enabled)
    AB.biddingModes:Set("autoBidEnabled", enabled)
end

-- Bid Speed Slider UI
local bidSpeedCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabBidding)
corner(6, bidSpeedCard)

make("TextLabel", {
    Size = UDim2.new(0.4, 0, 0, 20),
    Position = UDim2.new(0, 12, 0, 4),
    BackgroundTransparency = 1,
    Text = "Bidding Speed (Delay):",
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, bidSpeedCard)

local bidSpeedValLbl = make("TextLabel", {
    Size = UDim2.new(0.3, 0, 0, 20),
    Position = UDim2.new(0.7, -12, 0, 4),
    BackgroundTransparency = 1,
    Text = string.format("%.2fs", AB.speed),
    TextColor3 = C.accent,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Right,
}, bidSpeedCard)

local sliderTrack = make("Frame", {
    Size = UDim2.new(1, -24, 0, 6),
    Position = UDim2.new(0, 12, 0.5, 8),
    BackgroundColor3 = COLORS.BG,
    BorderSizePixel = 0,
}, bidSpeedCard)
corner(3, sliderTrack)

local sliderFill = make("Frame", {
    Size = UDim2.fromScale(0.3, 1),
    BackgroundColor3 = C.accent,
    BorderSizePixel = 0,
}, sliderTrack)
corner(3, sliderFill)

local sliderKnob = make("Frame", {
    Size = UDim2.new(0, 14, 0, 14),
    Position = UDim2.new(0.3, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.text,
    BorderSizePixel = 0,
}, sliderTrack)
corner(99, sliderKnob); stroke(1, C.border, sliderKnob)

local sliderDragging = false
local MIN_SPD, MAX_SPD = 0.02, 2.0
local function applySliderAt(ratio)
    ratio = math.clamp(ratio, 0, 1)
    AB.speed = math.floor((MIN_SPD * (MAX_SPD / MIN_SPD) ^ ratio) * 100) / 100
    gConfig.autoBidSpeed = AB.speed
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0); sliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
    bidSpeedValLbl.Text = string.format("%.2fs", AB.speed)
end

local function updateBidSpeedUI(spd)
    spd = tonumber(spd) or gConfig.autoBidSpeed or AB.speed or 0.3
    AB.speed = spd
    gConfig.autoBidSpeed = spd
    local ratio = math.clamp(math.log(spd / MIN_SPD) / math.log(MAX_SPD / MIN_SPD), 0, 1)
    sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
    sliderKnob.Position = UDim2.new(ratio, 0, 0.5, 0)
    bidSpeedValLbl.Text = string.format("%.2fs", spd)
end
_G.uiUpdaters["autoBidSpeed"] = updateBidSpeedUI
updateBidSpeedUI(gConfig.autoBidSpeed or AB.speed or 0.3)

table.insert(cleanUpSignals, sliderTrack.InputBegan:Connect(function(inp) if isTouchOrClick(inp) then sliderDragging = true; applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)) end end))
table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp) if sliderDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then applySliderAt(math.clamp((inp.Position.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)) end end))
table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
    if isTouchOrClick(inp) and sliderDragging then
        sliderDragging = false
        saveConfig()
    end
end))

-- Min Starting Bid Card
local minBidCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabBidding)
corner(6, minBidCard)

make("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Min Starting Bid limit:",
    TextColor3 = C.text,
    TextSize = 11,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, minBidCard)

local minBidBox = make("TextBox", {
    Size = UDim2.new(0, 80, 0, 24),
    Position = UDim2.new(1, -142, 0.5, -12),
    BackgroundColor3 = COLORS.BG,
    Text = tostring(gConfig.minStartBid or AB.minStartBid or 0),
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    ClearTextOnFocus = false,
}, minBidCard)
corner(5, minBidBox); stroke(1, C.border, minBidBox)

local minBidLbl = make("TextLabel", {
    Size = UDim2.new(0, 50, 1, 0),
    Position = UDim2.new(1, -56, 0, 0),
    BackgroundTransparency = 1,
    Text = ((gConfig.minStartBid or AB.minStartBid or 0) == 0 and "Off" or "$" .. tostring(gConfig.minStartBid or AB.minStartBid or 0)),
    TextColor3 = C.gold,
    TextSize = 9,
    Font = Enum.Font.Montserrat,
    TextXAlignment = Enum.TextXAlignment.Left,
}, minBidCard)

local function updateMinBidUI(v)
    v = tonumber(v) or gConfig.minStartBid or 0
    AB.minStartBid = v
    gConfig.minStartBid = v
    minBidBox.Text = tostring(v)
    minBidLbl.Text = (v == 0 and "Off" or "$" .. v)
    minBidLbl.TextColor3 = (v == 0 and C.text2 or C.gold)
end
_G.uiUpdaters["minStartBid"] = updateMinBidUI

minBidBox:GetPropertyChangedSignal("Text"):Connect(function()
    local v = tonumber(minBidBox.Text)
    if v then
        AB.minStartBid = math.max(0, math.floor(v))
        gConfig.minStartBid = AB.minStartBid
        minBidLbl.Text = AB.minStartBid == 0 and "Off" or "$" .. AB.minStartBid
        minBidLbl.TextColor3 = AB.minStartBid == 0 and C.text2 or C.gold
    end
end)

minBidBox.FocusLost:Connect(function()
    local v = tonumber(minBidBox.Text)
    if v then
        AB.minStartBid = math.max(0, math.floor(v))
        gConfig.minStartBid = AB.minStartBid
        minBidBox.Text = tostring(AB.minStartBid)
        minBidLbl.Text = AB.minStartBid == 0 and "Off" or "$" .. AB.minStartBid
        minBidLbl.TextColor3 = AB.minStartBid == 0 and C.text2 or C.gold
        saveConfig()
    else
        minBidBox.Text = tostring(gConfig.minStartBid or 0)
    end
end)

_G.inputFlushers = _G.inputFlushers or {}
_G.inputFlushers["minBidBox"] = function()
    local v = tonumber(minBidBox.Text)
    if v then
        gConfig.minStartBid = math.max(0, math.floor(v))
        AB.minStartBid = gConfig.minStartBid
    end
end

-- Bidding Log window
local logOuter = make("Frame", {
    Size = UDim2.new(1, 0, 0, 96),
    BackgroundColor3 = COLORS.BG,
    BorderSizePixel = 0,
}, tabBidding)
corner(6, logOuter); pad(6, logOuter)

local logLabels = {}
for i = 1, 6 do 
    logLabels[i] = make("TextLabel", {
        Text = "", TextSize = 8, TextColor3 = C.text2, Font = Enum.Font.Montserrat,
        BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, (i - 1) * 13), Size = UDim2.new(1, 0, 0, 12),
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
    }, logOuter) 
end

local clearLogBtn = make("TextButton", {
    Text = "Clear", TextSize = 8, TextColor3 = C.text2, BackgroundColor3 = C.card,
    Position = UDim2.new(1, -36, 1, -14), Size = UDim2.new(0, 32, 0, 14), Font = Enum.Font.Montserrat, AutoButtonColor = false,
}, logOuter)
corner(3, clearLogBtn)
clearLogBtn.MouseButton1Click:Connect(function()
    AB.logLines = {}
    if AB.onLog then AB.onLog() end
end)

AB.onLog = function() 
    for i, lbl in ipairs(logLabels) do 
        local entry = AB.logLines[i]
        if entry then 
            lbl.Text = entry.text
            lbl.TextColor3 = entry.col 
        else 
            lbl.Text = "" 
        end 
    end 
end

-- [Target] SUBTAB 4: ITEM HUNTER & COW SCANNER
do
    gConfig.targetScannerOnly = gConfig.targetScannerOnly or false
    gConfig.targetItemOverrideBid = gConfig.targetItemOverrideBid == nil and true or gConfig.targetItemOverrideBid
    if not gConfig.targetItemsList then
        gConfig.targetItemsList = { ["Cow"] = true }
    end

end


-- Auto-Pawn Monitor Loop (triggers on Full Inventory OR Target Rate %)
task.spawn(function()
    while task.wait(3) do
        if _G.AHScanner_RunID ~= myRunID then break end
        
        -- 1. Auto Pawn on Inventory Full / Fill Percentage
        if AB.autoPawnFull then
            local invCount = LocalPlayer:GetAttribute("InventoryCount") or 0
            local invCap = LocalPlayer:GetAttribute("InventoryCap") or 20
            local targetPct = gConfig.autoPawnInventoryPercent or 100
            local currentPct = invCap > 0 and ((invCount / invCap) * 100) or 0
            if currentPct >= targetPct and (os.clock() - lastAutoPawnTime) > 4 then
                lastAutoPawnTime = os.clock()
                task.spawn(function()
                    pcall(function() pawnSellAll(true, string.format("Fill %d%%", math.floor(currentPct))) end)
                end)
            end
        end
        
        -- 2. Auto Pawn on Target Rate Threshold (%)
        if AB.autoPawnRateEnabled and (os.clock() - lastPawnRateCheckTime) > 20 then
            lastPawnRateCheckTime = os.clock()
            task.spawn(function()
                pcall(function()
                    local getPawnState = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("GetPawnState", 3)
                    if getPawnState then
                        local state = getPawnState:InvokeServer()
                        if state and state.rate then
                            local currentRatePct = math.floor((state.rate * 100) + 0.5)
                            if currentRatePct >= AB.targetPawnRate and (os.clock() - lastAutoPawnTime) > 4 then
                                lastAutoPawnTime = os.clock()
                                pawnSellAll(true, string.format("Rate %d%%", currentRatePct))
                            end
                        end
                    end
                end)
            end)
        end
    end
end)

end -- end Auto-Bid do block

-- [Profit] PAWN TAB
do
-- Auto Pawn on Full Inventory Toggle
local _, updatePawnFull = createToggle(tabPawn, "Auto Pawn when Inventory Full", gConfig.autoPawnFull, function(state)
    gConfig.autoPawnFull = state
    AB.autoPawnFull = state
    saveConfig()
end)
    _G.uiToggles["autoPawnFull"] = updatePawnFull


-- Auto Pawn on Target Rate Toggle
local _, updatePawnRate = createToggle(tabPawn, "Auto Pawn on Target Rate", gConfig.autoPawnRateEnabled, function(state)
    gConfig.autoPawnRateEnabled = state
    AB.autoPawnRateEnabled = state
    saveConfig()
end)
    _G.uiToggles["autoPawnRateEnabled"] = updatePawnRate


-- Target Pawn Rate Threshold Card
local pawnRateCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabPawn)
corner(6, pawnRateCard)
make("TextLabel", {
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Min Pawn Rate Threshold (%):",
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnRateCard)
local pawnRateBox = make("TextBox", {
    Size = UDim2.new(0, 70, 0, 24),
    Position = UDim2.new(1, -82, 0.5, -12),
    BackgroundColor3 = COLORS.BG,
    Text = tostring(gConfig.targetPawnRate or AB.targetPawnRate or 100),
    TextColor3 = C.green,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    ClearTextOnFocus = false,
}, pawnRateCard)
corner(5, pawnRateBox); stroke(1, C.border, pawnRateBox)

local function updatePawnRateUI(val)
    val = tonumber(val) or gConfig.targetPawnRate or AB.targetPawnRate or 100
    val = math.max(1, math.floor(val))
    AB.targetPawnRate = val
    gConfig.targetPawnRate = val
    pawnRateBox.Text = tostring(val)
end
_G.uiUpdaters["targetPawnRate"] = updatePawnRateUI

pawnRateBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(pawnRateBox.Text)
    if val then
        AB.targetPawnRate = math.max(1, math.floor(val))
        gConfig.targetPawnRate = AB.targetPawnRate
    end
end)
pawnRateBox.FocusLost:Connect(function()
    local val = tonumber(pawnRateBox.Text)
    if val then
        AB.targetPawnRate = math.max(1, math.floor(val))
        gConfig.targetPawnRate = AB.targetPawnRate
        pawnRateBox.Text = tostring(AB.targetPawnRate)
        saveConfig()
    else
        pawnRateBox.Text = tostring(gConfig.targetPawnRate or 100)
    end
end)
_G.inputFlushers["pawnRateBox"] = function()
    local val = tonumber(pawnRateBox.Text)
    if val then
        AB.targetPawnRate = math.max(1, math.floor(val))
        gConfig.targetPawnRate = AB.targetPawnRate
    end
end


-- Target Inventory Fill Threshold Card
local pawnFillCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabPawn)
corner(6, pawnFillCard)
make("TextLabel", {
    Size = UDim2.new(0.6, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Pawn Trigger: Inventory Fill %:",
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnFillCard)
local pawnFillBox = make("TextBox", {
    Size = UDim2.new(0, 70, 0, 24),
    Position = UDim2.new(1, -82, 0.5, -12),
    BackgroundColor3 = COLORS.BG,
    Text = tostring(gConfig.autoPawnInventoryPercent or 100),
    TextColor3 = C.accent,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    ClearTextOnFocus = false,
}, pawnFillCard)
corner(5, pawnFillBox); stroke(1, C.border, pawnFillBox)

local function updatePawnFillUI(val)
    val = tonumber(val) or gConfig.autoPawnInventoryPercent or 100
    val = math.clamp(math.floor(val), 1, 100)
    gConfig.autoPawnInventoryPercent = val
    pawnFillBox.Text = tostring(val)
end
_G.uiUpdaters["autoPawnInventoryPercent"] = updatePawnFillUI

pawnFillBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(pawnFillBox.Text)
    if val then
        gConfig.autoPawnInventoryPercent = math.clamp(math.floor(val), 1, 100)
    end
end)
pawnFillBox.FocusLost:Connect(function()
    local val = tonumber(pawnFillBox.Text)
    if val then
        gConfig.autoPawnInventoryPercent = math.clamp(math.floor(val), 1, 100)
        pawnFillBox.Text = tostring(gConfig.autoPawnInventoryPercent)
        saveConfig()
    else
        pawnFillBox.Text = tostring(gConfig.autoPawnInventoryPercent or 100)
    end
end)
_G.inputFlushers["pawnFillBox"] = function()
    local val = tonumber(pawnFillBox.Text)
    if val then
        gConfig.autoPawnInventoryPercent = math.clamp(math.floor(val), 1, 100)
    end
end


-- Max Item Value Auto-Pawn Limit Card
local pawnValueCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabPawn)
corner(6, pawnValueCard)
make("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Pawn Items Under Value ($):",
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnValueCard)

local pawnValueBox = make("TextBox", {
    Size = UDim2.new(0, 70, 0, 24),
    Position = UDim2.new(1, -142, 0.5, -12),
    BackgroundColor3 = COLORS.BG,
    Text = tostring(gConfig.autoPawnMaxItemValue or 0),
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    ClearTextOnFocus = false,
}, pawnValueCard)
corner(5, pawnValueBox); stroke(1, C.border, pawnValueBox)

local pawnValueStatusLbl = make("TextLabel", {
    Size = UDim2.new(0, 50, 1, 0),
    Position = UDim2.new(1, -62, 0, 0),
    BackgroundTransparency = 1,
    Text = ((gConfig.autoPawnMaxItemValue or 0) == 0 and "Off (All)" or "Active"),
    TextColor3 = ((gConfig.autoPawnMaxItemValue or 0) == 0 and C.text2 or C.gold),
    TextSize = 9,
    Font = Enum.Font.Montserrat,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnValueCard)

local function updatePawnValueUI(val)
    val = tonumber(val) or gConfig.autoPawnMaxItemValue or 0
    val = math.max(0, math.floor(val))
    gConfig.autoPawnMaxItemValue = val
    pawnValueBox.Text = tostring(val)
    pawnValueStatusLbl.Text = (val == 0 and "Off (All)" or "Active")
    pawnValueStatusLbl.TextColor3 = (val == 0 and C.text2 or C.gold)
end
_G.uiUpdaters["autoPawnMaxItemValue"] = updatePawnValueUI

pawnValueBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(pawnValueBox.Text)
    if val then
        gConfig.autoPawnMaxItemValue = math.max(0, math.floor(val))
        pawnValueStatusLbl.Text = (gConfig.autoPawnMaxItemValue == 0 and "Off (All)" or "Active")
        pawnValueStatusLbl.TextColor3 = (gConfig.autoPawnMaxItemValue == 0 and C.text2 or C.gold)
    end
end)
pawnValueBox.FocusLost:Connect(function()
    local val = tonumber(pawnValueBox.Text)
    if val then
        gConfig.autoPawnMaxItemValue = math.max(0, math.floor(val))
        pawnValueBox.Text = tostring(gConfig.autoPawnMaxItemValue)
        pawnValueStatusLbl.Text = (gConfig.autoPawnMaxItemValue == 0 and "Off (All)" or "Active")
        pawnValueStatusLbl.TextColor3 = (gConfig.autoPawnMaxItemValue == 0 and C.text2 or C.gold)
        saveConfig()
    else
        pawnValueBox.Text = tostring(gConfig.autoPawnMaxItemValue or 0)
    end
end)
_G.inputFlushers["pawnValueBox"] = function()
    local val = tonumber(pawnValueBox.Text)
    if val then
        gConfig.autoPawnMaxItemValue = math.max(0, math.floor(val))
    end
end


-- Min Item Value input
local pawnMinValueCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabPawn)
corner(6, pawnMinValueCard)
make("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "Pawn Items Over Value ($):",
    TextColor3 = C.text,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnMinValueCard)

local pawnMinValueBox = make("TextBox", {
    Size = UDim2.new(0, 70, 0, 24),
    Position = UDim2.new(1, -142, 0.5, -12),
    BackgroundColor3 = COLORS.BG,
    Text = tostring(gConfig.autoPawnMinItemValue or 0),
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    ClearTextOnFocus = false,
}, pawnMinValueCard)
corner(5, pawnMinValueBox); stroke(1, C.border, pawnMinValueBox)

local pawnMinValueStatusLbl = make("TextLabel", {
    Size = UDim2.new(0, 50, 1, 0),
    Position = UDim2.new(1, -62, 0, 0),
    BackgroundTransparency = 1,
    Text = ((gConfig.autoPawnMinItemValue or 0) == 0 and "Off (All)" or "Active"),
    TextColor3 = ((gConfig.autoPawnMinItemValue or 0) == 0 and C.text2 or C.gold),
    TextSize = 9,
    Font = Enum.Font.Montserrat,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pawnMinValueCard)

local function updatePawnMinValueUI(val)
    val = tonumber(val) or gConfig.autoPawnMinItemValue or 0
    val = math.max(0, math.floor(val))
    gConfig.autoPawnMinItemValue = val
    pawnMinValueBox.Text = tostring(val)
    pawnMinValueStatusLbl.Text = (val == 0 and "Off (All)" or "Active")
    pawnMinValueStatusLbl.TextColor3 = (val == 0 and C.text2 or C.gold)
end
_G.uiUpdaters["autoPawnMinItemValue"] = updatePawnMinValueUI

pawnMinValueBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(pawnMinValueBox.Text)
    if val then
        gConfig.autoPawnMinItemValue = math.max(0, math.floor(val))
        pawnMinValueStatusLbl.Text = (gConfig.autoPawnMinItemValue == 0 and "Off (All)" or "Active")
        pawnMinValueStatusLbl.TextColor3 = (gConfig.autoPawnMinItemValue == 0 and C.text2 or C.gold)
    end
end)
pawnMinValueBox.FocusLost:Connect(function()
    local val = tonumber(pawnMinValueBox.Text)
    if val then
        gConfig.autoPawnMinItemValue = math.max(0, math.floor(val))
        pawnMinValueBox.Text = tostring(gConfig.autoPawnMinItemValue)
        pawnMinValueStatusLbl.Text = (gConfig.autoPawnMinItemValue == 0 and "Off (All)" or "Active")
        pawnMinValueStatusLbl.TextColor3 = (gConfig.autoPawnMinItemValue == 0 and C.text2 or C.gold)
        saveConfig()
    else
        pawnMinValueBox.Text = tostring(gConfig.autoPawnMinItemValue or 0)
    end
end)
_G.inputFlushers["pawnMinValueBox"] = function()
    local val = tonumber(pawnMinValueBox.Text)
    if val then
        gConfig.autoPawnMinItemValue = math.max(0, math.floor(val))
    end
end

-- Sell All and Check Rates Action Buttons
local pawnActionsRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 30),
    BackgroundTransparency = 1,
}, tabPawn)
list(nil, 6, pawnActionsRow).FillDirection = Enum.FillDirection.Horizontal

local sellAllBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = C.card,
    Text = "Sell All (Pawn)",
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
}, pawnActionsRow)
corner(6, sellAllBtn); stroke(1, C.border, sellAllBtn)
sellAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local success, err = xpcall(function()
            pawnSellAll(false)
        end, function(e)
            return tostring(e) .. "\n" .. debug.traceback()
        end)
        if not success then
            warn("Pawn Sell All Click Error: " .. tostring(err))
        end
    end)
end)

local checkRatesBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = C.card,
    Text = "Check Rates",
    TextColor3 = C.accent,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
}, pawnActionsRow)
corner(6, checkRatesBtn); stroke(1, C.border, checkRatesBtn)

local ratesPopup = nil
checkRatesBtn.MouseButton1Click:Connect(function()
    local function closeRatesPopup()
        if ratesPopup then
            local p = ratesPopup
            ratesPopup = nil
            tw(p, 0.3, {Size = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
            task.delay(0.3, function() p:Destroy() end)
        end
    end
    if ratesPopup then closeRatesPopup(); return end
    local popup = make("Frame", {
        Name = "RatesPopup", Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, -100, 0.5, -130),
        BackgroundColor3 = COLORS.BG, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 9999
    }, ScreenGui)
    ratesPopup = popup
    tw(popup, 0.4, {Size = UDim2.new(0, 200, 0, 260)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    corner(10, popup); stroke(1.5, C.accent, popup)
    
    local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = COLORS.Sidebar, BorderSizePixel = 0, ZIndex = 21, Active = true }, popup)
    corner(10, titleBar)
    
    local dragging, dragStart, startPos = false, nil, nil
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = popup.Position
        end
    end)
    titleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            popup.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    
    make("TextLabel", { Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = "Pawn Rates", TextColor3 = C.accent, Font = Enum.Font.MontserratBold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, titleBar)
    
    local closeBtn = make("TextButton", { Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(1, -24, 0.5, -10), BackgroundColor3 = C.red, Text = "X", TextColor3 = C.text, Font = Enum.Font.MontserratBold, TextSize = 10, ZIndex = 22 }, titleBar)
    corner(6, closeBtn); closeBtn.MouseButton1Click:Connect(closeRatesPopup)
    
    local infoBar = make("Frame", { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.new(0, 6, 0, 32), BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 21 }, popup)
    corner(4, infoBar)
    
    local rateLbl = make("TextLabel", { Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = "Rate: --", TextColor3 = C.green, Font = Enum.Font.MontserratBold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22 }, infoBar)
    local timerLbl = make("TextLabel", { Size = UDim2.new(0.5, -6, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundTransparency = 1, Text = "Refresh: --:--", TextColor3 = C.text2, Font = Enum.Font.MontserratMedium, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 22 }, infoBar)
    
    local scroll = make("ScrollingFrame", { Size = UDim2.new(1, -12, 1, -92), Position = UDim2.new(0, 6, 0, 56), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = C.accent, ZIndex = 21, Active = true, ScrollingDirection = Enum.ScrollingDirection.Y }, popup)
    list(nil, 3, scroll)
    
    local totalBar = make("Frame", { Size = UDim2.new(1, -12, 0, 26), Position = UDim2.new(0, 6, 1, -30), BackgroundColor3 = C.card, BorderSizePixel = 0, ZIndex = 21 }, popup)
    corner(6, totalBar); stroke(1, C.green, totalBar)
    
    local totalLbl = make("TextLabel", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = "Total Value: $0", TextColor3 = C.green, Font = Enum.Font.MontserratBold, TextSize = 10, ZIndex = 22 }, totalBar)
    
    local loadingLbl = make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Loading rates...", TextColor3 = C.text2, Font = Enum.Font.MontserratMedium, TextSize = 9, ZIndex = 22 }, scroll)
    
    local updateLoopActive = true
    popup.AncestryChanged:Connect(function() if not popup:IsDescendantOf(game) then updateLoopActive = false end end)
    
    task.spawn(function()
        local success, err = pcall(function()
            local ItemsData = require(ReplicatedStorage.Modules.Items)
            local MutatorModule = require(ReplicatedStorage.Modules.MutatorModule)
            local getRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("GetSellableItems")
            if not getRemote then return end
            local getPawnState = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Pawn"):WaitForChild("GetPawnState")
            
            loadingLbl:Destroy()
                local rateMultiplier = 0.5
                local secondsLeft = 0
                local lastStateFetch = 0
                while updateLoopActive do
                    local now = os.time()
                    if now - lastStateFetch > 10 or secondsLeft <= 0 then
                        if getPawnState then
                            local state = getPawnState:InvokeServer()
                            if state then
                                rateMultiplier = state.rate or 0.75
                                secondsLeft = math.max(0, math.floor(state.secondsUntilNext or 0))
                                lastStateFetch = now
                            end
                        end
                    else
                        secondsLeft = math.max(0, secondsLeft - 1)
                    end
                    
                    local pct = math.round((rateMultiplier - 1) * 100)
                    rateLbl.Text = string.format("Rate: %s%d%%", pct >= 0 and "+" or "", pct)
                    rateLbl.TextColor3 = pct < 0 and C.red or C.green
                    
                    local mins = math.floor(secondsLeft / 60)
                    local secs = secondsLeft % 60
                    timerLbl.Text = string.format("Refresh: %02d:%02d", mins, secs)
                    
                    for _, child in ipairs(scroll:GetChildren()) do if not child:IsA("UIListLayout") then child:Destroy() end end
                    
                    local curItems = getRemote:InvokeServer()
                    if not curItems or not next(curItems) then
                        make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Empty", TextColor3 = C.text2, Font = Enum.Font.MontserratMedium, TextSize = 9, ZIndex = 22 }, scroll)
                        totalLbl.Text = "Total Value: $0"
                    else
                        local entries = {}
                        local total = 0
                        for guid, data in pairs(curItems) do
                            local conf = ItemsData[tostring(data.ItemId)] or ItemsData[tonumber(data.ItemId)]
                            local name = conf and conf.Name or ("Item #"..tostring(data.ItemId))
                            local rawPrice = MutatorModule:CalculatePriceForEntry(conf and conf.BasePrice or 0, data)
                            local finalPawnPrice = rawPrice * rateMultiplier
                            total = total + finalPawnPrice
                            table.insert(entries, { name = name, price = finalPawnPrice })
                        end
                        table.sort(entries, function(a,b) return a.price > b.price end)
                        for idx, entry in ipairs(entries) do
                            local row = make("Frame", { Size = UDim2.new(1, -4, 0, 24), BackgroundColor3 = COLORS.BG, BorderSizePixel = 0, ZIndex = 22 }, scroll)
                            corner(4, row)
                            make("TextLabel", { Size = UDim2.new(0.65, -4, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = entry.name, TextColor3 = C.text, Font = Enum.Font.MontserratMedium, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 23 }, row)
                            make("TextLabel", { Size = UDim2.new(0.35, -6, 1, 0), Position = UDim2.new(0.65, 0, 0, 0), BackgroundTransparency = 1, Text = string.format("$%.1f", entry.price), TextColor3 = C.green, Font = Enum.Font.MontserratBold, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23 }, row)
                        end
                    totalLbl.Text = string.format("Total Value: $%.1f", total)
                    end
                    task.wait(5)
                end
            end)
        end)
        if not success then
            if loadingLbl and loadingLbl.Parent then
                loadingLbl.Text = "Error: require is blocked on this executor"
                loadingLbl.TextColor3 = C.red
            end
            warn("Check Rates Error: " .. tostring(err))
        end
    end)
end


-- UTILITIES TAB
do
    -- Disable outer scrolling so nested scroll frames work flawlessly without conflict
    tabUtilities.ScrollingEnabled = false
    tabUtilities.ScrollBarThickness = 0
    tabUtilities.AutomaticCanvasSize = Enum.AutomaticSize.None
    tabUtilities.CanvasSize = UDim2.new(0, 0, 0, 0)

    -- Sub-tab navigation container
    local subTabNav = make("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
    }, tabUtilities)
    list(nil, 6, subTabNav).FillDirection = Enum.FillDirection.Horizontal

    local panelMain = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.accent,
        Active = true,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = true,
    }, tabUtilities)
    list(nil, 6, panelMain)

    local panelQuest = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -38),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = C.accent,
        Active = true,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
    }, tabUtilities)
    list(nil, 6, panelQuest)

    -- Sub-tab buttons
    local btnMain = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = COLORS.BG,
        Text = "Main Cheats",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, subTabNav)
    corner(6, btnMain); stroke(1, C.accent, btnMain)

    local btnQuest = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = C.card,
        Text = "Quest Automation",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, subTabNav)
    corner(6, btnQuest); stroke(1, C.border, btnQuest)

    btnMain.MouseButton1Click:Connect(function()
        panelMain.Visible = true
        panelQuest.Visible = false
        btnMain.BackgroundColor3 = COLORS.BG
        btnMain.TextColor3 = C.gold
        stroke(1, C.accent, btnMain)
        btnQuest.BackgroundColor3 = C.card
        btnQuest.TextColor3 = C.text2
        stroke(1, C.border, btnQuest)
    end)

    btnQuest.MouseButton1Click:Connect(function()
        panelMain.Visible = false
        panelQuest.Visible = true
        btnQuest.BackgroundColor3 = COLORS.BG
        btnQuest.TextColor3 = C.gold
        stroke(1, C.accent, btnQuest)
        btnMain.BackgroundColor3 = C.card
        btnMain.TextColor3 = C.text2
        stroke(1, C.border, btnMain)
    end)

    -- PANEL 1: MAIN CHEATS
    -- PLAYER UTILITIES SECTION
    local playerSecCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    }, panelMain)
    
    make("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "── Player Enhancements ──",
        TextColor3 = C.accent,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, playerSecCard)

    -- Walkspeed Toggle
    local wsToggle, updateWsToggle = createToggle(panelMain, "Enable Walkspeed Hack", gConfig.walkSpeedEnabled, function(state)
        gConfig.walkSpeedEnabled = state
        saveConfig()
    end)
    _G.uiToggles["walkSpeedEnabled"] = updateWsToggle

    -- Walkspeed Slider / Input Card
    local wsInputCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, panelMain)
    corner(6, wsInputCard)

    make("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "Custom Walkspeed Value",
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, wsInputCard)

    local wsValBox = make("TextBox", {
        Size = UDim2.new(0.3, 0, 0.7, 0),
        Position = UDim2.new(0.67, 0, 0.15, 0),
        BackgroundColor3 = C.border,
        Text = tostring(gConfig.customWalkSpeed),
        TextColor3 = C.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        PlaceholderText = "16 - 150",
    }, wsInputCard)
    corner(4, wsValBox)

    local function updateWsUI(val)
        val = tonumber(val) or gConfig.customWalkSpeed or 30
        val = math.clamp(math.floor(val), 16, 150)
        gConfig.customWalkSpeed = val
        wsValBox.Text = tostring(val)
    end
    _G.uiUpdaters["customWalkSpeed"] = updateWsUI

    wsValBox:GetPropertyChangedSignal("Text"):Connect(function()
        if isSyncingUI then return end
        local val = tonumber(wsValBox.Text)
        if val then
            gConfig.customWalkSpeed = math.clamp(math.floor(val), 16, 150)
            -- saveConfig() removed: disk write is in FocusLost / flushInputValues only
        end
    end)

    wsValBox.FocusLost:Connect(function(enterPressed)
        local val = tonumber(wsValBox.Text)
        if val then
            val = math.clamp(math.floor(val), 16, 150)
            gConfig.customWalkSpeed = val
            wsValBox.Text = tostring(val)
            saveConfig()
        else
            wsValBox.Text = tostring(gConfig.customWalkSpeed or 30)
        end
    end)
    _G.inputFlushers["wsValBox"] = function()
        local val = tonumber(wsValBox.Text)
        if val then
            gConfig.customWalkSpeed = math.clamp(math.floor(val), 16, 150)
        end
    end

    -- Flight Toggle
    local flightToggle, updateFlightToggle = createToggle(panelMain, "Enable Flight Mode", gConfig.flightEnabled, function(state)
        gConfig.flightEnabled = state
        saveConfig()
    end)
    _G.uiToggles["flightEnabled"] = updateFlightToggle

    -- Flight Speed Slider / Input Card
    local flightInputCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, panelMain)
    corner(6, flightInputCard)

    make("TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "Flight Speed Value",
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, flightInputCard)

    local flightValBox = make("TextBox", {
        Size = UDim2.new(0.3, 0, 0.7, 0),
        Position = UDim2.new(0.67, 0, 0.15, 0),
        BackgroundColor3 = C.border,
        Text = tostring(gConfig.flightSpeed),
        TextColor3 = C.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        PlaceholderText = "10 - 200",
    }, flightInputCard)
    corner(4, flightValBox)

    local function updateFlightUI(val)
        val = tonumber(val) or gConfig.flightSpeed or 50
        val = math.clamp(math.floor(val), 10, 200)
        gConfig.flightSpeed = val
        flightValBox.Text = tostring(val)
    end
    _G.uiUpdaters["flightSpeed"] = updateFlightUI

    flightValBox:GetPropertyChangedSignal("Text"):Connect(function()
        if isSyncingUI then return end
        local val = tonumber(flightValBox.Text)
        if val then
            gConfig.flightSpeed = math.clamp(math.floor(val), 10, 200)
            -- saveConfig() removed: disk write is in FocusLost / flushInputValues only
        end
    end)

    flightValBox.FocusLost:Connect(function(enterPressed)
        local val = tonumber(flightValBox.Text)
        if val then
            val = math.clamp(math.floor(val), 10, 200)
            gConfig.flightSpeed = val
            flightValBox.Text = tostring(val)
            saveConfig()
        else
            flightValBox.Text = tostring(gConfig.flightSpeed or 50)
        end
    end)
    _G.inputFlushers["flightValBox"] = function()
        local val = tonumber(flightValBox.Text)
        if val then
            gConfig.flightSpeed = math.clamp(math.floor(val), 10, 200)
        end
    end

    -- Space divider
    local divCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundTransparency = 1,
    }, panelMain)

    -- ── GENERAL AUTOMATION SECTION
    local genSecCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
    }, panelMain)
    make("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "── General Automation ──",
        TextColor3 = C.accent,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, genSecCard)

    local noNPCToggleCard2, updateNoNPCToggle2 = createToggle(panelMain, "No NPC Collision (Pass-Through)", gConfig.noNPCCollision, function(state)
        gConfig.noNPCCollision = state
        saveConfig()
        if _G.scanAllNPCs then pcall(_G.scanAllNPCs) end
        if _G.uiToggles["noNPCCollision"] then pcall(_G.uiToggles["noNPCCollision"], state) end
    end)
    noNPCToggleCard2.Name = "NoNPCUtilitiesToggle"

    local npcCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, panelMain)
    corner(6, npcCard)

    make("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Teleport Target:",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, npcCard)

    local selectedTpTarget = "Shopping Mall"
    local tpDropdownBtn = make("TextButton", {
        Size = UDim2.new(0, 120, 0, 26),
        Position = UDim2.new(1, -132, 0.5, -13),
        BackgroundColor3 = COLORS.BG,
        Text = "Shopping Mall v",
        TextColor3 = COLORS.Purple,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, npcCard)
    corner(5, tpDropdownBtn); stroke(1, C.border, tpDropdownBtn)

    local tpDDContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 125),
        BackgroundColor3 = COLORS.Sidebar,
        Visible = false,
    }, panelMain)
    corner(6, tpDDContainer)

    local scrollFrame = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, 360),
    }, tpDDContainer)
    list(nil, 4, scrollFrame)
    pad(4, scrollFrame)

    local tpOpen = false
    tpDropdownBtn.MouseButton1Click:Connect(function()
        tpOpen = not tpOpen
        tpDDContainer.Visible = tpOpen
        tpDropdownBtn.Text = selectedTpTarget .. (tpOpen and " ^" or " v")
    end)

    local TP_TARGETS = {
        { name = "Shopping Mall", pos = Vector3.new(345, 1723, -100) },
        { name = "Event NPC: Kyle", pos = Vector3.new(-153.92, 1730.56, -758.66) },
        { name = "Event NPC: Annie", pos = Vector3.new(-163.42, 1730.56, -874.36) },
        { name = "Merchant: Sam", modelPath = "Areas.Lucky Beach.Sam", fallback = Vector3.new(-227.08, 1701.56, -1762.77) },
        { name = "Merchant: Billy", modelPath = "Areas.Junk Yard.Billy", fallback = Vector3.new(-1052.7, 1728.8, 108.9) },
        { name = "Merchant: Sal", modelPath = "Areas.Back Alley.Sal", fallback = Vector3.new(-324.9, 1725.1, 335.5) },
        { name = "Merchant: Ted", modelPath = "Areas.Farmyard.Ted", fallback = Vector3.new(-24.5, 1726.5, -675.2) },
        { name = "Merchant: Steve", modelPath = "Areas.Shipyard.Steve", fallback = Vector3.new(-1205.8, 1736.2, -780.4) },
        { name = "Merchant: Michael", modelPath = "Areas.Business Bay.Michael", fallback = Vector3.new(1988.12, 1725.36, -3935.04) },
        { name = "Area: Business Bay", pos = Vector3.new(1988.12, 1725.36, -3935.04) },
        { name = "Area: Cargo Train", pos = Vector3.new(-422.0, 1731.0, 952.0) },
        { name = "Event NPC: Train Conductor", pos = Vector3.new(-419.4, 1731.5, 951.5) },
        { name = "Area: The Mines", pos = Vector3.new(-3180.33, 1578.50, -1912.78) },
    }

    local function resolveTargetPosition(target)
        if target.pos then return target.pos end
        if target.modelPath then
            local inst = workspace
            for partName in target.modelPath:gmatch("[^%.]+") do
                inst = inst and inst:FindFirstChild(partName)
            end
            if inst then
                local bp = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChild("HumanoidRootPart") or inst:FindFirstChildWhichIsA("BasePart")) or inst
                if bp then return bp.Position end
            end
        end
        return target.fallback
    end

    for _, target in ipairs(TP_TARGETS) do
        local btn = make("TextButton", {
            Size = UDim2.new(1, -6, 0, 24),
            BackgroundColor3 = C.card,
            Text = target.name,
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, scrollFrame)
        corner(4, btn); stroke(1, C.border, btn)
        
        btn.MouseButton1Click:Connect(function()
            selectedTpTarget = target.name
            tpDropdownBtn.Text = target.name .. " v"
            tpOpen = false
            tpDDContainer.Visible = false
            
            pcall(function()
                local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local pos = resolveTargetPosition(target)
                    if pos then
                        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                        showWorkshopPopup("Teleported to " .. target.name, C.green)
                    end
                end
            end)
        end)
    end

    local speedActive = false
    local defaultSpeed = 16
    local hackSpeed = 32
    local speedToggleCard = createToggle(panelMain, "Increase WalkSpeed (x2)", false, function(state)
        speedActive = state
        _G.NexSpeedActive = state
        pcall(function() LocalPlayer.Character.Humanoid.WalkSpeed = state and hackSpeed or defaultSpeed end)
    end)

    local infJumpActive = false
    table.insert(cleanUpSignals, UserInputService.JumpRequest:Connect(function() 
        if infJumpActive then 
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end 
        end 
    end))

    local jumpToggleCard = createToggle(panelMain, "Enable Infinite Jump", false, function(state)
        infJumpActive = state
    end)

    local tpActionsRow = make("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundTransparency = 1,
    }, panelMain)
    list(nil, 6, tpActionsRow).FillDirection = Enum.FillDirection.Horizontal

    local fastTpBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = C.card,
        Text = "Fast TP (Driveway)",
        TextColor3 = C.accent,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, tpActionsRow)
    corner(6, fastTpBtn)

    local safeTpBtn = make("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = C.card,
        Text = "Safe TP (Driveway)",
        TextColor3 = C.green,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, tpActionsRow)
    corner(6, safeTpBtn)

    local function getTpTarget()
        return getMyLivePlotDrivewayCF()
    end

    local function flatCF(cf, heightOffset, yawOffset)
        heightOffset = heightOffset or 0
        yawOffset = yawOffset or 0
        local pos = cf.Position + Vector3.new(0, heightOffset, 0)
        local look = cf.LookVector
        local yaw = math.atan2(-look.X, -look.Z) + yawOffset
        return CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
    end

    fastTpBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local targetCFrame = getTpTarget()
            if not targetCFrame then
                showWorkshopPopup("Plot driveway not found!", C.red)
                return
            end
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local isSitting = hum and hum.Sit or false
            local safeCF = flatCF(targetCFrame, isSitting and 4.5 or 2, math.rad(90))
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = safeCF
                showWorkshopPopup("Fast TP Completed!", C.green)
            end
        end)
    end)

    local tweenSpeeds = {60, 120, 200, 300}
    local currentTwSpdIdx = 2

    safeTpBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local targetCFrame = getTpTarget()
            if not targetCFrame then
                showWorkshopPopup("Plot driveway not found!", C.red)
                return
            end
            local char = LocalPlayer.Character
            if not char then return end
            local hum = char:FindFirstChild("Humanoid")
            local isSitting = hum and hum.Sit or false
            local safeCF = flatCF(targetCFrame, isSitting and 4.5 or 2, math.rad(90))
            
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            
            local startCF = hrp.CFrame
            local dist = (startCF.Position - safeCF.Position).Magnitude
            local speed = tweenSpeeds[currentTwSpdIdx] or 120
            local duration = dist / speed
            
            showWorkshopPopup(string.format("Safe TP started! ETA: %.1fs", duration), C.green)
            
            local val = Instance.new("CFrameValue")
            val.Value = startCF
            local wasAnchored = hrp.Anchored
            hrp.Anchored = true
            
            local restored = false
            local function restoreAnchor()
                if restored then return end
                restored = true
                pcall(function() hrp.Anchored = wasAnchored end)
            end
            task.delay(duration + 2, restoreAnchor)
            
            local conn = val.Changed:Connect(function(cf) 
                hrp.CFrame = cf
            end)
            
            local tw2 = TweenService:Create(val, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Value = safeCF})
            tw2.Completed:Connect(function()
                conn:Disconnect()
                val:Destroy()
                restoreAnchor()
                showWorkshopPopup("Safe TP completed!", C.green)
            end)
            tw2:Play()
        end)
    end)

    local twSpdSelectBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C.card,
        Text = "Safe TP Speed: " .. tweenSpeeds[currentTwSpdIdx] .. " studs/s",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, panelMain)
    corner(6, twSpdSelectBtn)
    twSpdSelectBtn.MouseButton1Click:Connect(function()
        currentTwSpdIdx = currentTwSpdIdx % #tweenSpeeds + 1
        twSpdSelectBtn.Text = "Safe TP Speed: " .. tweenSpeeds[currentTwSpdIdx] .. " studs/s"
    end)

    local unstickCarBtn = make("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C.card,
        Text = "Unstick Car",
        TextColor3 = COLORS.Orange,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, panelMain)
    corner(6, unstickCarBtn)
    unstickCarBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local vehicle = hum and hum.SeatPart and hum.SeatPart:FindFirstAncestorWhichIsA("Model")
            if vehicle then
                for _, part in ipairs(vehicle:GetDescendants()) do
                    if part:IsA("BasePart") then part.Anchored = false end
                end
                showWorkshopPopup("Car unstuck successfully!", C.green)
            else
                showWorkshopPopup("Not sitting inside a vehicle", COLORS.Orange)
            end
        end)
    end)

    local antiAFKConn = nil
    local antiAFKInputConns = {}

    local function toggleAntiAFK(state)
        if antiAFKConn then
            task.cancel(antiAFKConn)
            antiAFKConn = nil
        end
        if antiAFKInputConns then
            for _, c in ipairs(antiAFKInputConns) do
                pcall(function() c:Disconnect() end)
            end
        end
        antiAFKInputConns = {}

        if state then
            -- getconnections(LocalPlayer.Idled) removed to prevent memory access crashes on Wave/PC executors

            local VirtualInputManager = game:GetService("VirtualInputManager")

            local function afkDoKeepAlive()
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightBracket, false, game)
                    task.wait(0.05)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightBracket, false, game)
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if not hum.Sit then
                            hum:Move(Vector3.new(0, 0, 0.01), true)
                            task.wait(0.1)
                            hum:Move(Vector3.new(0, 0, 0), true)
                        else
                            local seat = hum.SeatPart
                            if seat and seat:IsA("VehicleSeat") then
                                seat.Steer = 1
                                task.wait(0.1)
                                seat.Steer = 0
                            end
                        end
                    end
                end)
            end

            pcall(function()
                local idledConn = LocalPlayer.Idled:Connect(function()
                    afkDoKeepAlive()
                end)
                table.insert(antiAFKInputConns, idledConn)
            end)

            antiAFKConn = task.spawn(function()
                while _G.AHScanner_RunID == myRunID do
                    task.wait(30)
                    afkDoKeepAlive()
                end
            end)
        end
    end

    createToggle(panelMain, "Anti-AFK", true, toggleAntiAFK)
    toggleAntiAFK(true)

    createButton(panelMain, "Restore Mobile Controls", function()
        pcall(function()
            local player = game:GetService("Players").LocalPlayer
            local playerGui = player and player:FindFirstChildWhichIsA("PlayerGui")
            local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
            if touchGui then
                touchGui.Enabled = true
                local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
                if touchControlFrame then
                    touchControlFrame.Visible = true
                    local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                    if jumpButton then jumpButton.Visible = true end
                    local dpad = touchControlFrame:FindFirstChild("DynamicThumbstick")
                    if dpad then dpad.Visible = true end
                end
            end
            local PlayerModule = player and player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule")
            if PlayerModule then
                local controls = require(PlayerModule)
                if controls and controls.GetControls then
                    local ctrl = controls:GetControls()
                    if ctrl and ctrl.Enable then
                        ctrl:Enable(true)
                    end
                end
            end
            
            -- Reset ProximityPromptService to clear stuck mobile UI prompts (like "Drive")
            local pps = game:GetService("ProximityPromptService")
            pps.Enabled = false
            task.wait(0.1)
            pps.Enabled = true
            
            showWorkshopPopup("Mobile controls restored!", C.green)
        end)
    end)


    -- PANEL 2: QUEST AUTOMATION
        local questAcceptToggleCard, updateQuestAcceptToggle = createToggle(panelQuest, "Auto Accept Quests", gConfig.autoAcceptQuests, function(state)
        gConfig.autoAcceptQuests = state
        saveConfig()
    end)
    _G.uiToggles["autoAcceptQuests"] = updateQuestAcceptToggle

    local questClaimToggleCard, updateQuestClaimToggle = createToggle(panelQuest, "Auto Claim Quest Rewards", gConfig.autoClaimQuests, function(state)
        gConfig.autoClaimQuests = state
        saveConfig()
    end)
    _G.uiToggles["autoClaimQuests"] = updateQuestClaimToggle

    -- NPC Selector Dropdown Card
    local npcSelectorCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, panelQuest)
    corner(6, npcSelectorCard)

    make("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Allowed Quest NPCs:",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, npcSelectorCard)

    local regularNpcList = {
        "Billy", "Sal", "Ted", "Steve", "Sam", "Michael", "Mike", "Building Inspector", 
        "Museum Attendant", "Gas Station Owner", "Cletus", 
        "TollboothGuard", "Basketball Player 6", "Basketball Player 7", "Fisherman"
    }

    if not gConfig.allowedQuestNpcs then gConfig.allowedQuestNpcs = {} end

    -- Helper: returns true if NPC is allowed by whitelist
    local function isNpcAllowed(npcName)
        if not npcName or npcName == "" then return true end
        if not gConfig.allowedQuestNpcs then return true end
        local hasAnyActive = false
        for _, v in pairs(gConfig.allowedQuestNpcs) do
            if v == true then hasAnyActive = true; break end
        end
        if not hasAnyActive then return true end
        return gConfig.allowedQuestNpcs[npcName] == true
    end

    -- ═════════════════════════════════════════════════════════════
    -- 1. MAIN QUEST NPCS DROPDOWN
    -- ═════════════════════════════════════════════════════════════
    local activeNpcsText = "All NPCs v"
    local npcDropdownBtn = make("TextButton", {
        Size = UDim2.new(0, 150, 0, 26),
        Position = UDim2.new(1, -162, 0.5, -13),
        BackgroundColor3 = COLORS.BG,
        Text = activeNpcsText,
        TextColor3 = C.gold,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, npcSelectorCard)
    corner(5, npcDropdownBtn); stroke(1, C.border, npcDropdownBtn)

    local npcDdContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 150),
        BackgroundColor3 = COLORS.Sidebar,
        Visible = false,
    }, panelQuest)
    corner(6, npcDdContainer)

    local npcScrollFrame = make("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(0, 0, 0, #regularNpcList * 30),
    }, npcDdContainer)
    list(nil, 4, npcScrollFrame)
    pad(4, npcScrollFrame)

    local npcDdOpen = false
    local function updateNpcsButtonText()
        local selected = {}
        for _, n in ipairs(regularNpcList) do
            if gConfig.allowedQuestNpcs[n] then
                table.insert(selected, n)
            end
        end
        if #selected == #regularNpcList or #selected == 0 then
            activeNpcsText = "All NPCs"
        else
            activeNpcsText = tostring(#selected) .. " NPCs"
        end
        npcDropdownBtn.Text = activeNpcsText .. (npcDdOpen and " ^" or " v")
    end
    updateNpcsButtonText()

    npcDropdownBtn.MouseButton1Click:Connect(function()
        npcDdOpen = not npcDdOpen
        npcDdContainer.Visible = npcDdOpen
        updateNpcsButtonText()
    end)

    for _, npcName in ipairs(regularNpcList) do
        local row = make("Frame", {
            Size = UDim2.new(1, -6, 0, 26),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, npcScrollFrame)
        corner(4, row); stroke(1, C.border, row)

        make("TextLabel", {
            Size = UDim2.new(0.7, 0, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = npcName,
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)

        local checkIndicator = make("TextLabel", {
            Size = UDim2.new(0, 30, 1, 0),
            Position = UDim2.new(1, -38, 0, 0),
            BackgroundTransparency = 1,
            Text = gConfig.allowedQuestNpcs[npcName] and "[x]" or "[ ]",
            TextColor3 = gConfig.allowedQuestNpcs[npcName] and C.accent or C.text2,
            TextSize = 12,
            Font = Enum.Font.MontserratBold,
        }, row)

        local rowBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
        }, row)

        rowBtn.MouseButton1Click:Connect(function()
            gConfig.allowedQuestNpcs[npcName] = not gConfig.allowedQuestNpcs[npcName]
            local isNowAllowed = gConfig.allowedQuestNpcs[npcName] == true
            checkIndicator.Text = isNowAllowed and "[x]" or "[ ]"
            checkIndicator.TextColor3 = isNowAllowed and C.accent or C.text2
            updateNpcsButtonText()
        end)
    end

    -- ═════════════════════════════════════════════════════════════
    -- [Quest] ROBUST QUEST AUTOMATION ENGINE
    -- ═════════════════════════════════════════════════════════════
    local function handleAnyQuestDialog(gui, timeout)
        local tStart = tick()
        local maxTime = timeout or 2.5
        local anyClicked = false
        while tick() - tStart < maxTime do
            local foundBtn = false
            if gui then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") and desc.Visible and desc.AbsoluteSize.X > 15 then
                        local txt = desc.Text:lower()
                        if txt:find("thanks") or txt:find("accept") or txt:find("yes") or txt:find("claim") or txt:find("ok") or txt:find("continue") or txt:find("next") or desc.Name == "Option1" or desc.Name == "AcceptButton" then
                            foundBtn = true
                            anyClicked = true
                            pcall(function()
                                if firesignal then
                                    firesignal(desc.MouseButton1Click)
                                elseif getconnections then
                                    local conns = getconnections(desc.MouseButton1Click)
                                    if conns and conns[1] then conns[1]:Fire() end
                                end
                            end)
                            task.wait(0.2)
                            break
                        end
                    end
                end
            end
            if not foundBtn then
                task.wait(0.1)
            end
        end
        return anyClicked
    end

    local function findNPCModel(name)
        if not name or name == "" then return nil end
        local cleanName = name:lower():gsub("%s+", "")
        
        local checkFolders = {
            workspace:FindFirstChild("Areas"),
            workspace:FindFirstChild("Mall - Shop NPCs"),
            workspace:FindFirstChild("Shops"),
            workspace:FindFirstChild("NPCs"),
            workspace
        }
        for _, folder in ipairs(checkFolders) do
            if folder then
                for _, desc in ipairs(folder:GetDescendants()) do
                    if desc:IsA("Model") then
                        local dName = desc.Name:lower():gsub("%s+", "")
                        if dName == cleanName or dName:find(cleanName) or cleanName:find(dName) then
                            if desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChildWhichIsA("Humanoid") or desc:FindFirstChildWhichIsA("ProximityPrompt", true) then
                                return desc
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function getNPCPrompt(npcModel)
        if not npcModel then return nil end
        local prompt = npcModel:FindFirstChild("NPCQuestPrompt", true)
            or npcModel:FindFirstChild("TalkPrompt", true)
            or npcModel:FindFirstChildWhichIsA("ProximityPrompt", true)
        return prompt
    end

    local function resolveNPCFromText(text)
        if not text or type(text) ~= "string" then return nil end
        local clean = text:lower()
        for _, name in ipairs(regularNpcList) do
            if clean:find(name:lower()) then
                return name
            end
        end
        local m1 = text:match("(%w+)'s Reward") or text:match("(%w+)'s Quest")
        if m1 then return m1 end
        local m2 = text:match("speak to ([%w%s]+)") or text:match("talk to ([%w%s]+)") or text:match("return to ([%w%s]+)")
        if m2 then
            m2 = m2:gsub("^%s+", ""):gsub("%s+$", "")
            for _, name in ipairs(regularNpcList) do
                if name:lower() == m2:lower() or m2:lower():find(name:lower()) then
                    return name
                end
            end
            return m2
        end
        return nil
    end

    local function interactWithNPC(npcModel, reason)
        if not npcModel then return false end
        local npcHrp = npcModel:FindFirstChild("HumanoidRootPart") or npcModel.PrimaryPart or npcModel:FindFirstChildWhichIsA("BasePart")
        local lp = game:GetService("Players").LocalPlayer
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildWhichIsA("Humanoid")
        local prompt = getNPCPrompt(npcModel)
        
        if not (npcHrp and hrp and prompt and prompt.Enabled) then return false end

        _G.questTpInProgress = true
        abLog("[Quest] Auto-Quest: Teleporting to " .. npcModel.Name .. " (" .. tostring(reason or "Quest") .. ")", C.gold)
        
        local oldCF = hrp.CFrame
        local wasSeated = hum and hum.Sit
        local seatPart = hum and hum.SeatPart

        -- Safely unseat to prevent physics flings
        if hum and hum.Sit then
            hum.Sit = false
            task.wait(0.2)
        end

        -- Teleport directly in front of the NPC
        hrp.CFrame = npcHrp.CFrame * CFrame.new(0, 0, -3.5) * CFrame.Angles(0, math.pi, 0)
        task.wait(0.35)

        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        end

        -- Handle any dialog buttons that appear (Accept / Thanks! / Option1)
        handleAnyQuestDialog(lp:FindFirstChild("PlayerGui"), 2.5)
        task.wait(0.2)

        -- Teleport back to original position safely
        if hrp and oldCF then
            hrp.CFrame = oldCF
            task.wait(0.2)
            if wasSeated and seatPart and hum then
                pcall(function() seatPart:Sit(hum) end)
            end
        end

        _G.questTpInProgress = false
        return true
    end

    -- Auto Quest Manager Background Loop
    task.spawn(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local lp = game:GetService("Players").LocalPlayer

        while ScreenGui and ScreenGui.Parent do
            task.wait(3.5)
            
            -- Skip if auction pickup, active bidding, or another TP is active
            if not (_G.questTpInProgress or AB.pickupPhase or AB.startingAuction or AB.activeLot) then

            -- 1. Auto Claim Completed Quests
            if gConfig.autoClaimQuests then
                pcall(function()
                    local targetNpcName = nil
                    
                    -- Check QuestSystem module
                    local okQS, questSys = pcall(function() return require(ReplicatedStorage.Modules.QuestSystem) end)
                    if okQS and questSys and questSys.GetActiveQuests then
                        local active = questSys:GetActiveQuests()
                        if active then
                            for _, q in ipairs(active) do
                                if q.Id and q.Id:find("quest_reward") then
                                    targetNpcName = q.Id:match("quest_reward_(.+)")
                                end
                                if not targetNpcName and q.Data and q.Data.Tasks then
                                    for _, t in ipairs(q.Data.Tasks) do
                                        if t.Id == "claim_reward" or (t.Text and (t.Text:lower():find("speak") or t.Text:lower():find("talk") or t.Text:lower():find("reward"))) then
                                            targetNpcName = resolveNPCFromText(t.Text) or resolveNPCFromText(q.Data.Name)
                                            if targetNpcName then break end
                                        end
                                    end
                                end
                                if targetNpcName then break end
                            end
                        end
                    end

                    -- Check screen Quest Log text (e.g. "Ted's Reward: Go speak to Ted to claim your reward")
                    if not targetNpcName then
                        local pGui = lp:FindFirstChild("PlayerGui")
                        if pGui then
                            for _, desc in ipairs(pGui:GetDescendants()) do
                                if desc:IsA("TextLabel") and desc.Visible and desc.Text ~= "" then
                                    local txt = desc.Text
                                    if txt:find("claim your reward") or txt:find("'s Reward") or (txt:lower():find("speak to") and txt:lower():find("reward")) then
                                        targetNpcName = resolveNPCFromText(txt)
                                        if targetNpcName then break end
                                    end
                                end
                            end
                        end
                    end

                    if targetNpcName and isNpcAllowed(targetNpcName) then
                        local npc = findNPCModel(targetNpcName)
                        if npc then
                            interactWithNPC(npc, "Claim Reward")
                            task.wait(2.0)
                        end
                    end
                end)
            end

            -- 2. Auto Accept New Quests (Red '!' Exclamation Mark or Available Prompt)
            if gConfig.autoAcceptQuests and not _G.questTpInProgress then
                pcall(function()
                    local pGui = lp:FindFirstChild("PlayerGui")
                    local foundNPC = nil
                    
                    -- Scan PlayerGui for QuestExclamation billboards
                    if pGui then
                        for _, sg in ipairs(pGui:GetChildren()) do
                            if sg.Name:find("QuestExclamation_") and sg.Enabled then
                                local npcName = sg.Name:match("QuestExclamation_(.+)")
                                if npcName and isNpcAllowed(npcName) then
                                    foundNPC = findNPCModel(npcName)
                                    if foundNPC then break end
                                end
                            end
                        end
                    end

                    -- If not found in PlayerGui, scan workspace NPC models directly
                    if not foundNPC then
                        for _, name in ipairs(regularNpcList) do
                            if isNpcAllowed(name) then
                                local npc = findNPCModel(name)
                                if npc then
                                    local prompt = getNPCPrompt(npc)
                                    local excl = npc:FindFirstChild("Exclamation", true) or npc:FindFirstChild("QuestExclamation", true)
                                    if (excl and excl.Enabled ~= false) or (prompt and prompt.Enabled and (prompt.ActionText:lower():find("quest") or prompt.ActionText:lower():find("talk") or prompt.ObjectText:lower():find("quest"))) then
                                        foundNPC = npc
                                        break
                                    end
                                end
                            end
                        end
                    end

                    if foundNPC then
                        interactWithNPC(foundNPC, "Accept Quest")
                        task.wait(2.0)
                    end
                end)
            end
            end
        end
    end)
end

-- SHOP (REMOTES) TAB
do
    local lp = game:GetService("Players").LocalPlayer

    local function getActiveBoostTime(id)
        local expire = lp:GetAttribute("ActiveLuckDrinkExpireAt_" .. id) or 0
        local now = workspace:GetServerTimeNow()
        local rem = expire - now
        return math.max(0, math.floor(rem))
    end

    local function formatTime(seconds)
        if seconds <= 0 then return "Inactive" end
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%dm %ds", mins, secs)
    end

    -- Header Panel
    local headerFrame = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabShop)
    corner(6, headerFrame); stroke(1, C.border, headerFrame)

    local diamondLabel = make("TextLabel", {
        Size = UDim2.new(0.5, -6, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Diamonds: ...",
        TextColor3 = C.gold,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, headerFrame)

    local activeBoostLabel = make("TextLabel", {
        Size = UDim2.new(0.5, -12, 1, 0),
        Position = UDim2.new(0.5, 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "Active Boost: ...",
        TextColor3 = C.accent,
        TextSize = 11,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, headerFrame)

    task.spawn(function()
        while true do
            local diams = lp:GetAttribute("Diamonds") or 0
            diamondLabel.Text = string.format("Diamonds: %s", tostring(diams))

            local d1 = getActiveBoostTime(1)
            local d2 = getActiveBoostTime(2)
            local d3 = getActiveBoostTime(3)
            
            if d3 > 0 then
                activeBoostLabel.Text = "Boost: +300% (" .. formatTime(d3) .. ")"
                activeBoostLabel.TextColor3 = C.gold
            elseif d2 > 0 then
                activeBoostLabel.Text = "Boost: +150% (" .. formatTime(d2) .. ")"
                activeBoostLabel.TextColor3 = C.accent
            elseif d1 > 0 then
                activeBoostLabel.Text = "Boost: +50% (" .. formatTime(d1) .. ")"
                activeBoostLabel.TextColor3 = C.text
            else
                activeBoostLabel.Text = "Boost: Inactive"
                activeBoostLabel.TextColor3 = C.text2
            end
            task.wait(1.0)
        end
    end)

    -- Section: Luck Drinks
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "LUCK DRINK BOOSTS (DIAMONDS):",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, tabShop)

    -- 1. Auto-Buy Drinks (Stockpile) Multi-Select Card
    local autoBuyCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabShop)
    corner(6, autoBuyCard); stroke(1, C.border, autoBuyCard)
    
    make("TextLabel", {
        Size = UDim2.new(0.42, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Auto-Buy (Stockpile):",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, autoBuyCard)
    
    local autoBuyToggle = make("TextButton", {
        Size = UDim2.new(0, 55, 0, 24),
        Position = UDim2.new(0.43, 0, 0.5, -12),
        BackgroundColor3 = gConfig.autoBuyDrinks and C.accent or COLORS.BG,
        Text = gConfig.autoBuyDrinks and "ON" or "OFF",
        TextColor3 = C.gold,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, autoBuyCard)
    corner(5, autoBuyToggle); stroke(1, C.border, autoBuyToggle)
    
    local selectedBuyDrinkBtn = make("TextButton", {
        Size = UDim2.new(0, 100, 0, 26),
        Position = UDim2.new(1, -112, 0.5, -13),
        BackgroundColor3 = COLORS.BG,
        Text = "None v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, autoBuyCard)
    corner(5, selectedBuyDrinkBtn); stroke(1, C.border, selectedBuyDrinkBtn)
    
    local buyDrinkDdContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, tabShop)
    list(nil, 4, buyDrinkDdContainer)
    
    local buyDrinkDdOpen = false
    local buyDrinkList = {
        { id = "1", name = "Drink 1 (+50%)", short = "D1" },
        { id = "2", name = "Drink 2 (+150%)", short = "D2" },
        { id = "3", name = "Drink 3 (+300%)", short = "D3" },
    }
    local buyBtns = {}
    
    local function updateBuyDropdownText()
        if not gConfig.buyLuckDrinks then gConfig.buyLuckDrinks = {} end
        local selected = {}
        for _, d in ipairs(buyDrinkList) do
            if gConfig.buyLuckDrinks[d.id] then table.insert(selected, d.short) end
        end
        if #selected == 0 then
            selectedBuyDrinkBtn.Text = "None" .. (buyDrinkDdOpen and " ^" or " v")
            selectedBuyDrinkBtn.TextColor3 = C.text2
        elseif #selected == #buyDrinkList then
            selectedBuyDrinkBtn.Text = "All Drinks" .. (buyDrinkDdOpen and " ^" or " v")
            selectedBuyDrinkBtn.TextColor3 = C.gold
        else
            selectedBuyDrinkBtn.Text = table.concat(selected, ", ") .. (buyDrinkDdOpen and " ^" or " v")
            selectedBuyDrinkBtn.TextColor3 = C.gold
        end
        for _, d in ipairs(buyDrinkList) do
            local b = buyBtns[d.id]
            if b then
                if gConfig.buyLuckDrinks[d.id] then
                    b.TextColor3 = C.gold
                    b.BackgroundColor3 = COLORS.BG
                else
                    b.TextColor3 = C.text2
                    b.BackgroundColor3 = C.card
                end
            end
        end
    end
    
    selectedBuyDrinkBtn.MouseButton1Click:Connect(function()
        buyDrinkDdOpen = not buyDrinkDdOpen
        buyDrinkDdContainer.Visible = buyDrinkDdOpen
        updateBuyDropdownText()
    end)
    
    for _, opt in ipairs(buyDrinkList) do
        local btn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = C.card,
            Text = opt.name,
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, buyDrinkDdContainer)
        corner(4, btn); stroke(1, C.border, btn)
        buyBtns[opt.id] = btn
        
        btn.MouseButton1Click:Connect(function()
            if not gConfig.buyLuckDrinks then gConfig.buyLuckDrinks = {} end
            gConfig.buyLuckDrinks[opt.id] = not gConfig.buyLuckDrinks[opt.id]
            updateBuyDropdownText()
            saveConfig()
        end)
    end
    updateBuyDropdownText()
    _G.uiUpdaters["buyLuckDrinks"] = updateBuyDropdownText

    local function updateAutoBuyDrinksUI(state)
        gConfig.autoBuyDrinks = state
        autoBuyToggle.Text = state and "ON" or "OFF"
        autoBuyToggle.BackgroundColor3 = state and C.accent or COLORS.BG
    end
    _G.uiToggles["autoBuyDrinks"] = updateAutoBuyDrinksUI
    
    autoBuyToggle.MouseButton1Click:Connect(function()
        local newState = not gConfig.autoBuyDrinks
        updateAutoBuyDrinksUI(newState)
        saveConfig()
    end)

    -- 2. Auto-Consume Boost Multi-Select Card
    local autoConsumeCard = make("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
    }, tabShop)
    corner(6, autoConsumeCard); stroke(1, C.border, autoConsumeCard)
    
    make("TextLabel", {
        Size = UDim2.new(0.42, 0, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Auto-Consume Boost:",
        TextColor3 = C.text,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, autoConsumeCard)
    
    local autoConsumeToggle = make("TextButton", {
        Size = UDim2.new(0, 55, 0, 24),
        Position = UDim2.new(0.43, 0, 0.5, -12),
        BackgroundColor3 = gConfig.autoConsumeDrinks and C.accent or COLORS.BG,
        Text = gConfig.autoConsumeDrinks and "ON" or "OFF",
        TextColor3 = C.gold,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, autoConsumeCard)
    corner(5, autoConsumeToggle); stroke(1, C.border, autoConsumeToggle)
    
    local selectedConsumeBtn = make("TextButton", {
        Size = UDim2.new(0, 100, 0, 26),
        Position = UDim2.new(1, -112, 0.5, -13),
        BackgroundColor3 = COLORS.BG,
        Text = "None v",
        TextColor3 = C.gold,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        BorderSizePixel = 0,
    }, autoConsumeCard)
    corner(5, selectedConsumeBtn); stroke(1, C.border, selectedConsumeBtn)
    
    local consumeDdContainer = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = false,
    }, tabShop)
    list(nil, 4, consumeDdContainer)
    
    local consumeDdOpen = false
    local consumeDrinkList = {
        { id = "1", name = "Drink 1 (+50%)", short = "D1" },
        { id = "2", name = "Drink 2 (+150%)", short = "D2" },
        { id = "3", name = "Drink 3 (+300%)", short = "D3" },
    }
    local consumeBtns = {}
    
    local function updateConsumeDropdownText()
        if not gConfig.consumeLuckDrinks then gConfig.consumeLuckDrinks = {} end
        local selected = {}
        for _, d in ipairs(consumeDrinkList) do
            if gConfig.consumeLuckDrinks[d.id] then table.insert(selected, d.short) end
        end
        if #selected == 0 then
            selectedConsumeBtn.Text = "None" .. (consumeDdOpen and " ^" or " v")
            selectedConsumeBtn.TextColor3 = C.text2
        elseif #selected == #consumeDrinkList then
            selectedConsumeBtn.Text = "All Drinks" .. (consumeDdOpen and " ^" or " v")
            selectedConsumeBtn.TextColor3 = C.gold
        else
            selectedConsumeBtn.Text = table.concat(selected, ", ") .. (consumeDdOpen and " ^" or " v")
            selectedConsumeBtn.TextColor3 = C.gold
        end
        for _, d in ipairs(consumeDrinkList) do
            local b = consumeBtns[d.id]
            if b then
                if gConfig.consumeLuckDrinks[d.id] then
                    b.TextColor3 = C.gold
                    b.BackgroundColor3 = COLORS.BG
                else
                    b.TextColor3 = C.text2
                    b.BackgroundColor3 = C.card
                end
            end
        end
    end
    
    selectedConsumeBtn.MouseButton1Click:Connect(function()
        consumeDdOpen = not consumeDdOpen
        consumeDdContainer.Visible = consumeDdOpen
        updateConsumeDropdownText()
    end)
    
    for _, opt in ipairs(consumeDrinkList) do
        local btn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = C.card,
            Text = opt.name,
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratMedium,
            BorderSizePixel = 0,
        }, consumeDdContainer)
        corner(4, btn); stroke(1, C.border, btn)
        consumeBtns[opt.id] = btn
        
        btn.MouseButton1Click:Connect(function()
            if not gConfig.consumeLuckDrinks then gConfig.consumeLuckDrinks = {} end
            gConfig.consumeLuckDrinks[opt.id] = not gConfig.consumeLuckDrinks[opt.id]
            updateConsumeDropdownText()
            saveConfig()
        end)
    end
    updateConsumeDropdownText()
    _G.uiUpdaters["consumeLuckDrinks"] = updateConsumeDropdownText

    local function updateAutoConsumeDrinksUI(state)
        gConfig.autoConsumeDrinks = state
        autoConsumeToggle.Text = state and "ON" or "OFF"
        autoConsumeToggle.BackgroundColor3 = state and C.accent or COLORS.BG
    end
    _G.uiToggles["autoConsumeDrinks"] = updateAutoConsumeDrinksUI
    
    autoConsumeToggle.MouseButton1Click:Connect(function()
        local newState = not gConfig.autoConsumeDrinks
        updateAutoConsumeDrinksUI(newState)
        saveConfig()
    end)

        -- Luck Drink Purchases
    local drinks = {
        { id = "1", itemId = 359, name = "Luck Drink 1 (+50%)", cost = 12 },
        { id = "2", itemId = 360, name = "Luck Drink 2 (+150%)", cost = 25 },
        { id = "3", itemId = 361, name = "Luck Drink 3 (+300%)", cost = 65 }
    }

    for _, drk in ipairs(drinks) do
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabShop)
        corner(6, card); stroke(1, C.border, card)

        local nameLbl = make("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = drk.name,
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)

        local useBtn = make("TextButton", {
            Size = UDim2.new(0, 60, 0, 24),
            Position = UDim2.new(1, -158, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "Use (0)",
            TextColor3 = C.text2,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, card)
        corner(5, useBtn); stroke(1, C.border, useBtn)

        local buyBtn = make("TextButton", {
            Size = UDim2.new(0, 80, 0, 24),
            Position = UDim2.new(1, -92, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "Buy (" .. drk.cost .. " Diamonds)",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, card)
        corner(5, buyBtn); stroke(1, C.border, buyBtn)

        -- Periodically update owned drink counts
        task.spawn(function()
            while true do
                local inv = _G.AHUserInventoryCache
                local count = 0
                if inv and type(inv) == "table" then
                    for _, item in pairs(inv) do
                        if type(item) == "table" and tonumber(item.ItemId) == drk.itemId then
                            count = count + 1
                        end
                    end
                end
                useBtn.Text = "Use (" .. count .. ")"
                if count > 0 then
                    useBtn.TextColor3 = C.accent
                    useBtn.BackgroundColor3 = COLORS.BG
                else
                    useBtn.TextColor3 = C.text2
                    useBtn.BackgroundColor3 = C.card
                end
                task.wait(3.0)
            end
        end)

        useBtn.MouseButton1Click:Connect(function()
            local inv = _G.AHUserInventoryCache
            local targetGuid = nil
            if inv and type(inv) == "table" then
                for guid, item in pairs(inv) do
                    if type(item) == "table" and tonumber(item.ItemId) == drk.itemId then
                        targetGuid = guid
                        break
                    end
                end
            end
            if targetGuid then
                ReplicatedStorage.Events.UI.UseEnergyDrink:FireServer(targetGuid)
                showWorkshopPopup("Consumed " .. drk.name .. "!", C.green)
            else
                showWorkshopPopup("You don't own any " .. drk.name .. "!", C.red)
            end
        end)

        buyBtn.MouseButton1Click:Connect(function()
            local res = ReplicatedStorage.Events.EnergyShop.BuyDrink:InvokeServer(drk.id)
            if res and res.success then
                showWorkshopPopup("Purchased " .. drk.name .. "!", C.green)
            else
                showWorkshopPopup("Failed: " .. (res and res.error or "Not enough diamonds/No stock"), C.red)
            end
        end)
    end

    -- Section: Wrenches
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "WRENCH SHOP:",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, tabShop)

    local wrenchList = {
        { id = "0", name = "Rusty Wrench", cost = 0 },
        { id = "1", name = "Basic Wrench", cost = 0 },
        { id = "2", name = "Steel Wrench", cost = 1500 },
        { id = "3", name = "Precision Wrench", cost = 10000 },
        { id = "4", name = "Master Wrench", cost = 35000 }
    }

    for _, wr in ipairs(wrenchList) do
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabShop)
        corner(6, card); stroke(1, C.border, card)

        local nameLbl = make("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = wr.name,
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)

        local actionBtn = make("TextButton", {
            Size = UDim2.new(0, 90, 0, 24),
            Position = UDim2.new(1, -102, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "Checking...",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, card)
        corner(5, actionBtn); stroke(1, C.border, actionBtn)

        task.spawn(function()
            while true do
                local state = ReplicatedStorage.Events.WrenchShop.GetState:InvokeServer()
                if state then
                    local isEquipped = state.equipped == "Wrench" .. wr.id
                    local isOwned = state.owned and state.owned["Wrench" .. wr.id]
                    if isEquipped then
                        actionBtn.Text = "EQUIPPED"
                        actionBtn.TextColor3 = C.green
                        actionBtn.BackgroundColor3 = C.card
                    elseif isOwned then
                        actionBtn.Text = "EQUIP"
                        actionBtn.TextColor3 = C.text
                        actionBtn.BackgroundColor3 = COLORS.BG
                    else
                        actionBtn.Text = wr.cost == 0 and "EQUIP" or "BUY ($" .. wr.cost .. ")"
                        actionBtn.TextColor3 = C.gold
                        actionBtn.BackgroundColor3 = COLORS.BG
                    end
                end
                task.wait(2.5)
            end
        end)

        actionBtn.MouseButton1Click:Connect(function()
            local state = ReplicatedStorage.Events.WrenchShop.GetState:InvokeServer()
            local isOwned = state and state.owned and state.owned["Wrench" .. wr.id]
            if isOwned then
                local res = ReplicatedStorage.Events.WrenchShop.EquipWrench:InvokeServer("Wrench" .. wr.id)
                if res and res.success then showWorkshopPopup("Equipped " .. wr.name .. "!", C.green) end
            else
                local res = ReplicatedStorage.Events.WrenchShop.BuyWrench:InvokeServer("Wrench" .. wr.id)
                if res and res.success then showWorkshopPopup("Purchased " .. wr.name .. "!", C.green) end
            end
        end)
    end

    -- Section: Lockpicks
    make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = "LOCKPICK SHOP:",
        TextColor3 = C.text2,
        TextSize = 10,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, tabShop)

    local lockpickList = {
        { id = "0", name = "Rusty Lockpick", cost = 0 },
        { id = "1", name = "Basic Lockpick", cost = 0 },
        { id = "2", name = "Steel Lockpick", cost = 1500 },
        { id = "3", name = "Precision Lockpick", cost = 15000 },
        { id = "4", name = "Master Lockpick", cost = 50000 }
    }

    for _, lk in ipairs(lockpickList) do
        local card = make("Frame", {
            Size = UDim2.new(1, 0, 0, 38),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabShop)
        corner(6, card); stroke(1, C.border, card)

        local nameLbl = make("TextLabel", {
            Size = UDim2.new(0.6, 0, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1,
            Text = lk.name,
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)

        local actionBtn = make("TextButton", {
            Size = UDim2.new(0, 90, 0, 24),
            Position = UDim2.new(1, -102, 0.5, -12),
            BackgroundColor3 = COLORS.BG,
            Text = "Checking...",
            TextColor3 = C.gold,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
        }, card)
        corner(5, actionBtn); stroke(1, C.border, actionBtn)

        task.spawn(function()
            while true do
                local state = ReplicatedStorage.Events.LockpickShop.GetState:InvokeServer()
                if state then
                    local isEquipped = state.equipped == "Picklock" .. lk.id
                    local isOwned = state.owned and state.owned["Picklock" .. lk.id]
                    if isEquipped then
                        actionBtn.Text = "EQUIPPED"
                        actionBtn.TextColor3 = C.green
                        actionBtn.BackgroundColor3 = C.card
                    elseif isOwned then
                        actionBtn.Text = "EQUIP"
                        actionBtn.TextColor3 = C.text
                        actionBtn.BackgroundColor3 = COLORS.BG
                    else
                        actionBtn.Text = lk.cost == 0 and "EQUIP" or "BUY ($" .. lk.cost .. ")"
                        actionBtn.TextColor3 = C.gold
                        actionBtn.BackgroundColor3 = COLORS.BG
                    end
                end
                task.wait(2.5)
            end
        end)

        actionBtn.MouseButton1Click:Connect(function()
            local state = ReplicatedStorage.Events.LockpickShop.GetState:InvokeServer()
            local isOwned = state and state.owned and state.owned["Picklock" .. lk.id]
            if isOwned then
                local res = ReplicatedStorage.Events.LockpickShop.EquipLockpick:InvokeServer("Picklock" .. lk.id)
                if res and res.success then showWorkshopPopup("Equipped " .. lk.name .. "!", C.green) end
            else
                local res = ReplicatedStorage.Events.LockpickShop.BuyLockpick:InvokeServer("Picklock" .. lk.id)
                if res and res.success then showWorkshopPopup("Purchased " .. lk.name .. "!", C.green) end
            end
        end)
    end

    -- Background Auto-Buy (Stockpile) & Auto-Consume Loop
    task.spawn(function()
        local drinkItemIds = { ["1"] = 359, ["2"] = 360, ["3"] = 361 }
        local drinkCosts = { ["1"] = 12, ["2"] = 25, ["3"] = 65 }
        local lastBuyTime = 0
        
        while true do
            -- 1. Auto-Buy to Stockpile (Buys all selected drinks to inventory WITHOUT consuming)
            if gConfig.autoBuyDrinks and gConfig.buyLuckDrinks then
                if os.clock() - lastBuyTime >= 8 then
                    pcall(function()
                        local diams = lp:GetAttribute("Diamonds") or 0
                        -- Check selected drinks (highest tier 3 -> 2 -> 1)
                        for _, buyId in ipairs({"3", "2", "1"}) do
                            if gConfig.buyLuckDrinks[buyId] then
                                local cost = drinkCosts[buyId] or 12
                                if diams >= cost then
                                    local res = ReplicatedStorage.Events.EnergyShop.BuyDrink:InvokeServer(buyId)
                                    if res and res.success then
                                        lastBuyTime = os.clock()
                                        abLog("Stockpile: Bought Luck Drink " .. buyId .. " (Saved to Inventory)!", C.gold)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                end
            end
            
            -- 2. Auto-Consume Boost (Drinks highest selected available drink when active boost expires)
            if gConfig.autoConsumeDrinks and gConfig.consumeLuckDrinks then
                pcall(function()
                    local d1 = getActiveBoostTime(1)
                    local d2 = getActiveBoostTime(2)
                    local d3 = getActiveBoostTime(3)
                    
                    if d1 <= 10 and d2 <= 10 and d3 <= 10 then
                        local inv = _G.AHUserInventoryCache
                        local consumed = false
                        
                        -- Check selected consume drinks in priority order: 3 -> 2 -> 1
                        for _, consumeId in ipairs({"3", "2", "1"}) do
                            if gConfig.consumeLuckDrinks[consumeId] then
                                local targetItemId = drinkItemIds[consumeId] or 359
                                local targetGuid = nil
                                if inv and type(inv) == "table" then
                                    for guid, item in pairs(inv) do
                                        if type(item) == "table" and tonumber(item.ItemId) == targetItemId then
                                            targetGuid = guid
                                            break
                                        end
                                    end
                                end
                                
                                if targetGuid then
                                    ReplicatedStorage.Events.UI.UseEnergyDrink:FireServer(targetGuid)
                                    abLog("Auto-Consume: Drank Luck Drink " .. consumeId .. " from stockpile!", C.green)
                                    consumed = true
                                    task.wait(2.0)
                                    break
                                end
                            end
                        end
                        
                        -- If none in inventory and auto-buy is on, buy and consume highest enabled
                        if not consumed and gConfig.autoBuyDrinks and gConfig.buyLuckDrinks then
                            for _, consumeId in ipairs({"3", "2", "1"}) do
                                if gConfig.consumeLuckDrinks[consumeId] and gConfig.buyLuckDrinks[consumeId] then
                                    local res = ReplicatedStorage.Events.EnergyShop.BuyDrink:InvokeServer(consumeId)
                                    if res and res.success and res.inventoryGUID then
                                        ReplicatedStorage.Events.UI.UseEnergyDrink:FireServer(res.inventoryGUID)
                                        abLog("Auto-Consume: Bought & Drank Luck Drink " .. consumeId .. "!", C.green)
                                        task.wait(2.0)
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)
            end
            
            task.wait(3.0)
        end
    end)
end


-- EXCLUSIONS TAB
do

-- Build category -> items map from live ItemsData at runtime
local catMap   = {}
local catOrder = {}
local itemToCat = {} -- map item name to category for filtering
pcall(function()
    for _, data in pairs(ItemsData) do
        if type(data) == "table" then
            local cat  = tostring(data.Category or data.category or data.Type or "Misc")
            local name = data.Name or data.name
            if name and name ~= "" then
                itemToCat[name] = cat
                if not catMap[cat] then catMap[cat] = {} end
                table.insert(catMap[cat], name)
            end
        end
    end
    for cat, items in pairs(catMap) do
        table.sort(items)
        table.insert(catOrder, cat)
    end
    table.sort(catOrder)
end)

-- If ItemsData was empty (low-level executor), fall back to workspace scan
if #catOrder == 0 then
    pcall(function()
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("Model") then
                local base = desc.PrimaryPart or desc:FindFirstChild("Base")
                if base then
                    local iname = desc:GetAttribute("ItemName") or desc:GetAttribute("Name")
                    local cat   = desc:GetAttribute("Category") or "Misc"
                    if iname and iname ~= "" and not iname:lower():find("garage") then
                        itemToCat[iname] = cat
                        if not catMap[cat] then catMap[cat] = {} end
                        local found = false
                        for _, n in ipairs(catMap[cat]) do if n == iname then found = true; break end end
                        if not found then table.insert(catMap[cat], iname) end
                    end
                end
            end
        end
        for cat, items in pairs(catMap) do
            table.sort(items)
            table.insert(catOrder, cat)
        end
        table.sort(catOrder)
    end)
end

-- Safety: if still empty, add placeholder
if #catOrder == 0 then
    catOrder = { "No items found" }
    catMap["No items found"] = {}
end

-- Category cycle row: [<]  Category Name (count)  [>]
local catIdx = 1
local searchQuery = ""
local refreshItemList, rebuildChips

-- Protected Mutators Multi-Select Card (Choice 2)
local mutFilterCard = make("Frame", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
    ZIndex = 30,
}, tabExclusions)
corner(6, mutFilterCard)
stroke(1, C.border, mutFilterCard)

make("TextLabel", {
    Size = UDim2.new(0.48, 0, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    BackgroundTransparency = 1,
    Text = "Protected Gavel / Trophy Mutators:",
    TextColor3 = C.text,
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 31,
}, mutFilterCard)

local mutDropdownBtn = make("TextButton", {
    Size = UDim2.new(0.49, 0, 0, 22),
    Position = UDim2.new(0.49, 0, 0.5, -11),
    BackgroundColor3 = COLORS.BG,
    Text = "All (Default)",
    TextColor3 = C.gold,
    TextSize = 10,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = true,
    ZIndex = 31,
}, mutFilterCard)
corner(4, mutDropdownBtn)
stroke(1, C.border, mutDropdownBtn)

local mutDropdownList = make("ScrollingFrame", {
    Size = UDim2.new(0.96, 0, 0, 180),
    Position = UDim2.new(0.02, 0, 1, 4),
    BackgroundColor3 = Color3.fromRGB(22, 18, 32),
    BorderSizePixel = 1,
    BorderColor3 = C.border,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Visible = false,
    ZIndex = 50,
}, mutFilterCard)
corner(6, mutDropdownList)
pad(4, mutDropdownList)
list(Enum.HorizontalAlignment.Left, 2, mutDropdownList)

-- Dynamically fetch all mutators from the game's MutatorModule at runtime
local availableMutators = {}
local mutatorSet = {}
pcall(function()
    local mmMod = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("MutatorModule")
    local mm = mmMod and require(mmMod)
    if mm and type(mm._kindByName) == "table" then
        for mName, _ in pairs(mm._kindByName) do
            local str = tostring(mName)
            if str ~= "" and not mutatorSet[str] then
                mutatorSet[str] = true
                table.insert(availableMutators, str)
            end
        end
    end
end)
if #availableMutators == 0 then
    local fallbacks = {
        "Diamond", "Pure", "Gold", "Rainbow", "Corrupted", "Gem",
        "Secret", "Void", "Ancient", "Timeless", "Antique", "Redacted", "Seized", "Silver",
        "Dusty", "Saloon Sparkle", "Tumbleweed", "Gunsmoked", "Goldrush"
    }
    for _, f in ipairs(fallbacks) do table.insert(availableMutators, f) end
end
table.sort(availableMutators)
table.insert(availableMutators, 1, "None")

local function updateMutDropdownText()
    local selected = {}
    for _, m in ipairs(availableMutators) do
        if gConfig.targetExcludedMutators and gConfig.targetExcludedMutators[m] == true then
            table.insert(selected, m)
        end
    end
    if #selected == 0 then
        mutDropdownBtn.Text = "All (Default)"
        mutDropdownBtn.TextColor3 = C.gold
    elseif #selected <= 2 then
        mutDropdownBtn.Text = table.concat(selected, " / ")
        mutDropdownBtn.TextColor3 = C.accent
    else
        mutDropdownBtn.Text = tostring(#selected) .. " Selected"
        mutDropdownBtn.TextColor3 = C.accent
    end
end

-- Search filter input for the mutators list
local mutSearchBox = make("TextBox", {
    Size = UDim2.new(1, -8, 0, 22),
    BackgroundColor3 = Color3.fromRGB(32, 26, 46),
    Text = "",
    PlaceholderText = "Search mutation...",
    TextColor3 = C.text,
    PlaceholderColor3 = C.text2,
    Font = Enum.Font.Montserrat,
    TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
    BorderSizePixel = 0,
    ZIndex = 51,
}, mutDropdownList)
corner(4, mutSearchBox)
pad(2, mutSearchBox)

-- Clear All / Reset option
local clearBtn = make("TextButton", {
    Size = UDim2.new(1, -8, 0, 20),
    BackgroundColor3 = Color3.fromRGB(45, 20, 30),
    Text = "Reset (Protect All Gavels/Trophies)",
    TextColor3 = C.red,
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = true,
    ZIndex = 51,
}, mutDropdownList)
corner(4, clearBtn)

local optButtons = {}

clearBtn.MouseButton1Click:Connect(function()
    gConfig.targetExcludedMutators = {}
    saveConfig()
    updateMutDropdownText()
    for _, btn in ipairs(optButtons) do
        local optName = btn:GetAttribute("MutName")
        if optName then
            btn.Text = string.format(" [ ]  %s", optName == "None" and "None (No Mutation)" or optName)
            btn.TextColor3 = C.text2
            btn.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
        end
    end
    abLog("[Shield] Exclusions: Reset to protect all Gavels & Trophies.", C.green)
end)

for _, mName in ipairs(availableMutators) do
    local isChecked = gConfig.targetExcludedMutators and (gConfig.targetExcludedMutators[mName] == true)
    local optBtn = make("TextButton", {
        Size = UDim2.new(1, -8, 0, 20),
        BackgroundColor3 = isChecked and Color3.fromRGB(40, 25, 60) or Color3.fromRGB(28, 22, 40),
        Text = string.format(" [%s]  %s", isChecked and "X" or " ", mName == "None" and "None (No Mutation)" or mName),
        TextColor3 = isChecked and C.gold or C.text2,
        TextSize = 9,
        Font = Enum.Font.MontserratBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        ZIndex = 51,
    }, mutDropdownList)
    corner(4, optBtn)
    optBtn:SetAttribute("MutName", mName)
    table.insert(optButtons, optBtn)
    
    local capM = mName
    optBtn.MouseButton1Click:Connect(function()
        gConfig.targetExcludedMutators = gConfig.targetExcludedMutators or {}
        local newState = not gConfig.targetExcludedMutators[capM]
        if newState then
            gConfig.targetExcludedMutators[capM] = true
        else
            gConfig.targetExcludedMutators[capM] = nil
        end
        optBtn.Text = string.format(" [%s]  %s", newState and "X" or " ", capM == "None" and "None (No Mutation)" or capM)
        optBtn.TextColor3 = newState and C.gold or C.text2
        optBtn.BackgroundColor3 = newState and Color3.fromRGB(40, 25, 60) or Color3.fromRGB(28, 22, 40)
        updateMutDropdownText()
        saveConfig()
        if newState then
            abLog("[Shield] Gavels/Trophies with [" .. capM .. "] will be kept safe in bag.", C.gold)
        else
            abLog("ℹ Removed [" .. capM .. "] from protected mutators filter.", C.textMuted)
        end
    end)
end

-- Filter mutator list by search box
mutSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = mutSearchBox.Text:lower():match("^%s*(.-)%s*$")
    for _, btn in ipairs(optButtons) do
        local mName = btn:GetAttribute("MutName")
        if mName then
            if query == "" or mName:lower():find(query, 1, true) then
                btn.Visible = true
            else
                btn.Visible = false
            end
        end
    end
end)

local function refreshMutButtons()
    updateMutDropdownText()
    for _, btn in ipairs(optButtons) do
        local mName = btn:GetAttribute("MutName")
        if mName then
            local isChecked = gConfig.targetExcludedMutators and (gConfig.targetExcludedMutators[mName] == true)
            btn.Text = string.format(" [%s]  %s", isChecked and "X" or " ", mName == "None" and "None (No Mutation)" or mName)
            btn.TextColor3 = isChecked and C.gold or C.text2
            btn.BackgroundColor3 = isChecked and Color3.fromRGB(40, 25, 60) or Color3.fromRGB(28, 22, 40)
        end
    end
end
_G.refreshMutDropdown = refreshMutButtons
refreshMutButtons()

mutDropdownBtn.MouseButton1Click:Connect(function()
    mutDropdownList.Visible = not mutDropdownList.Visible
end)

-- [Scale] Uranium Min Weight (kg) Config Card
-- Min Uranium Ore Weight card removed for public release

-- Exclusions action row
local exclActionRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
}, tabExclusions)
list(nil, 6, exclActionRow).FillDirection = Enum.FillDirection.Horizontal

local restoreExclBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = C.card,
    Text = "↺ Restore Default Exclusions",
    TextColor3 = C.gold,
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, exclActionRow)
corner(5, restoreExclBtn); stroke(1, C.border, restoreExclBtn)

local clearExclBtn = make("TextButton", {
    Size = UDim2.new(0.5, -3, 1, 0),
    BackgroundColor3 = C.card,
    Text = "Clear All Exclusions",
    TextColor3 = C.red,
    TextSize = 9,
    Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0,
    AutoButtonColor = false,
}, exclActionRow)
corner(5, clearExclBtn); stroke(1, C.border, clearExclBtn)

-- Search container
local searchFrame = make("Frame", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
}, tabExclusions)
corner(6, searchFrame); pad(2, searchFrame)
stroke(1, C.border, searchFrame)

local searchBox = make("TextBox", {
    Size = UDim2.new(1, -12, 1, 0),
    Position = UDim2.new(0, 6, 0, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = "Search item or category...",
    TextColor3 = C.text,
    PlaceholderColor3 = C.text2,
    Font = Enum.Font.Montserrat,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
}, searchFrame)

-- Category cycle row: [<]  Category Name (count)  [>]
local cycleRow = make("Frame", {
    Size = UDim2.new(1, 0, 0, 24),
    BackgroundTransparency = 1,
}, tabExclusions)
list(nil, 0, cycleRow).FillDirection = Enum.FillDirection.Horizontal

local prevBtn = make("TextButton", {
    Size = UDim2.new(0, 24, 1, 0),
    BackgroundColor3 = C.card,
    Text = "<",
    TextColor3 = C.text,
    TextSize = 12, Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0, AutoButtonColor = false,
}, cycleRow)
corner(6, prevBtn)

local catLabel = make("TextButton", {
    Size = UDim2.new(1, -48, 1, 0),
    BackgroundColor3 = C.card,
    Text = "",
    TextColor3 = C.accent,
    TextSize = 9, Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0, AutoButtonColor = false,
}, cycleRow)
corner(6, catLabel)
stroke(1, C.border, catLabel)

local nextBtn = make("TextButton", {
    Size = UDim2.new(0, 24, 1, 0),
    BackgroundColor3 = C.card,
    Text = ">",
    TextColor3 = C.text,
    TextSize = 12, Font = Enum.Font.MontserratBold,
    BorderSizePixel = 0, AutoButtonColor = false,
}, cycleRow)
corner(6, nextBtn)

local function updateCatLabel()
    local cat = catOrder[catIdx] or "None"
    local cnt = catMap[cat] and #catMap[cat] or 0
    catLabel.Text = cat .. " (" .. cnt .. ")"
end

-- Item list (always visible, fixed height scrollable)
local ITEM_ROW_H = 22
local itemScrollFrame = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 150),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, tabExclusions)
corner(6, itemScrollFrame); pad(3, itemScrollFrame)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, itemScrollFrame)

local itemRowInstances = {}

-- Excluded items chip list label
make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 14),
    BackgroundTransparency = 1,
    Text = "Excluded items (This Category):",
    TextColor3 = C.accent,
    TextSize = 9, Font = Enum.Font.MontserratBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, tabExclusions)

local chipScroll = make("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 68),
    BackgroundColor3 = C.card,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    Active = true,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, tabExclusions)
corner(6, chipScroll); pad(3, chipScroll)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, chipScroll)

local chipInstances = {}
local emptyChipLabel = make("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundTransparency = 1,
    Text = "No exclusions matching view.",
    TextColor3 = C.text2,
    TextSize = 9, Font = Enum.Font.Montserrat,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 9999,
}, chipScroll)

rebuildChips = function()
    for _, c in ipairs(chipInstances) do c:Destroy() end
    chipInstances = {}
    local count = 0
    local cat = catOrder[catIdx] or ""
    
    for name, _ in pairs(gConfig.excludedItems) do
        local itemCat = itemToCat[name] or "Misc"
        local matchesSearch = searchQuery == "" or name:lower():find(searchQuery) or itemCat:lower():find(searchQuery)
        
        -- If searching, show any match. If not searching, restrict to current category.
        local shouldShow = false
        if searchQuery ~= "" then
            shouldShow = matchesSearch
        else
            shouldShow = (itemCat == cat)
        end

        if shouldShow then
            count = count + 1
            local chip = make("Frame", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundColor3 = Color3.fromRGB(38, 22, 55),
                BorderSizePixel = 0, LayoutOrder = count,
            }, chipScroll)
            corner(5, chip); stroke(1, Color3.fromRGB(110, 50, 190), chip)
            make("TextLabel", {
                Size = UDim2.new(1, -28, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = name .. " (" .. itemCat .. ")", TextColor3 = C.text,
                TextSize = 9, Font = Enum.Font.Montserrat,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }, chip)
            local xBtn = make("TextButton", {
                Size = UDim2.new(0, 16, 0, 14),
                Position = UDim2.new(1, -20, 0.5, -7),
                BackgroundColor3 = C.red,
                Text = "x", TextColor3 = Color3.fromRGB(255,255,255),
                TextSize = 8, Font = Enum.Font.MontserratBold,
                BorderSizePixel = 0, AutoButtonColor = false,
            }, chip)
            corner(4, xBtn)
            local cn = name
            xBtn.MouseButton1Click:Connect(function()
                gConfig.excludedItems[cn] = nil
                rebuildChips()
                refreshItemList()
                saveConfig()
            end)
            table.insert(chipInstances, chip)
        end
    end
    emptyChipLabel.Visible = (count == 0)
end

refreshItemList = function()
    if not gConfig.excludedItems then gConfig.excludedItems = {} end
    for _, r in ipairs(itemRowInstances) do r:Destroy() end
    itemRowInstances = {}
    
    local showIdx = 0
    
    -- Helper to create a clickable item row
    local function makeRow(itemName, displayText)
        showIdx = showIdx + 1
        local excluded = gConfig.excludedItems[itemName] == true
        local row = make("Frame", {
            Size = UDim2.new(1, 0, 0, ITEM_ROW_H),
            BackgroundColor3 = excluded and Color3.fromRGB(35, 18, 50) or C.card,
            BorderSizePixel = 0, LayoutOrder = showIdx,
        }, itemScrollFrame)
        corner(5, row)
        if excluded then stroke(1, Color3.fromRGB(110, 50, 190), row) end
        
        make("TextLabel", {
            Size = UDim2.new(0, 22, 1, 0),
            Position = UDim2.new(0, 4, 0, 0),
            BackgroundTransparency = 1,
            Text = excluded and "[X]" or "[ ]",
            TextColor3 = excluded and C.accent or C.text2,
            TextSize = 9, Font = Enum.Font.MontserratBold,
        }, row)
        make("TextLabel", {
            Size = UDim2.new(1, -30, 1, 0),
            Position = UDim2.new(0, 28, 0, 0),
            BackgroundTransparency = 1,
            Text = displayText,
            TextColor3 = excluded and C.text or C.text2,
            TextSize = 9,
            Font = excluded and Enum.Font.MontserratBold or Enum.Font.Montserrat,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
        local btn = make("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Text = "", ZIndex = 2,
        }, row)
        local capName = itemName
        btn.MouseEnter:Connect(function()
            if not gConfig.excludedItems[capName] then
                row.BackgroundColor3 = C.cardHover
            end
        end)
        btn.MouseLeave:Connect(function()
            row.BackgroundColor3 = gConfig.excludedItems[capName] == true
                and Color3.fromRGB(35, 18, 50) or C.card
        end)
        btn.MouseButton1Click:Connect(function()
            if gConfig.excludedItems[capName] then
                gConfig.excludedItems[capName] = nil
            else
                gConfig.excludedItems[capName] = true
            end
            rebuildChips()
            refreshItemList()
            saveConfig()
        end)
        table.insert(itemRowInstances, row)
    end

    if searchQuery ~= "" then
        -- Search across ALL categories
        local seen = {}
        for _, cat in ipairs(catOrder) do
            local items = catMap[cat] or {}
            for _, itemName in ipairs(items) do
                if not seen[itemName] and itemName:lower():find(searchQuery) then
                    seen[itemName] = true
                    makeRow(itemName, itemName .. "  [" .. cat .. "]")
                end
            end
        end
    else
        -- Normal mode: show current category only
        local cat   = catOrder[catIdx] or ""
        local items = catMap[cat] or {}
        for _, itemName in ipairs(items) do
            makeRow(itemName, itemName)
        end
    end
end

-- Wire cycle buttons
prevBtn.MouseButton1Click:Connect(function()
    catIdx = catIdx - 1
    if catIdx < 1 then catIdx = #catOrder end
    updateCatLabel()
    refreshItemList()
    rebuildChips()
end)
nextBtn.MouseButton1Click:Connect(function()
    catIdx = catIdx + 1
    if catIdx > #catOrder then catIdx = 1 end
    updateCatLabel()
    refreshItemList()
    rebuildChips()
end)
prevBtn.MouseEnter:Connect(function() prevBtn.BackgroundColor3 = C.cardHover end)
prevBtn.MouseLeave:Connect(function() prevBtn.BackgroundColor3 = C.card end)
nextBtn.MouseEnter:Connect(function() nextBtn.BackgroundColor3 = C.cardHover end)
nextBtn.MouseLeave:Connect(function() nextBtn.BackgroundColor3 = C.card end)

-- Wire search box
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchQuery = searchBox.Text:lower()
    refreshItemList()
    rebuildChips()
end)

updateCatLabel()
refreshItemList()
rebuildChips()

_G.rebuildExclusionChips = rebuildChips
_G.refreshExclusionItemList = refreshItemList

restoreExclBtn.MouseButton1Click:Connect(function()
    table.clear(gConfig.excludedItems)
    pcall(function()
        for id, data in pairs(ItemsData) do
            if type(data) == "table" then
                local name = data.Name or data.name or ""
                local category = (data.Category or data.category or data.Type or ""):lower()
                local lowerName = name:lower()
                
                local isTrophy = lowerName:find("trophy") or category:find("trophy") or lowerName:find("gavel")
                local isAccessory = category:find("accessory") or category:find("accessories")
                local isSafe = lowerName:find("safe") or lowerName:find("lockbox")
                local isWheel = (lowerName:find("wheel") or category:find("wheel")) and not lowerName:find("wheelbarrow")
                local isCert = lowerName:find("certificate") or category:find("certificate") or lowerName:find("authenticity")
                local isPart = (lowerName:find("part") or category:find("part")) and not lowerName:find("particle")
                local isLucky = lowerName:find("luck drink") or lowerName:find("luck_drink") or lowerName:find("luckdrink")
                local isBrewOrQuestTool = lowerName:find("cauldron skull") or lowerName:find("cauldron bag") or lowerName:find("gravedigger shovel") or lowerName:find("uranium ore") or category == "tool"
                if isTrophy or isAccessory or isSafe or isWheel or isCert or isPart or isLucky or isBrewOrQuestTool then
                    gConfig.excludedItems[name] = true
                end
            end
        end
    end)
    pcall(function()
        for id, data in pairs(ItemsData) do
            if type(data) == "table" then
                local name = data.Name or data.name or ""
                local lower = name:lower()
                local cat = (data.Category or data.category or ""):lower()
                if lower:find("luck drink") or lower:find("cauldron skull") or lower:find("cauldron bag") or lower:find("gravedigger shovel") or lower:find("uranium ore") or cat == "tool" then
                    gConfig.excludedItems[name] = true
                end
            end
        end
    end)
    gConfig.targetExcludedMutators = {}
    if refreshMutButtons then refreshMutButtons() end
    rebuildChips()
    refreshItemList()
    saveConfig()
    restoreExclBtn.Text = "Defaults Restored!"
    task.delay(1.5, function()
        if restoreExclBtn and restoreExclBtn.Parent then
            restoreExclBtn.Text = "↺ Restore Default Exclusions"
        end
    end)
end)

clearExclBtn.MouseButton1Click:Connect(function()
    table.clear(gConfig.excludedItems)
    gConfig.targetExcludedMutators = {}
    if refreshMutButtons then refreshMutButtons() end
    rebuildChips()
    refreshItemList()
    saveConfig()
    clearExclBtn.Text = "Cleared All!"
    task.delay(1.5, function()
        if clearExclBtn and clearExclBtn.Parent then
            clearExclBtn.Text = "Clear All Exclusions"
        end
    end)
end)

end -- end Exclusions do block




-- ── 2. BACKGROUND UPDATES & HANDLERS ─────────────────

-- =========================================================================
-- NPC COLLISION BYPASS ("TEMBUS NPC" - FULL PASS-THROUGH)
-- =========================================================================
local npcCollisionParts = {} -- [BasePart] = true (stored for per-frame Stepped collision suppression)
local npcModelsTracked = {}  -- [Model] = true

local function isNPCModel(model)
    if not model or not model:IsA("Model") then return false end
    if model == LocalPlayer.Character then return false end
    if Players:GetPlayerFromCharacter(model) then return false end

    local name = model.Name:lower()
    if name == "auctioneer" or name:find("bidder") or name:find("shopper") or name:find("merchant")
        or name:find("npc") or name:find("dealer") or name:find("cashier") or name:find("conductor")
        or name:find("monkey") then
        return true
    end

    local parent = model.Parent
    if parent and (parent.Name == "NPCSpawns" or parent.Name == "NPCs" or parent.Name == "Bidders" or parent.Name == "Garages" or parent.Name == "_Debris") then
        return true
    end

    if CollectionService:HasTag(model, "NPC") then
        return true
    end

    if model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController") then
        return true
    end

    return false
end

local function applyNPCPartNoclip(part)
    if part:IsA("BasePart") then
        npcCollisionParts[part] = true
        if gConfig.noNPCCollision ~= false then
            pcall(function()
                part.CanCollide = false
            end)
        end
    end
end

local function makeNPCModelNoclip(model)
    if not model or npcModelsTracked[model] then return end
    npcModelsTracked[model] = true

    -- Anchor stationary NPC root/torso so they never fall through terrain when CanCollide is false
    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    if hrp and hrp:IsA("BasePart") then
        pcall(function()
            hrp.Anchored = true
        end)
    end

    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            applyNPCPartNoclip(desc)
        end
    end

    table.insert(cleanUpSignals, model.DescendantAdded:Connect(function(desc)
        if desc:IsA("BasePart") then
            applyNPCPartNoclip(desc)
        end
    end))
end

local function scanAllNPCs()
    -- 1. Garages (Auctioneers & NPCSpawns bidders)
    local debris = workspace:FindFirstChild("_Debris")
    local garages = debris and debris:FindFirstChild("Garages")
    if garages then
        for _, g in ipairs(garages:GetChildren()) do
            local auc = g:FindFirstChild("Auctioneer")
            if auc and auc:IsA("Model") then
                makeNPCModelNoclip(auc)
            end
            local spawns = g:FindFirstChild("NPCSpawns")
            if spawns then
                for _, b in ipairs(spawns:GetChildren()) do
                    if b:IsA("Model") then
                        makeNPCModelNoclip(b)
                    elseif b:IsA("BasePart") then
                        applyNPCPartNoclip(b)
                    end
                end
            end
            local bidders = g:FindFirstChild("Bidders")
            if bidders then
                for _, b in ipairs(bidders:GetChildren()) do
                    if b:IsA("Model") then
                        makeNPCModelNoclip(b)
                    elseif b:IsA("BasePart") then
                        applyNPCPartNoclip(b)
                    end
                end
            end
        end
    end

    -- 2. Workspace NPCs folder
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, m in ipairs(npcsFolder:GetChildren()) do
            if m:IsA("Model") then
                makeNPCModelNoclip(m)
            end
        end
    end

    -- 3. Tagged NPCs via CollectionService
    pcall(function()
        for _, inst in ipairs(CollectionService:GetTagged("NPC")) do
            if inst:IsA("Model") then
                makeNPCModelNoclip(inst)
            elseif inst:IsA("BasePart") then
                applyNPCPartNoclip(inst)
            end
        end
    end)

    -- 4. Deep scan: All Humanoid NPC models across all workspace folders (Mall, Shops, Areas, Quests, Garages)
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Humanoid") then
            local model = desc.Parent
            if model and model:IsA("Model") and not Players:GetPlayerFromCharacter(model) then
                makeNPCModelNoclip(model)
            end
        end
    end
end
_G.scanAllNPCs = scanAllNPCs

-- Hook RunService.Stepped: Enforce CanCollide = false every single physics frame
table.insert(cleanUpSignals, RunService.Stepped:Connect(function()
    if gConfig.noNPCCollision == false then return end
    for part in pairs(npcCollisionParts) do
        if part.Parent then
            if part.CanCollide then
                part.CanCollide = false
            end
        else
            npcCollisionParts[part] = nil
        end
    end
end))

-- Hook workspace.DescendantAdded: Instantly catch newly spawned auction NPCs before vehicle arrives
table.insert(cleanUpSignals, workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") and isNPCModel(desc) then
        makeNPCModelNoclip(desc)
    elseif desc:IsA("BasePart") then
        local pModel = desc:FindFirstAncestorOfClass("Model")
        if pModel and isNPCModel(pModel) then
            applyNPCPartNoclip(desc)
        end
    end
end))

-- Background periodic sweep
task.spawn(function()
    pcall(scanAllNPCs)
    while true do
        task.wait(2.0)
        pcall(scanAllNPCs)
    end
end)

local function doScan()
    if scanning then return end; scanning = true
    task.spawn(function()
        local ok, result = pcall(scanAllAreas); scanning = false
        if ok and result then 
            scanData = result
        end
    end)
end


table.insert(cleanUpSignals, UserInputService.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == currentKeybind then
        if gConfig.disable3DRendering then
            if _G.exitOvernightMode then
                _G.exitOvernightMode()
            elseif _G.uiToggles["disable3DRendering"] then
                _G.uiToggles["disable3DRendering"](false)
            end
            return
        end
        if not processed then
            toggleUI(Win)
        end
    end
end))

local draggingMain, dragStartMain, dragStartCenter = false, nil, nil
TitleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true
        dragStartMain = inp.Position
        dragStartCenter = Vector2.new(
            Win.AbsolutePosition.X + (Win.AbsoluteSize.X / 2),
            Win.AbsolutePosition.Y + (Win.AbsoluteSize.Y / 2)
        )
    end
end)
table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        draggingMain = false
    end
end))
table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
    if draggingMain and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
        local delta = inp.Position - dragStartMain
        local targetX = dragStartCenter.X + delta.X
        local targetY = dragStartCenter.Y + delta.Y

        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local halfW = Win.AbsoluteSize.X / 2
        local halfH = Win.AbsoluteSize.Y / 2
        local minX = math.min(halfW, vp.X / 2)
        local maxX = math.max(halfW, vp.X - halfW)
        local minY = math.min(halfH, vp.Y / 2)
        local maxY = math.max(halfH, vp.Y - halfH)

        Win.Position = UDim2.new(0, math.clamp(targetX, minX, maxX), 0, math.clamp(targetY, minY, maxY))
    end
end))

-- Quick Win controller: owns only the first bid, pause and temporary zone exit.
do
    local installQuickWin = (function()
-- First-bid, server-acknowledged pause, then leave the zone until the server awards pickup.
-- Returns a factory so the same controller can be exercised independently through MCP.
return function(context)
    local player, events = context.player, context.events
    local state, config = context.state, context.config
    local controller = {connections = {}, phase = "idle", destroyed = false}
    local round, holdConnection
    local function log(message)
        if context.log then context.log("Quick Win: " .. message) end
    end
    local function current()
        return not controller.destroyed and (not context.isCurrent or context.isCurrent())
    end
    local function characterParts()
        local character = player.Character
        return character, character and character:FindFirstChildOfClass("Humanoid"),
            character and character:FindFirstChild("HumanoidRootPart")
    end
    local function releasePause()
        if round and round.requestedPause then
            round.requestedPause = false
            pcall(function() events.RequestAuctionPause:FireServer(false) end)
        end
    end
    local function stopHolding()
        if holdConnection then holdConnection:Disconnect(); holdConnection = nil end
    end
    local function returnToZone()
        if round and round.outside and round.character == player.Character then
            local _, humanoid, root = characterParts()
            if root and humanoid and humanoid.Health > 0 and not humanoid.SeatPart then
                root.CFrame = round.returnFrame
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end
    function controller:Cancel(reason, resume)
        if not round then return end
        stopHolding()
        if self.phase == "won" then
            releasePause()
            state.quickWinActive = false
            return
        end
        returnToZone()
        releasePause()
        state.quickWinActive = false
        state.quickWinHandled = false
        state.quickWinMinBidBlocked = false
        self.phase = "fallback"
        round.cancelled = true
        round.status, round.reason = "cancelled", reason
        if reason then log(reason) end
        if resume and current() and config.autoBidEnabled == true and config.quickWinAuction ~= true
            and context.resumeBidding then context.resumeBidding() end
    end
    function controller:Destroy()
        if self.destroyed then return end
        self:Cancel(nil, false)
        self.destroyed = true
        for _, connection in ipairs(self.connections) do connection:Disconnect() end
    end
    local function listen(name, callback)
        local remote = events:FindFirstChild(name)
        if not remote then return false end
        controller.connections[#controller.connections + 1] = remote.OnClientEvent:Connect(function(...)
            if not current() then controller:Destroy(); return end
            local ok, problem = pcall(callback, ...)
            if not ok then controller:Cancel("stopped: " .. tostring(problem), true) end
        end)
        return true
    end
    local function beginRound(garage)
        local terminal = controller.phase == "won" or controller.phase == "fallback" or controller.phase == "skipped"
        if round and round.garage == garage and not terminal then return end
        if round then controller:Cancel(nil, false) end
        round = {garage = garage, status = "watching", started = os.clock()}
        controller.lastRun = round
        controller.phase = "watching"
        state.quickWinHandled = nil
        state.quickWinMinBidBlocked = false
    end
    local function skipCurrentAuction(reason)
        local attempt = round
        if not attempt then return end
        if state.pickupPhase then controller:Cancel("pickup is active; leaving it undisturbed.", false); return end
        local leave = events:FindFirstChild("LeaveAuction")
        if not leave then controller:Cancel("cannot skip: leave service unavailable.", false); return end
        controller.phase, attempt.status = "skipping", "skipping"
        state.quickWinActive, state.quickWinHandled = true, true
        state.leavingAuction = true
        state.leaveStartedAt = os.clock()
        state.lastSkippedGarage = attempt.garage
        state.lastSkippedAt = os.clock()
        if context.stopBidding then context.stopBidding() end
        stopHolding()
        returnToZone()
        releasePause()
        local key = attempt.garage:GetAttribute("GUID") or attempt.garage.Name
        _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
        _G.AHGarageCooldowns[key] = os.clock() + 60
        log(reason or "opening price below your minimum; leaving for the next eligible garage.")
        task.spawn(function()
            local ok, problem = pcall(function() return leave:InvokeServer() end)
            local waitStart = os.clock()
            while player:GetAttribute("InAuction") == true and (os.clock() - waitStart < 0.8) do
                task.wait(0.05)
            end
            state.leavingAuction = false
            state.leaveStartedAt = nil
            -- A delayed response must never clear a newer auction or an unloaded hub.
            if round ~= attempt or attempt.cancelled or not current() then
                if not round or round == attempt or attempt.cancelled then
                    state.quickWinActive = false
                    state.auctionOpen = false
                    state.startingAuction = false
                    state.biddingUIOpen = false
                end
                return
            end
            if not ok then
                state.auctionOpen = false
                state.startingAuction = false
                state.biddingUIOpen = false
                controller:Cancel("could not leave auction: " .. tostring(problem), false)
                return
            end
            state.auctionOpen, state.biddingUIOpen, state.startingAuction, state.weAreWinning = false, false, false, false
            state.activeLot, state.activeLotData, state.activeGarageInstance = nil, nil, nil
            state.currentBid = 0
            state.quickWinActive, state.quickWinHandled = false, true
            if _G.AHLastTargetLot == attempt.garage then _G.AHLastTargetLot = nil end
            controller.phase, attempt.status = "skipped", "skipped"
        end)
    end
    local function exitZone()
        local attempt = round
        local character, humanoid, root = characterParts()
        local zone = attempt.garage and attempt.garage:FindFirstChild("AuctionZone")
        if not root or not humanoid or not zone or not zone:IsA("BasePart") then
            controller:Cancel("zone or character unavailable; attempt stopped.", true)
            return
        end
        attempt.character, attempt.returnFrame = character, root.CFrame
        humanoid.Sit = false
        local unseatDeadline = os.clock() + 1.5
        while humanoid.SeatPart and current() and os.clock() < unseatDeadline do
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.wait(0.05)
        end
        if round ~= attempt or attempt.cancelled or not current() or config.quickWinAuction ~= true then return end
        if humanoid.SeatPart then controller:Cancel("could not leave the seat; attempt stopped.", true); return end
        local localRoot = zone.CFrame:PointToObjectSpace(root.Position)
        local sign = localRoot.X < 0 and -1 or 1
        local position = zone.CFrame:PointToWorldSpace(Vector3.new(sign * (zone.Size.X / 2 + 25), localRoot.Y, 0))
        local ignore = RaycastParams.new()
        ignore.FilterType = Enum.RaycastFilterType.Exclude
        ignore.FilterDescendantsInstances = {character, attempt.garage}
        ignore.RespectCanCollide = true
        local ground = workspace:Raycast(position + Vector3.new(0, 5, 0), Vector3.new(0, -25, 0), ignore)
        if ground then position = Vector3.new(position.X, ground.Position.Y + humanoid.HipHeight + root.Size.Y / 2, position.Z) end
        local _, yaw = root.CFrame:ToOrientation()
        attempt.outsideFrame = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
        attempt.outside, attempt.exitedAt = true, os.clock()
        attempt.status = "outside"
        controller.phase = "outside"
        root.CFrame = attempt.outsideFrame
        root.AssemblyLinearVelocity = Vector3.zero
        holdConnection = game:GetService("RunService").Heartbeat:Connect(function()
            if round ~= attempt or attempt.cancelled or controller.phase ~= "outside" then stopHolding(); return end
            if not current() or config.quickWinAuction ~= true or player.Character ~= character or humanoid.Health <= 0 then
                controller:Cancel("cancelled; pause released.", false)
                return
            end
            local localPosition = zone.CFrame:PointToObjectSpace(root.Position)
            if math.abs(localPosition.X) < zone.Size.X / 2 + 5 then root.CFrame = attempt.outsideFrame end
            root.AssemblyLinearVelocity = Vector3.zero
        end)
        log("first bid confirmed. Staying outside the zone for the 10-second finish.")
        task.delay(16, function()
            if round == attempt and current() and controller.phase == "outside" then
                controller:Cancel("no server win confirmed; attempt stopped.", true)
            end
        end)
    end
    listen("ToggleAuctionArea", function(inside, garage)
        if config.quickWinAuction ~= true or typeof(garage) ~= "Instance" then return end
        if inside then beginRound(garage)
        elseif round and round.garage == garage and controller.phase == "outside" then round.zoneExitConfirmed = true end
    end)
    listen("UpdateCurrentWinningBid", function(amount, winner, who, nextBid, garage)
        if config.quickWinAuction ~= true or typeof(garage) ~= "Instance" then return end
        local terminal = controller.phase == "won" or controller.phase == "fallback" or controller.phase == "skipped"
        -- A new auction can reuse the same garage Instance. Only its Starting update
        -- may rearm a finished attempt; ordinary NPC updates must not rearm it.
        if winner == "Starting" and terminal then beginRound(garage) end
        if not round or round.garage ~= garage then
            beginRound(garage)
            if winner ~= "Starting" then
                skipCurrentAuction("another bidder was already leading; leaving this garage for the next eligible one.")
                return
            end
        end
        local attempt = round
        if controller.phase == "watching" then
            -- Allow bidding even if an NPC or server started the opening bid, as long as it's within limits
            if winner ~= "Starting" and winner == LocalPlayer.Name then
                -- We are already the winning bidder!
                controller.phase, attempt.status = "pause-requested", "pause-requested"
                attempt.requestedPause = true
                events.RequestAuctionPause:FireServer(true)
                return
            end
            if context.allowed then
                local allowed, reason = context.allowed(garage, amount, nextBid)
                if not allowed then
                    if reason == "below-minimum" then
                        skipCurrentAuction("opening price below your minimum; leaving for the next eligible garage.")
                    else
                        skipCurrentAuction("garage is outside your selected garage settings; skipping it.")
                    end
                    return
                end
            end
            if state.pickupPhase or state.quickWinMinBidBlocked or _G.isMiningActive or _G.isFreightCollecting
                or _G.isPickupActive or _G.questTpInProgress then
                controller:Cancel("another activity is active; skipping this attempt.", true)
                return
            end
            local price = tonumber(nextBid) or tonumber(amount)
            -- EntryCurrency pays admission; auction bids use Cash, including Halloween.
            local balance = tonumber(player:GetAttribute("Cash"))
            if not price or price ~= price or price == math.huge or price < 0 then
                controller:Cancel("invalid first bid: " .. tostring(nextBid), false)
                return
            end
            if context.maxBid and price > context.maxBid then
                controller:Cancel(string.format("first bid $%.2f exceeds configured cap $%.2f.", price, context.maxBid), false)
                return
            end
            if not balance then
                controller:Cancel("Cash balance unavailable; attempt stopped.", false)
                return
            end
            if price > balance then
                controller:Cancel(string.format("first bid $%.2f exceeds Cash balance $%.2f.", price, balance), false)
                return
            end
            state.quickWinActive, state.quickWinHandled = true, true
            if context.stopBidding then context.stopBidding() end
            attempt.bidAmount, attempt.status = price, "bid-requested"
            controller.phase = "bid-requested"
            events.Bid:FireServer()
            task.delay(3, function()
                if round == attempt and current() and controller.phase == "bid-requested" then
                    controller:Cancel("first bid was not acknowledged; attempt stopped.", true)
                end
            end)
        elseif controller.phase == "bid-requested" then
            if winner ~= player.Name and who ~= player then
                skipCurrentAuction("another bidder took the lead before the pause; skipping this garage.")
                return
            end
            controller.phase, attempt.status = "pause-requested", "pause-requested"
            attempt.requestedPause = true
            events.RequestAuctionPause:FireServer(true)
            task.delay(2, function()
                if round == attempt and current() and controller.phase == "pause-requested" then
                    controller:Cancel("pause was not acknowledged; attempt stopped.", true)
                end
            end)
        elseif (controller.phase == "pause-requested" or controller.phase == "outside")
            and winner ~= player.Name and who ~= player then
            controller:Cancel("another bid arrived; attempt stopped.", true)
        end
    end)
    listen("AuctionPaused", function(paused, garage)
        if not round or (garage and round.garage ~= garage) then return end
        if paused and controller.phase == "pause-requested" then
            controller.phase = "exiting"
            task.spawn(function()
                local ok, problem = pcall(exitZone)
                if not ok then controller:Cancel("could not exit: " .. tostring(problem), true) end
            end)
        elseif not paused and (controller.phase == "outside" or controller.phase == "exiting") then
            controller:Cancel("pause ended early; returned to the auction.", true)
        end
    end)
    listen("AuctionPickupStart", function()
        if not round or controller.phase ~= "outside" then return end
        controller.phase, round.status = "won", "won"
        stopHolding()
        returnToZone()
        releasePause()
        state.quickWinActive = false
        state.quickWinHandled = true
        state.weAreWinning = true
        if context.onWin then context.onWin(round.garage) end
        log("server awarded the garage. Existing pickup automation will handle the items.")
    end)
    if not events:FindFirstChild("RequestAuctionPause") or not events:FindFirstChild("AuctionPaused") then
        controller:Destroy()
        log("pause service unavailable; feature disabled.")
    end
    return controller
end

    end)()
    AB.quickWinController = installQuickWin({
        player = LocalPlayer, events = AuctionEvents, state = AB, config = gConfig,
        stopBidding = stopBidLoop, resumeBidding = startBidLoop,
        isCurrent = function() return _G.AHScanner_RunID == myRunID and ScreenGui and ScreenGui.Parent ~= nil end,
        log = function(message) abLog(message, C.gold) end,
        allowed = function(garage, amount, nextBid)
            local name = garage:GetAttribute("GarageId") or garage.Name
            local isAirdrop = name and (string.find(name:lower(), "airdrop") or string.find(name:lower(), "defcon") or string.find(name:lower(), "cargo"))
            if isAirdrop and gConfig.alwaysCollectAirdrop == true then
                AB.quickWinMinBidBlocked = false
                return true
            end
            local minimum = AB.biddingModes.ParseMinimum(gConfig.quickWinMinStartBid) or 0
            if minimum <= 1 then
                AB.quickWinMinBidBlocked = false
            elseif AB.quickWinMinBidBlocked then
                return false, "below-minimum"
            end
            -- If user is manually in this auction or Quick Win is armed, don't block by garage selection filter!
            local isAutofarmDriving = (gConfig.seatedAutofarm == true) and not AB.manualAuctionEntry
            if isAutofarmDriving and not isGarageAllowed(name, true) then return false end
            local opening = tonumber(amount) or tonumber(nextBid) or 0
            if minimum > 1 and opening < minimum then
                local ignoreMinBid = false
                if garage and evaluateItemRule then
                    for _, desc in ipairs(garage:GetDescendants()) do
                        if desc:IsA("Model") and isItemModel and isItemModel(desc) then
                            local dec = evaluateItemRule(desc, "auction")
                            if dec == "allow" then
                                ignoreMinBid = true
                                break
                            end
                        end
                    end
                end
                if not ignoreMinBid then
                    AB.quickWinMinBidBlocked = true
                    return false, "below-minimum"
                end
            end
            return true
        end,
        onWin = function(garage) _G.AHLastTargetLot = garage end,
    })
    for _, connection in ipairs(AB.quickWinController.connections) do table.insert(cleanUpSignals, connection) end
end

local StartAuctionEvent = AuctionEvents and (AuctionEvents:FindFirstChild("ToggleAuctionArea") or AuctionEvents:FindFirstChild("StartAuction"))
if StartAuctionEvent then
    table.insert(cleanUpSignals, StartAuctionEvent.OnClientEvent:Connect(function(isOpen, data)
        if isOpen then
            -- Ignore stray ToggleAuctionArea(true) triggered while leaving/skipping the same round
            if AB.leavingAuction or (AB.quickWinController and AB.quickWinController.phase == "skipping") then
                return
            end
            local garageInst = (typeof(data) == "Instance") and data or nil
            if garageInst and AB.lastSkippedGarage == garageInst and AB.lastSkippedAt and (os.clock() - AB.lastSkippedAt < 2.0) then
                return
            end
            -- Do not reset live auction state if ToggleAuctionArea(true) fires again for the active garage
            if AB.auctionOpen and garageInst and AB.activeGarageInstance == garageInst then
                AB.startingAuction = false
                return
            end
            AB.auctionOpen = true
            AB.auctionOpenedAt = os.clock()
            AB.biddingUIOpen = false
            AB.activeGarageInstance = garageInst
            AB.startingAuction = false -- Clear start trigger lock
            AB.weAreWinning = false    -- Reset win state for new auction
            AB.bidsThisRound = 0
            AB.currentBid = 0
            AB.minBidBlocked = false
            AB.quickWinMinBidBlocked = false
            local lotName = "Unknown"
            if typeof(data) == "Instance" then
                lotName = data:GetAttribute("GarageId") or data.Name
            elseif type(data) == "table" then
                lotName = data.LotName or data.Name or "Unknown"
            elseif type(data) == "string" then
                lotName = data
            end
            local lotConf = gConfig.garages and gConfig.garages[lotName]
            AB.activeLot = lotName
            AB.activeLotData = lotConf
            abLog("Started: " .. tostring(lotName), C.accent)
            
            local startingBid = 0
            if data and type(data) == "table" then
                startingBid = tonumber(
                    data.StartingBid or data.MinBid or data.OpeningBid
                    or data.StartBid  or data.InitialBid or data.startingBid
                    or data.minBid    or data.openingBid  or 0
                ) or 0
            elseif typeof(data) == "Instance" then
                startingBid = tonumber(data:GetAttribute("MinBid") or data:GetAttribute("StartingBid") or data:GetAttribute("OpeningBid") or 0) or 0
            end
                local catalogEntry = GARAGE_CATALOG[lotName]
                if catalogEntry then
                    startingBid = catalogEntry.minBid or 0
                    if AB.minStartBid > 0 then
                        abLog(string.format("Using catalog bid: $%d for %s", startingBid, lotName), C.text2)
                    end
                end
            

            local isSeized = false
            local debris = workspace:FindFirstChild("_Debris")
            local garages = debris and debris:FindFirstChild("Garages")
            local matchedGarage = nil
            if garages then
                for _, g in ipairs(garages:GetChildren()) do
                    if (g:GetAttribute("GarageId") or g.Name) == lotName or g.Name == lotName then
                        matchedGarage = g
                        if isGarageSeized(g) then
                            isSeized = true
                            break
                        end
                    end
                end
            end
            currentGarageIsSeized = isSeized
            _G.AHIsCurrentGarageSeized = isSeized
            if isSeized then
                lastAuctionWasSeized = true
                _G.AHLastAuctionWasSeized = true
            end
            if matchedGarage and not _G.AHLastTargetLot then
                _G.AHLastTargetLot = matchedGarage
            end

            local isSeated = gConfig.seatedAutofarm or (gConfig.seizedGarageSniping and isSeized)
            local garageSelected = isGarageAllowed(lotName, isSeated) or (gConfig.seizedGarageSniping and isSeized)

            local areaOk = false
            local catEntry = GARAGE_CATALOG[lotName]
            local areaName = catEntry and catEntry.area or ""
            
            if isSeized and gConfig.seizedGarageSniping then
                if gConfig.seizedAreas then
                    if gConfig.seizedAreas["Any Area"] or gConfig.seizedAreas[areaName] then
                        areaOk = true
                    else
                        for selArea, isEn in pairs(gConfig.seizedAreas) do
                            if isEn and string.find(areaName, selArea) then areaOk = true; break end
                        end
                    end
                else
                    areaOk = true
                end
            elseif isSeated then
                local hasAnyAfSel = false
                if gConfig.afSelectedGarages then
                    for _, v in pairs(gConfig.afSelectedGarages) do
                        if v == true then hasAnyAfSel = true; break end
                    end
                end
                if hasAnyAfSel then
                    areaOk = garageSelected
                elseif gConfig.afAutoBuyAreas then
                    if gConfig.afAutoBuyAreas["Any Area"] or gConfig.afAutoBuyAreas[areaName] then
                        areaOk = true
                    else
                        for selArea, _ in pairs(gConfig.afAutoBuyAreas) do
                            if string.find(areaName, selArea) then
                                areaOk = true
                                break
                            end
                        end
                    end
                else
                    areaOk = (gConfig.afAutoBuyArea == "Any Area" or areaName == gConfig.afAutoBuyArea or string.find(areaName, gConfig.afAutoBuyArea))
                end
            else
                local hasAnySel = false
                if gConfig.selectedGarages then
                    for _, v in pairs(gConfig.selectedGarages) do
                        if v == true then hasAnySel = true; break end
                    end
                end
                if hasAnySel then
                    areaOk = garageSelected
                elseif gConfig.autoBuyAreas then
                    if gConfig.autoBuyAreas["Any Area"] or gConfig.autoBuyAreas[areaName] then
                        areaOk = true
                    else
                        for selArea, _ in pairs(gConfig.autoBuyAreas) do
                            if string.find(areaName, selArea) then
                                areaOk = true
                                break
                            end
                        end
                    end
                else
                    areaOk = (gConfig.autoBuyArea == "Any Area" or areaName == gConfig.autoBuyArea or string.find(areaName, gConfig.autoBuyArea))
                end
            end
            if isSeated and not AB.enabled and gConfig.autoBidEnabled then
                AB.enabled = true
                if updateBidLoopBtn then updateBidLoopBtn(true) end
            end

            -- Remote on-foot Auto Buy (only when NOT doing seated autofarm)
            if gConfig.autoBuyStorages and not isSeated then
                if garageSelected and areaOk then
                    abLog("Auto Buy triggered -> Teleporting...", C.green)
                    local targetPos
                    if workspace:FindFirstChild("Areas") then
                        for _, c in ipairs(workspace.Areas:GetDescendants()) do
                            if c:IsA("Model") and string.find(c.Name, lotName) then
                                local pt = c:FindFirstChild("Door") or c.PrimaryPart or c:FindFirstChildWhichIsA("BasePart")
                                if pt then targetPos = pt.CFrame; break end
                            end
                        end
                    end
                    if targetPos then
                        fastTP(targetPos)
                        task.delay(1.5, function()
                            if gConfig.autoBidEnabled then
                                AB.enabled = true
                                if updateBidLoopBtn then updateBidLoopBtn(true) end
                                if AB.auctionOpen then startBidLoop() end
                            end
                        end)
                    else
                        abLog("Auto Buy: Lot not found in workspace", C.red)
                    end
                elseif not garageSelected then
                    abLog("Skipped: " .. tostring(lotConf and lotConf.name or lotName) .. " not selected", C.text2)
                else
                    abLog("Auto Buy: Ignoring (wrong area)", C.text2)
                end
            end
            
            local canBid = (AB.enabled == true and gConfig.autoBidEnabled == true)
            if canBid and garageSelected and AB.biddingUIOpen then
                startBidLoop()
            elseif not garageSelected and canBid then
                abLog("Auto-Bid skipped: Garage not selected", C.text2)
            end
        else
            -- ToggleAuctionArea(false) fires whenever stepping/exiting AuctionZone (including Quick Win 10s wait!).
            -- Only treat it as closing if Quick Win isn't active, bidding UI isn't open, and server InAuction is false.
            local qwPhase = AB.quickWinController and AB.quickWinController.phase
            local qwHolding = AB.quickWinActive or qwPhase == "exiting" or qwPhase == "outside" or qwPhase == "pause-requested" or qwPhase == "skipping"
            if qwHolding or AB.biddingUIOpen or LocalPlayer:GetAttribute("InAuction") == true then
                return
            end
            AB.auctionOpen = false
            AB.activeGarageInstance = nil
            abLog("Left auction area", C.text2)
            stopBidLoop()
            AB.minBidBlocked = false
        end
    end))
end

local function cleanRestoreControls()
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local playerGui = player and player:FindFirstChildWhichIsA("PlayerGui")
        local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
        if touchGui then
            touchGui.Enabled = true
            local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
            if touchControlFrame then
                touchControlFrame.Visible = true
                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                if jumpButton then jumpButton.Visible = true end
                local dpad = touchControlFrame:FindFirstChild("DynamicThumbstick")
                if dpad then dpad.Visible = true end
            end
        end
        local PlayerModule = player and player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule")
        if PlayerModule then
            local controls = require(PlayerModule)
            if controls and controls.GetControls then
                local ctrl = controls:GetControls()
                if ctrl and ctrl.Enable then
                    pcall(function() ctrl:Enable(true) end)
                end
            end
        end
    end)
end

local function forceResetControls()
    pcall(function()
        local player = game:GetService("Players").LocalPlayer
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if hum and hum.SeatPart then
            return
        end
        if hum then
            local targetSpd = (_G.gConfig and _G.gConfig.walkSpeedEnabled and tonumber(_G.gConfig.customWalkSpeed))
                or (_G.NexSpeedActive and 32 or 16)
            hum.WalkSpeed = targetSpd
            hum.Jump = false
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end
        if root then
            root.Anchored = false
        end
        cleanRestoreControls()
    end)
end

local ToggleBiddingUI = AuctionEvents and AuctionEvents:FindFirstChild("ToggleBiddingUI")
if ToggleBiddingUI then
    table.insert(cleanUpSignals, ToggleBiddingUI.OnClientEvent:Connect(function(isOpen)
        if isOpen and AB.minBidBlocked then
            abLog("ToggleBidUI blocked: below min $" .. AB.minStartBid, COLORS.Orange)
            return
        end
        AB.biddingUIOpen = (isOpen == true)
        AB.auctionOpen = (isOpen == true)
        if isOpen then
            if AB.auctionOpenedAt == 0 then AB.auctionOpenedAt = os.clock() end
            AB.currentBid = 0
            AB.auctionJustOpened = true
            if currentGarageIsSeized or _G.AHIsCurrentGarageSeized or (_G.AHLastTargetLot and isGarageSeized(_G.AHLastTargetLot)) or hasWantedStars() then
                lastAuctionWasSeized = true
                _G.AHLastAuctionWasSeized = true
            end
            local isSeated = gConfig.seatedAutofarm
            local canBid = (AB.enabled == true and gConfig.autoBidEnabled == true)
            if canBid then
                local garageOk = (AB.activeLot == nil) or isGarageAllowed(AB.activeLot, isSeated)
                if garageOk then
                    startBidLoop()
                else
                    abLog("Skipped: Garage not selected", C.text2)
                end
            end
        else
            stopBidLoop()
            AB.minBidBlocked = false
            abLog("Auction closed", C.text2)
            
            local wasSeizedAuction = (lastAuctionWasSeized == true)
                or (_G.AHLastAuctionWasSeized == true)
                or (currentGarageIsSeized == true)
                or (_G.AHIsCurrentGarageSeized == true)
                or hasWantedStars()
            
            if _G.AHLastTargetLot and not AB.weAreWinning and not AB.pickupPhase then
                local gKey = _G.AHLastTargetLot:GetAttribute("GUID") or _G.AHLastTargetLot.Name
                _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                _G.AHGarageCooldowns[gKey] = os.clock() + 60
                _G.AHLastTargetLot = nil
            end
            
            AB.activeLot = nil
            AB.activeLotData = nil
            AB.activeGarageInstance = nil
            AB.biddingUIOpen = false
            AB.auctionOpenedAt = 0
            AB.startingAuction = false
            task.delay(0.5, forceResetControls)
            
            task.delay(1.5, function()
                if not AB.pickupPhase and not AB.weAreWinning then
                    lastAuctionWasSeized = false
                    _G.AHLastAuctionWasSeized = false
                    currentGarageIsSeized = false
                    _G.AHIsCurrentGarageSeized = false
                end
            end)
        end
    end))
end

if UpdateWinningBidEvent then
    table.insert(cleanUpSignals, UpdateWinningBidEvent.OnClientEvent:Connect(function(prevBid, winnerName, winnerInstance, nextBid, garageInst)
        -- Args: prevBid(number), winnerName(string), winnerInstance(Instance), nextBid(number), garageInstance(Instance)
        AB.currentBid = tonumber(nextBid) or tonumber(prevBid) or AB.currentBid
        AB.auctionJustOpened = false
        AB.biddingUIOpen = true
        
        local isAirdrop = AB.activeLot and (string.find(AB.activeLot, "Airdrop") or AB.activeLot == "Camo Airdrop")
        local bypassMinBid = isAirdrop and (gConfig.alwaysCollectAirdrop == true)
        if AB.enabled and AB.auctionOpen and AB.minStartBid > 0 and not bypassMinBid and AB.currentBid < AB.minStartBid then
            AB.minBidBlocked = true
            AB.auctionOpen   = false
            AB.biddingUIOpen = false
            AB.activeLot = nil
            AB.activeLotData = nil
            AB.activeGarageInstance = nil
            if LeaveAuctionRemote then task.spawn(requestLeaveAuction, LeaveAuctionRemote) end
            stopBidLoop()
            abLog(string.format("KILLED: opening $%d < min $%d", AB.currentBid, AB.minStartBid), C.red)
            return
        end
        
        -- Check if the PREVIOUS winner (before this new bid) was us
        local isUs = false
        if typeof(winnerInstance) == "Instance" and winnerInstance:IsA("Player") then
            isUs = (winnerInstance == LocalPlayer)
        elseif type(winnerName) == "string" then
            isUs = (winnerName == LocalPlayer.Name)
        end
        AB.weAreWinning = isUs
        if isUs then
            abLog("WE'RE WINNING: $"..AB.currentBid, C.gold)
        end
    end))
end

-- Live Garage Scanner HUD Sync Loop
task.spawn(function()
    while true do
        task.wait(0.4)
        if _G.AHScanner_RunID ~= myRunID then break end
        
        pcall(function()
            if AB.auctionOpen then
                local debris = workspace:FindFirstChild("_Debris")
                local garages = debris and debris:FindFirstChild("Garages")
                local activeGarage = nil
                
                if garages then
                    for _, g in ipairs(garages:GetChildren()) do
                        if g:GetAttribute("InAuction") == true then
                            activeGarage = g
                            break
                        end
                    end
                end
                
                if not activeGarage and garages then
                    local lp = Players.LocalPlayer
                    local char = lp and lp.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        local closestDist = 70
                        for _, g in ipairs(garages:GetChildren()) do
                            local p = g.PrimaryPart or g:FindFirstChildWhichIsA("BasePart")
                            if p then
                                local d = (p.Position - root.Position).Magnitude
                                if d < closestDist then
                                    closestDist = d
                                    activeGarage = g
                                end
                            end
                        end
                    end
                end
                
                if activeGarage then
                    local floor = activeGarage:FindFirstChild("Floorspace")
                    local rawItems = floor and floor:GetChildren() or {}
                    local itemsList = {}
                    local hasTargetItem = false
                    local targetList = gConfig.targetItemsList or { ["Cow"] = true }
                    
                    for _, item in ipairs(rawItems) do
                        if isValidGarageItem(item) then
                            local itemId = item:GetAttribute("ItemId")
                            local cond = item:GetAttribute("Condition")
                            local resolvedName = resolveGarageItemName(item)
                            
                            local isTarget = false
                            if itemId == 765 or resolvedName:lower():find("cow") or (targetList["Cow"] and (resolvedName:lower():find("cow") or itemId == 765)) then
                                isTarget = true
                                hasTargetItem = true
                            end
                            
                            for targetName, isEn in pairs(targetList) do
                                if isEn and targetName ~= "" and targetName ~= "Cow" then
                                    if resolvedName:lower():find(targetName:lower()) or (itemId and tostring(itemId) == tostring(targetName)) then
                                        isTarget = true
                                        hasTargetItem = true
                                        break
                                    end
                                end
                            end
                            
                            table.insert(itemsList, {
                                name = resolvedName,
                                cond = cond,
                                isTarget = isTarget
                            })
                        end
                    end
                    
                    updateGarageScannerHUD(activeGarage.Name, itemsList, hasTargetItem)
                end
            else
                if scannerHUD and scannerHUD.Visible then
                    scannerHUD.Visible = false
                end
            end
        end)
    end
end)

-- Live UI Bidding Watchdog (detects on-screen auction bar & auto-fires bids independently)
task.spawn(function()
    while true do
        task.wait(0.2)
        if _G.AHScanner_RunID ~= myRunID then break end
        
        pcall(function()
            local lp = Players.LocalPlayer
            local pg = lp and lp:FindFirstChild("PlayerGui")
            
            if AB.quickWinActive then return end
            -- Detect active bidding UI (ignore ambient HUD banners)
            local isAuctionVisible = false
            local ignoredBanners = { AuctionLoadProgress = true, AuctionWinBanner = true, TutorialAuctionBannerGui = true, AuctionFeeNotice = true }
            if pg then
                for _, g in ipairs(pg:GetChildren()) do
                    if not ignoredBanners[g.Name] and (g.Name:lower():find("bidding") or g.Name:lower():find("bidui") or g.Name == "AuctionGui") and g:IsA("ScreenGui") and g.Enabled then
                        for _, desc in ipairs(g:GetDescendants()) do
                            if desc:IsA("TextLabel") and (tostring(desc.Text):find("CURRENT BID") or tostring(desc.Text):find("HIGHEST BID") or tostring(desc.Text):find("YOUR BID")) and desc.Visible then
                                isAuctionVisible = true
                                break
                            end
                        end
                    end
                    if isAuctionVisible then break end
                end
            end
            
            if isAuctionVisible and not AB.auctionOpen then
                AB.auctionOpen = true
                AB.auctionJustOpened = false
                local canBid = (AB.enabled == true and gConfig.autoBidEnabled == true)
                if canBid then
                    startBidLoop()
                end
            end
        end)
    end
end)


local AuctionPickupEnd = AuctionEvents and AuctionEvents:FindFirstChild("AuctionPickupEnd")
if AuctionPickupEnd then
    table.insert(cleanUpSignals, AuctionPickupEnd.OnClientEvent:Connect(function()
        abLog("[Finish] Server ended auction pickup phase.", C.text2)
        if not _G.AHPickupCycleRunning then
            AB.pickupPhase = false
            AB.weAreWinning = false
        end
    end))
end

local AuctionPickupStart = AuctionEvents and AuctionEvents:FindFirstChild("AuctionPickupStart")
if AuctionPickupStart then
    table.insert(cleanUpSignals, AuctionPickupStart.OnClientEvent:Connect(function()
        AB.weAreWinning = true
        AB.pickupPhase = true
        if gConfig.autoCollectWon ~= true then
            local waitSec = math.clamp(tonumber(gConfig.manualCollectDelay) or 15, 0, 180)
            abLog(string.format("[Tournament] Auto Collect OFF — pausing up to %ds for spray / Collect!", waitSec), C.gold)
            return
        end
        abLog("WON! Auto-picking up items...", C.green)

        task.spawn(function()
            task.wait(2.0)
            if runAutoPickupCycle then
                runAutoPickupCycle("AuctionWon")
            end
        end)
    end))
end

    -- [Power] PERFORMANCE TAB SETUP
    do
        list(nil, 6, tabPerformance)
        
        local descLabel = make("TextLabel", {
            Text = "Restricting rendering frame rates and disabling 3D graphics drastically saves CPU/GPU power. Highly recommended for overnight active farming to prevent overheating.",
            TextSize = 10,
            TextColor3 = C.text2,
            Font = Enum.Font.MontserratBold,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.95, 0, 0, 45),
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, tabPerformance)
        
        local overlayScreen = nil
        local updateRender = nil
        
        local function exitOvernightMode()
            gConfig.disable3DRendering = false
            pcall(function()
                game:GetService("RunService"):Set3dRenderingEnabled(true)
            end)
            if overlayScreen then
                pcall(function() overlayScreen:Destroy() end)
                overlayScreen = nil
            end
            pcall(function()
                local leftover = ScreenGui:FindFirstChild("OvernightOverlay")
                if leftover then leftover:Destroy() end
            end)
            if updateRender then
                updateRender(false)
            end
            saveConfig()
        end
        _G.exitOvernightMode = exitOvernightMode

        local function set3DRendering(state)
            gConfig.disable3DRendering = state
            pcall(function()
                game:GetService("RunService"):Set3dRenderingEnabled(not state)
            end)
            
            if state then
                if not overlayScreen then
                    overlayScreen = make("Frame", {
                        Name = "OvernightOverlay",
                        Size = UDim2.new(1, 0, 1, 100),
                        Position = UDim2.new(0, 0, 0, -50),
                        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        ZIndex = 100000,
                    }, ScreenGui)
                    
                    local overlayText = make("TextLabel", {
                        Text = "NexWorks OVERNIGHT MODE ACTIVE\n\n3D Rendering disabled to save CPU & GPU.\nPress [RightShift] or Click anywhere to exit.",
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        TextColor3 = Color3.fromRGB(150, 170, 220),
                        TextSize = 12,
                        Font = Enum.Font.MontserratBold,
                        TextWrapped = true,
                        ZIndex = 100001,
                    }, overlayScreen)
                    
                    local clickBtn = make("TextButton", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "",
                        ZIndex = 100002,
                        Active = true,
                    }, overlayScreen)
                    clickBtn.MouseButton1Click:Connect(exitOvernightMode)
                    clickBtn.Activated:Connect(exitOvernightMode)
                end
            else
                exitOvernightMode()
            end
            saveConfig()
        end
        
        local function setFPSCap(state)
            gConfig.capFPS15 = state
            local targetCap = state and 15 or 240
            -- 1. Modern Roblox Client Native Cap (UserGameSettings)
            pcall(function()
                local ugs = UserSettings():GetService("UserGameSettings")
                if ugs then
                    ugs.FramerateCap = targetCap
                end
            end)
            -- 2. Executor C hook (setfpscap / set_fps_cap)
            pcall(function()
                local fn = setfpscap or set_fps_cap
                if fn then
                    fn(state and 15 or 999)
                end
            end)
            saveConfig()
        end
        
        local renderToggle, rawUpdateRender = createToggle(tabPerformance, "Disable 3D Rendering (Black Screen)", gConfig.disable3DRendering, set3DRendering)
        updateRender = rawUpdateRender
        _G.uiToggles["disable3DRendering"] = function(state)
            updateRender(state)
            set3DRendering(state)
        end
        
        local fpsToggle, rawUpdateFps = createToggle(tabPerformance, "Cap Framerate (15 FPS)", gConfig.capFPS15, setFPSCap)
        _G.uiToggles["capFPS15"] = function(state)
            rawUpdateFps(state)
            setFPSCap(state)
        end
    end

    -- AUTOMATION SUBTAB SETUP
    do
        list(nil, 6, tabAutomation)
        
        local indexClaimToggleCard, updateIndexClaim = createToggle(tabAutomation, "Auto Claim Index Book Rewards", gConfig.autoClaimIndexRewards, function(state)
            gConfig.autoClaimIndexRewards = state
            saveConfig()
        end)
        _G.uiToggles["autoClaimIndexRewards"] = updateIndexClaim

    end

    -- ═════════════════════════════════════════════════════
    -- 🛡️ ITEM RULES SYSTEM (BETA) - MODAL & LAUNCHER SETUP
    -- ═════════════════════════════════════════════════════
    do
        local knownMutationsList = {
            "None", "Silver", "Gold", "Corrupted", "Diamond", "Gem", "Rainbow",
            "Dusty", "Saloon Sparkle", "Tumbleweed", "Gunsmoked", "Goldrush",
            "Polished Brass", "Steam", "Clockwork",
            "Titanium", "Morganite", "Citrine", "Lapis", "Carnelian", "Aquamarine",
            "Amethyst", "Emerald", "Sapphire", "Ruby",
            "Bulletproof", "Fortified", "Jestered", "Vaulted", "Camo", "Warforged", "Encrypted"
        }
        local knownRaritiesList = {
            "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Exotic", "Ancient", "Divine", "Special"
        }
        local knownIsTypesList = {
            "Vault items", "Energy drinks", "Event exclusives", "Limited items"
        }

        local function getLiveCatalogItems()
            local items = {}
            local seen = {}
            if ItemsData then
                for id, data in pairs(ItemsData) do
                    if type(data) == "table" and data.Name and not seen[data.Name] then
                        seen[data.Name] = true
                        table.insert(items, data.Name)
                    end
                end
            end
            if #items == 0 then
                pcall(function()
                    for _, desc in ipairs(workspace:GetDescendants()) do
                        if desc:IsA("Model") then
                            local n = desc:GetAttribute("ItemName") or desc:GetAttribute("Name")
                            if n and not seen[n] and not n:lower():find("garage") then
                                seen[n] = true
                                table.insert(items, n)
                            end
                        end
                    end
                end)
            end
            table.sort(items)
            return items
        end

        local function getLiveCategories()
            local cats = {}
            local seen = {}
            if ItemsData then
                for _, data in pairs(ItemsData) do
                    if type(data) == "table" then
                        local cat = tostring(data.Category or data.category or data.Type or "Misc")
                        if not seen[cat] then
                            seen[cat] = true
                            table.insert(cats, cat)
                        end
                    end
                end
            end
            if #cats == 0 then
                cats = {"Antique", "Electronics", "Furniture", "Jewelry", "Tools", "Weapons", "Vehicles", "Collectibles", "Safes", "Drinks", "Misc"}
            end
            table.sort(cats)
            return cats
        end

        -- ── 1. STANDALONE ITEM RULES MODAL FRAME (640 x 420) ──
        local ItemRulesModal = make("Frame", {
            Name = "ItemRulesModal",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 640, 0, 420),
            BackgroundColor3 = Color3.fromRGB(12, 14, 20),
            ClipsDescendants = true,
            Active = true,
            Visible = false,
            ZIndex = 100000,
        }, ScreenGui)
        corner(8, ItemRulesModal)
        stroke(1.2, C.border, ItemRulesModal)

        -- TitleBar
        local ModalTitleBar = make("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = COLORS.Sidebar,
            BorderSizePixel = 0,
            ZIndex = 100001,
        }, ItemRulesModal)
        corner(8, ModalTitleBar)

        local ModalTitleLabel = make("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0),
            Position = UDim2.new(0, 14, 0, 0),
            BackgroundTransparency = 1,
            Text = "Item Rules",
            TextColor3 = C.text,
            TextSize = 13,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 100002,
        }, ModalTitleBar)

        -- Red Close [X] Button
        local ModalCloseBtn = make("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0.5, -12),
            BackgroundColor3 = Color3.fromRGB(130, 30, 30),
            Text = "X",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 100002,
        }, ModalTitleBar)
        corner(4, ModalCloseBtn)

        ModalCloseBtn.MouseButton1Click:Connect(function()
            ItemRulesModal.Visible = false
        end)

        -- Draggable Modal Logic
        local draggingModal, dragStartModal, dragStartModalCenter = false, nil, nil
        ModalTitleBar.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                draggingModal = true
                dragStartModal = inp.Position
                dragStartModalCenter = Vector2.new(
                    ItemRulesModal.AbsolutePosition.X + (ItemRulesModal.AbsoluteSize.X / 2),
                    ItemRulesModal.AbsolutePosition.Y + (ItemRulesModal.AbsoluteSize.Y / 2)
                )
            end
        end)
        table.insert(cleanUpSignals, UserInputService.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                draggingModal = false
            end
        end))
        table.insert(cleanUpSignals, UserInputService.InputChanged:Connect(function(inp)
            if draggingModal and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                local delta = inp.Position - dragStartModal
                local targetX = dragStartModalCenter.X + delta.X
                local targetY = dragStartModalCenter.Y + delta.Y
                local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
                local halfW = ItemRulesModal.AbsoluteSize.X / 2
                local halfH = ItemRulesModal.AbsoluteSize.Y / 2
                ItemRulesModal.Position = UDim2.new(0, math.clamp(targetX, halfW, vp.X - halfW), 0, math.clamp(targetY, halfH, vp.Y - halfH))
            end
        end))

        -- ── 2. SUBTAB SWITCHER: [Rules] vs [Lists] ──
        local currentSubtab = "rules"
        local currentSelectedLane = "AutoSell"
        local currentSelectedRuleIdx = 1

        local subtabBar = make("Frame", {
            Size = UDim2.new(0, 180, 0, 28),
            Position = UDim2.new(0, 14, 0, 42),
            BackgroundTransparency = 1,
            ZIndex = 100001,
        }, ItemRulesModal)
        list(Enum.HorizontalAlignment.Left, 6, subtabBar).FillDirection = Enum.FillDirection.Horizontal

        local btnRulesTab = make("TextButton", {
            Size = UDim2.new(0, 85, 1, 0),
            BackgroundColor3 = Color3.fromRGB(60, 120, 220),
            Text = "Rules",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 100002,
        }, subtabBar)
        corner(6, btnRulesTab)

        local btnListsTab = make("TextButton", {
            Size = UDim2.new(0, 85, 1, 0),
            BackgroundColor3 = C.card,
            Text = "Lists",
            TextColor3 = C.text2,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 100002,
        }, subtabBar)
        corner(6, btnListsTab)

        -- Main Content Split Container
        local modalBody = make("Frame", {
            Size = UDim2.new(1, -28, 1, -112),
            Position = UDim2.new(0, 14, 0, 76),
            BackgroundTransparency = 1,
            ZIndex = 100001,
        }, ItemRulesModal)

        -- Left Pane (180px)
        local leftPane = make("Frame", {
            Size = UDim2.new(0, 180, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 100002,
        }, modalBody)

        local leftHeader = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "RULES (ordered)",
            TextColor3 = Color3.fromRGB(0, 200, 255),
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 100003,
        }, leftPane)

        local leftScroll = make("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, -44),
            Position = UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 100003,
        }, leftPane)
        list(Enum.HorizontalAlignment.Center, 4, leftScroll)

        local leftFooter = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 22),
            Position = UDim2.new(0, 0, 1, -22),
            BackgroundTransparency = 1,
            Text = "First match wins.",
            TextColor3 = C.textMuted,
            TextSize = 8.5,
            Font = Enum.Font.Montserrat,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 100003,
        }, leftPane)

        -- Right Pane (Inspector / Lane Editor)
        local rightPane = make("ScrollingFrame", {
            Size = UDim2.new(1, -192, 1, 0),
            Position = UDim2.new(0, 192, 0, 0),
            BackgroundColor3 = Color3.fromRGB(16, 20, 30),
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 100002,
        }, modalBody)
        corner(6, rightPane)
        stroke(1, C.border, rightPane)
        pad(10, rightPane)
        list(Enum.HorizontalAlignment.Left, 6, rightPane)

        -- Bottom Status Bar
        local modalFooter = make("TextLabel", {
            Size = UDim2.new(1, -28, 0, 24),
            Position = UDim2.new(0, 14, 1, -28),
            BackgroundTransparency = 1,
            Text = "Lists decide which items a lane touches. A rule beats a list for the items it names.",
            TextColor3 = C.textMuted,
            TextSize = 9,
            Font = Enum.Font.MontserratMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 100002,
        }, ItemRulesModal)

        -- ── 3. MULTI-SELECT PICKER DIALOG POPUP (380 x 320) ──
        local PickerOverlay = make("Frame", {
            Name = "PickerOverlay",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.5,
            Visible = false,
            ZIndex = 200000,
        }, ItemRulesModal)

        local PickerBox = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 380, 0, 320),
            BackgroundColor3 = Color3.fromRGB(15, 18, 28),
            BorderSizePixel = 0,
            ClipsDescendants = true,
            ZIndex = 200001,
        }, PickerOverlay)
        corner(8, PickerBox)
        stroke(1.5, Color3.fromRGB(0, 200, 255), PickerBox)

        local PickerTitleBar = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Color3.fromRGB(22, 27, 40),
            BorderSizePixel = 0,
            ZIndex = 200002,
        }, PickerBox)

        local PickerTitle = make("TextLabel", {
            Size = UDim2.new(1, -40, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = "Select Items",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 200003,
        }, PickerTitleBar)

        local PickerCloseBtn = make("TextButton", {
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(1, -26, 0.5, -10),
            BackgroundColor3 = C.card,
            Text = "X",
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            ZIndex = 200003,
        }, PickerTitleBar)
        corner(4, PickerCloseBtn)

        local PickerSearchFrame = make("Frame", {
            Size = UDim2.new(1, -20, 0, 26),
            Position = UDim2.new(0, 10, 0, 38),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            ZIndex = 200002,
        }, PickerBox)
        corner(5, PickerSearchFrame)
        stroke(1, C.border, PickerSearchFrame)

        local PickerSearchBox = make("TextBox", {
            Size = UDim2.new(1, -12, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = "Search...",
            TextColor3 = C.text,
            PlaceholderColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.Montserrat,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 200003,
        }, PickerSearchFrame)

        local PickerScroll = make("ScrollingFrame", {
            Size = UDim2.new(1, -20, 1, -112),
            Position = UDim2.new(0, 10, 0, 70),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 200002,
        }, PickerBox)
        list(Enum.HorizontalAlignment.Left, 2, PickerScroll)

        local PickerActionBar = make("Frame", {
            Size = UDim2.new(1, -20, 0, 28),
            Position = UDim2.new(0, 10, 1, -34),
            BackgroundTransparency = 1,
            ZIndex = 200002,
        }, PickerBox)
        list(Enum.HorizontalAlignment.Right, 6, PickerActionBar).FillDirection = Enum.FillDirection.Horizontal

        local btnPickerSelectAll = make("TextButton", {
            Size = UDim2.new(0, 75, 1, 0),
            BackgroundColor3 = C.card,
            Text = "Select All",
            TextColor3 = C.text2,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            ZIndex = 200003,
        }, PickerActionBar)
        corner(4, btnPickerSelectAll); stroke(1, C.border, btnPickerSelectAll)

        local btnPickerClearAll = make("TextButton", {
            Size = UDim2.new(0, 75, 1, 0),
            BackgroundColor3 = C.card,
            Text = "Clear All",
            TextColor3 = C.red,
            TextSize = 9,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            ZIndex = 200003,
        }, PickerActionBar)
        corner(4, btnPickerClearAll); stroke(1, C.border, btnPickerClearAll)

        local btnPickerDone = make("TextButton", {
            Size = UDim2.new(0, 70, 1, 0),
            BackgroundColor3 = Color3.fromRGB(60, 120, 220),
            Text = "Done",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            ZIndex = 200003,
        }, PickerActionBar)
        corner(4, btnPickerDone)

        local activePickerCallback = nil
        local activePickerTargetSet = nil
        local activePickerOptions = {}
        local pickerRowButtons = {}

        local function refreshPickerRows(query)
            query = query and query:lower() or ""
            for _, btn in ipairs(pickerRowButtons) do btn:Destroy() end
            pickerRowButtons = {}

            for _, opt in ipairs(activePickerOptions) do
                if query == "" or opt:lower():find(query, 1, true) then
                    local isChecked = activePickerTargetSet and activePickerTargetSet[opt] == true
                    local rowBtn = make("TextButton", {
                        Size = UDim2.new(1, 0, 0, 22),
                        BackgroundColor3 = isChecked and Color3.fromRGB(28, 38, 58) or Color3.fromRGB(18, 22, 32),
                        Text = (isChecked and " [X]  " or " [ ]  ") .. opt,
                        TextColor3 = isChecked and Color3.fromRGB(0, 200, 255) or C.text2,
                        TextSize = 9.5,
                        Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BorderSizePixel = 0,
                        AutoButtonColor = false,
                        ZIndex = 200004,
                    }, PickerScroll)
                    corner(4, rowBtn)
                    local optRef = opt
                    rowBtn.MouseButton1Click:Connect(function()
                        if activePickerTargetSet then
                            if activePickerTargetSet[optRef] then
                                activePickerTargetSet[optRef] = nil
                            else
                                activePickerTargetSet[optRef] = true
                            end
                            saveConfig()
                            refreshPickerRows(PickerSearchBox.Text)
                            if activePickerCallback then activePickerCallback() end
                        end
                    end)
                    table.insert(pickerRowButtons, rowBtn)
                end
            end
        end

        local function openPicker(title, optionsList, targetSet, onDone)
            PickerTitle.Text = "Select " .. title
            PickerSearchBox.Text = ""
            activePickerOptions = optionsList
            activePickerTargetSet = targetSet
            activePickerCallback = onDone
            refreshPickerRows("")
            PickerOverlay.Visible = true
        end

        local function closePicker()
            PickerOverlay.Visible = false
            if activePickerCallback then activePickerCallback() end
            saveConfig()
        end

        PickerCloseBtn.MouseButton1Click:Connect(closePicker)
        btnPickerDone.MouseButton1Click:Connect(closePicker)
        PickerSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            refreshPickerRows(PickerSearchBox.Text)
        end)
        btnPickerSelectAll.MouseButton1Click:Connect(function()
            if activePickerTargetSet then
                for _, opt in ipairs(activePickerOptions) do activePickerTargetSet[opt] = true end
                refreshPickerRows(PickerSearchBox.Text)
                if activePickerCallback then activePickerCallback() end
                saveConfig()
            end
        end)
        btnPickerClearAll.MouseButton1Click:Connect(function()
            if activePickerTargetSet then
                table.clear(activePickerTargetSet)
                refreshPickerRows(PickerSearchBox.Text)
                if activePickerCallback then activePickerCallback() end
                saveConfig()
            end
        end)

        -- ── 4. RENDERERS FOR [Rules] AND [Lists] ──
        local renderModalBody = nil

        local function getFilterCount(targetTable)
            if not targetTable then return 0 end
            local c = 0
            for _, _ in pairs(targetTable) do c = c + 1 end
            return c
        end

        local function getLaneTotalFilters(laneKey)
            local lane = gConfig.itemLists and gConfig.itemLists[laneKey]
            if not lane then return 0 end
            local cnt = getFilterCount(lane.items) + getFilterCount(lane.mutations) + getFilterCount(lane.categories) + getFilterCount(lane.rarities)
            if lane.vaultItems then cnt = cnt + 1 end
            if lane.energyDrinks then cnt = cnt + 1 end
            if lane.limitedItems then cnt = cnt + 1 end
            if lane.eventExclusives then cnt = cnt + 1 end
            return cnt
        end

        -- Row builder helper for Left Panel
        local function makeLeftLaneButton(name, count, isSelected, onClick)
            local btn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = isSelected and Color3.fromRGB(60, 120, 220) or Color3.fromRGB(22, 28, 42),
                Text = string.format(" %s (%d)", name, count),
                TextColor3 = isSelected and Color3.fromRGB(255, 255, 255) or C.text2,
                TextSize = 10,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 100004,
            }, leftScroll)
            corner(5, btn)
            btn.MouseButton1Click:Connect(onClick)
            return btn
        end

        -- Row builder helper for Right Panel Checkbox
        local function makeInspectorCheckbox(parent, labelText, descText, isChecked, onToggle)
            local card = make("Frame", {
                Size = UDim2.new(1, 0, 0, descText and 36 or 24),
                BackgroundColor3 = Color3.fromRGB(20, 26, 38),
                BorderSizePixel = 0,
                ZIndex = 100003,
            }, parent)
            corner(4, card)
            
            local boxBtn = make("TextButton", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = (isChecked and " [X]  " or " [ ]  ") .. labelText,
                TextColor3 = isChecked and Color3.fromRGB(0, 215, 255) or C.text,
                TextSize = 9.5,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 100004,
            }, card)

            if descText then
                make("TextLabel", {
                    Size = UDim2.new(1, -18, 0, 14),
                    Position = UDim2.new(0, 18, 0, 18),
                    BackgroundTransparency = 1,
                    Text = descText,
                    TextColor3 = C.textMuted,
                    TextSize = 8,
                    Font = Enum.Font.Montserrat,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 100004,
                }, card)
            end

            boxBtn.MouseButton1Click:Connect(function()
                onToggle(not isChecked)
            end)
            return card
        end

        -- Row builder helper for Selector Row
        local function makeInspectorSelectorRow(parent, labelText, targetSet, optionsGetter, title)
            local row = make("Frame", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                ZIndex = 100003,
            }, parent)

            make("TextLabel", {
                Size = UDim2.new(0, 95, 1, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text2,
                TextSize = 9.5,
                Font = Enum.Font.MontserratBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 100004,
            }, row)

            local count = getFilterCount(targetSet)
            local badgeText = count == 0 and "(0) nothing" or string.format("(%d) selected", count)

            local badgeBtn = make("TextButton", {
                Size = UDim2.new(1, -155, 1, 0),
                Position = UDim2.new(0, 100, 0, 0),
                BackgroundColor3 = Color3.fromRGB(24, 30, 44),
                Text = badgeText,
                TextColor3 = count > 0 and Color3.fromRGB(0, 215, 255) or C.text2,
                TextSize = 9.5,
                Font = Enum.Font.Montserrat,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 100004,
            }, row)
            corner(4, badgeBtn); stroke(1, C.border, badgeBtn)

            local clearBtn = make("TextButton", {
                Size = UDim2.new(0, 48, 1, 0),
                Position = UDim2.new(1, -48, 0, 0),
                BackgroundColor3 = Color3.fromRGB(28, 22, 32),
                Text = "clear",
                TextColor3 = count > 0 and C.red or C.textMuted,
                TextSize = 9,
                Font = Enum.Font.MontserratBold,
                BorderSizePixel = 0,
                ZIndex = 100004,
            }, row)
            corner(4, clearBtn); stroke(1, C.border, clearBtn)

            badgeBtn.MouseButton1Click:Connect(function()
                openPicker(title or labelText, optionsGetter(), targetSet, function()
                    renderModalBody()
                end)
            end)

            clearBtn.MouseButton1Click:Connect(function()
                table.clear(targetSet)
                saveConfig()
                renderModalBody()
            end)
            return row
        end

        renderModalBody = function()
            for _, c in ipairs(leftScroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
            for _, c in ipairs(rightPane:GetChildren()) do if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end end

            tw(btnRulesTab, 0.12, {
                BackgroundColor3 = currentSubtab == "rules" and Color3.fromRGB(60, 120, 220) or C.card,
                TextColor3 = currentSubtab == "rules" and Color3.fromRGB(255, 255, 255) or C.text2
            })
            tw(btnListsTab, 0.12, {
                BackgroundColor3 = currentSubtab == "lists" and Color3.fromRGB(60, 120, 220) or C.card,
                TextColor3 = currentSubtab == "lists" and Color3.fromRGB(255, 255, 255) or C.text2
            })

            -- ── MODE 1: [LISTS] (Default Lanes) ──
            if currentSubtab == "lists" then
                leftHeader.Text = "LISTS (per lane)"
                leftFooter.Text = "The number is how many things that lane filters on."

                local lanes = {"Pickup", "Shelves", "AutoSell", "Grading", "Auction"}
                for _, laneName in ipairs(lanes) do
                    local isSel = (currentSelectedLane == laneName)
                    local cnt = getLaneTotalFilters(laneName)
                    makeLeftLaneButton(laneName, cnt, isSel, function()
                        currentSelectedLane = laneName
                        renderModalBody()
                    end)
                end

                local lists = gConfig.itemLists
                if currentSelectedLane == "AutoSell" then
                    local autoSell = lists.AutoSell
                    autoSell.items = autoSell.items or {}
                    autoSell.mutations = autoSell.mutations or {}
                    autoSell.categories = autoSell.categories or {}
                    autoSell.rarities = autoSell.rarities or {}

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "AutoSell -- never sold",
                        TextColor3 = Color3.fromRGB(80, 160, 255),
                        TextSize = 11, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = "Anything picked here is kept rather than sold.",
                        TextColor3 = C.text2,
                        TextSize = 9, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    makeInspectorSelectorRow(rightPane, "Item names", autoSell.items, getLiveCatalogItems, "Item Names")
                    
                    makeInspectorCheckbox(rightPane, "Vault items (safes)", "Unopened safes, which the locksmith can still open.", autoSell.vaultItems == true, function(s)
                        autoSell.vaultItems = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Energy drinks", "Your luck and rush potions.", autoSell.energyDrinks == true, function(s)
                        autoSell.energyDrinks = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Event exclusives", "In-game events (Sandstorm, Police). Usually worth keeping.", autoSell.eventExclusives == true, function(s)
                        autoSell.eventExclusives = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Limited items", "Timed-event items (Alien Invasion). Usually worth keeping.", autoSell.limitedItems == true, function(s)
                        autoSell.limitedItems = s; saveConfig(); renderModalBody()
                    end)

                    makeInspectorSelectorRow(rightPane, "Mutations", autoSell.mutations, function() return knownMutationsList end, "Mutations")
                    makeInspectorSelectorRow(rightPane, "Categories", autoSell.categories, getLiveCategories, "Categories")
                    makeInspectorSelectorRow(rightPane, "Rarities", autoSell.rarities, function() return knownRaritiesList end, "Rarities")

                elseif currentSelectedLane == "Grading" then
                    local grading = lists.Grading
                    grading.rarities = grading.rarities or {}

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "Grading -- which rarities get graded",
                        TextColor3 = Color3.fromRGB(80, 160, 255),
                        TextSize = 11, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = "These rarities ARE graded -- a keep-list, not a skip-list.",
                        TextColor3 = C.text2,
                        TextSize = 9, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 48),
                        BackgroundTransparency = 1,
                        Text = "No name, category, mutation or limited boxes: Auto Grade never had them. Use a rule.\n\"Grade Vault Before Opening\" stays on the Processing tab: it is a sequencing switch, not a filter: with Auto Vault on it grades safes even if Auto Grade is off, so it is not something this list controls.",
                        TextColor3 = Color3.fromRGB(240, 180, 60),
                        TextSize = 8, Font = Enum.Font.Montserrat,
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    makeInspectorSelectorRow(rightPane, "Rarities to grade", grading.rarities, function() return knownRaritiesList end, "Rarities")

                    makeInspectorCheckbox(rightPane, "Energy drinks (grade them)", "ON = graded first and regardless of the rarity list. The console says why if one is not.", grading.energyDrinks == true, function(s)
                        grading.energyDrinks = s; saveConfig(); renderModalBody()
                    end)

                elseif currentSelectedLane == "Auction" then
                    local auction = lists.Auction
                    auction.mutations = auction.mutations or {}
                    auction.items = auction.items or {}
                    auction.rarities = auction.rarities or {}

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "Auction -- ignores your Min Bid",
                        TextColor3 = Color3.fromRGB(80, 160, 255),
                        TextSize = 11, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = "A garage holding any of these is worth entering under Min Bid.",
                        TextColor3 = C.text2,
                        TextSize = 9, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 50),
                        BackgroundTransparency = 1,
                        Text = "Boxed items never match whatever you tick: roughly half a garage cannot be identified by anyone before the win. That is the real ceiling here.\nNo category/limited/vault boxes: they are reachable the same way rarities are, but each name costs ~68ms to learn and the preview cache dies near 141. Value is the one thing genuinely unknowable before a win.",
                        TextColor3 = Color3.fromRGB(240, 180, 60),
                        TextSize = 8, Font = Enum.Font.Montserrat,
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    makeInspectorSelectorRow(rightPane, "Mutations", auction.mutations, function() return knownMutationsList end, "Mutations")
                    makeInspectorSelectorRow(rightPane, "Item names", auction.items, getLiveCatalogItems, "Item Names")
                    makeInspectorSelectorRow(rightPane, "Rarities", auction.rarities, function() return knownRaritiesList end, "Rarities")

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "WHAT IS ACTUALLY WATCHED",
                        TextColor3 = Color3.fromRGB(0, 200, 255),
                        TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 36),
                        BackgroundTransparency = 1,
                        Text = "No item or rarity selected -- Min Bid applies normally.\nMutations always work. Items and rarities must be learned first with \"Learn ALL Items\" on the Auction tab. Boxed items never match.",
                        TextColor3 = Color3.fromRGB(240, 180, 60),
                        TextSize = 8, Font = Enum.Font.Montserrat,
                        TextWrapped = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                elseif currentSelectedLane == "Pickup" then
                    local pickup = lists.Pickup
                    pickup.items = pickup.items or {}
                    pickup.categories = pickup.categories or {}
                    pickup.rarities = pickup.rarities or {}
                    pickup.mutations = pickup.mutations or {}

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "Pickup -- left on ground",
                        TextColor3 = Color3.fromRGB(80, 160, 255),
                        TextSize = 11, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = "Anything picked here is ignored and left on the ground.",
                        TextColor3 = C.text2,
                        TextSize = 9, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    makeInspectorSelectorRow(rightPane, "Item names", pickup.items, getLiveCatalogItems, "Item Names")
                    makeInspectorSelectorRow(rightPane, "Categories", pickup.categories, getLiveCategories, "Categories")
                    makeInspectorSelectorRow(rightPane, "Rarities", pickup.rarities, function() return knownRaritiesList end, "Rarities")
                    makeInspectorSelectorRow(rightPane, "Mutations", pickup.mutations, function() return knownMutationsList end, "Mutations")

                    makeInspectorCheckbox(rightPane, "Limited items", "Timed-event items (Alien Invasion). Usually left if inventory full.", pickup.limitedItems == true, function(s)
                        pickup.limitedItems = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Vault items", "Unopened safes.", pickup.vaultItems == true, function(s)
                        pickup.vaultItems = s; saveConfig(); renderModalBody()
                    end)

                elseif currentSelectedLane == "Shelves" then
                    local shelves = lists.Shelves
                    shelves.items = shelves.items or {}
                    shelves.mutations = shelves.mutations or {}
                    shelves.categories = shelves.categories or {}
                    shelves.rarities = shelves.rarities or {}

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "Shelves -- never put on shelf",
                        TextColor3 = Color3.fromRGB(80, 160, 255),
                        TextSize = 11, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 14),
                        BackgroundTransparency = 1,
                        Text = "Anything picked here stays in your bag rather than displayed.",
                        TextColor3 = C.text2,
                        TextSize = 9, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    makeInspectorSelectorRow(rightPane, "Item names", shelves.items, getLiveCatalogItems, "Item Names")

                    makeInspectorCheckbox(rightPane, "Vault items", "Unopened safes.", shelves.vaultItems == true, function(s)
                        shelves.vaultItems = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Limited items", "Timed-event items.", shelves.limitedItems == true, function(s)
                        shelves.limitedItems = s; saveConfig(); renderModalBody()
                    end)
                    makeInspectorCheckbox(rightPane, "Event exclusives", "In-game event items.", shelves.eventExclusives == true, function(s)
                        shelves.eventExclusives = s; saveConfig(); renderModalBody()
                    end)

                    makeInspectorSelectorRow(rightPane, "Mutations", shelves.mutations, function() return knownMutationsList end, "Mutations")
                    makeInspectorSelectorRow(rightPane, "Categories", shelves.categories, getLiveCategories, "Categories")
                    makeInspectorSelectorRow(rightPane, "Rarities", shelves.rarities, function() return knownRaritiesList end, "Rarities")
                end

            -- ── MODE 2: [RULES] (Custom Prioritized Engine) ──
            else
                leftHeader.Text = "RULES (ordered)"
                leftFooter.Text = "First match wins. Drag or use arrows to prioritize."

                local rules = gConfig.itemRules
                for idx, rule in ipairs(rules) do
                    local isSel = (currentSelectedRuleIdx == idx)
                    local rowFrame = make("Frame", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = isSel and Color3.fromRGB(35, 45, 68) or Color3.fromRGB(20, 25, 36),
                        BorderSizePixel = 0,
                        ZIndex = 100004,
                    }, leftScroll)
                    corner(5, rowFrame)
                    if isSel then stroke(1, Color3.fromRGB(0, 200, 255), rowFrame) end

                    local selectBtn = make("TextButton", {
                        Size = UDim2.new(1, -55, 1, 0),
                        BackgroundTransparency = 1,
                        Text = string.format(" %d. %s", idx, rule.name or "empty"),
                        TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or C.text2,
                        TextSize = 9.5,
                        Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        ZIndex = 100005,
                    }, rowFrame)
                    selectBtn.MouseButton1Click:Connect(function()
                        currentSelectedRuleIdx = idx
                        renderModalBody()
                    end)

                    local btnUp = make("TextButton", {
                        Size = UDim2.new(0, 16, 0, 18),
                        Position = UDim2.new(1, -52, 0.5, -9),
                        BackgroundColor3 = C.card,
                        Text = "^", TextColor3 = C.text2,
                        TextSize = 8, Font = Enum.Font.MontserratBold,
                        BorderSizePixel = 0, ZIndex = 100005,
                    }, rowFrame)
                    corner(3, btnUp)
                    btnUp.MouseButton1Click:Connect(function()
                        if idx > 1 then
                            local temp = rules[idx]
                            rules[idx] = rules[idx - 1]
                            rules[idx - 1] = temp
                            currentSelectedRuleIdx = idx - 1
                            saveConfig()
                            renderModalBody()
                        end
                    end)

                    local btnDown = make("TextButton", {
                        Size = UDim2.new(0, 16, 0, 18),
                        Position = UDim2.new(1, -34, 0.5, -9),
                        BackgroundColor3 = C.card,
                        Text = "v", TextColor3 = C.text2,
                        TextSize = 8, Font = Enum.Font.MontserratBold,
                        BorderSizePixel = 0, ZIndex = 100005,
                    }, rowFrame)
                    corner(3, btnDown)
                    btnDown.MouseButton1Click:Connect(function()
                        if idx < #rules then
                            local temp = rules[idx]
                            rules[idx] = rules[idx + 1]
                            rules[idx + 1] = temp
                            currentSelectedRuleIdx = idx + 1
                            saveConfig()
                            renderModalBody()
                        end
                    end)

                    local btnDel = make("TextButton", {
                        Size = UDim2.new(0, 16, 0, 18),
                        Position = UDim2.new(1, -17, 0.5, -9),
                        BackgroundColor3 = Color3.fromRGB(60, 20, 25),
                        Text = "x", TextColor3 = C.red,
                        TextSize = 8, Font = Enum.Font.MontserratBold,
                        BorderSizePixel = 0, ZIndex = 100005,
                    }, rowFrame)
                    corner(3, btnDel)
                    btnDel.MouseButton1Click:Connect(function()
                        table.remove(rules, idx)
                        if currentSelectedRuleIdx > #rules then currentSelectedRuleIdx = math.max(1, #rules) end
                        saveConfig()
                        renderModalBody()
                    end)
                end

                local ruleActionsRow = make("Frame", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundTransparency = 1,
                    ZIndex = 100004,
                }, leftScroll)
                list(Enum.HorizontalAlignment.Center, 4, ruleActionsRow).FillDirection = Enum.FillDirection.Horizontal

                local btnAddRule = make("TextButton", {
                    Size = UDim2.new(0.55, -2, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(24, 32, 50),
                    Text = "+ Add rule",
                    TextColor3 = Color3.fromRGB(0, 200, 255),
                    TextSize = 9, Font = Enum.Font.MontserratBold,
                    BorderSizePixel = 0, ZIndex = 100005,
                }, ruleActionsRow)
                corner(4, btnAddRule); stroke(1, C.border, btnAddRule)

                btnAddRule.MouseButton1Click:Connect(function()
                    table.insert(rules, {
                        name = "New Rule",
                        appliesTo = "ALL",
                        items = {},
                        mutations = {},
                        categories = {},
                        rarities = {},
                        isTypes = {},
                        worthMin = 0, worthMax = 0,
                        weightMin = 0, weightMax = 0,
                        effects = {},
                    })
                    currentSelectedRuleIdx = #rules
                    saveConfig()
                    renderModalBody()
                end)

                local btnClearRule = make("TextButton", {
                    Size = UDim2.new(0.45, -2, 1, 0),
                    BackgroundColor3 = Color3.fromRGB(30, 22, 28),
                    Text = "Clear rule",
                    TextColor3 = C.red,
                    TextSize = 9, Font = Enum.Font.MontserratBold,
                    BorderSizePixel = 0, ZIndex = 100005,
                }, ruleActionsRow)
                corner(4, btnClearRule); stroke(1, C.border, btnClearRule)

                btnClearRule.MouseButton1Click:Connect(function()
                    local cur = rules[currentSelectedRuleIdx]
                    if cur then
                        cur.name = "empty"
                        cur.items = {}
                        cur.mutations = {}
                        cur.categories = {}
                        cur.rarities = {}
                        cur.isTypes = {}
                        cur.worthMin = 0; cur.worthMax = 0
                        cur.weightMin = 0; cur.weightMax = 0
                        cur.effects = {}
                        saveConfig()
                        renderModalBody()
                    end
                end)

                local activeRule = rules[currentSelectedRuleIdx]
                if not activeRule then
                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 50),
                        BackgroundTransparency = 1,
                        Text = "No rules defined yet.\nClick \"+ Add rule\" on the left to create your first rule.",
                        TextColor3 = C.text2,
                        TextSize = 10, Font = Enum.Font.Montserrat,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        ZIndex = 100003,
                    }, rightPane)
                else
                    activeRule.items = activeRule.items or {}
                    activeRule.mutations = activeRule.mutations or {}
                    activeRule.categories = activeRule.categories or {}
                    activeRule.rarities = activeRule.rarities or {}
                    activeRule.isTypes = activeRule.isTypes or {}
                    activeRule.effects = activeRule.effects or {}

                    local nameRow = make("Frame", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundTransparency = 1,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(0, 50, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "Call it",
                        TextColor3 = C.text2,
                        TextSize = 10, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100004,
                    }, nameRow)

                    local nameBox = make("TextBox", {
                        Size = UDim2.new(1, -55, 1, 0),
                        Position = UDim2.new(0, 55, 0, 0),
                        BackgroundColor3 = Color3.fromRGB(20, 26, 38),
                        Text = activeRule.name or "",
                        PlaceholderText = "Rule name...",
                        TextColor3 = C.text,
                        PlaceholderColor3 = C.text2,
                        TextSize = 10, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BorderSizePixel = 0, ClearTextOnFocus = false,
                        ZIndex = 100004,
                    }, nameRow)
                    corner(4, nameBox); pad(6, nameBox); stroke(1, C.border, nameBox)

                    nameBox.FocusLost:Connect(function()
                        activeRule.name = nameBox.Text
                        saveConfig()
                        renderModalBody()
                    end)

                    local appliesRow = make("Frame", {
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundTransparency = 1,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(0, 90, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "APPLIES TO:",
                        TextColor3 = Color3.fromRGB(0, 200, 255),
                        TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100004,
                    }, appliesRow)

                    local isAll = (activeRule.appliesTo ~= "ANY")
                    local btnAll = make("TextButton", {
                        Size = UDim2.new(0, 55, 1, 0),
                        Position = UDim2.new(0, 95, 0, 0),
                        BackgroundColor3 = isAll and Color3.fromRGB(60, 120, 220) or C.card,
                        Text = "ALL", TextColor3 = isAll and Color3.fromRGB(255, 255, 255) or C.text2,
                        TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        BorderSizePixel = 0, ZIndex = 100004,
                    }, appliesRow)
                    corner(4, btnAll)

                    local btnAny = make("TextButton", {
                        Size = UDim2.new(0, 55, 1, 0),
                        Position = UDim2.new(0, 155, 0, 0),
                        BackgroundColor3 = (not isAll) and Color3.fromRGB(60, 120, 220) or C.card,
                        Text = "ANY", TextColor3 = (not isAll) and Color3.fromRGB(255, 255, 255) or C.text2,
                        TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        BorderSizePixel = 0, ZIndex = 100004,
                    }, appliesRow)
                    corner(4, btnAny)

                    btnAll.MouseButton1Click:Connect(function() activeRule.appliesTo = "ALL"; saveConfig(); renderModalBody() end)
                    btnAny.MouseButton1Click:Connect(function() activeRule.appliesTo = "ANY"; saveConfig(); renderModalBody() end)

                    makeInspectorSelectorRow(rightPane, "Item name", activeRule.items, getLiveCatalogItems, "Item Names")
                    makeInspectorSelectorRow(rightPane, "Mutation", activeRule.mutations, function() return knownMutationsList end, "Mutations")
                    makeInspectorSelectorRow(rightPane, "Category", activeRule.categories, getLiveCategories, "Categories")
                    makeInspectorSelectorRow(rightPane, "Rarity", activeRule.rarities, function() return knownRaritiesList end, "Rarities")
                    makeInspectorSelectorRow(rightPane, "Is", activeRule.isTypes, function() return knownIsTypesList end, "Types")

                    local worthRow = make("Frame", {
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundTransparency = 1,
                        ZIndex = 100003,
                    }, rightPane)

                    make("TextLabel", {
                        Size = UDim2.new(0, 95, 1, 0),
                        BackgroundTransparency = 1,
                        Text = "Worth range",
                        TextColor3 = C.text2, TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 100004,
                    }, worthRow)

                    local minWBox = make("TextBox", {
                        Size = UDim2.new(0, 75, 1, 0),
                        Position = UDim2.new(0, 100, 0, 0),
                        BackgroundColor3 = Color3.fromRGB(20, 26, 38),
                        Text = tostring(activeRule.worthMin or 0),
                        TextColor3 = C.text, TextSize = 9, Font = Enum.Font.Montserrat,
                        BorderSizePixel = 0, ClearTextOnFocus = false, ZIndex = 100004,
                    }, worthRow)
                    corner(4, minWBox); stroke(1, C.border, minWBox)
                    minWBox.FocusLost:Connect(function()
                        activeRule.worthMin = tonumber(minWBox.Text) or 0
                        saveConfig()
                    end)

                    make("TextLabel", {
                        Size = UDim2.new(0, 20, 1, 0),
                        Position = UDim2.new(0, 180, 0, 0),
                        BackgroundTransparency = 1, Text = "to",
                        TextColor3 = C.textMuted, TextSize = 9, Font = Enum.Font.Montserrat, ZIndex = 100004,
                    }, worthRow)

                    local maxWBox = make("TextBox", {
                        Size = UDim2.new(0, 75, 1, 0),
                        Position = UDim2.new(0, 205, 0, 0),
                        BackgroundColor3 = Color3.fromRGB(20, 26, 38),
                        Text = tostring(activeRule.worthMax or 0),
                        TextColor3 = C.text, TextSize = 9, Font = Enum.Font.Montserrat,
                        BorderSizePixel = 0, ClearTextOnFocus = false, ZIndex = 100004,
                    }, worthRow)
                    corner(4, maxWBox); stroke(1, C.border, maxWBox)
                    maxWBox.FocusLost:Connect(function()
                        activeRule.worthMax = tonumber(maxWBox.Text) or 0
                        saveConfig()
                    end)

                    make("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 18),
                        BackgroundTransparency = 1,
                        Text = "RULE EFFECTS (10 Actions)",
                        TextColor3 = Color3.fromRGB(0, 200, 255),
                        TextSize = 9.5, Font = Enum.Font.MontserratBold,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 100003,
                    }, rightPane)

                    local effectsGrid = make("Frame", {
                        Size = UDim2.new(1, 0, 0, 120),
                        BackgroundTransparency = 1,
                        ZIndex = 100003,
                    }, rightPane)

                    local eff = activeRule.effects
                    local function makeEffToggle(xOff, yOff, name, key, mutuallyExclusiveKey)
                        local isChecked = (eff[key] == true)
                        local chk = make("TextButton", {
                            Size = UDim2.new(0.48, -4, 0, 20),
                            Position = UDim2.new(xOff, 0, 0, yOff),
                            BackgroundColor3 = isChecked and Color3.fromRGB(28, 38, 58) or Color3.fromRGB(18, 22, 32),
                            Text = (isChecked and " [X]  " or " [ ]  ") .. name,
                            TextColor3 = isChecked and Color3.fromRGB(0, 215, 255) or C.text2,
                            TextSize = 9, Font = Enum.Font.MontserratBold,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            BorderSizePixel = 0, AutoButtonColor = false,
                            ZIndex = 100004,
                        }, effectsGrid)
                        corner(4, chk)
                        chk.MouseButton1Click:Connect(function()
                            local nVal = not isChecked
                            eff[key] = nVal
                            if nVal and mutuallyExclusiveKey then eff[mutuallyExclusiveKey] = false end
                            saveConfig()
                            renderModalBody()
                        end)
                    end

                    makeEffToggle(0, 0, "Always pick up", "always_pickup", "never_pickup")
                    makeEffToggle(0.5, 0, "Never pick up", "never_pickup", "always_pickup")

                    makeEffToggle(0, 24, "Allow selling", "allow_selling", "never_sell")
                    makeEffToggle(0.5, 24, "Never sell", "never_sell", "allow_selling")

                    makeEffToggle(0, 48, "Allow placing", "allow_placing", "never_place")
                    makeEffToggle(0.5, 48, "Never place", "never_place", "allow_placing")

                    makeEffToggle(0, 72, "Allow grading", "allow_grading", "never_grade")
                    makeEffToggle(0.5, 72, "Never grade", "never_grade", "allow_grading")

                    makeEffToggle(0, 96, "Never wash", "never_wash", nil)
                    makeEffToggle(0.5, 96, "Ignore Min Bid", "ignore_min_bid", nil)
                end
            end
        end

        btnRulesTab.MouseButton1Click:Connect(function()
            currentSubtab = "rules"
            renderModalBody()
        end)
        btnListsTab.MouseButton1Click:Connect(function()
            currentSubtab = "lists"
            renderModalBody()
        end)

        _G.refreshItemRulesModal = renderModalBody
        renderModalBody()

        -- ── 5. LAUNCHER TAB IN MAIN WINDOW (`tabItemRules`) ──
        list(nil, 6, tabItemRules)

        local launcherHeader = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Color3.fromRGB(24, 30, 46),
            BorderSizePixel = 0,
        }, tabItemRules)
        corner(6, launcherHeader)

        make("TextLabel", {
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = "ITEM RULES & LANE LIFECYCLE (BETA)",
            TextColor3 = Color3.fromRGB(0, 200, 255),
            TextSize = 10, Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, launcherHeader)

        local openEditorBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(18, 26, 44),
            Text = "Open the rule editor",
            TextColor3 = Color3.fromRGB(0, 215, 255),
            TextSize = 11, Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0, AutoButtonColor = false,
        }, tabItemRules)
        corner(6, openEditorBtn)
        stroke(1.5, Color3.fromRGB(0, 180, 255), openEditorBtn)

        openEditorBtn.MouseButton1Click:Connect(function()
            ItemRulesModal.Visible = not ItemRulesModal.Visible
            if ItemRulesModal.Visible then
                renderModalBody()
            end
        end)

        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "Shortcut: Press [ J ] to toggle the rule editor anytime.",
            TextColor3 = C.gold,
            TextSize = 9.5, Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        }, tabItemRules)

        local statsCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 80),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabItemRules)
        corner(6, statsCard); pad(8, statsCard); stroke(1, C.border, statsCard)

        local statsLabel = make("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "Loading rules configuration...",
            TextColor3 = C.text2,
            TextSize = 9, Font = Enum.Font.Montserrat,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
        }, statsCard)

        local function updateLauncherStats()
            local ruleCnt = gConfig.itemRules and #gConfig.itemRules or 0
            local pCnt = getLaneTotalFilters("Pickup")
            local sCnt = getLaneTotalFilters("Shelves")
            local aCnt = getLaneTotalFilters("AutoSell")
            local gCnt = getLaneTotalFilters("Grading")
            local aucCnt = getLaneTotalFilters("Auction")

            statsLabel.Text = string.format(
                "Active Custom Rules: %d\n" ..
                "Active Lane Filters: Pickup (%d) | Shelves (%d) | AutoSell (%d) | Grading (%d) | Auction (%d)\n\n" ..
                "Evaluation Order: Custom Rules (First match wins) -> Default Lane Lists -> Tab Settings fallback.",
                ruleCnt, pCnt, sCnt, aCnt, gCnt, aucCnt
            )
        end
        updateLauncherStats()

        -- ── 6. HOTKEY LISTENER FOR [ J ] ──
        table.insert(cleanUpSignals, UserInputService.InputBegan:Connect(function(inp, gpe)
            if not gpe and inp.KeyCode == Enum.KeyCode.J then
                ItemRulesModal.Visible = not ItemRulesModal.Visible
                if ItemRulesModal.Visible then
                    renderModalBody()
                end
            end
        end))

    end -- end Item Rules system block

    -- DEDICATED CHARMS TAB SETUP
    do
        -- GAVEL CHARM AUTOMATION SECTION
        local charmHeaderCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Color3.fromRGB(24, 30, 44),
            BorderSizePixel = 0,
        }, tabCharms)
        corner(6, charmHeaderCard)
        make("TextLabel", {
            Size = UDim2.new(1, -20, 1, 0),
            Position = UDim2.new(0, 10, 0, 0),
            BackgroundTransparency = 1,
            Text = "GAVEL CHARM AUTOMATION",
            TextColor3 = Color3.fromRGB(0, 240, 200),
            Font = Enum.Font.MontserratBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, charmHeaderCard)

        local charmToggleCard, updateCharmToggle = createToggle(tabCharms, "Auto Claim Diamond Charm (60m)", gConfig.autoClaimDiamondCharm, function(state)
            gConfig.autoClaimDiamondCharm = state
            saveConfig()
            if state then
                abLog("[Diamond Charm] Auto Claim enabled.", C.green)
            else
                abLog("[Diamond Charm] Auto Claim disabled.", C.text2)
            end
        end)
        _G.uiToggles["autoClaimDiamondCharm"] = updateCharmToggle

        -- Status & Test Card
        local charmStatusCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 46),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabCharms)
        corner(6, charmStatusCard)

        local charmStatusLbl = make("TextLabel", {
            Size = UDim2.new(0.65, 0, 0, 18),
            Position = UDim2.new(0, 10, 0, 5),
            BackgroundTransparency = 1,
            Text = "Status: Checking plot...",
            TextColor3 = C.gold,
            Font = Enum.Font.MontserratBold,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, charmStatusCard)

        local charmSubLbl = make("TextLabel", {
            Size = UDim2.new(0.65, 0, 0, 16),
            Position = UDim2.new(0, 10, 0, 24),
            BackgroundTransparency = 1,
            Text = "Last Claimed: Never",
            TextColor3 = C.text2,
            Font = Enum.Font.Montserrat,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, charmStatusCard)

        local testClaimBtn = make("TextButton", {
            Size = UDim2.new(0.30, 0, 0, 28),
            Position = UDim2.new(0.68, 0, 0.5, -14),
            BackgroundColor3 = Color3.fromRGB(30, 45, 65),
            Text = "Claim Now",
            TextColor3 = C.accent,
            Font = Enum.Font.MontserratBold,
            TextSize = 9,
            BorderSizePixel = 0,
        }, charmStatusCard)
        corner(4, testClaimBtn)
        stroke(1, C.accent, testClaimBtn)
        testClaimBtn.MouseButton1Click:Connect(function()
            if _G.triggerDiamondCharmRoutine then
                abLog("[Diamond Charm] Manual test claim triggered!", C.cyan)
                _G.triggerDiamondCharmRoutine(true)
            else
                abLog("[Diamond Charm] Charm routine not ready yet.", C.red)
            end
        end)

        -- Live status updater for the UI label
        task.spawn(function()
            while task.wait(1) do
                if _G.AHScanner_RunID ~= myRunID then break end
                pcall(function()
                    if not charmStatusLbl or not charmStatusLbl.Parent then return end
                    if not gConfig.autoClaimDiamondCharm then
                        charmStatusLbl.Text = "Status: Disabled"
                        charmStatusLbl.TextColor3 = C.text2
                        return
                    end
                    
                    -- Check if a charm prompt actively exists on the live plot
                    local livePrompt = nil
                    if _G.findDiamondCharmPrompt then
                        livePrompt = _G.findDiamondCharmPrompt()
                    end
                    
                    if livePrompt then
                        local act = tostring(livePrompt.ActionText or ""):lower()
                        local mins = act:match("ready%s*in%s*(%d+)%s*m")
                        local secs = act:match("ready%s*in%s*(%d+)%s*s")
                        if mins then
                            charmStatusLbl.Text = "Status: Ready in " .. mins .. "m (In-Game)"
                            charmStatusLbl.TextColor3 = C.gold
                        elseif secs then
                            charmStatusLbl.Text = "Status: Ready in " .. secs .. "s (In-Game)"
                            charmStatusLbl.TextColor3 = C.gold
                        elseif act:find("claim") or act == "e" or (livePrompt.Enabled and not act:find("ready")) then
                            charmStatusLbl.Text = "Status: Ready to Claim!"
                            charmStatusLbl.TextColor3 = Color3.fromRGB(0, 240, 120)
                        else
                            charmStatusLbl.Text = "Status: " .. tostring(livePrompt.ActionText)
                            charmStatusLbl.TextColor3 = C.gold
                        end
                    else
                        charmStatusLbl.Text = "Status: No Charm on Plot"
                        charmStatusLbl.TextColor3 = Color3.fromRGB(255, 110, 110)
                    end
                    
                    if charmSubLbl and charmSubLbl.Parent then
                        local last = tonumber(gConfig.lastDiamondCharmClaim or 0)
                        if last == 0 then
                            charmSubLbl.Text = "Last Claimed: Never"
                        else
                            charmSubLbl.Text = "Last Claimed: " .. os.date("%H:%M:%S", last)
                        end
                    end
                end)
            end
        end)
    end

    -- [Folder] PROFILES & CONFIG MANAGER TAB
    do
        -- list/pad already applied by createTab("Profiles")

        local activeProfileLabel
        local refreshProfileDropdown

        -- Helper to fetch all profiles live from filesystem
        local function getLiveProfiles()
            local profiles = {}
            local seen = {}
            pcall(function()
                if not isfolder("NexHub") then makefolder("NexHub") end
                if not isfolder(configBaseFolder) then makefolder(configBaseFolder) end
                if not isfolder(configSettingsFolder) then makefolder(configSettingsFolder) end
                
                if listfiles then
                    local files = listfiles(configSettingsFolder)
                    for _, path in ipairs(files) do
                        local name = path:match("([^\\/]+)%.json$")
                        if name and name ~= "furniture_cache" and not seen[name] then
                            seen[name] = true
                            table.insert(profiles, name)
                        end
                    end
                end
            end)
            if not seen["default"] then
                table.insert(profiles, "default")
            end
            table.sort(profiles)
            return profiles
        end

        local selectedProfileToLoad = currentProfileName or "default"
        local resetDeleteBtn = function() end

        -- Card 1: Active Configuration Banner & Manual Save Button
        local activeCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = C.panel,
            BorderSizePixel = 0,
        }, tabConfig)
        corner(8, activeCard)
        stroke(1, C.accent, activeCard)

        make("TextLabel", {
            Size = UDim2.new(0.55, 0, 0, 20),
            Position = UDim2.new(0, 12, 0, 8),
            BackgroundTransparency = 1,
            Text = "Active Profile:",
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, activeCard)

        activeProfileLabel = make("TextLabel", {
            Size = UDim2.new(0.55, 0, 0, 22),
            Position = UDim2.new(0, 12, 0, 26),
            BackgroundTransparency = 1,
            Text = (currentProfileName or "default") .. ".json",
            TextColor3 = C.gold,
            TextSize = 13,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, activeCard)

        local manualSaveBtn = make("TextButton", {
            Size = UDim2.new(0.4, -12, 0, 36),
            Position = UDim2.new(0.6, 0, 0.5, -18),
            BackgroundColor3 = Color3.fromRGB(35, 80, 55),
            Text = "Save Config",
            TextColor3 = Color3.fromRGB(120, 255, 170),
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, activeCard)
        corner(6, manualSaveBtn)
        stroke(1, Color3.fromRGB(60, 180, 100), manualSaveBtn)

        manualSaveBtn.MouseButton1Click:Connect(function()
            if _G.flushInputValues then pcall(_G.flushInputValues) end
            local prof = currentProfileName or "default"
            local ok, err = saveConfig(prof)
            if ok then
                abLog("Config successfully saved to " .. prof .. ".json", C.green)
                manualSaveBtn.Text = "Saved!"
                manualSaveBtn.TextColor3 = Color3.fromRGB(80, 255, 140)
                task.delay(2, function()
                    if manualSaveBtn and manualSaveBtn.Parent then
                        manualSaveBtn.Text = "Save Config"
                        manualSaveBtn.TextColor3 = Color3.fromRGB(120, 255, 170)
                    end
                end)
            else
                abLog("[X] Error saving config: " .. tostring(err), C.red)
                manualSaveBtn.Text = "Save Failed"
                manualSaveBtn.TextColor3 = C.red
                task.delay(2, function()
                    if manualSaveBtn and manualSaveBtn.Parent then
                        manualSaveBtn.Text = "Save Config"
                        manualSaveBtn.TextColor3 = Color3.fromRGB(120, 255, 170)
                    end
                end)
            end
        end)

        -- Card 2: Autoload Configuration on Startup
        local autoloadCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 60),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabConfig)
        corner(8, autoloadCard)
        stroke(1, C.border, autoloadCard)

        make("TextLabel", {
            Size = UDim2.new(0.68, 0, 0, 18),
            Position = UDim2.new(0, 12, 0, 8),
            BackgroundTransparency = 1,
            Text = "* Autoload on Startup:",
            TextColor3 = C.text2,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, autoloadCard)

        local autoloadStatusLabel = make("TextLabel", {
            Size = UDim2.new(0.68, 0, 0, 22),
            Position = UDim2.new(0, 12, 0, 28),
            BackgroundTransparency = 1,
            Text = "Loading...",
            TextColor3 = C.gold,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, autoloadCard)

        local autoloadToggleBtn = make("TextButton", {
            Size = UDim2.new(0.28, -12, 0, 36),
            Position = UDim2.new(0.72, 0, 0.5, -18),
            BackgroundColor3 = Color3.fromRGB(30, 65, 45),
            Text = "* ON",
            TextColor3 = Color3.fromRGB(120, 255, 170),
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, autoloadCard)
        corner(6, autoloadToggleBtn)
        local autoloadToggleStroke = stroke(1, Color3.fromRGB(60, 180, 100), autoloadToggleBtn)

        local function updateAutoloadDisplay()
            local autoName, isAuto = getAutoloadInfo()
            if isAuto and autoName and autoName ~= "" then
                autoloadStatusLabel.Text = autoName .. ".json"
                autoloadStatusLabel.TextColor3 = C.gold
                autoloadToggleBtn.Text = "* ON"
                autoloadToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 65, 45)
                autoloadToggleBtn.TextColor3 = Color3.fromRGB(120, 255, 170)
                autoloadToggleStroke.Color = Color3.fromRGB(60, 180, 100)
            else
                autoloadStatusLabel.Text = "Disabled (Boots with Clean Defaults)"
                autoloadStatusLabel.TextColor3 = Color3.fromRGB(160, 155, 175)
                autoloadToggleBtn.Text = "OFF"
                autoloadToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 45)
                autoloadToggleBtn.TextColor3 = Color3.fromRGB(180, 175, 190)
                autoloadToggleStroke.Color = Color3.fromRGB(80, 75, 95)
            end
        end

        autoloadToggleBtn.MouseButton1Click:Connect(function()
            local autoName, isAuto = getAutoloadInfo()
            if isAuto then
                setAutoloadInfo("none", false)
                abLog("Autoload on startup disabled", C.orange)
            else
                local target = selectedProfileToLoad or currentProfileName or "default"
                setAutoloadInfo(target, true)
                abLog("* Autoload enabled for: " .. target .. ".json", C.green)
            end
            updateAutoloadDisplay()
            if refreshProfileDropdown then refreshProfileDropdown() end
        end)

        -- Card 3: Live Profile Selector & Actions (Load / Set Autoload / Delete)
        local selectorCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabConfig)
        corner(8, selectorCard)
        stroke(1, C.border, selectorCard)
        pad(8, selectorCard)
        list(Enum.HorizontalAlignment.Left, 6, selectorCard)

        make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16),
            BackgroundTransparency = 1,
            Text = "Select Profile:",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, selectorCard)

        local ddBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = COLORS.BG,
            Text = selectedProfileToLoad .. ".json  ▼",
            TextColor3 = C.gold,
            TextSize = 11,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, selectorCard)
        corner(6, ddBtn)
        stroke(1, C.border, ddBtn)

        local ddList = make("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Visible = false,
        }, selectorCard)
        list(Enum.HorizontalAlignment.Left, 3, ddList)

        refreshProfileDropdown = function()
            for _, c in ipairs(ddList:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            local live = getLiveProfiles()
            local autoName, isAuto = getAutoloadInfo()
            for _, pName in ipairs(live) do
                local isThisAutoload = (isAuto and pName == autoName)
                local isThisActive = (pName == currentProfileName)
                local tag = ""
                if isThisActive and isThisAutoload then
                    tag = " (Active, * Autoload)"
                elseif isThisActive then
                    tag = " (Active)"
                elseif isThisAutoload then
                    tag = " (* Autoload)"
                end

                local pBtn = make("TextButton", {
                    Size = UDim2.new(1, 0, 0, 24),
                    BackgroundColor3 = (pName == selectedProfileToLoad) and Color3.fromRGB(45, 30, 65) or Color3.fromRGB(28, 22, 38),
                    Text = "  " .. pName .. tag,
                    TextColor3 = isThisAutoload and C.gold or (isThisActive and C.accent or C.text),
                    TextSize = 10,
                    Font = Enum.Font.MontserratBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    BorderSizePixel = 0,
                    AutoButtonColor = true,
                }, ddList)
                corner(4, pBtn)
                local capP = pName
                pBtn.MouseButton1Click:Connect(function()
                    resetDeleteBtn()
                    selectedProfileToLoad = capP
                    ddBtn.Text = selectedProfileToLoad .. ".json  ▼"
                    ddList.Visible = false
                end)
            end
        end

        ddBtn.MouseButton1Click:Connect(function()
            resetDeleteBtn()
            ddList.Visible = not ddList.Visible
            ddBtn.Text = selectedProfileToLoad .. ".json  " .. (ddList.Visible and "▲" or "▼")
            if ddList.Visible then
                refreshProfileDropdown()
            end
        end)

        -- Row 1 of buttons: Load Profile & Set as Autoload
        local actionRow = make("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, selectorCard)

        local loadBtn = make("TextButton", {
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(30, 45, 80),
            Text = "Load Profile",
            TextColor3 = Color3.fromRGB(120, 180, 255),
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, actionRow)
        corner(6, loadBtn)
        stroke(1, Color3.fromRGB(60, 110, 200), loadBtn)

        loadBtn.MouseButton1Click:Connect(function()
            local ok = loadConfig(selectedProfileToLoad)
            if ok then
                activeProfileLabel.Text = selectedProfileToLoad .. ".json"
                syncUI()
                if _G.rebuildExclusionChips then pcall(_G.rebuildExclusionChips) end
                if _G.refreshExclusionItemList then pcall(_G.refreshExclusionItemList) end
                if _G.refreshMutDropdown then pcall(_G.refreshMutDropdown) end
                abLog("Profile loaded: " .. selectedProfileToLoad .. ".json", C.green)
                loadBtn.Text = "Loaded!"
                loadBtn.TextColor3 = Color3.fromRGB(80, 200, 255)
                task.delay(2, function()
                    if loadBtn and loadBtn.Parent then
                        loadBtn.Text = "Load Profile"
                        loadBtn.TextColor3 = Color3.fromRGB(120, 180, 255)
                    end
                end)
                if refreshProfileDropdown then refreshProfileDropdown() end
            else
                abLog("[X] Failed to load profile: " .. selectedProfileToLoad, C.red)
                loadBtn.Text = "Load Failed"
                loadBtn.TextColor3 = C.red
                task.delay(2, function()
                    if loadBtn and loadBtn.Parent then
                        loadBtn.Text = "Load Profile"
                        loadBtn.TextColor3 = Color3.fromRGB(120, 180, 255)
                    end
                end)
            end
        end)

        local setAutoloadBtn = make("TextButton", {
            Size = UDim2.new(0.5, -4, 1, 0),
            Position = UDim2.new(0.5, 4, 0, 0),
            BackgroundColor3 = Color3.fromRGB(48, 40, 22),
            Text = "* Set as Autoload",
            TextColor3 = C.gold,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, actionRow)
        corner(6, setAutoloadBtn)
        stroke(1, Color3.fromRGB(180, 140, 50), setAutoloadBtn)

        setAutoloadBtn.MouseButton1Click:Connect(function()
            setAutoloadInfo(selectedProfileToLoad, true)
            updateAutoloadDisplay()
            if refreshProfileDropdown then refreshProfileDropdown() end
            abLog("* Profile set as Autoload: " .. selectedProfileToLoad .. ".json", C.green)
            setAutoloadBtn.Text = "Set as Autoload!"
            setAutoloadBtn.TextColor3 = Color3.fromRGB(120, 255, 170)
            task.delay(2, function()
                if setAutoloadBtn and setAutoloadBtn.Parent then
                    setAutoloadBtn.Text = "* Set as Autoload"
                    setAutoloadBtn.TextColor3 = C.gold
                end
            end)
        end)

        -- Row 2 of buttons: Delete Profile (with safety confirmation)
        local delBtn = make("TextButton", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundColor3 = Color3.fromRGB(60, 22, 28),
            Text = "Delete Profile",
            TextColor3 = Color3.fromRGB(255, 120, 120),
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, selectorCard)
        corner(6, delBtn)
        local delStroke = stroke(1, Color3.fromRGB(160, 50, 60), delBtn)

        local isConfirmingDelete = false
        local deleteTimeoutThread = nil

        resetDeleteBtn = function()
            isConfirmingDelete = false
            if deleteTimeoutThread then
                pcall(task.cancel, deleteTimeoutThread)
                deleteTimeoutThread = nil
            end
            if delBtn and delBtn.Parent then
                delBtn.Text = "Delete Profile"
                delBtn.BackgroundColor3 = Color3.fromRGB(60, 22, 28)
                delBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
                delStroke.Color = Color3.fromRGB(160, 50, 60)
            end
        end

        delBtn.MouseButton1Click:Connect(function()
            if selectedProfileToLoad == "default" then
                resetDeleteBtn()
                abLog("[Warning] Cannot delete the 'default' configuration profile!", C.orange)
                return
            end

            -- Step 1: Ask for confirmation
            if not isConfirmingDelete then
                isConfirmingDelete = true
                delBtn.Text = "Confirm Delete " .. selectedProfileToLoad .. "? (Click again)"
                delBtn.BackgroundColor3 = Color3.fromRGB(130, 20, 30)
                delBtn.TextColor3 = Color3.fromRGB(255, 240, 240)
                delStroke.Color = Color3.fromRGB(255, 75, 85)
                abLog("[Warning] Press 'Delete Profile' again within 5s to delete: " .. selectedProfileToLoad .. ".json", C.orange)

                deleteTimeoutThread = task.delay(5, function()
                    resetDeleteBtn()
                end)
                return
            end

            -- Step 2: Confirmed! Execute deletion
            resetDeleteBtn()
            local targetFile = configSettingsFolder .. "/" .. selectedProfileToLoad .. ".json"
            local deleted = false
            pcall(function()
                if delfile then delfile(targetFile); deleted = true
                elseif deletefile then deletefile(targetFile); deleted = true end
            end)
            if deleted then
                abLog("[Trash] Deleted profile: " .. selectedProfileToLoad, C.red)
                local autoName, isAuto = getAutoloadInfo()
                if autoName == selectedProfileToLoad then
                    setAutoloadInfo("default", true)
                    updateAutoloadDisplay()
                end
                selectedProfileToLoad = "default"
                ddBtn.Text = "default.json  ▼"
                loadConfig("default")
                activeProfileLabel.Text = "default.json"
                syncUI()
                if _G.rebuildExclusionChips then pcall(_G.rebuildExclusionChips) end
                if _G.refreshExclusionItemList then pcall(_G.refreshExclusionItemList) end
                if _G.refreshMutDropdown then pcall(_G.refreshMutDropdown) end
                if refreshProfileDropdown then refreshProfileDropdown() end
            else
                abLog("[X] Failed to delete file (function not supported by executor)", C.red)
            end
        end)

        -- Initialize Autoload Card Display
        updateAutoloadDisplay()

        -- Card 3: Create New Profile (Save As)
        local newCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 84),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
        }, tabConfig)
        corner(8, newCard)
        stroke(1, C.border, newCard)

        make("TextLabel", {
            Size = UDim2.new(1, -20, 0, 20),
            Position = UDim2.new(0, 10, 0, 6),
            BackgroundTransparency = 1,
            Text = "Create New Profile (Save As):",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, newCard)

        local newNameBox = make("TextBox", {
            Size = UDim2.new(0.6, -15, 0, 32),
            Position = UDim2.new(0, 10, 0, 34),
            BackgroundColor3 = COLORS.BG,
            Text = "",
            PlaceholderText = "Profile name (e.g. night_farm)",
            TextColor3 = C.gold,
            PlaceholderColor3 = C.text2,
            Font = Enum.Font.MontserratBold,
            TextSize = 10,
            ClearTextOnFocus = false,
            BorderSizePixel = 0,
        }, newCard)
        corner(6, newNameBox)
        stroke(1, C.border, newNameBox)

        local createBtn = make("TextButton", {
            Size = UDim2.new(0.4, -15, 0, 32),
            Position = UDim2.new(0.6, 5, 0, 34),
            BackgroundColor3 = Color3.fromRGB(45, 30, 65),
            Text = "Save As New",
            TextColor3 = C.accent,
            TextSize = 10,
            Font = Enum.Font.MontserratBold,
            BorderSizePixel = 0,
            AutoButtonColor = true,
        }, newCard)
        corner(6, createBtn)
        stroke(1, Color3.fromRGB(110, 60, 180), createBtn)

        createBtn.MouseButton1Click:Connect(function()
            if _G.flushInputValues then pcall(_G.flushInputValues) end
            local raw = newNameBox.Text:match("^%s*(.-)%s*$")
            if not raw or raw == "" then
                abLog("[Warning] Please enter a profile name first!", C.orange)
                return
            end
            local clean = raw:gsub("[^%w_%-]", "_")
            saveConfig(clean)
            activeProfileLabel.Text = clean .. ".json"
            selectedProfileToLoad = clean
            ddBtn.Text = clean .. ".json"
            newNameBox.Text = ""
            refreshProfileDropdown()
            abLog("Saved new profile: " .. clean .. ".json", C.green)
        end)

        -- Card 4: Directory Info
        local infoCard = make("Frame", {
            Size = UDim2.new(1, 0, 0, 48),
            BackgroundColor3 = Color3.fromRGB(16, 14, 24),
            BorderSizePixel = 0,
        }, tabConfig)
        corner(6, infoCard)
        stroke(1, Color3.fromRGB(35, 30, 50), infoCard)

        make("TextLabel", {
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = "Storage: workspace/NexHub/StorageHunters/settings/\nYou can copy, backup, or share your .json configs anytime!",
            TextColor3 = C.text2,
            TextSize = 9,
            Font = Enum.Font.MontserratMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
        }, infoCard)
    end

local AuctionPickupEnd = AuctionEvents and AuctionEvents:FindFirstChild("AuctionPickupEnd")
if AuctionPickupEnd then
    table.insert(cleanUpSignals, AuctionPickupEnd.OnClientEvent:Connect(function()
        if not _G.AHPickupCycleRunning then
            AB.pickupPhase = false
            AB.weAreWinning = false
        end
        abLog("[Freight] Pickup phase ended!", C.text2)
    end))
end

-- Auto-Place Incompatible Slot Tracker & Toast Listener
_G.AHIncompatibleSlots = _G.AHIncompatibleSlots or {}
_G.AHUnsellableGuids = _G.AHUnsellableGuids or {}
local function handlePlaceErrorToast(msg)
    if type(msg) ~= "string" then return end
    local lowerMsg = msg:lower()
    if lowerMsg:find("won't fit") then
        if _G.AHLastPlacingGuid and _G.AHLastPlacingSlotId then
            _G.AHIncompatibleSlots[_G.AHLastPlacingGuid .. "_" .. _G.AHLastPlacingSlotId] = true
        end
    elseif lowerMsg:find("cannot sell") or lowerMsg:find("can't be shelved") or lowerMsg:find("no sell value") or lowerMsg:find("%[quest%]") then
        if _G.AHLastPlacingGuid then
            _G.AHUnsellableGuids[_G.AHLastPlacingGuid] = true
        end
    end
end

local NotifyRemote = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("UI") and ReplicatedStorage.Events.UI:FindFirstChild("Notify")
if NotifyRemote then
    table.insert(cleanUpSignals, NotifyRemote.OnClientEvent:Connect(function(msg, ...)
        handlePlaceErrorToast(msg)
    end))
end

pcall(function()
    local ToastsMod = require(ReplicatedStorage.Modules.Screens.Toasts)
    if ToastsMod and type(ToastsMod.Show) == "function" and not _G.AHToastsHooked then
        _G.AHToastsHooked = true
        local oldShow = ToastsMod.Show
        ToastsMod.Show = function(self, msg, ...)
            handlePlaceErrorToast(msg)
            return oldShow(self, msg, ...)
        end
    end
end)

-- Cleanup Handler
_G.AHScanner_CleanUp = function()
    if AB.quickWinController then AB.quickWinController:Destroy() end
    pcall(function() game:GetService("RunService"):Set3dRenderingEnabled(true) end)
    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        if ugs then ugs.FramerateCap = 240 end
    end)
    pcall(function()
        local fn = setfpscap or set_fps_cap
        if fn then fn(999) end
    end)
    if AB then
        AB.enabled = false
        AB.auctionOpen = false
        stopBidLoop()
    end
    for _, conn in ipairs(cleanUpSignals) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(cleanUpSignals)
    if _G.AHAutoPlaceThread then
        pcall(function() task.cancel(_G.AHAutoPlaceThread) end)
        _G.AHAutoPlaceThread = nil
    end
    pcall(function() ScreenGui:Destroy() end)
    print("NexWorks Cleaned up successfully.")
end

-- Open animations & defaults
Win.BackgroundTransparency = 1
task.wait(0.05)
tw(Win, 0.4, {BackgroundTransparency=0})

tabs["Main"].btn.BackgroundTransparency = 0
tabs["Main"].btn.BackgroundColor3 = COLORS.TabBtnActive
tabs["Main"].btn.TextColor3 = C.accent
tabs["Main"].frame.Visible = true
activeTab = tabs["Main"]
syncUI()

setShopType("Wash")
doScan()
print("NexWorks v16.1 Beta | High UNC Build | Loaded successfully!")

if _G.AHAutoPlaceThread then
    pcall(function() task.cancel(_G.AHAutoPlaceThread) end)
end

local function getItemSize(itemConf)
    local ok, w, d, h = pcall(function()
        if not itemConf then return 1, 1, 1 end
        local name = itemConf.Name
        local pgui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        local preview = pgui and pgui:FindFirstChild("ItemPreviewCache")
        local cache = game:GetService("ReplicatedStorage"):FindFirstChild("_StockCache")
        local model = (preview and preview:FindFirstChild(name)) or (cache and cache:FindFirstChild(name))
        if model then
            local boundingBoxSize
            if model:IsA("Model") then
                boundingBoxSize = model:GetExtentsSize()
            elseif model:IsA("BasePart") then
                boundingBoxSize = model.Size
            else
                boundingBoxSize = Vector3.new(0.5, 0.5, 0.5)
            end
            return boundingBoxSize.X * 0.82, boundingBoxSize.Z * 0.82, boundingBoxSize.Y
        end
        local cat = (itemConf.Category or ""):lower()
        if cat:find("large") or cat:find("giant") or cat:find("vehicle") or cat:find("structure") or cat:find("podium") then
            return 5, 5, 5
        end
        return 1.8, 1.8, 1.8
    end)
    if ok and w then return w, d, h else return 1.8, 1.8, 1.8 end
end

local function executeSmartPlotPlacement(force)
    local placedCount = 0
    local RS = game:GetService("ReplicatedStorage")
    local PlotEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Plot")
    local PlaceStockItem = PlotEvents and PlotEvents:FindFirstChild("PlaceStockItem")
    if not PlaceStockItem then return 0 end
    
    local inv = RS.Events.Inventory.GetPlayerInventory:InvokeServer()
    if not inv or not next(inv) then return 0 end
    
    local myPlot = getMyLivePlot and getMyLivePlot()
    if not myPlot then
        local lp = game:GetService("Players").LocalPlayer
        local plots = workspace:FindFirstChild("_Plots") or workspace:FindFirstChild("Plots")
        if plots then
            for _, p in ipairs(plots:GetChildren()) do
                local owner = p:GetAttribute("OwnerUserId") or p:GetAttribute("OwnerName")
                if owner == lp.UserId or tonumber(owner) == lp.UserId or tostring(owner) == lp.Name then
                    myPlot = p
                    break
                end
            end
        end
    end
    
    -- Check occupied items on plot stock (Authoritative server query works from any distance!)
    local occupied = {}
    local GetShopStock = PlotEvents and PlotEvents:FindFirstChild("GetShopStock")
    if GetShopStock and myPlot then
        local ok, stockList = pcall(function() return GetShopStock:InvokeServer(myPlot) end)
        if ok and type(stockList) == "table" then
            for _, entry in ipairs(stockList) do
                local attrs = entry.Attrs
                if attrs and attrs.ShelfGUID and attrs.SnapPointName then
                    local sId = tostring(attrs.ShelfGUID) .. "_" .. tostring(attrs.SnapPointName)
                    occupied[sId] = true
                end
            end
        end
    end
    -- Fallback: check workspace Stock folder if streamed in
    local Stock = myPlot and myPlot:FindFirstChild("Stock")
    if Stock then
        for _, item in ipairs(Stock:GetChildren()) do
            local shelfGuid = item:GetAttribute("ShelfGUID")
            local snapName = item:GetAttribute("SnapPointName")
            if shelfGuid and snapName then
                local sId = tostring(shelfGuid) .. "_" .. tostring(snapName)
                occupied[sId] = true
            end
        end
    end
    
    -- Update permanent Furniture Cache ONLY when physically near the plot (prevent streaming-out wipe!)
    local nearPlot = isNearMyPlot and isNearMyPlot(120)
    local Furniture = myPlot and myPlot:FindFirstChild("Furniture")
    if nearPlot and Furniture and #Furniture:GetChildren() > 0 then
        local tempCache = {}
        for _, shelf in ipairs(Furniture:GetDescendants()) do
            if shelf:IsA("Model") and shelf:GetAttribute("GUID") then
                local shelfGuid = tostring(shelf:GetAttribute("GUID"))
                local shelfName = shelf.Name or ""
                local isLargeFloorPodium = (shelfName:find("Large Floor Podium") ~= nil)
                local isPodium = (shelfName:lower():find("podium") ~= nil)
                for _, att in ipairs(shelf:GetDescendants()) do
                    if att:IsA("Attachment") and att.Name:match("^SnapPoint") then
                        local rawW = att:GetAttribute("SlotWidth")
                        local rawD = att:GetAttribute("SlotDepth")
                        local defW = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                        local defD = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                        table.insert(tempCache, {
                            shelfName = shelfName,
                            shelfGuid = shelfGuid,
                            snapName = att.Name,
                            targetCFrame = att.WorldCFrame,
                            slotWidth = rawW or defW,
                            slotDepth = rawD or defD,
                            isPodium = isPodium,
                            isLargeFloorPodium = isLargeFloorPodium,
                        })
                    end
                end
            end
        end
        if #tempCache > 0 and #tempCache >= (#_G.PlotFurnitureCache or 0) then
            _G.PlotFurnitureCache = tempCache
            pcall(saveFurnitureCacheDisk, tempCache)
        end
    end
    
    _G.PlotFurnitureCache = (_G.PlotFurnitureCache and #_G.PlotFurnitureCache > 0 and _G.PlotFurnitureCache) or (loadFurnitureCacheDisk and loadFurnitureCacheDisk()) or {}
    local sourceSlots = #_G.PlotFurnitureCache > 0 and _G.PlotFurnitureCache or nil
    
    local emptySlots = {}
    if sourceSlots then
        for _, slot in ipairs(sourceSlots) do
            local slotId = tostring(slot.shelfGuid) .. "_" .. tostring(slot.snapName)
            if not occupied[slotId] then
                local sName = slot.shelfName or ""
                local isLargeFloorPodium = slot.isLargeFloorPodium
                if isLargeFloorPodium == nil then
                    isLargeFloorPodium = (sName:find("Large Floor Podium") ~= nil)
                end
                local isPodium = slot.isPodium
                if isPodium == nil then
                    isPodium = (sName:lower():find("podium") ~= nil)
                end
                local defW = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                local defD = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                table.insert(emptySlots, {
                    shelfName = sName,
                    shelfGuid = slot.shelfGuid,
                    snapName = slot.snapName,
                    targetCFrame = slot.targetCFrame or slot.cf,
                    slotWidth = slot.slotWidth or defW,
                    slotDepth = slot.slotDepth or defD,
                    isPodium = isPodium,
                    isLargeFloorPodium = isLargeFloorPodium,
                })
            end
        end
    elseif Furniture then
        for _, shelf in ipairs(Furniture:GetDescendants()) do
            if shelf:IsA("Model") and shelf:GetAttribute("GUID") then
                local shelfGuid = tostring(shelf:GetAttribute("GUID"))
                local shelfName = shelf.Name or ""
                local isLargeFloorPodium = (shelfName:find("Large Floor Podium") ~= nil)
                local isPodium = (shelfName:lower():find("podium") ~= nil)
                for _, att in ipairs(shelf:GetDescendants()) do
                    if att:IsA("Attachment") and att.Name:match("^SnapPoint") then
                        local slotId = tostring(shelfGuid) .. "_" .. tostring(att.Name)
                        if not occupied[slotId] then
                            local rawW = att:GetAttribute("SlotWidth")
                            local rawD = att:GetAttribute("SlotDepth")
                            local defW = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                            local defD = isLargeFloorPodium and 6.5 or (isPodium and 3.5 or 3.0)
                            table.insert(emptySlots, {
                                shelfName = shelfName,
                                shelfGuid = shelfGuid,
                                snapName = att.Name,
                                targetCFrame = att.WorldCFrame,
                                slotWidth = rawW or defW,
                                slotDepth = rawD or defD,
                                isPodium = isPodium,
                                isLargeFloorPodium = isLargeFloorPodium,
                            })
                        end
                    end
                end
            end
        end
    end
    
    if #emptySlots == 0 then return 0 end
    
    -- Authoritative server check via ShelfAutoStock preview (works from any distance!)
    local serverBlocked = {}
    local serverFits = {}
    local ShelfAutoStock = PlotEvents and PlotEvents:FindFirstChild("ShelfAutoStock")
    if ShelfAutoStock then
        local sOk, preview = pcall(function() return ShelfAutoStock:InvokeServer("preview") end)
        if sOk and type(preview) == "table" and preview.Ok == true then
            if tonumber(preview.FreeSlots) == 0 or tonumber(preview.SpaceLeft) == 0 then
                return 0
            end
            if type(preview.Blocked) == "table" then
                serverBlocked = preview.Blocked
            end
            if type(preview.Fits) == "table" then
                serverFits = preview.Fits
            end
        end
    end
    
    -- Filter and prioritize inventory candidates
    local candidateItems = {}
    local candidateGuids = {}
    local ItemsDataMod = require(RS.Modules.Items)
    local MutatorMod = require(RS.Modules.MutatorModule)
    
    for guid, data in pairs(inv) do
        if not (_G.AHUnsellableGuids and _G.AHUnsellableGuids[guid]) then
            if not (data.StartTime or data.Grade == "WorkInProgress" or data.CleanMutation == "WorkInProgress" or data.Condition == "WorkInProgress" or data.Opened or data.Favorited) then
                local itemConf = ItemsDataMod[tostring(data.ItemId)] or ItemsDataMod[tonumber(data.ItemId)]
                if itemConf then
                    local name = itemConf.Name or ""
                    if not isItemExcluded(name, data, "place") then
                        local price = MutatorMod:CalculatePriceForEntry(itemConf.BasePrice or 0, data)
                        local minThreshold = tonumber(gConfig.minAutoPlaceValue) or 0
                        local maxThreshold = tonumber(gConfig.maxAutoPlaceValue) or 0
                        local priceOk = (minThreshold <= 0 or price >= minThreshold) and (maxThreshold <= 0 or price <= maxThreshold)
                        if priceOk then
                            -- If server explicitly marked this item as blocked (Quest, NoSlot, NoValue, etc.), skip immediately to prevent wasted calls & toasts
                            local isServerBlocked = (serverBlocked[guid] ~= nil)
                            if not isServerBlocked then
                                local w, d, h = getItemSize(itemConf)
                                w = w or 1.8
                                d = d or 1.8
                                local cat = (itemConf.Category or ""):lower()
                                local isOversized = (w > 4.2 or d > 4.2 or cat == "livestock" or cat == "vehicle")
                                table.insert(candidateItems, {
                                    guid = guid,
                                    data = data,
                                    itemConf = itemConf,
                                    name = name,
                                    price = price,
                                    w = w,
                                    d = d,
                                    h = h,
                                    isOversized = isOversized,
                                    serverFits = (serverFits[guid] == true),
                                })
                                table.insert(candidateGuids, guid)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #candidateItems == 0 then return 0 end
    
    -- PRIMARY: Native authoritative server auto-stock placement
    -- The server natively matches all shelves, tables, and podiums (even custom models) without slot mismatches!
    if ShelfAutoStock and #candidateGuids > 0 then
        local applyOk, applyRes = pcall(function()
            return ShelfAutoStock:InvokeServer("apply", candidateGuids)
        end)
        if applyOk and type(applyRes) == "table" and applyRes.Ok == true then
            local numPlaced = tonumber(applyRes.Placed) or 0
            if numPlaced > 0 then
                abLog("* Auto-Place: Server stocked " .. numPlaced .. " item" .. (numPlaced > 1 and "s" or "") .. " onto store shelves!", C.green)
                return numPlaced
            end
        end
    end
    
    -- SECONDARY FALLBACK: Manual snap point placement
    -- Sort candidates: server-confirmed fits first, smaller items first (fills small shelves, saving large podiums), highest value first
    table.sort(candidateItems, function(a, b)
        if a.serverFits ~= b.serverFits then
            return a.serverFits == true
        end
        if a.isOversized ~= b.isOversized then
            return not a.isOversized
        end
        return a.price > b.price
    end)
    
    _G.AHAttemptedSlots = _G.AHAttemptedSlots or {}
    for storedGuid in pairs(_G.AHAttemptedSlots) do
        if not inv[storedGuid] then
            _G.AHAttemptedSlots[storedGuid] = nil
        end
    end
    
    for _, candidate in ipairs(candidateItems) do
        local stillActive = force or gConfig.autoSellStore or gConfig.afAutoPlace or gConfig.autoPlaceStoreItems or _G.autoPlaceStoreItems
        if not stillActive then break end
        if #emptySlots == 0 then break end
        
        local guid = candidate.guid
        local data = candidate.data
        local itemConf = candidate.itemConf
        local name = candidate.name
        local price = candidate.price
        local w = candidate.w
        local d = candidate.d
        local isOversized = candidate.isOversized
        
        local foundIdx = nil
        local rotateNeeded = false
        
        -- PASS 1 for regular (non-oversized) items:
        -- Prefer standard tables, shelves, and small podiums FIRST to keep Large Floor Podiums open for big items
        if not isOversized then
            for i, slot in ipairs(emptySlots) do
                local slotId = tostring(slot.shelfGuid) .. "_" .. tostring(slot.snapName)
                local isBlacklisted = _G.AHIncompatibleSlots and _G.AHIncompatibleSlots[guid .. "_" .. slotId]
                local lastAttempt = _G.AHAttemptedSlots[guid] and _G.AHAttemptedSlots[guid][slotId]
                local alreadyTried = lastAttempt and (os.clock() - lastAttempt < 45.0)
                if not isBlacklisted and not alreadyTried then
                    if not slot.isLargeFloorPodium then
                        local mult = slot.isPodium and 2 or 1
                        local slotW = (slot.slotWidth or 3.0) * mult + 0.1
                        local slotD = (slot.slotDepth or 3.0) * mult + 0.1
                        if (w <= slotW and d <= slotD) then
                            foundIdx = i
                            rotateNeeded = false
                            break
                        elseif (d <= slotW and w <= slotD) then
                            foundIdx = i
                            rotateNeeded = true
                            break
                        end
                    end
                end
            end
        end
        
        -- PASS 2: If regular item didn't fit on smaller shelves, fallback to Large Floor Podium.
        -- If item IS OVERSIZED: MUST ONLY match a Large Floor Podium!
        if not foundIdx then
            for i, slot in ipairs(emptySlots) do
                local slotId = tostring(slot.shelfGuid) .. "_" .. tostring(slot.snapName)
                local isBlacklisted = _G.AHIncompatibleSlots and _G.AHIncompatibleSlots[guid .. "_" .. slotId]
                local lastAttempt = _G.AHAttemptedSlots[guid] and _G.AHAttemptedSlots[guid][slotId]
                local alreadyTried = lastAttempt and (os.clock() - lastAttempt < 45.0)
                if not isBlacklisted and not alreadyTried then
                    if isOversized then
                        -- CRITICAL FIX: Oversized items MUST ONLY match actual Large Floor Podiums!
                        if slot.isLargeFloorPodium then
                            foundIdx = i
                            rotateNeeded = false
                            break
                        end
                    else
                        if slot.isLargeFloorPodium then
                            foundIdx = i
                            rotateNeeded = false
                            break
                        end
                    end
                end
            end
        end
        
        if foundIdx then
            local slot = table.remove(emptySlots, foundIdx)
            local slotId = tostring(slot.shelfGuid) .. "_" .. tostring(slot.snapName)
            _G.AHAttemptedSlots[guid] = _G.AHAttemptedSlots[guid] or {}
            _G.AHAttemptedSlots[guid][slotId] = os.clock()
            _G.AHLastPlacingGuid = guid
            _G.AHLastPlacingSlotId = slotId
            
            local rotY = (itemConf.ShelfRotationY or 0) + (rotateNeeded and 90 or 0)
            local targetCFrame = slot.targetCFrame * CFrame.Angles(0, math.rad(rotY), 0)
            
            abLog("[Power] Auto-Place: Placing " .. name .. " for $" .. math.floor(price), C.green)
            local trackingGuid = HttpService and HttpService:GenerateGUID(false) or tostring(os.clock())
            pcall(function()
                PlaceStockItem:FireServer(guid, tostring(data.ItemId), targetCFrame, price, slot.shelfGuid, slot.snapName, false, 1, false, nil, 0)
            end)
            pcall(function()
                PlaceStockItem:FireServer(guid, tostring(data.ItemId), targetCFrame, price, slot.shelfGuid, slot.snapName, false, 0, true)
            end)
            pcall(function()
                PlaceStockItem:FireServer(guid, tostring(data.ItemId), targetCFrame, price, slot.shelfGuid, slot.snapName, nil, nil, true, trackingGuid)
            end)
            
            local ChangeStockPrice = PlotEvents:FindFirstChild("ChangeStockPrice")
            if ChangeStockPrice then
                task.delay(0.2, function()
                    pcall(function() ChangeStockPrice:FireServer(guid, price) end)
                end)
            end
            
            placedCount = placedCount + 1
            task.wait(0.25)
        end
    end
    return placedCount
end
_G.executeSmartPlotPlacement = executeSmartPlotPlacement

local _pitStopLastAttempt = 0  -- cooldown tracker: os.clock() of last pit-stop attempt
local _pitStopCooldown = 120   -- seconds to wait after a 0-placed pit-stop

local function doPlotPitStop(force)
    local totalPlaced = 0
    pcall(function()
        local lp = game:GetService("Players").LocalPlayer
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        -- Check if we are already near the saved plot position (use saved CFrame if available)
        local alreadyNear = false
        if isNearMyPlot and isNearMyPlot(120) then
            alreadyNear = true
        elseif gConfig.savedPlotDriveway and typeof(gConfig.savedPlotDriveway) == "CFrame" then
            alreadyNear = (root.Position - gConfig.savedPlotDriveway.Position).Magnitude <= 120
        end

        if alreadyNear then
            local placed = executeSmartPlotPlacement(force)
            if placed and placed > 0 then
                abLog("* Placed " .. placed .. " items onto store shelves!", C.green)
            end
            totalPlaced = placed or 0
            return
        end

        -- Snapshot vehicle BEFORE any teleport (nil if on foot — that's fine)
        local inVehicle = hum.SeatPart ~= nil
        local seat    = hum.SeatPart
        local vehicle = seat and seat:FindFirstAncestorWhichIsA("Model")
        -- Return point: vehicle pivot if in vehicle, else player's current position
        local returnCF = root.CFrame
        if vehicle then
            returnCF = vehicle:GetPivot()
        end

        local drivewayCF = getMyLivePlotDrivewayCF and getMyLivePlotDrivewayCF()
        if not drivewayCF then
            abLog("[Warning] Could not resolve plot driveway! Stand at your plot driveway and tap 'Save Current Plot'.", COLORS.Orange)
            return
        end

        abLog("Pit-Stop: teleporting to plot to stock store...", C.gold)

        safeTP(drivewayCF)
        pcall(function()
            if lp.RequestStreamAroundAsync then
                lp:RequestStreamAroundAsync(drivewayCF.Position)
            end
        end)

        -- Wait up to 3s for plot Furniture to stream in
        local waited = 0
        while waited < 3 do
            local p = getMyLivePlot and getMyLivePlot()
            if p and p:FindFirstChild("Furniture") and #p.Furniture:GetChildren() > 0 then break end
            task.wait(0.3)
            waited = waited + 0.3
        end

        local placed = executeSmartPlotPlacement(force)
        if placed and placed > 0 then
            abLog("* Placed " .. placed .. " items onto store shelves!", C.green)
        end
        totalPlaced = placed or 0

        -- Apply cooldown if nothing was placed (shelves full / all excluded)
        if totalPlaced == 0 and not force then
            _pitStopLastAttempt = os.clock()
            abLog("ℹ Pit-Stop: Nothing placed (shelves full or all excluded). 120s cooldown.", C.orange)
        end

        task.wait(0.4)

        -- Always return to original position
        safeTP(returnCF)
        task.wait(0.5)

        -- Only attempt re-seat if the player was in a vehicle before the pit-stop
        if inVehicle and vehicle then
            char = lp.Character
            hum  = char and char:FindFirstChildOfClass("Humanoid")
            root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and root and vehicle.Parent then
                -- Find the correct seat (VehicleSeat or DriveSeat)
                local targetSeat = vehicle:FindFirstChildWhichIsA("VehicleSeat")
                    or vehicle:FindFirstChild("DriveSeat")
                if targetSeat then
                    -- Position character above seat so Sit() can grab it
                    root.CFrame = targetSeat.CFrame * CFrame.new(0, 2, 0)
                    task.wait(0.15)
                    targetSeat:Sit(hum)
                    abLog("[Autofarm] Returned and reseated in vehicle.", C.green)
                end
            end
        else
            abLog("[Plot] Returned to previous location.", C.green)
        end
    end)
    return totalPlaced
end
_G.doManualPlotPitStop = doPlotPitStop


_G.AHAutoPlaceThread = task.spawn(function()
    while true do
        task.wait(2.5)
        if _G.AHScanner_RunID ~= myRunID then break end

        local shouldPlace = gConfig.autoSellStore or gConfig.afAutoPlace or gConfig.autoPlaceStoreItems or _G.autoPlaceStoreItems
        if shouldPlace then
            pcall(function()
                local isBlocked = AB and (AB.quickWinActive or AB.auctionOpen or AB.pickupPhase or AB.startingAuction)
                local farFromPlot = isNearMyPlot and not isNearMyPlot(120)

                -- Check if pit-stop conditions are met FIRST — before remote placement clears the bag
                local pitStopTriggered = false
                if gConfig.enablePlotPitStop
                    and not isBlocked
                    and farFromPlot
                    and (os.clock() - _pitStopLastAttempt) >= _pitStopCooldown then

                    -- LIVE inventory fetch
                    local invRemote = ReplicatedStorage:FindFirstChild("Events")
                        and ReplicatedStorage.Events:FindFirstChild("Inventory")
                        and ReplicatedStorage.Events.Inventory:FindFirstChild("GetPlayerInventory")
                    local inv = invRemote and invRemote:InvokeServer()

                    if inv and next(inv) then
                        -- DYNAMIC max backpack capacity from live InventoryLabel UI
                        local maxCapacity = 35
                        pcall(function()
                            local lp = game:GetService("Players").LocalPlayer
                            local label = lp.PlayerGui.UIControllerGui.HotbarContainer.HotbarInventoryButton.InventoryLabel
                            local _, cap = label.Text:match("(%d+)%s*/%s*(%d+)")
                            if cap then maxCapacity = tonumber(cap) or 35 end
                        end)

                        local ItemsDataMod = require(game:GetService("ReplicatedStorage").Modules.Items)
                        local placableCount = 0
                        for _, data in pairs(inv) do
                            local isWIP = (data.StartTime or data.Grade == "WorkInProgress"
                                or data.CleanMutation == "WorkInProgress"
                                or data.Condition == "WorkInProgress" or data.Opened) ~= nil
                            if not isWIP then
                                local itemConf = ItemsDataMod[tostring(data.ItemId)] or ItemsDataMod[tonumber(data.ItemId)]
                                local name = itemConf and itemConf.Name or ""
                                if itemConf and not isItemExcluded(name, data, "place") then
                                    placableCount = placableCount + 1
                                end
                            end
                        end

                        local thresholdPercent = tonumber(gConfig.autoPlaceThreshold) or 80
                        local triggerCount = math.max(5, math.floor(maxCapacity * (thresholdPercent / 100)))

                        if placableCount >= triggerCount then
                            -- Check for empty shelf slots before wasting a teleport
                            local hasEmptySlots = true -- default: allow if we can't confirm
                            local PlotEvents = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Plot")
                            local ShelfAutoStock = PlotEvents and PlotEvents:FindFirstChild("ShelfAutoStock")
                            if ShelfAutoStock then
                                local pOk, prev = pcall(function() return ShelfAutoStock:InvokeServer("preview") end)
                                if pOk and type(prev) == "table" and prev.Ok == true then
                                    hasEmptySlots = (tonumber(prev.FreeSlots) or 0) > 0
                                end
                            end
                            local cache = _G.PlotFurnitureCache
                            if hasEmptySlots and cache and #cache > 0 then
                                local myPlot = getMyLivePlot and getMyLivePlot()
                                if myPlot then
                                    local GetShopStock = PlotEvents and PlotEvents:FindFirstChild("GetShopStock")
                                    local occupied = {}
                                    if GetShopStock then
                                        local sOk, sList = pcall(function() return GetShopStock:InvokeServer(myPlot) end)
                                        if sOk and type(sList) == "table" then
                                            for _, entry in ipairs(sList) do
                                                local attrs = entry.Attrs
                                                if attrs and attrs.ShelfGUID and attrs.SnapPointName then
                                                    occupied[tostring(attrs.ShelfGUID) .. "_" .. tostring(attrs.SnapPointName)] = true
                                                end
                                            end
                                        end
                                    end
                                    local Stock = myPlot:FindFirstChild("Stock")
                                    if Stock then
                                        for _, item in ipairs(Stock:GetChildren()) do
                                            local sg = item:GetAttribute("ShelfGUID")
                                            local sn = item:GetAttribute("SnapPointName")
                                            if sg and sn then occupied[tostring(sg).."_"..tostring(sn)] = true end
                                        end
                                    end
                                    local foundEmpty = false
                                    for _, slot in ipairs(cache) do
                                        local sid = tostring(slot.shelfGuid).."_"..tostring(slot.snapName)
                                        if not occupied[sid] then foundEmpty = true break end
                                    end
                                    hasEmptySlots = foundEmpty
                                end
                            end

                            if hasEmptySlots then
                                abLog(string.format("Pit-Stop triggered! %d/%d placeable items (threshold %d%%)", placableCount, maxCapacity, thresholdPercent), C.gold)
                                doPlotPitStop()
                                pitStopTriggered = true
                            else
                                abLog("ℹ Pit-Stop skipped: all store shelves are full.", C.textMuted)
                                _pitStopLastAttempt = os.clock()
                                pitStopTriggered = true -- still skip remote place this cycle
                            end
                        end
                    end
                end

                -- Only run remote placement if pit-stop didn't already handle it
                if not pitStopTriggered then
                    local placed = executeSmartPlotPlacement()
                    if placed and placed > 0 then
                        abLog("* Auto-Place: Placed " .. placed .. " items onto store shelves!", C.green)
                    end
                end
            end)
        end
    end
end)




-- Enforce notification suppression and sound muting states
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(0.5)
        pcall(function()
            local playerGui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
            local toasts = playerGui and playerGui:FindFirstChild("ToastsGui")
            if toasts then
                local shouldDisable = gConfig.disableGameNotifications
                if toasts.Enabled == shouldDisable then
                    toasts.Enabled = not shouldDisable
                end
            end

            local ss = game:GetService("SoundService")
            local soundsFolder = ss:FindFirstChild("Sounds")
            if soundsFolder then
                local muteSounds = {
                    { name = "SnapIntoPlace", defaultVol = 0.5 },
                    { name = "ClothMove", defaultVol = 0.5 },
                    { name = "ItemPickup", defaultVol = 1.0 },
                    { name = "Pop", defaultVol = 1.2 },
                    { name = "Pop2", defaultVol = 0.035 },
                }
                for _, sInfo in ipairs(muteSounds) do
                    local snd = soundsFolder:FindFirstChild(sInfo.name)
                    if snd then
                        if gConfig.mutePlacingSounds then
                            snd.Volume = 0
                        else
                            if snd.Volume == 0 then snd.Volume = sInfo.defaultVol end
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto-Unload on Full Cargo loop
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(2.5)
        if autoUnloadFull or gConfig.afAutoUnload then
            pcall(function()
                local vehicle = getMyVehicle()
                if vehicle then
                    local weight = vehicle:GetAttribute("CargoWeight") or 0
                    local limit = vehicle:GetAttribute("CargoWeightLimit") or 100
                    local thresholdVal = (gConfig and gConfig.autoUnloadThreshold) or 80
                    local thresholdRatio = thresholdVal / 100
                    
                    if limit > 0 and (weight >= (limit * thresholdRatio)) then
                        local vehicleId = vehicle:GetAttribute("VehicleGUID") or LocalPlayer:GetAttribute("EquippedVehicle")
                        local getItemsRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Vehicles"):FindFirstChild("GetVehicleItems")
                        local transferRemote = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Vehicles"):FindFirstChild("TransferVehicleItemsToInventory")
                        if getItemsRemote and transferRemote then
                            local items = getItemsRemote:InvokeServer(vehicleId)
                            if items then
                                local guids = {}
                                for guid, _ in pairs(items) do
                                    table.insert(guids, guid)
                                end
                                if #guids > 0 then
                                    transferRemote:FireServer(guids)
                                    abLog("[Truck] Auto-Unloaded " .. #guids .. " items from truck to inventory!", C.green)
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)


-- Seated Autofarm Loop
task.spawn(function()
    local lastTargetLot = nil
    local lastEngineerCheckAt = 0

    while ScreenGui and ScreenGui.Parent do
        task.wait(0.15)
        if gConfig.seatedAutofarm or gConfig.seizedGarageSniping then
            pcall(function()
                local char = LocalPlayer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then return end
                
                -- [Stop] BIDIRECTIONAL LOCK: Yield if Mining, Freight collection, Quest TP, LeaveAuction, or other background tasks are active!
                if AB.leavingAuction and AB.leaveStartedAt and (os.clock() - AB.leaveStartedAt > 4.5) then
                    AB.leavingAuction = false
                    AB.leaveStartedAt = nil
                end
                if AB.pickupPhase or _G.AHPickupCycleRunning or _G.isMiningActive or _G.isFreightCollecting or _G.isPickupActive or _G.questTpInProgress or AB.quickWinActive or AB.leavingAuction then
                    return
                end
                if LocalPlayer:GetAttribute("InAuction") == true and not AB.auctionOpen and not AB.startingAuction then
                    requestLeaveAuction()
                    return
                end
                
                local debris = workspace:FindFirstChild("_Debris")
                local garages = debris and debris:FindFirstChild("Garages")
                local currentLotName = AB.activeLot
                
                local targetGarage = nil
                local targetLotName = nil
                
                -- [Power] PRIORITY 0: POWER PLANT QUEST DELIVERIES (throttled every 5s between skips; reset on win)
                -- If we have items in our bag for Power Plant, focus on delivering them FIRST before hunting/driving to garages!
                if gConfig.autoEngineerQuest
                    and not currentLotName and not AB.startingAuction and not AB.pickupPhase and not AB.auctionOpen
                    and (os.clock() - lastEngineerCheckAt >= 5.0) then
                    lastEngineerCheckAt = os.clock()
                    local didDeliver = false
                    if _G.performEngineerDeliveries then
                        didDeliver = _G.performEngineerDeliveries()
                    end
                    if didDeliver then
                        return -- Deliveries complete; yield this autofarm tick so state settles cleanly
                    end
                end
                
                -- [Plot] SMART PLOT PIT-STOP (physical teleport only if user enabled it)
                if gConfig.autoPlaceStoreItems and gConfig.enablePlotPitStop
                    and not currentLotName and not AB.startingAuction and not AB.pickupPhase
                    and not isNearMyPlot(120)
                    and (os.clock() - _pitStopLastAttempt) >= _pitStopCooldown then

                    -- LIVE inventory fetch — always fresh
                    local invRemote = ReplicatedStorage:FindFirstChild("Events")
                        and ReplicatedStorage.Events:FindFirstChild("Inventory")
                        and ReplicatedStorage.Events.Inventory:FindFirstChild("GetPlayerInventory")
                    local inv = invRemote and invRemote:InvokeServer()
                    if inv then
                        -- DYNAMIC max capacity from live UI label
                        local maxCapacity = 35
                        pcall(function()
                            local lp = game:GetService("Players").LocalPlayer
                            local label = lp.PlayerGui.UIControllerGui.HotbarContainer.HotbarInventoryButton.InventoryLabel
                            local _, cap = label.Text:match("(%d+)%s*/%s*(%d+)")
                            if cap then maxCapacity = tonumber(cap) or 35 end
                        end)

                        local nonExcludedCount = 0
                        for _, data in pairs(inv) do
                            local itemConf = ItemsData[tostring(data.ItemId)] or ItemsData[tonumber(data.ItemId)]
                            local name = itemConf and itemConf.Name or ""
                            if not isItemExcluded(name, data, "place") then
                                nonExcludedCount = nonExcludedCount + 1
                            end
                        end

                        local thresholdPercent = gConfig.autoPlaceThreshold or 80
                        local triggerCount = math.max(5, math.floor(maxCapacity * (thresholdPercent / 100)))

                        -- STRICT: only teleport if there are actually items to place
                        if nonExcludedCount >= triggerCount then
                            doPlotPitStop()
                        end
                    end
                end


                if not currentLotName and not AB.startingAuction and not AB.pickupPhase and garages then
                    _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                    
                    -- [Alert] PRIORITY 1: SEIZED GARAGE SNIPER (15x Loot)
                    if gConfig.seizedGarageSniping then
                        for _, garage in ipairs(garages:GetChildren()) do
                            local lotName = garage:GetAttribute("GarageId") or garage.Name
                            local gKey = garage:GetAttribute("GUID") or garage.Name
                            local onCooldown = _G.AHGarageCooldowns[gKey] and (os.clock() < _G.AHGarageCooldowns[gKey])
                            if isGarageSeizedAllowed(lotName, garage) and not onCooldown then
                                local promptPart = garage:FindFirstChild("EntrySquare") and garage.EntrySquare:FindFirstChild("PromptPart")
                                local prompt = promptPart and promptPart:FindFirstChild("EnterAuction")
                                local canStart = garage:GetAttribute("InAuction") ~= true and ((prompt and prompt.Enabled) or (promptPart == nil))
                                if canStart then
                                    targetGarage = garage
                                    targetLotName = lotName
                                    currentGarageIsSeized = true
                                    _G.AHIsCurrentGarageSeized = true
                                    lastAuctionWasSeized = true
                                    _G.AHLastAuctionWasSeized = true
                                    abLog("[Alert] Seized Garage Priority Target Acquired: " .. lotName .. " (15x Mutator)", Color3.fromRGB(255, 215, 0))
                                    break
                                end
                            end
                        end
                    end
                    
                    -- [Sync] PRIORITY 2: ROUTINE FARMING (Fallback - ONLY if Main Autofarm is enabled!)
                    if not targetGarage and gConfig.seatedAutofarm then
                        local hasAnyAfSel = false
                        if gConfig.afSelectedGarages then
                            for _, v in pairs(gConfig.afSelectedGarages) do
                                if v == true then hasAnyAfSel = true; break end
                            end
                        end

                        local bestGarage = nil
                        local bestLotName = nil
                        local bestDist = math.huge
                        local charRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        local comparePos = charRoot and charRoot.Position or (vehicle and vehicle:GetPivot().Position) or Vector3.new(0, 0, 0)

                        for _, garage in ipairs(garages:GetChildren()) do
                            local lotName = garage:GetAttribute("GarageId") or garage.Name
                            local garageSelected = isGarageAllowed(lotName, true)
                            local catEntry = GARAGE_CATALOG[lotName]
                            if not catEntry then
                                for k, v in pairs(GARAGE_CATALOG) do
                                    if k:lower() == lotName:lower() or (v.name and v.name:lower() == lotName:lower()) then
                                        catEntry = v
                                        break
                                    end
                                end
                            end
                            local areaName = (catEntry and catEntry.area) or garage:GetAttribute("AreaName") or ""
                            local areaOk = false
                            if hasAnyAfSel then
                                -- When user explicitly selects garage(s), selection overrides the general Area filter!
                                areaOk = garageSelected
                            elseif gConfig.afAutoBuyAreas then
                                if gConfig.afAutoBuyAreas["Any Area"] or gConfig.afAutoBuyAreas[areaName] then
                                    areaOk = true
                                else
                                    for selArea, isEn in pairs(gConfig.afAutoBuyAreas) do
                                        if isEn and (selArea == areaName or string.find(areaName, selArea) or string.find(selArea, areaName)) then
                                            areaOk = true
                                            break
                                        end
                                    end
                                end
                            else
                                areaOk = (gConfig.afAutoBuyArea == "Any Area" or areaName == gConfig.afAutoBuyArea or string.find(areaName, gConfig.afAutoBuyArea))
                            end
                            
                            local gKey = garage:GetAttribute("GUID") or garage.Name
                            local onCooldown = _G.AHGarageCooldowns[gKey] and (os.clock() < _G.AHGarageCooldowns[gKey])
                            
                            if garageSelected and areaOk and not onCooldown then
                                local isTrainGarage = (areaName == "Cargo Train") or string.find(lotName, "Train") or string.find(garage.Name, "Train")
                                local trainReady = true
                                if isTrainGarage then
                                    local Lighting = game:GetService("Lighting")
                                    local trainPhase = Lighting:GetAttribute("CargoTrainPhase")
                                    if trainPhase ~= "Stopped" then
                                        trainReady = false
                                        if not _G._lastTrainWaitLog or (os.clock() - _G._lastTrainWaitLog > 10) then
                                            _G._lastTrainWaitLog = os.clock()
                                            abLog("[Train] Cargo Train is in transit (" .. tostring(trainPhase or "Moving") .. "). Waiting for train to stop at station...", C.textDim)
                                        end
                                    end
                                end

                                local promptPart = garage:FindFirstChild("EntrySquare") and garage.EntrySquare:FindFirstChild("PromptPart")
                                local prompt = promptPart and promptPart:FindFirstChild("EnterAuction")
                                local canStart = trainReady and garage:GetAttribute("InAuction") ~= true and ((prompt and prompt.Enabled) or (promptPart == nil))
                                if canStart then
                                    local cf = (promptPart and promptPart.CFrame) or getGarageEntranceCFrame(garage) or garage:GetPivot()
                                    local dist = cf and (comparePos - cf.Position).Magnitude or 1000
                                    if dist < bestDist then
                                        bestDist = dist
                                        bestGarage = garage
                                        bestLotName = lotName
                                    end
                                end
                            end
                        end

                        if bestGarage then
                            targetGarage = bestGarage
                            targetLotName = bestLotName
                            currentGarageIsSeized = false
                            _G.AHIsCurrentGarageSeized = false
                        end
                    end
                end
                
                -- Only board vehicle if Main Autofarm is ON, or actively running a pickup/snipe phase!
                local isAutofarmActive = gConfig.seatedAutofarm or (gConfig.seizedGarageSniping and currentGarageIsSeized) or AB.pickupPhase or _G.AHPickupCycleRunning
                if not isAutofarmActive then
                    -- Autofarm is inactive: Allow player to walk, drive, and Click TP freely without script interference!
                    return
                end
                
                -- State 1: Vehicle Boarding / On-Foot Preparation
                local vehicle = getMyVehicle()
                if not vehicle then
                    local spawnRemote = ReplicatedStorage:FindFirstChild("Events")
                        and ReplicatedStorage.Events:FindFirstChild("Vehicles")
                        and ReplicatedStorage.Events.Vehicles:FindFirstChild("RequestSpawn")
                    if spawnRemote then
                        spawnRemote:FireServer()
                        task.wait(1.0)
                        vehicle = getMyVehicle()
                    end
                end
                
                if vehicle and not AB.pickupPhase and not _G.AHPickupCycleRunning and not AB.quickWinActive then
                    local seat = vehicle:FindFirstChild("DriveSeat") or vehicle:FindFirstChildWhichIsA("VehicleSeat")
                    if seat and hum and hum.SeatPart ~= seat then
                        seat:Sit(hum)
                        local sitDeadline = os.clock() + 0.3
                        while hum.SeatPart ~= seat and os.clock() < sitDeadline do
                            task.wait(0.03)
                        end
                    end
                end
                
                -- Support BOTH Seated Driving & On-Foot Autofarm (never freezes if player has no car!)
                local isSeatedInCar = vehicle and hum and hum.SeatPart and hum.SeatPart:IsDescendantOf(vehicle)
                local moverPart = isSeatedInCar and (vehicle.PrimaryPart or vehicle:FindFirstChild("Body") or vehicle:FindFirstChildWhichIsA("BasePart")) or root
                
                if not AB.pickupPhase and not _G.AHPickupCycleRunning and moverPart and hum and hum.Health > 0 then
                    local vehicleRoot = moverPart
                    
                    -- State 2: Safe TP Navigation to active lot
                    if currentLotName then
                        local bestGarage = nil
                        local bestDist = math.huge
                        local bestCF = nil
                        
                        -- Find physical garage model closest to player
                        if garages then
                            for _, garage in ipairs(garages:GetChildren()) do
                                local lotName = garage:GetAttribute("GarageId") or garage.Name
                                local garageSelected = isGarageAllowed(lotName, true) or (gConfig.seizedGarageSniping and isGarageSeized(garage))
                                if garageSelected and (garage.Name == currentLotName or garage:GetAttribute("GarageId") == currentLotName or string.find(garage.Name, currentLotName)) then
                                    local promptPart = garage:FindFirstChild("EntrySquare") and garage.EntrySquare:FindFirstChild("PromptPart")
                                    local cf = (promptPart and promptPart.CFrame) or getGarageEntranceCFrame(garage) or garage:GetPivot()
                                    if cf then
                                        local dist = (vehicleRoot.Position - cf.Position).Magnitude
                                        if dist < bestDist then
                                            bestDist = dist
                                            bestGarage = garage
                                            bestCF = cf
                                        end
                                    end
                                end
                            end
                        end
                        
                        -- Fallback to static descendant search if physical model not found in _Debris
                        if not bestCF and workspace:FindFirstChild("Areas") then
                            for _, c in ipairs(workspace.Areas:GetDescendants()) do
                                if c:IsA("Model") and (c.Name == currentLotName or string.find(c.Name, currentLotName)) then
                                    local promptPart = c:FindFirstChild("EntrySquare") and c.EntrySquare:FindFirstChild("PromptPart")
                                    local cf = (promptPart and promptPart.CFrame) or getGarageEntranceCFrame(c) or c:GetPivot()
                                    if cf then
                                        local dist = (vehicleRoot.Position - cf.Position).Magnitude
                                        if dist < bestDist then
                                            bestDist = dist
                                            bestGarage = c
                                            bestCF = cf
                                        end
                                    end
                                end
                            end
                        end

                        if bestCF and bestGarage and vehicleRoot then
                            -- AUCTION GUARD: If auction is open and player is already within 75 studs, DO NOT teleport (we are bidding!)
                            local inAuctionRadius = bestDist <= 75
                            if not inAuctionRadius and not AB.auctionOpen then
                                if vehicle then
                                    parkVehicleAtGarage(vehicle, bestGarage, bestCF)
                                else
                                    local rp = RaycastParams.new()
                                    rp.FilterDescendantsInstances = { char }
                                    rp.FilterType = Enum.RaycastFilterType.Exclude
                                    local gHit = workspace:Raycast(bestCF.Position + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), rp)
                                    local gy = gHit and gHit.Position.Y or (bestCF.Position.Y - 2.5)
                                    root.AssemblyLinearVelocity = Vector3.zero
                                    root.CFrame = CFrame.new(bestCF.Position.X, gy + 3.0, bestCF.Position.Z)
                                end
                                task.wait(0.15)
                            end
                            lastTargetLot = bestGarage
                        end
                    elseif targetGarage and vehicleRoot then
                        local garage = targetGarage
                        local lotName = targetLotName
                        local promptPart = garage:FindFirstChild("EntrySquare") and garage.EntrySquare:FindFirstChild("PromptPart")
                        local prompt = promptPart and promptPart:FindFirstChild("EnterAuction")
                        local canStart = (prompt and prompt.Enabled) or (not prompt)
                        if canStart then
                            AB.startingAuction = true -- Set active trigger lock
                            task.delay(10, function()
                                if AB.startingAuction and not AB.activeLot then
                                    AB.startingAuction = false
                                end
                            end)
                            
                            local targetCF = (promptPart and promptPart.CFrame) or getGarageEntranceCFrame(garage) or garage:GetPivot()
                            if targetCF then
                                local driveSeat = vehicle and (vehicle:FindFirstChildWhichIsA("VehicleSeat", true)
                                    or vehicle:FindFirstChild("DriveSeat", true)
                                    or vehicle:FindFirstChildWhichIsA("Seat", true)) or nil

                                local playerCheckPos = (driveSeat and driveSeat.Position) or root.Position
                                local playerDistXZ = Vector2.new(playerCheckPos.X - targetCF.Position.X, playerCheckPos.Z - targetCF.Position.Z).Magnitude

                                -- Reposition once if not in range or if garage changed; prevent jittering during prompt hold
                                if playerDistXZ > 5.5 or lastTargetLot ~= garage then
                                    if vehicle then
                                        parkVehicleAtGarage(vehicle, garage, targetCF)
                                    else
                                        local rp = RaycastParams.new()
                                        rp.FilterDescendantsInstances = { char }
                                        rp.FilterType = Enum.RaycastFilterType.Exclude
                                        local gHit = workspace:Raycast(targetCF.Position + Vector3.new(0, 4, 0), Vector3.new(0, -16, 0), rp)
                                        local gy = gHit and gHit.Position.Y or (targetCF.Position.Y - 2.5)
                                        if hum.PlatformStand then hum.PlatformStand = false end
                                        root.AssemblyLinearVelocity = Vector3.zero
                                        root.CFrame = CFrame.new(targetCF.Position.X, gy + 3.0, targetCF.Position.Z)
                                    end
                                    task.wait(0.08)
                                end
                                
                                -- Wait for prompt to load
                                local actualPrompt = prompt
                                if not actualPrompt then
                                    for retry = 1, 10 do
                                        local pPart = (garage:FindFirstChild("EntrySquare") and garage.EntrySquare:FindFirstChild("PromptPart"))
                                            or garage:FindFirstChild("PromptPart", true)
                                        actualPrompt = (pPart and pPart:FindFirstChild("EnterAuction")) or garage:FindFirstChild("EnterAuction", true)
                                        if actualPrompt and actualPrompt.Enabled then break end
                                        task.wait(0.15)
                                    end
                                end
                                
                                if actualPrompt and actualPrompt.Enabled then
                                    pcall(function()
                                        game:GetService("ProximityPromptService").Enabled = true
                                        actualPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
                                        actualPrompt.RequiresLineOfSight = false
                                        actualPrompt.MaxActivationDistance = 40
                                    end)
                                    -- Yield briefly so ProximityPromptService registers the prompt before InputHoldBegin
                                    task.wait(0.1)
                                    abLog("[Autofarm] Entering " .. lotName .. "!", Color3.fromRGB(100, 255, 100))
                                    lastTargetLot = garage
                                    _G.AHLastTargetLot = garage

                                    local holdDur = actualPrompt.HoldDuration or 0
                                    AB.lastSkippedGarage = nil
                                    AB.lastSkippedAt = nil
                                    if gConfig.auctionRush and _G.triggerAuctionRush then
                                        _G.triggerAuctionRush(lotName)
                                    end
                                    pcall(function()
                                        actualPrompt:InputHoldBegin()
                                        task.wait(holdDur + 0.12)
                                        actualPrompt:InputHoldEnd()
                                        actualPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
                                    end)

                                    -- Wait up to 2.5s for auction entry confirmation (ToggleAuctionArea or InAuction attribute)
                                    local openWait = os.clock()
                                    while (os.clock() - openWait < 2.5)
                                        and not AB.auctionOpen
                                        and LocalPlayer:GetAttribute("InAuction") ~= true do
                                        -- Fail fast if prompt disappeared/disabled without putting us in an auction
                                        if (os.clock() - openWait > 0.8) and (not actualPrompt.Parent or not actualPrompt.Enabled) then
                                            break
                                        end
                                        task.wait(0.05)
                                    end

                                    if not AB.auctionOpen and LocalPlayer:GetAttribute("InAuction") == true then
                                        AB.auctionOpen = true
                                        AB.auctionOpenedAt = os.clock()
                                        AB.activeGarageInstance = garage
                                        AB.activeLot = lotName
                                    end

                                    local gKey = garage:GetAttribute("GUID") or garage.Name
                                    if not AB.auctionOpen then
                                        -- Entry failed / rejected by server
                                        _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                                        _G.AHGarageCooldowns[gKey] = os.clock() + 30
                                        AB.startingAuction = false
                                        lastTargetLot = nil
                                        _G.AHLastTargetLot = nil
                                        abLog("[Warning] Could not enter " .. lotName .. " (locked or busy). Cooldown set.", C.text2)
                                        return
                                    end

                                    -- Auction is open: wait for bidding / Quick Win / LeaveAuction to finish
                                    local roundWaitStart = os.clock()
                                    while (AB.auctionOpen or AB.quickWinActive or AB.leavingAuction) and not AB.pickupPhase do
                                        task.wait(0.1)
                                        if AB.leavingAuction and AB.leaveStartedAt and (os.clock() - AB.leaveStartedAt > 4.5) then
                                            AB.leavingAuction = false
                                            AB.leaveStartedAt = nil
                                        end
                                        local qwPhase = AB.quickWinController and AB.quickWinController.phase
                                        local qwWaitingOutside = (qwPhase == "exiting" or qwPhase == "outside" or qwPhase == "pause-requested")
                                        -- Watchdog: recover cleanly if entry paid fee / stalled without server opening bidding
                                        if AB.auctionOpen and not AB.biddingUIOpen and not qwWaitingOutside and AB.currentBid == 0 then
                                            local elapsed = os.clock() - roundWaitStart
                                            if elapsed > 18 or (elapsed > 3.0 and LocalPlayer:GetAttribute("InAuction") ~= true) then
                                                abLog("[Autofarm] Auction stalled before bidding opened; resetting to continue.", C.orange)
                                                AB.auctionOpen = false
                                                AB.startingAuction = false
                                                if LocalPlayer:GetAttribute("InAuction") == true then
                                                    requestLeaveAuction()
                                                end
                                                break
                                            end
                                        end
                                        if (os.clock() - roundWaitStart > 120) and not AB.pickupPhase then
                                            abLog("[Autofarm] Auction wait exceeded 120s; resetting state.", C.red)
                                            AB.auctionOpen = false
                                            AB.quickWinActive = false
                                            AB.startingAuction = false
                                            break
                                        end
                                    end

                                    -- Brief grace wait only if server won event came right before pickup flag
                                    if AB.weAreWinning and not AB.pickupPhase then
                                        local gDeadline = os.clock() + 0.5
                                        while not AB.pickupPhase and os.clock() < gDeadline do
                                            task.wait(0.05)
                                        end
                                    end

                                    -- Auction closed: wait for pickup (or manual spray/collect delay when Auto Collect is OFF)
                                    if AB.pickupPhase or AB.weAreWinning then
                                        lastEngineerCheckAt = 0
                                        local triggeredResumePickup = false
                                        if gConfig.autoCollectWon == true then
                                            abLog("[Autofarm] Auction won! Securing garage loot...", C.green)
                                        else
                                            local delaySec = math.clamp(tonumber(gConfig.manualCollectDelay) or 15, 0, 180)
                                            abLog(string.format("[Autofarm] Won! Waiting up to %ds (or until Collect) before next garage...", delaySec), C.gold)
                                        end
                                        local pWait = os.clock()
                                        while (AB.pickupPhase or _G.AHPickupCycleRunning) and (gConfig.seatedAutofarm or gConfig.seizedGarageSniping) do
                                            local elapsed = os.clock() - pWait
                                            local delaySec = math.clamp(tonumber(gConfig.manualCollectDelay) or 15, 0, 180)
                                            local maxWait = math.max(65, (gConfig.autoCollectWon ~= true and (delaySec + 30) or 65))
                                            if elapsed >= maxWait then break end
                                            if gConfig.autoCollectWon == true then
                                                if not _G.AHPickupCycleRunning and not triggeredResumePickup and runAutoPickupCycle then
                                                    triggeredResumePickup = true
                                                    task.spawn(function() runAutoPickupCycle("AuctionWon") end)
                                                end
                                            elseif not _G.AHPickupCycleRunning then
                                                if elapsed >= delaySec then
                                                    break
                                                end
                                            end
                                            task.wait(0.2)
                                        end
                                        AB.pickupPhase = false
                                        AB.weAreWinning = false
                                        AB.auctionOpen = false
                                        _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                                        _G.AHGarageCooldowns[gKey] = os.clock() + 180
                                    else
                                        -- Zero delay on skip / lost auction - instantly move to next garage!
                                        abLog("[Autofarm] Skipped / Lost auction - moving to next garage immediately.", C.text2)
                                        _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                                        _G.AHGarageCooldowns[gKey] = os.clock() + 45
                                    end

                                    AB.biddingUIOpen = false
                                    AB.activeGarageInstance = nil
                                    AB.startingAuction = false
                                    lastTargetLot = nil
                                    _G.AHLastTargetLot = nil
                                    lastAuctionWasSeized = false
                                    _G.AHLastAuctionWasSeized = false
                                    currentGarageIsSeized = false
                                    _G.AHIsCurrentGarageSeized = false
                                else
                                    -- Failed to stream in or not enabled, mark this garage on 15s retry cooldown
                                    local gKey = garage:GetAttribute("GUID") or garage.Name
                                    _G.AHGarageCooldowns = _G.AHGarageCooldowns or {}
                                    _G.AHGarageCooldowns[gKey] = os.clock() + 15
                                    AB.startingAuction = false
                                end
                            else
                                AB.startingAuction = false
                            end
                        end
                    end
                    end
            end)
        end
    end
end)

-- Background Police Stars Watchdog: Auto-dead completely disabled

end
setupUI()

-- =====================================================
-- ?? MOBILE CONTROLS RESTORER & AUTOMATION WORKERS
-- =====================================================

-- Background Mobile Controls Restorer
task.spawn(function()
    while task.wait(0.5) do
        if gConfig.seatedAutofarm and not AB.auctionOpen and not _G.isPickupActive then
            pcall(function()
                local player = game:GetService("Players").LocalPlayer
                local char = player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                -- Do NOT run controls restorer if seated in a vehicle!
                if hum and hum.SeatPart then
                    return
                end
                
                local playerGui = player and player:FindFirstChildWhichIsA("PlayerGui")
                local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
                local needsRestore = false
                
                if touchGui then
                    if not touchGui.Enabled then
                        needsRestore = true
                    else
                        local touchControlFrame = touchGui:FindFirstChild("TouchControlFrame")
                        if touchControlFrame then
                            if not touchControlFrame.Visible then
                                needsRestore = true
                            else
                                local jumpButton = touchControlFrame:FindFirstChild("JumpButton")
                                if jumpButton and not jumpButton.Visible then needsRestore = true end
                                local dpad = touchControlFrame:FindFirstChild("DynamicThumbstick")
                                if dpad and not dpad.Visible then needsRestore = true end
                            end
                        end
                    end
                end
                
                if needsRestore then
                    cleanRestoreControls()
                end
            end)
        end
    end
end)

-- Background Auto Wash & Safe Lockpick Workers
-- Use a _G sentinel so script re-runs kill the old loop and avoid stale closures
_G._NexWashLoop_Running = false
task.spawn(function()
    _G._NexWashLoop_Running = true
    local myRun = _G._NexWashLoop_Running
    -- Each run gets a unique ID; if a newer run starts, this loop exits
    local runId = (os.clock())
    _G._NexWashLoop_RunId = runId

    while task.wait(5) do
        -- Exit if a newer loop has taken over
        if _G._NexWashLoop_RunId ~= runId then break end

        local cfg = _G.gConfig
        if cfg then
            local processedGuids = {}
        local EV = game:GetService("ReplicatedStorage"):WaitForChild("Events")

        -- AUTO WASH
        if cfg.autoWash then
            pcall(function()
                local washEv = EV:WaitForChild("Wash")
                local res = washEv:WaitForChild("GetSlotState"):InvokeServer()
                local unlockedCount = res and res.unlockedCount or 1
                local slots = res and res.slots
                if slots then
                    for slotIndex = 1, 3 do
                        if slotIndex <= unlockedCount then
                            local slotData = slots[tostring(slotIndex)]
                            if not slotData then
                                -- Slot is empty, find items to wash
                                local eligibleRes = washEv:WaitForChild("GetWashableItems"):InvokeServer()
                                local eligible = eligibleRes and eligibleRes.items
                                if eligible and #eligible > 0 then
                                    local chosenItem = nil
                                    -- Try to prioritize Mint condition items first for Perfect mutator upgrade chance
                                    for _, item in ipairs(eligible) do
                                        local cond = tostring(item.Condition or item.condition or ""):lower()
                                        if cond == "mint" and not processedGuids[item.guid] then
                                            chosenItem = item
                                            break
                                        end
                                    end
                                    -- If no Mint items are found, select the first unprocessed eligible item
                                    if not chosenItem then
                                        for _, item in ipairs(eligible) do
                                            if not processedGuids[item.guid] then
                                                chosenItem = item
                                                break
                                            end
                                        end
                                    end
                                    if chosenItem then
                                        processedGuids[chosenItem.guid] = true
                                        washEv:WaitForChild("StartWash"):InvokeServer(slotIndex, chosenItem.guid, chosenItem.source, chosenItem.vehicleGUID)
                                        task.wait(0.5)
                                    end
                                end
                            else
                                -- If Washed==true: use ClaimWashedItem (moves item to inventory)
                                -- If time elapsed but not yet washed: use CollectWash (triggers server-side completion)
                                if slotData.Washed == true then
                                    local ok, r = pcall(function()
                                        return washEv:WaitForChild("ClaimWashedItem"):InvokeServer(slotIndex)
                                    end)
                                    if ok and type(r) == "table" and r.success then
                                        abLog("Wash slot " .. slotIndex .. " claimed!", C.green)
                                    end
                                    task.wait(0.4)
                                else
                                    local elapsed = workspace:GetServerTimeNow() - (slotData.StartTime or workspace:GetServerTimeNow())
                                    local remaining = (slotData.Duration or 0) - elapsed
                                    if remaining <= 0 then
                                        pcall(function()
                                            washEv:WaitForChild("CollectWash"):InvokeServer(slotIndex)
                                        end)
                                        task.wait(0.3)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- AUTO LOCKPICK
        if cfg.autoLockpick then
            pcall(function()
                local lsEv = EV:WaitForChild("Locksmith")
                local res = lsEv:WaitForChild("GetSlotState"):InvokeServer()
                local unlockedCount = res and res.unlockedCount or 1
                local slots = res and res.slots
                if slots then
                    for slotIndex = 1, 3 do
                        if slotIndex <= unlockedCount then
                            local slotData = slots[tostring(slotIndex)]
                            if not slotData then
                                -- Slot empty: find safes to lockpick
                                local ok, eligibleRes = pcall(function()
                                    return lsEv:WaitForChild("GetLockableItems"):InvokeServer()
                                end)
                                local eligible = ok and eligibleRes and eligibleRes.items
                                if eligible and #eligible > 0 then
                                    local chosenItem = nil
                                    for _, item in ipairs(eligible) do
                                        if not processedGuids[item.guid] then
                                            chosenItem = item
                                            break
                                        end
                                    end
                                    if chosenItem then
                                        processedGuids[chosenItem.guid] = true
                                        pcall(function()
                                            lsEv:WaitForChild("StartLocksmith"):InvokeServer(slotIndex, chosenItem.guid, chosenItem.source, chosenItem.vehicleGUID)
                                        end)
                                        task.wait(0.5)
                                    end
                                end
                            else
                                -- Slot active: time-based completion
                                local elapsed = workspace:GetServerTimeNow() - (slotData.StartTime or workspace:GetServerTimeNow())
                                local remaining = (slotData.Duration or 0) - elapsed
                                if remaining <= 0 then
                                    -- Safe finished: Open safe then immediately claim the safe item!
                                    pcall(function()
                                        lsEv:WaitForChild("OpenSafe"):InvokeServer(slotIndex)
                                    end)
                                    task.wait(0.3)
                                    local ok, r = pcall(function()
                                        return lsEv:WaitForChild("ClaimItem"):InvokeServer(slotIndex)
                                    end)
                                    if ok then
                                        abLog("Locksmith slot " .. slotIndex .. " safe opened and item claimed!", C.green)
                                    end
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                end
            end)
        end
        end
    end
end)



-- [Locked] AUTO-JAILBREAK BACKGROUND MONITOR
task.spawn(function()
    while task.wait(3) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoJailbreak then
            pcall(function()
                local jailRelease = LocalPlayer:GetAttribute("JailReleaseAt") or 0
                local now = workspace:GetServerTimeNow()
                if jailRelease > now then
                    abLog("[Alert] Incarceration detected! Auto-jailbreaking...", COLORS.Orange)
                    doJailbreak(true)
                end
            end)
        end
    end
end)

-- AUTO BANK HEIST BACKGROUND LOOP
task.spawn(function()
    while task.wait(15) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoBankHeist and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot and not _G.questTpInProgress and not isBankHeistRunning then
            pcall(function()
                local rs = game:GetService("ReplicatedStorage")
                local getBhState = rs:FindFirstChild("Events") and rs.Events:FindFirstChild("Misc") and rs.Events.Misc:FindFirstChild("BankHeist") and rs.Events.Misc.BankHeist:FindFirstChild("GetState")
                if getBhState then
                    local bhState = getBhState:InvokeServer()
                    if bhState and type(bhState) == "table" and (bhState.DetonateAt or 0) == 0 then
                        doBankHeist(false)
                    end
                end
            end)
        end
    end
end)

-- AUTO CLAIM INDEX REWARDS BACKGROUND LOOP
task.spawn(function()
    while task.wait(15) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoClaimIndexRewards then
            pcall(function()
                local collectionsEvents = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Collections")
                local getState = collectionsEvents and collectionsEvents:FindFirstChild("GetCollectionState")
                local claimMilestone = collectionsEvents and collectionsEvents:FindFirstChild("ClaimMilestoneReward")
                
                if getState and claimMilestone then
                    local state = getState:InvokeServer()
                    local Collections = require(ReplicatedStorage.Modules.Collections)
                    if state and type(state) == "table" and state.discovered and state.areaCatalog and state.milestones then
                        local discovered = state.discovered
                        local areaCatalog = state.areaCatalog
                        local milestones = state.milestones
                        
                        for _, area in ipairs(Collections.Areas) do
                            if not gConfig.autoClaimIndexRewards then break end
                            local areaName = area.Name
                            local itemsList = areaCatalog[areaName] or {}
                            local total = #itemsList
                            local found = 0
                            for _, itemName in ipairs(itemsList) do
                                if discovered[itemName] then
                                    found = found + 1
                                end
                            end
                            
                            local claimKey = Collections.ClaimKey(areaName, "Base")
                            local claimed = milestones[claimKey] or 0
                            local eligible = Collections.GetEligibleMilestoneCount(found, total, areaName)
                            
                            if claimed < eligible then
                                for step = claimed + 1, eligible do
                                    pcall(function() claimMilestone:InvokeServer(areaName) end)
                                    task.wait(0.5)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- WALKSPEED & FLIGHT UTILITY CONTROL LOOPS
task.spawn(function()
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    
    local flyBodyVelocity = nil
    local flyBodyGyro = nil
    local wasFlying = false
    local wasWalkSpeedOn = false
    
    table.insert(cleanUpSignals, RunService.RenderStepped:Connect(function()
        if _G.AHScanner_RunID ~= myRunID then return end
        
        local character = Players.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            -- 1. Walkspeed Hack handling
            if gConfig.walkSpeedEnabled and not gConfig.flightEnabled then
                humanoid.WalkSpeed = gConfig.customWalkSpeed
                wasWalkSpeedOn = true
            elseif not gConfig.walkSpeedEnabled and wasWalkSpeedOn then
                -- One-time reset when walkspeed hack is turned off
                humanoid.WalkSpeed = 16
                wasWalkSpeedOn = false
            end
            
            -- 2. Flight Mode handling (Ultra-smooth 360 Omni-directional)
            if gConfig.flightEnabled then
                humanoid.PlatformStand = true
                
                -- Initialize or verify BodyVelocity
                if not flyBodyVelocity or flyBodyVelocity.Parent ~= rootPart then
                    if flyBodyVelocity then pcall(function() flyBodyVelocity:Destroy() end) end
                    flyBodyVelocity = Instance.new("BodyVelocity")
                    flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    flyBodyVelocity.Parent = rootPart
                end
                
                -- Initialize or verify BodyGyro
                if not flyBodyGyro or flyBodyGyro.Parent ~= rootPart then
                    if flyBodyGyro then pcall(function() flyBodyGyro:Destroy() end) end
                    flyBodyGyro = Instance.new("BodyGyro")
                    flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                    flyBodyGyro.P = 15000
                    flyBodyGyro.D = 500
                    flyBodyGyro.CFrame = rootPart.CFrame
                    flyBodyGyro.Parent = rootPart
                end
                
                -- Camera CFrame orientation
                local camera = workspace.CurrentCamera
                local camCFrame = camera and camera.CFrame or rootPart.CFrame
                local moveDir = Vector3.new(0, 0, 0)
                
                -- 1. Keyboard Inputs (PC)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDir = moveDir + camCFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDir = moveDir - camCFrame.LookVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDir = moveDir - camCFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDir = moveDir + camCFrame.RightVector
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                    moveDir = moveDir + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                    moveDir = moveDir - Vector3.new(0, 1, 0)
                end
                
                -- 2. Mobile Thumbstick & Gamepad Controller Inputs
                if moveDir.Magnitude == 0 and humanoid.MoveDirection.Magnitude > 0 then
                    local flatLook = Vector3.new(camCFrame.LookVector.X, 0, camCFrame.LookVector.Z).Unit
                    local flatRight = Vector3.new(camCFrame.RightVector.X, 0, camCFrame.RightVector.Z).Unit
                    local dotLook = humanoid.MoveDirection:Dot(flatLook)
                    local dotRight = humanoid.MoveDirection:Dot(flatRight)
                    moveDir = (camCFrame.LookVector * dotLook) + (camCFrame.RightVector * dotRight)
                end
                
                -- 3. Apply Velocity
                local targetSpeed = tonumber(gConfig.flightSpeed) or 50
                if moveDir.Magnitude > 0 then
                    flyBodyVelocity.Velocity = moveDir.Unit * targetSpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
                
                -- 4. Rotate Character smoothly with Camera
                local lookTarget = rootPart.Position + camCFrame.LookVector * 100
                flyBodyGyro.CFrame = CFrame.lookAt(rootPart.Position, lookTarget)
            else
                -- Cleanup physics when flight is disabled
                if flyBodyVelocity then
                    pcall(function() flyBodyVelocity:Destroy() end)
                    flyBodyVelocity = nil
                end
                if flyBodyGyro then
                    pcall(function() flyBodyGyro:Destroy() end)
                    flyBodyGyro = nil
                end
                if humanoid.PlatformStand then
                    humanoid.PlatformStand = false
                end
                
                -- Reset walkspeed on landing
                if wasFlying then
                    if gConfig.walkSpeedEnabled then
                        humanoid.WalkSpeed = gConfig.customWalkSpeed or 32
                    else
                        humanoid.WalkSpeed = 16
                    end
                    wasFlying = false
                end
            end
            
                        if gConfig.flightEnabled then
                wasFlying = true
            end
        end
    end))
end)

-- ⌛ TIME CAPSULE AUTO COLLECTOR BACKGROUND LOOP
task.spawn(function()
    while task.wait(5) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoCollectTimeCapsules then
            pcall(function()
                local tcFolder = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("TimeCapsule")
                local getSlots = tcFolder and tcFolder:FindFirstChild("GetSlotStates")
                local collect = tcFolder and tcFolder:FindFirstChild("CollectItem")
                if getSlots and collect then
                    local res = getSlots:InvokeServer()
                    if res and type(res) == "table" and res.slots then
                        for slotIdx, slotData in pairs(res.slots) do
                            local item = slotData.ItemData
                            if item and item.Mutators and type(item.Mutators) == "table" then
                                local shouldCollect = false
                                for name, _ in pairs(item.Mutators) do
                                    if gConfig.targetCapsuleMutators[name] then
                                        shouldCollect = true
                                        break
                                    end
                                end
                                if shouldCollect then
                                    local slotNum = tonumber(slotIdx)
                                    if slotNum then
                                        pcall(function() collect:InvokeServer(slotNum) end)
                                        abLog("⌛ Time Capsule: Auto collected mutated item from slot " .. slotNum .. "!", C.green)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- AUTO COLLECT MUSEUM GIFTS BACKGROUND LOOP
task.spawn(function()
    while task.wait(10) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoCollectMuseumGifts then
            pcall(function()
                local museumFolder = ReplicatedStorage:FindFirstChild("Events") and ReplicatedStorage.Events:FindFirstChild("Museum")
                local getState = museumFolder and museumFolder:FindFirstChild("GetState")
                local collect = museumFolder and museumFolder:FindFirstChild("Collect")
                if getState and collect then
                    local state = getState:InvokeServer()
                    if state and type(state) == "table" and state.Unlocked then
                        for i = 1, state.Unlocked do
                            pcall(function() collect:InvokeServer(i) end)
                        end
                    end
                end
            end)
        end
    end
end)

-- ⏱ MUTUAL EXCLUSION SELF-HEALING WATCHDOG
task.spawn(function()
    while task.wait(2) do
        if _G.AHScanner_RunID ~= myRunID then break end
        local now = os.clock()
        if _G.isMiningActive and (now - (_G._lastMiningAttempt or now) > 45) then
            _G.isMiningActive = false
            abLog("⏱ Watchdog: Mining lock auto-cleared (timeout safety).", COLORS.Orange)
        end
        if _G.isFreightCollecting and (now - (_G._lastFreightAttempt or now) > 25) then
            _G.isFreightCollecting = false
            abLog("⏱ Watchdog: Missing Freight lock auto-cleared (timeout safety).", COLORS.Orange)
        end
        if _G.isPickupActive and (now - (_G._lastPickupAttempt or now) > 25) then
            _G.isPickupActive = false
        end
    end
end)

-- [Mine] AUTO MINE ROCK NODES BACKGROUND LOOP
task.spawn(function()
    while task.wait(5) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoMineNodes and not AB.quickWinActive and not AB.pickupPhase and (gConfig.continuousMiningDuringAuctions or (not AB.startingAuction and not AB.activeLot)) and not _G.questTpInProgress and not _G.isFreightCollecting then
            if not _G.isMiningActive and _G.startMiningSession then
                _G.startMiningSession(true)
            end
        end
    end
end)

-- [Lab] AUTO BREW CAULDRON BACKGROUND LOOP
task.spawn(function()
    while task.wait(10) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoBrewCauldron and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot and not _G.questTpInProgress then
            if _G.autoBrewOnce then
                _G.autoBrewOnce()
            end
        end
    end
end)

-- AUTO BUY & AUTO USE MINING DRINKS BACKGROUND LOOP
task.spawn(function()
    local lastMiningBuyTime = 0
    local miningDrinkDefs = {
        { id = "18", name = "Mining Speed Drink", itemId = 1233, cost = 20 },
        { id = "19", name = "Mining Luck Drink",  itemId = 1234, cost = 30 },
    }
    while task.wait(5) do
        if _G.AHScanner_RunID ~= myRunID then break end

        -- 1. Auto-Use Mining Drinks (drinks when active buff <= 10s remaining)
        if gConfig.autoUseMiningDrinks and gConfig.useMiningDrinks and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot then
            pcall(function()
                local inv = _G.AHUserInventoryCache
                local useRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("UI") and game:GetService("ReplicatedStorage").Events.UI:FindFirstChild("UseEnergyDrink")
                local buyRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("EnergyShop") and game:GetService("ReplicatedStorage").Events.EnergyShop:FindFirstChild("BuyDrink")
                local now = workspace:GetServerTimeNow()
                local diams = lp:GetAttribute("Diamonds") or 0

                for _, drk in ipairs(miningDrinkDefs) do
                    if gConfig.useMiningDrinks[drk.id] then
                        local expire = tonumber(lp:GetAttribute("ActiveLuckDrinkExpireAt_" .. drk.id)) or 0
                        local rem = expire - now
                        if rem <= 10 then
                            -- Check inventory for item
                            local targetGuid = nil
                            if inv and type(inv) == "table" then
                                for guid, item in pairs(inv) do
                                    if type(item) == "table" and tonumber(item.ItemId) == drk.itemId then
                                        targetGuid = guid
                                        break
                                    end
                                end
                            end

                            if targetGuid and useRemote then
                                useRemote:FireServer(targetGuid)
                                abLog("Auto-Use: Consumed " .. drk.name .. " from inventory!", C.green)
                                task.wait(1.5)
                            elseif not targetGuid and gConfig.autoBuyMiningDrinks and gConfig.buyMiningDrinks and gConfig.buyMiningDrinks[drk.id] and buyRemote and useRemote then
                                -- None in inventory, auto-buy and consume immediately if diamonds available
                                if diams >= drk.cost then
                                    local res = buyRemote:InvokeServer(drk.id)
                                    if res and res.success and res.inventoryGUID then
                                        task.wait(0.5)
                                        useRemote:FireServer(res.inventoryGUID)
                                        abLog("Auto-Use: Bought & Drank " .. drk.name .. " ([Gem] " .. drk.cost .. ")!", C.green)
                                        task.wait(1.5)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end

        -- 2. Auto-Buy to Stockpile (buys selected drinks if auto-buy is on)
        if gConfig.autoBuyMiningDrinks and gConfig.buyMiningDrinks and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot then
            if os.clock() - lastMiningBuyTime >= 10 then
                pcall(function()
                    local buyRemote = game:GetService("ReplicatedStorage"):FindFirstChild("Events") and game:GetService("ReplicatedStorage").Events:FindFirstChild("EnergyShop") and game:GetService("ReplicatedStorage").Events.EnergyShop:FindFirstChild("BuyDrink")
                    if buyRemote then
                        local diams = lp:GetAttribute("Diamonds") or 0
                        for _, drk in ipairs(miningDrinkDefs) do
                            if gConfig.buyMiningDrinks[drk.id] then
                                if diams >= drk.cost then
                                    local res = buyRemote:InvokeServer(drk.id)
                                    if res and res.success then
                                        lastMiningBuyTime = os.clock()
                                        abLog("Auto-Buy: Stockpiled " .. drk.name .. " ([Gem] " .. drk.cost .. ")!", C.gold)
                                        task.wait(1)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end
    end
end)

-- [Shield] ANTI-VOID GUARDIAN BACKGROUND LOOP
task.spawn(function()
    while task.wait(0.5) do
        if _G.AHScanner_RunID ~= myRunID then break end
        local char = LocalPlayer and LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and root.Position.Y < 1500 then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true
            root.CFrame = CFrame.new(169.9, 1726.0, -210.0)
            task.wait(0.15)
            root.Anchored = false
            root.AssemblyLinearVelocity = Vector3.zero
            abLog("[Shield] Anti-Void Guardian: Rescued player from void fall!", Color3.fromRGB(255, 170, 0))
        end
    end
end)

-- [Freight] AUTO COLLECT MISSING FREIGHT BACKGROUND LOOP
task.spawn(function()
    while task.wait(15) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoCollectMissingFreight and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot and not _G.questTpInProgress and not _G.isMiningActive and not AB.quickWinActive then
            local mf = workspace:FindFirstChild("_MissingFreight")
            if mf and #mf:GetChildren() > 0 then
                if _G.collectAllMissingFreight then
                    _G.collectAllMissingFreight(false)
                end
            end
        end
    end
end)

-- [Train] AUTO CLAIM DAILY TRAIN TICKETS BACKGROUND LOOP
task.spawn(function()
    while task.wait(60) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoClaimDailyTickets and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot and not _G.questTpInProgress and not _G.isMiningActive and not _G.isFreightCollecting and not AB.quickWinActive then
            if _G.claimDailyTicketsNow then
                _G.claimDailyTicketsNow(false)
            end
        end
    end
end)

-- [Power] AUTO QUEST DELIVERIES BACKGROUND LOOP
task.spawn(function()
    while task.wait(5) do
        if _G.AHScanner_RunID ~= myRunID then break end
        if gConfig.autoEngineerQuest and not AB.pickupPhase and not AB.startingAuction and not AB.activeLot and not AB.auctionOpen and not _G.questTpInProgress and not _G.isMiningActive and not _G.isFreightCollecting and not AB.quickWinActive then
            pcall(function()
                if _G.performEngineerDeliveries then
                    _G.performEngineerDeliveries()
                end
            end)
        end
    end
end)



-- ============================================================================
-- DIAMOND CHARM & GAVEL LOADOUT AUTOMATION CONTROLLER
-- ============================================================================

task.spawn(function()
    local isExecutingCharmRoutine = false

    local function isAuctionSafeForCharmSwap()
        if AB and (AB.auctionOpen or AB.pickupPhase or AB.startingAuction or AB.quickWinActive) then
            return false
        end
        if _G.isMiningActive or _G.questTpInProgress or _G.isFreightCollecting then
            return false
        end
        local lp = game:GetService("Players").LocalPlayer
        local char = lp and lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local garages = workspace:FindFirstChild("Garages") or workspace:FindFirstChild("_Garages")
            if garages then
                for _, g in ipairs(garages:GetChildren()) do
                    if g:GetAttribute("InAuction") == true then
                        local gPivot = g:GetPivot()
                        if (hrp.Position - gPivot.Position).Magnitude < 75 then
                            return false
                        end
                    end
                end
            end
        end
        return true
    end

    local function findDiamondCharmPromptOnPlot()
        local myPlot = getMyLivePlot and getMyLivePlot()
        
        -- StreamingEnabled distance support: request stream around plot if streamed out
        if not myPlot then
            local lp = game:GetService("Players").LocalPlayer
            if lp and lp.RequestStreamAroundAsync then
                pcall(function()
                    local plotCF = getMyLivePlotDrivewayCF and getMyLivePlotDrivewayCF()
                    if plotCF then
                        lp:RequestStreamAroundAsync(plotCF.Position)
                    else
                        lp:RequestStreamAroundAsync(Vector3.new(389, 1724, -177))
                    end
                end)
                myPlot = getMyLivePlot and getMyLivePlot()
            end
        end
        
        local searchRoots = {}
        if myPlot then table.insert(searchRoots, myPlot) end
        table.insert(searchRoots, workspace)
        
        for _, root in ipairs(searchRoots) do
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    local objText = tostring(desc.ObjectText or ""):lower()
                    local actText = tostring(desc.ActionText or ""):lower()
                    if (objText:find("diamond") and (objText:find("charm") or actText:find("charm") or actText:find("claim") or actText:find("ready"))) 
                       or (objText:find("charm") and (actText:find("diamond") or actText:find("claim"))) then
                        return desc
                    end
                end
            end
        end
        return nil
    end
    _G.findDiamondCharmPrompt = findDiamondCharmPromptOnPlot

    local function executeDiamondCharmRoutine(isManual)
        if isExecutingCharmRoutine then return end
        if not isManual and not isAuctionSafeForCharmSwap() then
            return
        end
        
        isExecutingCharmRoutine = true
        
        task.spawn(function()
            local prompt = findDiamondCharmPromptOnPlot()
            local claimed = false
            
            if prompt then
                local act = tostring(prompt.ActionText or ""):lower()
                if act:find("ready in") then
                    abLog("[Diamond Charm] Gavel prompt is still on cooldown (" .. tostring(prompt.ActionText) .. ").", C.gold)
                else
                    abLog("[Diamond Charm] Found prompt on plot! Firing claim...", C.gold)
                    if fireproximityprompt then
                        pcall(function() fireproximityprompt(prompt, 0) end)
                    else
                        firePrompt(prompt)
                    end
                    claimed = true
                end
            else
                -- Direct remote fallback under ReplicatedStorage.Events.Plot
                pcall(function()
                    local RS = game:GetService("ReplicatedStorage")
                    local plotEvents = RS:FindFirstChild("Events") and RS.Events:FindFirstChild("Plot")
                    if plotEvents then
                        for _, child in ipairs(plotEvents:GetChildren()) do
                            local n = child.Name:lower()
                            if n:find("charm") or n:find("diamond") then
                                if child:IsA("RemoteFunction") then child:InvokeServer() else child:FireServer() end
                                claimed = true
                                break
                            end
                        end
                    end
                end)
            end
            
            if claimed then
                gConfig.lastDiamondCharmClaim = os.time()
                saveConfig()
                abLog("[Diamond Charm] Claim successful! Cooldown reset for 60m.", C.green)
            else
                abLog("[Diamond Charm] No Diamond Charm found on plot to claim.", C.red)
            end
            isExecutingCharmRoutine = false
        end)
    end
    _G.triggerDiamondCharmRoutine = executeDiamondCharmRoutine

    -- AUTO CLAIM DIAMOND CHARM BACKGROUND LOOP
    task.spawn(function()
        while task.wait(5) do
            if _G.AHScanner_RunID ~= myRunID then break end
            if gConfig.autoClaimDiamondCharm and not isExecutingCharmRoutine then
                local prompt = findDiamondCharmPromptOnPlot()
                if prompt then
                    local act = tostring(prompt.ActionText or ""):lower()
                    local isReady = act:find("claim") or act == "e" or (prompt.Enabled and not act:find("ready in"))
                    if isReady and isAuctionSafeForCharmSwap() then
                        executeDiamondCharmRoutine(false)
                    end
                end
            end
        end
    end)
end)
