-- Options:
local maxClonesPerPlayer = 50
local maxClickDistance = 2048 -- Ignore positions further than this from the world origin.
local hiddenCharacterCFrame = CFrame.new(0, 1000, 0)
local reachedDistance = 6 -- Stop retrying a move once a clone is this close to its target.
local walkSpeedThreshold = 1 -- Studs per second a clone must move to play its walk animation.

-- Clones only ever stand, walk and fall, so skip the physics checks for everything else.
local unusedHumanoidStates = {
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.GettingUp,
	Enum.HumanoidStateType.Flying,
	Enum.HumanoidStateType.StrafingNoPhysics,
}

-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local spawnClone = remotes:WaitForChild("SpawnClone")
local moveClones = remotes:WaitForChild("MoveClones")

local templates = {} -- [Player] = { model: Model, idleAnimation: Animation?, walkAnimation: Animation? }
local clonesByPlayer = {} -- [Player] = { { id, owner, model, humanoid, root, walkTrack, target } }
local clonesById = {} -- [number] = clone, for looking up the clones a client asks to move
local nextCloneId = 0

local function isValidPosition(position)
	return typeof(position) == "Vector3"
		and position == position -- false when any component is NaN
		and position.Magnitude < maxClickDistance
end

-- Templates:
local function getAnimation(animate, name)
	local folder = animate:FindFirstChild(name)
	local animation = folder and folder:FindFirstChildWhichIsA("Animation")
	return animation and animation:Clone()
end

-- Copies the character into a template that clones are made from.
local function createTemplate(character)
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = false

	-- The Animate script is a LocalScript and won't run on a clone, so keep its animations and play them from the server instead.
	local template = { model = model }
	local animate = model:FindFirstChild("Animate")
	if animate then
		template.idleAnimation = getAnimation(animate, "idle")
		template.walkAnimation = getAnimation(animate, "walk")
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LocalScript") or descendant:IsA("ForceField") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") and descendant.Parent:IsA("Accessory") then
			-- Hats and hair are purely visual, so keep them out of physics, touches and raycasts.
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	return template
end

-- Makes the character invisible and parks it in the sky so it can't be seen or bumped into.
local function hideCharacter(character)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	character:PivotTo(hiddenCharacterCFrame)
	if character.PrimaryPart then
		character.PrimaryPart.Anchored = true
	end
end

-- Clones:
local function loadAnimation(animator, animation, priority)
	if not animation then return nil end

	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	return track
end

local function createClone(player, template, position)
	local model = template.model:Clone()
	model.Name = player.Name .. "Clone"
	model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))

	-- Give the clone a unique id and mark who owns it.
	-- These are set before parenting so clients see them as soon as the clone appears.
	nextCloneId += 1
	local id = nextCloneId
	model:SetAttribute("CloneId", id)
	model:SetAttribute("OwnerId", player.UserId)

	model.Parent = game.Workspace
	model.PrimaryPart:SetNetworkOwner(nil)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	for _, state in unusedHumanoidStates do
		humanoid:SetStateEnabled(state, false)
	end

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local idleTrack = loadAnimation(animator, template.idleAnimation, Enum.AnimationPriority.Idle)
	if idleTrack then idleTrack:Play() end

	local clone = {
		id = id,
		owner = player,
		model = model,
		humanoid = humanoid,
		root = model.PrimaryPart,
		walkTrack = loadAnimation(animator, template.walkAnimation, Enum.AnimationPriority.Movement),
		target = nil,
	}

	-- MoveTo gives up after 8 seconds, so keep walking until the clone gets close to its target.
	humanoid.MoveToFinished:Connect(function(reached)
		if reached or not clone.target then return end

		if (clone.root.Position - clone.target).Magnitude > reachedDistance then
			humanoid:MoveTo(clone.target)
		end
	end)

	-- Clean up clones that die, e.g. by falling out of the world, and forget them once they're gone.
	humanoid.Died:Connect(function()
		model:Destroy()
	end)
	model.Destroying:Connect(function()
		clonesById[id] = nil

		local playerClones = clonesByPlayer[player]
		local index = playerClones and table.find(playerClones, clone)
		if index then
			table.remove(playerClones, index)
		end
	end)

	clonesById[id] = clone
	return clone
end

-- Play each clone's walk animation while it's moving sideways.
local function updateWalkAnimations()
	for _, playerClones in clonesByPlayer do
		for _, clone in playerClones do
			local walkTrack = clone.walkTrack
			if walkTrack then
				local velocity = clone.root.AssemblyLinearVelocity
				local isMoving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > walkSpeedThreshold
				if isMoving ~= walkTrack.IsPlaying then
					if isMoving then walkTrack:Play() else walkTrack:Stop() end
				end
			end
		end
	end
end

-- Players:
-- Runs once the character's hats, clothes and body parts have loaded, so the template copies the full avatar.
local function onCharacterAppearanceLoaded(player, character)
	-- The appearance can finish loading before the character is put in the workspace, and hiding it then
	-- gets undone when it spawns, so wait for that. Give up if the player has respawned in the meantime.
	while character.Parent == nil do
		if player.Character ~= character then return end
		task.wait()
	end

	if templates[player] then
		templates[player].model:Destroy()
	end
	templates[player] = createTemplate(character)

	hideCharacter(character)
end

local function onPlayerAdded(player)
	clonesByPlayer[player] = {}

	-- Listen for the appearance event itself rather than waiting for it inside CharacterAdded,
	-- it can fire in the same frame as CharacterAdded and a wait started after that never finishes.
	player.CharacterAppearanceLoaded:Connect(function(character)
		onCharacterAppearanceLoaded(player, character)
	end)
	if player.Character and player:HasAppearanceLoaded() then
		task.spawn(onCharacterAppearanceLoaded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	-- Clear the list first so each clone's Destroying handler doesn't edit it mid-loop.
	local playerClones = clonesByPlayer[player] or {}
	clonesByPlayer[player] = nil
	for _, clone in playerClones do
		clone.model:Destroy()
	end

	if templates[player] then
		templates[player].model:Destroy()
		templates[player] = nil
	end
end

-- Remote events:
spawnClone.OnServerEvent:Connect(function(player, position)
	local template = templates[player]
	local playerClones = clonesByPlayer[player]
	if not template or not playerClones or not isValidPosition(position) then return end
	if #playerClones >= maxClonesPerPlayer then return end

	table.insert(playerClones, createClone(player, template, position))
end)

-- Moves the clones the client has selected, sent as a list of clone ids.
moveClones.OnServerEvent:Connect(function(player, position, cloneIds)
	if not isValidPosition(position) or typeof(cloneIds) ~= "table" then return end

	-- A player can never own more than maxClonesPerPlayer, so ignore anything longer.
	if #cloneIds > maxClonesPerPlayer then return end

	for _, id in cloneIds do
		local clone = clonesById[id]

		-- Only move clones this player actually owns, so nobody can move someone else's.
		if clone and clone.owner == player then
			clone.target = position
			clone.humanoid:MoveTo(position)
		end
	end
end)

RunService.Heartbeat:Connect(updateWalkAnimations)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
