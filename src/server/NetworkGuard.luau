--[[ NetworkGuard
	One job: the only door a client may knock on. Services register a named
	handler here; the guard owns the remote wiring, the per-player cooldowns, the
	argument type checks and the range checks, and it is the only module allowed to
	push a state snapshot to a client.
]]

local Players = game:GetService("Players")

local ServerState = nil
local remotes = nil
local handlers = {}
local cooldownUntil = {}

local NetworkGuard = {}

-- Per-remote minimum seconds between accepted calls. Tuned so a fast player can
-- still play, but a spammer cannot hammer the server.
NetworkGuard.cooldowns = {
	RequestHatch = 0.75,
	RequestPlace = 0.45,
	RequestPickup = 0.45,
	RequestSteal = 0.6,
	RequestStunThief = 0.5,
	RequestGrabDropped = 0.4,
	RequestBuyPad = 0.4,
	RequestBuyLock = 0.4,
	RequestBuyUpgrade = 0.4,
	RequestRebirth = 1.5,
	RequestDevGrant = 0.5,
	RequestSnapshot = 0.2,
}

-- How far a player may be from a thing they claim to be using.
NetworkGuard.reachDistance = 32

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("PolarShared"):WaitForChild("Remotes"))

function NetworkGuard.init(context)
	ServerState = context.state
	remotes = context.remotes

	for _, name in ipairs(Remotes.events) do
		local remote = remotes:FindFirstChild(name)
		if remote then
			remote.OnServerEvent:Connect(function(player, ...)
				NetworkGuard.dispatch(player, name, ...)
			end)
		end
	end

	local snapshotFunction = remotes:FindFirstChild("GetSnapshot")
	if snapshotFunction then
		snapshotFunction.OnServerInvoke = function(player)
			local record = ServerState.get(player)
			if not record then
				return nil
			end
			return ServerState.snapshot(record)
		end
	end

	NetworkGuard.register("RequestDevGrant", NetworkGuard.devGrant)

	print("[NetworkGuard] wired " .. #remotes:GetChildren() .. " remotes")
end

-- ---------------------------------------------------------------- dev grant

-- Studio-only affordance: the recorded build needs a den full of characters to
-- photograph, and the only honest way to get there is to pay for them. This is
-- refused outside Studio, so a live server never sees it.
function NetworkGuard.devGrant(player, record, amount)
	local isStudio = game:GetService("RunService"):IsStudio()
	if not isStudio then
		return
	end
	local value = NetworkGuard.asNumber(amount, 0, 50000000)
	if not value then
		return
	end
	ServerState.addCash(record, value)
	NetworkGuard.notify(player, string.format("Studio grant: +$%d", math.floor(value)), Color3.fromRGB(126, 255, 176))
	NetworkGuard.pushState(player)
end

function NetworkGuard.register(name, handler)
	handlers[name] = handler
end

local function cooldownKey(player, name)
	return tostring(player.UserId) .. ":" .. name
end

-- Called on every client event: identity, record, cooldown, then the handler.
function NetworkGuard.dispatch(player, name, ...)
	local handler = handlers[name]
	if not handler then
		return
	end

	local record = ServerState.get(player)
	if not record then
		return
	end

	local now = os.clock()
	local key = cooldownKey(player, name)
	local window = NetworkGuard.cooldowns[name] or 0.2
	if (cooldownUntil[key] or 0) > now then
		return
	end
	cooldownUntil[key] = now + window

	-- A handler that explodes must never take the server with it.
	local ok, err = pcall(handler, player, record, ...)
	if not ok then
		warn(string.format("[NetworkGuard] %s from %s failed: %s", name, player.Name, tostring(err)))
	end
end

-- ---------------------------------------------------------------- outgoing

function NetworkGuard.notify(player, text, color, duration)
	if not player or not player.Parent then
		return
	end
	local remote = remotes:FindFirstChild("Notify")
	if remote then
		remote:FireClient(player, {
			text = text,
			color = color or Color3.fromRGB(255, 255, 255),
			duration = duration or 2.5,
		})
	end
end

function NetworkGuard.pushState(player)
	if not player or not player.Parent then
		return
	end
	local record = ServerState.get(player)
	if not record then
		return
	end
	local remote = remotes:FindFirstChild("StateChanged")
	if remote then
		remote:FireClient(player, ServerState.snapshot(record))
	end
end

function NetworkGuard.broadcastState()
	for _, player in ipairs(Players:GetPlayers()) do
		NetworkGuard.pushState(player)
	end
end

function NetworkGuard.banner(kind, text, color, seconds)
	local remote = remotes:FindFirstChild("BannerEvent")
	if not remote then
		return
	end
	remote:FireAllClients({
		kind = kind,
		text = text,
		color = color or Color3.fromRGB(255, 255, 255),
		seconds = seconds or 3,
	})
end

function NetworkGuard.effect(kind, payload)
	local remote = remotes:FindFirstChild("EffectEvent")
	if not remote then
		return
	end
	remote:FireAllClients(kind, payload)
end

function NetworkGuard.effectTo(player, kind, payload)
	local remote = remotes:FindFirstChild("EffectEvent")
	if not remote or not player or not player.Parent then
		return
	end
	remote:FireClient(player, kind, payload)
end

function NetworkGuard.hatchResult(player, payload)
	local remote = remotes:FindFirstChild("HatchResult")
	if not remote or not player or not player.Parent then
		return
	end
	remote:FireClient(player, payload)
end

-- ---------------------------------------------------------------- validation

-- Clean a value the client sent. Anything that is not the expected type is nil,
-- never an exception, so a malformed payload is simply refused.
function NetworkGuard.asString(value, maxLength)
	if type(value) ~= "string" then
		return nil
	end
	if #value > (maxLength or 64) then
		return nil
	end
	return value
end

function NetworkGuard.asNumber(value, minimum, maximum)
	if type(value) ~= "number" then
		return nil
	end
	if value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	if minimum and value < minimum then
		return nil
	end
	if maximum and value > maximum then
		return nil
	end
	return value
end

function NetworkGuard.asInt(value, minimum, maximum)
	local number = NetworkGuard.asNumber(value, minimum, maximum)
	if not number then
		return nil
	end
	return math.floor(number + 0.5)
end

-- The player's humanoid root, or nil when they have no living character.
function NetworkGuard.rootOf(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- Distance check against anything with a Position (a base, a pad, an NPC).
function NetworkGuard.inReach(player, position, reach)
	local root = NetworkGuard.rootOf(player)
	if not root then
		return false
	end
	return (root.Position - position).Magnitude <= (reach or NetworkGuard.reachDistance)
end

function NetworkGuard.alive(player)
	local root = NetworkGuard.rootOf(player)
	return root ~= nil
end

return NetworkGuard
