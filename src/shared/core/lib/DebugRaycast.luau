--[[ File Info

	Author(s): ChiefWildin
	Module: DebugRaycast.lua
	Version: 1.0.0

]]

-- Services

local Debris = game:GetService("Debris")

-- Module Declaration

local DebugRaycast = {}

-- Constants

local DEFAULT_HIT_COLOR = Color3.fromRGB(0, 255, 0)
local DEFAULT_MISS_COLOR = Color3.fromRGB(255, 0, 0)

-- Global Variables

local Container: Folder?

-- Private Functions

local function GetContainer()
	if not Container then
		Container = Instance.new("Folder")
		Container.Name = "DebugRaycast"
		Container.Parent = workspace
	end

	return Container
end

local function CreateDebugPart(
	color: Color3,
	cframe: CFrame,
	size: Vector3,
	shape: Enum.PartType,
	transparency: number?,
	duration: number?
)
	local debugPart = Instance.new("Part")
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.CastShadow = false
	debugPart.Color = color
	debugPart.Material = Enum.Material.Neon
	debugPart.CFrame = cframe
	debugPart.Shape = shape
	debugPart.Size = size
	debugPart.Transparency = transparency or 0.5
	debugPart.Parent = GetContainer()

	if duration then
		Debris:AddItem(debugPart, duration)
	end

	return debugPart
end

-- local function CreateDebugMeshPart(color: Color3, cframe: CFrame, transparency: number?, duration: number?)
-- 	local debugPart = Instance.new("MeshPart")
-- 	debugPart.Anchored = true
-- 	debugPart.CanCollide = false
-- 	debugPart.CanQuery = false
-- 	debugPart.CanTouch = false
-- 	debugPart.CastShadow = false
-- 	debugPart.Color = color
-- 	debugPart.Material = Enum.Material.Neon
-- 	debugPart.CFrame = cframe
-- 	debugPart.Size = Vector3.new(1, 1, 1)
-- 	debugPart.Transparency = transparency or 0.5
-- 	debugPart.Parent = GetContainer()

-- 	if duration then
-- 		Debris:AddItem(debugPart, duration)
-- 	end

-- 	return debugPart
-- end

-- Public Functions

function DebugRaycast:Spherecast(
	position: Vector3,
	radius: number,
	direction: Vector3,
	params: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	transparency: number?,
	duration: number?
)
	local raycastResult = workspace:Spherecast(position, radius, direction, params)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or position + direction

	-- Start
	CreateDebugPart(
		color,
		CFrame.new(position),
		Vector3.new(radius * 2, radius * 2, radius * 2),
		Enum.PartType.Ball,
		transparency,
		duration
	)
	-- Middle
	CreateDebugPart(
		color,
		CFrame.new(position:Lerp(endPos, 0.5))
			* CFrame.new(position, endPos).Rotation
			* CFrame.Angles(0, math.pi / 2, 0),
		Vector3.new((position - endPos).Magnitude, radius * 2, radius * 2),
		Enum.PartType.Cylinder,
		transparency,
		duration
	)
	-- End
	CreateDebugPart(
		color,
		CFrame.new(endPos),
		Vector3.new(radius * 2, radius * 2, radius * 2),
		Enum.PartType.Ball,
		transparency,
		duration
	)

	return raycastResult
end

function DebugRaycast:Blockcast(
	cframe: CFrame,
	size: Vector3,
	direction: Vector3,
	params: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	transparency: number?,
	duration: number?
)
	local raycastResult = workspace:Blockcast(cframe, size, direction, params)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or cframe.Position + direction

	CreateDebugPart(
		color,
		CFrame.new(cframe.Position:Lerp(endPos, 0.5)) * CFrame.new(cframe.Position, endPos).Rotation,
		Vector3.new(size.X, size.Y, (cframe.Position - endPos).Magnitude),
		Enum.PartType.Block,
		transparency,
		duration
	)
	-- local meshPart = CreateDebugMeshPart(
	-- 	color,
	-- 	CFrame.new(cframe.Position:Lerp(endPos, 0.5)) * CFrame.new(cframe.Position, endPos).Rotation,
	-- 	transparency,
	-- 	duration
	-- )
	-- local x = size.X / 2
	-- local y = size.Y / 2
	-- local z = (cframe.Position - endPos).Magnitude / 2
	-- local editableMesh = Instance.new("EditableMesh")

	-- -- Vertex setup
	-- local first = editableMesh:AddVertex(Vector3.new(-x, y, -z))
	-- local second = editableMesh:AddVertex(Vector3.new(x, y, -z))
	-- local third = editableMesh:AddVertex(Vector3.new(-x, y, z))
	-- local fourth = editableMesh:AddVertex(Vector3.new(x, y, z))
	-- local fifth = editableMesh:AddVertex(Vector3.new(-x, -y, -z))
	-- local sixth = editableMesh:AddVertex(Vector3.new(x, -y, -z))
	-- local seventh = editableMesh:AddVertex(Vector3.new(-x, -y, z))
	-- local eighth = editableMesh:AddVertex(Vector3.new(x, -y, z))

	-- -- Correct vertex normals
	-- for _, vertex in pairs(editableMesh:GetVertices()) do
	-- 	editableMesh:SetVertexNormal(vertex, editableMesh:GetPosition(vertex).Unit)
	-- end

	-- -- Draw faces
	-- editableMesh:AddTriangle(first, second, third)
	-- editableMesh:AddTriangle(second, fourth, third)

	-- editableMesh:AddTriangle(first, fifth, second)
	-- editableMesh:AddTriangle(second, fifth, sixth)

	-- editableMesh:AddTriangle(second, fourth, sixth)
	-- editableMesh:AddTriangle(sixth, fourth, eighth)

	-- editableMesh:AddTriangle(first, third, fifth)
	-- editableMesh:AddTriangle(third, seventh, fifth)

	-- editableMesh:AddTriangle(third, fourth, seventh)
	-- editableMesh:AddTriangle(fourth, eighth, seventh)

	-- editableMesh:AddTriangle(fifth, seventh, sixth)
	-- editableMesh:AddTriangle(seventh, eighth, sixth)

	-- editableMesh.Parent = meshPart

	return raycastResult
end

function DebugRaycast:Raycast(
	origin: Vector3,
	direction: Vector3,
	raycastParams: RaycastParams?,
	hitColor: Color3?,
	missColor: Color3?,
	thickness: number?,
	transparency: number?,
	duration: number?
): RaycastResult?
	local raycastResult = workspace:Raycast(origin, direction, raycastParams)
	hitColor = hitColor or DEFAULT_HIT_COLOR
	missColor = missColor or DEFAULT_MISS_COLOR
	local color = raycastResult and hitColor or missColor
	local endPos = raycastResult and raycastResult.Position or origin + direction

	CreateDebugPart(
		color,
		CFrame.new(origin:Lerp(endPos, 0.5)) * CFrame.new(origin, endPos).Rotation,
		Vector3.new(thickness, thickness, (origin - endPos).Magnitude),
		Enum.PartType.Block,
		transparency,
		duration
	)

	return raycastResult
end

return DebugRaycast
