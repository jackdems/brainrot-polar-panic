--[[ InputController
	One job: what the keyboard and mouse mean. E is the single context verb
	(place / pick up / steal / stun / hatch), Q drops, 1-2-3 open the panels, P
	buy a pad, L buy a lock. It decides nothing else: it reads the nearest
	interactable and fires the right remote.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)

local InputController = {}

local player = Players.LocalPlayer

-- How close the player must be before E offers each verb.
InputController.eggReach = 30
InputController.beltReach = 14
InputController.dropReach = 20
InputController.thiefReach = 26
InputController.denReach = 38

function InputController.new(context)
	local self = {}

	local remotes = context.remotes
	local world = context.world
	local hud = context.hud
	local shopPanel = context.shop
	local denPanel = context.den
	local rebirthPanel = context.rebirth
	local state = context.state

	self.world = world
	self.state = state
	self.nearest = nil

	-- ------------------------------------------------------------ scanning

	-- The nearest thing E would act on. Lower distance wins; the thief is checked
	-- first so it never loses to a den standing behind it.
	local function scanForInteractable()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			self.nearest = nil
			return
		end
		local origin = root.Position

		local best = nil
		local bestDistance = math.huge

		local function consider(kind, distance, payload, label, color)
			if distance < bestDistance then
				bestDistance = distance
				best = { kind = kind, distance = distance, payload = payload, label = label, color = color }
			end
		end

		-- The bandit first: it is the emergency.
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") and model.Name == "YetiBandit" then
				local distance = (origin - model:GetPivot().Position).Magnitude
				if distance <= InputController.thiefReach then
					consider("thief", distance, model, "STUN THE YETI BANDIT", Color3.fromRGB(255, 126, 108))
				end
			end
		end

		-- Egg machines.
		for id, machine in pairs(world.eggMachines or {}) do
			local position = machine.position
			if position then
				local distance = (origin - position).Magnitude
				if distance <= InputController.eggReach then
					local egg = EggConfig.byId[id]
					consider("egg", distance, id, "HATCH THE " .. string.upper(egg and egg.name or id),
						Color3.fromRGB(126, 232, 255))
				end
			end
		end

		-- Belt loot and dropped (frozen or stunned) loot.
		for _, model in ipairs(workspace:GetChildren()) do
			if model:IsA("Model") then
				if model.Name:sub(1, 9) == "Conveyor_" then
					local distance = (origin - model:GetPivot().Position).Magnitude
					if distance <= InputController.beltReach then
						consider("belt", distance, model, "GRAB IT OFF THE BELT", Color3.fromRGB(126, 255, 176))
					end
				elseif model.Name:sub(1, 8) == "Dropped_" then
					local distance = (origin - model:GetPivot().Position).Magnitude
					if distance <= InputController.dropReach then
						consider("dropped", distance, model,
							"GRAB " .. string.upper(model.Name:gsub("^Dropped_", "")), Color3.fromRGB(255, 236, 130))
					end
				end
			end
		end

		-- Dens: your own for placing and picking, anybody else's for stealing.
		local myIndex = state.snapshot and state.snapshot.baseIndex
		for index, baseInfo in ipairs(world.bases or {}) do
			local distance = (origin - baseInfo.position).Magnitude
			if distance <= InputController.denReach then
				if index == myIndex then
					if state.snapshot and state.snapshot.carried then
						consider("place", distance, index, "PLACE AT YOUR DEN", Color3.fromRGB(126, 255, 176))
					else
						consider("pickup", distance, index, "PICK UP FROM YOUR DEN", Color3.fromRGB(255, 236, 130))
					end
				else
					local owner = state.snapshot and state.snapshot.dens and state.snapshot.dens[index]
					if owner then
						local label = if owner.locked then ("LOCKED — " .. owner.name) else ("STEAL FROM " .. owner.name)
						consider("steal", distance, { owner = owner, baseIndex = index }, label,
							if owner.locked then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(255, 160, 120))
					end
				end
			end
		end

		self.nearest = best

		if best then
			hud.setHint("[E]  " .. best.label, best.color)
		elseif state.snapshot and state.snapshot.carried then
			hud.setHint("[E]  PLACE AT YOUR DEN  ·  walk home", Color3.fromRGB(255, 236, 130))
		else
			hud.setHint("", nil)
		end
	end

	task.spawn(function()
		while true do
			scanForInteractable()
			task.wait(0.2)
		end
	end)

	-- ------------------------------------------------------------ verbs

	-- Which pad socket of somebody else's den is nearest to a point.
	local function nearestPadIndex(baseInfo, origin)
		local bestIndex, bestDistance = nil, math.huge
		for _, child in ipairs(baseInfo.model:GetChildren()) do
			if child:IsA("BasePart") and child:GetAttribute("PadIndex") then
				local distance = (origin - child.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestIndex = child:GetAttribute("PadIndex")
				end
			end
		end
		return bestIndex
	end

	function self.act()
		local target = self.nearest
		if not target then
			return
		end

		if target.kind == "egg" then
			remotes.RequestHatch:FireServer(target.payload)
		elseif target.kind == "belt" or target.kind == "dropped" then
			remotes.RequestGrabDropped:FireServer(target.payload:GetAttribute("CharacterId"))
		elseif target.kind == "thief" then
			remotes.RequestStunThief:FireServer()
		elseif target.kind == "place" then
			remotes.RequestPlace:FireServer()
		elseif target.kind == "pickup" then
			remotes.RequestPickup:FireServer()
		elseif target.kind == "steal" then
			if state.snapshot and state.snapshot.carried then
				hud.setHint("Your hands are full — place what you have first.", Color3.fromRGB(255, 160, 120))
				return
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local baseInfo = nil
			for index, info in ipairs(world.bases or {}) do
				if index == target.payload.baseIndex then
					baseInfo = info
				end
			end
			local padIndex = if (baseInfo and root) then nearestPadIndex(baseInfo, root.Position) else 1
			remotes.RequestSteal:FireServer(target.payload.owner.userId, padIndex or 1)
		end
	end

	function self.drop()
		remotes.RequestDrop:FireServer()
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if processed then
			return
		end

		local key = input.KeyCode
		if key == Enum.KeyCode.E then
			self.act()
		elseif key == Enum.KeyCode.Q then
			self.drop()
		elseif key == Enum.KeyCode.One then
			shopPanel.toggle()
		elseif key == Enum.KeyCode.Two then
			denPanel.toggle()
		elseif key == Enum.KeyCode.Three then
			rebirthPanel.toggle()
		elseif key == Enum.KeyCode.P then
			remotes.RequestBuyPad:FireServer()
		elseif key == Enum.KeyCode.L then
			remotes.RequestBuyLock:FireServer()
		end
	end)

	return self
end

return InputController
