local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Server = Modules:WaitForChild("Server")

local SessionHandler = require(Server:WaitForChild("SessionHandler"))

export type QueueService = {
	SessionHandler: SessionHandler.SessionHandler,

	Queue: {Player},

	Machine: Model,
	Player1Holder: BasePart,
	Player2Holder: BasePart,

	Player1: Player?,
	Player2: Player?,

	Init: (self: QueueService) -> (),
	FindInQueue: (self: QueueService, player: Player) -> boolean,
	JoinQueue: (self: QueueService, player: Player) -> boolean,
	LeaveQueue: (self: QueueService, player: Player) -> boolean,
	StartQueue: (self: QueueService) -> boolean,
	ClearQueue: (self: QueueService) -> (),
	GetQueue: (self: QueueService) -> {Player},
	AddPlayerFromPart: (self: QueueService, hit: BasePart) -> ()
}

local QueueService = {}
QueueService.__index = QueueService

function QueueService.new(machine: Model): QueueService
	local self = setmetatable({}, QueueService)

	self.SessionHandler = SessionHandler.new()

	self.Machine = machine
	self.Player1Holder = machine:WaitForChild("Player1Holder") :: BasePart
	self.Player2Holder = machine:WaitForChild("Player2Holder") :: BasePart

	self.Queue = {}
	self.Player1 = nil
	self.Player2 = nil
	self.Timer = 5
	self:Init()

	return self
end

function QueueService:FindInQueue(player: Player): boolean
	return table.find(self.Queue, player) ~= nil
end



function QueueService:JoinQueue(player: Player): boolean
	if self:FindInQueue(player) then
		return false
	end

	table.insert(self.Queue, player)

	return true
end

function QueueService:LeaveQueue(player: Player): boolean
	local index = table.find(self.Queue, player)

	if not index then
		return false
	end

	table.remove(self.Queue, index)

	return true
end

function QueueService:StartQueue(): boolean
	if #self.Queue < 2 then
		return false
	end


	local player1 = table.remove(self.Queue, 1)
	local player2 = table.remove(self.Queue, 1)

	if not player1 or not player2 then
		return false
	end


	self.Player1 = player1
	self.Player2 = player2
	while self.Timer > 0 do
		self.Timer -= 1
		print(self.Timer)
		task.wait(1)
	end

	if not player1 or not player2 then
		return false
	end

	self.Timer = 5
	self.SessionHandler:StartSession(player1, player2)

	self.Player1 = nil
	self.Player2 = nil

	return true
end

function QueueService:ClearQueue()
	table.clear(self.Queue)

	self.Player1 = nil
	self.Player2 = nil
end

function QueueService:GetQueue(): {Player}
	return self.Queue
end

function QueueService:AddPlayerFromPart(hit: BasePart)
	local character = hit.Parent

	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)

	if not player then
		return
	end

	self:JoinQueue(player)
end

function QueueService:Init()
	self.Player1Holder.Touched:Connect(function(hit)
		self:AddPlayerFromPart(hit)
	end)

	self.Player2Holder.Touched:Connect(function(hit)
		self:AddPlayerFromPart(hit)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			print(self.Queue)
			self:StartQueue()
		end
	end)
end

return QueueService
