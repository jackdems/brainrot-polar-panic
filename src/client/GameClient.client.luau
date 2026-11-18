--[[ GameClient
	The client boot. One job: build the ScreenGui, construct every panel, hold the
	local copy of the state the server pushed, and route the remotes into the right
	panel. No game rules live here.

	This file is named GameClient.client.luau and the starter's grey-square demo
	client (Game.client.luau) was deleted: Rojo maps all of src/client, so both
	would run and the starter's box would appear in the world and the captures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("PolarShared")
local Remotes = require(Shared.Remotes)
local RarityConfig = require(Shared.RarityConfig)

local Hud = require(script.Parent.Hud)
local ShopUi = require(script.Parent.ShopUi)
local PlotUi = require(script.Parent.PlotUi)
local RebirthUi = require(script.Parent.RebirthUi)
local BannerUi = require(script.Parent.BannerUi)
local EffectsClient = require(script.Parent.EffectsClient)
local InputController = require(script.Parent.InputController)

-- ---------------------------------------------------------------- the gui

local existing = playerGui:FindFirstChild("PolarPanicHud")
if existing then
	existing:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PolarPanicHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- ---------------------------------------------------------------- remotes

local folder = ReplicatedStorage:WaitForChild(Remotes.folderName, 60)
if not folder then
	warn("[PolarPanic] client: remotes folder never appeared; UI is inert")
	return
end

local function remote(name)
	return folder:WaitForChild(name, 30)
end

local requestHatch = remote("RequestHatch")
local requestPlace = remote("RequestPlace")
local requestPickup = remote("RequestPickup")
local requestSteal = remote("RequestSteal")
local requestStun = remote("RequestStunThief")
local requestGrab = remote("RequestGrabDropped")
local requestBuyPad = remote("RequestBuyPad")
local requestBuyLock = remote("RequestBuyLock")
local requestBuyUpgrade = remote("RequestBuyUpgrade")
local requestRebirth = remote("RequestRebirth")
local requestDrop = remote("RequestDrop")

local stateChanged = remote("StateChanged")
local notifyEvent = remote("Notify")
local bannerEvent = remote("BannerEvent")
local hatchResult = remote("HatchResult")
local effectEvent = remote("EffectEvent")

-- ---------------------------------------------------------------- state

local state = {
	snapshot = nil,
	baseIndex = nil,
}

-- ---------------------------------------------------------------- panels

local banner = BannerUi.new(gui)
local effects = EffectsClient.new(gui, workspace.CurrentCamera)
local hud = Hud.new(gui)

local shop = ShopUi.new(gui, function(eggId)
	requestHatch:FireServer(eggId)
end, function(upgradeId)
	if upgradeId == "Lock" then
		requestBuyLock:FireServer()
	else
		requestBuyUpgrade:FireServer(upgradeId)
	end
end)

local den = PlotUi.new(gui, {
	buyPad = function()
		requestBuyPad:FireServer()
	end,
	buyLock = function()
		requestBuyLock:FireServer()
	end,
	pickup = function()
		requestPickup:FireServer()
	end,
})

local rebirth = RebirthUi.new(gui, {
	rebirth = function()
		requestRebirth:FireServer()
	end,
})

hud.onShop = function()
	shop.toggle()
end
hud.onDen = function()
	den.toggle()
end
hud.onRebirth = function()
	rebirth.toggle()
end

-- ---------------------------------------------------------------- render

local function renderAll(snapshot)
	if not snapshot then
		return
	end
	state.snapshot = snapshot
	state.baseIndex = snapshot.baseIndex
	hud.setSnapshot(snapshot)
	shop.render(snapshot)
	den.render(snapshot)
	rebirth.render(snapshot)
end

stateChanged.OnClientEvent:Connect(renderAll)

-- Ask once at boot in case the server's first push happened before we listened.
local getSnapshot = folder:FindFirstChild("GetSnapshot")
if getSnapshot then
	task.spawn(function()
		local snapshot = getSnapshot:InvokeServer()
		if snapshot then
			renderAll(snapshot)
		end
	end)
end

-- ---------------------------------------------------------------- incoming

notifyEvent.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		banner.toast(payload.text, payload.color, payload.duration)
	else
		banner.toast(tostring(payload), Color3.fromRGB(255, 255, 255), 2.5)
	end
end)

bannerEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	banner.show(payload.text, payload.color, payload.seconds)

	if payload.kind == "icewall" then
		banner.countdown(payload.seconds or 20, payload.color)
		banner.setDanger(0.75)
	elseif payload.kind == "thief" then
		banner.setDanger(0.5)
	elseif payload.kind == "blizzard" then
		banner.setDanger(0)
	elseif payload.kind == "rebirth" then
		effects.shake(1.4, 0.9)
	end
end)

hatchResult.OnClientEvent:Connect(function(payload)
	if not payload then
		return
	end
	effects.announceHatch(payload)
	if payload.position then
		effects.burst(payload.position + Vector3.new(0, 8, 0), payload.rarityColor, 70)
	end
	banner.toast("HATCHED  " .. string.upper(payload.name), payload.rarityColor, 2.6)
end)

effectEvent.OnClientEvent:Connect(function(kind, payload)
	payload = payload or {}

	if kind == "paid" then
		hud.pulseCash()
		effects.floatMoney(payload.amount or 0)
	elseif kind == "hatch" then
		effects.burst(payload.position, RarityConfig.colorOf(payload.rarity), 60)
	elseif kind == "place" then
		if payload.position then
			effects.burst(payload.position + Vector3.new(0, 4, 0), RarityConfig.colorOf(payload.rarity), 50)
		end
	elseif kind == "grab" or kind == "steal" or kind == "drop" then
		if payload.position then
			effects.burst(payload.position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 236, 130), 40)
		end
	elseif kind == "wallWarning" then
		banner.setDanger(0.8)
	elseif kind == "wallSweep" then
		banner.setDanger(0.9)
		effects.shake(0.7, 1.2)
	elseif kind == "wallClear" then
		banner.setDanger(0)
		banner.hideCountdown()
	elseif kind == "frozen" then
		banner.setDanger(1)
		effects.shake(1.2, 0.7)
		task.delay(payload.seconds or 5, function()
			banner.setDanger(0)
		end)
	elseif kind == "blizzard" or kind == "blizzardEnd" then
		banner.setDanger(0)
	elseif kind == "rebirth" then
		effects.shake(1.5, 1)
		if payload.position then
			effects.burst(payload.position, Color3.fromRGB(255, 214, 92), 120)
		end
	elseif kind == "upgrade" or kind == "unlock" or kind == "lock" or kind == "locked" then
		if payload.position then
			effects.burst(payload.position + Vector3.new(0, 6, 0), Color3.fromRGB(126, 232, 255), 40)
		end
	elseif kind == "thiefSpawn" or kind == "thiefGrab" or kind == "stun" then
		if payload.position then
			effects.burst(payload.position + Vector3.new(0, 8, 0), Color3.fromRGB(255, 120, 96), 40)
		end
	end
end)

-- ---------------------------------------------------------------- input

local input = InputController.new({
	remotes = {
		RequestHatch = requestHatch,
		RequestPlace = requestPlace,
		RequestPickup = requestPickup,
		RequestSteal = requestSteal,
		RequestStunThief = requestStun,
		RequestGrabDropped = requestGrab,
		RequestBuyPad = requestBuyPad,
		RequestBuyLock = requestBuyLock,
		RequestBuyUpgrade = requestBuyUpgrade,
		RequestRebirth = requestRebirth,
		RequestDrop = requestDrop,
	},
	world = {
		eggMachines = {},
		bases = {},
	},
	hud = hud,
	shop = shop,
	den = den,
	rebirth = rebirth,
	state = state,
})

-- The client builds its own map of interactables from the world the server
-- replicated: egg machines by their EggId attribute, dens by their BaseIndex.
task.spawn(function()
	local world = workspace:WaitForChild("PolarPanic", 30)
	if not world then
		return
	end

	local shopDistrict = world:WaitForChild("ShopDistrict", 20)
	if shopDistrict then
		for _, child in ipairs(shopDistrict:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("EggId") then
				input.world.eggMachines[child:GetAttribute("EggId")] = {
					model = child,
					position = child:GetPivot().Position,
				}
			end
		end
	end

	local basesFolder = world:WaitForChild("Bases", 20)
	if basesFolder then
		for _, child in ipairs(basesFolder:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("BaseIndex") then
				table.insert(input.world.bases, {
					model = child,
					position = child:GetPivot().Position,
					index = child:GetAttribute("BaseIndex"),
				})
			end
		end
		-- ipairs order must be den order, not filesystem order.
		table.sort(input.world.bases, function(a, b)
			return a.index < b.index
		end)
	end
end)

-- Keep the camera's reference fresh (it is replaced on respawn).
RunService.RenderStepped:Connect(function()
	if workspace.CurrentCamera and effects then
		effects.camera = workspace.CurrentCamera
	end
end)

print("[PolarPanic] client ready")
