--[[ EffectsClient
	One job: the client-side show. Floating "+$N" popups over the cash card, the
	character pop-out on a hatch, the ice-block flash when frozen, sparkle bursts
	when something is placed, and a camera shake when the wall sweeps past.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local EffectsClient = {}

local player = Players.LocalPlayer

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

function EffectsClient.new(gui, camera)
	local self = {}
	self.camera = camera

	local popupLayer = Instance.new("Frame")
	popupLayer.Name = "PopupLayer"
	popupLayer.Size = UDim2.fromScale(1, 1)
	popupLayer.BackgroundTransparency = 1
	popupLayer.Parent = gui

	self.shakeStrength = 0
	self.shakeUntil = 0

	-- ------------------------------------------------------------ popups

	-- A "+$12" that rises off the cash card and fades.
	function self.floatMoney(amount)
		if amount < 0.5 then
			return
		end
		local text = Instance.new("TextLabel")
		text.Name = "MoneyPopup"
		text.AnchorPoint = Vector2.new(0, 0.5)
		text.Position = UDim2.new(0, 240 + math.random(-16, 16), 0, 132)
		text.Size = UDim2.fromOffset(240, 44)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextSize = 34
		text.TextColor3 = Color3.fromRGB(126, 255, 176)
		text.TextStrokeTransparency = 0.35
		text.TextStrokeColor3 = Color3.fromRGB(8, 24, 12)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = "+$" .. self.shortNumber(amount)
		text.Parent = popupLayer

		local target = UDim2.new(0, 240 + math.random(-30, 30), 0, 60)
		TweenService:Create(text, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1, function()
			if text and text.Parent then
				text:Destroy()
			end
		end)
	end

	-- The hatch result, right under the banner, in the rarity's colour.
	function self.announceHatch(payload)
		if not payload then
			return
		end
		local card = Instance.new("Frame")
		card.Name = "HatchResult"
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, 330)
		card.Size = UDim2.fromOffset(600, 96)
		card.BackgroundColor3 = Color3.fromRGB(10, 18, 34)
		card.BackgroundTransparency = 0.1
		card.BorderSizePixel = 0
		card.Parent = popupLayer
		corner(card, 16)

		local stroke = Instance.new("UIStroke")
		stroke.Color = payload.rarityColor or Color3.fromRGB(255, 255, 255)
		stroke.Thickness = 5
		stroke.Parent = card

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -20, 0, 44)
		title.Position = UDim2.fromOffset(10, 6)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.Text = string.upper(payload.name)
		title.Parent = card

		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, -20, 0, 36)
		sub.Position = UDim2.fromOffset(10, 52)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBlack
		sub.TextScaled = true
		sub.TextColor3 = payload.mutationColor or Color3.fromRGB(255, 236, 130)
		sub.Text = string.format("%s  ·  %s  ·  $%d/s", string.upper(payload.rarity),
			string.upper(payload.mutation or "NONE"), payload.moneyPerSecond or 0)
		sub.Parent = card

		card.Size = UDim2.fromOffset(300, 50)
		TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(600, 96),
		}):Play()

		task.delay(3, function()
			TweenService:Create(card, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(title, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(sub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.5)
			if card and card.Parent then
				card:Destroy()
			end
		end)
	end

	-- ------------------------------------------------------------ 3D sparkles

	function self.burst(position, color, count)
		if not position then
			return
		end
		local anchor = Instance.new("Part")
		anchor.Name = "BurstAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = position
		anchor.Parent = workspace

		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 236, 130))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(0.5, 1)
		emitter.Speed = NumberRange.new(16, 26)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 1
		emitter.Rate = 0
		emitter.Parent = anchor
		emitter:Emit(count or 40)

		task.delay(1.4, function()
			if anchor and anchor.Parent then
				anchor:Destroy()
			end
		end)
	end

	-- ------------------------------------------------------------ camera shake

	function self.shake(strength, seconds)
		self.shakeStrength = math.max(self.shakeStrength, strength or 0.6)
		self.shakeUntil = math.max(self.shakeUntil, os.clock() + (seconds or 0.6))
	end

	RunService.RenderStepped:Connect(function()
		local activeCamera = self.camera or workspace.CurrentCamera
		if not activeCamera then
			return
		end
		if os.clock() < self.shakeUntil and self.shakeStrength > 0 then
			local s = self.shakeStrength
			activeCamera.CFrame = activeCamera.CFrame * CFrame.new(
				(math.random() - 0.5) * s,
				(math.random() - 0.5) * s,
				(math.random() - 0.5) * s
			)
		else
			self.shakeStrength = 0
		end
	end)

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

	self.popupLayer = popupLayer
	return self
end

return EffectsClient
