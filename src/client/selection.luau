-- Tracks the local player's clones, which of them are selected and their control groups, shared by the input and UI scripts.

-- Variables:
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local selection = {}

local clones = {} -- [Model] = true, every clone this player owns
local selectedClones = {} -- [Model] = Highlight
local groups = {} -- [group number] = { [Model] = true }
local changedEvent = Instance.new("BindableEvent")
local changePending = false

-- Fires once after any clones are added or removed, the selection changes or a group is saved.
selection.changed = changedEvent.Event

-- Batches changes made in the same frame, e.g. selecting a whole group, into one changed event.
local function notifyChanged()
	if changePending then return end
	changePending = true

	task.defer(function()
		changePending = false
		changedEvent:Fire()
	end)
end

-- Selection:
-- Outlines the clone and adds it to the selection.
function selection.select(model)
	if selectedClones[model] then return end

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.7
	highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
	highlight.Adornee = model
	highlight.Parent = model
	selectedClones[model] = highlight
	notifyChanged()
end

-- Removes the outline and takes the clone out of the selection.
function selection.deselect(model)
	local highlight = selectedClones[model]
	if not highlight then return end

	highlight:Destroy()
	selectedClones[model] = nil
	notifyChanged()
end

function selection.toggle(model)
	if selectedClones[model] then
		selection.deselect(model)
	else
		selection.select(model)
	end
end

-- Deselects every clone.
function selection.clear()
	for model in selectedClones do
		selection.deselect(model)
	end
end

function selection.isSelected(model)
	return selectedClones[model] ~= nil
end

function selection.hasSelection()
	return next(selectedClones) ~= nil
end

function selection.getSelected()
	local models = {}
	for model in selectedClones do
		table.insert(models, model)
	end
	return models
end

-- Turns a { [Model] = true } set into a list, oldest clone first.
local function toSortedList(set)
	local models = {}
	for model in set do
		table.insert(models, model)
	end
	table.sort(models, function(a, b)
		return a:GetAttribute("CloneId") < b:GetAttribute("CloneId")
	end)
	return models
end

-- Control groups:
-- Saves the current selection under this group number, saving an empty selection clears the group.
function selection.saveGroup(group)
	local members = {}
	for model in selectedClones do
		members[model] = true
	end
	groups[group] = next(members) and members or nil
	notifyChanged()
end

-- Replaces the selection with the clones saved in this group.
function selection.selectGroup(group)
	local members = groups[group]
	if not members then return end

	selection.clear()
	for model in members do
		selection.select(model)
	end
end

-- Returns the clones in this group, oldest first.
function selection.getGroup(group)
	return toSortedList(groups[group] or {})
end

-- Clones:
-- Returns every clone this player owns, oldest first.
function selection.getClones()
	return toSortedList(clones)
end

-- The server sets CloneId and OwnerId before parenting, so they're already there when the clone appears.
local function onChildAdded(child)
	if child:IsA("Model") and child:GetAttribute("CloneId") and child:GetAttribute("OwnerId") == player.UserId then
		clones[child] = true
		notifyChanged()
	end
end

-- Forget clones when they're removed, e.g. when they die.
local function onChildRemoved(child)
	if not clones[child] then return end

	clones[child] = nil
	selection.deselect(child)
	for group, members in groups do
		members[child] = nil
		if not next(members) then
			groups[group] = nil
		end
	end
	notifyChanged()
end

game.Workspace.ChildAdded:Connect(onChildAdded)
game.Workspace.ChildRemoved:Connect(onChildRemoved)
for _, child in game.Workspace:GetChildren() do
	onChildAdded(child)
end

return selection
