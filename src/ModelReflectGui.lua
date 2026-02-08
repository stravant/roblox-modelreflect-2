
local Plugin = script.Parent.Parent
local Packages = Plugin.Packages
local React = require(Packages.React)

local Colors = require("./PluginGui/Colors")
local HelpGui = require("./PluginGui/HelpGui")
local SubPanel = require("./PluginGui/SubPanel")
local NumberInput = require("./PluginGui/NumberInput")
local Checkbox = require("./PluginGui/Checkbox")
local PluginGui = require("./PluginGui/PluginGui")
local OperationButton = require("./PluginGui/OperationButton")
local Settings = require("./Settings")
local PluginGuiTypes = require("./PluginGui/Types")

local e = React.createElement

local function createNextOrder()
	local order = 0
	return function()
		order += 1
		return order
	end
end

local function OperationPanel(props: {
	Settings: Settings.ModelReflectSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Reflect copy over world plane",
		LayoutOrder = props.LayoutOrder,
	}, {
		Main = e("Frame", {
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, {
			ListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			Text = e("TextLabel", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 0,
				BackgroundColor3 = Colors.GREY,
				BorderSizePixel = 0,
				Font = Enum.Font.SourceSans,
				TextSize = 18,
				TextColor3 = Colors.WHITE,
				RichText = true,
				Text = "<i>Click on a surface to create a copy of the selection that is reflected over that surface.</i>",
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				LayoutOrder = 1,
			}, {
				Padding = e("UIPadding", {
					PaddingTop = UDim.new(0, 2),
					PaddingBottom = UDim.new(0, 2),
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),
			SelectAfterReflecting = e(HelpGui.WithHelpIcon, {
				LayoutOrder = 2,
				Subject = e(Checkbox, {
					Label = "Select reflected copy",
					Checked = props.Settings.SelectReflectedCopy,
					Changed = function(newValue: boolean)
						props.Settings.SelectReflectedCopy = newValue
						props.UpdatedSettings()
					end,
				}),
				Help = e(HelpGui.BasicTooltip, {
					HelpRichText = "Should the newly reflected copy be selected or should the original be left selected?",
				}),
			}),
			CloseAfterReflecting = e(HelpGui.WithHelpIcon, {
				LayoutOrder = 3,
				Subject = e(Checkbox, {
					Label = "Keep open after reflecting",
					Checked = props.Settings.KeepOpenAfterReflecting,
					Changed = function(newValue: boolean)
						props.Settings.KeepOpenAfterReflecting = newValue
						props.UpdatedSettings()
					end,
				}),
				Help = e(HelpGui.BasicTooltip, {
					HelpRichText = "Should the <i>Model Reflect</i> window stay open after reflecting a copy over a plane, or close automatically?",
				}),
			}),
		}),
	})
end

local function EqualSizedOperationButton(props: {
	Text: string,
	SubText: string?,
	Height: number,
	Disabled: boolean,
	Color: Color3,
	LayoutOrder: number?,
	OnClick: () -> (),
})
	return e("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		Flex = e("UIFlexItem", {
			FlexMode = Enum.UIFlexMode.Grow,
			GrowRatio = 1,
		}),
		Content = e(OperationButton, {
			Text = props.Text,
			SubText = props.SubText,
			Height = props.Height,
			Disabled = props.Disabled,
			Color = props.Color,
			OnClick = props.OnClick,
		}),
	})
end

local function FlipPanel(props: {
	Settings: Settings.ModelReflectSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Reflect selection on local axis",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 2),
	}, {
		Buttons = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			ListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			FlipX = e(EqualSizedOperationButton, {
				Text = "Flip X",
				Color = Color3.new(0.6, 0.1, 0.1),
				Height = 30,
				OnClick = function()
					props.HandleAction("flipX")
				end,
				LayoutOrder = 1,
			}),
			FlipY = e(EqualSizedOperationButton, {
				Text = "Flip Y",
				Color = Color3.new(0.1, 0.6, 0.1),
				Height = 30,
				OnClick = function()
					props.HandleAction("flipY")
				end,
				LayoutOrder = 2,
			}),
			FlipZ = e(EqualSizedOperationButton, {
				Text = "Flip Z",
				Color = Color3.new(0.1, 0.1, 0.6),
				Height = 30,
				OnClick = function()
					props.HandleAction("flipZ")
				end,
				LayoutOrder = 3,
			}),
		}),
		KeepOpenAfterFlipping = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 2,
			Subject = e(Checkbox, {
				Label = "Keep open after flipping",
				Checked = props.Settings.KeepOpenAfterFlipping,
				Changed = function(newValue: boolean)
					props.Settings.KeepOpenAfterFlipping = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Should the <i>Model Reflect</i> window stay open after flipping the selection over a local axis, or close automatically?",
			}),
		}),
	})
end

local function AdvancedPanel(props: {
	Settings: Settings.ModelReflectSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	LayoutOrder: number?,
})
	return e(SubPanel, {
		Title = "Advanced",
		LayoutOrder = props.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, {
		CutoffDelay = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 1,
			Subject = e(NumberInput, {
				Label = "Fail after",
				Unit = "seconds",
				Value = props.Settings.CutoffDelay,
				ValueEntered = function(newValue: number)
					props.Settings.CutoffDelay = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "To avoid Studio hanging, give up on reflecting a complex selection after this amount of time.",
			}),
		}),
		MaxUnionDepth = e(HelpGui.WithHelpIcon, {
			LayoutOrder = 2,
			Subject = e(NumberInput, {
				Label = "Max Union depth",
				Value = props.Settings.MaxUnionDepth,
				ValueEntered = function(newValue: number)
					props.Settings.MaxUnionDepth = newValue
					props.UpdatedSettings()
				end,
			}),
			Help = e(HelpGui.BasicTooltip, {
				HelpRichText = "Ignore unions nested deeper than this. The plugin doesn't hard fail when passing this limit because some large models may have one very deep branch in them but otherwise succeed.",
			}),
		}),
	})
end

local function ErrorDisplay(props: {
	Message: string,
	IsWarning: boolean,
	LayoutOrder: number?,
})
	local messageColor = if props.IsWarning then Colors.WARNING_YELLOW else Colors.DARK_RED
	local flashOnChange = function(textLabel: TextLabel)
		if not textLabel then
			return
		end
		local flashTask = task.spawn(function()
			for i = 1, 4 do
				task.wait(0.2)
				textLabel.TextColor3 = Colors.WHITE
				task.wait(0.2)
				textLabel.TextColor3 = messageColor
			end
		end)
		return function()
			textLabel.TextColor3 = messageColor
			task.cancel(flashTask)
		end
	end
	return props.Message and e("Frame", {
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Label = e("TextLabel", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = props.Message,
			TextColor3 = messageColor,
			Font = Enum.Font.SourceSansBold,
			TextSize = 18,
			BackgroundTransparency = 1,
			RichText = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ref = flashOnChange,
		}),
	})
end

local MODEL_REFLECT_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "Model Reflect",
	PendingText = "Select at least one Part, Model, or Folder to reflect.\nThen select a plane to reflect a copy of that geometry over.",
	TutorialElement = nil,
}

local function ModelReflectGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CurrentSettings: Settings.ModelReflectSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
	ErrorMessage: string?,
	IsWarning: boolean,
})
	local nextOrder = createNextOrder()
	return e(PluginGui, {
		Config = MODEL_REFLECT_CONFIG,
		State = {
			Mode = props.GuiState,
			Settings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			Panelized = props.Panelized,
		},
	}, {
		CancelButtonPadding = e("Frame", {
			Size = UDim2.fromScale(1, 0),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			CancelButton = e(OperationButton, {
				Text = "Close <i>Model Reflect</i>",
				Color = Colors.DARK_RED,
				Disabled = false,
				Height = 34,
				OnClick = function()
					props.HandleAction("cancel")
				end,
				LayoutOrder = nextOrder(),
			}),
		}),
		OperationPanel = e(OperationPanel, {
			Settings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
		FlipPanel = e(FlipPanel, {
			Settings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
		AdvancedPanel = e(AdvancedPanel, {
			Settings = props.CurrentSettings,
			UpdatedSettings = props.UpdatedSettings,
			HandleAction = props.HandleAction,
			LayoutOrder = nextOrder(),
		}),
		ErrorMessageDisplay = e(ErrorDisplay, {
			Message = props.ErrorMessage,
			IsWarning = props.IsWarning,
			LayoutOrder = nextOrder(),
		}),
	})
end

return ModelReflectGui
