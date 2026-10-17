-- Tiny helpers for building scale-based UI from code.
local Ui = {}

Ui.Colors = {
	Panel = Color3.fromRGB(28, 26, 40),
	Accent = Color3.fromRGB(255, 205, 70),
	Good = Color3.fromRGB(90, 200, 120),
	Muted = Color3.fromRGB(90, 88, 110),
	Text = Color3.new(1, 1, 1),
}

function Ui.make(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Ui.corner(scale: number?): UICorner
	return Ui.make("UICorner", { CornerRadius = UDim.new(scale or 0.2, 0) })
end

function Ui.label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		AutoLocalize = false,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextLabel", defaults)
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		AutoLocalize = false,
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Ui.Colors.Text,
		BackgroundColor3 = Ui.Colors.Good,
		AutoButtonColor = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = Ui.make("TextButton", defaults)
	Ui.corner(0.25).Parent = button
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0.05, 0),
		PaddingRight = UDim.new(0.05, 0),
		PaddingTop = UDim.new(0.12, 0),
		PaddingBottom = UDim.new(0.12, 0),
		Parent = button,
	})
	return button
end

function Ui.screen(name: string, order: number): ScreenGui
	return Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
end

return Ui
