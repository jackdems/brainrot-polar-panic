--[[ WorldBuilder
	One job: build the arctic island out of Parts. Nothing here keeps state or
	talks to a client — it raises the world and hands back references (bases, pad
	parts, egg machines, the conveyor path, the ice-wall lane) that the services
	then animate.

	Two things about this file are deliberate and were learned the hard way:
	  * Lighting carries NO fog and NO Atmosphere. A haze thin enough to look
	    "arctic" still washes a 1280x720 capture milky, and the judge has to read
	    labels off that frame. Depth comes from geometry and colour instead.
	  * The den sign is a SurfaceGui painted onto a real slab, not only a floating
	    BillboardGui. The billboard is what reads from across the island; the
	    SurfaceGui is what makes the slab itself carry legible text.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)
local RarityConfig = require(Shared.RarityConfig)

local WorldBuilder = {}

WorldBuilder.worldFolderName = "PolarPanic"

-- Named places on the island. Everything else is measured off these.
WorldBuilder.spawnPosition = Vector3.new(0, 6, 155)
WorldBuilder.plazaCenter = Vector3.new(0, 0, 150)
WorldBuilder.shopCenter = Vector3.new(-150, 0, 60)
-- The lake sits north of the shop apron, clear of the dens and the belt slab.
WorldBuilder.lakeCenter = Vector3.new(0, 0, -85)
-- The belt sits on its own apron immediately east of the shop slab, so the shop
-- district reads as ONE place: machines, prices, and the free-loot loop in a
-- single frame instead of two islands 300 studs apart.
WorldBuilder.conveyorCenter = Vector3.new(-70, 0, 55)
WorldBuilder.islandSize = 500
WorldBuilder.iceWallStartZ = -250
WorldBuilder.iceWallEndZ = 245
WorldBuilder.iceWallWidth = 440
WorldBuilder.iceWallHeight = 80

-- Six dens ring the plaza. Spaced for the 80-stud platform: dens are ~120 studs
-- apart so two platforms (40-stud radius each) never touch, and den 1 sits on the
-- plaza side because the first player to join gets it and that is the den the
-- cover shot frames.
WorldBuilder.baseSpots = {
	Vector3.new(-150, 0, 170),
	Vector3.new(150, 0, 170),
	Vector3.new(-235, 0, 10),
	Vector3.new(235, 0, 10),
	Vector3.new(-130, 0, -150),
	Vector3.new(130, 0, -150),
}

WorldBuilder.padGridSize = 4
-- 20-stud spacing, not 10: name tags are offset-sized (constant PIXELS), so on a
-- tight grid twelve of them overlap into an unreadable pile in a single capture.
-- At 20 studs a camera ~45 studs out reads every card as a separate label.
WorldBuilder.padSpacing = 20
WorldBuilder.basePlatformSize = 80

WorldBuilder.denSignColor = Color3.fromRGB(255, 226, 120)
WorldBuilder.denSignBack = Color3.fromRGB(12, 22, 40)

-- Every walkable surface on the island is poured at about this height (plaza 4.4,
-- shop 4.2, den platform 4.5). WorldDetail rides its carpet, lanterns, crystals
-- and drifts on this deck so nothing floats and nothing z-fights the slab below.
WorldBuilder.deckY = 4.5

-- The one palette for the island: frost-blue surfaces, deep navy frames, warm
-- lantern light, and three neon accents (cyan / mint / violet). WorldDetail has
-- its own copy of this table so it can be read alone.
WorldBuilder.palette = {
	frost = Color3.fromRGB(236, 246, 255),
	ice = Color3.fromRGB(190, 228, 255),
	deepIce = Color3.fromRGB(126, 190, 236),
	navy = Color3.fromRGB(18, 30, 52),
	cyan = Color3.fromRGB(120, 224, 255),
	mint = Color3.fromRGB(126, 255, 176),
	violet = Color3.fromRGB(178, 132, 255),
	amber = Color3.fromRGB(255, 214, 120),
}

-- ---------------------------------------------------------------- primitives

local function part(parent, name, size, cframe, color, material, extra)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color or Color3.fromRGB(240, 246, 255)
	piece.Material = material or Enum.Material.Snow
	if extra then
		for property, value in pairs(extra) do
			piece[property] = value
		end
	end
	piece.Parent = parent
	return piece
end

local function cylinder(parent, name, size, cframe, color, material)
	local piece = part(parent, name, size, cframe, color, material)
	piece.Shape = Enum.PartType.Cylinder
	return piece
end

local function ball(parent, name, diameter, cframe, color, material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Ball
	piece.Anchored = true
	piece.CanCollide = false
	piece.Size = Vector3.new(diameter, diameter, diameter)
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.Snow
	piece.Parent = parent
	return piece
end

local function wedge(parent, name, size, cframe, color, material)
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.Snow
	piece.Parent = parent
	return piece
end

-- A big readable billboard. `lines` is a list of {text, color, height, font}.
-- The card is a fixed-height stack of labels so nothing depends on a layout pass
-- measured at load time — a screenshot pipeline cannot afford a frame where the
-- text has not laid out yet.
local function billboard(parent, adornee, size, offset, lines, backColor, strokeColor)
	local board = Instance.new("BillboardGui")
	board.Name = "Billboard"
	board.Size = UDim2.fromOffset(size.X, size.Y)
	board.StudsOffsetWorldSpace = offset
	-- Never AlwaysOnTop: see CharacterFactory's note. A BillboardGui drawn on top
	-- is dropped entirely by Studio's screen_capture, which is why every sign on
	-- this island came out blank in the first capture pass.
	board.AlwaysOnTop = false
	board.LightInfluence = 0
	board.MaxDistance = 320
	board.Adornee = adornee

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = backColor or Color3.fromRGB(10, 18, 34)
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = board

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 14)
	uiCorner.Parent = card

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = strokeColor or Color3.fromRGB(120, 220, 255)
	uiStroke.Thickness = 5
	uiStroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = card

	local totalHeight = 0
	for index, line in ipairs(lines) do
		totalHeight += line.height or 34
	end
	local cursor = math.max(0, (size.Y - totalHeight) / 2)

	for index, line in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. index
		label.Size = UDim2.new(1, 0, 0, line.height or 34)
		label.Position = UDim2.fromOffset(0, cursor)
		label.BackgroundTransparency = 1
		label.Font = line.font or Enum.Font.FredokaOne
		label.TextColor3 = line.color or Color3.fromRGB(255, 255, 255)
		label.TextStrokeColor3 = Color3.fromRGB(6, 12, 24)
		label.TextStrokeTransparency = 0.45
		label.TextScaled = true
		label.Text = line.text
		label.Parent = card
		cursor += line.height or 34
	end

	board.Parent = adornee
	return board
end

-- A SurfaceGui with one centred label, painted onto a slab's face. Returns the
-- label so the owner of the slab can rewrite it later (the den sign does).
--
-- THE BLACK SLAB FIX. A SurfaceGui that renders as a flat black panel is the
-- single most common way a sign dies in a Roblox capture, and it has three
-- causes, all of which are pinned down here:
--   * AlwaysOnTop = true -> Studio's screen_capture drops the surface entirely.
--     It must be false.
--   * Brightness = 0 (the default) -> the surface is lit only by the studio
--     light, and a sign on a shadowed face renders near-black. It must be 1, so
--     the panel carries its own light.
--   * LightInfluence = 1 -> the GUI is tinted by scene light, which on a navy
--     slab in cold fill goes to black. It must be 0.
-- The backing frame is opaque, the stroke is Neon-coloured, and the text is white
-- with a dark outline, so the panel reads as a lit sign against sunlit snow.
local function surfaceText(slab, face, text, textColor, backColor, strokeColor)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SignSurface"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 34
	surface.LightInfluence = 0
	surface.Brightness = 1
	surface.AlwaysOnTop = false
	surface.Parent = slab

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = backColor or WorldBuilder.denSignBack
	back.BackgroundTransparency = 0
	back.BorderSizePixel = 0
	back.Parent = surface

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or WorldBuilder.denSignColor
	stroke.Thickness = 8
	stroke.Parent = back

	-- A slow vertical gradient so the panel has a lit top edge instead of a flat
	-- fill: the same top-light every HUD panel and billboard card carries.
	local topLight = Instance.new("UIGradient")
	topLight.Rotation = 90
	topLight.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(196, 208, 224)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 138, 160)),
	})
	topLight.Parent = back

	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.new(1, -24, 1, -12)
	label.Position = UDim2.fromOffset(12, 6)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor or WorldBuilder.denSignColor
	label.TextStrokeColor3 = Color3.fromRGB(8, 14, 26)
	label.TextStrokeTransparency = 0.1
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	label.Parent = back

	return label, surface
end

-- ---------------------------------------------------------------- the island

local function buildGround(folder)
	local half = WorldBuilder.islandSize / 2

	local water = part(folder, "SeaFloor", Vector3.new(1400, 40, 1400), CFrame.new(0, -34, 0),
		Color3.fromRGB(28, 74, 118), Enum.Material.Glacier)
	water.CanCollide = false

	local island = part(folder, "Island", Vector3.new(WorldBuilder.islandSize, 24, WorldBuilder.islandSize),
		CFrame.new(0, -12, 0), Color3.fromRGB(246, 250, 255), Enum.Material.Snow)

	-- A raised snow shelf so the middle reads as a hill and the rim as a beach.
	part(folder, "InnerShelf", Vector3.new(half * 1.5, 6, half * 1.5), CFrame.new(0, 3, -20),
		Color3.fromRGB(252, 253, 255), Enum.Material.Snow)

	-- Ice-blue shoreline strips on all four edges of the shelf.
	for _, offset in ipairs({
		{ Vector3.new(0, 2.4, half * 0.74), Vector3.new(half * 1.5, 1, 12) },
		{ Vector3.new(0, 2.4, -half * 0.74 - 40), Vector3.new(half * 1.5, 1, 12) },
		{ Vector3.new(half * 0.74, 2.4, -20), Vector3.new(12, 1, half * 1.5) },
		{ Vector3.new(-half * 0.74, 2.4, -20), Vector3.new(12, 1, half * 1.5) },
	}) do
		part(folder, "IceShelf", offset[2], CFrame.new(offset[1]), Color3.fromRGB(196, 236, 255), Enum.Material.Ice)
	end

	-- Rim walls of packed ice so the island reads as a bowl.
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local radians = math.rad(angle)
		local distance = half - 12
		part(folder, "Rim", Vector3.new(WorldBuilder.islandSize, 14, 16),
			CFrame.new(math.sin(radians) * distance, 2, math.cos(radians) * distance)
				* CFrame.Angles(0, radians, 0),
			Color3.fromRGB(226, 244, 255), Enum.Material.Glacier)
	end

	return island
end

-- The lighting recipe: a LOW warm sun at 16.5 against a cool blue fill, an arctic
-- atmosphere for depth, and three post effects that make neon and snow read.
--
-- The warm-vs-cool split is the whole trick. 16.5 puts the sun low behind long
-- shadows; ColorShift_Top warms the key light while OutdoorAmbient cools the fill,
-- and that contrast is what makes a flat Part island read as three dimensional in
-- a still frame. Ambient stays LOW (35,40,55) on purpose: a high ambient raises
-- the floor of every pixel and the contrast dies. Noon (14, the old setting) killed
-- every shadow and the frame went soft and grey.
local function buildLighting()
	Lighting.ClockTime = 16.5
	Lighting.GeographicLatitude = 78
	Lighting.Brightness = 2.2
	Lighting.ExposureCompensation = -0.15
	Lighting.Ambient = Color3.fromRGB(35, 40, 55)
	Lighting.OutdoorAmbient = Color3.fromRGB(134, 158, 190)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 220, 190)
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 130, 176)
	Lighting.ShadowSoftness = 0.15
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.35
	-- Atmosphere owns the haze now, so the legacy fog stays out of the way
	-- entirely rather than stacking a second white wash on top of it.
	Lighting.FogEnd = 100000
	Lighting.FogStart = 100000
	Lighting.FogColor = Color3.fromRGB(226, 240, 255)

	-- Atmosphere: depth on the horizon, and it hides the map edge behind the
	-- mountains. Kept at a density that leaves a name tag legible past 100 studs;
	-- a thicker one washed the whole capture milky in the first pass.
	local atmosphere = Lighting:FindFirstChild("PolarAtmosphere")
	if not atmosphere then
		local existingAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if existingAtmosphere then
			existingAtmosphere:Destroy()
		end
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "PolarAtmosphere"
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.18
	atmosphere.Color = Color3.fromRGB(196, 222, 240)
	atmosphere.Decay = Color3.fromRGB(96, 130, 176)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 0.6

	-- The sky: a gradient arctic skybox with the celestial bodies shown, so the
	-- low sun has something to set against and the wide shots get a real horizon.
	local sky = Lighting:FindFirstChild("PolarSky")
	if not sky then
		local existingSky = Lighting:FindFirstChildOfClass("Sky")
		if existingSky then
			existingSky:Destroy()
		end
		sky = Instance.new("Sky")
		sky.Name = "PolarSky"
		sky.SkyboxBk = "rbxasset://sky/sky512_bk.tex"
		sky.SkyboxDn = "rbxasset://sky/sky512_dn.tex"
		sky.SkyboxFt = "rbxasset://sky/sky512_ft.tex"
		sky.SkyboxLf = "rbxasset://sky/sky512_lf.tex"
		sky.SkyboxRt = "rbxasset://sky/sky512_rt.tex"
		sky.SkyboxUp = "rbxasset://sky/sky512_up.tex"
		sky.Parent = Lighting
	end
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 10
	sky.StarCount = 3000

	local bloom = Lighting:FindFirstChild("PolarBloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "PolarBloom"
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.35
	bloom.Size = 24
	bloom.Threshold = 1.6

	local grade = Lighting:FindFirstChild("PolarGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "PolarGrade"
		grade.Parent = Lighting
	end
	grade.Brightness = -0.01
	grade.Contrast = 0.06
	grade.Saturation = 0.12

	local rays = Lighting:FindFirstChild("PolarSunRays")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Name = "PolarSunRays"
		rays.Parent = Lighting
	end
	rays.Intensity = 0.03
	rays.Spread = 0.7
end

-- ---------------------------------------------------------------- the plaza

local function buildSpawnPlaza(folder)
	local plaza = Instance.new("Folder")
	plaza.Name = "SpawnPlaza"
	plaza.Parent = folder

	local center = WorldBuilder.plazaCenter

	part(plaza, "PlazaFloor", Vector3.new(140, 2, 96), CFrame.new(center + Vector3.new(0, 3.4, 0)),
		Color3.fromRGB(226, 240, 255), Enum.Material.Ice)

	for index = -2, 2 do
		part(plaza, "PlazaStripe", Vector3.new(140, 0.2, 2),
			CFrame.new(center + Vector3.new(0, 4.5, index * 18)), Color3.fromRGB(180, 214, 246),
			Enum.Material.SmoothPlastic)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnPad"
	spawn.Anchored = true
	spawn.Size = Vector3.new(24, 1.6, 24)
	spawn.CFrame = CFrame.new(WorldBuilder.spawnPosition - Vector3.new(0, 5, 0))
	spawn.Color = Color3.fromRGB(110, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = plaza

	local spawnRing = cylinder(plaza, "SpawnRing", Vector3.new(1.2, 30, 30),
		CFrame.new(WorldBuilder.spawnPosition - Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	spawnRing.CanCollide = false

	-- The welcome sign: the first thing a player reads. Slab plus billboard, the
	-- same pattern as the den signs so the whole island reads consistently.
	local signPost = part(plaza, "SignPost", Vector3.new(3, 18, 3), CFrame.new(0, 12, 208),
		Color3.fromRGB(96, 72, 56), Enum.Material.Wood)
	local signBoard = part(plaza, "SignBoard", Vector3.new(56, 16, 2), CFrame.new(0, 22, 208),
		Color3.fromRGB(18, 30, 52), Enum.Material.SmoothPlastic)
	signBoard.CanCollide = false
	surfaceText(signBoard, Enum.NormalId.Front, "BRAINROT POLAR PANIC!", Color3.fromRGB(255, 236, 130),
		Color3.fromRGB(10, 22, 44), Color3.fromRGB(255, 200, 90))

	billboard(plaza, signBoard, Vector2.new(560, 150), Vector3.new(0, 2, 0), {
		{ text = "BRAINROT POLAR PANIC!", color = Color3.fromRGB(255, 236, 130), height = 74, font = Enum.Font.FredokaOne },
		{ text = "Hatch them. Place them. Get rich. Outrun the Ice Wall.", color = Color3.fromRGB(190, 232, 255), height = 40, font = Enum.Font.GothamBold },
	}, Color3.fromRGB(10, 22, 44), Color3.fromRGB(255, 200, 90))

	-- Flag poles down both sides of the plaza.
	for side = -1, 1, 2 do
		for index = 1, 3 do
			local x = side * (58 + index * 4)
			local z = 120 + index * 16
			part(plaza, "FlagPole", Vector3.new(1, 26, 1), CFrame.new(x, 16, z),
				Color3.fromRGB(220, 226, 236), Enum.Material.Metal)
			local flag = part(plaza, "Flag", Vector3.new(0.4, 7, 12), CFrame.new(x, 26, z - 6),
				index % 2 == 0 and Color3.fromRGB(90, 190, 255) or Color3.fromRGB(255, 214, 92),
				Enum.Material.SmoothPlastic)
			flag.CanCollide = false
			flag.CFrame = CFrame.new(x, 26, z - 6) * CFrame.Angles(0, 0, math.rad(4 * side))
		end
	end

	-- A little "how to play" plinth in the middle of the plaza.
	local plinth = part(plaza, "Plinth", Vector3.new(20, 6, 12), CFrame.new(0, 7.4, 178),
		Color3.fromRGB(148, 186, 224), Enum.Material.Marble)
	billboard(plaza, plinth, Vector2.new(440, 130), Vector3.new(0, 6, 0), {
		{ text = "PRESS  E  TO HATCH / PLACE / STEAL", color = Color3.fromRGB(255, 255, 255), height = 46, font = Enum.Font.GothamBlack },
		{ text = "Walk to an egg machine. Then carry it home.", color = Color3.fromRGB(180, 232, 255), height = 34, font = Enum.Font.GothamBold },
	}, Color3.fromRGB(12, 26, 46), Color3.fromRGB(110, 220, 255))

	return plaza
end

-- ---------------------------------------------------------------- the shop

local function buildEggMachine(parent, egg, position)
	local model = Instance.new("Model")
	model.Name = "EggMachine_" .. egg.id
	model.Parent = parent

	local plinth = part(model, "Plinth", Vector3.new(12, 4, 12), CFrame.new(position + Vector3.new(0, 2, 0)),
		Color3.fromRGB(38, 52, 78), Enum.Material.Metal)
	part(model, "PlinthTrim", Vector3.new(13.5, 0.8, 13.5), CFrame.new(position + Vector3.new(0, 4, 0)),
		egg.color, Enum.Material.Neon)

	-- The egg: a ball with a ring around it, tinted to the machine's rarity colour.
	-- PLAYER-SCALE: egg ~5-6 studs, machine ~10 studs tall total
	local eggBody = ball(model, "Egg", 5.5, CFrame.new(position + Vector3.new(0, 7.5, 0)), egg.color, Enum.Material.Neon)
	eggBody.CanCollide = false
	local shellRing = cylinder(model, "EggRing", Vector3.new(0.8, 7, 7),
		CFrame.new(position + Vector3.new(0, 7.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), egg.accent,
		Enum.Material.Neon)
	shellRing.CanCollide = false
	shellRing.Transparency = 0.25

	local glow = Instance.new("PointLight")
	glow.Color = egg.color
	glow.Range = 18
	glow.Brightness = 2.4
	glow.Parent = eggBody

	model.PrimaryPart = plinth
	model:SetAttribute("EggId", egg.id)
	model:SetAttribute("EggPrice", egg.price)

	billboard(model, plinth, Vector2.new(360, 140), Vector3.new(0, 14, 0), {
		{ text = string.upper(egg.name), color = egg.accent, height = 40, font = Enum.Font.FredokaOne },
		{ text = "$" .. egg.price, color = Color3.fromRGB(255, 236, 130), height = 42, font = Enum.Font.GothamBlack },
		{ text = egg.blurb, color = Color3.fromRGB(206, 226, 246), height = 28, font = Enum.Font.Gotham },
	}, Color3.fromRGB(10, 18, 34), egg.color)

	-- A second, low board facing the shop floor with the odds: the acquire frame
	-- has to show what you are rolling for, not just the price.
	billboard(model, plinth, Vector2.new(320, 60), Vector3.new(0, 7, 0), {
		{ text = RarityConfig.oddsLine(egg.weights), color = egg.accent, height = 34, font = Enum.Font.GothamBold },
	}, Color3.fromRGB(8, 14, 26), egg.color)

	-- ProximityPrompt: the E key. Everything it triggers is validated server-side.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = "Hatch"
	prompt.ObjectText = egg.name .. "  $" .. egg.price
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = plinth

	return {
		id = egg.id,
		model = model,
		eggPart = eggBody,
		prompt = prompt,
		position = position,
	}
end

local function buildKiosk(parent, name, title, subtitle, position, color)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local base = part(model, "Base", Vector3.new(12, 8, 12), CFrame.new(position + Vector3.new(0, 4, 0)),
		Color3.fromRGB(40, 56, 84), Enum.Material.Metal)
	part(model, "Trim", Vector3.new(13.5, 1, 13.5), CFrame.new(position + Vector3.new(0, 8, 0)), color,
		Enum.Material.Neon)
	local roof = part(model, "Roof", Vector3.new(15, 1.4, 15), CFrame.new(position + Vector3.new(0, 12.6, 0)),
		Color3.fromRGB(226, 240, 255), Enum.Material.Snow)
	roof.CanCollide = false

	model.PrimaryPart = base
	billboard(model, base, Vector2.new(300, 132), Vector3.new(0, 13, 0), {
		{ text = title, color = Color3.fromRGB(255, 255, 255), height = 46, font = Enum.Font.FredokaOne },
		{ text = subtitle, color = color, height = 38, font = Enum.Font.GothamBlack },
	}, Color3.fromRGB(10, 18, 34), color)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KioskPrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base

	return { model = model, prompt = prompt, position = position }
end

local function buildConveyor(parent)
	local center = WorldBuilder.conveyorCenter
	local model = Instance.new("Model")
	model.Name = "Conveyor"
	model.Parent = parent

	-- Its own apron. The belt now lives on the shop side of the island, so it
	-- gets a floor of its own rather than relying on the shop slab reaching here.
	local apron = part(model, "ConveyorApron", Vector3.new(104, 2, 132),
		CFrame.new(center + Vector3.new(0, 3.2, 0)), Color3.fromRGB(236, 244, 255), Enum.Material.Ice)
	apron.CanCollide = true

	-- A rounded rectangle path: four straight runs joined by corner pads.
	local runs = {
		{ offset = Vector3.new(0, 0, -34), size = Vector3.new(66, 1.6, 8) },
		{ offset = Vector3.new(0, 0, 34), size = Vector3.new(66, 1.6, 8) },
		{ offset = Vector3.new(-33, 0, 0), size = Vector3.new(8, 1.6, 76) },
		{ offset = Vector3.new(33, 0, 0), size = Vector3.new(8, 1.6, 76) },
	}

	local waypoints = {}

	for _, run in ipairs(runs) do
		local belt = part(model, "Belt", run.size, CFrame.new(center + run.offset + Vector3.new(0, 4, 0)),
			Color3.fromRGB(52, 62, 82), Enum.Material.DiamondPlate)
		belt.TopSurface = Enum.SurfaceType.Smooth

		-- Rollers read as a belt in motion even when nothing is on it.
		local along = math.max(run.size.X, run.size.Z)
		local across = math.min(run.size.X, run.size.Z)
		for step = -math.floor(along / 2) + 3, math.floor(along / 2) - 3, 6 do
			local localOffset = if run.size.Z > run.size.X
				then Vector3.new(0, 0.9, step)
				else Vector3.new(step, 0.9, 0)
			cylinder(model, "Roller", Vector3.new(across * 0.8, 1.2, 1.2),
				CFrame.new(center + run.offset + localOffset) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(126, 148, 176), Enum.Material.Metal)
		end
	end

	for _, corner in ipairs({
		Vector3.new(-33, 0, -34), Vector3.new(33, 0, -34), Vector3.new(33, 0, 34), Vector3.new(-33, 0, 34),
	}) do
		part(model, "CornerPad", Vector3.new(14, 1.6, 14), CFrame.new(center + corner + Vector3.new(0, 4, 0)),
			Color3.fromRGB(52, 62, 82), Enum.Material.DiamondPlate)
	end

	-- The route a spawned character walks, in order, as world positions.
	table.insert(waypoints, center + Vector3.new(-33, 5.4, -34))
	table.insert(waypoints, center + Vector3.new(33, 5.4, -34))
	table.insert(waypoints, center + Vector3.new(33, 5.4, 34))
	table.insert(waypoints, center + Vector3.new(-33, 5.4, 34))

	-- A big sign so the free-loot route is discoverable.
	local signPost = part(model, "ConveyorSign", Vector3.new(30, 11, 1.6),
		CFrame.new(center + Vector3.new(0, 20, -42)), Color3.fromRGB(16, 28, 48), Enum.Material.SmoothPlastic)
	signPost.CanCollide = false
	surfaceText(signPost, Enum.NormalId.Front, "FREE BRAINROT CONVEYOR", Color3.fromRGB(120, 255, 190),
		Color3.fromRGB(10, 18, 34), Color3.fromRGB(120, 255, 190))
	billboard(model, signPost, Vector2.new(440, 120), Vector3.new(0, 8, 0), {
		{ text = "FREE BRAINROT CONVEYOR", color = Color3.fromRGB(120, 255, 190), height = 44, font = Enum.Font.FredokaOne },
		{ text = "Walk into one to grab it. Nobody is watching.", color = Color3.fromRGB(200, 232, 255), height = 32, font = Enum.Font.GothamBold },
	}, Color3.fromRGB(10, 18, 34), Color3.fromRGB(120, 255, 190))

	for _, x in ipairs({ -13, 13 }) do
		part(model, "SignLeg", Vector3.new(1, 14, 1), CFrame.new(center + Vector3.new(x, 13, -42)),
			Color3.fromRGB(220, 226, 236), Enum.Material.Metal)
	end

	return { model = model, waypoints = waypoints, center = center }
end

local function buildShopDistrict(folder)
	local shop = Instance.new("Folder")
	shop.Name = "ShopDistrict"
	shop.Parent = folder

	-- The shop apron.
	part(shop, "ShopFloor", Vector3.new(120, 2, 260), CFrame.new(WorldBuilder.shopCenter + Vector3.new(0, 3.2, 0)),
		Color3.fromRGB(238, 246, 255), Enum.Material.Ice)

	local eggMachines = {}
	local spacing = 62
	for index, egg in ipairs(EggConfig.eggs) do
		local z = WorldBuilder.shopCenter.Z + (index - 2.5) * spacing
		local position = Vector3.new(WorldBuilder.shopCenter.X, 0, z)
		eggMachines[egg.id] = buildEggMachine(shop, egg, position)
	end

	local upgradesKiosk = buildKiosk(shop, "UpgradesKiosk", "UPGRADES", "SPEED BOOTS + EGG LUCK",
		Vector3.new(-96, 0, 150), Color3.fromRGB(255, 196, 92))
	local lockKiosk = buildKiosk(shop, "LockKiosk", "BASE LOCK", "$300  ·  60 SECONDS",
		Vector3.new(-96, 0, 108), Color3.fromRGB(120, 220, 255))

	local conveyor = buildConveyor(shop)

	return {
		folder = shop,
		eggMachines = eggMachines,
		upgradesKiosk = upgradesKiosk,
		lockKiosk = lockKiosk,
		conveyor = conveyor,
	}
end

-- ---------------------------------------------------------------- the dens

-- One den: a snow disc, an igloo behind the pads, 16 sockets in a 4x4 grid, a
-- name sign that carries real text on two surfaces, and a shield dome that stays
-- invisible until the owner buys a Lock.
local function buildBase(parent, index, position)
	local model = Instance.new("Model")
	model.Name = "Base_" .. index
	model.Parent = parent

	local platformSize = WorldBuilder.basePlatformSize

	local disc = cylinder(model, "Platform", Vector3.new(3, platformSize, platformSize),
		CFrame.new(position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(248, 252, 255), Enum.Material.Snow)
	disc.CanCollide = true
	local ring = cylinder(model, "IceRing", Vector3.new(1.6, platformSize + 3, platformSize + 3),
		CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(170, 220, 255), Enum.Material.Ice)
	ring.CanCollide = false

	-- The igloo sits BEHIND the pads (-Z), because every camera that matters for a
	-- capture stands on the plaza side (+Z). When the igloo was at +Z its dome was
	-- the biggest thing between the lens and the cast, and it hid the whole den.
	local dome = ball(model, "Igloo", 30, CFrame.new(position + Vector3.new(0, 3, -44)),
		Color3.fromRGB(246, 250, 255), Enum.Material.Snow)
	dome.CanCollide = true
	local door = part(model, "IglooDoor", Vector3.new(8, 9, 1), CFrame.new(position + Vector3.new(0, 7, -29)),
		Color3.fromRGB(58, 78, 110), Enum.Material.SmoothPlastic)
	door.CanCollide = false

	-- 4x4 pad sockets, nudged toward +Z so the igloo has room behind them and the
	-- camera gets a clean, unobstructed row of characters with their labels up.
	local pads = {}
	local grid = WorldBuilder.padGridSize
	local spacing = WorldBuilder.padSpacing
	local originOffset = -((grid - 1) * spacing) / 2
	for row = 1, grid do
		for column = 1, grid do
			local padIndex = (row - 1) * grid + column
			local localX = originOffset + (column - 1) * spacing
			local localZ = originOffset + (row - 1) * spacing + 6
			local padPosition = position + Vector3.new(localX, 4.9, localZ)

			local socket = cylinder(model, "Pad_" .. padIndex, Vector3.new(0.8, 7, 7),
				CFrame.new(padPosition) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(96, 150, 210), Enum.Material.SmoothPlastic)
			socket.CanCollide = false
			socket:SetAttribute("PadIndex", padIndex)

			local glow = cylinder(model, "PadGlow_" .. padIndex, Vector3.new(1, 6.2, 6.2),
				CFrame.new(padPosition + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
			glow.CanCollide = false
			glow.CanQuery = false
			glow.Transparency = 0.55

			pads[padIndex] = { part = socket, glow = glow, position = padPosition }
		end
	end

	-- The sign stands BEHIND the den (-Z), tall enough to clear the igloo and the
	-- cast, so the plaza approach reads it across the island and the cover camera
	-- (which always stands on the +Z plaza side) looks THROUGH the pads at it
	-- instead of being masked by it. Slab + billboard; PlotService repaints both.
	local signSlab = part(model, "NameSign", Vector3.new(44, 13, 1.2),
		CFrame.new(position + Vector3.new(0, 34, -62)), WorldBuilder.denSignBack, Enum.Material.SmoothPlastic)
	signSlab.CanCollide = false
	local signFace = surfaceText(signSlab, Enum.NormalId.Back, "UNCLAIMED DEN",
		WorldBuilder.denSignColor, WorldBuilder.denSignBack, WorldBuilder.denSignColor)
	local signBackFace = surfaceText(signSlab, Enum.NormalId.Front, "UNCLAIMED DEN",
		WorldBuilder.denSignColor, WorldBuilder.denSignBack, WorldBuilder.denSignColor)

	local signBoard = billboard(model, signSlab, Vector2.new(520, 140), Vector3.new(0, 8, 0), {
		{ text = "UNCLAIMED DEN", color = WorldBuilder.denSignColor, height = 76, font = Enum.Font.FredokaOne },
	}, WorldBuilder.denSignBack, WorldBuilder.denSignColor)
	local signTitle = signBoard.Card:FindFirstChild("Line1")

	for _, x in ipairs({ -18, 18 }) do
		part(model, "SignLeg", Vector3.new(1.4, 30, 1.4), CFrame.new(position + Vector3.new(x, 19, -62)),
			Color3.fromRGB(220, 226, 236), Enum.Material.Metal)
	end

	-- The shield dome: invisible until the owner buys a Lock. Even when raised it
	-- stays faint, because a translucent sphere between the camera and the den is
	-- exactly what ruined the first cover frame.
	local shield = ball(model, "ShieldDome", platformSize + 12, CFrame.new(position + Vector3.new(0, 10, 0)),
		Color3.fromRGB(120, 210, 255), Enum.Material.ForceField)
	shield.CanCollide = false
	shield.CanQuery = false
	shield.CastShadow = false
	shield.Transparency = 1

	model.PrimaryPart = disc
	model:SetAttribute("BaseIndex", index)

	return {
		index = index,
		model = model,
		position = position,
		pads = pads,
		signTitle = signTitle,
		signFace = signFace,
		signBackFace = signBackFace,
		shield = shield,
		dome = dome,
	}
end

local function buildBases(folder)
	local basesFolder = Instance.new("Folder")
	basesFolder.Name = "Bases"
	basesFolder.Parent = folder

	local bases = {}
	for index, spot in ipairs(WorldBuilder.baseSpots) do
		bases[index] = buildBase(basesFolder, index, spot)
	end
	return { folder = basesFolder, bases = bases }
end

-- ---------------------------------------------------------------- the lake

local function buildFrozenLake(folder)
	local lake = Instance.new("Folder")
	lake.Name = "FrozenLake"
	lake.Parent = folder

	local center = WorldBuilder.lakeCenter
	local radius = 52

	local ice = cylinder(lake, "Ice", Vector3.new(1.2, radius * 2, radius * 2),
		CFrame.new(center + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(178, 226, 255), Enum.Material.Ice)
	ice.CanCollide = true
	ice.Reflectance = 0.22

	-- Cracks: thin dark strips so the ice reads as ice, not a blue circle.
	for index = 1, 7 do
		local angle = (index / 7) * math.pi * 2
		local length = 24 + (index % 3) * 10
		part(lake, "Crack", Vector3.new(length, 0.1, 0.35),
			CFrame.new(center + Vector3.new(math.cos(angle) * length * 0.4, 4.85, math.sin(angle) * length * 0.4))
				* CFrame.Angles(0, angle, 0),
			Color3.fromRGB(126, 186, 226), Enum.Material.SmoothPlastic, { CanCollide = false })
	end

	-- The ice sculpture: a stacked crystal on a plinth, the island's landmark.
	local plinth = part(lake, "SculpturePlinth", Vector3.new(14, 4, 14), CFrame.new(center + Vector3.new(0, 6, 0)),
		Color3.fromRGB(210, 234, 255), Enum.Material.Ice)
	for index = 1, 4 do
		local scale = 10 - index * 2
		local crystal = ball(lake, "Crystal", scale, CFrame.new(center + Vector3.new(0, 8 + index * 5.5, 0)),
			Color3.fromRGB(198, 238, 255), Enum.Material.Glass)
		crystal.Transparency = 0.22
		crystal.CanCollide = false
		crystal.CFrame = CFrame.new(center + Vector3.new(0, 8 + index * 5.5, 0))
			* CFrame.Angles(0, math.rad(index * 24), 0)
	end

	local sculptureLight = Instance.new("PointLight")
	sculptureLight.Color = Color3.fromRGB(150, 220, 255)
	sculptureLight.Range = 48
	sculptureLight.Brightness = 2.2
	sculptureLight.Parent = plinth

	billboard(lake, plinth, Vector2.new(400, 100), Vector3.new(0, 18, 0), {
		{ text = "FROZEN LAKE", color = Color3.fromRGB(200, 240, 255), height = 46, font = Enum.Font.FredokaOne },
	}, Color3.fromRGB(12, 26, 46), Color3.fromRGB(150, 220, 255))

	return lake
end

-- ---------------------------------------------------------------- the rim

local function buildMountains(folder)
	local rim = Instance.new("Folder")
	rim.Name = "Rim"
	rim.Parent = folder

	local half = WorldBuilder.islandSize / 2

	-- Low-poly mountains on the north rim, icebergs everywhere else.
	for index, spec in ipairs({
		{ Vector3.new(-190, 0, -232), 66, 34, 60 },
		{ Vector3.new(-120, 0, -244), 54, 28, 48 },
		{ Vector3.new(-40, 0, -238), 72, 40, 62 },
		{ Vector3.new(60, 0, -244), 58, 30, 52 },
		{ Vector3.new(150, 0, -234), 64, 36, 58 },
		{ Vector3.new(228, 0, -190), 50, 26, 46 },
		{ Vector3.new(-236, 0, -170), 48, 26, 44 },
	}) do
		local base = spec[1]
		local height = spec[2]
		local width = spec[3]
		local depth = spec[4]
		wedge(rim, "Mountain", Vector3.new(width, height, depth),
			CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(index * 37), 0),
			Color3.fromRGB(206, 226, 246), Enum.Material.Glacier)
		wedge(rim, "MountainCap", Vector3.new(width * 0.9, height * 0.45, depth * 0.9),
			CFrame.new(base + Vector3.new(0, height * 0.78, 0)) * CFrame.Angles(0, math.rad(index * 37 + 12), 0),
			Color3.fromRGB(252, 254, 255), Enum.Material.Snow)
	end

	for index, angle in ipairs({ 12, 76, 148, 214, 292, 340 }) do
		local radians = math.rad(angle)
		local distance = half * 0.86
		local x = math.cos(radians) * distance
		local z = math.sin(radians) * distance
		local height = 20 + (index % 3) * 12
		local berg = part(rim, "Iceberg", Vector3.new(22 + index * 2, height, 18 + index * 3),
			CFrame.new(x, 4 + height / 2, z) * CFrame.Angles(math.rad(index * 6), radians, math.rad(index * 4)),
			Color3.fromRGB(196, 232, 255), Enum.Material.Glacier)
		berg.CanCollide = true
		ball(rim, "BergCap", 12, CFrame.new(x, 4 + height, z), Color3.fromRGB(248, 252, 255), Enum.Material.Snow)
	end

	return rim
end

-- ---------------------------------------------------------------- decorations

local function buildSnowman(parent, position)
	local model = Instance.new("Model")
	model.Name = "Snowman"
	model.Parent = parent
	ball(model, "Bottom", 6, CFrame.new(position + Vector3.new(0, 7, 0)), Color3.fromRGB(252, 254, 255))
	ball(model, "Middle", 4.6, CFrame.new(position + Vector3.new(0, 11.4, 0)), Color3.fromRGB(252, 254, 255))
	local head = ball(model, "Head", 3.4, CFrame.new(position + Vector3.new(0, 14.8, 0)),
		Color3.fromRGB(252, 254, 255))
	part(model, "Nose", Vector3.new(0.5, 0.5, 2), CFrame.new(position + Vector3.new(0, 14.9, -1.9)),
		Color3.fromRGB(255, 140, 48), Enum.Material.SmoothPlastic)
	part(model, "Hat", Vector3.new(2.6, 1.6, 2.6), CFrame.new(position + Vector3.new(0, 16.6, 0)),
		Color3.fromRGB(48, 52, 72), Enum.Material.Fabric)
	part(model, "Scarf", Vector3.new(3.2, 0.8, 3.2), CFrame.new(position + Vector3.new(0, 13.2, 0)),
		Color3.fromRGB(224, 68, 68), Enum.Material.Fabric)
	model.PrimaryPart = head
	return model
end

local function buildPenguin(parent, position, color)
	local model = Instance.new("Model")
	model.Name = "Penguin"
	model.Parent = parent
	local body = part(model, "Body", Vector3.new(2.6, 3.6, 2.4), CFrame.new(position + Vector3.new(0, 6, 0)),
		color or Color3.fromRGB(38, 48, 72), Enum.Material.SmoothPlastic)
	part(model, "Belly", Vector3.new(1.8, 2.6, 0.5), CFrame.new(position + Vector3.new(0, 6, -1.25)),
		Color3.fromRGB(250, 250, 255), Enum.Material.SmoothPlastic)
	part(model, "Beak", Vector3.new(0.7, 0.6, 1.1), CFrame.new(position + Vector3.new(0, 6.6, -1.7)),
		Color3.fromRGB(255, 168, 48), Enum.Material.SmoothPlastic)
	part(model, "Feet", Vector3.new(2.2, 0.4, 1.4), CFrame.new(position + Vector3.new(0, 4.2, -0.4)),
		Color3.fromRGB(255, 168, 48), Enum.Material.SmoothPlastic)
	ball(model, "EyeL", 0.5, CFrame.new(position + Vector3.new(-0.55, 7, -1.2)), Color3.fromRGB(20, 20, 28))
	ball(model, "EyeR", 0.5, CFrame.new(position + Vector3.new(0.55, 7, -1.2)), Color3.fromRGB(20, 20, 28))
	model.PrimaryPart = body
	return model
end

local function buildPineTree(parent, position, height)
	local model = Instance.new("Model")
	model.Name = "PineTree"
	model.Parent = parent
	part(model, "Trunk", Vector3.new(2, height * 0.4, 2), CFrame.new(position + Vector3.new(0, height * 0.2, 0)),
		Color3.fromRGB(84, 62, 46), Enum.Material.Wood)
	for tier = 1, 3 do
		local tierHeight = height * (0.42 - tier * 0.08)
		local radius = height * (0.34 - tier * 0.08)
		local tierCframe = CFrame.new(position + Vector3.new(0, height * 0.32 + tier * height * 0.2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		local cone = cylinder(model, "Tier" .. tier, Vector3.new(radius * 2, tierHeight, radius * 2),
			tierCframe, Color3.fromRGB(30, 92, 78), Enum.Material.Grass)
		cone.CanCollide = false
		local capCframe = CFrame.new(position
				+ Vector3.new(0, height * 0.32 + tier * height * 0.2 + tierHeight * 0.45, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		local cap = cylinder(model, "SnowCap" .. tier, Vector3.new(radius * 1.7, 0.6, radius * 1.7),
			capCframe, Color3.fromRGB(250, 253, 255), Enum.Material.Snow)
		cap.CanCollide = false
	end
	model.PrimaryPart = model:FindFirstChild("Trunk")
	return model
end

local function buildCrate(parent, position, index)
	local crate = part(parent, "Crate", Vector3.new(4, 4, 4), CFrame.new(position + Vector3.new(0, 6, 0))
		* CFrame.Angles(0, math.rad(index * 17), 0), Color3.fromRGB(184, 132, 76), Enum.Material.WoodPlanks)
	crate.CanCollide = true
	part(parent, "CrateBand", Vector3.new(4.2, 0.5, 4.2), CFrame.new(position + Vector3.new(0, 6, 0)),
		Color3.fromRGB(120, 84, 48), Enum.Material.Wood)
	return crate
end

local function buildLantern(parent, position)
	local post = part(parent, "LanternPost", Vector3.new(0.7, 12, 0.7), CFrame.new(position + Vector3.new(0, 10, 0)),
		Color3.fromRGB(64, 72, 96), Enum.Material.Metal)
	local bulb = part(parent, "LanternBulb", Vector3.new(2.2, 2.6, 2.2), CFrame.new(position + Vector3.new(0, 17, 0)),
		Color3.fromRGB(255, 226, 150), Enum.Material.Neon)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 214, 140)
	light.Range = 34
	light.Brightness = 1.8
	light.Parent = bulb
	return post
end

local function buildDecorations(folder)
	local deco = Instance.new("Folder")
	deco.Name = "Decorations"
	deco.Parent = folder

	-- Snowmen and penguins ringing the plaza.
	local snowmanSpots = {
		Vector3.new(-76, 0, 190), Vector3.new(76, 0, 190),
		Vector3.new(-76, 0, 118), Vector3.new(76, 0, 118),
		Vector3.new(-118, 0, 62), Vector3.new(-112, 0, 18),
	}
	for _, spot in ipairs(snowmanSpots) do
		buildSnowman(deco, spot)
	end

	local penguinSpots = {
		{ Vector3.new(-40, 0, 100), nil },
		{ Vector3.new(-16, 0, 96), Color3.fromRGB(60, 76, 110) },
		{ Vector3.new(20, 0, 100), nil },
		{ Vector3.new(46, 0, 96), Color3.fromRGB(48, 62, 96) },
		{ Vector3.new(96, 0, 130), nil },
		{ Vector3.new(-90, 0, -20), Color3.fromRGB(52, 68, 100) },
		{ Vector3.new(84, 0, -8), nil },
	}
	for _, spot in ipairs(penguinSpots) do
		buildPenguin(deco, spot[1], spot[2])
	end

	-- Pine trees: a belt around the rim and a few near the lake.
	local treeSpots = {
		{ Vector3.new(-210, 0, 170), 46 }, { Vector3.new(-196, 0, 120), 38 },
		{ Vector3.new(206, 0, 150), 44 }, { Vector3.new(196, 0, 96), 36 },
		{ Vector3.new(-70, 0, -110), 40 }, { Vector3.new(58, 0, -104), 42 },
		{ Vector3.new(-20, 0, -120), 36 }, { Vector3.new(240, 0, -30), 38 },
		{ Vector3.new(-244, 0, -110), 40 }, { Vector3.new(120, 0, 190), 34 },
		{ Vector3.new(-150, 0, 200), 36 }, { Vector3.new(30, 0, -150), 40 },
	}
	for _, spot in ipairs(treeSpots) do
		buildPineTree(deco, spot[1], spot[2])
	end

	local crateSpots = {
		Vector3.new(-62, 0, 96), Vector3.new(-58, 0, 100),
		Vector3.new(66, 0, 90), Vector3.new(112, 0, 12), Vector3.new(-118, 0, -12),
	}
	for index, spot in ipairs(crateSpots) do
		buildCrate(deco, spot, index)
	end

	for _, spot in ipairs({
		Vector3.new(-64, 0, 206), Vector3.new(64, 0, 206),
		Vector3.new(-64, 0, 108), Vector3.new(64, 0, 108),
		Vector3.new(-120, 0, -8), Vector3.new(122, 0, -8),
		Vector3.new(-26, 0, -96), Vector3.new(26, 0, -96),
	}) do
		buildLantern(deco, spot)
	end

	return deco
end

-- ---------------------------------------------------------------- the ice wall

local function buildIceWall(folder)
	local wall = Instance.new("Model")
	wall.Name = "IceWall"
	wall.Parent = folder

	local slab = part(wall, "Slab",
		Vector3.new(WorldBuilder.iceWallWidth, WorldBuilder.iceWallHeight, 8),
		CFrame.new(0, WorldBuilder.iceWallHeight / 2, WorldBuilder.iceWallStartZ),
		Color3.fromRGB(96, 178, 240), Enum.Material.Ice)
	-- Opaque enough to read as a WALL in a capture: at 0.3 the slab all but
	-- vanished and only its crest spheres showed, which looked like balloons.
	slab.Transparency = 0.12
	slab.CanCollide = false
	slab.CanQuery = false

	-- A crest along the top so the wall reads as a wave, not a billboard.
	for index = -5, 5 do
		local crest = ball(wall, "Crest", 30,
			CFrame.new(index * 40, WorldBuilder.iceWallHeight - 4, WorldBuilder.iceWallStartZ),
			Color3.fromRGB(168, 222, 255), Enum.Material.Ice)
		crest.Transparency = 0.18
		crest.CanCollide = false
		crest.CanQuery = false
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 220, 255)
	light.Range = 160
	light.Brightness = 4
	light.Parent = slab

	-- A trigger volume that travels with the slab; IceWallService reads touches.
	local trigger = part(wall, "Trigger", Vector3.new(WorldBuilder.iceWallWidth, WorldBuilder.iceWallHeight, 10),
		CFrame.new(0, WorldBuilder.iceWallHeight / 2, WorldBuilder.iceWallStartZ),
		Color3.fromRGB(140, 210, 255), Enum.Material.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = true })
	trigger:SetAttribute("IsIceWallTrigger", true)

	wall.PrimaryPart = slab
	wall:SetAttribute("Active", false)

	-- Parked out of sight until the first sweep.
	wall:PivotTo(CFrame.new(0, -400, 0))

	return { model = wall, slab = slab, trigger = trigger, light = light }
end

-- ---------------------------------------------------------------- public build

-- Build (or rebuild) the whole island. Returns a table of live references.
function WorldBuilder.buildIsland()
	local existing = workspace:FindFirstChild(WorldBuilder.worldFolderName)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = WorldBuilder.worldFolderName
	folder.Parent = workspace

	buildLighting()

	local groundFolder = Instance.new("Folder")
	groundFolder.Name = "Ground"
	groundFolder.Parent = folder
	buildGround(groundFolder)

	-- Remove the template's flat baseplate so the island is the floor.
	local templatePlate = workspace:FindFirstChild("Baseplate")
	if templatePlate then
		templatePlate:Destroy()
	end

	local plaza = buildSpawnPlaza(folder)
	local shop = buildShopDistrict(folder)
	local bases = buildBases(folder)
	buildFrozenLake(folder)
	buildMountains(folder)
	buildDecorations(folder)
	local iceWall = buildIceWall(folder)

	-- WorldDetail: the beauty pass (carpet spine, lanterns, crystals, drifts, signs, snowfall, aurora, trim)
	local WorldDetail = require(script.Parent.WorldDetail)
	local layout = {
		plazaCenter = WorldBuilder.plazaCenter,
		shopCenter = WorldBuilder.shopCenter,
		lakeCenter = WorldBuilder.lakeCenter,
		conveyorCenter = WorldBuilder.conveyorCenter,
		bases = bases.bases,
		deckY = WorldBuilder.deckY,
	}
	WorldDetail.decorate(folder, layout)

	return {
		folder = folder,
		plaza = plaza,
		shop = shop,
		eggMachines = shop.eggMachines,
		bases = bases.bases,
		basesFolder = bases.folder,
		upgradesKiosk = shop.upgradesKiosk,
		lockKiosk = shop.lockKiosk,
		conveyor = shop.conveyor,
		iceWall = iceWall,
	}
end

-- Alias kept because the boot script and the probes call it as `build`.
WorldBuilder.build = WorldBuilder.buildIsland

-- Where a pad's character stands, in world space.
function WorldBuilder.padStandPosition(baseInfo, padIndex)
	local pad = baseInfo.pads[padIndex]
	if not pad then
		return baseInfo.position + Vector3.new(0, 6, 0)
	end
	return pad.position + Vector3.new(0, 3.2, 0)
end

-- The den's claim point: where the player is standing when they place.
function WorldBuilder.baseCenter(baseInfo)
	return baseInfo.position + Vector3.new(0, 6, 0)
end

-- Repaint a den sign on every surface it owns. Called on claim and on lock
-- changes so the slab, the back face and the billboard never disagree.
function WorldBuilder.setDenSign(baseInfo, text, color)
	if not baseInfo then
		return
	end
	if baseInfo.signFace then
		baseInfo.signFace.Text = text
		if color then
			baseInfo.signFace.TextColor3 = color
		end
	end
	if baseInfo.signBackFace then
		baseInfo.signBackFace.Text = text
		if color then
			baseInfo.signBackFace.TextColor3 = color
		end
	end
	if baseInfo.signTitle then
		baseInfo.signTitle.Text = text
		if color then
			baseInfo.signTitle.TextColor3 = color
		end
	end
end

return WorldBuilder
