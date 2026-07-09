-- WeaponClient By Mylo @xcb8 on discord

-- Services are cached at the top so we don't repeatedly call GetService
-- throughout the module.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")


-- This keeps all framework related objects organized in one location.
-- The client uses these folders to access shared modules, events, and weapon configs.
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Modules = Framework:WaitForChild("Modules")
local Remotes = Framework:WaitForChild("Remotes")
local Weapons = Framework:WaitForChild("Weapons")


local FireEvent = Remotes:WaitForChild("Fire")
local ReloadEvent = Remotes:WaitForChild("Reload")


-- These modules handle separate responsibilities.
-- ViewmodelService controls the first person weapon model.
-- ShotHandler handles visual bullet effects like tracers.
local ViewmodelService = require(Modules:WaitForChild("ViewmodelService"))
local ShotHandler = require(Modules:WaitForChild("ShotHandler"))


local player = Players.LocalPlayer


-- Export types allow Luau's type checker to understand what a WeaponClient object contains.
-- This helps prevent mistakes when accessing properties or calling functions.
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


-- Constructor function responsible for creating a new weapon controller.
-- Each weapon gets its own state instead of relying on shared variables.
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

	-- Connections are stored so they can all be cleaned up later.
	self.Connections = {}

	self.LastShot = 0

	return self
end


-- Checks if the weapon is currently allowed to perform actions.
-- Keeping this in one function prevents repeating the same checks everywhere.
function WeaponClient:IsReady()
	return self.Equipped
		and not self.Reloading
end


-- Handles fire validation before allowing a shot.
-- This prevents firing while reloading, empty magazines, or firing faster than the weapon allows.
function WeaponClient:CanFire()
	if not self:IsReady() then
		return false
	end

	if self.Ammo <= 0 then
		return false
	end

	local cooldown = 60 / self.Config.FireRate

	if tick() - self.LastShot < cooldown then
		return false
	end

	return true
end


-- Converts the center of the player's screen into a world position.
-- This allows the weapon to shoot where the player is aiming instead of directly using the mouse.
function WeaponClient:GetAimPosition()
	local camera = workspace.CurrentCamera

	local ray = camera:ScreenPointToRay(
		camera.ViewportSize.X / 2,
		camera.ViewportSize.Y / 2
	)

	local result = workspace:Raycast(
		ray.Origin,
		ray.Direction * self.Config.Range
	)

	if result then
		return result.Position
	end

	return ray.Origin + ray.Direction * self.Config.Range
end


-- Handles local visual effects so the weapon feels responsive immediately.
-- These effects do not determine damage; the server still handles validation.
function WeaponClient:PlayMuzzleEffects()
	if not self.Viewmodel then
		return
	end

	local muzzle = self.Viewmodel.CurrentVM
		and self.Viewmodel.CurrentVM.Gun.Muzzle

	if not muzzle then
		return
	end

	for _, effect in ipairs(muzzle:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			effect:Emit(effect:GetAttribute("Amount") or 10)
		end
	end
end


-- Creates the visual bullet trail separately from the actual server shot.
-- Keeping visuals separate allows the weapon to feel instant without trusting the client.
function WeaponClient:CreateTracer(position)
	if not self.Viewmodel then
		return
	end

	local muzzle = self.Viewmodel.CurrentVM.Gun.Muzzle

	ShotHandler:CreateTracer(
		muzzle.Position,
		position,
		self.Config.Range
	)
end


-- Main firing function.
-- Handles client feedback while sending the request to the server.
function WeaponClient:Fire()
	if not self:CanFire() then
		return
	end

	self.LastShot = tick()
	self.Ammo -= 1

	local position = self:GetAimPosition()

	FireEvent:FireServer(position)

	self:PlayMuzzleEffects()
	self:CreateTracer(position)
end


-- Reload logic is handled locally for responsiveness.
-- The server should still verify ammo and reload states.
function WeaponClient:Reload()
	if self.Reloading then
		return
	end

	if self.Ammo >= self.Config.MagSize then
		return
	end

	self.Reloading = true

	ReloadEvent:FireServer()

	task.delay(
		self.Config.ReloadTime or 2,
		function()
			self.Ammo = self.Config.MagSize
			self.Reloading = false
		end
	)
end


-- Starts aiming and tells the viewmodel to transition into ADS.
function WeaponClient:Aim()
	if self.Aiming then
		return
	end

	self.Aiming = true

	if self.Viewmodel then
		self.Viewmodel:StartAim()
	end
end


-- Returns the weapon from ADS back to normal position.
function WeaponClient:StopAim()
	if not self.Aiming then
		return
	end

	self.Aiming = false

	if self.Viewmodel then
		self.Viewmodel:StopAim()
	end
end


-- Creates and initializes the first person weapon model.
function WeaponClient:Equip()
	self.Equipped = true

	self.Viewmodel = ViewmodelService.Construct(
		self.Weapon.Name
	)

	self.Viewmodel:Create()
end


-- Cleans up the weapon when it is no longer equipped.
function WeaponClient:Unequip()
	self.Equipped = false

	self:StopAim()

	self:Destroy()
end


-- Connections are stored instead of being created anonymously.
-- This makes cleanup easier and prevents memory leaks.
function WeaponClient:SetupConnections()

	table.insert(
		self.Connections,
		self.Weapon.Activated:Connect(function()
			self:Fire()
		end)
	)

	table.insert(
		self.Connections,
		self.Weapon.Equipped:Connect(function()
			self:Equip()
		end)
	)

	table.insert(
		self.Connections,
		self.Weapon.Unequipped:Connect(function()
			self:Unequip()
		end)
	)
end


-- Update loop passes frame updates to systems that need them.
-- The weapon client itself does not control viewmodel behavior.
function WeaponClient:Update(dt)
	if not self.Viewmodel then
		return
	end

	self.Viewmodel:Update(dt)
end


-- Starts all required connections and update loops.
function WeaponClient:Init()
	self:SetupConnections()

	self.UpdateConnection = RunService.RenderStepped:Connect(function(dt)
		self:Update(dt)
	end)
end


-- Removes references and disconnects events.
-- This prevents memory leaks when weapons are removed or replaced.
function WeaponClient:Destroy()

	if self.Viewmodel then
		self.Viewmodel:Destroy()
		self.Viewmodel = nil
	end


	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end

	table.clear(self.Connections)


	if self.UpdateConnection then
		self.UpdateConnection:Disconnect()
		self.UpdateConnection = nil
	end
end


return WeaponClient
