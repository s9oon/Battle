-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

local selectedClones = {} -- [Model] = Highlight

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local spawnClone = remotes:WaitForChild("SpawnClone")
local moveClones = remotes:WaitForChild("MoveClones")

-- Clicks only count when they hit the terrain.
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Include
raycastParams.FilterDescendantsInstances = { game.Workspace.Terrain }

local function getClickedPosition()
	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local result = game.Workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
	return result and result.Position
end

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

local function getKeyDown(keyCode)
	return UserInputService:IsKeyDown(keyCode)
end

-- Selection:
-- Outlines the clone and adds it to the selection.
local function select(model)
	if selectedClones[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
	highlight.Adornee = model
	highlight.Parent = model
	selectedClones[model] = highlight
end

-- Removes the outline and takes the clone out of the selection.
local function deselect(model)
	local highlight = selectedClones[model]
	if not highlight then return end

	highlight:Destroy()
	selectedClones[model] = nil
end

-- For now, every clone you own is selected as soon as it spawns.
game.Workspace.ChildAdded:Connect(function(child)
	if child:GetAttribute("OwnerId") == player.UserId then
		select(child)
	end
end)

-- Drop clones from the selection when they're removed, e.g. when they die.
game.Workspace.ChildRemoved:Connect(deselect)

-- Returns the ids of every selected clone, ready to send to the server.
local function getSelectedCloneIds()
	local cloneIds = {}
	for model in selectedClones do
		table.insert(cloneIds, model:GetAttribute("CloneId"))
	end
	return cloneIds
end

-- Right click spawns a clone, left click moves the selected clones. Shift + left click is the camera drag, so skip it.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local position = getClickedPosition()
		if position then
			spawnClone:FireServer(position)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not isShiftDown() then
		local position = getClickedPosition()
		if position and next(selectedClones) then
			moveClones:FireServer(position, getSelectedCloneIds())
		end
	end
end)