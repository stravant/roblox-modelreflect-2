local InitialPosition = Vector2.new(24, 24)
local kSettingsKey = "redupeState"

local PluginGuiTypes = require("./PluginGui/Types")

export type ModelReflectSettings = PluginGuiTypes.PluginGuiSettings & {
	SelectReflectedCopy: boolean,
	KeepOpenAfterReflecting: boolean,
	KeepOpenAfterFlipping: boolean,
}

local function loadSettings(plugin: Plugin): ModelReflectSettings
	-- Placeholder for loading state logic
	local raw = plugin:GetSetting(kSettingsKey) or {}
	return {
		WindowPosition = Vector2.new(
			raw.WindowPositionX or InitialPosition.X,
			raw.WindowPositionY or InitialPosition.Y
		),
		WindowAnchor = Vector2.new(
			raw.WindowAnchorX or 0,
			raw.WindowAnchorY or 0
		),
		WindowHeightDelta = if raw.WindowHeightDelta ~= nil then raw.WindowHeightDelta else 0,
		DoneTutorial = if raw.DoneTutorial ~= nil then raw.DoneTutorial else false,
		HaveHelp = if raw.HaveHelp ~= nil then raw.HaveHelp else true,

		----

		SelectReflectedCopy = if raw.SelectReflectedCopy ~= nil then raw.SelectReflectedCopy else true,
		KeepOpenAfterReflecting = if raw.KeepOpenAfterReflecting ~= nil then raw.KeepOpenAfterReflecting else false,
		KeepOpenAfterFlipping = if raw.KeepOpenAfterFlipping ~= nil then raw.KeepOpenAfterFlipping else true,
	}
end
local function saveSettings(plugin: Plugin, settings: ModelReflectSettings)
	-- Placeholder for saving state logic
	plugin:SetSetting(kSettingsKey, {
		WindowPositionX = settings.WindowPosition.X,
		WindowPositionY = settings.WindowPosition.Y,
		WindowAnchorX = settings.WindowAnchor.X,
		WindowAnchorY = settings.WindowAnchor.Y,
		WindowHeightDelta = settings.WindowHeightDelta,
		DoneTutorial = settings.DoneTutorial,
		HaveHelp = settings.HaveHelp,

		----

		SelectReflectedCopy = settings.SelectReflectedCopy,
		KeepOpenAfterReflecting = settings.KeepOpenAfterReflecting,
		KeepOpenAfterFlipping = settings.KeepOpenAfterFlipping,
	})
end

return {
	Load = loadSettings,
	Save = saveSettings,
}