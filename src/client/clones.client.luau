-- Variables:
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local camera = game.Workspace.CurrentCamera

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

-- Right click spawns a clone, left click moves every clone. Shift + left click is the camera drag, so skip it.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local position = getClickedPosition()
		if position then
			spawnClone:FireServer(position)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not isShiftDown() then
		local position = getClickedPosition()
		if position then
			moveClones:FireServer(position)
		end
	end
end)
