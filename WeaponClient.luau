--[[
	Mylos WeaponClient
]]


export type WeaponClient = {
	weapon: Tool,
	viewmodel: any,
	config: table,
	Aiming: boolean,

	Fire: (self: WeaponClient) -> (),
	Aim: (self: WeaponClient) -> (),
	StopAim: (self: WeaponClient) -> (),
	Init: (self: WeaponClient) -> (),
	Destroy: (self: WeaponClient) -> (),
}


local WeaponClient = {}
WeaponClient.__index = WeaponClient


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")


local Framework = ReplicatedStorage:WaitForChild("Framework")
local Modules = Framework:WaitForChild("Modules")
local Remotes = Framework:WaitForChild("Remotes")
local WeaponData = Framework:WaitForChild("Weapons")


local FireEvent = Remotes:WaitForChild("Fire")


local ViewmodelService = require(Modules:WaitForChild("ViewmodelService"))
local ShotHandler = require(Modules:WaitForChild("ShotHandler"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()


function WeaponClient.Construct(tool: Tool): WeaponClient
	local config = require(WeaponData:WaitForChild(tool.Name))

	local self = setmetatable({
		weapon = tool,
		viewmodel = nil,
		config = config,
		Aiming = false,
	}, WeaponClient)

	return self
end


function WeaponClient:Fire()
	FireEvent:FireServer(mouse.Hit.Position)

	local muzzle = self.viewmodel.CurrentVM.Gun.Muzzle

	for _, obj in ipairs(muzzle:GetChildren()) do
		if obj:IsA("ParticleEmitter") then
			obj:Emit(10)
		end
	end

	ShotHandler:CreateTracer(
		muzzle.Position,
		mouse.Hit.Position,
		1000
	)
end

function WeaponClient:Aim()
	if self.Aiming then return end

	self.Aiming = true

	if self.viewmodel then
		self.viewmodel:StartAim()
	end
end


function WeaponClient:StopAim()
	if not self.Aiming then return end

	self.Aiming = false

	if self.viewmodel then
		self.viewmodel:StopAim()
	end
end

function WeaponClient:Init()
	self.viewmodel = ViewmodelService.Construct(self.weapon.Name)
	self.viewmodel:Create()
end


function WeaponClient:Destroy()
	if self.viewmodel then
		self.viewmodel:Destroy()
		self.viewmodel = nil
	end
end

return WeaponClient
