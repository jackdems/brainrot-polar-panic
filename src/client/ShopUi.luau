--[[ ShopUi
	One job: the egg shop panel and the upgrade row. Big cards, prices you can read
	at screenshot scale, and a hatch button per egg that fires RequestHatch.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PolarShared")

local EggConfig = require(Shared.EggConfig)
local UpgradesConfig = require(Shared.UpgradesConfig)

local ShopUi = {}

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

local function pad(parent, top, bottom)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top or 12)
	padding.PaddingBottom = UDim.new(0, bottom or 12)
	padding.Parent = parent
	return padding
end

-- The odds line on an egg card: read at screenshot scale, so keep it compact.
local function oddsText(egg)
	local parts = {}
	for _, rarityName in ipairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }) do
		local weight = egg.weights[rarityName]
		if weight then
			table.insert(parts, string.format("%s %s%%", string.sub(rarityName, 1, 4), tostring(weight)))
		end
	end
	return table.concat(parts, "  ·  ")
end

function ShopUi.new(gui, fireHatch, fireUpgrade)
	local self = {}

	local frame = Instance.new("Frame")
	frame.Name = "ShopPanel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(1080, 620)
	frame.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	corner(frame, 22)

	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(126, 232, 255)
	outline.Thickness = 5
	outline.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 58)
	title.Position = UDim2.fromOffset(20, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 44
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "EGG SHOP — HATCH YOUR NEXT BRAINROT"
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

	-- Four egg cards in a row, then a narrower upgrade strip underneath.
	local grid = Instance.new("Frame")
	grid.Name = "EggGrid"
	grid.Size = UDim2.new(1, -40, 0, 380)
	grid.Position = UDim2.fromOffset(20, 76)
	grid.BackgroundTransparency = 1
	grid.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 16)
	layout.Parent = grid

	self.eggButtons = {}
	self.eggCards = {}

	for _, egg in ipairs(EggConfig.eggs) do
		local card = Instance.new("Frame")
		card.Name = "Egg_" .. egg.id
		card.Size = UDim2.fromOffset(248, 372)
		card.BackgroundColor3 = Color3.fromRGB(18, 30, 50)
		card.BorderSizePixel = 0
		card.Parent = grid
		corner(card, 16)

		local ring = Instance.new("UIStroke")
		ring.Color = egg.color
		ring.Thickness = 5
		ring.Parent = card

		-- The egg itself: a drawn disc so the card reads without a 3D render.
		local orb = Instance.new("Frame")
		orb.Name = "Orb"
		orb.AnchorPoint = Vector2.new(0.5, 0)
		orb.Position = UDim2.new(0.5, 0, 0, 18)
		orb.Size = UDim2.fromOffset(120, 120)
		orb.BackgroundColor3 = egg.color
		orb.BorderSizePixel = 0
		orb.Parent = card
		corner(orb, 60)

		local orbShine = Instance.new("Frame")
		orbShine.Name = "Shine"
		orbShine.Size = UDim2.fromOffset(34, 34)
		orbShine.Position = UDim2.fromOffset(20, 20)
		orbShine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		orbShine.BackgroundTransparency = 0.35
		orbShine.BorderSizePixel = 0
		orbShine.Parent = orb
		corner(orbShine, 22)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "EggName"
		nameLabel.Size = UDim2.new(1, -16, 0, 40)
		nameLabel.Position = UDim2.fromOffset(8, 146)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextSize = 26
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = egg.accent
		nameLabel.Text = egg.name
		nameLabel.Parent = card

		local priceLabel = Instance.new("TextLabel")
		priceLabel.Name = "Price"
		priceLabel.Size = UDim2.new(1, -16, 0, 46)
		priceLabel.Position = UDim2.fromOffset(8, 186)
		priceLabel.BackgroundTransparency = 1
		priceLabel.Font = Enum.Font.FredokaOne
		priceLabel.TextSize = 42
		priceLabel.TextScaled = true
		priceLabel.TextColor3 = Color3.fromRGB(126, 255, 176)
		priceLabel.Text = "$" .. egg.price
		priceLabel.Parent = card

		local oddsLabel = Instance.new("TextLabel")
		oddsLabel.Name = "Odds"
		oddsLabel.Size = UDim2.new(1, -16, 0, 92)
		oddsLabel.Position = UDim2.fromOffset(8, 232)
		oddsLabel.BackgroundTransparency = 1
		oddsLabel.Font = Enum.Font.GothamMedium
		oddsLabel.TextSize = 15
		oddsLabel.TextWrapped = true
		oddsLabel.TextColor3 = Color3.fromRGB(196, 214, 236)
		-- The odds line is built by the module-level oddsText helper.
		oddsLabel.Text = oddsText(egg)
		oddsLabel.Parent = card

		local hatchButton = Instance.new("TextButton")
		hatchButton.Name = "Hatch"
		hatchButton.Size = UDim2.new(1, -20, 0, 64)
		hatchButton.AnchorPoint = Vector2.new(0.5, 1)
		hatchButton.Position = UDim2.new(0.5, 0, 1, -12)
		hatchButton.BackgroundColor3 = egg.color
		hatchButton.BorderSizePixel = 0
		hatchButton.Font = Enum.Font.FredokaOne
		hatchButton.TextSize = 26
		hatchButton.TextColor3 = Color3.fromRGB(10, 16, 28)
		hatchButton.Text = "HATCH"
		hatchButton.Parent = card
		corner(hatchButton, 12)

		local buttonRing = Instance.new("UIStroke")
		buttonRing.Color = Color3.fromRGB(255, 255, 255)
		buttonRing.Thickness = 3
		buttonRing.Parent = hatchButton

		hatchButton.MouseButton1Click:Connect(function()
			fireHatch(egg.id)
			TweenService:Create(hatchButton, TweenInfo.new(0.12), { Size = UDim2.new(1, -32, 0, 54) }):Play()
			task.delay(0.14, function()
				TweenService:Create(hatchButton, TweenInfo.new(0.12), { Size = UDim2.new(1, -20, 0, 64) }):Play()
			end)
		end)

		self.eggButtons[egg.id] = hatchButton
		self.eggCards[egg.id] = card
	end

	-- Upgrades strip.
	local upgradeRow = Instance.new("Frame")
	upgradeRow.Name = "Upgrades"
	upgradeRow.Size = UDim2.new(1, -40, 0, 108)
	upgradeRow.Position = UDim2.fromOffset(20, 468)
	upgradeRow.BackgroundColor3 = Color3.fromRGB(16, 26, 44)
	upgradeRow.BorderSizePixel = 0
	upgradeRow.Parent = frame
	corner(upgradeRow, 14)

	local upgradeLayout = Instance.new("UIListLayout")
	upgradeLayout.FillDirection = Enum.FillDirection.Horizontal
	upgradeLayout.Padding = UDim.new(0, 14)
	upgradeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	upgradeLayout.Parent = upgradeRow
	pad(upgradeRow, 8, 8)
	local upgradePad = Instance.new("UIPadding")
	upgradePad.PaddingLeft = UDim.new(0, 14)
	upgradePad.Parent = upgradeRow

	self.upgradeLabels = {}

	for _, upgrade in ipairs(UpgradesConfig.upgrades) do
		local button = Instance.new("TextButton")
		button.Name = "Upgrade_" .. upgrade.id
		button.Size = UDim2.fromOffset(320, 84)
		button.BackgroundColor3 = Color3.fromRGB(28, 44, 70)
		button.BorderSizePixel = 0
		button.Font = Enum.Font.GothamBlack
		button.TextSize = 19
		button.TextWrapped = true
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = string.format("%s  Lv 0/%d  ·  $%d\n%s",
			string.upper(upgrade.name), upgrade.maxLevel, upgrade.price, upgrade.blurb)
		button.Parent = upgradeRow
		corner(button, 12)
		button.MouseButton1Click:Connect(function()
			fireUpgrade(upgrade.id)
		end)
		self.upgradeLabels[upgrade.id] = button
	end

	local lockButton = Instance.new("TextButton")
	lockButton.Name = "BuyLock"
	lockButton.Size = UDim2.fromOffset(250, 84)
	lockButton.BackgroundColor3 = Color3.fromRGB(28, 62, 96)
	lockButton.BorderSizePixel = 0
	lockButton.Font = Enum.Font.GothamBlack
	lockButton.TextSize = 19
	lockButton.TextWrapped = true
	lockButton.TextColor3 = Color3.fromRGB(190, 232, 255)
	lockButton.Text = string.format("BASE LOCK  ·  $%d\n60 s of shield. Blocks thieves.", UpgradesConfig.lockPrice)
	lockButton.Parent = upgradeRow
	corner(lockButton, 12)
	lockButton.MouseButton1Click:Connect(function()
		fireUpgrade("Lock")
	end)

	-- ------------------------------------------------------------ behaviour

	function self.show()
		frame.Visible = true
		frame.Size = UDim2.fromOffset(940, 540)
		TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(1080, 620) }):Play()
	end

	function self.hide()
		frame.Visible = false
	end

	function self.toggle()
		if frame.Visible then
			self.hide()
		else
			self.show()
		end
	end

	function self.isOpen()
		return frame.Visible
	end

	function self.render(snapshot)
		if not snapshot then
			return
		end
		local cash = snapshot.cash or 0
		for _, egg in ipairs(EggConfig.eggs) do
			local button = self.eggButtons[egg.id]
			local card = self.eggCards[egg.id]
			if button and card then
				local unlocked = (snapshot.rebirths or 0) >= (egg.requiresRebirth or 0)
				local affordable = cash >= egg.price
				if not unlocked then
					button.Text = "LOCKED — REBIRTH 1"
					button.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
				elseif affordable then
					button.Text = "HATCH  $" .. egg.price
					button.BackgroundColor3 = egg.color
				else
					button.Text = "NEED $" .. egg.price
					button.BackgroundColor3 = Color3.fromRGB(86, 96, 116)
				end
				card.BackgroundTransparency = if affordable or not unlocked then 0 else 0.35
			end
		end

		local levels = snapshot.upgrades or {}
		for _, upgrade in ipairs(UpgradesConfig.upgrades) do
			local button = self.upgradeLabels[upgrade.id]
			local level = levels[upgrade.id] or 0
			if button then
				local price = UpgradesConfig.nextPrice(upgrade.id, level)
				if not price then
					button.Text = string.format("%s  Lv %d/%d  ·  MAXED\n%s",
						string.upper(upgrade.name), level, upgrade.maxLevel, upgrade.blurb)
					button.BackgroundColor3 = Color3.fromRGB(44, 84, 56)
				else
					button.Text = string.format("%s  Lv %d/%d  ·  $%d\n%s",
						string.upper(upgrade.name), level, upgrade.maxLevel, price, upgrade.blurb)
					button.BackgroundColor3 = if cash >= price then Color3.fromRGB(28, 60, 92) else Color3.fromRGB(40, 44, 58)
				end
			end
		end
	end

	self.frame = frame
	return self
end

return ShopUi
