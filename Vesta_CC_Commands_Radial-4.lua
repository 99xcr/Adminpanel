-- ==========================================
-- VESTA | CC COMMANDS  (Radial Circle GUI)
-- Floating V → circular admin panel
-- Real gears from VestaGears + proper Gun/Knife
-- ==========================================
local Players            = game:GetService("Players")
local TextChatService    = game:GetService("TextChatService")
local LocalPlayer        = Players.LocalPlayer
local Debris             = game:GetService("Debris")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local camera    = workspace.CurrentCamera
local mouse     = LocalPlayer:GetMouse()

for _, name in ipairs({"CustomAdminPanel","MMVWatermark","LanguageSelectorGui","VestaMapSelector","VestaRadialPanel","VestaFloatButton","VestaGears"}) do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local function tr(k)
	local t = {
		readyStatus = "READY",
		jailRan = "JAIL/UNJAIL EXECUTED!",
		flingRan = "FLING EXECUTED!",
		playerBlockRan = "PLAYER BLOCK/UNBLOCK EXECUTED!",
		invalidCommand = "INVALID COMMAND!",
	}
	return t[k] or k
end

-- ==========================================
-- HELPERS (from VestaGears)
-- ==========================================
local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHandle(tool)
	return tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
end

local function addSound(parent, name, id, volume)
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Parent = parent
	return s
end

local function stripScripts(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
	end
end

-- aiming
local lastTouch
UserInputService.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch then lastTouch = i.Position end
end)
UserInputService.TouchTap:Connect(function(pos)
	if pos and pos[1] then lastTouch = pos[1] end
end)

local function isShiftLock()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then return true end
	local ok, rt = pcall(function()
		return UserSettings():GetService("UserGameSettings").RotationType
	end)
	return ok and rt == Enum.RotationType.CameraRelative
end

local function aimPoint(origin, ignore)
	local shiftlock = isShiftLock()
	if shiftlock or (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) then
		local cam = workspace.CurrentCamera
		local vp = cam.ViewportSize
		local p = Vector2.new(vp.X/2, vp.Y/2)
		if not shiftlock and lastTouch then p = lastTouch end
		local ray = cam:ViewportPointToRay(p.X, p.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {ignore}
		local res = workspace:Raycast(ray.Origin, ray.Direction*1000, params)
		return res and res.Position or (ray.Origin + ray.Direction*1000)
	end
	return mouse.Hit.Position
end

-- preload cache
local cache, loading = {}, {}
local function preload(id)
	if not id or id==0 or cache[id]~=nil or loading[id] then return end
	loading[id] = true
	task.spawn(function()
		local template = false
		for attempt=1,4 do
			local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..id) end)
			if ok and objs and objs[1] then
				local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
				if t then
					t.Parent = nil
					stripScripts(t)
					template = t
					break
				end
			end
			task.wait(0.5*attempt)
		end
		cache[id] = template
		loading[id] = nil
	end)
end

local function loadRealTool(id, fallbackSize, fallbackColor)
	if cache[id] then return cache[id]:Clone() end
	-- try once more quickly
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://"..id) end)
	if ok and objs and objs[1] then
		local t = objs[1]:IsA("Tool") and objs[1] or objs[1]:FindFirstChildWhichIsA("Tool", true)
		if t then
			t.Parent = nil
			stripScripts(t)
			cache[id] = t
			return t:Clone()
		end
	end
	-- fallback visual
	local tool = Instance.new("Tool")
	tool.RequiresHandle = true
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = fallbackSize or Vector3.new(1,1,2)
	h.Color = fallbackColor or Color3.fromRGB(100,100,100)
	h.CanCollide = false
	h.Parent = tool
	return tool
end

-- preload important models
task.spawn(function()
	preload(11719016)   -- Blow Dryer
	preload(236438668)  -- Sea Bow
	preload(16688968)   -- Gravity Coil
	preload(99119158)   -- Speed Coil
	preload(36913601)   -- Broom
	preload(402305186)  -- Gold Carpet
end)

-- ==========================================
-- BLOCK / JAIL / FLING / ESP (kept light)
-- ==========================================
local blockEnabled = false
local blockedPlayers, playerBlockVisuals = {}, {}
local jailedPlayers, playerJailVisuals, jailSavedCFrames = {}, {}, {}
local espEnabled, highlights = false, {}

local function getPlayerRole(plr)
	local char = plr.Character
	if not char then return "Innocent" end
	if char:FindFirstChild("Knife") or (plr.Backpack and plr.Backpack:FindFirstChild("Knife")) then return "Murderer" end
	if char:FindFirstChild("Gun") or (plr.Backpack and plr.Backpack:FindFirstChild("Gun")) then return "Sheriff" end
	return "Innocent"
end

local function setCharacterLock(locked)
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hrp then
		hrp.Anchored = locked
		if not locked then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end
	if hum then
		hum.WalkSpeed = locked and 0 or 16
		hum.JumpPower = locked and 0 or 50
	end
end

local function toggleBlock()
	blockEnabled = not blockEnabled
	setCharacterLock(blockEnabled)
end

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.35)
	setCharacterLock(blockEnabled)
end)

local function removeESP(plr)
	if highlights[plr] then highlights[plr]:Destroy(); highlights[plr]=nil end
end

local function updateESPForPlayer(plr)
	if plr == LocalPlayer then return end
	if not espEnabled then removeESP(plr) return end
	local char = plr.Character
	if char then
		local hl = highlights[plr]
		if not hl or not hl.Parent then
			hl = Instance.new("Highlight")
			hl.Adornee = char
			hl.Parent = char
			highlights[plr] = hl
		end
		local role = getPlayerRole(plr)
		if role == "Murderer" then
			hl.FillColor = Color3.fromRGB(255,0,0)
		elseif role == "Sheriff" then
			hl.FillColor = Color3.fromRGB(0,0,255)
		else
			hl.FillColor = Color3.fromRGB(0,255,0)
		end
		hl.OutlineColor = Color3.fromRGB(255,255,255)
	else
		removeESP(plr)
	end
end

local function toggleESP()
	espEnabled = not espEnabled
	for _,p in ipairs(Players:GetPlayers()) do
		if espEnabled then updateESPForPlayer(p) else removeESP(p) end
	end
end

Players.PlayerRemoving:Connect(removeESP)
RunService.Heartbeat:Connect(function()
	if espEnabled then
		for _,p in ipairs(Players:GetPlayers()) do updateESPForPlayer(p) end
	end
end)

-- simple jail / block / fling (kept functional)
local function findRoleOrPlayerTarget(query, allowSelf)
	if not query or query=="" then return nil end
	local q = string.lower(string.match(query,"^%s*(.-)%s*$") or "")
	if q=="" then return nil end
	if allowSelf and (q=="me" or q=="self") then return LocalPlayer end
	if q=="murder" or q=="murderer" then
		for _,p in ipairs(Players:GetPlayers()) do
			if getPlayerRole(p)=="Murderer" and (allowSelf or p~=LocalPlayer) then return p end
		end
		return nil
	end
	if q=="sherif" or q=="sheriff" then
		for _,p in ipairs(Players:GetPlayers()) do
			if getPlayerRole(p)=="Sheriff" and (allowSelf or p~=LocalPlayer) then return p end
		end
		return nil
	end
	for _,p in ipairs(Players:GetPlayers()) do
		if allowSelf or p~=LocalPlayer then
			if string.find(string.lower(p.Name),q,1,true) or string.find(string.lower(p.DisplayName),q,1,true) then
				return p
			end
		end
	end
	return nil
end

local function setTargetJailed(plr, should)
	if not plr then return end
	if should then
		jailedPlayers[plr] = true
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			jailSavedCFrames[plr] = hrp.CFrame
			pcall(function()
				hrp.Anchored = true
				hrp.AssemblyLinearVelocity = Vector3.zero
			end)
		end
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.WalkSpeed=0; hum.JumpPower=0 end) end
	else
		jailedPlayers[plr] = nil
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			pcall(function()
				hrp.Anchored = false
				hrp.CFrame = jailSavedCFrames[plr] or hrp.CFrame
			end)
		end
		jailSavedCFrames[plr] = nil
		local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then pcall(function() hum.WalkSpeed=16; hum.JumpPower=50 end) end
	end
end

local function flingTargetPlayer(target)
	if not target or target==LocalPlayer then return end
	local tHrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not tHrp or not myHrp then return end
	local oldCF = myHrp.CFrame
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(1e9,1e9,1e9)
	bv.Velocity = Vector3.new(120,420,120)
	bv.Parent = myHrp
	local start = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if os.clock()-start > 0.7 or not tHrp.Parent or not myHrp.Parent then
			if conn then conn:Disconnect() end
			return
		end
		pcall(function()
			myHrp.CFrame = tHrp.CFrame * CFrame.Angles(math.rad(os.clock()*900),0,0)
			tHrp.AssemblyLinearVelocity = Vector3.new(90,380,90)
		end)
	end)
	task.delay(0.72, function()
		if conn then conn:Disconnect() end
		if bv then bv:Destroy() end
		if myHrp and myHrp.Parent then
			pcall(function()
				myHrp.AssemblyLinearVelocity = Vector3.zero
				myHrp.CFrame = oldCF
			end)
		end
	end)
end

local function sendToRobloxChat(text)
	if type(text)~="string" or text=="" then return end
	local toSend = string.match(text,"^/") and text or ("/"..text)
	pcall(function()
		if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local chans = TextChatService:FindFirstChild("TextChannels")
			local gen = chans and (chans:FindFirstChild("RBXGeneral") or chans:FindFirstChild("General"))
			if gen and gen:IsA("TextChannel") then gen:SendAsync(toSend) return end
		end
		pcall(function() Players:Chat(toSend) end)
	end)
end

-- map selector
local MapList = {
	"Biolab","Icecastle","Log Cabin","Workshop","Workplace","Factory",
	"Milbase","Station","House2","Hotel","BeachResort","Yacht",
	"Barn","Farmhouse","ChristmasItaly","Manor","Mineshaft",
	"VampireCastle","Spaceship","SkiVillage_6v6","SkiVillage_RegularMode","Pier",
}
local mapSelectorGui, statusLabel

local function hideMapSelector()
	if mapSelectorGui then mapSelectorGui.Enabled = false end
end

local function showMapSelector()
	if not mapSelectorGui then
		mapSelectorGui = Instance.new("ScreenGui")
		mapSelectorGui.Name = "VestaMapSelector"
		mapSelectorGui.ResetOnSpawn = false
		mapSelectorGui.DisplayOrder = 50
		mapSelectorGui.Parent = playerGui

		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(0,260,0,380)
		frame.Position = UDim2.new(0.5,-130,0.5,-190)
		frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
		frame.BorderSizePixel = 0
		frame.Active = true
		frame.Draggable = true
		frame.Parent = mapSelectorGui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0,10)

		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1,-40,0,28)
		title.Position = UDim2.new(0,12,0,8)
		title.BackgroundTransparency = 1
		title.Text = "SELECT MAP"
		title.TextColor3 = Color3.fromRGB(245,245,248)
		title.Font = Enum.Font.GothamBlack
		title.TextSize = 14
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = frame

		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0,26,0,22)
		closeBtn.Position = UDim2.new(1,-34,0,8)
		closeBtn.BackgroundColor3 = Color3.fromRGB(30,30,30)
		closeBtn.Text = "X"
		closeBtn.TextColor3 = Color3.fromRGB(255,255,255)
		closeBtn.Font = Enum.Font.GothamBold
		closeBtn.TextSize = 13
		closeBtn.Parent = frame
		Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)
		closeBtn.MouseButton1Click:Connect(hideMapSelector)

		local scroll = Instance.new("ScrollingFrame")
		scroll.Size = UDim2.new(1,-16,1,-48)
		scroll.Position = UDim2.new(0,8,0,40)
		scroll.BackgroundColor3 = Color3.fromRGB(12,12,12)
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.CanvasSize = UDim2.new(0,0,0,0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.Parent = frame
		Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,7)
		local layout = Instance.new("UIListLayout", scroll)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0,4)

		for i, mapName in ipairs(MapList) do
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1,-4,0,30)
			btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
			btn.Text = mapName
			btn.TextColor3 = Color3.fromRGB(235,235,240)
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 12
			btn.LayoutOrder = i
			btn.Parent = scroll
			Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
			btn.MouseButton1Click:Connect(function()
				sendToRobloxChat("/map " .. mapName)
				hideMapSelector()
				if statusLabel then
					statusLabel.Text = string.upper(mapName) .. " SET!"
					task.delay(2, function()
						if statusLabel and statusLabel.Text == string.upper(mapName).." SET!" then
							statusLabel.Text = tr("readyStatus")
						end
					end)
				end
			end)
		end
	end
	mapSelectorGui.Enabled = true
end

local function handleChatOrCommandString(msg)
	if type(msg)~="string" then return false end
	local lower = string.lower(string.match(msg,"^%s*(.-)%s*$") or "")
	if lower=="" then return false end
	if lower=="map" or lower=="/map" then showMapSelector() return "map" end
	local flingT = string.match(lower,"^/?fling%s+(.+)$")
	if flingT then
		local t = findRoleOrPlayerTarget(flingT, false)
		if t then flingTargetPlayer(t) end
		return "fling"
	end
	local jailT = string.match(lower,"^/?jail%s+(.+)$")
	if jailT then
		local t = findRoleOrPlayerTarget(jailT, true)
		if t then setTargetJailed(t, true) end
		return "jail"
	end
	if lower=="/jail" or lower=="jail" then setTargetJailed(LocalPlayer, true) return "jail" end
	local unjailT = string.match(lower,"^/?unjail%s+(.+)$")
	if unjailT then
		local t = findRoleOrPlayerTarget(unjailT, true)
		if t then setTargetJailed(t, false) end
		return "jail"
	end
	if lower=="/unjail" or lower=="unjail" then
		for p in pairs(jailedPlayers) do setTargetJailed(p, false) end
		return "jail"
	end
	return false
end

LocalPlayer.Chatted:Connect(handleChatOrCommandString)

-- ==========================================
-- REAL GEARS (from VestaGears)
-- ==========================================

-- BLOW DRYER
local function giveHairDryer()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Blow Dryer") then backpack["Blow Dryer"]:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Blow Dryer") then
		LocalPlayer.Character["Blow Dryer"]:Destroy()
	end

	local tool = loadRealTool(11719016, Vector3.new(0.8,0.8,1.8), Color3.fromRGB(220,60,120))
	tool.Name = "Blow Dryer"
	tool.CanBeDropped = false
	local handle = getHandle(tool)
	if handle then
		addSound(handle, "Dryer", "rbxassetid://11717967", 0.7)
	end
	tool.Activated:Connect(function()
		if handle and handle:FindFirstChild("Dryer") then handle.Dryer:Play() end
		if handle then
			local att = handle:FindFirstChild("DryerAtt") or Instance.new("Attachment")
			att.Name = "DryerAtt"
			att.Parent = handle
			if not handle:FindFirstChild("DryerAir") then
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
				air.Parent = handle
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
				sp.Parent = handle
			end
			handle.DryerAir:Emit(45)
			handle.DryerSparkle:Emit(35)
		end
		local root = getChar():FindFirstChild("HumanoidRootPart")
		if root then
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(0,0,40000)
			bv.Velocity = root.CFrame.LookVector * 55
			bv.Parent = root
			Debris:AddItem(bv, 0.35)
		end
	end)
	tool.Parent = backpack
end

-- SEA BOW
local function giveCrossbowOfTheSea()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Sea Bow") then backpack["Sea Bow"]:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Sea Bow") then
		LocalPlayer.Character["Sea Bow"]:Destroy()
	end

	local tool = loadRealTool(236438668, Vector3.new(0.5,1.3,3), Color3.fromRGB(0,200,255))
	tool.Name = "Sea Bow"
	tool.CanBeDropped = false
	local handle = getHandle(tool)
	if handle then
		addSound(handle, "Shot", "rbxassetid://99204505", 0.7)
	end
	tool.Activated:Connect(function()
		local char = getChar()
		if handle and handle:FindFirstChild("Shot") then
			handle.Shot.Pitch = math.random(90,110)/100
			handle.Shot:Play()
		end
		local arrow = Instance.new("Part")
		arrow.Name = "SeaArrow"
		arrow.Size = Vector3.new(0.3,0.3,2.2)
		arrow.Color = Color3.fromRGB(0,200,255)
		arrow.Material = Enum.Material.Neon
		arrow.CanCollide = false
		addSound(arrow, "Hit", "rbxassetid://58274204", 0.8)
		arrow.CFrame = CFrame.new(handle and handle.Position or char.HumanoidRootPart.Position, aimPoint(handle and handle.Position or char.HumanoidRootPart.Position, char))
		arrow.AssemblyLinearVelocity = arrow.CFrame.LookVector * 120
		arrow.Parent = workspace
		local conn
		conn = arrow.Touched:Connect(function(part)
			if part:IsDescendantOf(char) then return end
			local scale = 8 + 4*math.random(1,3)
			pcall(function()
				workspace.Terrain:FillBall(arrow.Position, scale, Enum.Material.Water)
				task.delay(7, function()
					pcall(function() workspace.Terrain:FillBall(arrow.Position, scale, Enum.Material.Air) end)
				end)
			end)
			if arrow:FindFirstChild("Hit") then arrow.Hit:Play() end
			arrow.Anchored = true
			arrow.Transparency = 1
			conn:Disconnect()
		end)
		Debris:AddItem(arrow, 8)
	end)
	tool.Parent = backpack
end

-- SPEED COIL (real)
local function giveSpeedCoil()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Speed Coil") then backpack["Speed Coil"]:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Speed Coil") then
		LocalPlayer.Character["Speed Coil"]:Destroy()
	end

	local tool = loadRealTool(99119158, Vector3.new(1.4,1.6,1.6), Color3.fromRGB(220,30,30))
	tool.Name = "Speed Coil"
	tool.CanBeDropped = false
	tool.TextureId = "rbxassetid://99170415"

	local old
	tool.Equipped:Connect(function()
		local hum = getChar():FindFirstChildOfClass("Humanoid")
		if hum then
			old = hum.WalkSpeed
			hum.WalkSpeed = 40
		end
	end)
	tool.Unequipped:Connect(function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and old then hum.WalkSpeed = old end
	end)
	tool.Parent = backpack
end

-- GRAVITY COIL (real)
local function giveGravityCoil()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Gravity Coil") then backpack["Gravity Coil"]:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gravity Coil") then
		LocalPlayer.Character["Gravity Coil"]:Destroy()
	end

	local tool = loadRealTool(16688968, Vector3.new(1.4,1.6,1.6), Color3.fromRGB(60,120,255))
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
			if not hrp.Parent then
				if loop then loop:Disconnect() end
				return
			end
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
	tool.Parent = backpack
end

-- BROOM (real fly from VestaGears carpet system)
local function giveBroom()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Broom") then backpack.Broom:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Broom") then
		LocalPlayer.Character.Broom:Destroy()
	end

	local tool = loadRealTool(36913601, Vector3.new(0.4,0.4,5), Color3.fromRGB(110,70,35))
	tool.Name = "Broom"
	tool.CanBeDropped = false
	tool.TextureId = "rbxthumb://type=Asset&id=36913601&w=420&h=420"

	local handle = getHandle(tool)
	local bv, bg, loop

	local function stop()
		if loop then loop:Disconnect() loop=nil end
		if bv then bv:Destroy() bv=nil end
		if bg then bg:Destroy() bg=nil end
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
		bv.Velocity = Vector3.zero
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6,1e6,1e6)
		bg.P = 9000
		bg.D = 600
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp
		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent then return stop() end
			local cam = workspace.CurrentCamera.CFrame
			local mv = Vector3.zero
			if hum.MoveDirection.Magnitude > 0.05 then
				local localMove = cam:VectorToObjectSpace(hum.MoveDirection)
				mv = Vector3.new(localMove.X, 0, localMove.Z)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				mv -= Vector3.new(0,1,0)
			end
			local dir = cam.RightVector * mv.X + cam.LookVector * -mv.Z + Vector3.new(0,1,0)*mv.Y
			bv.Velocity = (dir.Magnitude > 0.05) and (dir.Unit * 80) or Vector3.zero
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
			end
		end)
	end

	tool.Equipped:Connect(start)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
	tool.Parent = backpack
end

-- GOLD CARPET (sit + gold trail/sparkle effects)
local function giveGoldenCarpet()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("GoldenCarpet") then backpack.GoldenCarpet:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("GoldenCarpet") then
		LocalPlayer.Character.GoldenCarpet:Destroy()
	end
	local tool = loadRealTool(402305186, Vector3.new(4,0.2,6), Color3.fromRGB(255,200,40))
	tool.Name = "GoldenCarpet"
	tool.CanBeDropped = false
	tool.TextureId = "rbxassetid://1014109561"
	-- hide the held model; we build our own carpet to sit on
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then d.Transparency = 1 end
	end

	local GOLD = Color3.fromRGB(255,200,40)
	local carpet, bv, bg, loop, weld

	local function stop()
		if loop then loop:Disconnect() loop=nil end
		if bv then bv:Destroy() bv=nil end
		if bg then bg:Destroy() bg=nil end
		if weld then weld:Destroy() weld=nil end
		if carpet then carpet:Destroy() carpet=nil end
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Sit = false end
	end

	local function start()
		stop()
		local char = getChar()
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end

		carpet = Instance.new("Part")
		carpet.Name = "VestaGoldCarpet"
		carpet.Size = Vector3.new(5, 0.3, 6.5)
		carpet.Color = GOLD
		carpet.Material = Enum.Material.Neon
		carpet.CanCollide = false
		carpet.Massless = true
		carpet.CFrame = hrp.CFrame * CFrame.new(0,-2.3,0)
		carpet.Parent = char

		weld = Instance.new("Weld")
		weld.Part0 = hrp
		weld.Part1 = carpet
		weld.C0 = CFrame.new(0,-2.3,0)
		weld.Parent = carpet

		-- trail from the rear corners
		local a0 = Instance.new("Attachment", carpet)
		a0.Position = Vector3.new(-2.4, 0, 3.2)
		local a1 = Instance.new("Attachment", carpet)
		a1.Position = Vector3.new(2.4, 0, 3.2)
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 1.4
		trail.LightEmission = 1
		trail.FaceCamera = true
		trail.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255,240,150)),
			ColorSequenceKeypoint.new(0.5, GOLD),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200,120,0)),
		}
		trail.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}
		trail.Parent = carpet

		-- center trail
		local c0 = Instance.new("Attachment", carpet); c0.Position = Vector3.new(0,0.2,3.2)
		local c1 = Instance.new("Attachment", carpet); c1.Position = Vector3.new(0,-0.2,3.2)
		local trail2 = trail:Clone()
		trail2.Attachment0 = c0
		trail2.Attachment1 = c1
		trail2.Lifetime = 2
		trail2.WidthScale = NumberSequence.new(3, 0)
		trail2.Parent = carpet

		-- sparkles
		local sp = Instance.new("ParticleEmitter")
		sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sp.Color = ColorSequence.new(Color3.fromRGB(255,235,120), GOLD)
		sp.LightEmission = 1
		sp.Rate = 70
		sp.Lifetime = NumberRange.new(0.8, 1.6)
		sp.Speed = NumberRange.new(2, 6)
		sp.SpreadAngle = Vector2.new(180,180)
		sp.Size = NumberSequence.new{NumberSequenceKeypoint.new(0,0.7), NumberSequenceKeypoint.new(1,0)}
		sp.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1)}
		sp.Rotation = NumberRange.new(0,360)
		sp.RotSpeed = NumberRange.new(-120,120)
		sp.Parent = carpet

		local glow = Instance.new("ParticleEmitter")
		glow.Texture = "rbxasset://textures/particles/smoke_main.dds"
		glow.Color = ColorSequence.new(GOLD)
		glow.LightEmission = 1
		glow.Rate = 25
		glow.Lifetime = NumberRange.new(0.6, 1)
		glow.Speed = NumberRange.new(0, 2)
		glow.Size = NumberSequence.new{NumberSequenceKeypoint.new(0,2.5), NumberSequenceKeypoint.new(1,0)}
		glow.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0,0.6), NumberSequenceKeypoint.new(1,1)}
		glow.Parent = carpet

		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 14
		light.Brightness = 2
		light.Parent = carpet

		-- flight
		bv = Instance.new("BodyVelocity")
		bv.MaxForce = Vector3.new(1e6,1e6,1e6)
		bv.Velocity = Vector3.zero
		bv.Parent = hrp
		bg = Instance.new("BodyGyro")
		bg.MaxTorque = Vector3.new(1e6,1e6,1e6)
		bg.P = 9000
		bg.D = 600
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp

		loop = RunService.Heartbeat:Connect(function()
			if not hrp.Parent or not carpet then return stop() end
			hum.Sit = true -- stay seated on the carpet
			local cam = workspace.CurrentCamera.CFrame
			local mv = Vector3.zero
			if hum.MoveDirection.Magnitude > 0.05 then
				local lm = cam:VectorToObjectSpace(hum.MoveDirection)
				mv = Vector3.new(lm.X, 0, lm.Z)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				mv -= Vector3.new(0,1,0)
			end
			local dir = cam.RightVector * mv.X + cam.LookVector * -mv.Z + Vector3.new(0,1,0)*mv.Y
			bv.Velocity = (dir.Magnitude > 0.05) and (dir.Unit * 80) or Vector3.zero
			local flat = Vector3.new(cam.LookVector.X, 0, cam.LookVector.Z)
			if flat.Magnitude > 0.01 then
				bg.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
			end
		end)
	end

	tool.Equipped:Connect(start)
	tool.Unequipped:Connect(stop)
	tool.Destroying:Connect(stop)
	tool.Parent = backpack
end

local function runRainbowCarpetScript()
	pcall(function()
		loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Open-Source-227632"))()
	end)
end

-- ==========================================
-- BOMB – click to drop a bomb under your feet, blast launches you up.
-- Infinite double jump, zero cooldown.
-- ==========================================
local function giveBomb()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack",5)
	if not backpack then return end
	if backpack:FindFirstChild("Bomb") then backpack.Bomb:Destroy() end
	if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb") then
		LocalPlayer.Character.Bomb:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = "Bomb"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Click to drop a bomb under your feet"

	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Shape = Enum.PartType.Ball
	h.Size = Vector3.new(1.3,1.3,1.3)
	h.Color = Color3.fromRGB(25,25,28)
	h.Material = Enum.Material.Metal
	h.CanCollide = false
	h.Parent = tool
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.15,0.5,0.15)
	fuse.Color = Color3.fromRGB(255,120,0)
	fuse.Material = Enum.Material.Neon
	fuse.CanCollide = false
	fuse.Massless = true
	fuse.CFrame = h.CFrame * CFrame.new(0,0.8,0)
	fuse.Parent = tool
	local fw = Instance.new("WeldConstraint")
	fw.Part0 = h; fw.Part1 = fuse; fw.Parent = h

	local function dropBomb()
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end
		local feet = hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y/2, 0)

		local b = Instance.new("Part")
		b.Name = "VestaBomb"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(1.5,1.5,1.5)
		b.Color = Color3.fromRGB(25,25,28)
		b.Material = Enum.Material.Metal
		b.Anchored = true
		b.CanCollide = false
		b.Position = feet
		b.Parent = workspace
		local pl = Instance.new("PointLight", b)
		pl.Color = Color3.fromRGB(255,120,0)
		pl.Range = 8

		task.delay(0.12, function()
			local pos = b.Position
			b:Destroy()
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
	end

	-- no debounce / no cooldown: every click drops a bomb
	tool.Activated:Connect(dropBomb)

	-- infinite double jump while you own the bomb
	local jumpConn = UserInputService.JumpRequest:Connect(function()
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end)
	tool.Destroying:Connect(function() jumpConn:Disconnect() end)

	tool.Parent = backpack
end

local function removeAllGears()
	local names = {"GoldenCarpet","Blow Dryer","Sea Bow","Broom","Speed Coil","Gravity Coil","Bomb"}
	for _, container in ipairs({LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character}) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") then
					for _, n in ipairs(names) do
						if item.Name == n then item:Destroy() break end
					end
				end
			end
		end
	end
end

local function removeThisGear()
	local char = LocalPlayer.Character
	if not char then return false end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			local name = child.Name
			child:Destroy()
			return true, name
		end
	end
	return false
end

-- ==========================================
-- FLOATING V (no planets)
-- ==========================================
local floatGui = Instance.new("ScreenGui")
floatGui.Name = "VestaFloatButton"
floatGui.ResetOnSpawn = false
floatGui.DisplayOrder = 100
floatGui.Parent = playerGui

local floatBtn = Instance.new("TextButton")
floatBtn.Name = "VButton"
floatBtn.Size = UDim2.new(0, 120, 0, 46)
floatBtn.Position = UDim2.new(1, -140, 0.72, 0)
floatBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
floatBtn.BorderSizePixel = 0
floatBtn.Text = "Vesta"
floatBtn.TextColor3 = Color3.fromRGB(0,0,0)
floatBtn.Font = Enum.Font.FredokaOne
floatBtn.TextSize = 26
floatBtn.AutoButtonColor = false
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Parent = floatGui
Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1,0)
local fStroke = Instance.new("UIStroke", floatBtn)
fStroke.Thickness = 3.5
fStroke.Color = Color3.fromRGB(255,255,255)
fStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local fGrad = Instance.new("UIGradient", fStroke)
fGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(0.8,  Color3.fromRGB(110,110,110)),
	ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,0,0)),
}
-- black trail circling the pill
RunService.RenderStepped:Connect(function()
	fGrad.Rotation = (os.clock() * 220) % 360
end)

-- ==========================================
-- RADIAL PANEL
-- ==========================================
local radialGui = Instance.new("ScreenGui")
radialGui.Name = "VestaRadialPanel"
radialGui.ResetOnSpawn = false
radialGui.DisplayOrder = 99
radialGui.Enabled = false
radialGui.Parent = playerGui

local radialFrame = Instance.new("Frame")
radialFrame.Size = UDim2.new(0, 360, 0, 360)
radialFrame.Position = UDim2.new(0.5, -180, 0.5, -180)
radialFrame.BackgroundTransparency = 1
radialFrame.Parent = radialGui

local center = Instance.new("Frame")
center.Size = UDim2.new(0, 100, 0, 100)
center.Position = UDim2.new(0.5, -50, 0.5, -50)
center.BackgroundColor3 = Color3.fromRGB(0,0,0)
center.BorderSizePixel = 0
center.Parent = radialFrame
Instance.new("UICorner", center).CornerRadius = UDim.new(1,0)
local cStroke = Instance.new("UIStroke", center)
cStroke.Color = Color3.fromRGB(70,70,78)
cStroke.Thickness = 2

local centerTitle = Instance.new("TextLabel")
centerTitle.Size = UDim2.new(1, -8, 0, 32)
centerTitle.Position = UDim2.new(0, 4, 0, 16)
centerTitle.BackgroundTransparency = 1
centerTitle.Text = "VESTA\nADMIN PANEL"
centerTitle.TextColor3 = Color3.fromRGB(255,255,255)
centerTitle.Font = Enum.Font.GothamBlack
centerTitle.TextSize = 12
centerTitle.TextWrapped = true
centerTitle.Parent = center

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(1, -8, 0, 16)
fpsLabel.Position = UDim2.new(0, 4, 0, 56)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS: -- | PING: --"
fpsLabel.TextColor3 = Color3.fromRGB(180,180,190)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 9
fpsLabel.Parent = center

local lastFps, frames = 0, 0
RunService.RenderStepped:Connect(function()
	frames += 1
	local now = os.clock()
	if now - lastFps >= 0.6 then
		local fps = math.floor(frames / (now - lastFps))
		frames = 0
		lastFps = now
		local ping = 0
		pcall(function()
			ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		fpsLabel.Text = string.format("FPS: %d | PING: %d MS", fps, ping)
	end
end)

statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, 300, 0, 20)
statusLabel.Position = UDim2.new(0.5, -150, 1, 18)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = tr("readyStatus")
statusLabel.TextColor3 = Color3.fromRGB(200,200,210)
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 12
statusLabel.Parent = radialFrame

local function flashStatus(msg)
	statusLabel.Text = msg
	task.delay(2, function()
		if statusLabel.Text == msg then
			statusLabel.Text = tr("readyStatus")
		end
	end)
end

local buttons = {
	{name="ESP",         action=function() toggleESP() flashStatus(espEnabled and "ESP: ON" or "ESP: OFF") end},
	{name="SHERIFF",     action=function() sendToRobloxChat("/sheriff") flashStatus("SHERIFF GIVEN") end},
	{name="MURDERER",    action=function() sendToRobloxChat("/murderer") flashStatus("MURDERER GIVEN") end},
	{name="BOMB",        action=function() giveBomb() flashStatus("BOMB") end},
	{name="MAP",         action=function() showMapSelector() end},
	{name="GOLD CARPET", action=function() giveGoldenCarpet() flashStatus("GOLDEN CARPET") end},
	{name="RAINBOW",     action=function() runRainbowCarpetScript() flashStatus("RAINBOW CARPET") end},
	{name="BLOW",        action=function() giveHairDryer() flashStatus("BLOW DRYER") end},
	{name="SEA BOW",     action=function() giveCrossbowOfTheSea() flashStatus("SEA BOW") end},
	{name="BROOM",       action=function() giveBroom() flashStatus("BROOM") end},
	{name="SPEED COIL",  action=function() giveSpeedCoil() flashStatus("SPEED COIL") end},
	{name="GRAVITY COIL",action=function() giveGravityCoil() flashStatus("GRAVITY COIL") end},
	{name="REMOVE ALL",  action=function() removeAllGears() flashStatus("ALL GEARS REMOVED") end},
	{name="REMOVE THIS", action=function()
		local ok, name = removeThisGear()
		if ok then flashStatus((name or "TOOL") .. " REMOVED")
		else flashStatus("NOTHING EQUIPPED") end
	end},
}

local radius = 135
local step = (2 * math.pi) / #buttons

for i, data in ipairs(buttons) do
	local ang = (i-1)*step - math.pi/2
	local x = math.cos(ang) * radius
	local y = math.sin(ang) * radius

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 68, 0, 68)
	btn.Position = UDim2.new(0.5, x-34, 0.5, y-34)
	btn.BackgroundColor3 = Color3.fromRGB(18,18,22)
	btn.BorderSizePixel = 0
	btn.Text = data.name
	btn.TextColor3 = Color3.fromRGB(240,240,245)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.TextWrapped = true
	btn.AutoButtonColor = false
	btn.Parent = radialFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(1,0)
	local bs = Instance.new("UIStroke", btn)
	bs.Color = Color3.fromRGB(60,60,70)
	bs.Thickness = 1.5

	if data.name == "REMOVE ALL" or data.name == "REMOVE THIS" then
		btn.BackgroundColor3 = Color3.fromRGB(140,35,45)
		bs.Color = Color3.fromRGB(180,50,60)
	end

	btn.MouseEnter:Connect(function()
		if data.name == "REMOVE ALL" or data.name == "REMOVE THIS" then
			TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(180,50,60)}):Play()
		else
			TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(40,40,50)}):Play()
			bs.Color = Color3.fromRGB(120,120,140)
		end
	end)
	btn.MouseLeave:Connect(function()
		if data.name == "REMOVE ALL" or data.name == "REMOVE THIS" then
			TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(140,35,45)}):Play()
		else
			TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3=Color3.fromRGB(18,18,22)}):Play()
			bs.Color = Color3.fromRGB(60,60,70)
		end
	end)
	btn.MouseButton1Click:Connect(data.action)
end

local open = false
floatBtn.MouseButton1Click:Connect(function()
	open = not open
	radialGui.Enabled = open
	if open then statusLabel.Text = tr("readyStatus") end
end)

print("[VESTA] Radial GUI ready")
