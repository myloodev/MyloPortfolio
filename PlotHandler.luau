local Players = game:GetService("Players")

local PlotManager = require(script.Parent.PlotManager)

type Plot = Model & {
	Owner: StringValue,
	PlotNumber: IntValue,
}

local function GetSpawnPosition(plot: Plot): Vector3
	local spawnPoint = plot:FindFirstChild("SpawnPoint")

	if spawnPoint and spawnPoint:IsA("BasePart") then
		return spawnPoint.Position + Vector3.new(0, 3, 0)
	end

	return plot:GetPivot().Position + Vector3.new(0, 3, 0)
end

local function TeleportCharacter(character: Model, position: Vector3)
	local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")

	if rootPart then
		character:PivotTo(CFrame.new(position))
	end
end

local function InitializePlots()
	for index, plot in ipairs(PlotManager.Plots) do
		local owner = Instance.new("StringValue")
		owner.Name = "Owner"
		owner.Parent = plot

		local plotNumber = Instance.new("IntValue")
		plotNumber.Name = "PlotNumber"
		plotNumber.Value = index
		plotNumber.Parent = plot
	end
end

local function AssignPlot(player: Player)
	for index, plot: Plot in ipairs(PlotManager.Plots) do
		if plot.Owner.Value ~= "" then
			continue
		end

		plot.Owner.Value = player.Name

		PlotManager:CreateProfileCircle(plot, player)

		local spawnPosition = GetSpawnPosition(plot)

		player.CharacterAdded:Connect(function(character)
			TeleportCharacter(character, spawnPosition)
		end)

		if player.Character then
			TeleportCharacter(player.Character, spawnPosition)
		end

		break
	end
end

local function ReleasePlot(player: Player)
	for _, plot: Plot in ipairs(PlotManager.Plots) do
		if plot.Owner.Value ~= player.Name then
			continue
		end

		plot.Owner.Value = ""

		local profileCircle = plot:FindFirstChild("ProfileCircle")

		if profileCircle then
			profileCircle:Destroy()
		end

		break
	end
end

InitializePlots()

Players.PlayerAdded:Connect(AssignPlot)
Players.PlayerRemoving:Connect(ReleasePlot)
