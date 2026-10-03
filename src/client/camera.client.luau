-- Options:
local cameraHeight = 25
local cameraOffsetX = 0
local cameraOffsetZ = 0

-- Variables:
local players = game:GetService("Players")
local runService = game:GetService("RunService")

local player = players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera = game.Workspace.CurrentCamera

player.CharacterAdded:Connect(function(newCharacter)
  character = newCharacter
end)

-- Camera Script:
local function updateCamera()
  local root = character and character.PrimaryPart
  if not root then return end

  camera.CameraType = Enum.CameraType.Scriptable
  local targetPosition = root.Position + Vector3.new(cameraOffsetX, cameraHeight, cameraOffsetZ)
  camera.CFrame = CFrame.lookAt(targetPosition, root.Position)
end

runService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)
