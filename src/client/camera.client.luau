-- Options:
local cameraPosition = Vector3.new(0, 60, 40)
local lookAtPosition = Vector3.new(0, 0, 0)
local groundHeight = 0
local zoomStep = 5 -- Studs of height changed per scroll wheel tick.
local minZoomHeight = 15
local maxZoomHeight = 150

-- Variables:
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local camera = game.Workspace.CurrentCamera
local cameraCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

local dragAnchor = nil -- The ground point grabbed when the drag started, or nil when not dragging.

-- Returns the point on the ground under the mouse, or nil if the mouse is aimed at the sky.
local function getGroundPointUnderMouse()
	local mousePosition = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	if ray.Direction.Y >= 0 then return nil end

	local distance = (groundHeight - ray.Origin.Y) / ray.Direction.Y
	return ray.Origin + ray.Direction * distance
end

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Shift + left click drag:
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and isShiftDown() then
		dragAnchor = getGroundPointUnderMouse()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragAnchor = nil
	end
end)

-- Scroll wheel zoom: moves the camera along the direction it's looking, keeping its height within limits.
local function zoom(ticks)
	local lookVector = cameraCFrame.LookVector
	local height = cameraCFrame.Position.Y - groundHeight
	local newHeight = math.clamp(height - ticks * zoomStep, minZoomHeight, maxZoomHeight)

	local distance = (height - newHeight) / -lookVector.Y
	cameraCFrame += lookVector * distance
end

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom(input.Position.Z)
	end
end)

-- Camera movement:
local function updateCamera()
	camera.CameraType = Enum.CameraType.Scriptable

	-- Slide the camera so the grabbed ground point stays under the mouse.
	if dragAnchor then
		local groundPoint = getGroundPointUnderMouse()
		if groundPoint then
			local offset = dragAnchor - groundPoint
			cameraCFrame += Vector3.new(offset.X, 0, offset.Z)
		end
	end

	camera.CFrame = cameraCFrame
end

RunService:BindToRenderStep("StationaryCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
