--[[ MoneyService
	One job: pay everybody. One accumulating Heartbeat tick, one payout per whole
	second per player, and the leaderboard values the client mirrors. No other
	module is allowed to add income.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MoneyService = {}

local ServerState, NetworkGuard

local accumulator = 0
local PUSH_INTERVAL = 0.45
local pushTimer = 0

function MoneyService.init(context)
	ServerState = context.state
	NetworkGuard = context.guard or require(script.Parent.NetworkGuard)

	-- leaderstats so the numbers are visible the moment a player joins.
	Players.PlayerAdded:Connect(MoneyService.buildLeaderstats)

	RunService.Heartbeat:Connect(MoneyService.step)

	print("[MoneyService] ticking")
end

-- A player's three public numbers. Called on join; harmless if repeated.
function MoneyService.buildLeaderstats(player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = stats

	local income = Instance.new("IntValue")
	income.Name = "PerSecond"
	income.Value = 0
	income.Parent = stats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = stats

	stats.Parent = player
end

-- Heartbeat accumulator: whole seconds only, so income is exactly $/s.
function MoneyService.step(deltaTime)
	accumulator += deltaTime
	pushTimer += deltaTime

	if accumulator >= 1 then
		local wholeSeconds = math.floor(accumulator)
		accumulator -= wholeSeconds
		MoneyService.tickIncome(wholeSeconds)
	end

	if pushTimer >= PUSH_INTERVAL then
		pushTimer = 0
		MoneyService.refreshLeaderstats()
	end
end

-- The one payout. Income is per placed character, so a full den is worth the sum.
function MoneyService.tickIncome(seconds)
	for _, player in ipairs(Players:GetPlayers()) do
		local record = ServerState.get(player)
		if record then
			local perSecond = ServerState.incomePerSecond(record)
			if perSecond > 0 then
				local payout = perSecond * seconds
				ServerState.addCash(record, payout)

				-- Per-pad bookkeeping: the den panel shows each character's earnings.
				local multiplier = ServerState.rebirthMultiplier(record) * ServerState.eventMultiplier
				for _, pad in pairs(record.pads) do
					pad.earned = (pad.earned or 0) + ServerState.padIncome(pad) * multiplier * seconds
				end

				-- The HUD's floating "+N" rides this event.
				NetworkGuard.effectTo(player, "paid", {
					amount = payout,
					cash = record.cash,
					perSecond = perSecond,
				})
			end
		end
	end
end

function MoneyService.refreshLeaderstats()
	for _, player in ipairs(Players:GetPlayers()) do
		local record = ServerState.get(player)
		local stats = player:FindFirstChild("leaderstats")
		if record and stats then
			local cashValue = stats:FindFirstChild("Cash")
			if cashValue then
				cashValue.Value = math.floor(record.cash)
			end
			local perSecond = stats:FindFirstChild("PerSecond")
			if perSecond then
				perSecond.Value = math.floor(ServerState.incomePerSecond(record))
			end
			local rebirths = stats:FindFirstChild("Rebirths")
			if rebirths then
				rebirths.Value = record.rebirths
			end
		end
	end
end

-- A shared purchase helper: every buyer goes through here so the "not enough
-- money" message is worded the same everywhere.
function MoneyService.purchase(player, record, price, label)
	if not ServerState.trySpend(record, price) then
		NetworkGuard.notify(player, string.format("Need $%d for %s.", price, label or "that"),
			Color3.fromRGB(255, 140, 120))
		return false
	end
	NetworkGuard.pushState(player)
	return true
end

return MoneyService
