--!strict

local CoreGui = game:GetService("CoreGui")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")
local DraggerService = game:GetService("DraggerService")

local Packages = script.Parent.Parent.Packages

local DraggerFramework = require(Packages.DraggerFramework)
local DraggerSchemaCore = require(Packages.DraggerSchemaCore)
local DraggerContext_PluginImpl = (require :: any)(DraggerFramework.Implementation.DraggerContext_PluginImpl)
--local Roact = require(Packages.Roact)
local Signal = require(Packages.Signal)

local Settings = require("./Settings")
local doReflect = require("./doReflect")

export type SessionState = {
}

local function spin(v: Vector3)
	if v:FuzzyEq(Vector3.yAxis) then
		return Vector3.zAxis
	else
		return Vector3.yAxis
	end
end

local function createFixedSelection(selection: { Instance })
	local selectionChangedSignal = Signal.new()
	return {
		Get = function()
			return selection
		end,
		Set = function(newSelection, _hint)
			task.defer(function()
				selectionChangedSignal:Fire()
			end)
		end,
		SelectionChanged = selectionChangedSignal,
	}
end

local function createSurfaceDisplay(): (Instance, BasePart)
	local folder = Instance.new("Folder")
	local part = Instance.new("Part", folder)
	part.Name = "Display"
	--
	local height = 2
	local width = 4
	--
	local boxHandleAdornment = Instance.new("BoxHandleAdornment", folder)
	boxHandleAdornment.Size = Vector3.new(width, 0.1, width)
	boxHandleAdornment.Transparency = 0.7
	boxHandleAdornment.Adornee = part
	boxHandleAdornment.ZIndex = 0
	boxHandleAdornment.Color3 = Color3.new(0, 0, 1)
	--
	local axis = Instance.new("CylinderHandleAdornment", folder)
	axis.CFrame = CFrame.fromEulerAnglesXYZ(math.pi/2, 0, 0) * CFrame.new(0, 0, -0.5 * height)
	axis.Height = height
	axis.Radius = 0.1
	axis.Adornee = part
	axis.ZIndex = 0
	axis.Color3 = Color3.new(0, 0, 1)
	--
	local arrow = Instance.new("ConeHandleAdornment", folder)
	arrow.CFrame = CFrame.fromEulerAnglesXYZ(math.pi/2, 0, 0) * CFrame.new(0, 0, -height)
	arrow.Height = 1
	arrow.Radius = 0.3
	arrow.Adornee = part
	arrow.ZIndex = 0
	arrow.Color3 = Color3.new(0, 0, 1)
	--
	for x = -2, 2 do
		axis = Instance.new("CylinderHandleAdornment", folder)
		axis.CFrame = CFrame.new(x, 0, 0)
		axis.Height = width + 0.5
		axis.Radius = 0.05
		axis.Adornee = part
		axis.ZIndex = 0
		axis.Color3 = Color3.new(0, 0, 1)
	end
	--
	for x = -2, 2 do
		axis = Instance.new("CylinderHandleAdornment", folder)
		axis.CFrame = CFrame.fromEulerAnglesXYZ(0, math.pi/2, 0) * CFrame.new(x, 0, 0)
		axis.Height = width + 0.5
		axis.Radius = 0.05
		axis.Adornee = part
		axis.ZIndex = 0
		axis.Color3 = Color3.new(0, 0, 1)
	end
	--
	return folder, part
end

-- Shows infinite extensions colored on each axis using a WireframeHandleAdornment
local function createAxisDisplay(): (Instance, BasePart)
	local folder = Instance.new("Folder")
	local part = Instance.new("Part", folder)
	part.Name = "AxisDisplay"
	--
	local onTopAdornment = Instance.new("WireframeHandleAdornment")
	onTopAdornment.Adornee = part
	onTopAdornment.ZIndex = 0
	onTopAdornment.AlwaysOnTop = true
	onTopAdornment.Transparency = 0.5
	onTopAdornment.Parent = folder
	local solidAdornment = Instance.new("WireframeHandleAdornment")
	solidAdornment.Adornee = part
	solidAdornment.ZIndex = 0
	solidAdornment.Parent = folder
	--
	local function addAxes(wireframe: WireframeHandleAdornment)
		wireframe.Color3 = Color3.new(1, 0, 0)
		wireframe:AddLine(-Vector3.xAxis * 5000, Vector3.xAxis * 5000)
		wireframe.Color3 = Color3.new(0, 1, 0)
		wireframe:AddLine(-Vector3.yAxis * 5000, Vector3.yAxis * 5000)
		wireframe.Color3 = Color3.new(0, 0, 1)
		wireframe:AddLine(-Vector3.zAxis * 5000, Vector3.zAxis * 5000)
	end
	addAxes(onTopAdornment)
	addAxes(solidAdornment)
	--
	return folder, part
end

local function startRecording(): string?
	return ChangeHistoryService:TryBeginRecording("RedupeChanges", "Redupe Changes")
end
local function stopRecording(id: string)
	local existingSelection = Selection:Get()
	ChangeHistoryService:FinishRecording(id, Enum.FinishRecordingOperation.Cancel)
	-- Finish recording may clobber the selection when using cancel mode, manually
	-- preserve the selection we had. Cancelling may have removed something that
	-- was selected but Set is tolerant of that.
	Selection:Set(existingSelection)
end

type ReflectBasis = {
	Origin: Vector3,
	Normal: Vector3,
}

local function createModelReflectSession(plugin: Plugin, targets: { Instance }, currentSettings: Settings.ModelReflectSettings, previousState: SessionState?)
	local session = {}
	local changeSignal = Signal.new()
	local doneSignal = Signal.new()

	local fixedSelection = createFixedSelection(targets)

	-- Context
	local draggerContext = DraggerContext_PluginImpl.new(
		plugin,
		game,
		settings(),
		fixedSelection
	)

	-- Show the pivot as part of the axis display
	local oldPivotShown = DraggerService.ShowPivotIndicator
	DraggerService.ShowPivotIndicator = true

	local axisDisplay, axisDisplayPart = createAxisDisplay()
	axisDisplay.Parent = CoreGui
	
	local function computeCenterOfTargets(): CFrame
		local info = DraggerSchemaCore.SelectionInfo.new(draggerContext, targets)
		local center, _, _ = info:getLocalBoundingBox()
		axisDisplayPart.CFrame = center
		return center
	end
	local currentCenter = computeCenterOfTargets()

	local adorn, adornPart = createSurfaceDisplay()

	local currentBasis: ReflectBasis? = nil

	local recordingInProgress = startRecording()

	local isOverUI = false
	local function updateHover()
		if not isOverUI then
			local mouseAt = UserInputService:GetMouseLocation()
			local mouseRay = workspace.CurrentCamera:ScreenPointToRay(mouseAt.X, mouseAt.Y)
			local result = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 5000)
			if result and not result.Instance.Locked then
				adorn.Parent = CoreGui
				local normal = result.Normal
				local at = result.Position
				local back = spin(normal):Cross(normal).Unit
				adornPart.CFrame = CFrame.fromMatrix(at, back, normal)
				currentBasis = {
					Origin = at,
					Normal = normal,
				}
				return
			end
		end
		adorn.Parent = nil
		currentBasis = nil
	end

	local inputChangedCn = UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			isOverUI = gameProcessed
		end
	end)
	-- Need at least one frame of delay before connecting this to avoid getting
	-- the same click as the draggers selecting the target.
	local inputBeganCn
	local delayedBeginCn = task.delay(0, function()
		inputBeganCn = UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
				updateHover()
				doneSignal:Fire()
			end
		end)
	end)
	local cursorTargetTask = task.spawn(function()
		while true do
			updateHover()
			task.wait()
		end
	end)

	local function teardown()
		inputChangedCn:Disconnect()
		if inputBeganCn then
			inputBeganCn:Disconnect()
		end
		task.cancel(delayedBeginCn)
		task.cancel(cursorTargetTask)
		adorn:Destroy()
		axisDisplay:Destroy()
		DraggerService.ShowPivotIndicator = oldPivotShown
		if recordingInProgress then
			stopRecording(recordingInProgress)
			recordingInProgress = nil
		end
	end

	local function reflectTargets(targets: {Instance}, basis: ReflectBasis): (boolean, string?)
		return doReflect(targets, {
			Origin = basis.Origin,
			Normal = basis.Normal,
			CutoffDelay = currentSettings.CutoffDelay,
			MaxUnionDepth = currentSettings.MaxUnionDepth,
		})
	end

	session.GetState = function(): SessionState
		return {
		}
	end
	session.Update = function()
		
	end
	session.FlipAroundPivot = function(axis: Vector3): (boolean, string?)
		local success, warning = reflectTargets(targets, {
			Origin = currentCenter.Position,
			Normal = currentCenter:VectorToWorldSpace(axis),
			CutoffDelay = currentSettings.CutoffDelay,
		})
		if not success then
			-- Cancel the recording to undo any partial changes
			if recordingInProgress then
				stopRecording(recordingInProgress)
				recordingInProgress = startRecording()
			end
			return false
		end

		changeSignal:Fire()

		-- Start new waypoint
		if recordingInProgress then
			ChangeHistoryService:FinishRecording(recordingInProgress, Enum.FinishRecordingOperation.Commit)
		else
			warn("Redupe: ChangeHistory Recording failed, fall back to adding waypoint.")
			ChangeHistoryService:SetWaypoint("Redupe Changes")
		end
		recordingInProgress = startRecording()
		return true, warning
	end
	session.ReflectOverTarget = function(): (boolean, string?)
		if currentBasis then
			local newTargets = {}
			for i, target in targets do
				local copy = target:Clone()
				copy.Parent = target.Parent
				newTargets[i] = copy
			end
			local success, warning = reflectTargets(newTargets, currentBasis)
			if not success then
				-- Cancel the recording to undo any partial changes
				if recordingInProgress then
					stopRecording(recordingInProgress)
					recordingInProgress = startRecording()
				end
				return false, warning
			end
			if currentSettings.SelectReflectedCopy then
				Selection:Set(newTargets)
			end

			-- Successfully complete the recording
			if recordingInProgress then
				ChangeHistoryService:FinishRecording(recordingInProgress, Enum.FinishRecordingOperation.Commit)
			else
				warn("Redupe: ChangeHistory Recording failed, fall back to adding waypoint.")
				ChangeHistoryService:SetWaypoint("Redupe Changes")
			end
			recordingInProgress = nil
			return true, warning
		end
		teardown()
		return true, nil
	end
	session.Destroy = function()
		teardown()
	end
	session.ChangeSignal = changeSignal
	session.DoneSignal = doneSignal

	-- Restore previous state if requested
	if previousState then
		-- TODO: Use it
		session.Update()
	end

	return session
end

export type ModelReflectSession = typeof(createModelReflectSession(...))

return createModelReflectSession