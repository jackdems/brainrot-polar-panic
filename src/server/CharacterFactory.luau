--[[ CharacterFactory
	One job: turn a cast entry plus a mutation into a built 3D model, and paint it.
	Pure builders — no state, no remotes, no money. Every model carries a
	BillboardGui name tag (NAME / RARITY / $ per second) and bobs on its own.
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)
local RarityConfig = require(Shared.RarityConfig)
local MutationConfig = require(Shared.MutationConfig)

local CharacterFactory = {}

local TAG_HEIGHT = 3.4

-- ---------------------------------------------------------------- part helpers

local function part(model, name, size, cframe, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Parent = model
	return piece
end

local function sphere(model, name, diameter, cframe, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Ball
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.Size = Vector3.new(diameter, diameter, diameter)
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Parent = model
	return piece
end

local function wedge(model, name, size, cframe, color, material)
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Parent = model
	return piece
end

local function weld(partA, partB, offset)
	local attachmentA = Instance.new("Attachment")
	attachmentA.Parent = partA
	local attachmentB = Instance.new("Attachment")
	attachmentB.Position = offset
	attachmentB.Parent = partB
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = partA
	constraint.Part1 = partB
	constraint.Parent = partA
	return constraint
end

-- Two big cartoon eyes, always in the same place, on every plan. This is the
-- joke the whole cast shares.
local function addEyes(model, body, bodyTop, eyeSpacing, eyeSize, forward)
	local face = forward or Vector3.new(0, 0, -1)
	local origin = bodyTop + face * (eyeSize * 0.9)
	for side = -1, 1, 2 do
		local offset = Vector3.new(eyeSpacing * side, 0, 0)
		local white = sphere(model, "EyeWhite", eyeSize, CFrame.new(origin + offset), Color3.fromRGB(255, 255, 255))
		local pupil = sphere(model, "EyePupil", eyeSize * 0.55,
			CFrame.new(origin + offset + face * (eyeSize * 0.36)), Color3.fromRGB(20, 18, 24))
		pupil.Material = Enum.Material.SmoothPlastic
		weld(white, pupil, Vector3.new(0, 0, 0))
		weld(body, white, Vector3.new(0, 0, 0))
	end
end

-- ---------------------------------------------------------------- body plans

-- A round friendly blob: sphere body, two stubby feet, a little fin.
local function buildBlob(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = sphere(model, "Body", 3.4, CFrame.new(0, 1.9, 0), bodyColor)
	local torso = part(model, "Belly", Vector3.new(2.2, 1.2, 2.0), CFrame.new(0, 1.35, 0), accent)
	weld(body, torso, Vector3.new())
	part(model, "FootL", Vector3.new(0.7, 0.35, 1.0), CFrame.new(-0.7, 0.2, -0.2), accent)
	part(model, "FootR", Vector3.new(0.7, 0.35, 1.0), CFrame.new(0.7, 0.2, -0.2), accent)
	part(model, "Fin", Vector3.new(0.3, 1.4, 1.0), CFrame.new(0, 2.9, 0.9) * CFrame.Angles(math.rad(-18), 0, 0), accent)
	addEyes(model, body, Vector3.new(0, 2.35, -1.2), 0.72, 0.78)
	return body, 3.9
end

-- A box bird: body, head, beak, two wings, two legs.
local function buildBird(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Body", Vector3.new(2.6, 2.2, 3.4), CFrame.new(0, 1.9, 0), bodyColor)
	local head = part(model, "Head", Vector3.new(2.0, 1.8, 1.8), CFrame.new(0, 3.5, -0.7), bodyColor)
	weld(body, head, Vector3.new())
	local beak = wedge(model, "Beak", Vector3.new(0.8, 0.7, 1.2), CFrame.new(0, 3.4, -2.0) * CFrame.Angles(0, math.rad(180), 0), accent)
	weld(head, beak, Vector3.new())
	part(model, "WingL", Vector3.new(0.3, 1.6, 1.8), CFrame.new(-1.5, 2.1, 0.1) * CFrame.Angles(0, 0, math.rad(12)), accent)
	part(model, "WingR", Vector3.new(0.3, 1.6, 1.8), CFrame.new(1.5, 2.1, 0.1) * CFrame.Angles(0, 0, math.rad(-12)), accent)
	part(model, "LegL", Vector3.new(0.28, 1.0, 0.28), CFrame.new(-0.6, 0.55, 0.3), accent)
	part(model, "LegR", Vector3.new(0.28, 1.0, 0.28), CFrame.new(0.6, 0.55, 0.3), accent)
	part(model, "Tail", Vector3.new(1.4, 0.4, 1.2), CFrame.new(0, 2.2, 1.9) * CFrame.Angles(math.rad(-20), 0, 0), accent)
	addEyes(model, head, Vector3.new(0, 3.7, -1.6), 0.52, 0.6)
	return body, 4.4
end

-- A cup character: tapered cup body, lid, straw, and (yes) eyes on the cup.
local function buildCup(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Cup", Vector3.new(2.4, 3.0, 2.4), CFrame.new(0, 1.8, 0), bodyColor)
	part(model, "CupRim", Vector3.new(2.7, 0.4, 2.7), CFrame.new(0, 3.35, 0), accent)
	local lid = part(model, "Lid", Vector3.new(2.5, 0.35, 2.5), CFrame.new(0, 3.6, 0), accent, Enum.Material.SmoothPlastic)
	weld(body, lid, Vector3.new())
	part(model, "Straw", Vector3.new(0.3, 2.2, 0.3), CFrame.new(0.6, 4.2, 0.2) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(255, 96, 128))
	part(model, "StrawTip", Vector3.new(0.45, 0.3, 0.45), CFrame.new(1.0, 5.2, 0.2), Color3.fromRGB(255, 96, 128))
	part(model, "Base", Vector3.new(2.6, 0.3, 2.6), CFrame.new(0, 0.2, 0), accent)
	addEyes(model, body, Vector3.new(0, 2.3, -1.22), 0.55, 0.66)
	return body, 5.6
end

-- A four-legged animal: body, head, two ears, a tail, four legs.
local function buildAnimal(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Body", Vector3.new(2.8, 2.0, 3.6), CFrame.new(0, 1.9, 0), bodyColor)
	local head = part(model, "Head", Vector3.new(2.0, 1.8, 1.8), CFrame.new(0, 3.1, -1.7), bodyColor)
	weld(body, head, Vector3.new())
	part(model, "EarL", Vector3.new(0.5, 0.9, 0.4), CFrame.new(-0.7, 4.1, -1.7) * CFrame.Angles(0, 0, math.rad(14)), accent)
	part(model, "EarR", Vector3.new(0.5, 0.9, 0.4), CFrame.new(0.7, 4.1, -1.7) * CFrame.Angles(0, 0, math.rad(-14)), accent)
	part(model, "Snout", Vector3.new(1.0, 0.7, 0.6), CFrame.new(0, 2.85, -2.6), accent)
	part(model, "Tail", Vector3.new(0.4, 1.6, 0.4), CFrame.new(0, 2.4, 1.95) * CFrame.Angles(math.rad(-28), 0, 0), accent)
	for _, x in ipairs({ -0.95, 0.95 }) do
		for _, z in ipairs({ -1.25, 1.25 }) do
			part(model, "Leg", Vector3.new(0.5, 1.5, 0.5), CFrame.new(x, 0.75, z), accent)
		end
	end
	addEyes(model, head, Vector3.new(0, 3.35, -2.55), 0.5, 0.58)
	return body, 4.4
end

-- A big brute: heavy torso, low head, two horns, arms.
local function buildBeast(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Torso", Vector3.new(3.8, 3.0, 3.0), CFrame.new(0, 2.4, 0), bodyColor, Enum.Material.Slate)
	local head = part(model, "Head", Vector3.new(2.4, 2.0, 2.0), CFrame.new(0, 3.2, -1.9), bodyColor, Enum.Material.Slate)
	weld(body, head, Vector3.new())
	part(model, "HornL", Vector3.new(0.45, 1.5, 0.45), CFrame.new(-0.9, 4.5, -1.9) * CFrame.Angles(math.rad(-16), 0, math.rad(16)), accent)
	part(model, "HornR", Vector3.new(0.45, 1.5, 0.45), CFrame.new(0.9, 4.5, -1.9) * CFrame.Angles(math.rad(-16), 0, math.rad(-16)), accent)
	part(model, "ArmL", Vector3.new(0.8, 2.4, 0.8), CFrame.new(-2.2, 2.2, 0) * CFrame.Angles(0, 0, math.rad(10)), accent)
	part(model, "ArmR", Vector3.new(0.8, 2.4, 0.8), CFrame.new(2.2, 2.2, 0) * CFrame.Angles(0, 0, math.rad(-10)), accent)
	part(model, "Jaw", Vector3.new(2.0, 0.6, 0.7), CFrame.new(0, 2.5, -2.7), accent)
	part(model, "FootL", Vector3.new(1.1, 0.7, 1.6), CFrame.new(-1.0, 0.35, -0.2), accent)
	part(model, "FootR", Vector3.new(1.1, 0.7, 1.6), CFrame.new(1.0, 0.35, -0.2), accent)
	addEyes(model, head, Vector3.new(0, 3.4, -2.75), 0.62, 0.7)
	return body, 4.6
end

-- The bespoke silhouettes. Each one is the shape its name promises.
local specialBuilders = {}

function specialBuilders.croissant(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local pieces = 5
	for i = 1, pieces do
		local t = (i - 1) / (pieces - 1)
		local x = (t - 0.5) * 2.6
		local y = 1.5 + math.sin(t * math.pi) * 1.4
		local scale = 0.7 + math.sin(t * math.pi) * 0.55
		sphere(model, "Lobe", 1.5 * scale, CFrame.new(x, y, 0) * CFrame.Angles(0, 0, (t - 0.5) * 1.2), bodyColor)
		if i > 1 then
			part(model, "Fold", Vector3.new(0.18, 0.5, 1.1), CFrame.new(x - 0.45, y + 0.15, 0), accent)
		end
	end
	local body = part(model, "Body", Vector3.new(2.2, 0.5, 1.2), CFrame.new(0, 1.2, 0), bodyColor)
	addEyes(model, body, Vector3.new(0, 2.6, -0.55), 0.62, 0.66)
	return body, 3.6
end

function specialBuilders.noodle(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Body", Vector3.new(1.6, 1.8, 1.6), CFrame.new(0, 1.7, 0), bodyColor)
	for i = 1, 4 do
		part(model, "Strand", Vector3.new(0.22, 2.4 + i * 0.35, 0.22),
			CFrame.new((i - 2.5) * 0.45, 3.2 + i * 0.18, 0.3) * CFrame.Angles(0, 0, math.rad((i - 2.5) * 9)), accent)
	end
	sphere(model, "Meatball", 1.1, CFrame.new(0, 4.5, 0.2), Color3.fromRGB(146, 74, 48))
	part(model, "Bowl", Vector3.new(2.2, 0.6, 2.2), CFrame.new(0, 0.55, 0), Color3.fromRGB(250, 250, 250))
	addEyes(model, body, Vector3.new(0, 2.1, -0.82), 0.42, 0.52)
	return body, 5.2
end

function specialBuilders.cornetto(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = wedge(model, "Cone", Vector3.new(2.2, 3.2, 2.2), CFrame.new(0, 1.7, 0) * CFrame.Angles(0, math.rad(45), math.rad(180)), bodyColor)
	sphere(model, "Scoop", 2.4, CFrame.new(0, 3.5, 0), Color3.fromRGB(255, 168, 210))
	sphere(model, "Scoop2", 1.7, CFrame.new(0.2, 4.4, 0.1), Color3.fromRGB(255, 236, 200))
	part(model, "Flake", Vector3.new(0.3, 1.6, 0.3), CFrame.new(0.5, 5.1, 0) * CFrame.Angles(0, 0, math.rad(-18)), accent)
	addEyes(model, body, Vector3.new(0, 2.6, -1.05), 0.5, 0.56)
	return body, 5.6
end

function specialBuilders.toast(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Slice", Vector3.new(2.6, 3.0, 1.0), CFrame.new(0, 1.9, 0), bodyColor)
	part(model, "Crust", Vector3.new(2.8, 0.5, 1.1), CFrame.new(0, 3.5, 0), accent)
	local butter = part(model, "Butter", Vector3.new(1.4, 0.35, 1.2), CFrame.new(0, 2.6, -0.1), Color3.fromRGB(255, 226, 120))
	butter.Material = Enum.Material.Neon
	part(model, "LegL", Vector3.new(0.35, 0.8, 0.35), CFrame.new(-0.7, 0.4, 0), accent)
	part(model, "LegR", Vector3.new(0.35, 0.8, 0.35), CFrame.new(0.7, 0.4, 0), accent)
	addEyes(model, body, Vector3.new(0, 2.2, -0.55), 0.5, 0.56)
	return body, 4.2
end

function specialBuilders.cactus(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = part(model, "Trunk", Vector3.new(1.6, 3.4, 1.6), CFrame.new(0, 2.0, 0), bodyColor, Enum.Material.Grass)
	local armL = part(model, "ArmL", Vector3.new(0.9, 1.8, 0.9), CFrame.new(-1.1, 2.4, 0), bodyColor, Enum.Material.Grass)
	armL.CFrame = CFrame.new(-1.1, 2.4, 0) * CFrame.Angles(0, 0, math.rad(18))
	part(model, "ArmR", Vector3.new(0.9, 1.4, 0.9), CFrame.new(1.1, 2.0, 0) * CFrame.Angles(0, 0, math.rad(-18)), bodyColor, Enum.Material.Grass)
	sphere(model, "Flower", 0.9, CFrame.new(0, 4.0, 0), accent)
	for i = 1, 4 do
		part(model, "Spike", Vector3.new(0.1, 0.4, 0.1),
			CFrame.new(math.sin(i * 1.6) * 0.85, 1.2 + i * 0.6, -0.85), Color3.fromRGB(246, 246, 220))
	end
	part(model, "Pot", Vector3.new(1.9, 0.8, 1.9), CFrame.new(0, 0.4, 0), Color3.fromRGB(198, 116, 72))
	addEyes(model, body, Vector3.new(0, 2.6, -0.85), 0.42, 0.5)
	return body, 4.4
end

function specialBuilders.skull(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = sphere(model, "Cranium", 3.2, CFrame.new(0, 2.2, 0), bodyColor, Enum.Material.Marble)
	part(model, "Jaw", Vector3.new(2.0, 1.0, 1.8), CFrame.new(0, 0.9, -0.2), bodyColor, Enum.Material.Marble)
	for i = -1, 1 do
		part(model, "Tooth", Vector3.new(0.32, 0.5, 0.3), CFrame.new(i * 0.45, 1.35, -0.95), accent)
	end
	local halo = part(model, "Halo", Vector3.new(2.6, 0.18, 2.6), CFrame.new(0, 4.2, 0), Color3.fromRGB(255, 214, 92), Enum.Material.Neon)
	halo.Shape = Enum.PartType.Cylinder
	local haloRing = halo
	haloRing.CFrame = CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	halo.Size = Vector3.new(0.18, 2.8, 2.8)
	for _, x in ipairs({ -0.55, 0.55 }) do
		local socket = part(model, "Socket", Vector3.new(0.9, 0.9, 0.4), CFrame.new(x, 2.5, -1.35), accent, Enum.Material.Slate)
		socket.Shape = Enum.PartType.Ball
	end
	part(model, "Glow", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.9, -1.45), Color3.fromRGB(255, 96, 96), Enum.Material.Neon)
	return body, 4.8
end

function specialBuilders.galaxy(model, entry)
	local bodyColor, accent = entry.bodyColor, entry.accentColor
	local body = sphere(model, "Core", 3.4, CFrame.new(0, 2.1, 0), bodyColor, Enum.Material.Neon)
	local ring = part(model, "Ring", Vector3.new(0.22, 5.0, 5.0), CFrame.new(0, 2.1, 0), accent, Enum.Material.ForceField)
	ring.Shape = Enum.PartType.Cylinder
	ring.CFrame = CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(78)) * CFrame.Angles(0, math.rad(20), 0)
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2
		sphere(model, "Star", 0.45,
			CFrame.new(math.cos(angle) * 2.6, 2.1 + math.sin(angle * 2) * 1.4, math.sin(angle) * 2.6),
			Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
	addEyes(model, body, Vector3.new(0, 2.5, -1.25), 0.66, 0.72)
	return body, 4.6
end

local planBuilders = {
	blob = buildBlob,
	bird = buildBird,
	cup = buildCup,
	animal = buildAnimal,
	beast = buildBeast,
}

-- ---------------------------------------------------------------- label + bob

local function buildNameTag(model, entry, mutationName)
	local board = Instance.new("BillboardGui")
	board.Name = "NameTag"
	board.Size = UDim2.fromOffset(300, 116)
	board.StudsOffsetWorldSpace = Vector3.new(0, TAG_HEIGHT, 0)
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = 320
	board.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Parent = board

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = RarityConfig.colorOf(entry.rarity)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Title"
	nameLabel.Size = UDim2.new(1, -12, 0, 46)
	nameLabel.Position = UDim2.fromOffset(6, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Text = entry.name
	nameLabel.Parent = card

	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = Color3.fromRGB(0, 0, 0)
	nameStroke.Thickness = 3
	nameStroke.Parent = nameLabel

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(0.5, -8, 0, 30)
	rarityLabel.Position = UDim2.fromOffset(6, 52)
	rarityLabel.BackgroundColor3 = RarityConfig.colorOf(entry.rarity)
	rarityLabel.BackgroundTransparency = 0.05
	rarityLabel.BorderSizePixel = 0
	rarityLabel.Font = Enum.Font.GothamBlack
	rarityLabel.TextColor3 = RarityConfig.textColorOf(entry.rarity)
	rarityLabel.TextScaled = true
	rarityLabel.Text = string.upper(entry.rarity)
	rarityLabel.Parent = card

	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 8)
	rarityCorner.Parent = rarityLabel

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.new(0.5, -8, 0, 30)
	incomeLabel.Position = UDim2.new(0.5, 2, 0, 52)
	incomeLabel.BackgroundColor3 = Color3.fromRGB(24, 34, 52)
	incomeLabel.BorderSizePixel = 0
	incomeLabel.Font = Enum.Font.GothamBlack
	incomeLabel.TextColor3 = Color3.fromRGB(126, 255, 176)
	incomeLabel.TextScaled = true
	incomeLabel.Text = "$" .. entry.moneyPerSecond .. "/s"
	incomeLabel.Parent = card

	local incomeCorner = Instance.new("UICorner")
	incomeCorner.CornerRadius = UDim.new(0, 8)
	incomeCorner.Parent = incomeLabel

	if mutationName and mutationName ~= MutationConfig.plainName then
		local mutationTag = Instance.new("TextLabel")
		mutationTag.Name = "Mutation"
		mutationTag.Size = UDim2.new(1, -12, 0, 26)
		mutationTag.Position = UDim2.fromOffset(6, 86)
		mutationTag.BackgroundTransparency = 1
		mutationTag.Font = Enum.Font.GothamBlack
		mutationTag.TextColor3 = MutationConfig.colorOf(mutationName)
		mutationTag.TextScaled = true
		mutationTag.Text = "★ " .. mutationName .. "  x" .. MutationConfig.multiplierOf(mutationName)
		mutationTag.Parent = card
		board.Size = UDim2.fromOffset(300, 140)
		TAG_HEIGHT = 3.6
	end

	board.Parent = model.PrimaryPart
	return board
end

local function addIdleBob(model, baseHeight)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local target = primary.Position + Vector3.new(0, baseHeight * 0.04, 0)
	local tween = TweenService:Create(
		primary,
		TweenInfo.new(1.1 + math.random() * 0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = target }
	)
	tween:Play()
end

local function addSparkles(model, tint)
	local emitterPart = model.PrimaryPart
	if not emitterPart then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(tint)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 22
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.Parent = emitterPart
end

-- ---------------------------------------------------------------- public build

-- Repaint every part of a built model for a mutation. Kept separate so a thief
-- or a steal can re-tint without rebuilding.
function CharacterFactory.applyMutation(model, mutationName)
	local mutation = MutationConfig.get(mutationName)
	if not mutation.tint then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Color = mutation.tint
			if mutation.material then
				descendant.Material = mutation.material
			end
		end
	end
	if mutation.sparkle then
		addSparkles(model, mutation.color)
	end
end

-- Build one character model. `options` is optional and holds:
--   mutation   mutation name (default "None")
--   carried    true when it hangs over a player's head (smaller tag, no collide)
--   scale      uniform scale, default 1
function CharacterFactory.build(entry, options)
	options = options or {}
	local mutationName = options.mutation or MutationConfig.plainName
	local scale = options.scale or 1

	local model = Instance.new("Model")
	model.Name = "Brainrot_" .. entry.name

	local plan = CastConfig.bodyPlanOf(entry)
	local builder = planBuilders[plan]
	if not builder then
		builder = specialBuilders[entry.form] or buildBlob
	elseif plan == "special" then
		builder = specialBuilders[entry.form] or buildBlob
	end

	local body, height = builder(model, entry)
	model.PrimaryPart = body

	-- Persist the identity on the model so any server-side reader can rebuild
	-- the money without trusting a client.
	model:SetAttribute("CharacterName", entry.name)
	model:SetAttribute("Rarity", entry.rarity)
	model:SetAttribute("MoneyPerSecond", entry.moneyPerSecond)
	model:SetAttribute("Mutation", mutationName)
	model:SetAttribute("BodyPlan", plan)

	local mutation = MutationConfig.get(mutationName)
	if mutation.tint then
		for _, descendant in ipairs(model:GetChildren()) do
			if descendant:IsA("BasePart") then
				descendant.Color = mutation.tint
				if mutation.material then
					descendant.Material = mutation.material
				end
			end
		end
	end
	if mutation.sparkle then
		addSparkles(model, mutation.color)
	end

	if scale ~= 1 then
		model:ScaleTo(scale)
		height *= scale
	end

	buildNameTag(model, entry, mutationName)

	if options.bob ~= false then
		addIdleBob(model, height)
	end

	if options.carried then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.CanCollide = false
				descendant.CanTouch = false
			end
		end
	end

	model:SetAttribute("Height", height)
	return model
end

-- A tiny ice block used when the wall or a stun freezes somebody.
function CharacterFactory.buildIceBlock(size, color)
	local block = Instance.new("Part")
	block.Name = "IceBlock"
	block.Size = size
	block.Anchored = true
	block.CanCollide = false
	block.CanQuery = false
	block.Color = color or Color3.fromRGB(160, 226, 255)
	block.Material = Enum.Material.Ice
	block.Transparency = 0.35
	return block
end

-- Convenience for UI: a character's effective income with its mutation.
function CharacterFactory.incomeOf(entry, mutationName)
	return entry.moneyPerSecond * MutationConfig.multiplierOf(mutationName or MutationConfig.plainName)
end

return CharacterFactory
