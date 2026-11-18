--[[ Hud
	One job: the money readout. A compact pill in the BOTTOM-LEFT corner (cash + $/s + pads line),
	a vertical rail of SMALL square buttons down the LEFT edge (Shop, Rebirth, My Den),
	and a slim centered carrying banner near the top. All together <15% HUD coverage.

	Layout rule (from Steal a Brainrot reference): the world dominates every frame;
	HUD elements are frost-blue panels with white text and rarity accents.
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
	outline.Thickness = thickness or 2
	outline.Parent = parent
	return outline
end

local function gradient(parent, topColor, bottomColor)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, bottomColor),
	})
	grad.Rotation = 90
	grad.Parent = parent
	return grad
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

	-- ------------------------------------------------------------ CASH PILL (bottom-left)
	local cashPill = Instance.new("Frame")
	cashPill.Name = "CashPill"
	cashPill.AnchorPoint = Vector2.new(0, 1)
	cashPill.Position = UDim2.new(0, 14, 1, -14)
	cashPill.Size = UDim2.fromOffset(260, 72)
	cashPill.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
	cashPill.BackgroundTransparency = 0.08
	cashPill.BorderSizePixel = 0
	cashPill.Parent = gui
	corner(cashPill, 14)
	stroke(cashPill, Color3.fromRGB(126, 255, 176), 2)
	gradient(cashPill, Color3.fromRGB(18, 30, 52), Color3.fromRGB(8, 16, 32))

	local cashLabel = label(cashPill, "Cash", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(12, 2), 30,
		Color3.fromRGB(126, 255, 176))
	cashLabel.TextXAlignment = Enum.TextXAlignment.Left
	cashLabel.TextStrokeColor3 = Color3.fromRGB(4, 20, 10)
	cashLabel.TextStrokeTransparency = 0.4
	cashLabel.Text = "$100"

	local rateLabel = label(cashPill, "Rate", UDim2.new(0.55, -12, 0, 22), UDim2.fromOffset(12, 38), 16,
		Color3.fromRGB(255, 236, 130))
	rateLabel.TextXAlignment = Enum.TextXAlignment.Left
	rateLabel.Text = "$0/s"

	local padsLabel = label(cashPill, "Pads", UDim2.new(0.45, -12, 0, 22), UDim2.new(0.55, 6, 0, 38), 16,
		Color3.fromRGB(150, 180, 210))
	padsLabel.TextXAlignment = Enum.TextXAlignment.Right
	padsLabel.Text = "6/16 · 0 PLACED"

	-- ------------------------------------------------------------ LEFT BUTTON RAIL
	local buttonRail = Instance.new("Frame")
	buttonRail.Name = "ButtonRail"
	buttonRail.AnchorPoint = Vector2.new(0, 0.5)
	buttonRail.Position = UDim2.new(0, 14, 0.5, -80)
	buttonRail.Size = UDim2.fromOffset(56, 280)
	buttonRail.BackgroundTransparency = 1
	buttonRail.Parent = gui

	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLayout.Padding = UDim.new(0, 10)
	railLayout.Parent = buttonRail

	self.buttons = {}

	local function addButton(name, text, iconColor, onClick)
		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = UDim2.fromOffset(56, 56)
		button.BackgroundColor3 = Color3.fromRGB(14, 24, 44)
		button.BackgroundTransparency = 0.08
		button.BorderSizePixel = 0
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 18
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.Text = text
		button.AutoButtonColor = false
		button.Parent = buttonRail
		corner(button, 12)
		stroke(button, iconColor, 2)

		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 36, 60)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 18, 36)),
		})
		grad.Rotation = 90
		grad.Parent = button

		button.MouseEnter:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0, Size = UDim2.fromOffset(62, 62) }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(0.15), { BackgroundTransparency = 0.08, Size = UDim2.fromOffset(56, 56) }):Play()
		end)
		button.MouseButton1Click:Connect(onClick)

		self.buttons[name] = button
		return button
	end

	addButton("ShopButton", "EGGS", Color3.fromRGB(126, 232, 255), function()
		if self.onShop then self.onShop() end
	end)
	addButton("RebirthButton", "REBIRTH", Color3.fromRGB(255, 196, 46), function()
		if self.onRebirth then self.onRebirth() end
	end)
	addButton("DenButton", "DEN", Color3.fromRGB(126, 255, 176), function()
		if self.onDen then self.onDen() end
	end)

	-- ------------------------------------------------------------ CARRIED BANNER (slim, centered, near top)
	local carriedCard = Instance.new("Frame")
	carriedCard.Name = "CarriedCard"
	carriedCard.AnchorPoint = Vector2.new(0.5, 0)
	carriedCard.Position = UDim2.new(0.5, 0, 0, 90)
	carriedCard.Size = UDim2.fromOffset(520, 48)
	carriedCard.BackgroundColor3 = Color3.fromRGB(40, 26, 8)
	carriedCard.BackgroundTransparency = 0.1
	carriedCard.BorderSizePixel = 0
	carriedCard.Visible = false
	carriedCard.Parent = gui
	corner(carriedCard, 12)
	stroke(carriedCard, Color3.fromRGB(255, 196, 46), 2)
	gradient(carriedCard, Color3.fromRGB(60, 40, 16), Color3.fromRGB(30, 20, 10))

	local carriedLabel = label(carriedCard, "Carried", UDim2.new(1, -20, 1, -8), UDim2.fromOffset(10, 4), 22,
		Color3.fromRGB(255, 236, 168))
	carriedLabel.Font = Enum.Font.GothamBlack
	carriedLabel.TextXAlignment = Enum.TextXAlignment.Center
	carriedLabel.Text = "CARRYING"

	-- ------------------------------------------------------------ CONTEXT HINT (bottom center, slim)
	local hint = Instance.new("TextLabel")
	hint.Name = "ContextHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -90)
	hint.Size = UDim2.fromOffset(600, 40)
	hint.BackgroundColor3 = Color3.fromRGB(8, 16, 32)
	hint.BackgroundTransparency = 0.12
	hint.BorderSizePixel = 0
	hint.Font = Enum.Font.GothamBlack
	hint.TextSize = 20
	hint.TextColor3 = Color3.fromRGB(255, 255, 255)
	hint.Text = ""
	hint.Parent = gui
	corner(hint, 10)
	stroke(hint, Color3.fromRGB(90, 140, 200), 2)

	-- ------------------------------------------------------------ RENDER
	self.cash = 100
	self.shownCash = 100

	function self.rollTowards(target)
		self.rollTarget = target
		self.rollStart = self.shownCash
		self.rollAt = os.clock()
	end

	function self.setSnapshot(snapshot)
		if not snapshot then return end

		local targetCash = snapshot.cash or 0
		self.cash = targetCash
		self.rollTowards(targetCash)

		local perSecond = snapshot.income or 0
		if (snapshot.eventMultiplier or 1) > 1 then
			rateLabel.Text = string.format("%s/s  x%d EVENT", self.formatNumber(perSecond), snapshot.eventMultiplier)
			rateLabel.TextColor3 = Color3.fromRGB(255, 214, 92)
		else
			rateLabel.Text = string.format("%s/s", self.formatNumber(perSecond))
			rateLabel.TextColor3 = Color3.fromRGB(255, 236, 130)
		end

		padsLabel.Text = string.format("%d/%d PADS  ·  %d PLACED",
			snapshot.unlockedPads or 6, snapshot.maxPads or 16, snapshot.placedCount or 0)

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
