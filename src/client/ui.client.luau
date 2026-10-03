-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("react"))
local ReactRoblox = require(packages:WaitForChild("react-roblox"))

local e = React.createElement
local player = Players.LocalPlayer

-- Components:
local function App()
	return e("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.fromOffset(240, 50),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.2,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Text = "Hello, world!",
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
	})
end

-- Mount React into a ScreenGui. ResetOnSpawn = false keeps the UI when the character respawns.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

ReactRoblox.createRoot(screenGui):render(e(App))
