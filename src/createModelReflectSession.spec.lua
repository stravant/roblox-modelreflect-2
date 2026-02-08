local TestTypes = require("./TestTypes")

local createModelReflectSession = require("./createModelReflectSession")

local Selection = game:GetService("Selection")

local plugin = script:FindFirstAncestorWhichIsA("Plugin")

local function defaultSettings(overrides: { [string]: any }?)
	local s = {
		WindowPosition = Vector2.new(0, 0),
		WindowAnchor = Vector2.new(0, 0),
		WindowHeightDelta = 0,
		DoneTutorial = true,
		HaveHelp = false,
		SelectReflectedCopy = true,
		KeepOpenAfterReflecting = false,
		KeepOpenAfterFlipping = true,
		CutoffDelay = 10,
		MaxUnionDepth = 10,
	}
	if overrides then
		for k, v in overrides do
			(s :: any)[k] = v
		end
	end
	return s
end

local function makePart(cf: CFrame?, size: Vector3?): BasePart
	local part = Instance.new("Part")
	part.CFrame = cf or CFrame.identity
	part.Size = size or Vector3.new(2, 2, 2)
	part.Anchored = true
	part.Parent = workspace
	return part
end

return function(t: TestTypes.TestContext)
	--
	-- FlipAroundPivot — basic geometry
	--

	t.test("FlipAroundPivot swaps two parts across X axis", function()
		local p1 = makePart(CFrame.new(0, 0, 0))
		local p2 = makePart(CFrame.new(10, 0, 0))
		local targets = { p1, p2 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success = session.FlipAroundPivot(Vector3.xAxis)

		t.expect(success).toBe(true)
		-- Center is at (5,0,0). Reflecting over x=5 swaps the two parts.
		t.expect(p1.Position:FuzzyEq(Vector3.new(10, 0, 0), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(0, 0, 0), 0.01)).toBe(true)

		session.Destroy()
		p1:Destroy()
		p2:Destroy()
	end)

	t.test("FlipAroundPivot swaps two parts across Y axis", function()
		local p1 = makePart(CFrame.new(0, 5, 0))
		local p2 = makePart(CFrame.new(0, -5, 0))
		local targets = { p1, p2 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success = session.FlipAroundPivot(Vector3.yAxis)

		t.expect(success).toBe(true)
		t.expect(p1.Position:FuzzyEq(Vector3.new(0, -5, 0), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(0, 5, 0), 0.01)).toBe(true)

		session.Destroy()
		p1:Destroy()
		p2:Destroy()
	end)

	t.test("FlipAroundPivot swaps two parts across Z axis", function()
		local p1 = makePart(CFrame.new(0, 0, 4))
		local p2 = makePart(CFrame.new(0, 0, -4))
		local targets = { p1, p2 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success = session.FlipAroundPivot(Vector3.zAxis)

		t.expect(success).toBe(true)
		t.expect(p1.Position:FuzzyEq(Vector3.new(0, 0, -4), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(0, 0, 4), 0.01)).toBe(true)

		session.Destroy()
		p1:Destroy()
		p2:Destroy()
	end)

	t.test("double FlipAroundPivot restores original positions", function()
		local p1 = makePart(CFrame.new(0, 0, 0))
		local p2 = makePart(CFrame.new(10, 0, 0))
		local targets = { p1, p2 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		session.FlipAroundPivot(Vector3.xAxis)
		session.FlipAroundPivot(Vector3.xAxis)

		t.expect(p1.Position:FuzzyEq(Vector3.new(0, 0, 0), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(10, 0, 0), 0.01)).toBe(true)

		session.Destroy()
		p1:Destroy()
		p2:Destroy()
	end)

	t.test("FlipAroundPivot returns success and no warning for simple parts", function()
		local p1 = makePart(CFrame.new(3, 0, 0))
		local targets = { p1 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success, warning = session.FlipAroundPivot(Vector3.xAxis)

		t.expect(success).toBe(true)
		t.expect(warning == nil).toBe(true)

		session.Destroy()
		p1:Destroy()
	end)

	t.test("FlipAroundPivot reflects a model with multiple parts", function()
		local model = Instance.new("Model")
		local p1 = Instance.new("Part")
		p1.Name = "Part1"
		p1.CFrame = CFrame.new(-5, 0, 0)
		p1.Size = Vector3.new(2, 2, 2)
		p1.Anchored = true
		p1.Parent = model
		local p2 = Instance.new("Part")
		p2.Name = "Part2"
		p2.CFrame = CFrame.new(5, 0, 0)
		p2.Size = Vector3.new(2, 2, 2)
		p2.Anchored = true
		p2.Parent = model
		model.Parent = workspace
		-- Model pivot defaults to origin, so reflection plane is at x=0

		local targets = { model }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success = session.FlipAroundPivot(Vector3.xAxis)

		t.expect(success).toBe(true)
		t.expect(p1.Position:FuzzyEq(Vector3.new(5, 0, 0), 0.01)).toBe(true)
		t.expect(p2.Position:FuzzyEq(Vector3.new(-5, 0, 0), 0.01)).toBe(true)

		session.Destroy()
		model:Destroy()
	end)

	--
	-- FlipAroundPivot — selection preservation
	--

	t.test("FlipAroundPivot preserves selection for non-union parts", function()
		local p1 = makePart(CFrame.new(0, 0, 0))
		local p2 = makePart(CFrame.new(10, 0, 0))
		local targets = { p1, p2 }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		session.FlipAroundPivot(Vector3.xAxis)

		local sel = Selection:Get()
		local hasP1, hasP2 = false, false
		for _, item in sel do
			if item == p1 then hasP1 = true end
			if item == p2 then hasP2 = true end
		end
		t.expect(hasP1).toBe(true)
		t.expect(hasP2).toBe(true)

		session.Destroy()
		p1:Destroy()
		p2:Destroy()
	end)

	t.test("FlipAroundPivot updates selection when union is replaced", function()
		-- Create two overlapping parts and union them
		local p1 = makePart(CFrame.new(5, 0, 0), Vector3.new(4, 4, 4))
		local p2 = makePart(CFrame.new(7, 0, 0), Vector3.new(4, 4, 4))
		local union = plugin:Union({ p1, p2 })
		union.Parent = workspace

		-- Also have a regular part in the selection
		local regular = makePart(CFrame.new(-5, 0, 0))

		local targets = { union, regular }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		local success = session.FlipAroundPivot(Vector3.xAxis)

		t.expect(success).toBe(true)

		local sel = Selection:Get()
		t.expect(#sel).toBe(2)

		-- Every item in the selection should still be parented (not destroyed)
		for _, item in sel do
			t.expect(item.Parent ~= nil).toBe(true)
		end

		-- Regular part should still be in the selection
		local hasRegular = false
		for _, item in sel do
			if item == regular then hasRegular = true end
		end
		t.expect(hasRegular).toBe(true)

		-- Old union should NOT be in the selection (it was destroyed and replaced)
		local hasOldUnion = false
		for _, item in sel do
			if item == union then hasOldUnion = true end
		end
		t.expect(hasOldUnion).toBe(false)

		session.Destroy()
		regular:Destroy()
		for _, item in sel do
			if item ~= regular then
				item:Destroy()
			end
		end
	end)

	t.test("FlipAroundPivot selection replacement is a UnionOperation", function()
		local p1 = makePart(CFrame.new(5, 0, 0), Vector3.new(4, 4, 4))
		local p2 = makePart(CFrame.new(7, 0, 0), Vector3.new(4, 4, 4))
		local union = plugin:Union({ p1, p2 })
		union.Parent = workspace

		local targets = { union }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		session.FlipAroundPivot(Vector3.xAxis)

		local sel = Selection:Get()
		t.expect(#sel).toBe(1)
		t.expect(sel[1]:IsA("UnionOperation")).toBe(true)
		t.expect(sel[1].Parent).toBe(workspace)

		session.Destroy()
		sel[1]:Destroy()
	end)

	--
	-- ReflectOverTarget
	--

	t.test("ReflectOverTarget with no basis returns true", function()
		local target = makePart(CFrame.new(0, 5, 0))
		local targets = { target }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings())
		session.SetBasis(nil)

		local success = session.ReflectOverTarget()
		t.expect(success).toBe(true)

		-- teardown cancels the ChangeHistory recording which may undo the part creation
		pcall(session.Destroy)
		pcall(target.Destroy, target)
	end)

	t.test("ReflectOverTarget clones and reflects target over basis", function()
		local target = makePart(CFrame.new(0, 5, 0))
		local targets = { target }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings({
			SelectReflectedCopy = true,
		}))

		-- Reflect over the XZ plane at the origin (Y normal)
		session.SetBasis({
			Origin = Vector3.new(0, 0, 0),
			Normal = Vector3.yAxis,
		})

		local success = session.ReflectOverTarget()
		t.expect(success).toBe(true)

		-- Selection should contain the reflected clone, not the original
		local sel = Selection:Get()
		t.expect(#sel).toBe(1)
		t.expect(sel[1] ~= target).toBe(true)
		t.expect(sel[1].Parent).toBe(workspace)

		-- Clone should be at the reflected position
		local clone = sel[1] :: BasePart
		t.expect(clone.Position:FuzzyEq(Vector3.new(0, -5, 0), 0.01)).toBe(true)

		-- Original should still exist at its original position
		t.expect(target.Parent).toBe(workspace)
		t.expect(target.Position:FuzzyEq(Vector3.new(0, 5, 0), 0.01)).toBe(true)

		session.Destroy()
		target:Destroy()
		clone:Destroy()
	end)

	t.test("ReflectOverTarget does not select clone when SelectReflectedCopy is false", function()
		local target = makePart(CFrame.new(0, 5, 0))
		local targets = { target }
		Selection:Set(targets)

		local session = createModelReflectSession(plugin, targets, defaultSettings({
			SelectReflectedCopy = false,
		}))

		session.SetBasis({
			Origin = Vector3.new(0, 0, 0),
			Normal = Vector3.yAxis,
		})

		local success = session.ReflectOverTarget()
		t.expect(success).toBe(true)

		-- Selection should NOT have been changed to the clone
		local sel = Selection:Get()
		local hasTarget = false
		for _, item in sel do
			if item == target then hasTarget = true end
		end
		t.expect(hasTarget).toBe(true)

		-- Clean up the clone
		for _, ch in workspace:GetChildren() do
			if ch.Name == target.Name and ch ~= target then
				ch:Destroy()
			end
		end

		session.Destroy()
		target:Destroy()
	end)
end
