local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MagnetGui"
screenGui.Parent = game.CoreGui

local button = Instance.new("TextButton")
button.Parent = screenGui
button.Text = "🧲 Ativar ÍMÃ Moedas"
button.Size = UDim2.new(0, 220, 0, 70)
button.Position = UDim2.new(0.5, -110, 0.88, 0)
button.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 16
button.BorderSizePixel = 0
button.AutoButtonColor = false

-- Efeito de brilho no botão
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = button

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 162, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255))
}
gradient.Parent = button

-- Variáveis
local magnetActive = false
local connections = {}
local magnetRange = 500 -- Raio do ímã (muito grande)
local magnetSpeed = 0.3 -- Velocidade do ímã

-- Função para atualizar botão
local function updateButton(active)
    if active then
        button.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50))
        }
        button.Text = "🔥 ÍMÃ ATIVO (Coleta tudo!)"
    else
        button.BackgroundColor3 = Color3.fromRGB(0, 162, 255)
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 162, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 255))
        }
        button.Text = "🧲 Ativar ÍMÃ Moedas"
    end
end

-- Detecta TODOS os tipos de moedas possíveis
local function findAllCoins()
    local coins = {}
    
    -- Procura em todos os lugares possíveis
    local searchAreas = {
        Workspace,
        Workspace:FindFirstChild("Workspace") or Workspace,
        Workspace:FindFirstChild("Coins"),
        Workspace:FindFirstChild("Coin"), 
        Workspace:FindFirstChild("Money"),
        Workspace:FindFirstChild("Drops"),
        Workspace:FindFirstChild("Collectibles"),
        Workspace:FindFirstChild("Items"),
        Workspace:FindFirstChild("Map"),
        Workspace:FindFirstChild("World")
    }
    
    for _, area in pairs(searchAreas) do
        if area then
            for _, obj in pairs(area:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("MeshPart") then
                    local name = obj.Name:lower()
                    -- Detecta qualquer coisa que seja moeda/dinheiro
                    if name:find("coin") or name:find("money") or name:find("cash") or 
                       name:find("dollar") or name:find("gem") or name:find("drop") or
                       name:find("collect") or name:find("orb") or name:find("crystal") or
                       (obj.BrickColor and obj.Material == Enum.Material.Neon) or
                       obj.Transparency > 0.5 then
                        
                        table.insert(coins, obj)
                    end
                end
            end
        end
    end
    
    return coins
end

-- Efeito ÍMÃ REAL - Tween as moedas até você
local function magnetCollect()
    local coins = findAllCoins()
    
    for _, coin in pairs(coins) do
        if coin and coin.Parent and coin.Position then
            local distance = (hrp.Position - coin.Position).Magnitude
            
            -- Se estiver no alcance do ímã
            if distance <= magnetRange then
                -- Torna a moeda não colidível e transparente (efeito voando)
                pcall(function()
                    coin.CanCollide = false
                    coin.Anchored = false
                    coin.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end)
                
                -- Tween direto para o jogador (ímã poderoso)
                local tweenInfo = TweenInfo.new(
                    math.min(magnetSpeed, distance * 0.003), -- Velocidade baseada na distância
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
                
                local tween = TweenService:Create(
                    coin,
                    tweenInfo,
                    {Position = hrp.Position + Vector3.new(0, 5, 0)}
                )
                
                tween:Play()
                
                -- Coleta automática quando chegar perto
                tween.Completed:Connect(function()
                    if coin and coin.Parent then
                        firetouchinterest(hrp, coin, 0)
                        firetouchinterest(hrp, coin, 1)
                        wait(0.1)
                        firetouchinterest(hrp, coin, 0)
                        firetouchinterest(hrp, coin, 1)
                    end
                end)
            end
        end
    end
end

-- Loop principal do ímã (60 FPS)
local function startMagnet()
    connections.loop = RunService.Heartbeat:Connect(function()
        if magnetActive and hrp.Parent then
            magnetCollect()
        end
    end)
end

-- Função toggle
local function toggleMagnet()
    magnetActive = not magnetActive
    updateButton(magnetActive)
    
    if magnetActive then
        print("🧲 ÍMÃ ATIVADO - Coletando todas as moedas!")
        startMagnet()
    else
        -- Limpa todas as conexões
        for _, conn in pairs(connections) do
            if conn then
                conn:Disconnect()
            end
        end
        connections = {}
        print("🧲 ÍMÃ DESATIVADO")
    end
end

-- Eventos do botão
button.MouseButton1Click:Connect(toggleMagnet)

-- Auto-reconexão
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = character:WaitForChild("HumanoidRootPart")
end)

print("🔥 ÍMÃ DE MOEDAS CARREGADO! Clique para ativar o poder total!")
print("📏 Alcance: " .. magnetRange .. " studs")
print("⚡ Velocidade: Ultra rápida")
