local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoCollectGui"
screenGui.Parent = game.CoreGui

local button = Instance.new("TextButton")
button.Parent = screenGui
button.Text = "🚀 Ativar Auto Moedas"
button.Size = UDim2.new(0, 200, 0, 60)
button.Position = UDim2.new(0.5, -100, 0.85, 0)
button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.BorderSizePixel = 0
button.AutoButtonColor = false

-- Efeitos visuais
local function updateButton(active)
    if active then
        button.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        button.Text = "⏹️ Desativar Auto Moedas"
    else
        button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        button.Text = "🚀 Ativar Auto Moedas"
    end
end

-- Variáveis
local autoCollect = false
local connection

-- Função para coletar moedas
local function collectCoins()
    -- Procura moedas em locais comuns
    local coinFolders = {
        Workspace:FindFirstChild("Coins"),
        Workspace:FindFirstChild("Coin"),
        Workspace:FindFirstChild("Money"),
        Workspace:FindFirstChild("Drops"),
        Workspace
    }
    
    for _, folder in pairs(coinFolders) do
        if folder then
            for _, part in pairs(folder:GetChildren()) do
                if part:IsA("BasePart") and part.Parent ~= character and 
                   (part.Name:lower():find("coin") or part.Name:lower():find("money") or 
                    part.Name:lower():find("drop")) then
                    
                    -- Verifica distância (opcional, para performance)
                    local distance = (hrp.Position - part.Position).Magnitude
                    if distance < 100 then
                        pcall(function()
                            firetouchinterest(hrp, part, 0)
                            firetouchinterest(hrp, part, 1)
                        end)
                    end
                end
            end
        end
    end
end

-- Função principal
local function toggleAutoCollect()
    autoCollect = not autoCollect
    updateButton(autoCollect)
    
    if autoCollect then
        -- Loop otimizado com RunService (muito mais rápido)
        connection = RunService.Heartbeat:Connect(function()
            collectCoins()
        end)
    else
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end
end

-- Evento do botão
button.MouseButton1Click:Connect(toggleAutoCollect)

-- Reconexão automática do personagem
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    hrp = character:WaitForChild("HumanoidRootPart")
end)

print("🔥 Auto Collect Coins carregado! Clique no botão para ativar.")
