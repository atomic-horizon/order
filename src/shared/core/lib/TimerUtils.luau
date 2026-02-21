--[[ File Info

	Author(s): ChiefWildin
	Module: TimerUtils.luau
	Version: 1.0.0

]]

-- Services

-- Dependencies

-- Types

-- Module Declaration

local TimerUtils = {}

-- Constants

-- Global Variables

-- Objects

-- Private Functions

-- Public Functions

function TimerUtils:TimeToNextSignificantUpdate(timeRemaining: number): number
	if timeRemaining > 86400 then
		return timeRemaining % 86400
	elseif timeRemaining > 3600 then
		return timeRemaining % 3600
	elseif timeRemaining > 60 then
		return timeRemaining % 60
	end

	return 1
end

function TimerUtils:GetStringForTimeRemaining(timeRemaining: number): string
	timeRemaining = math.round(timeRemaining)

	if timeRemaining > 86400 then
		local days = math.round(timeRemaining / 86400)
		return `{days}D`
	elseif timeRemaining > 3600 then
		local hours = timeRemaining // 3600
		local minutes = (timeRemaining % 3600) // 60
		return `{hours}H {minutes}M`
	elseif timeRemaining > 60 then
		local minutes = timeRemaining // 60
		local seconds = timeRemaining % 60
		return `{minutes}M {seconds}S`
	else
		return `{timeRemaining}S`
	end
end

return TimerUtils
