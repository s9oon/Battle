-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("react"))
local ReactRoblox = require(packages:WaitForChild("react-roblox"))

local selection = require(script.Parent:WaitForChild("selection"))

local e = React.createElement
local player = Players.LocalPlayer

local panelColor = Color3.fromRGB(30, 30, 30)
local buttonColor = Color3.fromRGB(55, 55, 55)
local selectedColor = Color3.fromRGB(255, 200, 0)
local textColor = Color3.fromRGB(255, 255, 255)

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Hooks:
-- Re-renders the component whenever clones are added, removed, selected or deselected.
local function useSelectionChanged()
	local _, setVersion = React.useState(0)

	React.useEffect(function()
		local connection = selection.changed:Connect(function()
			setVersion(function(version)
				return version + 1
			end)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
end

-- Components:
local function Button(props)
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = props.size,
		AutoButtonColor = true,
		BackgroundColor3 = props.selected and selectedColor or buttonColor,
		TextColor3 = props.selected and panelColor or textColor,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = props.text,
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 6) }),
	})
end

-- Clicking a clone selects only it, shift + clicking adds or removes it from the selection.
local function CloneButton(props)
	local model = props.model

	return e(Button, {
		layoutOrder = props.index,
		size = UDim2.new(1, 0, 0, 28),
		selected = props.selected,
		text = "Clone " .. props.index,
		onActivated = function()
			if isShiftDown() then
				selection.toggle(model)
			else
				selection.clear()
				selection.select(model)
			end
		end,
	})
end

local function ClonePanel()
	useSelectionChanged()

	local clones = selection.getClones()

	local cloneButtons = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, model in clones do
		cloneButtons[tostring(model:GetAttribute("CloneId"))] = e(CloneButton, {
			model = model,
			index = index,
			selected = selection.isSelected(model),
		})
	end
	if #clones == 0 then
		cloneButtons.Empty = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			TextColor3 = textColor,
			TextTransparency = 0.4,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			Text = "Right click the ground to spawn a clone.",
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(180, 320),
		BackgroundColor3 = panelColor,
		BackgroundTransparency = 0.2,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),

		Title = e("TextLabel", {
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundTransparency = 1,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			Text = "Clones (" .. #clones .. ")",
		}),

		Actions = e("Frame", {
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			All = e(Button, {
				layoutOrder = 1,
				size = UDim2.new(0.5, -2, 1, 0),
				text = "All",
				onActivated = function()
					for _, model in clones do
						selection.select(model)
					end
				end,
			}),
			None = e(Button, {
				layoutOrder = 2,
				size = UDim2.new(0.5, -2, 1, 0),
				text = "None",
				onActivated = selection.clear,
			}),
		}),

		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 1, -60),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, cloneButtons),
	})
end

local function App()
	return e(ClonePanel)
end

-- Mount React into a ScreenGui. ResetOnSpawn = false keeps the UI when the character respawns.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

ReactRoblox.createRoot(screenGui):render(e(App))
