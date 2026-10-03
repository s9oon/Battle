-- Options:
local cameraPosition = Vector3.new(0, 60, 40)
local lookAtPosition = Vector3.new(0, 0, 0)

-- Variables:
local runService = game:GetService("RunService")

local camera = game.Workspace.CurrentCamera
local cameraCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)

-- Camera Script:
local function updateCamera()
  camera.CameraType = Enum.CameraType.Scriptable
  camera.CFrame = cameraCFrame
end

runService:BindToRenderStep("StationaryCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)