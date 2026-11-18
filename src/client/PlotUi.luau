--[[ PlotUi
	One job: the den panel. Shows all 16 sockets, what sits on each one, the pad
	unlock price, the Lock button and the collection ladder (how many of each
	rarity the den holds, out of how many exist).

	This panel is docked LEFT and is narrower than the rebirth panel that sits
	opposite it, so both can be open at once with the den still visible in the
	gap between them — which is exactly what the 4-progression capture needs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local CastConfig = require(Shared.CastConfig)
local RarityConfig = require(Shared.RarityConfig)
local UpgradesConfig = require(Shared.UpgradesConfig)

local PlotUi = {}

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

function PlotUi.new(gui, actions)
	local self = {}

	local frame = Instance.new("Frame")
	frame.Name = "DenPanel"
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, 14, 0.5, 0)
	frame.Size = UDim2.fromOffset(560, 660)
	frame.BackgroundColor3 = Color3.fromRGB(8, 16, 30)
	frame.BackgroundTransparency = 0.03
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 20)

	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(126, 255, 176)
	outline.Thickness = 5
	outline.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -100, 0, 48)
	title.Position = UDim2.fromOffset(16, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "MY DEN — 16 SOCKETS"
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(84, 38)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 19
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "CLOSE"
	close.Parent = frame
	corner(close, 10)
	close.MouseButton1Click:Connect(function()
		self.hide()
	end)

	-- -------------------------------------------------------- pad grid (4x4)
	local grid = Instance.new("Frame")
	grid.Name = "PadGrid"
	grid.Position = UDim2.fromOffset(16, 62)
	grid.Size = UDim2.fromOffset(528, 372)
	grid.BackgroundTransparency = 1
	grid.Parent = frame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(126, 87)
	gridLayout.CellPadding = UDim2.fromOffset(6, 6)
	gridLayout.Parent = grid

	self.padCards = {}

	for index = 1, UpgradesConfig.basePadCount do
		local card = Instance.new("Frame")
		card.Name = "Pad_" .. index
		card.BackgroundColor3 = Color3.fromRGB(18, 30, 50)
		card.BorderSizePixel = 0
		card.Parent = grid
		corner(card, 9)

		local ring = Instance.new("UIStroke")
		ring.Color = Color3.fromRGB(90, 104, 128)
		ring.Thickness = 3
		ring.Parent = card

		local number = Instance.new("TextLabel")
		number.Name = "Number"
		number.Size = UDim2.fromOffset(34, 16)
		number.Position = UDim2.fromOffset(5, 2)
		number.BackgroundTransparency = 1
		number.Font = Enum.Font.GothamBlack
		number.TextSize = 13
		number.TextColor3 = Color3.fromRGB(140, 160, 190)
		number.Text = "#" .. index
		number.Parent = card

		local name = Instance.new("TextLabel")
		name.Name = "CastName"
		name.Size = UDim2.new(1, -10, 0, 32)
		name.Position = UDim2.fromOffset(5, 18)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextWrapped = true
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.Text = "EMPTY"
		name.Parent = card

		local rarity = Instance.new("TextLabel")
		rarity.Name = "Rarity"
		rarity.Size = UDim2.new(1, -10, 0, 15)
		rarity.Position = UDim2.fromOffset(5, 51)
		rarity.BackgroundTransparency = 1
		rarity.Font = Enum.Font.GothamBlack
		rarity.TextSize = 12
		rarity.TextColor3 = Color3.fromRGB(180, 200, 224)
		rarity.Text = ""
		rarity.Parent = card

		local income = Instance.new("TextLabel")
		income.Name = "Income"
		income.Size = UDim2.new(1, -10, 0, 18)
		income.Position = UDim2.fromOffset(5, 66)
		income.BackgroundTransparency = 1
		income.Font = Enum.Font.FredokaOne
		income.TextSize = 15
		income.TextColor3 = Color3.fromRGB(126, 255, 176)
		income.Text = ""
		income.Parent = card

		self.padCards[index] = { card = card, ring = ring, name = name, rarity = rarity, income = income }
	end

	-- The two buy buttons, side by side under the grid.
	local buyPad = Instance.new("TextButton")
	buyPad.Name = "BuyPad"
	buyPad.Size = UDim2.fromOffset(258, 62)
	buyPad.Position = UDim2.fromOffset(16, 446)
	buyPad.BackgroundColor3 = Color3.fromRGB(36, 84, 56)
	buyPad.BorderSizePixel = 0
	buyPad.Font = Enum.Font.FredokaOne
	buyPad.TextSize = 19
	buyPad.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyPad.TextWrapped = true
	buyPad.Text = "BUY PAD 7  ·  $500"
	buyPad.Parent = frame
	corner(buyPad, 12)
	buyPad.MouseButton1Click:Connect(function()
		actions.buyPad()
	end)
	self.buyPad = buyPad

	local buyLock = Instance.new("TextButton")
	buyLock.Name = "BuyLock"
	buyLock.Size = UDim2.fromOffset(258, 62)
	buyLock.Position = UDim2.fromOffset(286, 446)
	buyLock.BackgroundColor3 = Color3.fromRGB(24, 58, 92)
	buyLock.BorderSizePixel = 0
	buyLock.Font = Enum.Font.FredokaOne
	buyLock.TextSize = 19
	buyLock.TextColor3 = Color3.fromRGB(190, 232, 255)
	buyLock.TextWrapped = true
	buyLock.Text = "BASE LOCK  ·  $300 · 60 s"
	buyLock.Parent = frame
	corner(buyLock, 12)
	buyLock.MouseButton1Click:Connect(function()
		actions.buyLock()
	end)
	self.buyLock = buyLock

	-- -------------------------------------------------------- collection ladder
	local collectionTitle = Instance.new("TextLabel")
	collectionTitle.Name = "CollectionTitle"
	collectionTitle.Size = UDim2.new(1, -32, 0, 28)
	collectionTitle.Position = UDim2.fromOffset(16, 516)
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.Font = Enum.Font.FredokaOne
	collectionTitle.TextSize = 22
	collectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	collectionTitle.Text = "COLLECTION LADDER"
	collectionTitle.Parent = frame

	local collection = Instance.new("Frame")
	collection.Name = "Collection"
	collection.Size = UDim2.new(1, -32, 0, 112)
	collection.Position = UDim2.fromOffset(16, 546)
	collection.BackgroundTransparency = 1
	collection.Parent = frame

	local collectionLayout = Instance.new("UIGridLayout")
	collectionLayout.CellSize = UDim2.fromOffset(250, 24)
	collectionLayout.CellPadding = UDim2.fromOffset(4, 2)
	collectionLayout.Parent = collection

	self.rarityRows = {}
	for _, rarityName in ipairs(RarityConfig.order) do
		local row = Instance.new("TextLabel")
		row.Name = "Rarity_" .. rarityName
		row.BackgroundColor3 = RarityConfig.colorOf(rarityName)
		row.BackgroundTransparency = 0.45
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBlack
		row.TextSize = 14
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = RarityConfig.textColorOf(rarityName)
		row.Text = string.upper(rarityName)
		row.Parent = collection
		corner(row, 7)

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.Parent = row

		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "Count"
		countLabel.Size = UDim2.new(0.55, 0, 1, 0)
		countLabel.Position = UDim2.new(0.45, 0, 0, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.GothamBlack
		countLabel.TextSize = 14
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		countLabel.Text = "0 / 0"
		countLabel.Parent = row

		self.rarityRows[rarityName] = { row = row, count = countLabel }
	end

	-- -------------------------------------------------------- behaviour

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

		local pads = snapshot.pads or {}
		local unlocked = snapshot.unlockedPads or 6

		for index, card in pairs(self.padCards) do
			local pad = pads[index]
			if pad then
				card.name.Text = pad.name
				card.name.TextColor3 = Color3.fromRGB(255, 255, 255)
				card.rarity.Text = string.upper(pad.rarity)
					.. (pad.mutation ~= "None" and (" · " .. string.upper(pad.mutation)) or "")
				card.rarity.TextColor3 = RarityConfig.colorOf(pad.rarity)
				card.income.Text = "$" .. self.shortNumber(pad.income or 0) .. "/s"
				card.ring.Color = RarityConfig.glowOf(pad.rarity)
				card.ring.Thickness = 4
				card.card.BackgroundColor3 = Color3.fromRGB(22, 42, 32)
			elseif index <= unlocked then
				card.name.Text = "EMPTY"
				card.name.TextColor3 = Color3.fromRGB(120, 140, 170)
				card.rarity.Text = "UNLOCKED"
				card.rarity.TextColor3 = Color3.fromRGB(120, 220, 255)
				card.income.Text = ""
				card.ring.Color = Color3.fromRGB(80, 160, 210)
				card.ring.Thickness = 3
				card.card.BackgroundColor3 = Color3.fromRGB(18, 32, 50)
			else
				card.name.Text = "LOCKED"
				card.name.TextColor3 = Color3.fromRGB(90, 102, 120)
				card.rarity.Text = ""
				card.income.Text = ""
				card.ring.Color = Color3.fromRGB(66, 74, 92)
				card.ring.Thickness = 2
				card.card.BackgroundColor3 = Color3.fromRGB(14, 20, 32)
			end
		end

		if snapshot.nextPadPrice then
			self.buyPad.Text = string.format("BUY PAD %d  ·  $%s", unlocked + 1, self.shortNumber(snapshot.nextPadPrice))
			self.buyPad.BackgroundColor3 = if (snapshot.cash or 0) >= snapshot.nextPadPrice
				then Color3.fromRGB(36, 84, 56)
				else Color3.fromRGB(48, 54, 68)
		else
			self.buyPad.Text = "ALL PADS OPEN"
			self.buyPad.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
		end

		if snapshot.locked then
			self.buyLock.Text = string.format("LOCKED  ·  %d s LEFT", snapshot.lockSecondsLeft or 0)
			self.buyLock.BackgroundColor3 = Color3.fromRGB(26, 92, 120)
		else
			self.buyLock.Text = "BASE LOCK  ·  $300 · 60 s"
			self.buyLock.BackgroundColor3 = Color3.fromRGB(24, 58, 92)
		end

		-- Collection ladder: how many of each rarity the den holds, out of the
		-- total that exists at that rarity in the cast.
		local owned = {}
		for _, pad in pairs(pads) do
			owned[pad.rarity] = (owned[pad.rarity] or 0) + 1
		end
		for _, rarityName in ipairs(RarityConfig.order) do
			local row = self.rarityRows[rarityName]
			if row then
				local count = owned[rarityName] or 0
				row.count.Text = string.format("%d owned / %d exist", count, CastConfig.countAt(rarityName))
				row.row.BackgroundTransparency = if count > 0 then 0.2 else 0.7
			end
		end
	end

	function self.shortNumber(value)
		local number = math.floor(value or 0)
		if number >= 1e9 then
			return string.format("%.2fB", number / 1e9)
		elseif number >= 1e6 then
			return string.format("%.2fM", number / 1e6)
		elseif number >= 1e4 then
			return string.format("%.1fK", number / 1e3)
		end
		return tostring(number)
	end

	self.frame = frame
	return self
end

return PlotUi
