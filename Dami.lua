local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local Theme = {
	Background = Color3.fromRGB(15, 15, 15),
	Panel      = Color3.fromRGB(20, 20, 20),
	Elevated   = Color3.fromRGB(27, 27, 27),
	Stroke     = Color3.fromRGB(42, 42, 42),
	Accent     = Color3.fromRGB(140, 20, 20),
	AccentDim  = Color3.fromRGB(80, 15, 15),
	Text       = Color3.fromRGB(230, 230, 230),
	SubText    = Color3.fromRGB(140, 140, 140),

	TitleFont     = Enum.Font.GrenzeGotisch,
	BodyFont       = Enum.Font.Gotham,
	BodyFontMedium = Enum.Font.GothamSemibold,
	BodyFontBold   = Enum.Font.GothamBold,
}

local ThemeRegistry = {}

local function themed(instance, property, keyOrFunc)
	if type(keyOrFunc) == "function" then
		keyOrFunc()
		table.insert(ThemeRegistry, {instance = instance, property = property, func = keyOrFunc})
	else
		instance[property] = Theme[keyOrFunc]
		table.insert(ThemeRegistry, {instance = instance, property = property, key = keyOrFunc})
	end
	return instance
end

local function addToolTipToInstance(instance, window, text)
	if tostring(text):gsub(" ", "") ~= "" then
		instance.MouseEnter:Connect(function()
			window:ShowToolTip(text)
		end)
		instance.MouseLeave:Connect(function()
			window:HideToolTip()
		end)
	end
end

local Utility = {}

function Utility.create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		if child then
			child.Parent = inst
		end
	end
	return inst
end

function Utility.corner(radius)
	return Utility.create("UICorner", {CornerRadius = UDim.new(0, radius or 6)})
end

function Utility.pad(all)
	return Utility.create("UIPadding", {
		PaddingTop = UDim.new(0, all), PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all), PaddingRight = UDim.new(0, all),
	})
end

local ActiveTweens = setmetatable({}, {__mode = "k"})

function Utility.tween(inst, props, duration, style, dir, key)
	key = key or "_default"
	local bucket = ActiveTweens[inst]
	if not bucket then
		bucket = {}
		ActiveTweens[inst] = bucket
	end
	if bucket[key] then
		bucket[key]:Cancel()
	end

	local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, info, props)
	bucket[key] = t
	t:Play()
	return t
end

function Utility.hoverGlow(trigger, stroke, options)
	options = options or {}
	local hoverThickness = options.hoverThickness or 1.5
	local restThickness = options.restThickness or 1
	local restKey = options.restKey or "Stroke"

	trigger.MouseEnter:Connect(function()
		Utility.tween(stroke, {Color = Theme.Accent, Thickness = hoverThickness}, 0.15, nil, nil, "glow")
	end)
	trigger.MouseLeave:Connect(function()
		Utility.tween(stroke, {Color = Theme[restKey], Thickness = restThickness}, 0.15, nil, nil, "glow")
	end)
end

local DragRegistry = {}
local dragIdCounter = 0

local function beginDrag(onMove, onEnd)
	dragIdCounter += 1
	local id = dragIdCounter
	DragRegistry[id] = onMove

	local endedConn
	endedConn = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			DragRegistry[id] = nil
			if onEnd then onEnd() end
			endedConn:Disconnect()
		end
	end)

	return id
end

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		for _, onMove in pairs(DragRegistry) do
			onMove(input)
		end
	end
end)

function Utility.drag(handle, target, clampToScreen)
	target = target or handle
	local dragging, dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position

			beginDrag(function(moveInput)
				if not dragging then return end
				local delta = moveInput.Position - dragStart
				local newX = startPos.X.Offset + delta.X
				local newY = startPos.Y.Offset + delta.Y

				if clampToScreen and target.Parent then
					local viewport = workspace.CurrentCamera.ViewportSize
					local size = target.AbsoluteSize
					local minX, minY = -size.X * 0.5, 0
					local maxX, maxY = viewport.X - size.X * 0.5, viewport.Y - 20
					newX = math.clamp(newX, minX, maxX)
					newY = math.clamp(newY, minY, maxY)
				end

				target.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
			end, function()
				dragging = false
			end)
		end
	end)
end

local function card(height)
	local frame = Utility.create("Frame", {
		BackgroundColor3 = Theme.Elevated,
		Size = UDim2.new(1, 0, 0, height or 34),
		BorderSizePixel = 0,
	}, {
		Utility.corner(6),
	})
	themed(frame, "BackgroundColor3", "Elevated")
	local stroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	stroke.Parent = frame
	themed(stroke, "Color", "Stroke")
	Utility.hoverGlow(frame, stroke)
	return frame
end

local Dami = {}
Dami.__index = Dami

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function Dami.new(title)
	local screenGui = Utility.create("ScreenGui", {
		Name = title or "dami",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	if gethui then
		screenGui.Parent = gethui()
	elseif syn and syn.protect_gui then
		syn.protect_gui(screenGui)
		screenGui.Parent = Player:WaitForChild("PlayerGui")
	else
		screenGui.Parent = Player:WaitForChild("PlayerGui")
	end

	local toolTip = Utility.create("Frame", {
		Name = "ToolTip",
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		ZIndex = 100,
		Visible = false,
		Parent = screenGui,
	}, {
		Utility.corner(4),
		Utility.pad(4),
	})
	themed(toolTip, "BackgroundColor3", "Elevated")
	Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1, Transparency = 0.3}, {}).Parent = toolTip
	themed(toolTip.UIStroke, "Color", "Accent")

	local toolTipLabel = Utility.create("TextLabel", {
		Name = "TextLabel",
		Font = Theme.BodyFont,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = toolTip,
	})
	themed(toolTipLabel, "TextColor3", "Text")
	themed(toolTipLabel, "Font", "BodyFont")

	toolTip.AutomaticSize = Enum.AutomaticSize.XY

	local toolTipConn = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local mousePos = UserInputService:GetMouseLocation()
			toolTip.Position = UDim2.new(0, mousePos.X + 12, 0, mousePos.Y + 12)
		end
	end)

	local main = Utility.create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 540, 0, 420),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		Utility.corner(8),
	})
	themed(main, "BackgroundColor3", "Background")
	Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1, Transparency = 0.5}, {}).Parent = main
	themed(main.UIStroke, "Color", "Accent")

	local topBar = Utility.create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		Utility.corner(8),
	})
	themed(topBar, "BackgroundColor3", "Panel")
	Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		Position = UDim2.new(0, 0, 1, -10),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	local avatar = Utility.create("ImageLabel", {
		Name = "Avatar",
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		Image = "",
		Parent = topBar,
	}, {Utility.corner(14)})
	themed(avatar, "BackgroundColor3", "Elevated")

	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and content then
			avatar.Image = content
		end
	end)

	local titleLabel = Utility.create("TextLabel", {
		Text = title or "dami",
		Font = Theme.TitleFont,
		TextSize = 18,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 52, 0, 3),
		Size = UDim2.new(1, -96, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = topBar,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "TitleFont")

	local profileLabel = Utility.create("TextLabel", {
		Name = "ProfileName",
		Text = "@" .. Player.Name,
		Font = Theme.BodyFont,
		TextSize = 11,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 52, 0, 21),
		Size = UDim2.new(1, -96, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = topBar,
	})
	themed(profileLabel, "TextColor3", "SubText")
	themed(profileLabel, "Font", "BodyFont")

	if Player.DisplayName and Player.DisplayName ~= Player.Name then
		profileLabel.Text = Player.DisplayName .. " (@" .. Player.Name .. ")"
	end

	local accentBar = Utility.create("Frame", {
		Size = UDim2.new(0, 3, 1, -12),
		Position = UDim2.new(0, 0, 0, 6),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {Utility.corner(2)})
	themed(accentBar, "BackgroundColor3", "Accent")

	local closeButton = Utility.create("TextButton", {
		Text = "×",
		Font = Theme.BodyFontBold,
		TextSize = 20,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 24, 0, 24),
		ZIndex = 5,
		Parent = topBar,
	})
	themed(closeButton, "TextColor3", "SubText")
	themed(closeButton, "Font", "BodyFontBold")

	closeButton.MouseEnter:Connect(function()
		Utility.tween(closeButton, {TextColor3 = Theme.Accent}, 0.1)
	end)
	closeButton.MouseLeave:Connect(function()
		Utility.tween(closeButton, {TextColor3 = Theme.SubText}, 0.1)
	end)
	closeButton.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	local minimizeButton = Utility.create("TextButton", {
		Text = "-",
		Font = Theme.BodyFontBold,
		TextSize = 20,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -38, 0.5, 0),
		Size = UDim2.new(0, 24, 0, 24),
		ZIndex = 5,
		Parent = topBar,
	})
	themed(minimizeButton, "TextColor3", "SubText")
	themed(minimizeButton, "Font", "BodyFontBold")

	minimizeButton.MouseEnter:Connect(function()
		Utility.tween(minimizeButton, {TextColor3 = Theme.Accent}, 0.1)
	end)
	minimizeButton.MouseLeave:Connect(function()
		Utility.tween(minimizeButton, {TextColor3 = Theme.SubText}, 0.1)
	end)

	Utility.drag(topBar, main)

	local sidebar = Utility.create("Frame", {
		Name = "Sidebar",
		Position = UDim2.new(0, 0, 0, 42),
		Size = UDim2.new(0, 128, 1, -42),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = main,
	})
	themed(sidebar, "BackgroundColor3", "Panel")

	local tabList = Utility.create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}),
		Utility.pad(6),
	})
	themed(tabList, "ScrollBarImageColor3", "Accent")

	local pageContainer = Utility.create("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 128, 0, 42),
		Size = UDim2.new(1, -128, 1, -42),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local originalHeight = 420
	local isMinimizing = false

	local self = setmetatable({
		screenGui = screenGui,
		main = main,
		topBar = topBar,
		tabList = tabList,
		pageContainer = pageContainer,
		tabs = {},
		activeTab = nil,
		flags = {},
		flagSetters = {},
		configName = tostring(title or "dami"):gsub("[^%w_]", "_"),
		minimized = false,
		connections = {},
		toolTip = toolTip,
		toolTipLabel = toolTipLabel,
		notifHolder = Utility.create("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -16),
			Size = UDim2.new(0, 260, 1, -32),
			BackgroundTransparency = 1,
			Parent = screenGui,
		}, {
			Utility.create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 8),
			}),
		}),
	}, Dami)

	self:RegisterConnection(toolTipConn)

	minimizeButton.MouseButton1Click:Connect(function()
		if isMinimizing then return end
		isMinimizing = true

		self.minimized = not self.minimized
		main.ClipsDescendants = true

		local targetHeight = self.minimized and 42 or originalHeight
		if self.minimized then
			sidebar.Visible = false
			pageContainer.Visible = false
		end

		local tween = Utility.tween(main, {Size = UDim2.new(0, 540, 0, targetHeight)}, 0.25)
		tween.Completed:Connect(function()
			isMinimizing = false
			if not self.minimized then
				sidebar.Visible = true
				pageContainer.Visible = true
				main.ClipsDescendants = false
			end
		end)
	end)

	screenGui.Destroying:Connect(function()
		for _, conn in ipairs(self.connections) do
			if conn.Disconnect then
				conn:Disconnect()
			end
		end
		self.connections = {}
	end)

	return self
end

function Dami:RegisterConnection(connection)
	table.insert(self.connections, connection)
end

function Dami:Toggle()
	self.screenGui.Enabled = not self.screenGui.Enabled
end

function Dami:Destroy()
	self.screenGui:Destroy()
end

function Dami:RegisterFlag(name, getDefault, setter)
	if not name or name == "" then return end
	self.flags[name] = getDefault
	self.flagSetters[name] = setter
end

function Dami:SetFlag(name, value)
	if not self.flagSetters[name] then return end
	self.flags[name] = value
	self.flagSetters[name](value)
end

function Dami:GetFlag(name)
	return self.flags[name]
end

function Dami:SaveConfig(configName)
	configName = configName or self.configName
	if not (writefile and isfolder and makefolder) then
		return false, "executor does not support file writes"
	end
	if not isfolder("dami") then
		makefolder("dami")
	end
	local ok, encoded = pcall(function()
		return game:GetService("HttpService"):JSONEncode(self.flags)
	end)
	if not ok then
		return false, "failed to encode config"
	end
	writefile("dami/" .. configName .. ".json", encoded)
	return true
end

function Dami:LoadConfig(configName)
	configName = configName or self.configName
	if not (readfile and isfile) then
		return false, "executor does not support file reads"
	end
	local path = "dami/" .. configName .. ".json"
	if not isfile(path) then
		return false, "no config saved"
	end
	local ok, decoded = pcall(function()
		return game:GetService("HttpService"):JSONDecode(readfile(path))
	end)
	if not ok or type(decoded) ~= "table" then
		return false, "failed to decode config"
	end
	for name, value in pairs(decoded) do
		if self.flagSetters[name] then
			self:SetFlag(name, value)
		end
	end
	return true
end

function Dami:ShowToolTip(text)
	if text and text ~= "" then
		self.toolTipLabel.Text = text
		self.toolTip.Visible = true
	else
		self.toolTip.Visible = false
	end
end

function Dami:HideToolTip()
	self.toolTip.Visible = false
end

function Dami:AddTab(name)
	local button = Utility.create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Elevated,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = self.tabList,
	}, {Utility.corner(6)})

	local indicator = Utility.create("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = button,
	}, {Utility.corner(2)})

	local label = Utility.create("TextLabel", {
		Text = name,
		Font = Theme.BodyFontMedium,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -14, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	})
	themed(label, "Font", "BodyFontMedium")

	local function updateTabStyle()
		local isActive = (self.activeTab == tab)
		label.TextColor3 = isActive and Theme.Text or Theme.SubText
		indicator.BackgroundColor3 = Theme.Accent
	end
	themed(label, "TextColor3", updateTabStyle)

	local pageWrapper = Utility.create("CanvasGroup", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = self.pageContainer,
	})

	local page = Utility.create("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pageWrapper,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)}),
	})
	themed(page, "ScrollBarImageColor3", "Accent")

	local tab = setmetatable({
		window = self,
		button = button,
		label = label,
		indicator = indicator,
		page = page,
		pageWrapper = pageWrapper,
		sections = {},
	}, Tab)

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.tabs, tab)

	if not self.activeTab then
		self:SelectTab(tab)
	end

	return tab
end

local SECTION_PAD_TOP = 12
local SECTION_PAD_TOP_START = SECTION_PAD_TOP + 18

local function revealSection(section, index)
	local container = section.container
	task.delay((index - 1) * 0.05, function()
		if container and container.Parent then
			Utility.tween(container, {GroupTransparency = 0}, 0.2)
			if container:FindFirstChildOfClass("UIPadding") then
				Utility.tween(container.UIPadding, {PaddingTop = UDim.new(0, SECTION_PAD_TOP)}, 0.25)
			end
		end
	end)
end

local function revealAllSections(tab)
	for i, section in ipairs(tab.sections) do
		revealSection(section, i)
	end
end

local function hideAllSectionsInstant(tab)
	for _, section in ipairs(tab.sections) do
		local container = section.container
		if container and container.Parent then
			container.GroupTransparency = 1
			if container:FindFirstChildOfClass("UIPadding") then
				container.UIPadding.PaddingTop = UDim.new(0, SECTION_PAD_TOP_START)
			end
		end
	end
end

function Dami:SelectTab(tab)
	if self.activeTab == tab then return end

	if self.activeTab then
		local old = self.activeTab
		Utility.tween(old.label, {TextColor3 = Theme.SubText}, 0.15)
		Utility.tween(old.indicator, {Size = UDim2.new(0, 3, 0, 0)}, 0.15)
		Utility.tween(old.pageWrapper, {GroupTransparency = 1}, 0.15)
		task.delay(0.15, function()
			if self.activeTab ~= old then
				old.pageWrapper.Visible = false
				hideAllSectionsInstant(old)
			end
		end)
	end

	Utility.tween(tab.label, {TextColor3 = Theme.Text}, 0.15)
	Utility.tween(tab.indicator, {Size = UDim2.new(0, 3, 0, 20)}, 0.15)
	tab.pageWrapper.Visible = true
	Utility.tween(tab.pageWrapper, {GroupTransparency = 0}, 0.15)
	revealAllSections(tab)

	self.activeTab = tab
end

function Dami:SetTheme(newTheme)
	for key, value in pairs(newTheme) do
		Theme[key] = value
	end
	local activeRegistry = {}
	for _, entry in ipairs(ThemeRegistry) do
		if entry.instance and entry.instance.Parent then
			table.insert(activeRegistry, entry)
			if entry.func then
				entry.func()
			elseif entry.property == "Font" then
				entry.instance.Font = Theme[entry.key]
			else
				Utility.tween(entry.instance, {[entry.property] = Theme[entry.key]}, 0.25)
			end
		end
	end
	ThemeRegistry = activeRegistry
end

function Dami:Notify(title, text, duration)
	duration = duration or 3.5

	local notif = Utility.create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.notifHolder,
	}, {
		Utility.corner(6),
		Utility.create("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 0),
			PaddingRight = UDim.new(0, 10),
		}),
	})
	themed(notif, "BackgroundColor3", "Elevated")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = notif
	themed(notif.UIStroke, "Color", "Stroke")

	Utility.create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = notif,
	}, {Utility.corner(2)})

	local titleLabel = Utility.create("TextLabel", {
		Text = title,
		Font = Theme.BodyFontBold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(1, -14, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notif,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontBold")

	local descLabel = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 18),
		Size = UDim2.new(1, -14, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = notif,
	})
	themed(descLabel, "TextColor3", "SubText")
	themed(descLabel, "Font", "BodyFont")

	notif.Position = UDim2.new(0, 40, 0, 0)
	Utility.tween(notif, {Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0}, 0.25)

	task.delay(duration, function()
		if notif and notif.Parent then
			Utility.tween(notif, {Position = UDim2.new(0, 40, 0, 0), GroupTransparency = 1}, 0.2)
			task.wait(0.2)
			notif:Destroy()
		end
	end)
end

function Tab:AddSection(name)
	local container = Utility.create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.page,
	}, {
		Utility.corner(8),
		Utility.pad(12),
	})
	themed(container, "BackgroundColor3", "Panel")
	container.UIPadding.PaddingTop = UDim.new(0, SECTION_PAD_TOP_START)

	local layout = Utility.create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	layout.Parent = container

	local sectionLabel = Utility.create("TextLabel", {
		Text = name,
		Font = Theme.BodyFontBold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = container,
	})
	themed(sectionLabel, "TextColor3", "Text")
	themed(sectionLabel, "Font", "BodyFontBold")

	local section = setmetatable({tab = self, container = container}, Section)
	table.insert(self.sections, section)

	if self.window.activeTab == self then
		revealSection(section, #self.sections)
	end

	return section
end

function Section:AddButton(text, callback)
	local section = self
	local btn = card(34)
	btn.Parent = section.container

	local click = Utility.create("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 5,
		Parent = btn,
	})

	local label = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFontMedium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = btn,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	click.MouseButton1Click:Connect(function()
		Utility.tween(btn, {BackgroundColor3 = Theme.AccentDim}, 0.1)
		task.delay(0.1, function()
			Utility.tween(btn, {BackgroundColor3 = Theme.Elevated}, 0.15)
		end)
		if callback then callback() end
	end)

	local api = {instance = btn}
	function api:AddToolTip(text)
		addToolTipToInstance(btn, section.tab.window, text)
		return api
	end
	return api
end

function Section:AddToggle(text, default, callback, flagName)
	local section = self
	local toggle = card(34)
	toggle.Parent = section.container

	local label = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFontMedium,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toggle,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	local track = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 18),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = toggle,
	}, {Utility.corner(9)})

	local knob = Utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		Parent = track,
	}, {Utility.corner(7)})
	themed(knob, "BackgroundColor3", "Text")

	local trackGlow = Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1.5, Transparency = 1}, {})
	trackGlow.Parent = track
	themed(trackGlow, "Color", "Accent")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = toggle,
	})

	local state = default or false

	local function updateToggleStyle()
		local targetColor = state and Theme.Accent or Theme.Stroke
		Utility.tween(track, {BackgroundColor3 = targetColor}, 0.15)
		Utility.tween(trackGlow, {Transparency = state and 0.35 or 1}, 0.2)
	end
	themed(track, "BackgroundColor3", updateToggleStyle)

	local api = {}
	function api:Set(value)
		state = value
		updateToggleStyle()
		if state then
			Utility.tween(knob, {Position = UDim2.new(1, -16, 0.5, 0)}, 0.15)
		else
			Utility.tween(knob, {Position = UDim2.new(0, 2, 0.5, 0)}, 0.15)
		end
	end
	function api:Get() return state end

	api:Set(state)

	click.MouseButton1Click:Connect(function()
		api:Set(not state)
		if callback then callback(state) end
	end)

	function api:AddToolTip(text)
		addToolTipToInstance(toggle, section.tab.window, text)
		return api
	end

	function api:CreateKeybind(defaultBind, toggleCallback)
		track.Position = UDim2.new(1, -74, 0.5, 0)

		local keybindHolder = Utility.create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0, 54, 0, 18),
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			Parent = toggle,
		}, {Utility.corner(4)})
		themed(keybindHolder, "BackgroundColor3", "Panel")
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = keybindHolder
		themed(keybindHolder.UIStroke, "Color", "Stroke")

		local keyLabel = Utility.create("TextLabel", {
			Text = defaultBind and defaultBind.Name or "None",
			Font = Theme.BodyFontBold,
			TextSize = 10,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = keybindHolder,
		})
		themed(keyLabel, "TextColor3", "Text")
		themed(keyLabel, "Font", "BodyFontBold")

		local bindClick = Utility.create("TextButton", {
			Text = "", BackgroundTransparency = 1, ZIndex = 6, Size = UDim2.new(1, 0, 1, 0), Parent = keybindHolder,
		})

		local currentKey = defaultBind
		local listening = false
		local bindConn
		local gameplayConn

		local function updateGameplayListener()
			if gameplayConn then
				gameplayConn:Disconnect()
				gameplayConn = nil
			end
			if currentKey then
				gameplayConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if gameProcessed then return end
					if input.KeyCode == currentKey then
						api:Set(not state)
						if callback then callback(state) end
						if toggleCallback then toggleCallback(currentKey) end
					end
				end)
				section.tab.window:RegisterConnection(gameplayConn)
			end
		end

		updateGameplayListener()

		bindClick.MouseButton1Click:Connect(function()
			if listening then return end
			listening = true
			keyLabel.Text = "..."
			if gameplayConn then
				gameplayConn:Disconnect()
				gameplayConn = nil
			end

			bindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					currentKey = input.KeyCode
					keyLabel.Text = currentKey.Name
					listening = false
					bindConn:Disconnect()
					updateGameplayListener()
				end
			end)
			section.tab.window:RegisterConnection(bindConn)
		end)

		local keybindApi = {}
		function keybindApi:SetBind(key)
			currentKey = key
			keyLabel.Text = key and key.Name or "None"
			updateGameplayListener()
		end
		function keybindApi:GetBind()
			return currentKey
		end
		return keybindApi
	end

	if flagName then
		section.tab.window:RegisterFlag(flagName, state, function(value)
			api:Set(value)
			if callback then callback(value) end
		end)
	end

	return api
end

function Section:AddSlider(text, min, max, default, options, callback)
	local section = self
	if type(options) == "function" then
		callback = options
		options = {}
	end
	options = options or {}
	local step = options.step
	local precision = options.precision or 0
	local suffix = options.suffix or ""

	min, max = min or 0, max or 100

	local function round(v)
		if step then
			v = math.round(v / step) * step
		end
		local mult = 10^precision
		return math.round(v * mult) / mult
	end

	local value = math.clamp(round(default or min), min, max)

	local slider = card(46)
	slider.Parent = section.container

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 4),
		Size = UDim2.new(1, -60, 0, 16), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slider,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")

	local valueBox = Utility.create("TextBox", {
		Text = string.format("%." .. tostring(precision) .. "f", value) .. suffix,
		Font = Theme.BodyFontBold, TextSize = 12, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Position = UDim2.new(1, -66, 0, 4),
		Size = UDim2.new(0, 56, 0, 16), TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		Parent = slider,
	})
	themed(valueBox, "TextColor3", "SubText")
	themed(valueBox, "Font", "BodyFontBold")

	local bar = Utility.create("Frame", {
		Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -20, 0, 6),
		BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0, Parent = slider,
	}, {Utility.corner(3)})
	themed(bar, "BackgroundColor3", "Stroke")

	local fill = Utility.create("Frame", {
		Size = UDim2.new((max - min) > 0 and ((value - min) / (max - min)) or 0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bar,
	}, {Utility.corner(3)})
	themed(fill, "BackgroundColor3", "Accent")

	local fillGlow = Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1.5, Transparency = 1}, {})
	fillGlow.Parent = fill
	themed(fillGlow, "Color", "Accent")

	local dragButton = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 20),
		Position = UDim2.new(0, 0, 0, -10), Parent = bar,
	})

	local api = {}
	local dragging = false
	local dragChangedConn, dragEndedConn

	function api:Set(v)
		v = math.clamp(round(v), min, max)
		value = v
		local percent = (max - min) > 0 and ((v - min) / (max - min)) or 0
		fill.Size = UDim2.new(percent, 0, 1, 0)
		valueBox.Text = string.format("%." .. tostring(precision) .. "f", v) .. suffix
	end
	function api:Get() return value end

	valueBox.FocusLost:Connect(function(enterPressed)
		local cleaned = valueBox.Text
		if suffix ~= "" then
			cleaned = string.gsub(cleaned, suffix, "")
		end
		local num = tonumber(cleaned)
		if num then
			api:Set(num)
			if callback then callback(value) end
		else
			api:Set(value)
		end
	end)

	local function updateFromInput(inputPos)
		local percent = math.clamp((inputPos - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local v = min + (max - min) * percent
		api:Set(v)
		if callback then callback(value) end
	end

	local function disconnectDrag()
		if dragChangedConn then dragChangedConn:Disconnect(); dragChangedConn = nil end
		if dragEndedConn then dragEndedConn:Disconnect(); dragEndedConn = nil end
		dragging = false
		Utility.tween(fillGlow, {Transparency = 1}, 0.2)
	end

	dragButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			disconnectDrag()

			dragging = true
			Utility.tween(fillGlow, {Transparency = 0}, 0.15)
			updateFromInput(input.Position.X)

			dragChangedConn = UserInputService.InputChanged:Connect(function(moveInput)
				if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
					updateFromInput(moveInput.Position.X)
				end
			end)
			section.tab.window:RegisterConnection(dragChangedConn)

			dragEndedConn = UserInputService.InputEnded:Connect(function(endInput)
				if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
					disconnectDrag()
				end
			end)
			section.tab.window:RegisterConnection(dragEndedConn)
		end
	end)

	function api:AddToolTip(text)
		addToolTipToInstance(slider, section.tab.window, text)
		return api
	end

	if options.Flag then
		section.tab.window:RegisterFlag(options.Flag, value, function(v)
			api:Set(v)
			if callback then callback(v) end
		end)
	end

	return api
end

function Section:AddTextbox(text, placeholder, callback, flagName)
	local section = self
	local box = card(34)
	box.Parent = section.container

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	local inputHolder = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.5, -10, 0, 22), BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0, Parent = box,
	}, {Utility.corner(4)})
	themed(inputHolder, "BackgroundColor3", "Panel")

	local input = Utility.create("TextBox", {
		Text = "", PlaceholderText = placeholder or "",
		Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Parent = inputHolder,
	})
	themed(input, "TextColor3", "Text")
	themed(input, "PlaceholderColor3", "SubText")
	themed(input, "Font", "BodyFont")

	input.FocusLost:Connect(function(enterPressed)
		if callback then callback(input.Text, enterPressed) end
	end)

	local api = {
		Set = function(_, text2) input.Text = text2 end,
		Get = function() return input.Text end,
	}
	function api:AddToolTip(text)
		addToolTipToInstance(box, section.tab.window, text)
		return api
	end

	if flagName then
		section.tab.window:RegisterFlag(flagName, input.Text, function(value)
			api:Set(value)
			if callback then callback(value, false) end
		end)
	end

	return api
end

function Section:AddKeybind(text, default, callback, flagName)
	local section = self
	local bind = card(34)
	bind.Parent = section.container

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -100, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bind,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	local keyHolder = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 80, 0, 22), BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0, Parent = bind,
	}, {Utility.corner(4)})
	themed(keyHolder, "BackgroundColor3", "Panel")

	local keyLabel = Utility.create("TextLabel", {
		Text = default and default.Name or "None", Font = Theme.BodyFontBold, TextSize = 12,
		TextColor3 = Theme.Text, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), Parent = keyHolder,
	})
	themed(keyLabel, "TextColor3", "Text")
	themed(keyLabel, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.new(1, 0, 1, 0), Parent = bind,
	})

	local currentKey = default
	local listening = false
	local connection
	local gameplayConnection

	local function updateGameplayListener()
		if gameplayConnection then
			gameplayConnection:Disconnect()
			gameplayConnection = nil
		end
		if currentKey then
			gameplayConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if gameProcessed then return end
				if input.KeyCode == currentKey then
					if callback then callback(currentKey) end
				end
			end)
			section.tab.window:RegisterConnection(gameplayConnection)
		end
	end

	updateGameplayListener()

	click.MouseButton1Click:Connect(function()
		if listening then return end
		listening = true
		keyLabel.Text = "..."
		if gameplayConnection then
			gameplayConnection:Disconnect()
			gameplayConnection = nil
		end

		connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				currentKey = input.KeyCode
				keyLabel.Text = currentKey.Name
				listening = false
				connection:Disconnect()
				updateGameplayListener()
			end
		end)
		section.tab.window:RegisterConnection(connection)
	end)

	local api = {
		Set = function(_, key)
			currentKey = key
			keyLabel.Text = key and key.Name or "None"
			updateGameplayListener()
		end,
		Get = function() return currentKey end,
	}
	function api:AddToolTip(text)
		addToolTipToInstance(bind, section.tab.window, text)
		return api
	end

	if flagName then
		section.tab.window:RegisterFlag(flagName, currentKey and currentKey.Name or "None", function(value)
			local key = (value and value ~= "None") and Enum.KeyCode[value] or nil
			api:Set(key)
			if callback and key then callback(key) end
		end)
	end

	return api
end

function Section:AddDropdown(text, options, default, callback, flagName)
	local section = self
	options = options or {}

	local CLOSED_HEIGHT = 34
	local ITEM_HEIGHT = 26
	local ITEM_SPACING = 4
	local SEARCH_BOX_HEIGHT = 24
	local LIST_TOP = 36
	local LIST_BOTTOM_PAD = 8

	local function openHeightFor(count)
		local base = LIST_TOP + SEARCH_BOX_HEIGHT + 6
		if count == 0 then return base + ITEM_HEIGHT + LIST_BOTTOM_PAD end
		local listHeight = (count * ITEM_HEIGHT) + (math.max(0, count - 1) * ITEM_SPACING) + LIST_BOTTOM_PAD
		return base + listHeight
	end

	local dropdown = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = section.container,
	}, {Utility.corner(6)})
	themed(dropdown, "BackgroundColor3", "Elevated")
	local dropdownStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	dropdownStroke.Parent = dropdown
	themed(dropdownStroke, "Color", "Stroke")
	Utility.hoverGlow(dropdown, dropdownStroke)

	local header = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = dropdown,
	})

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")

	local selectedLabel = Utility.create("TextLabel", {
		Text = tostring(default or "Select"), Font = Theme.BodyFont, TextSize = 12,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(1, -140, 0, 0), Size = UDim2.new(0, 100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("TextLabel", {
		Text = "v", Font = Theme.BodyFontBold, TextSize = 12, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(1, -26, 0, 0),
		Size = UDim2.new(0, 20, 1, 0), Parent = header,
	})
	themed(arrow, "TextColor3", "Text")
	themed(arrow, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = header,
	})

	local searchHolder = Utility.create("Frame", {
		Size = UDim2.new(1, -12, 0, SEARCH_BOX_HEIGHT),
		Position = UDim2.new(0, 6, 0, LIST_TOP),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = dropdown,
	}, {Utility.corner(4)})
	themed(searchHolder, "BackgroundColor3", "Panel")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = searchHolder
	themed(searchHolder.UIStroke, "Color", "Stroke")

	local searchInput = Utility.create("TextBox", {
		Text = "", PlaceholderText = "Search...",
		Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Parent = searchHolder,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	local list = Utility.create("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 6, 0, LIST_TOP + SEARCH_BOX_HEIGHT + 6),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = dropdown,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ITEM_SPACING)}),
		Utility.create("UIPadding", {PaddingBottom = UDim.new(0, LIST_BOTTOM_PAD)}),
	})

	local noResults = Utility.create("TextLabel", {
		Text = "No matches", Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, LayoutOrder = 9999,
		Parent = list,
	})
	themed(noResults, "TextColor3", "SubText")
	themed(noResults, "Font", "BodyFont")

	local open = false
	local activeSearchText = ""
	local api = {}

	local function filterItems()
		local visibleCount = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local match = string.find(string.lower(child.Text), string.lower(activeSearchText), 1, true) ~= nil
				child.Visible = match
				if match then
					visibleCount = visibleCount + 1
				end
			end
		end
		noResults.Visible = (visibleCount == 0)
		if open then
			local newHeight = openHeightFor(visibleCount)
			Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, newHeight)}, 0.1)
		end
	end

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		activeSearchText = searchInput.Text
		filterItems()
	end)

	local function close()
		open = false
		searchInput.Text = ""
		activeSearchText = ""
		filterItems()
		Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)}, 0.15)
		Utility.tween(arrow, {Rotation = 0}, 0.15)
		task.delay(0.15, function()
			if not open then
				list.Visible = false
				searchHolder.Visible = false
			end
		end)
	end

	local function rebuild(items)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, opt in ipairs(items) do
			local item = Utility.create("TextButton", {
				Text = tostring(opt), Font = Theme.BodyFont, TextSize = 12,
				TextColor3 = Theme.Text, BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
				BorderSizePixel = 0, Parent = list,
			}, {Utility.corner(4)})
			themed(item, "TextColor3", "Text")
			themed(item, "BackgroundColor3", "Panel")
			themed(item, "Font", "BodyFont")

			item.MouseButton1Click:Connect(function()
				selectedLabel.Text = tostring(opt)
				close()
				if callback then callback(opt) end
			end)
		end
	end

	rebuild(options)

	function api:Refresh(newOptions)
		options = newOptions
		rebuild(options)
		filterItems()
	end
	function api:Set(value) selectedLabel.Text = tostring(value) end
	function api:Get() return selectedLabel.Text end

	click.MouseButton1Click:Connect(function()
		if open then
			close()
		else
			open = true
			list.Visible = true
			searchHolder.Visible = true

			local visibleCount = 0
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then
					visibleCount = visibleCount + 1
				end
			end

			Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))}, 0.15)
			Utility.tween(arrow, {Rotation = 180}, 0.15)
		end
	end)

	function api:AddToolTip(text)
		addToolTipToInstance(dropdown, section.tab.window, text)
		return api
	end

	if flagName then
		section.tab.window:RegisterFlag(flagName, selectedLabel.Text, function(value)
			api:Set(value)
			if callback then callback(value) end
		end)
	end

	return api
end

function Section:AddMultiDropdown(text, options, defaults, callback, flagName)
	local section = self
	options = options or {}

	local CLOSED_HEIGHT = 34
	local ITEM_HEIGHT = 26
	local ITEM_SPACING = 4
	local SEARCH_BOX_HEIGHT = 24
	local LIST_TOP = 36
	local LIST_BOTTOM_PAD = 8

	local function openHeightFor(count)
		local base = LIST_TOP + SEARCH_BOX_HEIGHT + 6
		if count == 0 then return base + ITEM_HEIGHT + LIST_BOTTOM_PAD end
		local listHeight = (count * ITEM_HEIGHT) + (math.max(0, count - 1) * ITEM_SPACING) + LIST_BOTTOM_PAD
		return base + listHeight
	end

	local dropdown = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT),
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = section.container,
	}, {Utility.corner(6)})
	themed(dropdown, "BackgroundColor3", "Elevated")
	local dropdownStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	dropdownStroke.Parent = dropdown
	themed(dropdownStroke, "Color", "Stroke")
	Utility.hoverGlow(dropdown, dropdownStroke)

	local header = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = dropdown,
	})

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")

	local selectedLabel = Utility.create("TextLabel", {
		Text = "None", Font = Theme.BodyFont, TextSize = 12,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(1, -140, 0, 0), Size = UDim2.new(0, 100, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = header,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("TextLabel", {
		Text = "v", Font = Theme.BodyFontBold, TextSize = 12, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(1, -26, 0, 0),
		Size = UDim2.new(0, 20, 1, 0), Parent = header,
	})
	themed(arrow, "TextColor3", "Text")
	themed(arrow, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = header,
	})

	local searchHolder = Utility.create("Frame", {
		Size = UDim2.new(1, -12, 0, SEARCH_BOX_HEIGHT),
		Position = UDim2.new(0, 6, 0, LIST_TOP),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = dropdown,
	}, {Utility.corner(4)})
	themed(searchHolder, "BackgroundColor3", "Panel")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = searchHolder
	themed(searchHolder.UIStroke, "Color", "Stroke")

	local searchInput = Utility.create("TextBox", {
		Text = "", PlaceholderText = "Search...",
		Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Parent = searchHolder,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	local list = Utility.create("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 6, 0, LIST_TOP + SEARCH_BOX_HEIGHT + 6),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = dropdown,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ITEM_SPACING)}),
		Utility.create("UIPadding", {PaddingBottom = UDim.new(0, LIST_BOTTOM_PAD)}),
	})

	local noResults = Utility.create("TextLabel", {
		Text = "No matches", Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, LayoutOrder = 9999,
		Parent = list,
	})
	themed(noResults, "TextColor3", "SubText")
	themed(noResults, "Font", "BodyFont")

	local open = false
	local activeSearchText = ""
	local selected = {}
	local checkboxes = {}
	local api = {}

	for _, v in ipairs(defaults or {}) do
		selected[tostring(v)] = true
	end

	local function currentSelection()
		local result = {}
		for _, opt in ipairs(options) do
			if selected[tostring(opt)] then
				table.insert(result, opt)
			end
		end
		return result
	end

	local function updateSelectedLabel()
		local picks = currentSelection()
		if #picks == 0 then
			selectedLabel.Text = "None"
		elseif #picks == 1 then
			selectedLabel.Text = tostring(picks[1])
		else
			selectedLabel.Text = #picks .. " selected"
		end
	end

	local function filterItems()
		local visibleCount = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local match = string.find(string.lower(child.Text), string.lower(activeSearchText), 1, true) ~= nil
				child.Visible = match
				if match then
					visibleCount = visibleCount + 1
				end
			end
		end
		noResults.Visible = (visibleCount == 0)
		if open then
			Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))}, 0.1)
		end
	end

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		activeSearchText = searchInput.Text
		filterItems()
	end)

	local function close()
		open = false
		searchInput.Text = ""
		activeSearchText = ""
		filterItems()
		Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, CLOSED_HEIGHT)}, 0.15)
		Utility.tween(arrow, {Rotation = 0}, 0.15)
		task.delay(0.15, function()
			if not open then
				list.Visible = false
				searchHolder.Visible = false
			end
		end)
	end

	local function rebuild(items)
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		checkboxes = {}
		for _, opt in ipairs(items) do
			local key = tostring(opt)
			local item = Utility.create("TextButton", {
				Text = key, TextTransparency = 1, Font = Theme.BodyFont, TextSize = 12,
				BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, ITEM_HEIGHT), BorderSizePixel = 0, Parent = list,
			}, {Utility.corner(4)})
			themed(item, "BackgroundColor3", "Panel")

			local box = Utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Theme.Panel,
				BorderSizePixel = 0, Parent = item,
			}, {Utility.corner(4)})
			Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = box
			themed(box.UIStroke, "Color", "Stroke")

			local check = Utility.create("TextLabel", {
				Text = "\226\156\147", Font = Theme.BodyFontBold, TextSize = 11, TextColor3 = Theme.Accent,
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center, Visible = selected[key] == true,
				Parent = box,
			})
			themed(check, "TextColor3", "Accent")

			local label = Utility.create("TextLabel", {
				Text = key, Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
				BackgroundTransparency = 1, Position = UDim2.new(0, 30, 0, 0),
				Size = UDim2.new(1, -36, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
				Parent = item,
			})
			themed(label, "TextColor3", "Text")
			themed(label, "Font", "BodyFont")

			checkboxes[key] = check

			item.MouseButton1Click:Connect(function()
				selected[key] = not selected[key] or nil
				check.Visible = selected[key] == true
				updateSelectedLabel()
				if callback then callback(currentSelection()) end
			end)
		end
	end

	rebuild(options)
	updateSelectedLabel()

	function api:Refresh(newOptions)
		options = newOptions
		local stillValid = {}
		for _, opt in ipairs(options) do
			stillValid[tostring(opt)] = true
		end
		for key in pairs(selected) do
			if not stillValid[key] then selected[key] = nil end
		end
		rebuild(options)
		updateSelectedLabel()
		if open then
			local visibleCount = 0
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then
					visibleCount = visibleCount + 1
				end
			end
			dropdown.Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))
		end
	end

	function api:Get()
		return currentSelection()
	end

	function api:Set(values)
		selected = {}
		for _, v in ipairs(values or {}) do
			selected[tostring(v)] = true
		end
		for key, check in pairs(checkboxes) do
			check.Visible = selected[key] == true
		end
		updateSelectedLabel()
	end

	click.MouseButton1Click:Connect(function()
		if open then
			close()
		else
			open = true
			list.Visible = true
			searchHolder.Visible = true

			local visibleCount = 0
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then
					visibleCount = visibleCount + 1
				end
			end

			Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))}, 0.15)
			Utility.tween(arrow, {Rotation = 180}, 0.15)
		end
	end)

	function api:AddToolTip(text)
		addToolTipToInstance(dropdown, section.tab.window, text)
		return api
	end

	if flagName then
		section.tab.window:RegisterFlag(flagName, api:Get(), function(value)
			api:Set(value)
			if callback then callback(value) end
		end)
	end

	return api
end

function Section:AddColorPicker(text, default, callback, flagName)
	local section = self
	default = default or Color3.fromRGB(140, 20, 20)

	local picker = card(34)
	picker.Parent = section.container

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFontMedium, TextSize = 13, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = picker,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")

	local swatch = Utility.create("TextButton", {
		Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 18), BackgroundColor3 = default,
		BorderSizePixel = 0, Parent = picker,
	}, {Utility.corner(4)})
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = swatch
	themed(swatch.UIStroke, "Color", "Stroke")

	local panel = Utility.create("Frame", {
		Size = UDim2.new(0, 180, 0, 180),
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 20,
		Parent = section.tab.window.main,
	}, {Utility.corner(6), Utility.pad(10)})
	themed(panel, "BackgroundColor3", "Elevated")
	Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1, Transparency = 0.4}, {}).Parent = panel
	themed(panel.UIStroke, "Color", "Accent")

	local svBox = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 90),
		BackgroundColor3 = default,
		BorderSizePixel = 0,
		Parent = panel,
	}, {Utility.corner(4)})

	local whiteOverlay = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = svBox,
	}, {
		Utility.corner(4),
		Utility.create("UIGradient", {Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)}}),
	})

	local blackOverlay = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, Parent = svBox,
	}, {
		Utility.corner(4),
		Utility.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new{
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)},
		}),
	})

	local svCursor = Utility.create("Frame", {
		Size = UDim2.new(0, 8, 0, 8), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 21, Parent = svBox,
	}, {Utility.corner(4), Utility.create("UIStroke", {Color = Color3.new(0,0,0), Thickness = 1})})

	local hueBar = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 100),
		BorderSizePixel = 0, Parent = panel,
	}, {
		Utility.corner(4),
		Utility.create("UIGradient", {Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 0, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
		})}),
	})

	local hueCursor = Utility.create("Frame", {
		Size = UDim2.new(0, 4, 1, 4), AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = hueBar,
	}, {Utility.corner(2)})

	local rgbInputHolder = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 126),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = panel,
	}, {Utility.corner(4)})
	themed(rgbInputHolder, "BackgroundColor3", "Panel")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = rgbInputHolder
	themed(rgbInputHolder.UIStroke, "Color", "Stroke")

	local rgbInput = Utility.create("TextBox", {
		Text = "",
		PlaceholderText = "RGB: 140, 20, 20",
		Font = Theme.BodyFont,
		TextSize = 10,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		ClearTextOnFocus = false,
		Parent = rgbInputHolder,
	})
	themed(rgbInput, "TextColor3", "Text")
	themed(rgbInput, "PlaceholderColor3", "SubText")
	themed(rgbInput, "Font", "BodyFont")

	local hue, sat, val = Color3.toHSV(default)
	local dragSV, dragHue = false, false
	local dragChangedConn, dragEndedConn

	local function updateColor(skipText)
		local color = Color3.fromHSV(hue, sat, val)
		swatch.BackgroundColor3 = color
		svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		if not skipText then
			local r = math.round(color.R * 255)
			local g = math.round(color.G * 255)
			local b = math.round(color.B * 255)
			rgbInput.Text = string.format("%d, %d, %d", r, g, b)
		end
		if callback then callback(color) end
	end

	local initR = math.round(default.R * 255)
	local initG = math.round(default.G * 255)
	local initB = math.round(default.B * 255)
	rgbInput.Text = string.format("%d, %d, %d", initR, initG, initB)

	rgbInput.FocusLost:Connect(function(enterPressed)
		local parts = string.split(string.gsub(rgbInput.Text, "%s+", ""), ",")
		local r = tonumber(parts[1])
		local g = tonumber(parts[2])
		local b = tonumber(parts[3])
		if r and g and b then
			local color = Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
			hue, sat, val = Color3.toHSV(color)
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			updateColor(true)
		else
			updateColor()
		end
	end)

	local function disconnectDrag()
		if dragChangedConn then dragChangedConn:Disconnect(); dragChangedConn = nil end
		if dragEndedConn then dragEndedConn:Disconnect(); dragEndedConn = nil end
		dragSV, dragHue = false, false
	end

	local function startDrag()
		disconnectDrag()

		dragChangedConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
			if dragSV then
				local rel = Vector2.new(
					math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1),
					math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
				)
				sat, val = rel.X, 1 - rel.Y
				svCursor.Position = UDim2.new(rel.X, 0, rel.Y, 0)
				updateColor()
			elseif dragHue then
				local percent = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
				hue = percent
				hueCursor.Position = UDim2.new(percent, 0, 0.5, 0)
				updateColor()
			end
		end)
		section.tab.window:RegisterConnection(dragChangedConn)

		dragEndedConn = UserInputService.InputEnded:Connect(function(endInput)
			if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
				disconnectDrag()
			end
		end)
		section.tab.window:RegisterConnection(dragEndedConn)
	end

	svBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag()
			dragSV = true
			local rel = Vector2.new(
				math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1),
				math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
			)
			sat, val = rel.X, 1 - rel.Y
			svCursor.Position = UDim2.new(rel.X, 0, rel.Y, 0)
			updateColor()
		end
	end)

	hueBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag()
			dragHue = true
			local percent = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
			hue = percent
			hueCursor.Position = UDim2.new(percent, 0, 0.5, 0)
			updateColor()
		end
	end)

	local open = false
	swatch.MouseButton1Click:Connect(function()
		open = not open
		if open then
			panel.Position = UDim2.new(0, swatch.AbsolutePosition.X - section.tab.window.main.AbsolutePosition.X - 190, 0, swatch.AbsolutePosition.Y - section.tab.window.main.AbsolutePosition.Y)
			panel.Visible = true
		else
			panel.Visible = false
		end
	end)

	local api = {
		Set = function(_, color)
			hue, sat, val = Color3.toHSV(color)
			swatch.BackgroundColor3 = color
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			svBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
			local r = math.round(color.R * 255)
			local g = math.round(color.G * 255)
			local b = math.round(color.B * 255)
			rgbInput.Text = string.format("%d, %d, %d", r, g, b)
		end,
		Get = function() return Color3.fromHSV(hue, sat, val) end,
	}

	function api:AddToolTip(text)
		addToolTipToInstance(picker, section.tab.window, text)
		return api
	end

	if flagName then
		local startColor = api:Get()
		section.tab.window:RegisterFlag(flagName, {
			R = math.round(startColor.R * 255),
			G = math.round(startColor.G * 255),
			B = math.round(startColor.B * 255),
		}, function(value)
			local color = Color3.fromRGB(value.R, value.G, value.B)
			api:Set(color)
			if callback then callback(color) end
		end)
	end

	return api
end

function Section:AddLabel(text)
	local section = self
	local labelFrame = Utility.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		BorderSizePixel = 0,
		Parent = self.container,
	})

	local label = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFont,
		TextSize = 13,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -10, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = labelFrame,
	})
	themed(label, "TextColor3", "SubText")
	themed(label, "Font", "BodyFont")

	local api = {}
	function api:SetText(newText)
		label.Text = newText
	end
	function api:AddToolTip(text)
		addToolTipToInstance(labelFrame, section.tab.window, text)
		return api
	end
	return api
end

function Section:AddParagraph(title, desc)
	local section = self
	local para = Utility.create("Frame", {
		BackgroundColor3 = Theme.Elevated,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = self.container,
	}, {
		Utility.corner(6),
		Utility.pad(8),
	})
	themed(para, "BackgroundColor3", "Elevated")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = para
	themed(para.UIStroke, "Color", "Stroke")

	local titleLabel = Utility.create("TextLabel", {
		Text = title,
		Font = Theme.BodyFontBold,
		TextSize = 13,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = para,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontBold")

	local descLabel = Utility.create("TextLabel", {
		Text = desc,
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 18),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = para,
	})
	themed(descLabel, "TextColor3", "SubText")
	themed(descLabel, "Font", "BodyFont")

	local api = {}
	function api:Set(newTitle, newDesc)
		titleLabel.Text = newTitle
		descLabel.Text = newDesc
	end
	function api:AddToolTip(text)
		addToolTipToInstance(para, section.tab.window, text)
		return api
	end
	return api
end

function Section:AddDivider()
	local section = self
	local holder = Utility.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 9),
		BorderSizePixel = 0,
		Parent = section.container,
	})

	local line = Utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = holder,
	})
	themed(line, "BackgroundColor3", "Stroke")

	local api = {}
	function api:AddToolTip(text)
		addToolTipToInstance(holder, section.tab.window, text)
		return api
	end
	return api
end

Dami.Theme = Theme

return Dami
