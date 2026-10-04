-- Variables:
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(packages:WaitForChild("react"))
local ReactRoblox = require(packages:WaitForChild("react-roblox"))

local selection = require(script.Parent:WaitForChild("selection"))
local icons = require(script.Parent:WaitForChild("icons"))

local e = React.createElement
local player = Players.LocalPlayer

local groupCount = 9

-- Every clone is a copy of the player's avatar, so they all share the player's headshot.
local headshot = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"

-- Chunky cartoon style to match the Zxgly icons: bright fills with thick navy outlines.
local colors = {
	outline = Color3.fromRGB(24, 26, 52),
	panel = Color3.fromRGB(52, 60, 110),
	tile = Color3.fromRGB(82, 94, 160),
	selected = Color3.fromRGB(255, 204, 51),
	portrait = Color3.fromRGB(190, 210, 255),
	green = Color3.fromRGB(88, 204, 92),
	red = Color3.fromRGB(238, 86, 86),
	text = Color3.fromRGB(255, 255, 255),
}

local boldFont = Enum.Font.FredokaOne

local function isShiftDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Hooks:
-- Re-renders the component whenever clones are added, removed, selected, deselected or grouped.
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

-- Style helpers:
local function corner(radius)
	return e("UICorner", { CornerRadius = radius and UDim.new(0, radius) or UDim.new(1, 0) })
end

-- Outlines the box itself rather than its text.
local function outline(thickness)
	return e("UIStroke", {
		Color = colors.outline,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Darkens the bottom of a box so flat colors look a little shaded.
local function shade()
	return e("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215)),
	})
end

-- Components:
-- White text with a navy outline, like the icons.
local function Label(props)
	return e("TextLabel", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		TextColor3 = colors.text,
		TextXAlignment = props.alignment or Enum.TextXAlignment.Center,
		Font = boldFont,
		TextSize = props.textSize or 16,
		Text = props.text,
	}, {
		Outline = e("UIStroke", { Color = colors.outline, Thickness = props.outlineThickness or 1.5 }),
	})
end

local function Icon(props)
	return e("ImageLabel", {
		AnchorPoint = props.anchorPoint,
		Position = props.position,
		Size = props.size,
		BackgroundTransparency = 1,
		Image = props.image,
		ImageTransparency = props.transparency or 0,
		ScaleType = Enum.ScaleType.Fit,
	})
end

local function Portrait(props)
	return e("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = props.position,
		Size = props.size,
		BackgroundColor3 = colors.portrait,
		Image = headshot,
		ScaleType = Enum.ScaleType.Crop,
	}, {
		Corner = corner(8),
		Outline = outline(2),
	})
end

-- A chunky colored button with a text label.
local function Button(props)
	return e("TextButton", {
		LayoutOrder = props.layoutOrder,
		Size = props.size,
		AutoButtonColor = true,
		BackgroundColor3 = props.color,
		Text = "",
		[React.Event.Activated] = props.onActivated,
	}, {
		Corner = corner(8),
		Outline = outline(),
		Shade = shade(),
		Label = e(Label, { size = UDim2.fromScale(1, 1), text = props.text, textSize = 18 }),
	})
end

-- Clicking a clone selects only it, shift + clicking adds or removes it from the selection.
local function CloneTile(props)
	local model = props.model

	return e("TextButton", {
		LayoutOrder = props.index,
		AutoButtonColor = true,
		BackgroundColor3 = props.selected and colors.selected or colors.tile,
		Text = "",
		[React.Event.Activated] = function()
			if isShiftDown() then
				selection.toggle(model)
			else
				selection.clear()
				selection.select(model)
			end
		end,
	}, {
		Corner = corner(10),
		Outline = outline(props.selected and 3 or 2.5),
		Shade = shade(),
		Portrait = e(Portrait, { position = UDim2.new(0.5, 0, 0, 6), size = UDim2.fromOffset(44, 44) }),
		Number = e(Label, {
			position = UDim2.new(0, 0, 1, -22),
			size = UDim2.new(1, 0, 0, 18),
			text = "#" .. props.index,
		}),

		-- Shows which control group the clone is in, if any.
		Group = props.group and e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = colors.outline,
			ZIndex = 2,
		}, {
			Corner = corner(),
			Label = e(Label, { size = UDim2.fromScale(1, 1), text = tostring(props.group), textSize = 13, outlineThickness = 0 }),
		}),
	})
end

local function ClonePanel()
	useSelectionChanged()

	local clones = selection.getClones()
	local selectedCount = #selection.getSelected()

	-- Lowest group number each clone belongs to, for the badge on its tile.
	local groupOf = {}
	for group = groupCount, 1, -1 do
		for _, model in selection.getGroup(group) do
			groupOf[model] = group
		end
	end

	local tiles = {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 3),
			PaddingBottom = UDim.new(0, 4),
		}),
		Layout = e("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 76),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, model in clones do
		tiles[tostring(model:GetAttribute("CloneId"))] = e(CloneTile, {
			model = model,
			index = index,
			selected = selection.isSelected(model),
			group = groupOf[model],
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 0),
		Size = UDim2.fromOffset(240, 400),
		BackgroundColor3 = colors.panel,
	}, {
		Corner = corner(14),
		Outline = outline(4),
		Shade = shade(),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),

		Icon = e(Icon, { size = UDim2.fromOffset(44, 44), image = icons.friends }),
		Title = e(Label, {
			position = UDim2.fromOffset(52, 0),
			size = UDim2.new(1, -52, 0, 26),
			alignment = Enum.TextXAlignment.Left,
			text = "Clones",
			textSize = 26,
			outlineThickness = 2,
		}),
		Subtitle = e(Label, {
			position = UDim2.fromOffset(52, 26),
			size = UDim2.new(1, -52, 0, 18),
			alignment = Enum.TextXAlignment.Left,
			text = #clones .. " total  ·  " .. selectedCount .. " selected",
			textSize = 14,
		}),

		Actions = e("Frame", {
			Position = UDim2.fromOffset(0, 56),
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			All = e(Button, {
				layoutOrder = 1,
				size = UDim2.new(0.5, -4, 1, 0),
				color = colors.green,
				text = "All",
				onActivated = function()
					for _, model in clones do
						selection.select(model)
					end
				end,
			}),
			None = e(Button, {
				layoutOrder = 2,
				size = UDim2.new(0.5, -4, 1, 0),
				color = colors.red,
				text = "None",
				onActivated = selection.clear,
			}),
		}),

		List = if #clones > 0
			then e("ScrollingFrame", {
				Position = UDim2.fromOffset(-3, 100),
				Size = UDim2.new(1, 6, 1, -100),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = colors.outline,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, tiles)
			else e(Label, {
				position = UDim2.fromOffset(0, 100),
				size = UDim2.new(1, 0, 0, 60),
				text = "Right click the ground\nto spawn a clone!",
				textSize = 16,
			}),
	})
end

-- Clicking a slot selects that group, shift + clicking saves the current selection to it, same as the number keys.
local function GroupSlot(props)
	local group = props.group
	local count = props.count

	return e("TextButton", {
		LayoutOrder = group,
		Size = UDim2.fromOffset(54, 62),
		AutoButtonColor = true,
		BackgroundColor3 = props.active and colors.selected or colors.tile,
		BackgroundTransparency = count == 0 and 0.4 or 0,
		Text = "",
		[React.Event.Activated] = function()
			if isShiftDown() then
				selection.saveGroup(group)
			else
				selection.selectGroup(group)
			end
		end,
	}, {
		Corner = corner(10),
		Outline = outline(props.active and 3 or 2.5),
		Shade = shade(),
		Key = e(Label, {
			position = UDim2.fromOffset(6, 2),
			size = UDim2.fromOffset(14, 18),
			alignment = Enum.TextXAlignment.Left,
			text = tostring(group),
			textSize = 16,
		}),
		Portrait = count > 0 and e(Portrait, { position = UDim2.fromOffset(27, 14), size = UDim2.fromOffset(30, 30) }),
		Empty = count == 0 and e(Icon, {
			anchorPoint = Vector2.new(0.5, 0),
			position = UDim2.fromOffset(27, 16),
			size = UDim2.fromOffset(28, 28),
			image = icons.helmet,
			transparency = 0.6,
		}),
		Count = count > 0 and e(Label, {
			position = UDim2.new(0, 0, 1, -18),
			size = UDim2.new(1, 0, 0, 16),
			text = "×" .. count,
			textSize = 14,
		}),
	})
end

local function GroupBar()
	useSelectionChanged()

	local selected = selection.getSelected()

	local slots = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Icon = e(Icon, { size = UDim2.fromOffset(44, 44), image = icons.sword }),
	}
	for group = 1, groupCount do
		local members = selection.getGroup(group)

		-- A group is active when exactly its clones are selected.
		local active = #members > 0 and #members == #selected
		for _, model in members do
			if not selection.isSelected(model) then
				active = false
			end
		end

		slots["Group" .. group] = e(GroupSlot, { group = group, count = #members, active = active })
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(0, 62),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = colors.panel,
	}, {
		Corner = corner(14),
		Outline = outline(4),
		Shade = shade(),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
		}),
		Slots = e("Frame", {
			Size = UDim2.fromScale(0, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, slots),
		Hint = e(Label, {
			anchorPoint = Vector2.new(0.5, 1),
			position = UDim2.new(0.5, 0, 0, -14),
			size = UDim2.new(1, 0, 0, 16),
			text = "Shift + 1-9 to save a group  ·  1-9 to select it",
			textSize = 14,
		}),
	})
end

local function App()
	return e(React.Fragment, nil, {
		ClonePanel = e(ClonePanel),
		GroupBar = e(GroupBar),
	})
end

-- Mount React into a ScreenGui. ResetOnSpawn = false keeps the UI when the character respawns.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "UI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

ReactRoblox.createRoot(screenGui):render(e(App))
