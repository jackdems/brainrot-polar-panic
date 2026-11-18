--[[ InputController
	One job: what the keyboard and mouse mean. E is the single context verb
	(hatch / place / pick up / steal / stun / grab), Q drops, 1-2-3 open the panels,
	P buys a pad, L buys a lock. It decides nothing else: it reads the nearest
	interactable, shows the matching hint, and fires the right remote.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)

local InputController = {}

local player = Players.LocalPlayer

-- How close the player must be before E offers each verb. These are Client-side
-- picks only — the server re-checks every one of them with its own reach.
InputController.eggReach = 30
InputController.beltReach = 14
InputController.dropReach = 20
InputController.thiefReach = 26
InputController.denReach = 44

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

	local function rootPosition()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		return root and root.Position or nil
	end

	-- The nearest thing E would act on. Lower distance wins; the thief is checked
	-- first so it never loses to a den standing behind it.
	local function scanForInteractable()
		local origin = rootPosition()
		if not origin then
			self.nearest = nil
			return
		end

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
				if string.sub(model.Name, 1, 9) == "Conveyor_" then
					local distance = (origin - model:GetPivot().Position).Magnitude
					if distance <= InputController.beltReach then
						consider("dropped", distance, model, "GRAB IT OFF THE BELT", Color3.fromRGB(126, 255, 176))
					end
				elseif string.sub(model.Name, 1, 8) == "Dropped_" then
					local distance = (origin - model:GetPivot().Position).Magnitude
					if distance <= InputController.dropReach then
						consider("dropped", distance, model,
							"GRAB " .. string.upper(string.gsub(model.Name, "^Dropped_", "")),
							Color3.fromRGB(255, 236, 130))
					end
				end
			end
		end

		-- Dens: your own for placing and picking, anybody else's for stealing.
		local snapshot = state.snapshot
		local myIndex = snapshot and snapshot.baseIndex
		for index, baseInfo in ipairs(world.bases or {}) do
			local distance = (origin - baseInfo.position).Magnitude
			if distance <= InputController.denReach then
				if index == myIndex then
					if snapshot and snapshot.carried then
						consider("place", distance, index, "PLACE AT YOUR DEN", Color3.fromRGB(126, 255, 176))
					elseif snapshot and (snapshot.placedCount or 0) > 0 then
						consider("pickup", distance, index, "PICK UP FROM YOUR DEN", Color3.fromRGB(255, 236, 130))
					end
				else
					local owner = snapshot and snapshot.dens and snapshot.dens[index]
					if owner then
						local label = if owner.locked
							then ("LOCKED — " .. owner.name)
							else ("STEAL FROM " .. owner.name)
						consider("steal", distance, { owner = owner, baseIndex = index }, label,
							if owner.locked then Color3.fromRGB(120, 220, 255) else Color3.fromRGB(255, 160, 120))
					end
				end
			end
		end

		self.nearest = best

		if best then
			hud.setHint("[E]  " .. best.label, best.color)
		elseif snapshot and snapshot.carried then
			hud.setHint("[E]  PLACE AT YOUR DEN  ·  walk home", Color3.fromRGB(255, 236, 130))
		else
			hud.setHint("", nil)
		end
	end

	task.spawn(function()
		while true do
			scanForInteractable()
			task.wait(0.15)
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
		elseif target.kind == "dropped" then
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
			if target.payload.owner.locked then
				hud.setHint("LOCKED — wait it out or out-earn them.", Color3.fromRGB(120, 220, 255))
				return
			end
			local origin = rootPosition()
			local baseInfo = nil
			for index, info in ipairs(world.bases or {}) do
				if index == target.payload.baseIndex then
					baseInfo = info
				end
			end
			local padIndex = if (baseInfo and origin) then nearestPadIndex(baseInfo, origin) else 1
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
