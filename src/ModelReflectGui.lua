
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
				Text = "<i>Click a plane to reflect a copy of the selection across it.</i>",
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
			SelectAfterReflecting = e(Checkbox, {
				Label = "Select reflected copy",
				Checked = props.Settings.SelectReflectedCopy,
				Changed = function(newValue: boolean)
					props.Settings.SelectReflectedCopy = newValue
					props.UpdatedSettings()
				end,
				LayoutOrder = 2,
			}),
			CloseAfterReflecting = e(Checkbox, {
				Label = "Keep open after reflecting",
				Checked = props.Settings.KeepOpenAfterReflecting,
				Changed = function(newValue: boolean)
					props.Settings.KeepOpenAfterReflecting = newValue
					props.UpdatedSettings()
				end,
				LayoutOrder = 3,
			}),
			Buttons = e("Frame", {
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 4,
				BackgroundTransparency = 1,
			}, {
				ListLayout = e("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 4),
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
		}, {
			ListLayout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			FlipX = e(EqualSizedOperationButton, {
				Text = "Flip X",
				Color = Color3.new(0.6, 0.1, 0.1),
				Height = 36,
				OnClick = function()
					props.HandleAction("flipX")
				end,
				LayoutOrder = 1,
			}),
			FlipY = e(EqualSizedOperationButton, {
				Text = "Flip Y",
				Color = Color3.new(0.1, 0.6, 0.1),
				Height = 36,
				OnClick = function()
					props.HandleAction("flipY")
				end,
				LayoutOrder = 2,
			}),
			FlipZ = e(EqualSizedOperationButton, {
				Text = "Flip Z",
				Color = Color3.new(0.1, 0.1, 0.6),
				Height = 36,
				OnClick = function()
					props.HandleAction("flipZ")
				end,
				LayoutOrder = 3,
			}),
		}),
		KeepOpenAfterFlipping = e(Checkbox, {
			LayoutOrder = 4,
			Label = "Keep open after flipping",
			Checked = props.Settings.KeepOpenAfterFlipping,
			Changed = function(newValue: boolean)
				props.Settings.KeepOpenAfterFlipping = newValue
				props.UpdatedSettings()
			end,
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
	}, {
		CutoffDelay = e(NumberInput, {
			Label = "Fail after",
			Unit = "seconds",
			Value = props.Settings.CutoffDelay,
			ValueEntered = function(newValue: number)
				props.Settings.CutoffDelay = newValue
			end,
			LayoutOrder = 1,
		}),
	})
end

local MODEL_REFLECT_CONFIG: PluginGuiTypes.PluginGuiConfig = {
	PluginName = "Model Reflect",
	PendingText = "Select at least one Part, Model, or Folder to duplicate.\nThen drag the handles to add or configure duplicates and hit Place to confirm.",
	TutorialElement = nil,
}

local function ModelReflectGui(props: {
	GuiState: PluginGuiTypes.PluginGuiMode,
	CurrentSettings: Settings.ModelReflectSettings,
	UpdatedSettings: () -> (),
	HandleAction: (string) -> (),
	Panelized: boolean,
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
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
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
	})
end

return ModelReflectGui
