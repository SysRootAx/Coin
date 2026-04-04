--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local playerData = LocalPlayer:FindFirstChild("PlayerData")
if playerData then
	local upgradeMagnet = playerData:FindFirstChild("Upgrade_magnet")
	if upgradeMagnet and upgradeMagnet:IsA("IntValue") then
		upgradeMagnet.Value = 999999999
	end
end
