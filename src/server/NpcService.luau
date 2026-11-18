--[[ NpcService
	One job: spawn 6 ambient part-built humanoid rigs that wander the island so the
	world reads as a busy multiplayer server. Each NPC: blocky avatar (torso/head/
	arms/legs Parts + Humanoid), random shirt/pants colors + skin tones, a floating
	name tag styled exactly like a real player's username, walk animation via
	TweenService on the rig's motor joints, and a waypoint loop.

	NPCs never touch game logic (no real money, no stealing) — they are set-dressing,
	verified by a probe that counts them walking.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")
local RarityConfig = require(Shared.RarityConfig)

local NpcService = {}

local NPC_NAMES = {
	"xX_FrostBoi_Xx",
	"egggslayer99",
	"polarpunk",
	"NoobMaster88",
	"iguana_gurl",
	"BrainrotHunter7",
}

local SKIN_TONES = {
	Color3.fromRGB(255, 218, 185),
	Color3.fromRGB(245, 205, 170),
	Color3.fromRGB(235, 190, 155),
	Color3.fromRGB(225, 175, 140),
	Color3.fromRGB(140, 100, 75),
	Color3.fromRGB(100, 70, 50),
}

local SHIRT_COLORS = {
	Color3.fromRGB(120, 224, 255), -- cyan
	Color3.fromRGB(126, 255, 176), -- mint
	Color3.fromRGB(178, 132, 255), -- violet
	Color3.fromRGB(255, 214, 120), -- amber
	Color3.fromRGB(255, 120, 150), -- pink
	Color3.fromRGB(100, 255, 200), -- teal
}

local PANTS_COLORS = {
	Color3.fromRGB(18, 30, 52),   -- navy
	Color3.fromRGB(34, 52, 82),   -- navy light
	Color3.fromRGB(60, 40, 90),   -- dark purple
	Color3.fromRGB(80, 60, 40),   -- brown
	Color3.fromRGB(40, 40, 60),   -- dark slate
	Color3.fromRGB(30, 60, 50),   -- dark green
}

-- Waypoint loop: spawn plaza → carpet → stare at the belt → egg machine → wander → a den edge → back
local function makeWaypoints(layout)
	local plaza = layout.plazaCenter
	local shop = layout.shopCenter
	local conveyor = layout.conveyorCenter
	local lake = layout.lakeCenter
	local deckY = layout.deckY

	return {
		Vector3.new(plaza.X, deckY + 3, plaza.Z + 10),
		Vector3.new(plaza.X, deckY + 3, plaza.Z - 20),
		Vector3.new(shop.X + 40, deckY + 3, shop.Z),
		Vector3.new(conveyor.X, deckY + 3, conveyor.Z),
		Vector3.new(shop.X - 60, deckY + 3, shop.Z + 40),
		Vector3.new(lake.X, deckY + 3, lake.Z),
		Vector3.new(plaza.X, deckY + 3, plaza.Z + 10),
	}
end

local function createRig(name, skinTone, shirtColor, pantsColor, startPos)
	local model = Instance.new("Model")
	model.Name = "AmbientNPC_" .. name
	model.Parent = workspace

	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.WalkSpeed = 10
	humanoid.Parent = model

	-- RootPart (invisible)
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Transparency = 1
	rootPart.CFrame = CFrame.new(startPos)
	rootPart.Parent = model

	-- Torso
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Anchored = false
	torso.CanCollide = false
	torso.Color = shirtColor
	torso.Material = Enum.Material.SmoothPlastic
	torso.Parent = model

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Anchored = false
	head.CanCollide = false
	head.Color = skinTone
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- Left Arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.Anchored = false
	leftArm.CanCollide = false
	leftArm.Color = skinTone
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Parent = model

	-- Right Arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.Anchored = false
	rightArm.CanCollide = false
	rightArm.Color = skinTone
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Parent = model

	-- Left Leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Anchored = false
	leftLeg.CanCollide = false
	leftLeg.Color = pantsColor
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Parent = model

	-- Right Leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Anchored = false
	rightLeg.CanCollide = false
	rightLeg.Color = pantsColor
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Parent = model

	-- Motor6Ds (joints)
	local function makeJoint(name, part0, part1, c0, c1)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0 = part0
		joint.Part1 = part1
		joint.C0 = c0
		joint.C1 = c1
		joint.Parent = part0
		return joint
	end

	-- Root joint
	makeJoint("RootJoint", rootPart, torso,
		CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
		CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)))

	-- Neck
	makeJoint("Neck", torso, head,
		CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)),
		CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-90), 0, math.rad(180)))

	-- Left Shoulder
	makeJoint("Left Shoulder", torso, leftArm,
		CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-90)),
		CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-90)))

	-- Right Shoulder
	makeJoint("Right Shoulder", torso, rightArm,
		CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)),
		CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))

	-- Left Hip
	makeJoint("Left Hip", torso, leftLeg,
		CFrame.new(-0.5, -1, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-90)),
		CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-90)))

	-- Right Hip
	makeJoint("Right Hip", torso, rightLeg,
		CFrame.new(0.5, -1, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)),
		CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(90), math.rad(90)))

	-- Player-like name tag (BillboardGui)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Adornee = head
	billboard.Parent = head

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 28
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Text = name
	label.Parent = billboard

	-- Face (simple eyes)
	local face = Instance.new("Decal")
	face.Name = "Face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head

	model.PrimaryPart = rootPart
	return model
end

local function walkCycle(rig, duration)
	local torso = rig:FindFirstChild("Torso")
	local leftArm = rig:FindFirstChild("Left Arm")
	local rightArm = rig:FindFirstChild("Right Arm")
	local leftLeg = rig:FindFirstChild("Left Leg")
	local rightLeg = rig:FindFirstChild("Right Leg")

	local ls = torso and torso:FindFirstChild("Left Shoulder")
	local rs = torso and torso:FindFirstChild("Right Shoulder")
	local lh = torso and torso:FindFirstChild("Left Hip")
	local rh = torso and torso:FindFirstChild("Right Hip")

	if not (ls and rs and lh and rh) then return end

	local walkTime = 0
	local original = {
		ls = ls.C0, rs = rs.C0, lh = lh.C0, rh = rh.C0,
	}

	task.spawn(function()
		while rig.Parent and humanoid and humanoid.Health > 0 do
			task.wait(0.03)
			walkTime = walkTime + 0.03
			local phase = walkTime * 8

			-- Arm swing
			ls.C0 = original.ls * CFrame.Angles(math.sin(phase) * 0.6, 0, 0)
			rs.C0 = original.rs * CFrame.Angles(-math.sin(phase) * 0.6, 0, 0)

			-- Leg swing
			lh.C0 = original.lh * CFrame.Angles(-math.sin(phase) * 0.8, 0, 0)
			rh.C0 = original.rh * CFrame.Angles(math.sin(phase) * 0.8, 0, 0)
		end
	end)
end

local function moveTo(rig, target, speed)
	local humanoid = rig:FindFirstChild("Humanoid")
	if not humanoid then return end

	local root = rig.PrimaryPart
	if not root then return end

	humanoid.WalkSpeed = speed or 10
	humanoid:MoveTo(target)

	-- Wait until arrived or timeout
	local timeout = 30
	local start = os.clock()
	while rig.Parent and humanoid.Health > 0 do
		local dist = (root.Position - target).Magnitude
		if dist < 4 then break end
		if os.clock() - start > timeout then break end
		task.wait(0.5)
	end
end

function NpcService.init(worldFolder, layout)
	local waypoints = makeWaypoints(layout)
	local npcs = {}

	for i, name in ipairs(NPC_NAMES) do
		local skinTone = SKIN_TONES[math.random(#SKIN_TONES)]
		local shirtColor = SHIRT_COLORS[math.random(#SHIRT_COLORS)]
		local pantsColor = PANTS_COLORS[math.random(#PANTS_COLORS)]

		local startPos = waypoints[1]
		local rig = createRig(name, skinTone, shirtColor, pantsColor, startPos)
		rig.Parent = worldFolder

		local humanoid = rig:FindFirstChild("Humanoid")

		-- Stagger start times
		task.delay(i * 5, function()
			if not rig.Parent then return end
			walkCycle(rig, 0.8)

			task.spawn(function()
				while rig.Parent and humanoid and humanoid.Health > 0 do
					for _, wp in ipairs(waypoints) do
						if not rig.Parent then return end
						moveTo(rig, wp, 8 + math.random() * 4)
						-- Random pause at each waypoint (3-90s as per spec)
						task.wait(3 + math.random() * 87)
					end
				end
			end)
		end)

		table.insert(npcs, rig)
	end

	print(string.format("[NpcService] spawned %d ambient NPCs", #npcs))
	return npcs
end

return NpcService