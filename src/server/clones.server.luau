-- Options:
local maxClonesPerPlayer = 50
local maxClickDistance = 2048 -- Ignore positions further than this from the world origin.
local hiddenCharacterCFrame = CFrame.new(0, 1000, 0)
local reachedDistance = 6 -- Stop retrying a move once a clone is this close to its target.
local walkSpeedThreshold = 1 -- Studs per second a clone must move to play its walk animation.

-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local spawnClone = remotes:WaitForChild("SpawnClone")
local moveClones = remotes:WaitForChild("MoveClones")

local templates = {} -- [player] = { model = Model, walkAnimationId = string?, idleAnimationId = string? }
local clones = {} -- [player] = { Model }

local function isValidPosition(position)
	return typeof(position) == "Vector3"
		and position == position -- false when any component is NaN
		and position.Magnitude < maxClickDistance
end

local function getAnimationId(animate, name)
	local folder = animate:FindFirstChild(name)
	local animation = folder and folder:FindFirstChildWhichIsA("Animation")
	return animation and animation.AnimationId
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
		template.walkAnimationId = getAnimationId(animate, "walk")
		template.idleAnimationId = getAnimationId(animate, "idle")
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LocalScript") or descendant:IsA("ForceField") then
			descendant:Destroy()
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

local function loadAnimation(animator, animationId, priority)
	if not animationId then return nil end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	return track
end

local function setUpClone(clone, template)
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	-- Animations:
	local idleTrack = loadAnimation(animator, template.idleAnimationId, Enum.AnimationPriority.Idle)
	local walkTrack = loadAnimation(animator, template.walkAnimationId, Enum.AnimationPriority.Movement)
	if idleTrack then idleTrack:Play() end

	-- Play the walk animation while the clone is moving sideways.
	if walkTrack then
		local root = clone.PrimaryPart
		local connection = RunService.Heartbeat:Connect(function()
			local velocity = root.AssemblyLinearVelocity
			local isMoving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > walkSpeedThreshold
			if isMoving and not walkTrack.IsPlaying then
				walkTrack:Play()
			elseif not isMoving and walkTrack.IsPlaying then
				walkTrack:Stop()
			end
		end)
		clone.Destroying:Connect(function()
			connection:Disconnect()
		end)
	end

	-- MoveTo gives up after 8 seconds, so keep walking until the clone gets close to its target.
	humanoid.MoveToFinished:Connect(function(reached)
		local target = humanoid:GetAttribute("MoveTarget")
		if reached or not target or not clone.PrimaryPart then return end

		if (clone.PrimaryPart.Position - target).Magnitude > reachedDistance then
			humanoid:MoveTo(target)
		end
	end)
end

local function onCharacterAdded(player, character)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if character.Parent == nil then return end

	if templates[player] then
		templates[player].model:Destroy()
	end
	templates[player] = createTemplate(character)

	hideCharacter(character)
end

local function onPlayerAdded(player)
	clones[player] = {}

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	for _, clone in clones[player] or {} do
		clone:Destroy()
	end
	if templates[player] then
		templates[player].model:Destroy()
	end

	clones[player] = nil
	templates[player] = nil
end

-- Clone events:
spawnClone.OnServerEvent:Connect(function(player, position)
	local template = templates[player]
	local playerClones = clones[player]
	if not template or not playerClones or not isValidPosition(position) then return end

	-- Forget clones that have been destroyed, e.g. fell out of the world.
	for i = #playerClones, 1, -1 do
		if playerClones[i].Parent == nil then
			table.remove(playerClones, i)
		end
	end
	if #playerClones >= maxClonesPerPlayer then return end

	local clone = template.model:Clone()
	clone.Name = player.Name .. "Clone"
	clone:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	clone.Parent = game.Workspace
	clone.PrimaryPart:SetNetworkOwner(nil)

	setUpClone(clone, template)
	table.insert(playerClones, clone)
end)

moveClones.OnServerEvent:Connect(function(player, position)
	local playerClones = clones[player]
	if not playerClones or not isValidPosition(position) then return end

	for _, clone in playerClones do
		local humanoid = clone.Parent and clone:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:SetAttribute("MoveTarget", position)
			humanoid:MoveTo(position)
		end
	end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
