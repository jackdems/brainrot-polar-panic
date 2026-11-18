--[[ Hud
	One job: the money readout. A big animated cash counter, the $/s rate, the
	rebirth multiplier, the lock badge, the carried strip and the hotbar buttons.
	Nothing here decides anything — it renders what the server pushed.

	Layout rule learned from the captures: the cash card lives top-LEFT under the
	Roblox menu strip and is deliberately large (72 px digits), because the cover
	thumbnail is scaled down and this number is what sells "you are getting rich".
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Hud = {}

local player = Players.LocalPlayer

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

local function stroke(parent, color, thickness)
	local outline = Instance.new("UIStroke")
	outline.Color = color
	outline.Thickness = thickness or 3
	outline.Parent = parent
	return outline
end

local function label(parent, name, size, position, textSize, color)
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextSize = textSize
	text.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	text.Text = ""
	text.Parent = parent
	return text
end

function Hud.new(gui)
	local self = {}

	-- ------------------------------------------------------------ cash card
	-- Big, top-left, clear of the Roblox menu buttons.
	local card = Instance.new("Frame")
	card.Name = "CashCard"
	card.AnchorPoint = Vector2.new(0, 0)
	card.Position = UDim2.new(0, 22, 0, 94)
	card.Size = UDim2.fromOffset(430, 164)
	card.BackgroundColor3 = Color3.fromRGB(6, 14, 26)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = gui
	corner(card, 18)
	stroke(card, Color3.fromRGB(126, 255, 176), 4)

	local cashLabel = label(card, "Cash", UDim2.new(1, -26, 0, 74), UDim2.fromOffset(16, 8), 66,
		Color3.fromRGB(126, 255, 176))
	cashLabel.Font = Enum.Font.FredokaOne
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextStrokeColor3 = Color3.fromRGB(4, 20, 10)
	cashLabel.TextStrokeTransparency = 0.4
	cashLabel.Text = "$100"

	local rateLabel = label(card, "Rate", UDim2.new(0.62, -18, 0, 40), UDim2.fromOffset(18, 88), 30,
		Color3.fromRGB(255, 236, 130))
	rateLabel.Font = Enum.Font.GothamBlack
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateLabel.Text = "$0 /s"

	local multiplierLabel = label(card, "Multiplier", UDim2.new(0.38, -14, 0, 40), UDim2.new(0.62, 6, 0, 88), 26,
		Color3.fromRGB(255, 176, 240))
	multiplierLabel.Font = Enum.Font.GothamBlack
	multiplierLabel.Text = "x1"

	local lockLabel = label(card, "Lock", UDim2.new(1, -26, 0, 30), UDim2.fromOffset(18, 130), 22,
		Color3.fromRGB(120, 220, 255))
	lockLabel.Font = Enum.Font.GothamBlack
	lockLabel.TextXAlignment = Enum.TextXAlignment.Left
	lockLabel.Text = ""

	-- ------------------------------------------------------------ carried strip
	local carriedCard = Instance.new("Frame")
	carriedCard.Name = "CarriedCard"
	carriedCard.AnchorPoint = Vector2.new(0.5, 0)
	carriedCard.Position = UDim2.new(0.5, 0, 0, 88)
	carriedCard.Size = UDim2.fromOffset(580, 70)
	carriedCard.BackgroundColor3 = Color3.fromRGB(40, 26, 8)
	carriedCard.BackgroundTransparency = 0.12
	carriedCard.BorderSizePixel = 0
	carriedCard.Visible = false
	carriedCard.Parent = gui
	corner(carriedCard, 14)
	stroke(carriedCard, Color3.fromRGB(255, 196, 46), 4)

	local carriedLabel = label(carriedCard, "Carried", UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4), 32,
		Color3.fromRGB(255, 236, 168))
	carriedLabel.Font = Enum.Font.GothamBlack
	carriedLabel.Text = "CARRYING"

	-- ------------------------------------------------------------ context hint
	local hint = Instance.new("TextLabel")
	hint.Name = "ContextHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -138)
	hint.Size = UDim2.fromOffset(820, 50)
	hint.BackgroundColor3 = Color3.fromRGB(6, 14, 26)
	hint.BackgroundTransparency = 0.15
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.GothamBlack
	hint.TextSize = 28
	hint.TextColor3 = Color3.fromRGB(255, 255, 255)
	hint.Text = ""
	hint.Parent = gui
	corner(hint, 12)
	stroke(hint, Color3.fromRGB(90, 140, 200), 2)

	-- ------------------------------------------------------------ hotbar
	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -24)
	hotbar.Size = UDim2.fromOffset(700, 96)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.Parent = hotbar

	self.buttons = {}

	local function addButton(name, text, keyHint, color, onClick)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(214, 88)
		button.BackgroundColor3 = color
		button.BorderSizePixel = 0
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 24
		button.TextColor3 = Color3.fromRGB(10, 14, 26)
		button.Text = text .. "\n[" .. keyHint .. "]"
		button.AutoButtonColor = true
		button.Parent = hotbar
		corner(button, 16)
		stroke(button, Color3.fromRGB(255, 255, 255), 3)
		button.MouseButton1Click:Connect(onClick)
		self.buttons[name] = button
		return button
	end

	addButton("ShopButton", "EGG SHOP", "1", Color3.fromRGB(126, 232, 255), function()
		if self.onShop then
			self.onShop()
		end
	end)
	addButton("DenButton", "MY DEN", "2", Color3.fromRGB(126, 255, 176), function()
		if self.onDen then
			self.onDen()
		end
	end)
	addButton("RebirthButton", "REBIRTH", "3", Color3.fromRGB(255, 196, 46), function()
		if self.onRebirth then
			self.onRebirth()
		end
	end)

	self.cash = 100
	self.shownCash = 100

	-- Roll the displayed number toward the real one every frame, so a tick reads
	-- as a counter spinning rather than a number being replaced.
	function self.rollTowards(target)
		self.rollTarget = target
		self.rollStart = self.shownCash
		self.rollAt = os.clock()
	end

	-- ------------------------------------------------------------ render

	function self.setSnapshot(snapshot)
		if not snapshot then
			return
		end

		local targetCash = snapshot.cash or 0
		self.cash = targetCash
		self.rollTowards(targetCash)

		local perSecond = snapshot.income or 0
		if (snapshot.eventMultiplier or 1) > 1 then
			rateLabel.Text = string.format("%s /s  x%d EVENT", self.formatNumber(perSecond), snapshot.eventMultiplier)
			rateLabel.TextColor3 = Color3.fromRGB(255, 214, 92)
		else
			rateLabel.Text = string.format("%s /s", self.formatNumber(perSecond))
			rateLabel.TextColor3 = Color3.fromRGB(255, 236, 130)
		end

		multiplierLabel.Text = "x" .. (snapshot.multiplier or 1)

		if snapshot.locked then
			lockLabel.Text = string.format("DEN LOCKED  %d s", snapshot.lockSecondsLeft or 0)
			lockLabel.TextColor3 = Color3.fromRGB(120, 220, 255)
		else
			lockLabel.Text = string.format("%d/%d PADS  ·  %d PLACED",
				snapshot.unlockedPads or 6, snapshot.maxPads or 16, snapshot.placedCount or 0)
			lockLabel.TextColor3 = Color3.fromRGB(150, 180, 210)
		end

		if snapshot.carried then
			carriedCard.Visible = true
			carriedLabel.Text = string.format("CARRYING  %s  ·  %s  ·  PRESS E AT YOUR DEN",
				string.upper(snapshot.carried.name), string.upper(snapshot.carried.mutation or "NONE"))
			carriedLabel.TextColor3 = Color3.fromRGB(255, 236, 168)
		else
			carriedCard.Visible = false
		end
	end

	function self.setHint(text, color)
		hint.Text = text or ""
		hint.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		hint.Visible = (text or "") ~= ""
	end

	function self.pulseCash()
		local original = cashLabel.TextColor3
		cashLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		TweenService:Create(cashLabel, TweenInfo.new(0.35), { TextColor3 = original }):Play()
	end

	function self.formatNumber(value)
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

	-- Cash text rides a RenderStepped so the counter rolls, not jumps.
	RunService.RenderStepped:Connect(function()
		if self.rollTarget then
			local elapsed = math.min(1, (os.clock() - (self.rollAt or 0)) / 0.28)
			self.shownCash = self.rollStart + (self.rollTarget - self.rollStart) * elapsed
			if elapsed >= 1 then
				self.shownCash = self.rollTarget
			end
		end
		cashLabel.Text = "$" .. self.formatNumber(self.shownCash)
	end)

	self.cashLabel = cashLabel
	self.rateLabel = rateLabel
	self.hintLabel = hint
	return self
end

return Hud
