-- ==========================================
-- VESTA | CC COMMANDS  (Radial Circle)
-- Real gears from your VestaGears script
-- Gun/Knife show real model in hands
-- ==========================================
local Players          = game:GetService("Players")
local TextChatService  = game:GetService("TextChatService")
local LocalPlayer      = Players.LocalPlayer
local Debris           = game:GetService("Debris")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local mouse     = LocalPlayer:GetMouse()

for _, n in ipairs({"VestaRadialPanel","VestaFloatButton","VestaMapSelector","VestaGears","CustomAdminPanel"}) do
	local o = playerGui:FindFirstChild(n)
	if o then o:Destroy() end
end

local function say(msg)
	-- status will be set later
end

-- ========== HELPERS ==========
local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHandle(tool)
	return tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
end

local function stripScripts(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
end

local function addSound(parent, name, id, vol)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = vol or 0.5
	s.Parent = parent
	return s
end

-- aiming
local lastTouch
UserInputService.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch then lastTouch = i.Position end
end)
UserInputService.TouchTap:Connect(function(p)
	if p and p[1] then lastTouch = p[1] end
end)

local function isShiftLock()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return true end
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
		local p = Vector2.new(vp.X/2, vp.Y/2)
		if not shift and lastTouch then p = lastTouch end
		local ray = cam:ViewportPointToRay(p.X, p.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {ignore}
		local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		return res and res.Position or (ray.Origin + ray.Direction * 1000)
	end
	return mouse.Hit.Position
end

-- Real bomb gear asset (change this ID to swap the bomb model)
local BOMB_ASSET_ID = 11563251

-- preload
local cache, loading = {}, {}
local function preload(id)
	if not id or cache[id] ~= nil or loading[id] then return end
	loading[id] = true
	task.spawn(function()
		local template = false
		for a = 1, 4 do
			local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
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

local function loadReal(id, size, color)
	if cache[id] then return cache[id]:Clone() end
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. id) end)
	if ok and objs and objs[1] then
		local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
		if t then
			t.Parent = nil
			stripScripts(t)
			cache[id] = t
			return t:Clone()
		end
	end
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size or Vector3.new(1,1,2)
	h.Color = color or Color3.fromRGB(120,120,120)
	h.CanCollide = false
	h.Parent = tool
	return tool
end

task.spawn(function()
	preload(11719016)  -- dryer
	preload(236438668) -- seabow
	preload(99119158)  -- speed
	preload(16688968)  -- gravity
	preload(36913601)  -- broom
	preload(BOMB_ASSET_ID) -- bomb gear
end)

-- ========== ESP ==========
local espOn, highlights = false, {}
local function getRole(plr)
	local c = plr.Character
	if not c then return "Innocent" end
	if c:FindFirstChild("Knife") or (plr.Backpack and plr.Backpack:FindFirstChild("Knife")) then return "Murderer" end
	if c:FindFirstChild("Gun") or (plr.Backpack and plr.Backpack:FindFirstChild("Gun")) then return "Sheriff" end
	return "Innocent"
end

local function removeESP(plr)
	if highlights[plr] then highlights[plr]:Destroy() highlights[plr] = nil end
end

local function updateESP(plr)
	if plr == LocalPlayer then return end
	if not espOn then removeESP(plr) return end
	local char = plr.Character
	if char then
		local hl = highlights[plr]
		if not hl or not hl.Parent then
			hl = Instance.new("Highlight")
			hl.Adornee = char
			hl.Parent = char
			highlights[plr] = hl
		end
		local r = getRole(plr)
		hl.FillColor = r == "Murderer" and Color3.fromRGB(255,0,0) or r == "Sheriff" and Color3.fromRGB(0,0,255) or Color3.fromRGB(0,255,0)
		hl.OutlineColor = Color3.fromRGB(255,255,255)
	else
		removeESP(plr)
	end
end

local function toggleESP()
	espOn = not espOn
	for _, p in ipairs(Players:GetPlayers()) do
		if espOn then updateESP(p) else removeESP(p) end
	end
end

Players.PlayerRemoving:Connect(removeESP)
RunService.Heartbeat:Connect(function()
	if espOn then for _, p in ipairs(Players:GetPlayers()) do updateESP(p) end end
end)

-- ========== CHAT + MAP ==========
local function sendChat(text)
	if not text or text == "" then return end
	local t = text:match("^/") and text or ("/" .. text)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local ch = TextChatService:FindFirstChild("TextChannels")
			local g = ch and (ch:FindFirstChild("RBXGeneral") or ch:FindFirstChild("General"))
			if g then g:SendAsync(t) return end
		end
		pcall(function() Players:Chat(t) end)
	end)
end

local MapList = {"Biolab","Icecastle","Log Cabin","Workshop","Workplace","Factory","Milbase","Station","House2","Hotel","BeachResort","Yacht","Barn","Farmhouse","ChristmasItaly","Manor","Mineshaft","VampireCastle","Spaceship","SkiVillage_6v6","SkiVillage_RegularMode","Pier"}
local mapGui, statusLabel

local function showMap()
	if not mapGui then
		mapGui = Instance.new("ScreenGui")
		mapGui.Name = "VestaMapSelector"
		mapGui.ResetOnSpawn = false
		mapGui.DisplayOrder = 200
		mapGui.Parent = playerGui

		local f = Instance.new("Frame")
		f.Size = UDim2.new(0,260,0,380)
		f.Position = UDim2.new(0.5,-130,0.5,-190)
		f.BackgroundColor3 = Color3.fromRGB(0,0,0)
		f.BorderSizePixel = 0
		f.Active = true
		f.Draggable = true
		f.Parent = mapGui
		Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1,-40,0,28)
		title.Position = UDim2.new(0,12,0,8)
		title.BackgroundTransparency = 1
		title.Text = "SELECT MAP"
		title.TextColor3 = Color3.fromRGB(245,245,248)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = f

		local x = Instance.new("TextButton")
		x.Size = UDim2.new(0,26,0,22)
		x.Position = UDim2.new(1,-34,0,8)
		x.BackgroundColor3 = Color3.fromRGB(30,30,30)
		x.Text = "X"
		x.TextColor3 = Color3.new(1,1,1)
		x.Font = Enum.Font.GothamBold
		x.TextSize = 13
		x.Parent = f
		Instance.new("UICorner", x).CornerRadius = UDim.new(0,6)
		x.MouseButton1Click:Connect(function() mapGui.Enabled = false end)

		local sc = Instance.new("ScrollingFrame")
		sc.Size = UDim2.new(1,-16,1,-48)
		sc.Position = UDim2.new(0,8,0,40)
		sc.BackgroundColor3 = Color3.fromRGB(12,12,12)
		sc.BorderSizePixel = 0
		sc.ScrollBarThickness = 5
		sc.CanvasSize = UDim2.new(0,0,0,0)
		sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sc.Parent = f
		Instance.new("UICorner", sc).CornerRadius = UDim.new(0,7)
		local lay = Instance.new("UIListLayout", sc)
		lay.Padding = UDim.new(0,4)
		lay.SortOrder = Enum.SortOrder.LayoutOrder

		for i, name in ipairs(MapList) do
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1,-4,0,30)
			b.BackgroundColor3 = Color3.fromRGB(25,25,25)
			b.Text = name
			b.TextColor3 = Color3.fromRGB(235,235,240)
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.LayoutOrder = i
			b.Parent = sc
			Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
			b.MouseButton1Click:Connect(function()
				sendChat("/map " .. name)
				mapGui.Enabled = false
				if statusLabel then
					statusLabel.Text = string.upper(name) .. " SET!"
					task.delay(2, function()
						if statusLabel.Text == string.upper(name).." SET!" then
							statusLabel.Text = "READY"
						end
					end)
				end
			end)
		end
	end
	mapGui.Enabled = true
end

-- ========== REAL GEARS ==========

-- Blow Dryer
local function giveDryer()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Blow Dryer") then c["Blow Dryer"]:Destroy() end
	end
	local tool = loadReal(11719016, Vector3.new(0.8,0.8,1.8), Color3.fromRGB(220,60,120))
	tool.Name = "Blow Dryer"
	tool.CanBeDropped = false
	local h = getHandle(tool)
	if h then addSound(h, "Dryer", "rbxassetid://11717967", 0.7) end
	tool.Activated:Connect(function()
		if h and h:FindFirstChild("Dryer") then h.Dryer:Play() end
		if h then
			if not h:FindFirstChild("DryerAir") then
				local air = Instance.new("ParticleEmitter")
				air.Name = "DryerAir"
				air.Texture = "rbxasset://textures/particles/smoke_main.dds"
				air.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,150,200))
				air.LightEmission = 0.5
				air.Rate = 0
				air.Lifetime = NumberRange.new(0.5, 1.1)
				air.Speed = NumberRange.new(25, 45)
				air.SpreadAngle = Vector2.new(18,18)
				air.EmissionDirection = Enum.NormalId.Front
				air.Size = NumberSequence.new{NumberSequenceKeypoint.new(0,0.6), NumberSequenceKeypoint.new(1,3)}
				air.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0.3), NumberSequenceKeypoint.new(1,1)}
				air.Parent = h
				local sp = Instance.new("ParticleEmitter")
				sp.Name = "DryerSparkle"
				sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sp.Color = ColorSequence.new(Color3.fromRGB(255,200,230), Color3.fromRGB(255,255,255))
				sp.LightEmission = 1
				sp.Rate = 0
				sp.Lifetime = NumberRange.new(0.6, 1.4)
				sp.Speed = NumberRange.new(15, 40)
				sp.SpreadAngle = Vector2.new(35,35)
				sp.EmissionDirection = Enum.NormalId.Front
				sp.Size = NumberSequence.new{NumberSequenceKeypoint.new(0,0.5), NumberSequenceKeypoint.new(1,0)}
				sp.Parent = h
			end
			h.DryerAir:Emit(45)
			h.DryerSparkle:Emit(35)
		end
		local root = getChar():FindFirstChild("HumanoidRootPart")
		if root then
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(0,0,4e4)
			bv.Velocity = root.CFrame.LookVector * 55
			bv.Parent = root
			Debris:AddItem(bv, 0.35)
		end
	end)
	tool.Parent = bp
end

-- Sea Bow
local function giveSeaBow()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Sea Bow") then c["Sea Bow"]:Destroy() end
	end
	local tool = loadReal(236438668, Vector3.new(0.5,1.3,3), Color3.fromRGB(0,200,255))
	tool.Name = "Sea Bow"
	tool.CanBeDropped = false
	local h = getHandle(tool)
	if h then addSound(h, "Shot", "rbxassetid://99204505", 0.7) end
	tool.Activated:Connect(function()
		local char = getChar()
		if h and h:FindFirstChild("Shot") then
			h.Shot.Pitch = math.random(90,110)/100
			h.Shot:Play()
		end
		local arrow = Instance.new("Part")
		arrow.Size = Vector3.new(0.3,0.3,2.2)
		arrow.Color = Color3.fromRGB(0,200,255)
		arrow.Material = Enum.Material.Neon
		arrow.CanCollide = false
		addSound(arrow, "Hit", "rbxassetid://58274204", 0.8)
		local origin = h and h.Position or char.HumanoidRootPart.Position
		arrow.CFrame = CFrame.new(origin, aimPoint(char))
		arrow.AssemblyLinearVelocity = arrow.CFrame.LookVector * 120
		arrow.Parent = workspace
		local conn
		conn = arrow.Touched:Connect(function(p)
			if p:IsDescendantOf(char) then return end
			local s = 8 + 4 * math.random(1,3)
			pcall(function()
				workspace.Terrain:FillBall(arrow.Position, s, Enum.Material.Water)
				task.delay(7, function()
					pcall(function() workspace.Terrain:FillBall(arrow.Position, s, Enum.Material.Air) end)
				end)
			end)
			if arrow:FindFirstChild("Hit") then arrow.Hit:Play() end
			arrow.Anchored = true
			arrow.Transparency = 1
			conn:Disconnect()
		end)
		Debris:AddItem(arrow, 8)
	end)
	tool.Parent = bp
end

-- Speed Coil
local function giveSpeedCoil()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Speed Coil") then c["Speed Coil"]:Destroy() end
	end
	local tool = loadReal(99119158, Vector3.new(1.4,1.6,1.6), Color3.fromRGB(220,30,30))
	tool.Name = "Speed Coil"
	tool.CanBeDropped = false
	tool.TextureId = "rbxassetid://99170415"
	local old
	tool.Equipped:Connect(function()
		local hum = getChar():FindFirstChildOfClass("Humanoid")
		if hum then old = hum.WalkSpeed; hum.WalkSpeed = 40 end
	end)
	tool.Unequipped:Connect(function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and old then hum.WalkSpeed = old end
	end)
	tool.Parent = bp
end

-- Gravity Coil
local function giveGravityCoil()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Gravity Coil") then c["Gravity Coil"]:Destroy() end
	end
	local tool = loadReal(16688968, Vector3.new(1.4,1.6,1.6), Color3.fromRGB(60,120,255))
	tool.Name = "Gravity Coil"
	tool.CanBeDropped = false
	tool.TextureId = "rbxassetid://16619617"
	local force, loop
	tool.Equipped:Connect(function()
		local hrp = getChar():FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		force = Instance.new("BodyForce")
		force.Parent = hrp
		local last = -1
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent then if loop then loop:Disconnect() end return end
			local m = hrp.AssemblyMass
			if m ~= last then
				last = m
				force.Force = Vector3.new(0, m * workspace.Gravity * 0.75, 0)
			end
		end)
	end)
	tool.Unequipped:Connect(function()
		if loop then loop:Disconnect() end
		if force then force:Destroy() end
	end)
	tool.Parent = bp
end

-- Broom: real broom in your inventory. Equip it to run the animation-triggered flight script.
local BROOM_TRIGGER_IDS = {
	["114924283270252"] = true,
	["130490463850590"] = true,
}
local BROOM_FORWARD_SPEED = 90 -- studs/s (forward and backward)
local BROOM_SIDE_SPEED    = 60 -- studs/s (left and right)

local function giveBroom()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Broom") then c.Broom:Destroy() end
	end
	local tool = loadReal(36913601, Vector3.new(0.4,0.4,5), Color3.fromRGB(110,70,35))
	tool.Name = "Broom"
	tool.CanBeDropped = false
	tool.TextureId = "rbxthumb://type=Asset&id=36913601&w=420&h=420"

	local player = LocalPlayer
	local camera = workspace.CurrentCamera
	local controls
	pcall(function()
		controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
	end)

	local runConnection
	local cleanup
	local animTrack
	local forceFly = false -- only used if the trigger animations can't be loaded

	local function isTriggerPlaying(animator)
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local id = tostring(track.Animation.AnimationId):match("%d+")
			if id and BROOM_TRIGGER_IDS[id] then
				return true
			end
		end
		return false
	end

	local function setupCharacter(character)
		if runConnection then
			runConnection:Disconnect()
			runConnection = nil
		end

		local humanoid = character:WaitForChild("Humanoid")
		local root = character:WaitForChild("HumanoidRootPart")
		local animator = humanoid:WaitForChild("Animator")

		local flying = false
		local attachment, linearVelocity, align

		local function activate()
			flying = true

			attachment = Instance.new("Attachment")
			attachment.Name = "FlightAttachment"
			attachment.Parent = root

			linearVelocity = Instance.new("LinearVelocity")
			linearVelocity.Attachment0 = attachment
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.MaxForce = math.huge
			linearVelocity.VectorVelocity = Vector3.zero
			linearVelocity.Parent = root

			align = Instance.new("AlignOrientation")
			align.Mode = Enum.OrientationAlignmentMode.OneAttachment
			align.Attachment0 = attachment
			align.MaxTorque = math.huge
			align.Responsiveness = 30
			align.CFrame = root.CFrame
			align.Parent = root

			humanoid.PlatformStand = true
		end

		local function deactivate()
			flying = false

			if linearVelocity then linearVelocity:Destroy() linearVelocity = nil end
			if align then align:Destroy() align = nil end
			if attachment then attachment:Destroy() attachment = nil end

			if humanoid.Parent then
				humanoid.PlatformStand = false
			end
		end

		cleanup = function()
			if runConnection then runConnection:Disconnect() runConnection = nil end
			if flying then deactivate() end
		end

		runConnection = RunService.Heartbeat:Connect(function()
			if humanoid.Health <= 0 then
				if flying then deactivate() end
				return
			end

			local shouldFly = forceFly or isTriggerPlaying(animator)

			if shouldFly and not flying then
				activate()
			elseif not shouldFly and flying then
				deactivate()
			end

			if flying then
				-- x = right(+)/left(-), z = backward(+)/forward(-), relative to the camera
				local move = controls:GetMoveVector()
				local camCF = camera.CFrame

				local velocity = camCF.RightVector * (move.X * BROOM_SIDE_SPEED)
					+ camCF.LookVector * (-move.Z * BROOM_FORWARD_SPEED)

				linearVelocity.VectorVelocity = velocity

				-- Face the direction the camera is looking
				align.CFrame = CFrame.lookAt(root.Position, root.Position + camCF.LookVector)
			end
		end)

		humanoid.Died:Once(function()
			if flying then deactivate() end
			if runConnection then
				runConnection:Disconnect()
				runConnection = nil
			end
		end)
	end

	local function stopAnim()
		if animTrack then pcall(function() animTrack:Stop() end) animTrack = nil end
		forceFly = false
	end

	tool.Equipped:Connect(function()
		if not controls then return end
		local char = getChar()
		task.spawn(setupCharacter, char)

		-- play the trigger animation ourselves so the flight starts automatically
		stopAnim()
		local humanoid = char:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")
		for _, id in ipairs({"114924283270252", "130490463850590"}) do
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://" .. id
			local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
			if ok and track then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
				animTrack = track
				break
			end
		end
		-- if no animation could be played, fly anyway while the broom is equipped
		if not animTrack then forceFly = true end
	end)
	tool.Unequipped:Connect(function()
		stopAnim()
		if cleanup then cleanup() cleanup = nil end
	end)
	tool.Destroying:Connect(function()
		stopAnim()
		if cleanup then cleanup() cleanup = nil end
	end)
	tool.Parent = bp
end

-- Gold Carpet: asset 1016183873, sit on it, rainbow-carpet trail system in gold
local GOLD_CARPET_ID = 1016183873

local function loadCarpetParts()
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. GOLD_CARPET_ID) end)
	if not (ok and objs and objs[1]) then return nil end
	local root = objs[1]
	stripScripts(root)
	return root
end

local function giveGoldCarpet()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("GoldenCarpet") then c.GoldenCarpet:Destroy() end
	end

	-- held tool is just an invisible handle; the carpet you sit on is built on equip
	local tool = Instance.new("Tool")
	tool.Name = "GoldenCarpet"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.TextureId = "rbxthumb://type=Asset&id=" .. GOLD_CARPET_ID .. "&w=420&h=420"
	local hold = Instance.new("Part")
	hold.Name = "Handle"
	hold.Size = Vector3.new(0.5,0.5,0.5)
	hold.Transparency = 1
	hold.CanCollide = false
	hold.Parent = tool

	local source = loadCarpetParts()

	local GOLD = Color3.fromRGB(255,200,40)
	local PALE = Color3.fromRGB(255,245,170)
	local DEEP = Color3.fromRGB(210,120,0)
	local goldSeq = ColorSequence.new{
		ColorSequenceKeypoint.new(0, PALE),
		ColorSequenceKeypoint.new(0.4, GOLD),
		ColorSequenceKeypoint.new(1, DEEP),
	}
	local model, bv, bg, loop, cycle
	local ribbonAlive = false

	local function stop()
		if loop then loop:Disconnect() loop = nil end
		ribbonAlive = false
		if cycle then cycle:Disconnect() cycle = nil end
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		if model then model:Destroy() model = nil end
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Sit = false end
	end

	local function start()
		stop()
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end
		if not source then source = loadCarpetParts() end

		model = Instance.new("Model")
		model.Name = "VestaGoldCarpet"
		local parts, main = {}, nil
		if source then
			local list = {}
			if source:IsA("BasePart") then table.insert(list, source) end
			for _, d in ipairs(source:GetDescendants()) do
				if d:IsA("BasePart") then table.insert(list, d) end
			end
			-- biggest part becomes the base
			local biggest, bigVol = nil, -1
			for _, d in ipairs(list) do
				local v = d.Size.X * d.Size.Y * d.Size.Z
				if v > bigVol then biggest, bigVol = d, v end
			end
			for _, d in ipairs(list) do
				local p = d:Clone()
				for _, ch in ipairs(p:GetChildren()) do
					if ch:IsA("Weld") or ch:IsA("WeldConstraint") or ch:IsA("Motor6D") or ch:IsA("ParticleEmitter") or ch:IsA("Trail") or ch:IsA("Script") or ch:IsA("LocalScript") then
						ch:Destroy()
					end
				end
				p.Anchored = false
				p.CanCollide = false
				p.Massless = true
				p.Transparency = 0
				parts[d] = p
				p.Parent = model
				if d == biggest then main = p end
			end
		end
		if not main then
			-- fallback flat carpet
			main = Instance.new("Part")
			main.Size = Vector3.new(5,0.3,6.5)
			main.Color = GOLD
			main.Material = Enum.Material.Neon
			main.CanCollide = false
			main.Massless = true
			main.Parent = model
			parts[main] = main
		end
		model.PrimaryPart = main
		model:PivotTo(hrp.CFrame * CFrame.new(0, -2.6, 0))
		for _, p in pairs(parts) do
			if p ~= main then
				local w = Instance.new("WeldConstraint")
				w.Part0 = main
				w.Part1 = p
				w.Parent = main
			end
		end
		local mw = Instance.new("WeldConstraint")
		mw.Part0 = hrp
		mw.Part1 = main
		mw.Parent = main
		model.Parent = char

		-- ===== RAINBOW CARPET TRAIL (same system as the gear), in GOLD =====
		ribbonAlive = true
		local GOLD_STRIPS = {
			Vector3.new(1.00, 0.96, 0.65),
			Vector3.new(1.00, 0.90, 0.40),
			Vector3.new(1.00, 0.83, 0.18),
			Vector3.new(1.00, 0.76, 0.05),
			Vector3.new(0.95, 0.68, 0.00),
			Vector3.new(0.85, 0.58, 0.00),
			Vector3.new(0.70, 0.45, 0.00),
		}
		local BaseUrl = "http://www.roblox.com/asset/?id="

		local ColorPart = Instance.new("Part")
		ColorPart.Name = "ColorPart"
		ColorPart.Material = Enum.Material.SmoothPlastic
		ColorPart.Reflectance = 0.25
		ColorPart.Transparency = 0.1
		ColorPart.Size = Vector3.new(1,1,1)
		ColorPart.Anchored = true
		ColorPart.CanCollide = false
		ColorPart.Locked = true
		ColorPart.TopSurface = Enum.SurfaceType.SmoothNoOutlines
		ColorPart.BottomSurface = Enum.SurfaceType.SmoothNoOutlines
		ColorPart.FrontSurface = Enum.SurfaceType.SmoothNoOutlines
		ColorPart.BackSurface = Enum.SurfaceType.SmoothNoOutlines
		ColorPart.LeftSurface = Enum.SurfaceType.SmoothNoOutlines
		ColorPart.RightSurface = Enum.SurfaceType.SmoothNoOutlines
		local ColorMesh = Instance.new("SpecialMesh")
		ColorMesh.Name = "Mesh"
		ColorMesh.MeshType = Enum.MeshType.FileMesh
		ColorMesh.MeshId = BaseUrl .. "9856898"
		ColorMesh.TextureId = BaseUrl .. "1361097"
		ColorMesh.Scale = ColorPart.Size * 2
		ColorMesh.Offset = Vector3.new(0,0,0)
		ColorMesh.VertexColor = Vector3.new(1,1,1)
		ColorMesh.Parent = ColorPart
		local ColorLight = Instance.new("PointLight")
		ColorLight.Name = "Light"
		ColorLight.Brightness = 50
		ColorLight.Range = 8
		ColorLight.Shadows = false
		ColorLight.Enabled = true
		ColorLight.Parent = ColorPart

		local function createGoldRibbon(length, cf)
			local ribbon = Instance.new("Model")
			ribbon.Name = "GoldPart"
			for i, v in ipairs(GOLD_STRIPS) do
				local part = ColorPart:Clone()
				part.Name = "Part"
				part.Size = Vector3.new(0.5, 0.5, length)
				part.CFrame = cf * CFrame.new(0.5 * (i - (#GOLD_STRIPS + 1) / 2), 0, 0)
				part.Mesh.Scale = part.Size * 2
				part.Mesh.VertexColor = v
				part.Light.Color = Color3.new(v.X, v.Y, v.Z)
				part.Parent = ribbon
			end
			return ribbon
		end

		task.spawn(function()
			local lastPlace
			while ribbonAlive and main.Parent and hrp.Parent do
				local currentPlace = main.Position
				local vel = hrp.AssemblyLinearVelocity
				local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
				if lastPlace and speed > 10 then
					local distance = (lastPlace - currentPlace).Magnitude
					if distance > 0.01 then
						local length = distance + 3.5
						local mid = lastPlace + (currentPlace - lastPlace).Unit * (distance / 2)
						local cf = CFrame.new(mid, currentPlace)
						local ribbon = createGoldRibbon(length, cf)
						Debris:AddItem(ribbon, 1)
						ribbon.Parent = workspace
					end
					lastPlace = currentPlace
				else
					lastPlace = currentPlace
				end
				task.wait(1/10)
			end
		end)

		-- ===== FLY (sitting) =====
		hum.Sit = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6,1e6,1e6)
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6,1e6,1e6)
		bg.P = 9000
		bg.D = 600
		bg.Parent = hrp
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent or not model then return stop() end
			hum.Sit = true
			local cam = workspace.CurrentCamera.CFrame
			local mv = Vector3.zero
			if hum.MoveDirection.Magnitude > 0.05 then
				local lm = cam:VectorToObjectSpace(hum.MoveDirection)
				mv = Vector3.new(lm.X, 0, lm.Z)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				mv -= Vector3.new(0,1,0)
			end
			local dir = cam.RightVector * mv.X + cam.LookVector * -mv.Z + Vector3.yAxis * mv.Y
			bv.Velocity = dir.Magnitude > 0.05 and dir.Unit * 80 or Vector3.zero
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
			end
		end)
	end

	tool.Equipped:Connect(start)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
	tool.Parent = bp
end

local function giveRainbow()
	pcall(function()
		loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Open-Source-227632"))()
	end)
end

-- ========== BOMB (real bomb gear) ==========
-- Click/tap: drops the bomb under your feet, blast launches you up.
-- No cooldown. Infinite double jump while you own it.
local function giveBomb()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("Bomb") then c.Bomb:Destroy() end
	end

	local tool = loadReal(BOMB_ASSET_ID, Vector3.new(1.3,1.3,1.3), Color3.fromRGB(25,25,28))
	tool.Name = "Bomb"
	tool.CanBeDropped = false
	local handle = getHandle(tool)

	tool.Activated:Connect(function()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end
		local feet = hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y/2, 0)

		local dropped
		if handle then
			dropped = handle:Clone()
			for _, ch in ipairs(dropped:GetDescendants()) do
				if ch:IsA("Script") or ch:IsA("LocalScript") or ch:IsA("Weld") or ch:IsA("WeldConstraint") or ch:IsA("Sound") then
					ch:Destroy()
				end
			end
			dropped.Transparency = 0
		else
			dropped = Instance.new("Part")
			dropped.Shape = Enum.PartType.Ball
			dropped.Size = Vector3.new(1.5,1.5,1.5)
			dropped.Color = Color3.fromRGB(25,25,28)
		end
		dropped.Name = "VestaBomb"
		dropped.Anchored = true
		dropped.CanCollide = false
		dropped.CFrame = CFrame.new(feet)
		dropped.Parent = workspace

		task.delay(0.12, function()
			local pos = dropped.Position
			dropped:Destroy()
			local ex = Instance.new("Explosion")
			ex.Position = pos
			ex.BlastRadius = 9
			ex.BlastPressure = 0
			ex.DestroyJointRadiusPercent = 0
			ex.ExplosionType = Enum.ExplosionType.NoCraters
			ex.Parent = workspace
			local r = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude < 14 then
				local v = r.AssemblyLinearVelocity
				r.AssemblyLinearVelocity = Vector3.new(v.X, 80, v.Z)
			end
		end)
	end)

	local jumpConn = UserInputService.JumpRequest:Connect(function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	tool.Destroying:Connect(function() jumpConn:Disconnect() end)

	tool.Parent = bp
end

local function removeAll()
	local names = {"Blow Dryer","Sea Bow","Speed Coil","Gravity Coil","Broom","GoldenCarpet","Bomb"}
	for _, c in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character}) do
		if c then
			for _, item in ipairs(c:GetChildren()) do
				if item:IsA("Tool") then
					for _, n in ipairs(names) do
						if item.Name == n then item:Destroy() break end
					end
				end
			end
		end
	end
end

local function removeThis()
	local char = LocalPlayer.Character
	if not char then return false end
	for _, ch in ipairs(char:GetChildren()) do
		if ch:IsA("Tool") then
			local n = ch.Name
			ch:Destroy()
			return true, n
		end
	end
	return false
end

-- ========== GUI ==========
local floatGui = Instance.new("ScreenGui")
floatGui.Name = "VestaFloatButton"
floatGui.ResetOnSpawn = false
floatGui.DisplayOrder = 100
floatGui.Parent = playerGui

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0,62,0,62)
floatBtn.Position = UDim2.new(1,-82,0.72,0)
floatBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
floatBtn.BorderSizePixel = 0
floatBtn.Text = "V"
floatBtn.TextColor3 = Color3.fromRGB(255,255,255)
floatBtn.Font = Enum.Font.FredokaOne
floatBtn.TextSize = 36
floatBtn.AutoButtonColor = false
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1,0)

local radialGui = Instance.new("ScreenGui")
radialGui.Name = "VestaRadialPanel"
radialGui.ResetOnSpawn = false
radialGui.DisplayOrder = 99
radialGui.Enabled = false
radialGui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.new(0,360,0,360)
root.Position = UDim2.new(0.5,-180,0.5,-180)
root.BackgroundTransparency = 1
root.Parent = radialGui

local center = Instance.new("Frame")
center.Size = UDim2.new(0,100,0,100)
center.Position = UDim2.new(0.5,-50,0.5,-50)
center.BackgroundColor3 = Color3.fromRGB(0,0,0)
center.BorderSizePixel = 0
center.Parent = root
Instance.new("UICorner", center).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", center).Color = Color3.fromRGB(70,70,78)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-8,0,32)
title.Position = UDim2.new(0,4,0,16)
title.BackgroundTransparency = 1
title.Text = "VESTA\nADMIN PANEL"
title.TextColor3 = Color3.new(1,1,1)
title.Font = Enum.Font.GothamBlack
title.TextSize = 12
title.TextWrapped = true
title.Parent = center

local fps = Instance.new("TextLabel")
fps.Size = UDim2.new(1,-8,0,16)
fps.Position = UDim2.new(0,4,0,56)
fps.BackgroundTransparency = 1
fps.Text = "FPS: -- | PING: --"
fps.TextColor3 = Color3.fromRGB(180,180,190)
fps.Font = Enum.Font.GothamBold
fps.TextSize = 9
fps.Parent = center

local lf, fr = 0, 0
RunService.RenderStepped:Connect(function()
	fr += 1
	local now = os.clock()
	if now - lf >= 0.6 then
		local f = math.floor(fr / (now - lf))
		fr = 0
		lf = now
		local p = 0
		pcall(function() p = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end)
		fps.Text = string.format("FPS: %d | PING: %d MS", f, p)
	end
end)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0,300,0,20)
statusLabel.Position = UDim2.new(0.5,-150,1,74)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "READY"
statusLabel.TextColor3 = Color3.fromRGB(200,200,210)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.Parent = root

local function flash(msg)
	statusLabel.Text = msg
	task.delay(2, function()
		if statusLabel.Text == msg then statusLabel.Text = "READY" end
	end)
end

local buttons = {
	{name="ESP", action=function() toggleESP() flash(espOn and "ESP: ON" or "ESP: OFF") end},
	{name="SHERIFF", action=function() sendChat("/sheriff") flash("SHERIFF GIVEN") end},
	{name="MURDERER", action=function() sendChat("/murderer") flash("MURDERER GIVEN") end},
	{name="BOMB", action=function() giveBomb() flash("BOMB") end},
	{name="MAP", action=function() showMap() end},
	{name="GOLD CARPET", action=function() giveGoldCarpet() flash("GOLDEN CARPET") end},
	{name="RAINBOW", action=function() giveRainbow() flash("RAINBOW CARPET") end},
	{name="BLOW", action=function() giveDryer() flash("BLOW DRYER") end},
	{name="SEA BOW", action=function() giveSeaBow() flash("SEA BOW") end},
	{name="BROOM", action=function() giveBroom() flash("BROOM") end},
	{name="SPEED COIL", action=function() giveSpeedCoil() flash("SPEED COIL") end},
	{name="GRAVITY COIL", action=function() giveGravityCoil() flash("GRAVITY COIL") end},
}

local radius = 135
local step = (2 * math.pi) / #buttons
for i, d in ipairs(buttons) do
	local a = (i-1)*step - math.pi/2
	local x = math.cos(a) * radius
	local y = math.sin(a) * radius
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0,68,0,68)
	b.Position = UDim2.new(0.5, x-34, 0.5, y-34)
	b.BackgroundColor3 = Color3.fromRGB(18,18,22)
	b.BorderSizePixel = 0
	b.Text = d.name
	b.TextColor3 = Color3.fromRGB(240,240,245)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 10
	b.TextWrapped = true
	b.AutoButtonColor = false
	b.Parent = root
	Instance.new("UICorner", b).CornerRadius = UDim.new(1,0)
	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(60,60,70)
	s.Thickness = 1.5
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(40,40,50)}):Play()
		s.Color = Color3.fromRGB(120,120,140)
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(18,18,22)}):Play()
		s.Color = Color3.fromRGB(60,60,70)
	end)
	b.MouseButton1Click:Connect(d.action)
end

-- two red boxes below the radial
local function makeRedBox(text, xOff, action)
	local rb = Instance.new("TextButton")
	rb.Size = UDim2.new(0,140,0,38)
	rb.Position = UDim2.new(0.5, xOff, 1, 20)
	rb.BackgroundColor3 = Color3.fromRGB(140,35,45)
	rb.BorderSizePixel = 0
	rb.Text = text
	rb.TextColor3 = Color3.fromRGB(255,255,255)
	rb.Font = Enum.Font.GothamBold
	rb.TextSize = 12
	rb.AutoButtonColor = false
	rb.Parent = root
	Instance.new("UICorner", rb).CornerRadius = UDim.new(0,8)
	local st = Instance.new("UIStroke", rb)
	st.Color = Color3.fromRGB(180,50,60)
	st.Thickness = 1.5
	rb.MouseEnter:Connect(function()
		TweenService:Create(rb, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(180,50,60)}):Play()
	end)
	rb.MouseLeave:Connect(function()
		TweenService:Create(rb, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(140,35,45)}):Play()
	end)
	rb.MouseButton1Click:Connect(action)
end
makeRedBox("REMOVE ALL", -148, function() removeAll() flash("ALL GEARS REMOVED") end)
makeRedBox("REMOVE THIS", 8, function()
	local ok, n = removeThis()
	flash(ok and ((n or "TOOL").." REMOVED") or "NOTHING EQUIPPED")
end)

local open = false
floatBtn.MouseButton1Click:Connect(function()
	open = not open
	radialGui.Enabled = open
	if open then statusLabel.Text = "READY" end
end)

print("[VESTA] Radial ready")
