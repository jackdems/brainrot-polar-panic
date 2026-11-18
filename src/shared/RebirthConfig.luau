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

return RebirthConfig
