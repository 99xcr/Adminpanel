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
	preload(402305186) -- gold carpet
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
		mapGui.DisplayOrder = 50
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

-- Broom (fly)
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

	local bv, bg, loop
	local function stop()
		if loop then loop:Disconnect() loop = nil end
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false end
	end
	local function start()
		stop()
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end
		hum.PlatformStand = true
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6,1e6,1e6)
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6,1e6,1e6)
		bg.P = 9000
		bg.D = 600
		bg.Parent = hrp
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent then return stop() end
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

-- Gold Carpet
local function giveGoldCarpet()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c and c:FindFirstChild("GoldenCarpet") then c.GoldenCarpet:Destroy() end
	end
	local tool = loadReal(402305186, Vector3.new(4,0.2,6), Color3.fromRGB(255,200,40))
	tool.Name = "GoldenCarpet"
	tool.CanBeDropped = false
	tool.TextureId = "rbxassetid://1014109561"
	tool.Parent = bp
end

local function giveRainbow()
	pcall(function()
		loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Open-Source-227632"))()
	end)
end

-- ========== GUN / KNIFE – real model in hands ==========
local function giveGun()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c then
			local old = c:FindFirstChild("VestaGun")
			if old then old:Destroy() end
		end
	end

	local source
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("Gun") then
		source = char.Gun
	elseif bp:FindFirstChild("Gun") then
		source = bp.Gun
	end

	local tool
	if source then
		tool = source:Clone()
		stripScripts(tool)
		tool.Name = "VestaGun"
	else
		-- try load a common gun asset as last resort
		tool = loadReal(16619617, Vector3.new(0.5,0.5,2), Color3.fromRGB(40,40,45))
		tool.Name = "VestaGun"
		tool.TextureId = "rbxassetid://16619617"
	end
	tool.CanBeDropped = false
	tool.Parent = bp
	-- equip immediately so it shows in hands
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(tool) end) end
end

local function giveKnife()
	local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not bp then return end
	for _, c in ipairs({bp, LocalPlayer.Character}) do
		if c then
			local old = c:FindFirstChild("VestaKnife")
			if old then old:Destroy() end
		end
	end

	local source
	local char = LocalPlayer.Character
	if char and char:FindFirstChild("Knife") then
		source = char.Knife
	elseif bp:FindFirstChild("Knife") then
		source = bp.Knife
	end

	local tool
	if source then
		tool = source:Clone()
		stripScripts(tool)
		tool.Name = "VestaKnife"
	else
		tool = Instance.new("Tool")
		tool.Name = "VestaKnife"
		tool.RequiresHandle = true
		tool.TextureId = "rbxassetid://16619617"
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Size = Vector3.new(0.3,0.3,1.4)
		h.Color = Color3.fromRGB(180,180,190)
		h.Material = Enum.Material.Metal
		h.CanCollide = false
		h.Parent = tool
	end
	tool.CanBeDropped = false
	tool.Parent = bp
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then pcall(function() hum:EquipTool(tool) end) end
end

local function removeAll()
	local names = {"Blow Dryer","Sea Bow","Speed Coil","Gravity Coil","Broom","GoldenCarpet","VestaGun","VestaKnife"}
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
floatBtn.Size = UDim2.new(0,56,0,56)
floatBtn.Position = UDim2.new(1,-76,0.72,0)
floatBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
floatBtn.BorderSizePixel = 0
floatBtn.Text = "V"
floatBtn.TextColor3 = Color3.new(1,1,1)
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 24
floatBtn.AutoButtonColor = false
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1,0)
Instance.new("UIStroke", floatBtn).Color = Color3.fromRGB(90,90,100)

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

local cmdBar = Instance.new("Frame")
cmdBar.Size = UDim2.new(0,300,0,36)
cmdBar.Position = UDim2.new(0.5,-150,1,18)
cmdBar.BackgroundColor3 = Color3.fromRGB(0,0,0)
cmdBar.BorderSizePixel = 0
cmdBar.Parent = root
Instance.new("UICorner", cmdBar).CornerRadius = UDim.new(0,8)

local cmdBox = Instance.new("TextBox")
cmdBox.Size = UDim2.new(1,-16,1,0)
cmdBox.Position = UDim2.new(0,8,0,0)
cmdBox.BackgroundTransparency = 1
cmdBox.PlaceholderText = "TYPE COMMAND (jail / fling / map...)"
cmdBox.PlaceholderColor3 = Color3.fromRGB(140,140,150)
cmdBox.Text = ""
cmdBox.TextColor3 = Color3.new(1,1,1)
cmdBox.Font = Enum.Font.GothamBold
cmdBox.TextSize = 12
cmdBox.TextXAlignment = Enum.TextXAlignment.Left
cmdBox.ClearTextOnFocus = false
cmdBox.Parent = cmdBar

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0,300,0,20)
statusLabel.Position = UDim2.new(0.5,-150,1,58)
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
	{name="GUN", action=function() giveGun() flash("GUN GIVEN") end},
	{name="KNIFE", action=function() giveKnife() flash("KNIFE GIVEN") end},
	{name="MAP", action=function() showMap() end},
	{name="GOLD CARPET", action=function() giveGoldCarpet() flash("GOLDEN CARPET") end},
	{name="RAINBOW", action=function() giveRainbow() flash("RAINBOW CARPET") end},
	{name="BLOW", action=function() giveDryer() flash("BLOW DRYER") end},
	{name="SEA BOW", action=function() giveSeaBow() flash("SEA BOW") end},
	{name="BROOM", action=function() giveBroom() flash("BROOM") end},
	{name="SPEED COIL", action=function() giveSpeedCoil() flash("SPEED COIL") end},
	{name="GRAVITY COIL", action=function() giveGravityCoil() flash("GRAVITY COIL") end},
	{name="REMOVE ALL", action=function() removeAll() flash("ALL GEARS REMOVED") end},
	{name="REMOVE THIS", action=function()
		local ok, n = removeThis()
		flash(ok and ((n or "TOOL").." REMOVED") or "NOTHING EQUIPPED")
	end},
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
	if d.name == "REMOVE ALL" or d.name == "REMOVE THIS" then
		b.BackgroundColor3 = Color3.fromRGB(140,35,45)
		s.Color = Color3.fromRGB(180,50,60)
	end
	b.MouseEnter:Connect(function()
		if d.name:find("REMOVE") then
			TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(180,50,60)}):Play()
		else
			TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(40,40,50)}):Play()
			s.Color = Color3.fromRGB(120,120,140)
		end
	end)
	b.MouseLeave:Connect(function()
		if d.name:find("REMOVE") then
			TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(140,35,45)}):Play()
		else
			TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(18,18,22)}):Play()
			s.Color = Color3.fromRGB(60,60,70)
		end
	end)
	b.MouseButton1Click:Connect(d.action)
end

local open = false
floatBtn.MouseButton1Click:Connect(function()
	open = not open
	radialGui.Enabled = open
	if open then statusLabel.Text = "READY" end
end)

cmdBox.FocusLost:Connect(function(enter)
	if not enter then return end
	local t = cmdBox.Text
	cmdBox.Text = ""
	local low = string.lower(t or "")
	if low == "map" or low == "/map" then showMap()
	elseif low:find("jail") then flash("JAIL COMMAND SENT")
	elseif low:find("fling") then flash("FLING COMMAND SENT")
	else flash("INVALID COMMAND") end
end)

print("[VESTA] Radial ready")
