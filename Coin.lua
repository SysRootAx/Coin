-- PowerupPanel v4 — Híbrido (Android & Desktop)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

if not game:IsLoaded() then game.Loaded:Wait() end

-- ─────────────────────────────────────────────
-- CONFIGURAÇÃO & ESTADO
-- ─────────────────────────────────────────────
local CFG = {
    MagnetRadius = 30,
    MagnetPullSpeed = 85,
    CoinPickupRadius = 6,
    Coin2xTouchRepeats = 2,
}

local S = {
    magnetEnabled = false,
    coin2xEnabled = false,
    dragging = false,
    dragInput = nil,
    dragStart = nil,
    startPos = nil,
    connections = {},
}

local ui = { toggles = {} }

-- ─────────────────────────────────────────────
-- UTILS
-- ─────────────────────────────────────────────
local function conn(c) table.insert(S.connections, c) return c end

local function disconnAll()
    for _, c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
    S.connections = {}
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ─────────────────────────────────────────────
-- INTERFACE (UI)
-- ─────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PowerupPanelV4"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Ajuste de tamanho para Mobile (usa escala relativa se a tela for pequena)
local isMobile = UserInputService.TouchEnabled
local panelSize = isMobile and UDim2.new(0, 320, 0, 400) or UDim2.new(0, 380, 0, 480)

local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = panelSize
mainFrame.Position = UDim2.new(0.5, -panelSize.X.Offset/2, 0.5, -panelSize.Y.Offset/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 15)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(45, 55, 85)
stroke.Parent = mainFrame

-- Header (Arraste)
local header = Instance.new("TextButton")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
header.Text = "⚡ POWER-UP PANEL (V4)"
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.AutoButtonColor = false
header.Parent = mainFrame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 15)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = header
Instance.new("UICorner", closeBtn)

-- Conteúdo (Lista)
local container = Instance.new("ScrollingFrame")
container.Size = UDim2.new(1, -20, 1, -70)
container.Position = UDim2.new(0, 10, 0, 60)
container.BackgroundTransparency = 1
container.CanvasSize = UDim2.new(0,0,0,0)
container.AutomaticCanvasSize = Enum.AutomaticSize.Y
container.ScrollBarThickness = 2
container.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.Parent = container

-- Função para criar Toggles compatíveis com toque
local function createToggle(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 60)
    btn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    btn.Text = "  " .. name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = container
    Instance.new("UICorner", btn)
    
    local enabled = false
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled
        btn.BackgroundColor3 = enabled and Color3.fromRGB(50, 120, 255) or Color3.fromRGB(30, 35, 50)
        btn.Text = enabled and "  " .. name .. ": ON" or "  " .. name .. ": OFF"
        btn.TextColor3 = enabled and Color3.new(1,1,1) or Color3.fromRGB(200, 200, 200)
        callback(enabled)
    end)
end

-- ─────────────────────────────────────────────
-- LÓGICA DE MOVIMENTAÇÃO (DRAG)
-- ─────────────────────────────────────────────
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        S.dragging = true
        S.dragStart = input.Position
        S.startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                S.dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if S.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - S.dragStart
        mainFrame.Position = UDim2.new(
            S.startPos.X.Scale, S.startPos.X.Offset + delta.X,
            S.startPos.Y.Scale, S.startPos.Y.Offset + delta.Y
        )
    end
end)

-- ─────────────────────────────────────────────
-- FUNCIONALIDADES
-- ─────────────────────────────────────────────
createToggle("Ímã de Moedas", function(v) S.magnetEnabled = v end)
createToggle("Multiplicador 2x", function(v) S.coin2xEnabled = v end)

local function isCoin(obj)
    local n = obj.Name:lower()
    return obj:IsA("BasePart") and (n:find("coin") or n:find("moeda") or obj:GetAttribute("IsCoin"))
end

-- Loop de Renderização
conn(RunService.Heartbeat:Connect(function(dt)
    if not S.magnetEnabled and not S.coin2xEnabled then return end
    
    local root = getRoot()
    if not root then return end
    
    -- Busca otimizada (apenas objetos próximos ou em pastas de moedas se possível)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCoin(obj) then
            local dist = (root.Position - obj.Position).Magnitude
            
            -- Ímã
            if S.magnetEnabled and dist < CFG.MagnetRadius then
                obj.CFrame = obj.CFrame:Lerp(root.CFrame, dt * (CFG.MagnetPullSpeed / dist))
            end
            
            -- 2x (Simulação de toque múltiplo)
            if S.coin2xEnabled and dist < CFG.CoinPickupRadius then
                if typeof(firetouchinterest) == "function" then
                    for i = 1, CFG.Coin2xTouchRepeats do
                        firetouchinterest(root, obj, 0)
                        firetouchinterest(root, obj, 1)
                    end
                end
            end
        end
    end
end))

closeBtn.MouseButton1Click:Connect(function()
    disconnAll()
    screenGui:Destroy()
end)
