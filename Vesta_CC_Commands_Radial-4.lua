-- VESTA radial panel
-- Gold Carpet + Blow Dryer use the Vesta Gears fly / blow logic.
-- Gun and Knife only clone the real tool you already have. No fake box.
-- REMOVE ALL / REMOVE THIS sit just above the command bar.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

for _, n in ipairs({ "VestaRadialPanel", "VestaFloatButton", "VestaMapSelector" }) do
	local o = playerGui:FindFirstChild(n)
	if o then o:Destroy() end
end

local DRYER_SOUND_ID = "rbxassetid://11717967"
local spawned = {}

local function mark(tool)
	tool:SetAttribute("VestaGiven", true)
	spawned[tool] = true
	tool.Destroying:Connect(function()
		spawned[tool] = nil
	end)
end

local function getChar()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHandle(tool)
	return tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
end

local function stripScripts(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
end

local function addSound(parent, name, id, volume)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = parent
	return s
end

local function rainbowSequence()
	local keys = {}
	for i = 0, 6 do
		keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 1, 1))
	end
	return ColorSequence.new(keys)
end

local function tintInstance(root, color)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") or d:IsA("Part") or d:IsA("UnionOperation") then
			d.Color = color
		elseif d:IsA("SpecialMesh") then
			d.VertexColor = Vector3.new(color.R, color.G, color.B)
		end
	end
end

-- aim
local lastTouch
UserInputService.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch then
		lastTouch = i.Position
	end
end)
UserInputService.TouchTap:Connect(function(p)
	if p and p[1] then
		lastTouch = p[1]
	end
end)

local function isShiftLock()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return true
	end
	local ok, rt = pcall(function()
		return UserSettings():GetService("UserGameSettings").RotationType
	end)
	return ok and rt == Enum.RotationType.CameraRelative
end

local function aimPoint(ignore)
	local shift = isShiftLock()
	if shift or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local p = Vector2.new(vp.X / 2, vp.Y / 2)
		if not shift and lastTouch then
			p = lastTouch
		end
		local ray = cam:ViewportPointToRay(p.X, p.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ignore }
		local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		return res and res.Position or (ray.Origin + ray.Direction * 1000)
	end
	return mouse.Hit.Position
end

local cache, loading = {}, {}
local function preload(id)
	if not id or cache[id] ~= nil or loading[id] then
		return
	end
	loading[id] = true
	task.spawn(function()
		local template = false
		for a = 1, 4 do
			local ok, objs = pcall(function()
				return game:GetObjects("rbxassetid://" .. id)
			end)
			if ok and objs and objs[1] then
				local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
				if t then
					t.Parent = nil
					stripScripts(t)
					template = t
					break
				end
			end
			task.wait(0.4 * a)
		end
		cache[id] = template
		loading[id] = nil
	end)
end

local function loadReal(id)
	if cache[id] then
		return cache[id]:Clone(), false
	end
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if ok and objs and objs[1] then
		local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
		if t then
			t.Parent = nil
			stripScripts(t)
			cache[id] = t
			return t:Clone(), false
		end
	end
	return nil, true
end

task.spawn(function()
	preload(1016183873) -- gold carpet
	preload(11719016) -- blow dryer
	preload(236438668) -- sea bow
	preload(99119158) -- speed coil
	preload(16688968) -- gravity coil
	preload(36913601) -- broom
end)

-- ===== carpet fly (same as Vesta Gears) =====
local controls
task.spawn(function()
	pcall(function()
		controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 3)):GetControls()
	end)
end)

local function getMove()
	if controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and v then
			return v
		end
	end
	local x = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
	local z = (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0)
	return Vector3.new(x, 0, z)
end

local function setupCarpet(tool, cfg)
	local handle = getHandle(tool)
	local bv, bg, loop, trail, a0, a1

	local function stop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
		if bv then
			bv:Destroy()
			bv = nil
		end
		if bg then
			bg:Destroy()
			bg = nil
		end
		if trail then
			trail:Destroy()
			trail = nil
		end
		if a0 then
			a0:Destroy()
			a0 = nil
		end
		if a1 then
			a1:Destroy()
			a1 = nil
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end

	local function start()
		stop()
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum and handle) then
			return
		end

		local half = handle.Size * 0.45
		a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-half.X, 0, 0)
		a0.Parent = handle
		a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(half.X, 0, 0)
		a1.Parent = handle
		trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 1.2
		trail.LightEmission = cfg.trailEmission or 0.6
		trail.Transparency = NumberSequence.new(0.1, 1)
		if cfg.trail == "rainbow" then
			trail.Color = rainbowSequence()
		elseif cfg.trail then
			trail.Color = cfg.trail
		end
		trail.Parent = handle

		hum.PlatformStand = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		bv.Velocity = Vector3.zero
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
		bg.P = 9000
		bg.D = 600
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp

		local fallback = tool:GetAttribute("Fallback")
		local hue, tintT = 0, 0
		loop = RunService.Heartbeat:Connect(function(dt)
			if not hrp.Parent then
				return stop()
			end
			local cam = workspace.CurrentCamera.CFrame
			local mv = getMove()
			local dir = cam.RightVector * mv.X + cam.LookVector * -mv.Z
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				dir += Vector3.yAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				dir -= Vector3.yAxis
			end
			bv.Velocity = (dir.Magnitude > 0.05) and (dir.Unit * cfg.speed) or Vector3.zero
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
			end
			if fallback and cfg.color == "rainbow" then
				hue = (hue + dt * 0.4) % 1
				tintT += dt
				if tintT > 0.1 then
					tintT = 0
					tintInstance(tool, Color3.fromHSV(hue, 1, 1))
				end
			end
		end)
	end

	tool.Equipped:Connect(start)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
end

local GOLD_CFG = {
	name = "Gold Carpet",
	speed = 70,
	color = Color3.fromRGB(255, 200, 40),
	trail = ColorSequence.new(Color3.fromRGB(255, 200, 40), Color3.fromRGB(255, 240, 150)),
}
local function fallbackCarpet(cfg)
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(4, 0.25, 6)
	h.Color = typeof(cfg.color) == "Color3" and cfg.color or Color3.fromRGB(255, 200, 40)
	h.Material = Enum.Material.Neon
	h.CanCollide = false
	h.Parent = tool
	local mesh = Instance.new("SpecialMesh", h)
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = "rbxassetid://223079737"
	mesh.TextureId = "rbxassetid://1014108463"
	mesh.Scale = Vector3.new(1.4, 1.4, 1.4)
	tool.TextureId = "rbxassetid://1014109561"
	tool.Grip = CFrame.new(-1.47, 0.35, -1.65, 0, 0, -1, -1, 0, 0, 0, 1, 0)
	tool:SetAttribute("Fallback", true)
	return tool
end

local function giveNamed(name, id, cfg, setup, extra)
	local bp = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not bp then
		return
	end
	for _, c in ipairs({ bp, player.Character }) do
		if c and c:FindFirstChild(name) then
			c[name]:Destroy()
		end
	end
	local tool = nil
	if id then
		tool = loadReal(id)
	end
	if not tool then
		tool = extra and extra() or fallbackCarpet(cfg or { name = name, color = Color3.new(1, 1, 1) })
	end
	tool.Name = name
	tool.CanBeDropped = false
	if cfg and cfg.icon then
		tool.TextureId = cfg.icon
	end
	mark(tool)
	tool.Parent = bp
	if setup then
		setup(tool, cfg)
	end
	return tool
end

-- ===== blow dryer (same as Vesta Gears: hold to blow) =====
local function windPuff(origin, look)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(255, 225, 240)
	p.Transparency = 0.4
	p.Size = Vector3.new(1.2, 1.2, 1.2)
	p.Position = origin + look * 2
	p.Parent = workspace
	local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
	TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = origin + look * 34 + spread,
		Size = Vector3.new(7, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.6)
end

local function setupDryer(tool)
	local handle = getHandle(tool)
	if not handle then
		return
	end
	local holding = false
	local loopConn
	local wind = addSound(handle, "Blow", DRYER_SOUND_ID, 0.7)
	wind.Looped = true
	local att = Instance.new("Attachment")
	att.Name = "WindOrigin"
	att.Parent = handle
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Wind"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(60, 80)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 225, 240))
	emitter.LightEmission = 0.4
	emitter.Parent = att

	local RANGE, PUSH = 34, 90
	local ACC, MAXSPEED, UP = 330, 100, 150

	local function stopBlowing()
		if not holding then
			return
		end
		holding = false
		emitter.Rate = 0
		wind:Stop()
		if loopConn then
			loopConn:Disconnect()
			loopConn = nil
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end

	local function startBlowing()
		if holding then
			return
		end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (char and hrp and tool.Parent == char) then
			return
		end
		holding = true
		emitter.Rate = 250
		wind:Play()
		if hum then
			hum.PlatformStand = true
		end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local acc, puffT = 0, 0
		loopConn = RunService.Heartbeat:Connect(function(dt)
			if not (holding and tool.Parent == char and handle.Parent and hrp.Parent) then
				return stopBlowing()
			end
			local origin = handle.Position
			local look = workspace.CurrentCamera.CFrame.LookVector
			att.WorldCFrame = CFrame.lookAt(origin, origin + look) * CFrame.Angles(-math.pi / 2, 0, 0)
			local v = hrp.AssemblyLinearVelocity - look * ACC * dt + Vector3.new(0, UP * dt, 0)
			if v.Magnitude > MAXSPEED then
				v = v.Unit * MAXSPEED
			end
			hrp.AssemblyLinearVelocity = v
			puffT += dt
			if puffT >= 0.07 then
				puffT = 0
				windPuff(origin, look)
			end
			acc += dt
			if acc >= 0.1 then
				acc = 0
				for _, part in ipairs(workspace:GetPartBoundsInRadius(origin + look * (RANGE / 2), RANGE / 2, params)) do
					if not part.Anchored then
						local to = part.Position - origin
						if to.Magnitude > 0.1 and to.Unit:Dot(look) > 0.7 then
							part.AssemblyLinearVelocity = part.AssemblyLinearVelocity + look * PUSH * 0.3
						end
					end
				end
			end
		end)
	end

	local pressInput
	local function isPress(i)
		return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
	end
	local c1 = UserInputService.InputBegan:Connect(function(i, processed)
		if processed or not isPress(i) then
			return
		end
		if i.UserInputType == Enum.UserInputType.Touch then
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize
			if vp and i.Position.X < vp.X * 0.3 and i.Position.Y > vp.Y * 0.45 then
				return
			end
		end
		if tool.Parent == player.Character then
			pressInput = i
			startBlowing()
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(i)
		if i == pressInput then
			pressInput = nil
			stopBlowing()
		end
	end)
	tool.Unequipped:Connect(stopBlowing)
	tool.Destroying:Connect(function()
		c1:Disconnect()
		c2:Disconnect()
		stopBlowing()
	end)
end

local function giveDryer()
	local tool = giveNamed("Blow Dryer", 11719016, nil, nil, function()
		local t = Instance.new("Tool")
		t.RequiresHandle = true
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(0.8, 0.8, 1.8)
		h.Color = Color3.fromRGB(220, 60, 120)
		h.CanCollide = false
		h.Parent = t
		return t
	end)
	if tool then
		setupDryer(tool)
	end
end

local function giveGold()
	local tool = giveNamed("Gold Carpet", 1016183873, GOLD_CFG, nil, function()
		return fallbackCarpet(GOLD_CFG)
	end)
	if tool then
		if tool.TextureId == "" then
			tool.TextureId = "rbxassetid://1014109561"
		end
		setupCarpet(tool, GOLD_CFG)
	end
end

-- ===== BROOM (standalone witch broom: click to fly / land) =====
local function giveBroom()
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end

	local TOOL_NAME = "Broom"
	local BROOM_ASSET_ID = 36913601
	local BROOM_SOUND_ID = "rbxassetid://35886425"
	local BROOM_IDLE_ANIM_ID = "114924283270252"
	local BROOM_MOVE_ANIM_ID = "130490463850590"
	local FLY_SPEED = 80
	local SEAT_OFFSET = 1.9
	local BROOM_SHIFT = 1.0
	local BROOM_FLIP = true
	local BROOM_ROLL = 0
	local BROOM_SCALE = 1
	local ARM_RAISE_DEG = 70
	local LEAN_DEG = 14
	local BROOM_TILT = 0.3
	local MOVE_SMOOTH = 0.15

	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			local old = container:FindFirstChild(TOOL_NAME)
			if old then
				old:Destroy()
			end
		end
	end

	local loaded
	do
		local ok, objs = pcall(function()
			return game:GetObjects("rbxassetid://" .. tostring(BROOM_ASSET_ID))
		end)
		if ok and type(objs) == "table" and objs[1] then
			loaded = objs[1]
			for _, d in ipairs(loaded:GetDescendants()) do
				if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
					d:Destroy()
				end
			end
		end
	end

	local tool
	if loaded and loaded:IsA("Tool") then
		tool = loaded
	else
		tool = Instance.new("Tool")
		if loaded and loaded:IsA("BasePart") then
			loaded.Name = "Handle"
			loaded.Anchored = false
			loaded.CanCollide = false
			loaded.Parent = tool
		elseif loaded and loaded:IsA("Model") then
			local primary = loaded.PrimaryPart or loaded:FindFirstChildWhichIsA("BasePart", true)
			if primary then
				primary.Name = "Handle"
				for _, part in ipairs(loaded:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						if part ~= primary then
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = primary
							weld.Part1 = part
							weld.Parent = primary
						end
					end
				end
				for _, child in ipairs(loaded:GetChildren()) do
					child.Parent = tool
				end
			end
			loaded:Destroy()
		end
	end

	tool.Name = TOOL_NAME
	tool.ToolTip = "Click to fly on the broom"
	tool.CanBeDropped = false
	tool.TextureId = "rbxthumb://type=Asset&id=" .. tostring(BROOM_ASSET_ID) .. "&w=420&h=420"
	if not tool:FindFirstChild("Handle") then
		tool.RequiresHandle = false
	end

	local flying = false
	local humanoid, root
	local flightModel, flightOffset
	local bodyVel, bodyGyro, loop, idleTrack, moveTrack, flySound
	local oldAutoRotate
	local savedC0 = {}
	local hiddenParts = {}

	local function safeDestroy(inst)
		if inst and inst.Parent then
			pcall(function()
				inst:Destroy()
			end)
		end
	end

	local function hideHeld()
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("BasePart") and hiddenParts[d] == nil then
				hiddenParts[d] = d.Transparency
				d.Transparency = 1
			end
		end
	end

	local function showHeld()
		for part, original in pairs(hiddenParts) do
			if part and part.Parent then
				part.Transparency = original
			end
		end
		table.clear(hiddenParts)
	end

	local function buildFlightModel()
		local model = Instance.new("Model")
		model.Name = "WitchBroomModel"

		local handle = tool:FindFirstChild("Handle")
		if handle then
			for _, child in ipairs(tool:GetChildren()) do
				if child:IsA("BasePart") or child:IsA("Model") then
					child:Clone().Parent = model
				end
			end
		end

		local hasParts = model:FindFirstChildWhichIsA("BasePart", true) ~= nil

		if not hasParts then
			local stick = Instance.new("Part")
			stick.Name = "Stick"
			stick.Size = Vector3.new(0.3, 0.3, 6.5)
			stick.Color = Color3.fromRGB(110, 70, 35)
			stick.Material = Enum.Material.Wood
			stick.Parent = model

			local bristles = Instance.new("Part")
			bristles.Name = "Bristles"
			bristles.Size = Vector3.new(1.5, 1.1, 2.2)
			bristles.Color = Color3.fromRGB(190, 150, 80)
			bristles.Material = Enum.Material.Fabric
			bristles.CFrame = CFrame.new(0, 0, 4.3)
			bristles.Parent = model

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = stick
			weld.Part1 = bristles
			weld.Parent = stick
		end

		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
			end
		end

		model.PrimaryPart = model:FindFirstChild("Handle")
			or model:FindFirstChild("Stick")
			or model:FindFirstChildWhichIsA("BasePart", true)
		model.Parent = workspace

		if BROOM_SCALE ~= 1 then
			pcall(function()
				model:ScaleTo(BROOM_SCALE)
			end)
		end

		local size = model:GetExtentsSize()
		local align = CFrame.new()
		if size.X >= size.Y and size.X >= size.Z then
			align = CFrame.Angles(0, math.rad(90), 0)
		elseif size.Y >= size.X and size.Y >= size.Z then
			align = CFrame.Angles(math.rad(90), 0, 0)
		end

		local flip = BROOM_FLIP and CFrame.Angles(0, math.pi, 0) or CFrame.new()
		flightOffset = flip * CFrame.Angles(0, 0, math.rad(BROOM_ROLL)) * align
		flightModel = model
	end

	local function setMotor(motor, newC0)
		if motor and motor:IsA("Motor6D") then
			if savedC0[motor] == nil then
				savedC0[motor] = motor.C0
			end
			motor.C0 = savedC0[motor] * newC0
		end
	end

	local function applyPose(character)
		local isR15 = humanoid and humanoid.RigType == Enum.HumanoidRigType.R15
		local raise = math.rad(ARM_RAISE_DEG)

		if isR15 then
			local rUpper = character:FindFirstChild("RightUpperArm")
			local lUpper = character:FindFirstChild("LeftUpperArm")
			local upperTorso = character:FindFirstChild("UpperTorso")
			setMotor(rUpper and rUpper:FindFirstChild("RightShoulder"), CFrame.Angles(raise, 0, math.rad(-8)))
			setMotor(lUpper and lUpper:FindFirstChild("LeftShoulder"), CFrame.Angles(raise, 0, math.rad(8)))
			setMotor(upperTorso and upperTorso:FindFirstChild("Waist"), CFrame.Angles(math.rad(-LEAN_DEG), 0, 0))
		else
			local torso = character:FindFirstChild("Torso")
			setMotor(torso and torso:FindFirstChild("Right Shoulder"), CFrame.Angles(0, 0, raise))
			setMotor(torso and torso:FindFirstChild("Left Shoulder"), CFrame.Angles(0, 0, -raise))
		end
	end

	local function restorePose()
		for motor, original in pairs(savedC0) do
			if motor and motor.Parent then
				motor.C0 = original
			end
		end
		table.clear(savedC0)
	end

	local function stop()
		flying = false

		if loop then
			loop:Disconnect()
			loop = nil
		end
		for _, track in ipairs({ idleTrack, moveTrack }) do
			pcall(function()
				track:Stop(0)
				track:Destroy()
			end)
		end
		idleTrack, moveTrack = nil, nil
		if flySound then
			pcall(function()
				flySound:Stop()
			end)
			safeDestroy(flySound)
			flySound = nil
		end

		restorePose()
		showHeld()

		safeDestroy(bodyVel)
		safeDestroy(bodyGyro)
		safeDestroy(flightModel)
		bodyVel, bodyGyro, flightModel = nil, nil, nil

		if humanoid and humanoid.Parent then
			humanoid.Sit = false
			humanoid.PlatformStand = false
			humanoid.AutoRotate = oldAutoRotate ~= nil and oldAutoRotate or true
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end

		if root and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local function setAnimState(moving)
		local want = (moving and moveTrack) or idleTrack or moveTrack
		local other = (want == moveTrack) and idleTrack or moveTrack
		if want and not want.IsPlaying then
			want:Play(0.2)
		end
		if other and other ~= want and other.IsPlaying then
			other:Stop(0.2)
		end
	end

	local function start()
		local character = player.Character
		if not character or tool.Parent ~= character then
			return
		end

		humanoid = character:FindFirstChildOfClass("Humanoid")
		root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end

		oldAutoRotate = humanoid.AutoRotate
		flying = true

		buildFlightModel()
		hideHeld()

		do
			flightModel:PivotTo(root.CFrame * CFrame.new(0, -SEAT_OFFSET, BROOM_SHIFT) * flightOffset)
			for _, d in ipairs(flightModel:GetDescendants()) do
				if d:IsA("BasePart") then
					local w = Instance.new("WeldConstraint")
					w.Part0 = root
					w.Part1 = d
					w.Parent = d
					d.Massless = true
					d.Anchored = false
				end
			end
		end

		humanoid.AutoRotate = false
		humanoid.Sit = true

		local animator = humanoid:FindFirstChildOfClass("Animator")
		local function loadTrack(id)
			if not animator or id == "" then
				return nil
			end
			local ok, track = pcall(function()
				local anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. id
				local t = animator:LoadAnimation(anim)
				t.Priority = Enum.AnimationPriority.Action4
				t.Looped = true
				return t
			end)
			return ok and track or nil
		end
		idleTrack = loadTrack(BROOM_IDLE_ANIM_ID)
		moveTrack = loadTrack(BROOM_MOVE_ANIM_ID)
		setAnimState(false)
		task.delay(1.5, function()
			if not flying then
				return
			end
			local loadedOk = (idleTrack and idleTrack.Length > 0) or (moveTrack and moveTrack.Length > 0)
			if not loadedOk then
				applyPose(character)
			end
		end)

		flySound = Instance.new("Sound")
		flySound.Name = "BroomFlySound"
		flySound.SoundId = BROOM_SOUND_ID
		flySound.Looped = true
		flySound.Volume = 1
		flySound.Parent = root
		flySound:Play()

		bodyVel = Instance.new("BodyVelocity")
		bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVel.Velocity = Vector3.zero
		bodyVel.Parent = root

		bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyGyro.P = 12000
		bodyGyro.CFrame = root.CFrame
		bodyGyro.Parent = root

		root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)

		local pitchSmooth, rollSmooth = 0, 0
		local smoothVel = Vector3.zero

		loop = RunService.RenderStepped:Connect(function()
			if not flying or not root or not root.Parent or not humanoid or humanoid.Health <= 0 then
				stop()
				return
			end

			if not humanoid.Sit then
				humanoid.Sit = true
			end

			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				flat = flat.Unit
			else
				flat = Vector3.new(0, 0, -1)
			end
			local right = Vector3.new(-flat.Z, 0, flat.X)

			local move = humanoid.MoveDirection
			local sideAmount = move:Dot(right)
			local direction = look * move:Dot(flat) + right * sideAmount

			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction += Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				direction += Vector3.new(0, -1, 0)
			end

			if direction.Magnitude > 1 then
				direction = direction.Unit
			end

			smoothVel = smoothVel:Lerp(direction * FLY_SPEED, MOVE_SMOOTH)
			local velocity = smoothVel
			bodyVel.Velocity = velocity
			setAnimState(direction.Magnitude > 0.1)

			pitchSmooth += ((velocity.Y / FLY_SPEED) * 0.35 * BROOM_TILT - pitchSmooth) * 0.08
			rollSmooth += ((-sideAmount) * 0.3 * BROOM_TILT - rollSmooth) * 0.08

			local orient = CFrame.lookAt(root.Position, root.Position + flat) * CFrame.Angles(pitchSmooth, 0, rollSmooth)
			bodyGyro.CFrame = orient
		end)
	end

	tool.Activated:Connect(function()
		if flying then
			stop()
		else
			start()
		end
	end)

	local charRemoving = player.CharacterRemoving:Connect(stop)

	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(function()
		stop()
		charRemoving:Disconnect()
	end)

	mark(tool)
	tool.Parent = backpack
end

local function setupSpeed(tool, speed)
	local old
	tool.Equipped:Connect(function()
		local hum = getChar():FindFirstChildOfClass("Humanoid")
		if hum then
			old = hum.WalkSpeed
			hum.WalkSpeed = speed
		end
	end)
	tool.Unequipped:Connect(function()
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum and old then
			hum.WalkSpeed = old
		end
	end)
end

local function giveSpeed()
	local tool = giveNamed("Speed Coil", 99119158, { icon = "rbxassetid://99170415" }, nil, function()
		local t = Instance.new("Tool")
		t.RequiresHandle = true
		t.TextureId = "rbxassetid://99170415"
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(1.4, 1.6, 1.6)
		h.Color = Color3.fromRGB(220, 30, 30)
		h.CanCollide = false
		h.Parent = t
		return t
	end)
	if tool then
		setupSpeed(tool, 40)
	end
end

local function giveGravity()
	local tool = giveNamed("Gravity Coil", 16688968, { icon = "rbxassetid://16619617" }, nil, function()
		local t = Instance.new("Tool")
		t.RequiresHandle = true
		t.TextureId = "rbxassetid://16619617"
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Shape = Enum.PartType.Cylinder
		h.Size = Vector3.new(1.4, 1.6, 1.6)
		h.Color = Color3.fromRGB(60, 120, 255)
		h.CanCollide = false
		h.Parent = t
		return t
	end)
	if not tool then
		return
	end
	local force, loop
	local function stop()
		if loop then
			loop:Disconnect()
			loop = nil
		end
		if force then
			force:Destroy()
			force = nil
		end
	end
	tool.Equipped:Connect(function()
		stop()
		local hrp = getChar():FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		force = Instance.new("BodyForce")
		force.Parent = hrp
		local last = -1
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent then
				return stop()
			end
			local m = hrp.AssemblyMass
			if m ~= last then
				last = m
				force.Force = Vector3.new(0, m * workspace.Gravity * 0.75, 0)
			end
		end)
	end)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
end

local SHOT_SOUND_ID = "rbxassetid://99204505"
local HIT_SOUND_ID = "rbxassetid://58274204"

local function giveSeaBow()
	local tool = giveNamed("Sea Bow", 236438668, nil, nil, function()
		local t = Instance.new("Tool")
		t.RequiresHandle = true
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(0.5, 1.3, 3)
		h.Color = Color3.fromRGB(0, 200, 255)
		h.Material = Enum.Material.Neon
		h.CanCollide = false
		h.Parent = t
		return t
	end)
	if not tool then
		return
	end
	local handle = getHandle(tool)
	if not handle then
		return
	end
	addSound(handle, "Shot", SHOT_SOUND_ID, 0.5)
	local ready = true
	tool.Activated:Connect(function()
		if not ready then
			return
		end
		ready = false
		local char = getChar()
		if handle:FindFirstChild("Shot") then
			handle.Shot.Pitch = math.random(90, 110) / 100
			handle.Shot:Play()
		end
		local arrow = Instance.new("Part")
		arrow.Name = "SeaArrow"
		arrow.Size = Vector3.new(0.2, 0.2, 2.5)
		arrow.Transparency = 0.25
		arrow.Reflectance = 0.5
		arrow.CanCollide = false
		arrow.Material = Enum.Material.SmoothPlastic
		arrow.BrickColor = BrickColor.new("Cyan")
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshId = "rbxassetid://235107348"
		mesh.TextureId = "rbxassetid://235107780"
		mesh.Parent = arrow
		addSound(arrow, "Hit", HIT_SOUND_ID, 1)
		arrow.CFrame = CFrame.new(handle.Position, aimPoint(char))
		arrow.AssemblyLinearVelocity = arrow.CFrame.LookVector * 120
		arrow.Parent = workspace
		local conn
		conn = arrow.Touched:Connect(function(part)
			if part:IsDescendantOf(char) then
				return
			end
			local scale = 8 + (4 * math.random(1, 3))
			pcall(function()
				workspace.Terrain:FillBall(arrow.Position, scale, Enum.Material.Water)
				task.delay(7, function()
					pcall(function()
						workspace.Terrain:FillBall(arrow.Position, scale, Enum.Material.Air)
					end)
				end)
			end)
			if arrow:FindFirstChild("Hit") then
				arrow.Hit:Play()
			end
			arrow.Anchored = true
			arrow.Transparency = 1
			conn:Disconnect()
		end)
		Debris:AddItem(arrow, 8)
		task.delay(1.2, function()
			ready = true
		end)
	end)
end

do
	local JUMP_POWER, BOOST_FRAMES = 78, 8
	UserInputService.JumpRequest:Connect(function()
		local char = player.Character
		if not (char and char:FindFirstChild("Sea Bow")) then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not (hum and root) then
			return
		end
		local st = hum:GetState()
		if st ~= Enum.HumanoidStateType.Swimming and st ~= Enum.HumanoidStateType.GettingUp then
			return
		end
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, JUMP_POWER, v.Z)
		task.spawn(function()
			for _ = 1, BOOST_FRAMES do
				if not root.Parent then
					break
				end
				if root.AssemblyLinearVelocity.Y < JUMP_POWER * 0.7 then
					local cur = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(cur.X, math.max(cur.Y, JUMP_POWER * 0.85), cur.Z)
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end)
end

local function giveRainbow()
	pcall(function()
		loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Open-Source-227632"))()
	end)
end

-- Gun / Knife: clone the tool you are holding (RedLuger, water gun, knife, etc).
-- Falls back to whatever matching tool is sitting in your backpack.
local GEAR_NAMES = {
	["blow dryer"] = true,
	["sea bow"] = true,
	["speed coil"] = true,
	["gravity coil"] = true,
	["broom"] = true,
	["gold carpet"] = true,
	["goldencarpet"] = true,
	["vestagun"] = true,
	["vestaknife"] = true,
}

local function isOurGear(tool)
	if not tool or not tool:IsA("Tool") then
		return true
	end
	if tool:GetAttribute("VestaGiven") then
		return true
	end
	return GEAR_NAMES[string.lower(tool.Name)] == true
end

local function looksLikeKnife(name)
	local n = string.lower(name)
	return n:find("knife") or n:find("blade") or n:find("sword") or n:find("dagger") or n:find("machete")
end

local function equippedTool()
	local char = player.Character
	if not char then
		return nil
	end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") and not isOurGear(ch) then
			return ch
		end
	end
	return nil
end

local function findRealWeapon(kind)
	local held = equippedTool()
	if held then
		local knife = looksLikeKnife(held.Name)
		if kind == "knife" and knife then
			return held
		end
		if kind == "gun" and not knife then
			return held
		end
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	if bp then
		for _, ch in ipairs(bp:GetChildren()) do
			if ch:IsA("Tool") and not isOurGear(ch) then
				local knife = looksLikeKnife(ch.Name)
				if kind == "knife" and knife then
					return ch
				end
				if kind == "gun" and not knife then
					return ch
				end
			end
		end
	end
	return nil
end

local function giveHeldCopy(kind)
	local source = findRealWeapon(kind)
	if not source then
		return nil
	end
	local bp = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	local copyName = source.Name .. " Copy"
	for _, c in ipairs({ bp, player.Character }) do
		if c and c:FindFirstChild(copyName) then
			c[copyName]:Destroy()
		end
	end
	local tool = source:Clone()
	stripScripts(tool)
	tool.Name = copyName
	tool.TextureId = source.TextureId
	tool.ToolTip = source.ToolTip
	tool.Grip = source.Grip
	tool.CanBeDropped = false
	mark(tool)
	tool.Parent = bp
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:EquipTool(tool)
		end)
	end
	return tool, source.Name
end

local function removeAll()
	local list = {}
	for tool in pairs(spawned) do
		list[#list + 1] = tool
	end
	for _, tool in ipairs(list) do
		pcall(function()
			tool:Destroy()
		end)
	end
	table.clear(spawned)
	for _, c in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if c then
			for _, item in ipairs(c:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("VestaGiven") then
					item:Destroy()
				end
			end
		end
	end
end

local function removeThis()
	local char = player.Character
	if not char then
		return false
	end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") then
			local n = ch.Name
			ch:Destroy()
			return true, n
		end
	end
	return false
end

-- ===== roles / map / jail (light) =====
local espOn, highlights = false, {}
local function getRole(plr)
	local c = plr.Character
	if not c then
		return "Innocent"
	end
	local function has(container, word)
		if not container then
			return false
		end
		for _, ch in ipairs(container:GetChildren()) do
			if ch:IsA("Tool") and not ch:GetAttribute("VestaGiven") and string.lower(ch.Name):find(word) then
				return true
			end
		end
		return false
	end
	if has(c, "knife") or has(plr:FindFirstChildOfClass("Backpack"), "knife") then
		return "Murderer"
	end
	if has(c, "gun") or has(plr:FindFirstChildOfClass("Backpack"), "gun") then
		return "Sheriff"
	end
	return "Innocent"
end

local function removeESP(plr)
	if highlights[plr] then
		highlights[plr]:Destroy()
		highlights[plr] = nil
	end
end

local function updateESP(plr)
	if plr == player or not espOn then
		removeESP(plr)
		return
	end
	local char = plr.Character
	if not char then
		removeESP(plr)
		return
	end
	local hl = highlights[plr]
	if not hl or not hl.Parent then
		hl = Instance.new("Highlight")
		hl.Adornee = char
		hl.Parent = char
		highlights[plr] = hl
	end
	local r = getRole(plr)
	hl.FillColor = r == "Murderer" and Color3.fromRGB(255, 0, 0) or r == "Sheriff" and Color3.fromRGB(0, 0, 255) or Color3.fromRGB(0, 255, 0)
	hl.OutlineColor = Color3.new(1, 1, 1)
end

local function toggleESP()
	espOn = not espOn
	for _, p in ipairs(Players:GetPlayers()) do
		if espOn then
			updateESP(p)
		else
			removeESP(p)
		end
	end
end
Players.PlayerRemoving:Connect(removeESP)
RunService.Heartbeat:Connect(function()
	if espOn then
		for _, p in ipairs(Players:GetPlayers()) do
			updateESP(p)
		end
	end
end)

local function sendChat(text)
	if not text or text == "" then
		return
	end
	local t = text:match("^/") and text or ("/" .. text)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local ch = TextChatService:FindFirstChild("TextChannels")
			local g = ch and (ch:FindFirstChild("RBXGeneral") or ch:FindFirstChild("General"))
			if g then
				g:SendAsync(t)
				return
			end
		end
		pcall(function()
			Players:Chat(t)
		end)
	end)
end

local jailed = {}
local function setJailed(plr, on)
	if not plr then
		return
	end
	jailed[plr] = on or nil
	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hrp then
		pcall(function()
			hrp.Anchored = on
		end)
	end
	if hum then
		pcall(function()
			hum.WalkSpeed = on and 0 or 16
			hum.JumpPower = on and 0 or 50
		end)
	end
end

local function findTarget(query, allowSelf)
	if not query or query == "" then
		return nil
	end
	local q = string.lower(query)
	if allowSelf and (q == "me" or q == "self") then
		return player
	end
	if q == "murder" or q == "murderer" then
		for _, p in ipairs(Players:GetPlayers()) do
			if getRole(p) == "Murderer" then
				return p
			end
		end
	end
	if q == "sheriff" or q == "sherif" then
		for _, p in ipairs(Players:GetPlayers()) do
			if getRole(p) == "Sheriff" then
				return p
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(p.Name), q, 1, true) or string.find(string.lower(p.DisplayName), q, 1, true) then
			if allowSelf or p ~= player then
				return p
			end
		end
	end
	return nil
end

local function fling(target)
	if not target or target == player then
		return
	end
	local tHrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local myHrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not tHrp or not myHrp then
		return
	end
	local old = myHrp.CFrame
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock() - start > 0.6 or not tHrp.Parent or not myHrp.Parent then
			conn:Disconnect()
			return
		end
		pcall(function()
			myHrp.CFrame = tHrp.CFrame
			tHrp.AssemblyLinearVelocity = Vector3.new(90, 380, 90)
		end)
	end)
	task.delay(0.65, function()
		if myHrp.Parent then
			pcall(function()
				myHrp.AssemblyLinearVelocity = Vector3.zero
				myHrp.CFrame = old
			end)
		end
	end)
end

local MapList = {
	"Biolab", "Icecastle", "Log Cabin", "Workshop", "Workplace", "Factory",
	"Milbase", "Station", "House2", "Hotel", "BeachResort", "Yacht",
	"Barn", "Farmhouse", "ChristmasItaly", "Manor", "Mineshaft",
	"VampireCastle", "Spaceship", "SkiVillage_6v6", "SkiVillage_RegularMode", "Pier",
}
local mapGui, statusLabel

local function showMap()
	if not mapGui then
		mapGui = Instance.new("ScreenGui")
		mapGui.Name = "VestaMapSelector"
		mapGui.ResetOnSpawn = false
		mapGui.DisplayOrder = 50
		mapGui.Parent = playerGui
		local f = Instance.new("Frame")
		f.Size = UDim2.new(0, 260, 0, 380)
		f.Position = UDim2.new(0.5, -130, 0.5, -190)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Active = true
		f.Draggable = true
		f.Parent = mapGui
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, -40, 0, 28)
		title.Position = UDim2.new(0, 12, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = "SELECT MAP"
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = f
		local x = Instance.new("TextButton")
		x.Size = UDim2.new(0, 26, 0, 22)
		x.Position = UDim2.new(1, -34, 0, 8)
		x.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		x.Text = "X"
		x.TextColor3 = Color3.new(1, 1, 1)
		x.Font = Enum.Font.GothamBold
		x.TextSize = 13
		x.Parent = f
		Instance.new("UICorner", x).CornerRadius = UDim.new(0, 6)
		x.MouseButton1Click:Connect(function()
			mapGui.Enabled = false
		end)
		local sc = Instance.new("ScrollingFrame")
		sc.Size = UDim2.new(1, -16, 1, -48)
		sc.Position = UDim2.new(0, 8, 0, 40)
		sc.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
		sc.BorderSizePixel = 0
		sc.ScrollBarThickness = 5
		sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sc.Parent = f
		Instance.new("UICorner", sc).CornerRadius = UDim.new(0, 7)
		local lay = Instance.new("UIListLayout", sc)
		lay.Padding = UDim.new(0, 4)
		for i, name in ipairs(MapList) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, -4, 0, 30)
			b.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			b.Text = name
			b.TextColor3 = Color3.fromRGB(235, 235, 240)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.LayoutOrder = i
			b.Parent = sc
			Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
			b.MouseButton1Click:Connect(function()
				sendChat("/map " .. name)
				mapGui.Enabled = false
				if statusLabel then
					statusLabel.Text = string.upper(name) .. " SET!"
					task.delay(2, function()
						if statusLabel.Text == string.upper(name) .. " SET!" then
							statusLabel.Text = "READY"
						end
					end)
				end
			end)
		end
	end
	mapGui.Enabled = true
end

-- ===== GUI =====
local floatGui = Instance.new("ScreenGui")
floatGui.Name = "VestaFloatButton"
floatGui.ResetOnSpawn = false
floatGui.DisplayOrder = 100
floatGui.Parent = playerGui

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 56, 0, 56)
floatBtn.Position = UDim2.new(1, -76, 0.72, 0)
floatBtn.BackgroundColor3 = Color3.new(0, 0, 0)
floatBtn.BorderSizePixel = 0
floatBtn.Text = "V"
floatBtn.TextColor3 = Color3.new(1, 1, 1)
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 24
floatBtn.AutoButtonColor = false
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(90, 90, 100)

local radialGui = Instance.new("ScreenGui")
radialGui.Name = "VestaRadialPanel"
radialGui.ResetOnSpawn = false
radialGui.DisplayOrder = 99
radialGui.Enabled = false
radialGui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.new(0, 420, 0, 470)
root.Position = UDim2.new(0.5, -210, 0.5, -250)
root.BackgroundTransparency = 1
root.Parent = radialGui

local circle = Instance.new("Frame")
circle.Size = UDim2.new(0, 360, 0, 360)
circle.Position = UDim2.new(0.5, -180, 0, 0)
circle.BackgroundTransparency = 1
circle.Parent = root

local center = Instance.new("Frame")
center.Size = UDim2.new(0, 100, 0, 100)
center.Position = UDim2.new(0.5, -50, 0.5, -50)
center.BackgroundColor3 = Color3.new(0, 0, 0)
center.BorderSizePixel = 0
center.Parent = circle
Instance.new("UICorner", center).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", center).Color = Color3.fromRGB(70, 70, 78)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -8, 0, 32)
title.Position = UDim2.new(0, 4, 0, 16)
title.BackgroundTransparency = 1
title.Text = "VESTA\nADMIN PANEL"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 12
title.TextWrapped = true
title.Parent = center

local fps = Instance.new("TextLabel")
fps.Size = UDim2.new(1, -8, 0, 16)
fps.Position = UDim2.new(0, 4, 0, 56)
fps.BackgroundTransparency = 1
fps.Text = "FPS: --"
fps.TextColor3 = Color3.fromRGB(180, 180, 190)
fps.Font = Enum.Font.GothamBold
fps.TextSize = 9
fps.Parent = center

local lf, fr = 0, 0
RunService.RenderStepped:Connect(function()
	fr += 1
	local now = os.clock()
	if now - lf >= 0.6 then
		local f = math.floor(fr / (now - lf))
		fr, lf = 0, now
		local p = 0
		pcall(function()
			p = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		fps.Text = string.format("FPS: %d | PING: %d", f, p)
	end
end)

local function flash(msg)
	if not statusLabel then
		return
	end
	statusLabel.Text = msg
	task.delay(2, function()
		if statusLabel.Text == msg then
			statusLabel.Text = "READY"
		end
	end)
end

local buttons = {
	{ name = "ESP", action = function()
		toggleESP()
		flash(espOn and "ESP: ON" or "ESP: OFF")
	end },
	{ name = "SHERIFF", action = function()
		sendChat("/sheriff")
		flash("SHERIFF GIVEN")
	end },
	{ name = "MURDERER", action = function()
		sendChat("/murderer")
		flash("MURDERER GIVEN")
	end },
	{ name = "GUN", action = function()
		local tool, name = giveHeldCopy("gun")
		if tool then
			flash((name or "GUN") .. " IN HAND")
		else
			flash("NO GUN ON YOU")
		end
	end },
	{ name = "KNIFE", action = function()
		local tool, name = giveHeldCopy("knife")
		if tool then
			flash((name or "KNIFE") .. " IN HAND")
		else
			flash("NO KNIFE ON YOU")
		end
	end },
	{ name = "MAP", action = function()
		showMap()
	end },
	{ name = "GOLD CARPET", action = function()
		giveGold()
		flash("GOLD CARPET")
	end },
	{ name = "RAINBOW", action = function()
		giveRainbow()
		flash("RAINBOW CARPET")
	end },
	{ name = "BLOW", action = function()
		giveDryer()
		flash("BLOW DRYER — HOLD CLICK")
	end },
	{ name = "SEA BOW", action = function()
		giveSeaBow()
		flash("SEA BOW")
	end },
	{ name = "BROOM", action = function()
		giveBroom()
		flash("BROOM")
	end },
	{ name = "SPEED COIL", action = function()
		giveSpeed()
		flash("SPEED COIL")
	end },
	{ name = "GRAVITY COIL", action = function()
		giveGravity()
		flash("GRAVITY COIL")
	end },
}

local radius, step = 135, (2 * math.pi) / #buttons
for i, d in ipairs(buttons) do
	local a = (i - 1) * step - math.pi / 2
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, 68, 0, 68)
	b.Position = UDim2.new(0.5, math.cos(a) * radius - 34, 0.5, math.sin(a) * radius - 34)
	b.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	b.BorderSizePixel = 0
	b.Text = d.name
	b.TextColor3 = Color3.fromRGB(240, 240, 245)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.TextWrapped = true
	b.AutoButtonColor = false
	b.Parent = circle
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(60, 60, 70)
	s.Thickness = 1.5
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(40, 40, 50) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(18, 18, 22) }):Play()
	end)
	b.MouseButton1Click:Connect(d.action)
end

-- two red boxes, just above the command bar
local function redBox(text, xScale)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -4, 0, 32)
	b.Position = UDim2.new(xScale, xScale == 0 and 0 or 4, 0, 0)
	b.BackgroundColor3 = Color3.fromRGB(170, 32, 42)
	b.BorderSizePixel = 0
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 13
	b.AutoButtonColor = false
	b.Parent = nil
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = Color3.fromRGB(210, 48, 58)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = Color3.fromRGB(170, 32, 42)
	end)
	return b
end

local redRow = Instance.new("Frame")
redRow.Name = "RemoveRow"
redRow.Size = UDim2.new(0, 300, 0, 32)
redRow.Position = UDim2.new(0.5, -150, 0, 368)
redRow.BackgroundTransparency = 1
redRow.Parent = root

local remAll = redBox("REMOVE ALL", 0)
remAll.Parent = redRow
local remThis = redBox("REMOVE THIS", 0.5)
remThis.Parent = redRow

remAll.MouseButton1Click:Connect(function()
	removeAll()
	flash("ALL REMOVED")
end)
remThis.MouseButton1Click:Connect(function()
	local ok, n = removeThis()
	flash(ok and ((n or "TOOL") .. " REMOVED") or "NOTHING EQUIPPED")
end)

local cmdBar = Instance.new("Frame")
cmdBar.Size = UDim2.new(0, 300, 0, 36)
cmdBar.Position = UDim2.new(0.5, -150, 0, 408)
cmdBar.BackgroundColor3 = Color3.new(0, 0, 0)
cmdBar.BorderSizePixel = 0
cmdBar.Parent = root
Instance.new("UICorner", cmdBar).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", cmdBar).Color = Color3.fromRGB(70, 70, 78)

local cmdBox = Instance.new("TextBox")
cmdBox.Size = UDim2.new(1, -16, 1, 0)
cmdBox.Position = UDim2.new(0, 8, 0, 0)
cmdBox.BackgroundTransparency = 1
cmdBox.PlaceholderText = "TYPE COMMAND  (jail player, fling murder...)"
cmdBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 150)
cmdBox.Text = ""
cmdBox.TextColor3 = Color3.new(1, 1, 1)
cmdBox.Font = Enum.Font.GothamBold
cmdBox.TextSize = 12
cmdBox.TextXAlignment = Enum.TextXAlignment.Left
cmdBox.ClearTextOnFocus = false
cmdBox.Parent = cmdBar

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 300, 0, 20)
statusLabel.Position = UDim2.new(0.5, -150, 0, 448)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "READY"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.Parent = root

local open = false
floatBtn.MouseButton1Click:Connect(function()
	open = not open
	radialGui.Enabled = open
	if open then
		statusLabel.Text = "READY"
	end
end)

cmdBox.FocusLost:Connect(function(enter)
	if not enter then
		return
	end
	local raw = cmdBox.Text
	cmdBox.Text = ""
	local low = string.lower(raw or "")
	local jailT = string.match(low, "^/?jail%s+(.+)$")
	local unjailT = string.match(low, "^/?unjail%s+(.+)$")
	local flingT = string.match(low, "^/?fling%s+(.+)$")
	if low == "map" or low == "/map" then
		showMap()
	elseif jailT then
		setJailed(findTarget(jailT, true), true)
		flash("JAILED")
	elseif low == "jail" or low == "/jail" then
		setJailed(player, true)
		flash("JAILED")
	elseif unjailT then
		setJailed(findTarget(unjailT, true), false)
		flash("UNJAILED")
	elseif low == "unjail" or low == "/unjail" then
		for p in pairs(jailed) do
			setJailed(p, false)
		end
		flash("UNJAILED")
	elseif flingT then
		fling(findTarget(flingT, false))
		flash("FLING")
	else
		flash("INVALID COMMAND")
	end
end)

print("[VESTA] radial ready")
