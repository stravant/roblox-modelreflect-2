local TestTypes = require("./TestTypes")

local doReflect = require("./doReflect")

local function defaultParams(overrides: { [string]: any }?): doReflect.Params
	local params = {
		Origin = Vector3.zero,
		Normal = Vector3.xAxis,
		CutoffDelay = 10,
		MaxUnionDepth = 10,
	}
	if overrides then
		for k, v in overrides do
			(params :: any)[k] = v
		end
	end
	return params
end

local function makePart(cf: CFrame?, size: Vector3?): BasePart
	local part = Instance.new("Part")
	part.CFrame = cf or CFrame.identity
	part.Size = size or Vector3.new(2, 2, 2)
	part.Anchored = true
	part.Parent = workspace
	return part
end

local function makeModel(parts: { { cf: CFrame, size: Vector3? } }): Model
	local model = Instance.new("Model")
	for i, info in parts do
		local part = Instance.new("Part")
		part.Name = `Part{i}`
		part.CFrame = info.cf
		part.Size = info.size or Vector3.new(2, 2, 2)
		part.Anchored = true
		part.Parent = model
	end
	model.Parent = workspace
	return model
end

return function(t: TestTypes.TestContext)
	--
	-- Basic position reflection
	--

	t.test("reflects part position over YZ plane (X normal) at origin", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local success = doReflect({ part }, defaultParams())
		t.expect(success).toBe(true)
		t.expect(part.Position:FuzzyEq(Vector3.new(-5, 0, 0), 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("reflects part position over XZ plane (Y normal) at origin", function()
		local part = makePart(CFrame.new(0, 7, 0))
		local success = doReflect({ part }, defaultParams({ Normal = Vector3.yAxis }))
		t.expect(success).toBe(true)
		t.expect(part.Position:FuzzyEq(Vector3.new(0, -7, 0), 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("reflects part position over XY plane (Z normal) at origin", function()
		local part = makePart(CFrame.new(0, 0, 3))
		local success = doReflect({ part }, defaultParams({ Normal = Vector3.zAxis }))
		t.expect(success).toBe(true)
		t.expect(part.Position:FuzzyEq(Vector3.new(0, 0, -3), 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("reflects part position over plane at non-origin point", function()
		-- Plane at X=10, normal X. Part at X=15 is 5 units away, should end at X=5.
		local part = makePart(CFrame.new(15, 3, 0))
		local success = doReflect({ part }, defaultParams({ Origin = Vector3.new(10, 0, 0) }))
		t.expect(success).toBe(true)
		t.expect(part.Position:FuzzyEq(Vector3.new(5, 3, 0), 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("part on the reflection plane stays in place", function()
		local part = makePart(CFrame.new(0, 5, 3))
		local success = doReflect({ part }, defaultParams())
		t.expect(success).toBe(true)
		-- X=0 is on the YZ plane, so position should stay the same
		t.expect(part.Position:FuzzyEq(Vector3.new(0, 5, 3), 0.01)).toBe(true)
		part:Destroy()
	end)

	--
	-- Rotation reflection
	--

	t.test("reflects Y rotation around X normal", function()
		-- Part rotated 45 degrees around Y, reflected over YZ plane
		-- should become -45 degrees around Y
		local part = makePart(CFrame.new(5, 0, 0) * CFrame.Angles(0, math.rad(45), 0))
		doReflect({ part }, defaultParams())
		local expected = CFrame.new(-5, 0, 0) * CFrame.Angles(0, math.rad(-45), 0)
		t.expect(part.CFrame:FuzzyEq(expected, 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("identity rotation part keeps identity rotation after reflect", function()
		local part = makePart(CFrame.new(5, 0, 0))
		doReflect({ part }, defaultParams())
		-- An axis-aligned box reflected over an axis-aligned plane stays axis-aligned
		t.expect(part.CFrame.Rotation).toEqual(CFrame.identity)
		part:Destroy()
	end)

	--
	-- Surface swapping
	--

	t.test("swaps Left and Right surfaces on normal parts", function()
		local part = makePart(CFrame.new(5, 0, 0))
		part.LeftSurface = Enum.SurfaceType.Hinge
		part.RightSurface = Enum.SurfaceType.Motor
		doReflect({ part }, defaultParams())
		t.expect(part.LeftSurface).toBe(Enum.SurfaceType.Motor)
		t.expect(part.RightSurface).toBe(Enum.SurfaceType.Hinge)
		part:Destroy()
	end)

	t.test("preserves Top and Bottom surfaces on normal parts", function()
		local part = makePart(CFrame.new(5, 0, 0))
		part.TopSurface = Enum.SurfaceType.Hinge
		part.BottomSurface = Enum.SurfaceType.Motor
		doReflect({ part }, defaultParams())
		t.expect(part.TopSurface).toBe(Enum.SurfaceType.Hinge)
		t.expect(part.BottomSurface).toBe(Enum.SurfaceType.Motor)
		part:Destroy()
	end)

	--
	-- FaceInstance reflection
	--

	t.test("reflects Decal face Left to Right", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Left
		decal.Parent = part
		doReflect({ part }, defaultParams())
		t.expect(decal.Face).toBe(Enum.NormalId.Right)
		part:Destroy()
	end)

	t.test("reflects Decal face Right to Left", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Right
		decal.Parent = part
		doReflect({ part }, defaultParams())
		t.expect(decal.Face).toBe(Enum.NormalId.Left)
		part:Destroy()
	end)

	t.test("preserves Decal on Top face", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.Parent = part
		doReflect({ part }, defaultParams())
		t.expect(decal.Face).toBe(Enum.NormalId.Top)
		part:Destroy()
	end)

	--
	-- Corner wedge special handling
	--

	t.test("corner wedge swaps X and Z size", function()
		local part = Instance.new("CornerWedgePart")
		part.Size = Vector3.new(4, 2, 6)
		part.CFrame = CFrame.new(5, 0, 0)
		part.Anchored = true
		part.Parent = workspace
		doReflect({ part }, defaultParams())
		t.expect(part.Size:FuzzyEq(Vector3.new(6, 2, 4), 0.01)).toBe(true)
		part:Destroy()
	end)

	t.test("corner wedge rotates surfaces", function()
		local part = Instance.new("CornerWedgePart")
		part.Size = Vector3.new(2, 2, 2)
		part.CFrame = CFrame.new(5, 0, 0)
		part.Anchored = true
		part.LeftSurface = Enum.SurfaceType.Hinge
		part.RightSurface = Enum.SurfaceType.Motor
		part.FrontSurface = Enum.SurfaceType.SteppingMotor
		part.BackSurface = Enum.SurfaceType.Weld
		part.Parent = workspace
		doReflect({ part }, defaultParams())
		-- Corner wedge surface mapping: Back↔Left, Front↔Right
		t.expect(part.BackSurface).toBe(Enum.SurfaceType.Hinge)
		t.expect(part.FrontSurface).toBe(Enum.SurfaceType.Motor)
		t.expect(part.RightSurface).toBe(Enum.SurfaceType.SteppingMotor)
		t.expect(part.LeftSurface).toBe(Enum.SurfaceType.Weld)
		part:Destroy()
	end)

	--
	-- Model reflection
	--

	t.test("reflects all parts in a model", function()
		local model = makeModel({
			{ cf = CFrame.new(5, 0, 0) },
			{ cf = CFrame.new(10, 0, 0) },
		})
		local success = doReflect({ model }, defaultParams())
		t.expect(success).toBe(true)
		local p1 = model:FindFirstChild("Part1") :: BasePart
		local p2 = model:FindFirstChild("Part2") :: BasePart
		t.expect(p1.Position:FuzzyEq(Vector3.new(-5, 0, 0), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(-10, 0, 0), 0.01)).toBe(true)
		model:Destroy()
	end)

	t.test("reflects model WorldPivot", function()
		local model = makeModel({
			{ cf = CFrame.new(5, 0, 0) },
		})
		model.WorldPivot = CFrame.new(5, 0, 0)
		doReflect({ model }, defaultParams())
		local pivot = model:GetPivot()
		t.expect(pivot.Position:FuzzyEq(Vector3.new(-5, 0, 0), 0.01)).toBe(true)
		model:Destroy()
	end)

	t.test("reflects nested model hierarchy", function()
		local outer = Instance.new("Model")
		local inner = Instance.new("Model")
		inner.Parent = outer
		local part = Instance.new("Part")
		part.CFrame = CFrame.new(8, 0, 0)
		part.Size = Vector3.new(2, 2, 2)
		part.Anchored = true
		part.Parent = inner
		inner.WorldPivot = CFrame.new(8, 0, 0)
		outer.WorldPivot = CFrame.new(8, 0, 0)
		outer.Parent = workspace
		doReflect({ outer }, defaultParams())
		t.expect(part.Position:FuzzyEq(Vector3.new(-8, 0, 0), 0.01)).toBe(true)
		t.expect(inner:GetPivot().Position:FuzzyEq(Vector3.new(-8, 0, 0), 0.01)).toBe(true)
		outer:Destroy()
	end)

	--
	-- Attachment reflection
	--

	t.test("reflects attachment relative to parent part", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local attachment = Instance.new("Attachment")
		attachment.CFrame = CFrame.new(1, 0, 0) -- offset 1 stud on local X
		attachment.Parent = part
		doReflect({ part }, defaultParams())
		-- Part reflected to (-5, 0, 0). Attachment offset should be reflected
		-- relative to the part's new orientation.
		local worldPos = attachment.WorldCFrame.Position
		-- The attachment was at world (6, 0, 0), should now be at (-6, 0, 0)
		t.expect(worldPos:FuzzyEq(Vector3.new(-6, 0, 0), 0.01)).toBe(true)
		part:Destroy()
	end)

	--
	-- Joint / Weld reflection
	--

	t.test("reflects weld constraint between two parts", function()
		local part0 = makePart(CFrame.new(3, 0, 0))
		local part1 = makePart(CFrame.new(7, 0, 0))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part0
		weld.Part1 = part1
		weld.Parent = part0
		-- Wrap both parts in a model so they're reflected together
		local model = Instance.new("Model")
		part0.Parent = model
		part1.Parent = model
		model.Parent = workspace
		local success = doReflect({ model }, defaultParams())
		t.expect(success).toBe(true)
		-- Parts should be reflected
		t.expect(part0.Position:FuzzyEq(Vector3.new(-3, 0, 0), 0.01)).toBe(true)
		t.expect(part1.Position:FuzzyEq(Vector3.new(-7, 0, 0), 0.01)).toBe(true)
		-- Weld should still reference the same parts
		t.expect(weld.Part0).toBe(part0)
		t.expect(weld.Part1).toBe(part1)
		model:Destroy()
	end)

	t.test("reflects Motor6D C0 and C1", function()
		local part0 = makePart(CFrame.new(3, 0, 0))
		local part1 = makePart(CFrame.new(5, 0, 0))
		local motor = Instance.new("Motor6D")
		motor.Part0 = part0
		motor.Part1 = part1
		motor.C0 = CFrame.new(1, 0, 0)
		motor.C1 = CFrame.new(-1, 0, 0)
		motor.Parent = part0
		local model = Instance.new("Model")
		part0.Parent = model
		part1.Parent = model
		model.Parent = workspace
		doReflect({ model }, defaultParams())
		-- C0 and C1 should have been updated to reflect the joint transform
		-- The world positions of the joint endpoints should be reflected
		local c0World = part0.CFrame:ToWorldSpace(motor.C0)
		local c1World = part1.CFrame:ToWorldSpace(motor.C1)
		-- Both C0 and C1 should map to the same world point (the joint point)
		-- and that point should be the reflection of the original joint point
		-- Original joint world point was part0.CFrame * C0 = (3,0,0)*(1,0,0) = (4,0,0)
		-- Reflected should be (-4,0,0)
		t.expect(c0World.Position:FuzzyEq(Vector3.new(-4, 0, 0), 0.01)).toBe(true)
		t.expect(c1World.Position:FuzzyEq(Vector3.new(-4, 0, 0), 0.01)).toBe(true)
		model:Destroy()
	end)

	--
	-- Multiple instances
	--

	t.test("reflects multiple separate instances", function()
		local part1 = makePart(CFrame.new(3, 0, 0))
		local part2 = makePart(CFrame.new(0, 5, 0))
		local success = doReflect({ part1, part2 }, defaultParams())
		t.expect(success).toBe(true)
		t.expect(part1.Position:FuzzyEq(Vector3.new(-3, 0, 0), 0.01)).toBe(true)
		t.expect(part2.Position:FuzzyEq(Vector3.new(0, 5, 0), 0.01)).toBe(true)
		part1:Destroy()
		part2:Destroy()
	end)

	--
	-- WedgePart reflection
	--

	t.test("reflects WedgePart correctly", function()
		local part = Instance.new("WedgePart")
		part.Size = Vector3.new(2, 4, 6)
		part.CFrame = CFrame.new(5, 0, 0)
		part.Anchored = true
		part.Parent = workspace
		doReflect({ part }, defaultParams())
		t.expect(part.Position:FuzzyEq(Vector3.new(-5, 0, 0), 0.01)).toBe(true)
		-- WedgePart size should be preserved (not a corner wedge)
		t.expect(part.Size:FuzzyEq(Vector3.new(2, 4, 6), 0.01)).toBe(true)
		part:Destroy()
	end)

	--
	-- Diagonal reflection plane
	--

	t.test("reflects over a diagonal plane", function()
		-- 45-degree plane between X and Z axes
		local normal = Vector3.new(1, 0, 1).Unit
		local part = makePart(CFrame.new(5, 0, 0))
		doReflect({ part }, defaultParams({ Normal = normal }))
		-- Reflecting (5,0,0) over plane with normal (1,0,1)/sqrt(2):
		-- projection = (5,0,0)·(1,0,1)/sqrt(2) * (1,0,1)/sqrt(2) = 5/sqrt(2) * (1,0,1)/sqrt(2) = (2.5, 0, 2.5)
		-- reflected = (5,0,0) - 2*(2.5,0,2.5) = (0,0,-5)
		t.expect(part.Position:FuzzyEq(Vector3.new(0, 0, -5), 0.01)).toBe(true)
		part:Destroy()
	end)

	--
	-- Return value
	--

	t.test("returns true with no warning for simple parts", function()
		local part = makePart(CFrame.new(5, 0, 0))
		local success, warning = doReflect({ part }, defaultParams())
		t.expect(success).toBe(true)
		t.expect(warning == nil).toBe(true)
		part:Destroy()
	end)

	t.test("empty list succeeds", function()
		local success = doReflect({}, defaultParams())
		t.expect(success).toBe(true)
	end)
end
