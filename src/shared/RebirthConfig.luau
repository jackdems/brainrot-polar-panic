--[[ RebirthConfig
	One job: the rebirth ladder. What a rebirth costs, what it pays back, how many
	you get, and the Galaxy Egg gate that rides on top of it.
]]

local RebirthConfig = {}

RebirthConfig.maxRebirths = 5
RebirthConfig.baseCost = 25000
RebirthConfig.baseMultiplier = 1

-- Rebirth N (0-indexed: your first rebirth is N = 0) costs 25000 * 2^N.
function RebirthConfig.cost(rebirths)
	return RebirthConfig.baseCost * (2 ^ (rebirths or 0))
end

-- Income multiplier after `rebirths` rebirths: x2 each time.
function RebirthConfig.multiplier(rebirths)
	return RebirthConfig.baseMultiplier * (2 ^ (rebirths or 0))
end

function RebirthConfig.canRebirth(rebirths)
	return (rebirths or 0) < RebirthConfig.maxRebirths
end

-- A rebirth buys exactly one extra pad socket (on top of the free six).
function RebirthConfig.padsFor(rebirths)
	return 6 + (rebirths or 0)
end

RebirthConfig.galaxyEggRebirth = 1

function RebirthConfig.galaxyUnlocked(rebirths)
	return (rebirths or 0) >= RebirthConfig.galaxyEggRebirth
end

-- The whole ladder as rows for the panel: {index, multiplier, cost}.
function RebirthConfig.ladder()
	local rows = {}
	for index = 1, RebirthConfig.maxRebirths do
		table.insert(rows, {
			index = index,
			multiplier = RebirthConfig.multiplier(index),
			cost = RebirthConfig.cost(index - 1),
		})
	end
	return rows
end

-- "x4" / "$25,000" - the panel and the HUD both want these strings.
function RebirthConfig.describeCost(rebirths)
	local cost = RebirthConfig.cost(rebirths)
	if cost >= 1e6 then
		return string.format("$%.1fM", cost / 1e6)
	elseif cost >= 1e4 then
		return string.format("$%.1fK", cost / 1e3)
	end
	return string.format("$%d", cost)
end

return RebirthConfig
