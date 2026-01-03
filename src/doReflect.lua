--!strict
--!nolint DeprecatedApi

local plugin = script:FindFirstAncestorWhichIsA("Plugin")
assert(plugin, [[
This module can only reflect Unions when used in a plugin because the separate API
is only available as plugin:Separate. The code will still work outside a plugin,
but only treat unions as basic square parts. Remove this assert to acknowledge.
]])

local querydescendants = require("./queryDescendants")
local copyPartProps = require("./copyPartProps")

type ParamsInternal = {
	WarnAt: number,
	CutoffAt: number,
	TimedOut: boolean,
}

local hasGivenStillWorkingMessage = false
local function tooLongCheck(params: ParamsInternal)
	local now = os.clock()
	if not hasGivenStillWorkingMessage and now > params.WarnAt then
		hasGivenStillWorkingMessage = true
		warn("Reflecting is taking a long time... will continue for " .. (params.CutoffAt - params.WarnAt) .. " more seconds.")
		task.wait(0.1)
	end
	if now > params.CutoffAt then
		error("Reflecting took too long. Modify the fail after setting to allow more time.")
	end
end

type OldCFrameMap = {
	[BasePart | Attachment | Model]: CFrame,
}

local function reflectVec(v: Vector3, axis: Vector3)
	return v - 2*(axis*v:Dot(axis))
end

local function ReflectCFrame(cf: CFrame, overCFrame: CFrame, corner: boolean, attachment: boolean)
	-- Mirroring characteristics
	local mirrorPoint = overCFrame.Position
	local mirrorAxis = overCFrame.LookVector

	-- Break to components
	local position = cf.Position
	local x, y, z = position.X, position.Y, position.Z

	-- Mirror position
	local newPos =
		mirrorPoint +
		reflectVec(Vector3.new(x, y, z) - mirrorPoint, mirrorAxis)

	-- Get rotation axis components
	local xAxis = cf.XVector
	local yAxis = cf.YVector
	local zAxis = cf.ZVector

	-- Mirror them
	xAxis = reflectVec(xAxis, mirrorAxis)
	yAxis = reflectVec(yAxis, mirrorAxis)
	zAxis = reflectVec(zAxis, mirrorAxis)

	-- Handedness fix
	if attachment then
		-- For attachments, the X and Y axis are the actively used ones that
		-- we want to preserve.
		zAxis = -zAxis
	else
		-- X axis chosen so that WedgeParts will work
		xAxis = -xAxis
	end

	-- Corner fix
	if corner then
		xAxis, zAxis = -zAxis, xAxis
	end

	-- Reconstitute
	return CFrame.new(newPos.X, newPos.Y, newPos.Z,
		xAxis.X,  yAxis.X,  zAxis.X,
		xAxis.Y,  yAxis.Y,  zAxis.Y,
		xAxis.Z,  yAxis.Z,  zAxis.Z)
end

local function IsCornerWedge(part: BasePart)
	local mesh = part:FindFirstChildWhichIsA('SpecialMesh')
	if mesh and mesh.MeshType == Enum.MeshType.CornerWedge then
		return true
	end
	if part:IsA("Part") and part.Shape == Enum.PartType.CornerWedge then
		return true
	end
	return part:IsA('CornerWedgePart')
end

type FaceItem = {
	Face: Enum.NormalId,
}

local function ToFaceItem(instance: Instance): FaceItem?
	if instance:IsA('FaceInstance') or instance:IsA('SurfaceGui') or 
		instance:IsA('SurfaceLight') or instance:IsA('SpotLight') then
		return instance :: any
	else
		return nil
	end
end

local function ReflectFaceItems(part: BasePart)
	for _, ch in part:GetChildren() do
		local faceItem = ToFaceItem(ch)
		if faceItem then
			if IsCornerWedge(part) then
				if faceItem.Face == Enum.NormalId.Left then
					faceItem.Face = Enum.NormalId.Back
				elseif faceItem.Face == Enum.NormalId.Right then
					faceItem.Face = Enum.NormalId.Front
				elseif faceItem.Face == Enum.NormalId.Front then
					faceItem.Face = Enum.NormalId.Right
				elseif faceItem.Face == Enum.NormalId.Back then
					faceItem.Face = Enum.NormalId.Left
				end
			else
				if faceItem.Face == Enum.NormalId.Left then
					faceItem.Face = Enum.NormalId.Right
				elseif faceItem.Face == Enum.NormalId.Right then
					faceItem.Face = Enum.NormalId.Left
				end
			end
		end
	end
end

local function ReflectRawPart(part: BasePart, axis: CFrame)
	local isCorner = IsCornerWedge(part)
	part.CFrame = ReflectCFrame(part.CFrame, axis, isCorner, false)
	if isCorner then
		part.BackSurface, part.FrontSurface, part.RightSurface, part.LeftSurface =
			part.LeftSurface, part.RightSurface, part.FrontSurface, part.BackSurface

		-- Added 18/12/19: Thanks TheNexusAvenger for this fix
		part.Size = Vector3.new(part.Size.Z, part.Size.Y, part.Size.X)
	else
		part.RightSurface, part.LeftSurface = part.LeftSurface, part.RightSurface
	end
	ReflectFaceItems(part)
	return part
end

-- Wrappers to fix typing
local function NegateUnion(part: BasePart): BasePart
	return plugin:Negate({part})[1] :: BasePart
end
local function SeparateUnion(part: UnionOperation | IntersectOperation): {BasePart}
	return plugin:Separate({part}) :: {BasePart}
end
local function UnionTogether(parts: {BasePart}): UnionOperation
	return plugin:Union((parts :: any) :: {Instance}) :: UnionOperation
end
local function IntersectTogether(parts: {BasePart}): IntersectOperation
	return plugin:Intersect((parts :: any) :: {Instance}) :: IntersectOperation
end

local function copyUnionProperties(from: PartOperation, to: PartOperation)
	to.UsePartColor = from.UsePartColor
	to.SmoothingAngle = from.SmoothingAngle
	copyPartProps(from, to)
end

local function GetSiblings(instance: Instance): {Instance}
	local parent = instance.Parent
	if parent then
		return parent:GetChildren()
	else
		return {}
	end
end

local function ReflectPart(part: BasePart, axis: CFrame, replacementPartMap: {[BasePart]: BasePart}, unionDepth: number, unionPath: string, params: ParamsInternal): BasePart?
	if unionDepth > 10 then
		print(unionDepth, unionPath)
		return nil
	end
	tooLongCheck(params)
	if plugin and part:IsA('UnionOperation') or part:IsA("IntersectOperation") then
		local isIntersection = part:IsA("IntersectOperation")
		
		-- Need to reparent the children to the reflected union
		local children = part:GetChildren()
		for _, ch in children do
			ch.Parent = nil
		end
		
		local oldSiblings = GetSiblings(part)
		local st1, err1 = pcall(function()
			return SeparateUnion(part)
		end)

		if st1 then
			local subParts: {BasePart} = err1
			for i, subPart in subParts do
				local newPart = ReflectPart(subPart, axis, replacementPartMap, unionDepth + 1, unionPath .. "." .. subPart.Name, params)
				if newPart then
					table.insert(subParts, newPart)
				end
			end

			local st2, err2 = pcall(function()
				local result = if isIntersection then IntersectTogether(subParts) else UnionTogether(subParts)
				copyUnionProperties(part, result)
				replacementPartMap[part] = result
				return result
			end)
			if st2 then
				local reflectedUnion = err2
				-- Reparent the stuff
				for _, ch in children do
					ch.Parent = reflectedUnion
				end
				-- Flip the face items
				ReflectFaceItems(reflectedUnion)
				return reflectedUnion -- err is the returned union
			else
				local errString = (err2 :: any) :: string
				local firstPart = subParts[1]
				if firstPart then
					warn("Error Unioning `"..firstPart:GetFullName().."`: "..errString)
				else
					warn("`"..part:GetFullName().."` contained an empty union, discarding it.")
				end
				-- Put back the children
				for _, ch in children do
					ch.Parent = part
				end
				ReflectRawPart(part, axis)
				return part
			end
		else
			local errString = (err1 :: any) :: string
			-- Separating may still create extra instances that weren't there
			-- before even in the case where the separate fails, so we need to
			-- have this extra code to remove those instances.
			local oldSiblingsSet = {}
			for _, ch in oldSiblings do
				oldSiblingsSet[ch] = true
			end
			for _, newSibling in GetSiblings(part) do
				if not oldSiblingsSet[newSibling] then
					newSibling:Destroy()
				end
			end

			warn("Error Separating `"..part:GetFullName().."`: "..errString)
			-- Put back the children
			for _, ch in children do
				ch.Parent = part
			end
			ReflectRawPart(part, axis)
			return part
		end
	elseif plugin and part:IsA('NegateOperation') then
		-- Negate itself should never fail
		local notNegated = NegateUnion(part)
		local reflected = ReflectPart(notNegated, axis, replacementPartMap, unionDepth + 1, unionPath, params)
		if reflected then
			local reNegated = NegateUnion(reflected)
			replacementPartMap[part] = reNegated
			return reNegated
		else
			return nil
		end
	else
		ReflectRawPart(part, axis)
		return part
	end
end

local function RecordModelAndAttachmentCFrames(root: Instance, oldCFrameMap: OldCFrameMap)
	-- Parts must be recorded separately as they may need to be replaced with a different part
	-- in the case of Unions that need to be separated to be reflected.
	if root:IsA("Model") then
		oldCFrameMap[root] = root:GetPivot()
	elseif root:IsA("Attachment") then
		oldCFrameMap[root] = root.WorldCFrame
	end
	for _, model in querydescendants(root, "Model") do
		oldCFrameMap[model] = model:GetPivot()
	end
	for _, attachment in querydescendants(root, "Attachment") do
		oldCFrameMap[attachment] = attachment.WorldCFrame
	end
end

local function ReflectPartsAndModelsRecursive(instance: Instance, axis: CFrame, oldCFrameMap: OldCFrameMap, modelPrimaryPartMap: {[Model]: BasePart?}, replacementPartMap: {[BasePart]: BasePart}, params: ParamsInternal)
	tooLongCheck(params)
	if instance:IsA("BasePart") then
		local oldCFrame = instance.CFrame
		local reflected = ReflectPart(instance, axis, replacementPartMap, 0, "MODEL", params)
		if reflected then
			oldCFrameMap[reflected] = oldCFrame
		end
	elseif instance:IsA("Model") then
		modelPrimaryPartMap[instance] = instance.PrimaryPart
		instance.WorldPivot = ReflectCFrame(instance.WorldPivot, axis, false, false)
	end
	for _, ch in instance:GetChildren() do
		ReflectPartsAndModelsRecursive(ch, axis, oldCFrameMap, modelPrimaryPartMap, replacementPartMap, params)
	end
end

local function patchProperty(instance: Instance, replacementPartMap: {[BasePart]: BasePart}, property: string)
	local value = (instance :: any)[property]
	if value and replacementPartMap[value] then
		(instance :: any)[property] = replacementPartMap[value]
	end
end

-- Reflecting parts may require destoying and recreating them in the case where
-- they're UnionOperations (CSG parts), in this case we need to fix up properties
-- that refered to those parts.
-- We won't do all properties, but only the ones that typically matter (Part0
-- and Part1 of welds)
local function PatchReplacementPartsRecursive(instance: Instance, replacementPartMap: {[BasePart]: BasePart}, primaryPartMap: {[Model]: BasePart}, params: ParamsInternal)
	tooLongCheck(params)
	if instance:IsA("WeldConstraint") or instance:IsA("JointInstance") or instance:IsA("NoCollisionConstraint") then
		patchProperty(instance, replacementPartMap, "Part0")
		patchProperty(instance, replacementPartMap, "Part1")
	elseif instance:IsA("ObjectValue") then
		patchProperty(instance, replacementPartMap, "Value")
	elseif instance:IsA("Model") then
		local oldPrimary = primaryPartMap[instance]
		if oldPrimary and replacementPartMap[oldPrimary] then
			instance.PrimaryPart = replacementPartMap[oldPrimary]
		end
	end
	for _, ch in instance:GetChildren() do
		PatchReplacementPartsRecursive(ch, replacementPartMap, primaryPartMap, params)
	end	
end

local function GetReferenceInstance(attachment: Attachment): Instance?
	local parent = attachment.Parent
	while parent do
		if parent:IsA("Attachment") or parent:IsA("PVInstance") then
			return parent
		end
		parent = parent.Parent
	end
	return nil
end

local function ReflectPartRelativeInstancesRecursive(instance: Instance, axis: CFrame, oldCFrameMap: OldCFrameMap, params: ParamsInternal)
	tooLongCheck(params)
	if instance:IsA("Attachment") then
		local reference = GetReferenceInstance(instance)
		if reference then
			local oldReference: CFrame
			local newReference: CFrame
			if reference:IsA("BasePart") then
				oldReference = oldCFrameMap[reference]
				newReference = reference.CFrame
			elseif reference:IsA("Model") then
				if reference.PrimaryPart then
					oldReference = oldCFrameMap[reference.PrimaryPart]
					assert(oldReference, "Should have an old CFrame for primary part")
					newReference = reference.PrimaryPart:GetPivot()
				else
					-- (old WorldPivot is in the oldCFrameMap for models)
					oldReference = oldCFrameMap[reference]
					assert(oldReference, "Should have an old WorldPivot for model")
					newReference = reference.WorldPivot
				end
			elseif reference:IsA("Camera") then
				-- Same because we don't reflect cameras
				oldReference = reference.CFrame
				newReference = reference.CFrame
			elseif reference:IsA("Attachment") then
				-- Attachments are simple. This works because we start at the top of the tree.
				-- The reference must be an ancestor and we must have completed putting the
				-- ancestors in the correct position before we get to this.
				oldReference = oldCFrameMap[reference]
				assert(oldReference, "Should have an oldCFrame for attachment")
				newReference = reference.WorldCFrame
			else
				warn("Didn't understand how to reflect an attachment relative to a `"..reference.ClassName.."`")
				oldReference = CFrame.identity
				newReference = CFrame.identity
			end
			local oldWorldCFrame = oldReference:ToWorldSpace(instance.CFrame)
			instance.CFrame = newReference:ToObjectSpace(ReflectCFrame(oldWorldCFrame, axis, false, true))	
		end
	elseif instance:IsA("JointInstance") then
		local joint = instance
		local part0 = joint.Part0
		local part1 = joint.Part1
		if part0 and part1 then
			local c0World = oldCFrameMap[part0]:ToWorldSpace(joint.C0)
			joint.C0 = part0.CFrame:ToObjectSpace(ReflectCFrame(c0World, axis, false, false))
			--
			local c1World = oldCFrameMap[part1]:ToWorldSpace(joint.C1)
			joint.C1 = part1.CFrame:ToObjectSpace(ReflectCFrame(c1World, axis, false, false))
		end
	end
	for _, ch in instance:GetChildren() do
		ReflectPartRelativeInstancesRecursive(ch, axis, oldCFrameMap, params)
	end
end

type HasEnabled = {
	Enabled: boolean,
}

type ReenableData = boolean | {
	[number]: CFrame,
}

local function DisableJointsRecursive(instance: Instance, reenableJoints: {[HasEnabled]: ReenableData}, params: ParamsInternal)
	tooLongCheck(params)
	if instance:IsA("WeldConstraint") or instance:IsA("JointInstance") or instance:IsA("Constraint") then
		local instanceWithEnabled = (instance :: any) :: HasEnabled
        if instanceWithEnabled.Enabled then
			instanceWithEnabled.Enabled = false
			if instance:IsA("JointInstance") then
				local part0, part1 = instance.Part0, instance.Part1
				if part0 and part1 then
					reenableJoints[instanceWithEnabled] = {part0.CFrame, part1.CFrame}
				else
					reenableJoints[instanceWithEnabled] = true
				end
			else
				-- Lie about the type, they all have Enabled anyways
				reenableJoints[instanceWithEnabled] = true
			end
		end
	end
	for _, ch in instance:GetChildren() do
		DisableJointsRecursive(ch, reenableJoints, params)
	end
end

local function ReenableJoints(jointsToReenable: {[HasEnabled]: ReenableData})
	for joint, cframes in jointsToReenable do
		joint.Enabled = true
	end
end

export type Params = {
	Origin: Vector3,
	Normal: Vector3,
	CutoffDelay: number?,
}

local function doReflect(toReflect: {Instance}, params: Params): boolean
	hasGivenStillWorkingMessage = false
	local axis = CFrame.lookAlong(params.Origin, params.Normal)
	local cutoffDelay = params.CutoffDelay or math.huge
	local paramsInternal = {
		WarnAt = os.clock() + math.min(2, 0.5 * cutoffDelay),
		CutoffAt = os.clock() + cutoffDelay,
		TimedOut = false,
	}
	local success, err = pcall(function()
		for i, instance in toReflect do
			local jointsToReenable = {} :: {[HasEnabled]: ReenableData}
			local oldCFrameMap = {} :: OldCFrameMap
			local replacementPartMap = {} :: {[BasePart]: BasePart}
			local primaryPartMap = {} :: {[Model]: BasePart}
			RecordModelAndAttachmentCFrames(instance, oldCFrameMap)
			DisableJointsRecursive(instance, jointsToReenable, paramsInternal)
			ReflectPartsAndModelsRecursive(instance, axis, oldCFrameMap, primaryPartMap, replacementPartMap, paramsInternal)
			PatchReplacementPartsRecursive(instance, replacementPartMap, primaryPartMap, paramsInternal)
			ReflectPartRelativeInstancesRecursive(instance, axis, oldCFrameMap, paramsInternal)
			ReenableJoints(jointsToReenable)
		end
	end)
	if not success then
		warn("Error reflecting parts: " .. err)
	end
	return success
end

return doReflect
