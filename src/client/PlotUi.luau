--[[ PlotUi
	One job: the den panel. Shows all 16 sockets, what sits on each one, the pad
	unlock price, the Lock button and the collection ladder (which rarities the
	player has actually placed). This is the panel the progression screenshot wants.
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
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(1060, 640)
	frame.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 22)

	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(126, 255, 176)
	outline.Thickness = 5
	outline.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0.6, -20, 0, 54)
	title.Position = UDim2.fromOffset(20, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "MY DEN — 16 SOCKETS"
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.fromOffset(120, 46)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 14)
	close.BackgroundColor3 = Color3.fromRGB(220, 70, 70)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBlack
	close.TextSize = 22
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
	grid.Position = UDim2.fromOffset(20, 76)
	grid.Size = UDim2.fromOffset(600, 540)
	grid.BackgroundTransparency = 1
	grid.Parent = frame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(144, 126)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.Parent = grid

	self.padCards = {}

	for index = 1, UpgradesConfig.basePadCount do
		local card = Instance.new("Frame")
		card.Name = "Pad_" .. index
		card.BackgroundColor3 = Color3.fromRGB(20, 32, 52)
		card.BorderSizePixel = 0
		card.Parent = grid
		corner(card, 10)

		local ring = Instance.new("UIStroke")
		ring.Color = Color3.fromRGB(90, 104, 128)
		ring.Thickness = 3
		ring.Parent = card

		local number = Instance.new("TextLabel")
		number.Name = "Number"
		number.Size = UDim2.fromOffset(40, 24)
		number.Position = UDim2.fromOffset(6, 4)
		number.BackgroundTransparency = 1
		number.Font = Enum.Font.GothamBlack
		number.TextSize = 18
		number.TextColor3 = Color3.fromRGB(150, 170, 200)
		number.Text = "#" .. index
		number.Parent = card

		local name = Instance.new("TextLabel")
		name.Name = "CastName"
		name.Size = UDim2.new(1, -12, 0, 40)
		name.Position = UDim2.fromOffset(6, 26)
		name.BackgroundTransparency = 1
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextWrapped = true
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.Text = "EMPTY"
		name.Parent = card

		local rarity = Instance.new("TextLabel")
		rarity.Name = "Rarity"
		rarity.Size = UDim2.new(1, -12, 0, 22)
		rarity.Position = UDim2.fromOffset(6, 68)
		rarity.BackgroundTransparency = 1
		rarity.Font = Enum.Font.GothamBlack
		rarity.TextSize = 16
		rarity.TextColor3 = Color3.fromRGB(180, 200, 224)
		rarity.Text = ""
		rarity.Parent = card

		local income = Instance.new("TextLabel")
		income.Name = "Income"
		income.Size = UDim2.new(1, -12, 0, 28)
		income.Position = UDim2.fromOffset(6, 92)
		income.BackgroundTransparency = 1
		income.Font = Enum.Font.FredokaOne
		income.TextSize = 20
		income.TextColor3 = Color3.fromRGB(126, 255, 176)
		income.Text = ""
		income.Parent = card

		self.padCards[index] = { card = card, ring = ring, name = name, rarity = rarity, income = income }
	end

	-- -------------------------------------------------------- right column
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.Position = UDim2.fromOffset(640, 76)
	side.Size = UDim2.fromOffset(400, 540)
	side.BackgroundTransparency = 1
	side.Parent = frame

	local buyPad = Instance.new("TextButton")
	buyPad.Name = "BuyPad"
	buyPad.Size = UDim2.new(1, 0, 0, 84)
	buyPad.BackgroundColor3 = Color3.fromRGB(36, 84, 56)
	buyPad.BorderSizePixel = 0
	buyPad.Font = Enum.Font.FredokaOne
	buyPad.TextSize = 24
	buyPad.TextColor3 = Color3.fromRGB(255, 255, 255)
	buyPad.TextWrapped = true
	buyPad.Text = "BUY PAD 7  ·  $500"
	buyPad.Parent = side
	corner(buyPad, 14)
	buyPad.MouseButton1Click:Connect(function()
		actions.buyPad()
	end)
	self.buyPad = buyPad

	local buyLock = Instance.new("TextButton")
	buyLock.Name = "BuyLock"
	buyLock.Size = UDim2.new(1, 0, 0, 84)
	buyLock.Position = UDim2.fromOffset(0, 96)
	buyLock.BackgroundColor3 = Color3.fromRGB(28, 62, 96)
	buyLock.BorderSizePixel = 0
	buyLock.Font = Enum.Font.FredokaOne
	buyLock.TextSize = 24
	buyLock.TextColor3 = Color3.fromRGB(190, 232, 255)
	buyLock.TextWrapped = true
	buyLock.Text = "BASE LOCK  ·  $300  ·  60 s"
	buyLock.Parent = side
	corner(buyLock, 14)
	buyLock.MouseButton1Click:Connect(function()
		actions.buyLock()
	end)
	self.buyLock = buyLock

	local pickup = Instance.new("TextButton")
	pickup.Name = "Pickup"
	pickup.Size = UDim2.new(1, 0, 0, 70)
	pickup.Position = UDim2.fromOffset(0, 192)
	pickup.BackgroundColor3 = Color3.fromRGB(84, 60, 24)
	pickup.BorderSizePixel = 0
	pickup.Font = Enum.Font.GothamBlack
	pickup.TextSize = 20
	pickup.TextColor3 = Color3.fromRGB(255, 236, 168)
	pickup.Text = "PICK UP LAST PLACED"
	pickup.Parent = side
	corner(pickup, 12)
	pickup.MouseButton1Click:Connect(function()
		actions.pickup()
	end)

	local collectionTitle = Instance.new("TextLabel")
	collectionTitle.Name = "CollectionTitle"
	collectionTitle.Size = UDim2.new(1, 0, 0, 34)
	collectionTitle.Position = UDim2.fromOffset(0, 276)
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.Font = Enum.Font.FredokaOne
	collectionTitle.TextSize = 26
	collectionTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	collectionTitle.TextXAlignment = Enum.TextXAlignment.Left
	collectionTitle.Text = "COLLECTION LADDER"
	collectionTitle.Parent = side

	local collection = Instance.new("Frame")
	collection.Name = "Collection"
	collection.Size = UDim2.new(1, 0, 0, 230)
	collection.Position = UDim2.fromOffset(0, 316)
	collection.BackgroundTransparency = 1
	collection.Parent = side

	local collectionLayout = Instance.new("UIListLayout")
	collectionLayout.Padding = UDim.new(0, 4)
	collectionLayout.Parent = collection

	self.rarityRows = {}
	for _, rarityName in ipairs(RarityConfig.order) do
		local row = Instance.new("Frame")
		row.Name = "Rarity_" .. rarityName
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundColor3 = RarityConfig.colorOf(rarityName)
		row.BackgroundTransparency = 0.55
		row.BorderSizePixel = 0
		row.Parent = collection
		corner(row, 8)

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(0.55, -8, 1, 0)
		rarityLabel.Position = UDim2.fromOffset(8, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Font = Enum.Font.GothamBlack
		rarityLabel.TextSize = 17
		rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
		rarityLabel.TextColor3 = RarityConfig.textColorOf(rarityName)
		rarityLabel.Text = string.upper(rarityName)
		rarityLabel.Parent = row

		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.new(0.45, -8, 1, 0)
		countLabel.Position = UDim2.new(0.55, 0, 0, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = Enum.Font.GothamBlack
		countLabel.TextSize = 17
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
				card.rarity.Text = string.upper(pad.rarity) .. (pad.mutation ~= "None" and (" · " .. string.upper(pad.mutation)) or "")
				card.rarity.TextColor3 = RarityConfig.colorOf(pad.rarity)
				card.income.Text = "$" .. self.shortNumber(pad.income or 0) .. "/s"
				card.ring.Color = RarityConfig.colorOf(pad.rarity)
				card.ring.Thickness = 4
				card.card.BackgroundColor3 = Color3.fromRGB(24, 44, 34)
			elseif index <= unlocked then
				card.name.Text = "EMPTY"
				card.name.TextColor3 = Color3.fromRGB(120, 140, 170)
				card.rarity.Text = "UNLOCKED"
				card.rarity.TextColor3 = Color3.fromRGB(120, 220, 255)
				card.income.Text = ""
				card.ring.Color = Color3.fromRGB(80, 160, 210)
				card.ring.Thickness = 3
				card.card.BackgroundColor3 = Color3.fromRGB(20, 34, 52)
			else
				card.name.Text = "LOCKED"
				card.name.TextColor3 = Color3.fromRGB(96, 108, 128)
				card.rarity.Text = ""
				card.income.Text = ""
				card.ring.Color = Color3.fromRGB(70, 78, 96)
				card.ring.Thickness = 2
				card.card.BackgroundColor3 = Color3.fromRGB(16, 22, 34)
			end
		end

		if snapshot.nextPadPrice then
			self.buyPad.Text = string.format("BUY PAD %d  ·  $%s", unlocked + 1, self.shortNumber(snapshot.nextPadPrice))
			self.buyPad.BackgroundColor3 = if (snapshot.cash or 0) >= snapshot.nextPadPrice
				then Color3.fromRGB(36, 84, 56) else Color3.fromRGB(48, 54, 68)
		else
			self.buyPad.Text = "ALL PADS OPEN"
			self.buyPad.BackgroundColor3 = Color3.fromRGB(48, 54, 68)
		end

		if snapshot.locked then
			self.buyLock.Text = string.format("LOCKED  ·  %d s LEFT", snapshot.lockSecondsLeft or 0)
			self.buyLock.BackgroundColor3 = Color3.fromRGB(28, 92, 120)
		else
			self.buyLock.Text = "BASE LOCK  ·  $300  ·  60 s"
			self.buyLock.BackgroundColor3 = Color3.fromRGB(28, 62, 96)
		end

		-- Collection ladder: how many of each rarity the den holds, out of the
		-- total that exists at that rarity.
		local owned = {}
		for _, pad in pairs(pads) do
			owned[pad.rarity] = (owned[pad.rarity] or 0) + 1
		end
		for _, rarityName in ipairs(RarityConfig.order) do
			local total = 0
			for _, entry in ipairs(CastConfig.cast) do
				if entry.rarity == rarityName then
					total += 1
				end
			end
			local row = self.rarityRows[rarityName]
			if row then
				local count = owned[rarityName] or 0
				row.count.Text = string.format("%d owned / %d exist", count, total)
				row.row.BackgroundTransparency = if count > 0 then 0.25 else 0.72
			end
		end
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

return PlotUi
