--[[ FILE

    Author: TactBacon, ChiefWildin
    Module: Sounds.lua
    Version: 2.0.0

]]

-- Services

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

-- Dependencies

-- local WarningTimer = shared("WarningTimer") ---@module WarningTimer

-- Module Declaration

local Sounds = {}

-- Global Variables

local EmittersCache: { [string]: AudioEmitter } = {}
local SoundsCache: { [string]: AudioPlayer } = {}

-- Objects

local SoundContainer = Instance.new("Folder")
if not RunService:IsRunning() then
	SoundContainer:Destroy()
else
	SoundContainer.Name = "SoundContainer"
	SoundContainer.Archivable = false
	SoundContainer.Parent = workspace
end

local SoundInstances = Instance.new("Folder")
if not RunService:IsRunning() then
	SoundInstances:Destroy()
else
	SoundInstances.Name = "SoundInstances" .. (RunService:IsServer() and "Server" or "Client")
	SoundInstances.Archivable = false
	SoundInstances.Parent = SoundService
end

local RandomObj = Random.new()

-- Public Functions

function Sounds:GetEmitter(emitterType: string): AudioEmitter?
	if EmittersCache[emitterType] then
		return EmittersCache[emitterType]
	end

	local emitter = SoundService.Audio.Emitters:FindFirstChild(emitterType, true)
	if emitter and emitter:IsA("AudioEmitter") then
		EmittersCache[emitterType] = emitter
		return emitter
	end

	return nil
end

function Sounds:GetSound(soundName: string): AudioPlayer?
	local sound = SoundsCache[soundName]
	if sound then
		return sound
	end

	SoundsCache[soundName] = SoundService:FindFirstChild(soundName, true)

	return SoundsCache[soundName]
end

function Sounds:PlayExistingSound(sound: AudioPlayer, varyPitch: number?, duration: number?): AudioPlayer
	if varyPitch or duration then
		sound.AutoLoad = true

		if not sound:GetAttribute("OriginalPlaybackSpeed") then
			sound:SetAttribute("OriginalPlaybackSpeed", sound.PlaybackSpeed)
		end

		-- if not sound.IsReady then
		-- 	if not sound:GetAttribute("Warned") then
		-- 		local loadWarning = WarningTimer.new(15, "Sound failed to load - " .. tostring(sound.Asset))
		-- 		while not sound.IsReady and loadWarning:IsAlive() do
		-- 			task.wait(0.1)
		-- 		end
		-- 		loadWarning:Stop()
		-- 	else
		-- 		local start = tick()
		-- 		while not sound.IsReady and tick() - start < 15 do
		-- 			task.wait(0.1)
		-- 		end
		-- 	end
		-- end
		local start = tick()
		while not sound.IsReady and tick() - start < 15 do
			task.wait(0.1)
		end

		-- if it didn't load, don't mess with it
		if not sound.IsReady then
			sound:SetAttribute("Warned", true)
			return sound
		end

		local pitch = varyPitch or 0
		sound.PlaybackSpeed = (sound.TimeLength / (duration or sound.TimeLength))
				* sound:GetAttribute("OriginalPlaybackSpeed")
			+ RandomObj:NextNumber(-pitch, pitch)
	end

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()

	return sound
end

function Sounds:PlaySound(
	soundName: string,
	shouldClone: boolean?,
	position: (Vector3 | BasePart)?,
	varyPitch: number?,
	duration: number?,
	emitterType: string?
): AudioPlayer?
	if not RunService:IsRunning() then
		return
	end

	local sound = self:GetSound(soundName)
	if not sound then
		warn("Could not find sound: " .. soundName)
		return
	end

	if shouldClone or position then
		local originalSound = sound

		sound = Instance.new("AudioPlayer")
		sound.Name = originalSound.Name
		sound.Asset = originalSound.Asset
		sound.Volume = originalSound.Volume
		sound.PlaybackSpeed = originalSound.PlaybackSpeed
		sound.Looping = originalSound.Looping
		sound:SetAttribute(
			"OriginalPlaybackSpeed",
			originalSound:GetAttribute("OriginalPlaybackSpeed") or sound.PlaybackSpeed
		)

		local wire = Instance.new("Wire")
		wire.SourceInstance = sound
		wire.Parent = sound

		local soundAdornee: Part?
		local emitter: AudioEmitter?
		if not position then
			local originalWire = originalSound:FindFirstChildWhichIsA("Wire")
			wire.TargetInstance = if originalWire
				then originalWire.TargetInstance
				else SoundService.Audio.Effects.Master_Fader
			sound.Parent = SoundInstances
		else
			if emitterType then
				emitter = self:GetEmitter(emitterType)
				if emitter then
					emitter = emitter:Clone()
				else
					warn(`Emitter type {emitterType} not found for sound {soundName}, using default instead`)
				end
			end
			if not emitter then
				emitter = Instance.new("AudioEmitter")
			end
			emitter.Name = soundName .. "_Emitter"

			wire.TargetInstance = emitter

			if typeof(position) == "Instance" then
				emitter.Parent = position
			else
				soundAdornee = Instance.new("Part")
				soundAdornee.CFrame = CFrame.new(position)
				soundAdornee.CanCollide = false
				soundAdornee.CanTouch = false
				soundAdornee.CanQuery = false
				soundAdornee.AudioCanCollide = false
				soundAdornee.Transparency = 1
				soundAdornee.Anchored = true
				soundAdornee.Size = Vector3.one
				soundAdornee.Parent = SoundContainer
				emitter.Parent = soundAdornee
				sound.Parent = soundAdornee
			end
		end

		if varyPitch or duration then
			task.spawn(function()
				while not sound.IsReady do
					sound.AutoLoad = true
					sound:GetPropertyChangedSignal("IsReady"):Wait()
				end

				local pitch = varyPitch or 0
				sound.PlaybackSpeed = (sound.TimeLength / (duration or sound.TimeLength))
						* sound:GetAttribute("OriginalPlaybackSpeed")
					+ RandomObj:NextNumber(-pitch, pitch)
			end)
		end

		sound.Ended:Connect(function()
			sound:Destroy()
			if emitter then
				emitter:Destroy()
			end
			if soundAdornee then
				soundAdornee:Destroy()
			end
		end)
	end

	sound:Stop()
	sound.TimePosition = 0
	sound:Play()

	return sound
end

return Sounds
