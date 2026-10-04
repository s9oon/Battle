-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = game.Workspace.CurrentCamera

local selection = require(script.Parent:WaitForChild("selection"))

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

-- Returns the ids of every selected clone, ready to send to the server.
local function getSelectedCloneIds()
	local cloneIds = {}
	for _, model in selection.getSelected() do
		table.insert(cloneIds, model:GetAttribute("CloneId"))
	end
	return cloneIds
end

-- Control groups:
-- Shift + a number key saves the current selection to that group, the number key on its own selects it again.
local groupKeys = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}
local groups = {} -- [group number] = { Model }

-- Roblox's tool hotbar also uses the number keys, so hide it.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- Remembers which clones are selected right now under this group number.
local function saveGroup(group)
	groups[group] = selection.getSelected()
end

-- Replaces the selection with the clones saved in this group, skipping any that have died since.
local function selectGroup(group)
	local models = groups[group]
	if not models then return end

	selection.clear()
	for _, model in models do
		if model.Parent then
			selection.select(model)
		end
	end
end

-- Input:
-- Number keys handle control groups, right click spawns a clone, left click moves the selected clones.
-- Shift + left click is the camera drag, so skip it.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local group = groupKeys[input.KeyCode]
	if group then
		if isShiftDown() then
			saveGroup(group)
		else
			selectGroup(group)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		local position = getClickedPosition()
		if position then
			spawnClone:FireServer(position)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not isShiftDown() then
		local position = getClickedPosition()
		if position and selection.hasSelection() then
			moveClones:FireServer(position, getSelectedCloneIds())
		end
	end
end)