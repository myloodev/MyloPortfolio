local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Modules = Framework:WaitForChild("Modules")
local Remotes = Framework:WaitForChild("Remotes")
local Weapons = Framework:WaitForChild("Weapons")

local FireEvent = Remotes:WaitForChild("Fire") :: RemoteEvent
local ReloadEvent = Remotes:WaitForChild("Reload") :: RemoteEvent

local ViewmodelService = require(Modules:WaitForChild("ViewmodelService"))
local ShotHandler = require(Modules:WaitForChild("ShotHandler"))

local player = Players.LocalPlayer

export type WeaponClient = {
	Weapon: Tool,
	Config: table,
	Viewmodel: any,
	Ammo: number,
	Aiming: boolean,
	Reloading: boolean,
	Equipped: boolean,
	Fire: (self: WeaponClient) -> (),
	Reload: (self: WeaponClient) -> (),
	Aim: (self: WeaponClient) -> (),
	StopAim: (self: WeaponClient) -> (),
	Init: (self: WeaponClient) -> (),
	Destroy: (self: WeaponClient) -> (),
}

local WeaponClient = {}
WeaponClient.__index = WeaponClient

function WeaponClient.Construct(tool: Tool): WeaponClient
	local config = require(Weapons:WaitForChild(tool.Name))
	local self = setmetatable({}, WeaponClient)
	
	self.Weapon = tool
	self.Config = config
	self.Viewmodel = nil
	self.Ammo = config.MagSize or 30
	self.Aiming = false
	self.Reloading = false
	self.Equipped = false
	self.Connections = {}
	self.LastShot = 0
	
	return self :: any
end

function WeaponClient:IsReady()
	return self.Equipped and not self.Reloading
end

function WeaponClient:CanFire()
	if not self:IsReady() then return false end
	if self.Ammo <= 0 then return false end
	
	local cooldown = 60 / self.Config.FireRate
	if os.clock() - self.LastShot < cooldown then return false end
	return true
end

function WeaponClient:GetAimPosition()
	local camera = workspace.CurrentCamera
	local viewSize = camera.ViewportSize
	local ray = camera:ScreenPointToRay(viewSize.X / 2, viewSize.Y / 2)
	
	local result = workspace:Raycast(ray.Origin, ray.Direction * self.Config.Range)
	if result then 
		return result.Position 
	end
	
	return ray.Origin + ray.Direction * self.Config.Range
end

function WeaponClient:PlayMuzzleEffects()
	if not self.Viewmodel or not self.Viewmodel.CurrentVM then return end
	
	local gun = self.Viewmodel.CurrentVM:FindFirstChild("Gun")
	local muzzle = gun and gun:FindFirstChild("Muzzle")
	if not muzzle then return end
	
	for _, effect in muzzle:GetChildren() do
		if effect:IsA("ParticleEmitter") then
			effect:Emit(effect:GetAttribute("Amount") or 10)
		end
	end
end

function WeaponClient:CreateTracer(position)
	if not self.Viewmodel or not self.Viewmodel.CurrentVM then return end
	
	local gun = self.Viewmodel.CurrentVM:FindFirstChild("Gun")
	local muzzle = gun and gun:FindFirstChild("Muzzle")
	if not muzzle then return end
	
	ShotHandler:CreateTracer(muzzle.Position, position, self.Config.Range)
end

function WeaponClient:Fire()
	if not self:CanFire() then return end
	
	self.LastShot = os.clock()
	self.Ammo -= 1
	
	local position = self:GetAimPosition()
	FireEvent:FireServer(position)
	
	self:PlayMuzzleEffects()
	self:CreateTracer(position)
end

function WeaponClient:Reload()
	if self.Reloading then return end
	if self.Ammo >= self.Config.MagSize then return end
	
	self.Reloading = true
	ReloadEvent:FireServer()
	
	task.delay(self.Config.ReloadTime or 2, function()
		self.Ammo = self.Config.MagSize
		self.Reloading = false
	end)
end

function WeaponClient:Aim()
	if self.Aiming then return end
	self.Aiming = true
	
	if self.Viewmodel then
		self.Viewmodel:StartAim()
	end
end

function WeaponClient:StopAim()
	if not self.Aiming then return end
	self.Aiming = false
	
	if self.Viewmodel then
		self.Viewmodel:StopAim()
	end
end

function WeaponClient:Equip()
	self.Equipped = true
	self.Viewmodel = ViewmodelService.Construct(self.Weapon.Name)
	self.Viewmodel:Create()
end

function WeaponClient:Unequip()
	self.Equipped = false
	self:StopAim()
	self:Destroy()
end

function WeaponClient:SetupConnections()
	table.insert(self.Connections, self.Weapon.Activated:Connect(function()
		self:Fire()
	end))
	
	table.insert(self.Connections, self.Weapon.Equipped:Connect(function()
		self:Equip()
	end))
	
	table.insert(self.Connections, self.Weapon.Unequipped:Connect(function()
		self:Unequip()
	end))
end

function WeaponClient:Update(dt)
	if not self.Viewmodel then return end
	self.Viewmodel:Update(dt)
end

function WeaponClient:Init()
	self:SetupConnections()
	self.UpdateConnection = RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end

function WeaponClient:Destroy()
	if self.Viewmodel then
		self.Viewmodel:Destroy()
		self.Viewmodel = nil
	end
	
	for _, connection in self.Connections do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	
	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end
end

return WeaponClient
