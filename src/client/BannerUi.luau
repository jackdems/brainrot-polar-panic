--[[ BannerUi
	One job: the big centre-screen announcements — the Ice Wall warning with its
	red vignette and countdown, the Golden Blizzard, a rebirth, a thief raid — plus
	the small toast line for one-off messages.
]]

local TweenService = game:GetService("TweenService")

local BannerUi = {}

local function corner(parent, radius)
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, radius)
	rounded.Parent = parent
	return rounded
end

function BannerUi.new(gui)
	local self = {}

	-- The vignette: a red border that fades in while the wall is coming.
	local vignette = Instance.new("Frame")
	vignette.Name = "DangerVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 1
	vignette.Parent = gui

	local vignetteGradient = Instance.new("UIGradient")
	vignetteGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	vignetteGradient.Rotation = 90
	vignetteGradient.Parent = vignette

	-- The banner bar.
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 196)
	banner.Size = UDim2.fromOffset(940, 116)
	banner.BackgroundColor3 = Color3.fromRGB(8, 16, 30)
	banner.BackgroundTransparency = 0.06
	banner.BorderSizePixel = 0
	banner.Visible = false
	banner.ZIndex = 5
	banner.Parent = gui
	corner(banner, 18)

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Color3.fromRGB(150, 220, 255)
	bannerStroke.Thickness = 5
	bannerStroke.Parent = banner

	local bannerText = Instance.new("TextLabel")
	bannerText.Name = "Text"
	bannerText.Size = UDim2.new(1, -30, 1, -12)
	bannerText.Position = UDim2.fromOffset(15, 6)
	bannerText.BackgroundTransparency = 1
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextSize = 46
	bannerText.TextScaled = true
	bannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bannerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	bannerText.TextStrokeTransparency = 0.4
	bannerText.Text = ""
	bannerText.Parent = banner

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.AnchorPoint = Vector2.new(0.5, 0)
	countdown.Position = UDim2.new(0.5, 0, 0, 320)
	countdown.Size = UDim2.fromOffset(460, 52)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.FredokaOne
	countdown.TextSize = 44
	countdown.TextColor3 = Color3.fromRGB(255, 236, 130)
	countdown.TextStrokeColor3 = Color3.fromRGB(30, 6, 6)
	countdown.TextStrokeTransparency = 0.3
	countdown.Text = ""
	countdown.Visible = false
	countdown.ZIndex = 5
	countdown.Parent = gui

	-- The toast line for a single message.
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 268)
	toast.Size = UDim2.fromOffset(820, 52)
	toast.BackgroundColor3 = Color3.fromRGB(8, 16, 30)
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.Font = Enum.Font.GothamBlack
	toast.TextSize = 24
	toast.TextColor3 = Color3.fromRGB(255, 255, 255)
	toast.Text = ""
	toast.Visible = false
	toast.ZIndex = 6
	toast.Parent = gui
	corner(toast, 12)

	local function showToast(text, color, duration)
		toast.Text = text or ""
		toast.TextColor3 = color or Color3.fromRGB(255, 255, 255)
		toast.Visible = true
		toast.TextTransparency = 0
		toast.BackgroundTransparency = 0.15
		task.delay(duration or 2.5, function()
			TweenService:Create(toast, TweenInfo.new(0.4),
				{ TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			task.wait(0.45)
			if toast.TextTransparency >= 1 then
				toast.Visible = false
			end
		end)
	end

	-- The banner: pops in, holds, fades.
	function self.show(text, color, seconds)
		bannerText.Text = text or ""
		bannerStroke.Color = color or Color3.fromRGB(150, 220, 255)
		banner.Visible = true
		banner.BackgroundTransparency = 0.7
		bannerText.TextTransparency = 1
		TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundTransparency = 0.06 }):Play()
		TweenService:Create(bannerText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()

		task.delay(seconds or 3, function()
			TweenService:Create(bannerText, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.wait(0.45)
			banner.Visible = false
		end)
	end

	-- A countdown that ticks under the banner (the wall warning uses it).
	local countdownToken = 0
	function self.countdown(seconds, color)
		countdownToken += 1
		local myToken = countdownToken
		countdown.TextColor3 = color or Color3.fromRGB(255, 236, 130)
		countdown.Visible = true
		task.spawn(function()
			for remaining = seconds, 0, -1 do
				if myToken ~= countdownToken then
					return
				end
				countdown.Text = string.format("SURVIVE  %d", remaining)
				task.wait(1)
			end
			if myToken == countdownToken then
				countdown.Visible = false
			end
		end)
	end

	function self.hideCountdown()
		countdownToken += 1
		countdown.Visible = false
	end

	function self.setDanger(level)
		TweenService:Create(vignette, TweenInfo.new(0.5),
			{ BackgroundTransparency = 1 - (level or 0) * 0.36 }):Play()
	end

	self.toast = showToast
	self.banner = banner
	self.vignette = vignette
	return self
end

return BannerUi
