-- Retrieves GuiTemplates
-- @module GuiTemplates
-- @author Quenty

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TemplateProvider = shared("TemplateProvider") ---@module TemplateProvider

local provider = TemplateProvider.new(ReplicatedStorage.GuiTemplates)

provider:Provide()

return provider
