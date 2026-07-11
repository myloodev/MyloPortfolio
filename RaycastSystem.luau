local Workspace = game:GetService("Workspace")

export type CastOptions = {
	Character: Model?,
	IgnoreList: {Instance}?,
	FilterType: Enum.RaycastFilterType?,
	IgnoreWater: boolean?,
	IgnoreAccessories: boolean?,
	IgnoreTransparent: boolean?,
	IgnoreNonCollidable: boolean?,
	MaxPenetrations: number?,
}

export type CastResult = {
	Instance: BasePart,
	Position: Vector3,
	Normal: Vector3,
	Material: Enum.Material,
	Distance: number,
	Result: RaycastResult,
}

local Raycast = {}

local DEFAULT_MAX_PENETRATIONS = 25
local SURFACE_OFFSET = 0.01

local function isAccessory(part: BasePart)
	return part:FindFirstAncestorOfClass("Accessory") ~= nil
end

local function shouldIgnore(part: BasePart, options: CastOptions)
	if options.IgnoreAccessories and isAccessory(part) then
		return true
	end
	if options.IgnoreTransparent and part.Transparency >= 1 then
		return true
	end
	if options.IgnoreNonCollidable and not part.CanCollide then
		return true
	end
	return false
end

function Raycast.Cast(origin: Vector3, direction: Vector3, radius: number, options: CastOptions?): CastResult?
	local config = options or {}
	
	local ignoreList = {}
	if config.IgnoreList then
		for _, instance in config.IgnoreList do
			table.insert(ignoreList, instance)
		end
	end
	if config.Character then
		table.insert(ignoreList, config.Character)
	end
	
	local params = RaycastParams.new()
	params.FilterType = config.FilterType or Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	params.IgnoreWater = config.IgnoreWater ~= false
	
	local currentOrigin = origin
	local currentDirection = direction
	local limit = config.MaxPenetrations or DEFAULT_MAX_PENETRATIONS
	
	for i = 1, limit do
		local hit = Workspace:Spherecast(currentOrigin, radius, currentDirection, params)
		if not hit then 
			break 
		end
		
		local part = hit.Instance
		if not part or not part:IsA("BasePart") then 
			break 
		end
		
		if not shouldIgnore(part, config) then
			return {
				Instance = part,
				Position = hit.Position,
				Normal = hit.Normal,
				Material = hit.Material,
				Distance = (hit.Position - origin).Magnitude,
				Result = hit,
			}
		end
		
		table.insert(ignoreList, part)
		params.FilterDescendantsInstances = ignoreList
		
		local distTravelled = (hit.Position - currentOrigin).Magnitude
		local distRemaining = currentDirection.Magnitude - distTravelled
		if distRemaining <= 0 then 
			break 
		end
		
		currentOrigin = hit.Position + currentDirection.Unit * SURFACE_OFFSET
		currentDirection = currentDirection.Unit * distRemaining
	end
	
	return nil
end

return Raycast
