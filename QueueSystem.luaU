local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Server = Modules:WaitForChild("Server")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local LeaveQueueEvent = Remotes:WaitForChild("LeaveQueueEvent") :: RemoteEvent
local JoinQueueEvent = Remotes:WaitForChild("JoinQueueEvent") :: RemoteEvent
local SessionHandler = require(Server:WaitForChild("SessionHandler"))

export type QueueService = {
	SessionHandler: any,
	Queue: {Player},
	Machine: Model,
	Player1Holder: BasePart,
	Player2Holder: BasePart,
	Player1: Player?,
	Player2: Player?,
	Timer: number,
	Init: (self: QueueService) -> (),
	FindInQueue: (self: QueueService, player: Player) -> boolean,
	JoinQueue: (self: QueueService, player: Player) -> boolean,
	LeaveQueue: (self: QueueService, player: Player) -> boolean,
	StartQueue: (self: QueueService) -> boolean,
	ClearQueue: (self: QueueService) -> (),
	GetQueue: (self: QueueService) -> {Player},
	AddPlayerFromPart: (self: QueueService, hit: BasePart, holderPart: BasePart) -> (),
	FreezePlayer: (self: QueueService, player: Player, holderPart: BasePart) -> (),
	UnfreezePlayer: (self: QueueService, player: Player) -> ()
}

local QueueService = {}
QueueService.__index = QueueService

local ActivePlayerQueues = {}

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
	return self :: any
end

function QueueService:FindInQueue(player: Player): boolean
	return table.find(self.Queue, player) ~= nil
end

function QueueService:JoinQueue(player: Player): boolean
	if ActivePlayerQueues[player] then return false end
	if self:FindInQueue(player) then return false end

	table.insert(self.Queue, player)
	ActivePlayerQueues[player] = self
	JoinQueueEvent:FireClient(player)
	return true
end

function QueueService:LeaveQueue(player: Player): boolean
	local index = table.find(self.Queue, player)
	if not index then return false end

	table.remove(self.Queue, index)
	if ActivePlayerQueues[player] == self then
		ActivePlayerQueues[player] = nil
	end
	return true
end

function QueueService:FreezePlayer(player: Player, holderPart: BasePart)
	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart

	if hum and hrp then
		local animator = hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				track:Stop()
			end
		end

		hum:Move(Vector3.zero)
		hum.WalkSpeed = 0
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		character:PivotTo(holderPart.CFrame)
		hrp.Anchored = true
	end
end

function QueueService:UnfreezePlayer(player: Player)
	local character = player.Character
	if not character then return end

	local hum = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart

	if hrp then
		hrp.Anchored = false
	end
	if hum then
		hum.WalkSpeed = 16
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function QueueService:StartQueue(): boolean
	if #self.Queue < 2 then return false end
	if self.Player1 or self.Player2 then return false end

	local player1 = self.Queue[1]
	local player2 = self.Queue[2]

	if not player1 or not player2 then return false end

	table.remove(self.Queue, 1)
	table.remove(self.Queue, 1)

	self.Player1 = player1
	self.Player2 = player2

	while self.Timer > 0 do
		if not player1.Parent or not player2.Parent or not ActivePlayerQueues[player1] or not ActivePlayerQueues[player2] then
			self:ClearQueue()
			return false
		end
		print("starting in " .. self.Timer)
		self.Timer -= 1
		task.wait(1)
	end

	if not player1.Parent or not player2.Parent then
		self:ClearQueue()
		return false
	end

	local teleportTarget = workspace:FindFirstChild("PlayerTeleport") :: BasePart

	if player1.Character and player1.Character:FindFirstChild("HumanoidRootPart") then
		player1.Character.HumanoidRootPart.Anchored = false
		player1.Character:PivotTo(teleportTarget.CFrame)
	end

	if player2.Character and player2.Character:FindFirstChild("HumanoidRootPart") then
		player2.Character.HumanoidRootPart.Anchored = false
		player2.Character:PivotTo(teleportTarget.CFrame)
	end

	ActivePlayerQueues[player1] = nil
	ActivePlayerQueues[player2] = nil

	self.Timer = 5
	self.SessionHandler:StartSession(player1, player2)

	self.Player1 = nil
	self.Player2 = nil
	return true
end

function QueueService:ClearQueue()
	for _, player in self.Queue do
		if ActivePlayerQueues[player] == self then
			ActivePlayerQueues[player] = nil
			self:UnfreezePlayer(player)
		end
	end
	table.clear(self.Queue)

	if self.Player1 then
		ActivePlayerQueues[self.Player1] = nil
		self:UnfreezePlayer(self.Player1)
		self.Player1 = nil
	end
	if self.Player2 then
		ActivePlayerQueues[self.Player2] = nil
		self:UnfreezePlayer(self.Player2)
		self.Player2 = nil
	end
	self.Timer = 5
end

function QueueService:GetQueue(): {Player}
	return self.Queue
end

function QueueService:AddPlayerFromPart(hit: BasePart, holderPart: BasePart)
	local character = hit.Parent
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	if ActivePlayerQueues[player] then return end

	local joined = self:JoinQueue(player)
	if joined then
		self:FreezePlayer(player, holderPart)
	end
end

function QueueService:Init()
	self.Player2Holder.Touched:Connect(function(hit)
		self:AddPlayerFromPart(hit, self.Player2Holder)
	end)

	self.Player1Holder.Touched:Connect(function(hit)
		self:AddPlayerFromPart(hit, self.Player1Holder)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			self:StartQueue()
		end
	end)

	JoinQueueEvent.OnServerEvent:Connect(function(player)
		if ActivePlayerQueues[player] then return end
		self:JoinQueue(player)
	end)

	LeaveQueueEvent.OnServerEvent:Connect(function(player)
		if ActivePlayerQueues[player] ~= self then return end
		if not self:FindInQueue(player) then return end

		self:LeaveQueue(player)
		self:UnfreezePlayer(player)
		player:LoadCharacterAsync()
	end)

	Players.PlayerRemoving:Connect(function(player)
		if ActivePlayerQueues[player] == self then
			self:LeaveQueue(player)
		end
	end)
end

return QueueService
