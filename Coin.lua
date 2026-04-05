-- PowerupPanel v4.1 — Híbrido com Sistema de Minimizar
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

-- ─────────────────────────────────────────────
-- INTERFACE (UI)
-- ─────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PowerupPanelV4_Minimizable"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local isMobile = UserInputService.TouchEnabled
local panelSize = isMobile and UDim2.new(0, 320, 0, 400) or UDim2.new(0, 380, 0, 480)

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Main"
mainFrame.Size = panelSize
mainFrame.Position = UDim2.new(0.5, -panelSize.X.Offset/2, 0.5, -panelSize.Y.Offset/2)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Visible = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 15)
local stroke = Instance.new("UIStroke", mainFrame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(45, 55, 85)

-- Floating Button (Inicia invisível)
local floatingBtn = Instance.new("TextButton")
floatingBtn.Name = "FloatingButton"
floatingBtn.Size = UDim2.new(0, 60, 0, 60)
floatingBtn.Position = UDim2.new(0.05, 0, 0.4, 0)
floatingBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
floatingBtn.Text = "⚡"
floatingBtn.TextColor3 = Color3.new(1,1,1)
floatingBtn.TextSize = 30
floatingBtn.Visible = false
floatingBtn.Parent = screenGui

Instance.new("UICorner", floatingBtn).CornerRadius = UDim.new(1, 0)
local fStroke = Instance.new("UIStroke", floatingBtn)
fStroke.Thickness = 2
fStroke.Color = Color3.new(1,1,1)

-- Header
local header = Instance.new("TextButton")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
header.Text = "  ⚡ POWER-UP PANEL"
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.Font = Enum.Font.GothamBold
header.TextSize = 14
header.AutoButtonColor = false
header.Parent = mainFrame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 15)

-- Botões de Controle (Fechar e Minimizar)
local btnContainer = Instance.new("Frame")
btnContainer.Size = UDim2.new(0, 80, 1, 0)
btnContainer.Position = UDim2.new(1, -85, 0, 0)
btnContainer.BackgroundTransparency = 1
btnContainer.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(0.5, 5, 0.5, -15)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Parent = btnContainer
Instance.new("UICorner", closeBtn)

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 30, 0, 30)
minBtn.Position = UDim2.new(0.5, -35, 0.5, -15)
minBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
minBtn.Text = "_"
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Parent = btnContainer
Instance.new("UICorner", minBtn)

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

-- ─────────────────────────────────────────────
-- SISTEMA DE DRAG (ARRASTAR) UNIVERSAL
-- ─────────────────────────────────────────────
local function makeDraggable(obj, target)
    local dragging, dragInput, dragStart, startPos
    target = target or obj

    obj.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeDraggable(header, mainFrame)
makeDraggable(floatingBtn)

-- ─────────────────────────────────────────────
-- LÓGICA MINIMIZAR / MAXIMIZAR
-- ─────────────────────────────────────────────
local function toggleUI(minimized)
    if minimized then
        mainFrame.Visible = false
        floatingBtn.Visible = true
    else
        mainFrame.Visible = true
        floatingBtn.Visible = false
    end
end

minBtn.MouseButton1Click:Connect(function() toggleUI(true) end)
floatingBtn.MouseButton1Click:Connect(function() toggleUI(false) end)

-- ─────────────────────────────────────────────
-- FUNCIONALIDADES
-- ─────────────────────────────────────────────
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

createToggle("Ímã de Moedas", function(v) S.magnetEnabled = v end)
createToggle("Multiplicador 2x", function(v) S.coin2xEnabled = v end)

local function getRoot()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function isCoin(obj)
    local n = obj.Name:lower()
    return obj:IsA("BasePart") and (n:find("coin") or n:find("moeda") or obj:GetAttribute("IsCoin"))
end

-- Loop de Renderização
local heartbeatConn = RunService.Heartbeat:Connect(function(dt)
    if not S.magnetEnabled and not S.coin2xEnabled then return end
    local root = getRoot()
    if not root then return end
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isCoin(obj) then
            local dist = (root.Position - obj.Position).Magnitude
            
            if S.magnetEnabled and dist < CFG.MagnetRadius then
                obj.CFrame = obj.CFrame:Lerp(root.CFrame, dt * (CFG.MagnetPullSpeed / math.max(dist, 1)))
            end
            
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
end)

closeBtn.MouseButton1Click:Connect(function()
    heartbeatConn:Disconnect()
    screenGui:Destroy()
end)
