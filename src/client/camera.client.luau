-- Options:
local cameraPosition = Vector3.new(0, 60, 40)
local lookAtPosition = Vector3.new(0, 0, 0)
local groundHeight = 0

-- Variables:
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")

local camera = game.Workspace.CurrentCamera
local cameraCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

local isDragging = false
local dragAnchor = nil

-- Returns the point on the ground under the mouse, or nil if the mouse is aimed at the sky.
local function getGroundPointUnderMouse()
  local mousePosition = userInputService:GetMouseLocation()
  local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
  if ray.Direction.Y >= 0 then return nil end

  local distance = (groundHeight - ray.Origin.Y) / ray.Direction.Y
  return ray.Origin + ray.Direction * distance
end

local function isShiftDown()
  return userInputService:IsKeyDown(Enum.KeyCode.LeftShift) or userInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Shift + left click drag:
userInputService.InputBegan:Connect(function(input, gameProcessed)
  if gameProcessed then return end

  if input.UserInputType == Enum.UserInputType.MouseButton1 and isShiftDown() then
    dragAnchor = getGroundPointUnderMouse()
    isDragging = dragAnchor ~= nil
  end
end)

userInputService.InputEnded:Connect(function(input)
  if input.UserInputType == Enum.UserInputType.MouseButton1 then
    isDragging = false
    dragAnchor = nil
  end
end)

-- Camera movment:
local function updateCamera()
  camera.CameraType = Enum.CameraType.Scriptable

  -- Slide the camera so the ground point grabbed on right click stays under the mouse.
  if isDragging then
    local groundPoint = getGroundPointUnderMouse()
    if groundPoint then
      local offset = dragAnchor - groundPoint
      cameraCFrame += Vector3.new(offset.X, 0, offset.Z)
    end
  end

  camera.CFrame = cameraCFrame
end

runService:BindToRenderStep("StationaryCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
