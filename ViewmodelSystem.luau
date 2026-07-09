--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")


local Collision = require(script.Collision)
local Sway = require(script.Sway)
local Bob = require(script.Bob)
local Config = require(script.Config)


local Shared = ReplicatedStorage.Shared
local ViewmodelsFolder = Shared.Viewmodels
local camera = workspace.CurrentCamera


local ViewmodelService = {}

type ViewmodelService = {
	Name: string,
	CurrentCamera: Camera,
	CurrentVM: Model,
	connections: {},
	
	Start: (self: ViewmodelService) -> (),
	Stop: (self: ViewmodelService) -> (),
	FindViewmodel: (self: ViewmodelService, name: string) -> Model,
}

function ViewmodelService.new(name: string): ViewmodelService
	local self: ViewmodelService = setmetatable({}, ViewmodelService)
	
	self.Name = name
	self.CurrentCamera = camera
	self.CurrentVM = nil
	self.connections = {}
	return self
end

function ViewmodelService:FindViewmodel(name: string)
	return ViewmodelsFolder:FindFirstChild(name)
end

function ViewmodelService:Start()
	
	self.CurrentVM = self:FindViewmodel(self.name):Clone()
	self.CurrentVM.Parent = self.CurrentCamera
	self.CurrentVM:PivotTo(self.CurrentCamera.CFrame)
	
	self.Sway = Sway.new()
	self.Bob = Bob.new()
	self.Collision = Collision.new()
	
	self.Sway:Start()
	self.Bob:Start()
	self.Collision:Start()
	
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt)
		if self.CurrentVM then
		self.CurrentVM:PivotTo(self.CurrentCamera.CFrame * self.Sway:Update() * self.Bob:Update(dt) * self.Collision:Update(dt))
		end
	end))
end

function ViewmodelService:Stop()
	
	if self.CurrentVM then
		self.CurrentVM:Destroy()
		self.CurrentVM = nil
	end
	
	if self.Sway then
		self.Sway:Stop()
		self.Sway = nil
	end
	
	if self.Bob then
		self.Bob:Stop()
		self.Bob = nil
	end
	
	if self.Collision then
		self.Collision:Stop()
		self.Collision = nil
	end
	
	if self.connections then
		for _, connection in self.connections do
			connection:Disconnect()
		end
		self.connections = {}
	end
end


return ViewmodelService
