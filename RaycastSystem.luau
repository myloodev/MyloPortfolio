local Workspace = game:GetService("Workspace")

export type CastOptions = {
	Character: Model?,
	IgnoreList: { Instance }?,
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

local function IsAccessory(part: BasePart): boolean
	local accessory = part:FindFirstAncestorOfClass("Accessory")

	return accessory ~= nil
end

local function ShouldIgnore(part: BasePart, options: CastOptions): boolean
	if options.IgnoreAccessories and IsAccessory(part) then
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

local function CreateIgnoreList(options: CastOptions): { Instance }
	local ignore = {}

	if options.IgnoreList then
		table.move(options.IgnoreList, 1, #options.IgnoreList, 1, ignore)
	end

	if options.Character then
		table.insert(ignore, options.Character)
	end

	return ignore
end

local function CreateParams(ignore: { Instance }, options: CastOptions): RaycastParams
	local params = RaycastParams.new()

	params.FilterType = options.FilterType or Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = options.IgnoreWater ~= false

	return params
end

local function CreateResult(origin: Vector3, result: RaycastResult): CastResult
	return {
		Instance = result.Instance,
		Position = result.Position,
		Normal = result.Normal,
		Material = result.Material,
		Distance = (result.Position - origin).Magnitude,
		Result = result,
	}
end

function Raycast.Cast(
	origin: Vector3,
	direction: Vector3,
	radius: number,
	options: CastOptions?
): CastResult?
	options = options or {}

	local ignore = CreateIgnoreList(options)
	local params = CreateParams(ignore, options)

	local currentOrigin = origin
	local currentDirection = direction
	local maxPenetrations = options.MaxPenetrations or DEFAULT_MAX_PENETRATIONS

	for _ = 1, maxPenetrations do
		local result = Workspace:Spherecast(
			currentOrigin,
			radius,
			currentDirection,
			params
		)

		if not result then
			return nil
		end

		local part = result.Instance

		if not part or not part:IsA("BasePart") then
			return nil
		end

		if not ShouldIgnore(part, options) then
			return CreateResult(origin, result)
		end

		table.insert(ignore, part)

		local travelled = (result.Position - currentOrigin).Magnitude
		local remaining = currentDirection.Magnitude - travelled

		if remaining <= 0 then
			return nil
		end

		currentOrigin = result.Position + currentDirection.Unit * SURFACE_OFFSET
		currentDirection = currentDirection.Unit * remaining
	end

	return nil
end

return Raycast
