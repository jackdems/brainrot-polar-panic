--[[ RebirthUi
	One job: the rebirth panel. The current multiplier, the live income, the next
	threshold, the pad you gain, the Galaxy Egg unlock, and the button that fires
	RequestRebirth. This is the panel the progression screenshot wants.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local RebirthConfig = require(Shared.RebirthConfig)
local CastConfig = require(Shared.CastConfig)

local RebirthUi = {}

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

function RebirthUi.new(gui, actions)
	local self = {}

	local frame = Instance.new("Frame")
	frame.Name = "RebirthPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(880, 560)
	frame.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
	frame.BackgroundTransparency = 0.03
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 24)

	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(255, 196, 46)
	outline.Thickness = 5
	outline.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 62)
	title.Position = UDim2.fromOffset(20, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 46
	title.TextColor3 = Color3.fromRGB(255, 214, 92)
	title.Text = "REBIRTH — RESET EVERYTHING, KEEP THE POWER"
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(110, 42)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 20
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "CLOSE"
	close.Parent = frame
	corner(close, 10)
	close.MouseButton1Click:Connect(function()
		self.hide()
	end)

	-- Three stat tiles along the top.
	local function statTile(name, offsetX, caption, accent)
		local tile = Instance.new("Frame")
		tile.Name = name
		tile.Position = UDim2.fromOffset(24 + offsetX, 84)
		tile.Size = UDim2.fromOffset(268, 112)
		tile.BackgroundColor3 = Color3.fromRGB(24, 20, 46)
		tile.BorderSizePixel = 0
		tile.Parent = frame
		corner(tile, 14)

		local ring = Instance.new("UIStroke")
		ring.Color = accent
		ring.Thickness = 3
		ring.Parent = tile

		local captionLabel = Instance.new("TextLabel")
		captionLabel.Size = UDim2.new(1, -16, 0, 26)
		captionLabel.Position = UDim2.fromOffset(8, 6)
		captionLabel.BackgroundTransparency = 1
		captionLabel.Font = Enum.Font.GothamBlack
		captionLabel.TextSize = 17
		captionLabel.TextColor3 = Color3.fromRGB(180, 190, 216)
		captionLabel.Text = caption
		captionLabel.Parent = tile

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.Size = UDim2.new(1, -16, 0, 66)
		value.Position = UDim2.fromOffset(8, 34)
		value.BackgroundTransparency = 1
		value.Font = Enum.Font.FredokaOne
		value.TextSize = 44
		value.TextColor3 = accent
		value.Text = "—"
		value.Parent = tile

		return tile, value
	end

	local _, currentValue = statTile("CurrentTile", 0, "CURRENT MULTIPLIER", Color3.fromRGB(255, 214, 92))
	local _, nextValue = statTile("NextTile", 292, "AFTER THIS REBIRTH", Color3.fromRGB(126, 255, 176))
	local _, costValue = statTile("CostTile", 584, "REBIRTH COST", Color3.fromRGB(255, 176, 240))

	-- The ladder strip: five pips, one per rebirth.
	local ladder = Instance.new("Frame")
	ladder.Name = "Ladder"
	ladder.Position = UDim2.fromOffset(24, 214)
	ladder.Size = UDim2.fromOffset(832, 48)
	ladder.BackgroundColor3 = Color3.fromRGB(20, 18, 40)
	ladder.BorderSizePixel = 0
	ladder.Parent = frame
	corner(ladder, 12)

	self.pips = {}
	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.Padding = UDim.new(0, 10)
	pipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pipLayout.Parent = ladder
	local pipPad = Instance.new("UIPadding")
	pipPad.PaddingLeft = UDim.new(0, 12)
	pipPad.Parent = ladder

	for index = 1, RebirthConfig.maxRebirths do
		local pip = Instance.new("TextLabel")
		pip.Name = "Pip_" .. index
		pip.Size = UDim2.fromOffset(150, 32)
		pip.BackgroundColor3 = Color3.fromRGB(44, 40, 66)
		pip.BorderSizePixel = 0
		pip.Font = Enum.Font.GothamBlack
		pip.TextSize = 17
		pip.TextColor3 = Color3.fromRGB(150, 160, 190)
		pip.Text = string.format("R%d  x%d", index, 2 ^ index)
		pip.Parent = ladder
		corner(pip, 8)
		self.pips[index] = pip
	end

	-- What a rebirth costs you and what it buys.
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(28, 274)
	body.Size = UDim2.fromOffset(824, 114)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 20
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = Color3.fromRGB(206, 214, 236)
	body.Text = ""
	body.Parent = frame
	self.body = body

	local rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "DoRebirth"
	rebirthButton.Size = UDim2.new(1, -48, 0, 92)
	rebirthButton.AnchorPoint = Vector2.new(0.5, 1)
	rebirthButton.Position = UDim2.new(0.5, 0, 1, -24)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 196, 46)
	rebirthButton.BorderSizePixel = 0
	rebirthButton.Font = Enum.Font.FredokaOne
	rebirthButton.TextSize = 34
	rebirthButton.TextColor3 = Color3.fromRGB(20, 12, 4)
	rebirthButton.Text = "REBIRTH NOW"
	rebirthButton.Parent = frame
	corner(rebirthButton, 16)
	rebirthButton.MouseButton1Click:Connect(function()
		actions.rebirth()
	end)
	self.rebirthButton = rebirthButton

	function self.show()
		frame.Visible = true
	end

	function self.hide()
		frame.Visible = false
	end

	function self.toggle()
		frame.Visible = not frame.Visible
	end

	function self.isOpen()
		return frame.Visible
	end

	function self.render(snapshot)
		if not snapshot then
			return
		end
		local rebirths = snapshot.rebirths or 0
		local multiplier = snapshot.multiplier or 1
		local nextMultiplier = 2 ^ math.min(rebirths + 1, RebirthConfig.maxRebirths)
		local cost = snapshot.nextRebirthCost or RebirthConfig.cost(rebirths)

		currentValue.Text = "x" .. multiplier
		costValue.Text = "$" .. self.shortNumber(cost)

		for index, pip in ipairs(self.pips) do
			if index <= rebirths then
				pip.BackgroundColor3 = Color3.fromRGB(255, 196, 46)
				pip.TextColor3 = Color3.fromRGB(28, 16, 4)
			elseif index == rebirths + 1 then
				pip.BackgroundColor3 = Color3.fromRGB(84, 68, 20)
				pip.TextColor3 = Color3.fromRGB(255, 226, 150)
			else
				pip.BackgroundColor3 = Color3.fromRGB(44, 40, 66)
				pip.TextColor3 = Color3.fromRGB(150, 160, 190)
			end
		end

		if not snapshot.rebirthAvailable then
			nextValue.Text = "MAXED"
			rebirthButton.Text = "MAXIMUM REBIRTH REACHED"
			rebirthButton.BackgroundColor3 = Color3.fromRGB(70, 74, 92)
			self.body.Text = "You have climbed the whole ladder. Nothing left to reset."
			return
		end

		nextValue.Text = "x" .. nextMultiplier

		local affordable = (snapshot.cash or 0) >= cost
		if affordable then
			rebirthButton.Text = string.format("REBIRTH FOR x%d  ·  $%s", nextMultiplier, self.shortNumber(cost))
			rebirthButton.BackgroundColor3 = Color3.fromRGB(255, 196, 46)
		else
			rebirthButton.Text = string.format("NEED $%s  ·  you have $%s", self.shortNumber(cost), self.shortNumber(snapshot.cash or 0))
			rebirthButton.BackgroundColor3 = Color3.fromRGB(74, 66, 40)
		end

		self.body.Text = string.format(
			"A rebirth wipes your cash and every character on your pads, then pays you back forever.\n" ..
			"· Income x%d becomes x%d on everything you own  ·  +1 pad socket (now %d unlocked)\n" ..
			"· The Galaxy Egg opens at rebirth 1: Epic 30%% · Legendary 45%% · Mythic 20%% · Secret 5%%\n" ..
			"· %d of %d rebirths used  ·  %d brainrots in the cast to chase",
			multiplier, nextMultiplier, (snapshot.unlockedPads or 6) + 1,
			rebirths, RebirthConfig.maxRebirths, CastConfig.count)
	end

	function self.shortNumber(value)
		local number = math.floor(value or 0)
		if number >= 1e9 then
			return string.format("%.1fB", number / 1e9)
		elseif number >= 1e6 then
			return string.format("%.1fM", number / 1e6)
		elseif number >= 1e4 then
			return string.format("%.1fK", number / 1e3)
		end
		return tostring(number)
	end

	self.frame = frame
	return self
end

return RebirthUi
