-- PowerupPanel v3 — LocalScript
-- Jetpack com slider drag, Super Tênis com pulo alto real

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Workspace        = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

if not RunService:IsClient() or not LocalPlayer then
	warn("[PowerupPanel] Rode como LocalScript no cliente.")
	return
end

if not game:IsLoaded() then game.Loaded:Wait() end

-- ─────────────────────────────────────────────
-- CONFIGURAÇÃO
-- ─────────────────────────────────────────────
local CFG = {
	MagnetRadius             = 26,
	MagnetPullSpeed          = 70,
	CoinPickupRadius         = 4.5,
	Coin2xTouchCooldown      = 0.18,
	Coin2xTouchRepeats       = 3,
	Coin2xRemoteMemory       = 24,
}

-- ─────────────────────────────────────────────
-- ESTADO
-- ─────────────────────────────────────────────
local S = {
	magnetEnabled    = false,
	coin2xEnabled    = false,
	panelDragging    = false,
	panelDragStart   = nil,
	panelStartPos    = nil,
	coin2xTouchedAt  = {},
	coin2xRemoteCalls = {},
	coin2xRemoteHooked = false,
	coin2xReplayingRemote = false,
	connections      = {},
}

local ui = {}

-- ─────────────────────────────────────────────
-- UTILS
-- ─────────────────────────────────────────────
local function conn(c) table.insert(S.connections, c) return c end
local function disconnAll()
	for _, c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
	S.connections = {}
end
local function clamp(v,a,b) return math.max(a, math.min(b, v)) end

local function getChar()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end
local function getRootPart()
	return getChar():FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
	return getChar():FindFirstChildOfClass("Humanoid")
end

local function findCoinAncestor(obj)
	local current = obj
	while current do
		if current:IsA("BasePart") and (current:GetAttribute("IsCoin") == true or string.find(string.lower(current.Name), "coin", 1, true)) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function cloneArgs(args)
	local copied = table.create(#args)
	for index, value in ipairs(args) do
		copied[index] = value
	end
	return copied
end

local function isCoinRelatedRemoteCall(remote, args)
	if not remote then return false end
	local remoteName = string.lower(remote.Name)
	if string.find(remoteName, "coin", 1, true)
		or string.find(remoteName, "cash", 1, true)
		or string.find(remoteName, "pickup", 1, true)
		or string.find(remoteName, "collect", 1, true)
	then
		return true
	end

	for _, value in ipairs(args) do
		if typeof(value) == "Instance" then
			if findCoinAncestor(value) then
				return true
			end
		elseif typeof(value) == "string" then
			local lowered = string.lower(value)
			if string.find(lowered, "coin", 1, true)
				or string.find(lowered, "cash", 1, true)
				or string.find(lowered, "pickup", 1, true)
				or string.find(lowered, "collect", 1, true)
			then
				return true
			end
		end
	end

	return false
end

local function rememberCoinRemoteCall(remote, methodName, args)
	if not S.coin2xEnabled or S.coin2xReplayingRemote then return end
	if not isCoinRelatedRemoteCall(remote, args) then return end

	table.insert(S.coin2xRemoteCalls, 1, {
		remote = remote,
		methodName = methodName,
		args = cloneArgs(args),
		time = os.clock(),
	})

	while #S.coin2xRemoteCalls > CFG.Coin2xRemoteMemory do
		table.remove(S.coin2xRemoteCalls)
	end
end

local function ensureCoin2xRemoteHook()
	if S.coin2xRemoteHooked then return end
	if typeof(hookmetamethod) ~= "function"
		or typeof(getnamecallmethod) ~= "function"
		or typeof(checkcaller) ~= "function"
	then
		return
	end

	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local args = {...}
		local methodName = getnamecallmethod()

		if not checkcaller()
			and S.coin2xEnabled
			and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))
			and (methodName == "FireServer" or methodName == "InvokeServer")
		then
			rememberCoinRemoteCall(self, methodName, args)
		end

		return oldNamecall(self, ...)
	end)

	S.coin2xRemoteHooked = true
end

local function getTouchParts()
	local char = getChar()
	if not char then return {} end

	local parts = {}
	local preferred = {
		"HumanoidRootPart",
		"Head",
		"UpperTorso",
		"LowerTorso",
		"LeftFoot",
		"RightFoot",
		"Left Leg",
		"Right Leg",
	}

	for _, name in ipairs(preferred) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(parts, part)
		end
	end

	if #parts == 0 then
		local root = getRootPart()
		if root then
			table.insert(parts, root)
		end
	end

	return parts
end

-- ─────────────────────────────────────────────
-- TWEENS
-- ─────────────────────────────────────────────
local function tw(obj, props, t)
	return TweenService:Create(obj,
		TweenInfo.new(t or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		props)
end

-- ─────────────────────────────────────────────
-- CORES
-- ─────────────────────────────────────────────
local C = {
	bg0     = Color3.fromRGB(7,  9,  15),
	bg1     = Color3.fromRGB(13, 16, 25),
	bg2     = Color3.fromRGB(19, 23, 35),
	bg3     = Color3.fromRGB(27, 32, 50),
	border  = Color3.fromRGB(42, 50, 76),
	borderH = Color3.fromRGB(68, 82,124),
	t0      = Color3.fromRGB(238,242,255),
	t1      = Color3.fromRGB(155,165,198),
	t2      = Color3.fromRGB(90, 100,138),
	a1      = Color3.fromRGB(72, 138,255),
	a2      = Color3.fromRGB(255,162, 48),
	a3      = Color3.fromRGB(176, 82,255),
	ok      = Color3.fromRGB(72, 228,152),
}

-- ─────────────────────────────────────────────
-- CONSTRUTORES UI
-- ─────────────────────────────────────────────
local function mkFrame(p)
	local f = Instance.new("Frame")
	for k,v in pairs(p) do f[k]=v end
	return f
end
local function mkLabel(p)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	for k,v in pairs(p) do l[k]=v end
	return l
end
local function mkButton(p)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Font = Enum.Font.GothamBold
	for k,v in pairs(p) do b[k]=v end
	return b
end
local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = parent
	return c
end
local function stroke(parent, color, thick)
	local s = Instance.new("UIStroke")
	s.Color     = color or C.border
	s.Thickness = thick or 1
	s.Parent    = parent
	return s
end

-- ─────────────────────────────────────────────
-- SCREEN GUI
-- ─────────────────────────────────────────────
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
do local old = playerGui:FindFirstChild("PowerupPanel") if old then old:Destroy() end end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "PowerupPanel"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = playerGui

local glow = mkFrame({
	Name="Glow", AnchorPoint=Vector2.new(0.5,0.5),
	Size=UDim2.new(0,430,0,560), Position=UDim2.new(0.5,0,0.5,10),
	BackgroundColor3=Color3.fromRGB(30,60,200), BackgroundTransparency=0.86,
	BorderSizePixel=0, ZIndex=0, Parent=screenGui,
})
corner(glow, 32)

local panel = mkFrame({
	Name="Panel", AnchorPoint=Vector2.new(0.5,0.5),
	Size=UDim2.new(0,400,0,532), Position=UDim2.new(0.5,0,0.5,0),
	BackgroundColor3=C.bg1, BorderSizePixel=0, Active=true, ZIndex=2, Parent=screenGui,
})
corner(panel, 20)
stroke(panel, C.border, 1)
do
	local g = Instance.new("UIGradient")
	g.Color    = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(17,21,35)), ColorSequenceKeypoint.new(1,Color3.fromRGB(9,11,19))})
	g.Rotation = 130
	g.Parent   = panel
end

ui.glow  = glow
ui.panel = panel
ui.toggles = {}

-- ── HEADER ──────────────────────────────────
local header = mkFrame({
	Size=UDim2.new(1,0,0,66), BackgroundColor3=C.bg0, BorderSizePixel=0, ZIndex=3, Parent=panel,
})
corner(header, 20)
mkFrame({Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,0,1,-20), BackgroundColor3=C.bg0, BorderSizePixel=0, ZIndex=3, Parent=header})
mkFrame({Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,1,-1), BackgroundColor3=C.border, BorderSizePixel=0, ZIndex=4, Parent=header})

local iconF = mkFrame({
	Size=UDim2.new(0,34,0,34), Position=UDim2.new(0,14,0.5,0), AnchorPoint=Vector2.new(0,0.5),
	BackgroundColor3=C.a1, BackgroundTransparency=0.82, BorderSizePixel=0, ZIndex=4, Parent=header,
})
corner(iconF, 10)
stroke(iconF, C.a1, 0.8)
mkLabel({Size=UDim2.new(1,0,1,0), Text="⚡", TextSize=17, TextColor3=C.a1, Font=Enum.Font.GothamBold, ZIndex=5, Parent=iconF})

mkLabel({
	Size=UDim2.new(1,-140,0,22), Position=UDim2.new(0,58,0,11),
	Text="Power-up Panel", TextColor3=C.t0, TextSize=18, Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4, Parent=header,
})
mkLabel({
	Size=UDim2.new(1,-140,0,14), Position=UDim2.new(0,58,0,34),
	Text="Configuração para estilo Subway Surfing", TextColor3=C.t2, TextSize=10,
	TextXAlignment=Enum.TextXAlignment.Left, ZIndex=4, Parent=header,
})

local dragHandle = mkButton({
	Name="DragHandle", Size=UDim2.new(1,-52,1,0),
	BackgroundTransparency=1, Text="", ZIndex=5, Parent=header,
})

local closeBtn = mkButton({
	Size=UDim2.new(0,30,0,30), Position=UDim2.new(1,-44,0.5,0), AnchorPoint=Vector2.new(0,0.5),
	BackgroundColor3=Color3.fromRGB(60,15,15), BackgroundTransparency=0.5,
	Text="✕", TextColor3=Color3.fromRGB(255,100,100), TextSize=12,
	Font=Enum.Font.GothamBold, ZIndex=5, Parent=header,
})
corner(closeBtn, 10)
stroke(closeBtn, Color3.fromRGB(180,40,40), 0.8)

-- ── SCROLL ───────────────────────────────────
local scroll = Instance.new("ScrollingFrame")
scroll.Size                  = UDim2.new(1,-14,1,-78)
scroll.Position              = UDim2.new(0,7,0,70)
scroll.BackgroundTransparency= 1
scroll.BorderSizePixel       = 0
scroll.ScrollBarThickness    = 3
scroll.ScrollBarImageColor3  = C.borderH
scroll.CanvasSize            = UDim2.new(0,0,0,0)
scroll.AutomaticCanvasSize   = Enum.AutomaticSize.Y
scroll.ZIndex                = 3
scroll.Parent                = panel

do
	local l = Instance.new("UIListLayout")
	l.Padding             = UDim.new(0,8)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.SortOrder           = Enum.SortOrder.LayoutOrder
	l.Parent              = scroll
	local p = Instance.new("UIPadding")
	p.PaddingTop    = UDim.new(0,8)
	p.PaddingBottom = UDim.new(0,10)
	p.PaddingLeft   = UDim.new(0,6)
	p.PaddingRight  = UDim.new(0,6)
	p.Parent        = scroll
end

local function mkCard(order, h)
	local c = mkFrame({
		Size=UDim2.new(1,0,0,h or 72), BackgroundColor3=C.bg2,
		BorderSizePixel=0, LayoutOrder=order, Parent=scroll,
	})
	corner(c, 14)
	stroke(c, C.border, 1)
	return c
end

local TOGGLE_DEFS = {
	{ key="magnet",   order=1, label="Ímã de Moedas",  desc="Atrai moedas próximas automaticamente enquanto estiver ativo.",              color=C.a3, icon="🧲" },
	{ key="coin2x",   order=2, label="Multiplicador 2x", desc="Tenta contar moeda em dobro ao coletar.",                                     color=C.a2, icon="💰" },
}

for _, def in ipairs(TOGGLE_DEFS) do
	local card = mkCard(def.order, 82)

	local bar = mkFrame({Size=UDim2.new(0,3,1,-18), Position=UDim2.new(0,0,0,9), BackgroundColor3=def.color, BorderSizePixel=0, Parent=card})
	corner(bar, 2)

	mkLabel({Size=UDim2.new(0,30,0,30), Position=UDim2.new(0,12,0.5,0), AnchorPoint=Vector2.new(0,0.5), Text=def.icon, TextSize=19, TextColor3=def.color, Parent=card})

	mkLabel({
		Size=UDim2.new(1,-150,0,18), Position=UDim2.new(0,50,0,13),
		Text=def.label, TextColor3=C.t0, TextSize=13, Font=Enum.Font.GothamBold,
		TextXAlignment=Enum.TextXAlignment.Left, Parent=card,
	})
	mkLabel({
		Size=UDim2.new(1,-150,0,34), Position=UDim2.new(0,50,0,32),
		Text=def.desc, TextColor3=C.t2, TextSize=9.5, TextWrapped=true,
		TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top, Parent=card,
	})

	local badgeF = mkFrame({
		Size=UDim2.new(0,56,0,18), Position=UDim2.new(1,-66,0,13),
		BackgroundColor3=def.color, BackgroundTransparency=0.9, BorderSizePixel=0, Parent=card,
	})
	corner(badgeF, 9)
	stroke(badgeF, def.color, 0.8)
	local badgeL = mkLabel({Size=UDim2.new(1,0,1,0), Text="INATIVO", TextColor3=def.color, TextSize=9, Font=Enum.Font.GothamBold, Parent=badgeF})

	local switchBtn = mkButton({
		Size=UDim2.new(0,54,0,28), Position=UDim2.new(1,-66,0,47),
		BackgroundTransparency=1, Text="", ZIndex=4, Parent=card,
	})
	local track = mkFrame({Size=UDim2.new(1,0,1,0), BackgroundColor3=C.bg3, BorderSizePixel=0, Parent=switchBtn})
	corner(track, 14)
	stroke(track, C.border, 1)
	local knob = mkFrame({
		AnchorPoint=Vector2.new(0,0.5), Size=UDim2.new(0,22,0,22),
		Position=UDim2.new(0,3,0.5,0), BackgroundColor3=C.t1, BorderSizePixel=0, ZIndex=5, Parent=track,
	})
	corner(knob, 11)

	ui.toggles[def.key] = {
		card=card, cardStroke=card:FindFirstChildOfClass("UIStroke"),
		badgeFrame=badgeF, badgeLabel=badgeL,
		switchBtn=switchBtn, track=track, knob=knob, color=def.color,
	}

	card.MouseEnter:Connect(function() tw(card,{BackgroundColor3=Color3.fromRGB(23,27,43)},0.14):Play() end)
	card.MouseLeave:Connect(function() tw(card,{BackgroundColor3=C.bg2},0.14):Play() end)
end

-- ── STATUS ────────────────────────────────────
local statusCard = mkCard(5, 64)
local statusLabel = mkLabel({
	Size=UDim2.new(1,-24,0,20), Position=UDim2.new(0,14,0,10),
	Text="● Pronto", TextColor3=C.ok, TextSize=13, Font=Enum.Font.GothamBold,
	TextXAlignment=Enum.TextXAlignment.Left, Parent=statusCard,
})
local summaryLabel = mkLabel({
	Size=UDim2.new(1,-24,0,26), Position=UDim2.new(0,14,0,32),
	Text="Ímã: OFF  ·  2x: OFF",
	TextColor3=C.t2, TextSize=10, TextWrapped=true,
	TextXAlignment=Enum.TextXAlignment.Left, TextYAlignment=Enum.TextYAlignment.Top,
	Font=Enum.Font.GothamMedium, Parent=statusCard,
})

ui.statusLabel  = statusLabel
ui.summaryLabel = summaryLabel

-- ─────────────────────────────────────────────
-- UI HELPERS
-- ─────────────────────────────────────────────
local function setStatus(text, color)
	statusLabel.Text       = "● " .. text
	statusLabel.TextColor3 = color or C.t0
end

local function updateSummary()
	summaryLabel.Text = string.format(
		"Ímã: %s  ·  2x: %s",
		S.magnetEnabled and "ON" or "OFF",
		S.coin2xEnabled and "ON" or "OFF"
	)
end

local function setToggleVisual(key, enabled)
	local t = ui.toggles[key]
	if not t then return end
	local ac = t.color
	t.badgeLabel.Text       = enabled and "ATIVO" or "INATIVO"
	t.badgeLabel.TextColor3 = enabled and ac or C.t2
	t.badgeFrame.BackgroundTransparency = enabled and 0.72 or 0.92
	tw(t.track,      {BackgroundColor3 = enabled and ac or C.bg3}):Play()
	tw(t.knob,       {Position = enabled and UDim2.new(1,-25,0.5,0) or UDim2.new(0,3,0.5,0)}):Play()
	tw(t.knob,       {BackgroundColor3 = enabled and Color3.fromRGB(255,255,255) or C.t1}):Play()
	tw(t.cardStroke, {Color = enabled and ac:Lerp(Color3.fromRGB(255,255,255),0.1) or C.border}):Play()
	updateSummary()
end

-- ─────────────────────────────────────────────
-- ÍMÃO
-- ─────────────────────────────────────────────
local function isCoinPart(obj)
	if not obj or not obj:IsA("BasePart") then return false end
	local nm = string.lower(obj.Name)
	return obj:GetAttribute("IsCoin") == true
		or nm == "coin" or nm == "coinpart"
		or (string.find(nm,"coin",1,true) ~= nil)
end

local function replayCoinRemote(coin)
	if not S.coin2xEnabled then return end
	if #S.coin2xRemoteCalls == 0 then return end

	for _, call in ipairs(S.coin2xRemoteCalls) do
		if call.remote and call.remote.Parent then
			local args = cloneArgs(call.args)
			local replacedCoinArg = false

			for index, value in ipairs(args) do
				if typeof(value) == "Instance" then
					local foundCoin = findCoinAncestor(value)
					if foundCoin then
						args[index] = coin
						replacedCoinArg = true
					end
				end
			end

			if replacedCoinArg or isCoinRelatedRemoteCall(call.remote, args) then
				S.coin2xReplayingRemote = true
				pcall(function()
					if call.methodName == "FireServer" then
						call.remote:FireServer(table.unpack(args))
					elseif call.methodName == "InvokeServer" then
						call.remote:InvokeServer(table.unpack(args))
					end
				end)
				S.coin2xReplayingRemote = false
				return true
			end
		end
	end

	return false
end

local function tryCoin2xTouch(coin)
	if not S.coin2xEnabled then return end
	if not coin or not coin.Parent then return end

	local now = os.clock()
	local last = S.coin2xTouchedAt[coin]
	if last and (now - last) < CFG.Coin2xTouchCooldown then return end
	S.coin2xTouchedAt[coin] = now

	replayCoinRemote(coin)

	if typeof(firetouchinterest) ~= "function" then return end

	local touchParts = getTouchParts()
	if #touchParts == 0 then return end

	for repeatIndex = 1, CFG.Coin2xTouchRepeats do
		task.delay((repeatIndex - 1) * 0.03, function()
			if not coin.Parent then return end
			for _, part in ipairs(getTouchParts()) do
				pcall(function()
					firetouchinterest(part, coin, 0)
					firetouchinterest(part, coin, 1)
				end)
			end
		end)
	end
end

local function processCoins(dt)
	if not S.magnetEnabled and not S.coin2xEnabled then return end
	local rp = getRootPart()
	if not rp then return end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if isCoinPart(obj) then
			local off  = rp.Position - obj.Position
			local dist = off.Magnitude
			if S.coin2xEnabled and dist <= CFG.CoinPickupRadius then
				tryCoin2xTouch(obj)
			end
			if S.magnetEnabled and dist <= CFG.MagnetRadius and dist > 0.1 then
				obj.CFrame = obj.CFrame + off.Unit * math.min(dist, CFG.MagnetPullSpeed * dt)
			end
		end
	end
end

-- ─────────────────────────────────────────────
-- ATIVAR / DESATIVAR
-- ─────────────────────────────────────────────
local function setMagnet(v)
	S.magnetEnabled = v
	setToggleVisual("magnet", v)
	setStatus(v and "Ímã ativo" or "Ímã desativado", v and C.a3 or C.t1)
end

local function setCoin2x(v)
	S.coin2xEnabled = v
	setToggleVisual("coin2x", v)
	if v then
		ensureCoin2xRemoteHook()
	end
	if v and typeof(firetouchinterest) ~= "function" and not S.coin2xRemoteHooked then
		setStatus("2x ativo (ambiente limitado)", C.a2)
	else
		setStatus(v and "Multiplicador 2x ativo" or "Multiplicador 2x desativado", v and C.a2 or C.t1)
	end
end

-- ─────────────────────────────────────────────
-- GLOW SYNC
-- ─────────────────────────────────────────────
local function syncGlow()
	if not ui.glow or not ui.panel then return end
	local ap = ui.panel.AbsolutePosition
	local as = ui.panel.AbsoluteSize
	ui.glow.Size     = UDim2.new(0, as.X+44, 0, as.Y+44)
	ui.glow.Position = UDim2.new(0, ap.X+as.X*0.5, 0, ap.Y+as.Y*0.5+14)
end

-- ─────────────────────────────────────────────
-- DRAG DO PAINEL
-- ─────────────────────────────────────────────
local function updatePanelDrag(input)
	if not S.panelDragStart or not S.panelStartPos then return end
	local delta = input.Position - S.panelDragStart
	local cam   = Workspace.CurrentCamera
	local vp    = cam and cam.ViewportSize or Vector2.new(1280,720)
	local hw    = ui.panel.AbsoluteSize.X * 0.5
	local hh    = ui.panel.AbsoluteSize.Y * 0.5
	local nx    = clamp(S.panelStartPos.X.Offset + delta.X, hw, vp.X - hw)
	local ny    = clamp(S.panelStartPos.Y.Offset + delta.Y, hh, vp.Y - hh)
	ui.panel.Position = UDim2.new(0, nx, 0, ny)
	syncGlow()
end

-- ─────────────────────────────────────────────
-- HOVER FECHAR
-- ─────────────────────────────────────────────
closeBtn.MouseEnter:Connect(function()
	tw(closeBtn, {BackgroundColor3=Color3.fromRGB(200,40,40), BackgroundTransparency=0.1}, 0.12):Play()
end)
closeBtn.MouseLeave:Connect(function()
	tw(closeBtn, {BackgroundColor3=Color3.fromRGB(60,15,15), BackgroundTransparency=0.5}, 0.12):Play()
end)

-- ─────────────────────────────────────────────
-- INIT
-- ─────────────────────────────────────────────
setToggleVisual("magnet",   false)
setToggleVisual("coin2x",   false)
setStatus("Pronto", C.ok)
updateSummary()
syncGlow()

-- ─────────────────────────────────────────────
-- EVENTS
-- ─────────────────────────────────────────────

-- Toggles
for key, t in pairs(ui.toggles) do
	conn(t.switchBtn.MouseButton1Click:Connect(function()
		if key == "magnet"   then setMagnet(not S.magnetEnabled)    end
		if key == "coin2x"   then setCoin2x(not S.coin2xEnabled)    end
	end))
	conn(t.card.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		if key == "magnet"   then setMagnet(not S.magnetEnabled)    end
		if key == "coin2x"   then setCoin2x(not S.coin2xEnabled)    end
	end))
end

-- Drag painel
conn(dragHandle.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		S.panelDragging  = true
		S.panelDragStart = input.Position
		S.panelStartPos  = ui.panel.Position
	end
end))
conn(dragHandle.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		S.panelDragging = false
	end
end))

-- Movimento global (drag painel + slider)
conn(UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
	and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if S.panelDragging then updatePanelDrag(input) end
end))

-- Solta mouse em qualquer lugar
conn(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
	or input.UserInputType == Enum.UserInputType.Touch then
		S.panelDragging  = false
	end
end))

-- Glow sync
conn(ui.panel:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncGlow))
conn(ui.panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncGlow))
local cam0 = Workspace.CurrentCamera
if cam0 then conn(cam0:GetPropertyChangedSignal("ViewportSize"):Connect(syncGlow)) end

-- Respawn
conn(LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.3)
	if S.magnetEnabled   then setToggleVisual("magnet",   true) end
	if S.coin2xEnabled   then setToggleVisual("coin2x",   true) end
	updateSummary()
	setStatus("Respawn — funções restauradas", C.ok)
end))

-- Loop principal
conn(RunService.RenderStepped:Connect(function(dt)
	processCoins(dt)
end))

-- Fechar
conn(closeBtn.MouseButton1Click:Connect(function()
	setMagnet(false)
	setCoin2x(false)
	disconnAll()
	screenGui:Destroy()
end))
