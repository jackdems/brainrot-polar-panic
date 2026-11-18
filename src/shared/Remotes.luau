--[[ Remotes
	One job: be the single catalogue of every wire between client and server, and
	the only way to reach one. Pure data plus a resolver — requiring this module
	creates nothing, so both sides can require it before the folder exists.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.folderName = "PolarPanicRemotes"

-- Client -> server. Every one of these is validated by NetworkGuard before it
-- touches ServerState.
Remotes.events = {
	"RequestHatch",
	"RequestPlace",
	"RequestPickup",
	"RequestSteal",
	"RequestStunThief",
	"RequestGrabDropped",
	"RequestBuyPad",
	"RequestBuyLock",
	"RequestBuyUpgrade",
	"RequestRebirth",
	"RequestDrop",
	"RequestSnapshot", -- fired with no args; answered on StateChanged
}

-- Server -> client.
Remotes.serverEvents = {
	"StateChanged",
	"Notify",
	"BannerEvent",
	"HatchResult",
	"EffectEvent",
}

-- Request/response channel for a fresh snapshot (client asks, server answers).
Remotes.functions = {
	"GetSnapshot",
}

Remotes.all = {}

-- Resolve the live instance for `name`, waiting for the server to publish the
-- folder. Returns nil for a name that is not in the catalogue.
function Remotes.get(name)
	local folder = ReplicatedStorage:FindFirstChild(Remotes.folderName)
	if not folder then
		folder = ReplicatedStorage:WaitForChild(Remotes.folderName, 30)
	end
	if not folder then
		return nil
	end
	return folder:FindFirstChild(name) or folder:WaitForChild(name, 30)
end

return Remotes
