

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

local PresetThemes = {
	cherry = {
		Accent = Color3.fromRGB(249, 22, 52),
		AccentDim = Color3.fromRGB(180, 15, 35),
	},
	orange = {
		Accent = Color3.fromRGB(244, 148, 22),
		AccentDim = Color3.fromRGB(180, 100, 15),
	},
	lemon = {
		Accent = Color3.fromRGB(220, 255, 66),
		AccentDim = Color3.fromRGB(160, 190, 40),
	},
	lime = {
		Accent = Color3.fromRGB(33, 255, 120),
		AccentDim = Color3.fromRGB(20, 190, 80),
	},
	raspberry = {
		Accent = Color3.fromRGB(0, 190, 255),
		AccentDim = Color3.fromRGB(0, 130, 190),
	},
	blueberry = {
		Accent = Color3.fromRGB(91, 77, 249),
		AccentDim = Color3.fromRGB(60, 50, 180),
	},
	grape = {
		Accent = Color3.fromRGB(134, 53, 255),
		AccentDim = Color3.fromRGB(90, 30, 180),
	}
}

local Theme = {
	Background = Color3.fromRGB(11, 11, 11),
	Panel      = Color3.fromRGB(15, 15, 15),
	Elevated   = Color3.fromRGB(18, 18, 18),
	Stroke     = Color3.fromRGB(35, 35, 35),
	HoverStroke = Color3.fromRGB(65, 65, 65),
	Accent     = Color3.fromRGB(134, 53, 255),
	AccentDim  = Color3.fromRGB(90, 30, 180),
	Text       = Color3.fromRGB(240, 240, 240),
	SubText    = Color3.fromRGB(150, 150, 150),

	TitleFont      = Enum.Font.Code,
	BodyFont       = Enum.Font.Code,
	BodyFontMedium = Enum.Font.Code,
	BodyFontBold   = Enum.Font.Code,
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
	return Utility.create("UICorner", {CornerRadius = UDim.new(0, radius or 4)})
end

function Utility.pad(all, right, top, bottom)
	local leftPad = all
	local rightPad = right or all
	local topPad = top or all
	local bottomPad = bottom or top or all
	return Utility.create("UIPadding", {
		PaddingTop = UDim.new(0, topPad),
		PaddingBottom = UDim.new(0, bottomPad),
		PaddingLeft = UDim.new(0, leftPad),
		PaddingRight = UDim.new(0, rightPad),
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

	local info = TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, info, props)
	bucket[key] = t
	t:Play()
	return t
end

function Utility.hoverGlow(trigger, stroke, options)
	options = options or {}
	local hoverThickness = options.hoverThickness or 1.2
	local restThickness = options.restThickness or 1
	local hoverKey = options.hoverKey or "HoverStroke"
	local restKey = options.restKey or "Stroke"

	trigger.MouseEnter:Connect(function()
		Utility.tween(stroke, {Color = Theme[hoverKey], Thickness = hoverThickness}, 0.1, nil, nil, "glow")
	end)
	trigger.MouseLeave:Connect(function()
		Utility.tween(stroke, {Color = Theme[restKey], Thickness = restThickness}, 0.1, nil, nil, "glow")
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

function Utility.resize(handle, target, minSize, maxSize)
	local resizing, dragStart, startSize
	minSize = minSize or Vector2.new(480, 320)
	maxSize = maxSize or Vector2.new(960, 720)

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			dragStart = input.Position
			startSize = target.AbsoluteSize

			beginDrag(function(moveInput)
				if not resizing then return end
				local delta = moveInput.Position - dragStart
				local newX = math.clamp(startSize.X + delta.X, minSize.X, maxSize.X)
				local newY = math.clamp(startSize.Y + delta.Y, minSize.Y, maxSize.Y)

				target.Size = UDim2.new(0, newX, 0, newY)
			end, function()
				resizing = false
			end)
		end
	end)
end

local function card(height)
	local frame = Utility.create("Frame", {
		BackgroundColor3 = Theme.Elevated,
		Size = UDim2.new(1, 0, 0, height or 30),
		BorderSizePixel = 0,
	})
	themed(frame, "BackgroundColor3", "Elevated")
	local stroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	stroke.Parent = frame
	themed(stroke, "Color", "Stroke")
	Utility.hoverGlow(frame, stroke)
	return frame
end

local function registerFlag(window, flagName, getVal, setVal)
	if not flagName then return end
	window.flags[flagName] = {
		Get = getVal,
		Set = setVal
	}
end

local Zyren = {}
Zyren.__index = Zyren

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

function Zyren.new(options)
	local title = "Zyren"
	local config = {}
	if type(options) == "table" then
		title = options.Title or "Zyren"
		config = options
	elseif type(options) == "string" then
		title = options
	end

	if type(options) == "table" then
		if type(options.Theme) == "string" then
			local preset = PresetThemes[string.lower(options.Theme)]
			if preset then
				for k, v in pairs(preset) do
					Theme[k] = v
				end
			end
		elseif type(options.Theme) == "table" then
			for k, v in pairs(options.Theme) do
				Theme[k] = v
			end
		end
	end

	local screenGui = Utility.create("ScreenGui", {
		Name = title or "Zyren",
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
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = screenGui,
	}, {
		Utility.corner(6),
	})
	themed(main, "BackgroundColor3", "Background")
	local windowStroke = Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1, Transparency = 0.5}, {})
	windowStroke.Parent = main
	themed(windowStroke, "Color", "Accent")

	local topBar = Utility.create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		Utility.corner(6),
	})
	themed(topBar, "BackgroundColor3", "Panel")
	

	Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		Position = UDim2.new(0, 0, 1, -8),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	})

	local titleLabel = Utility.create("TextLabel", {
		Text = title or "Zyren",
		Font = Theme.TitleFont,
		TextSize = 14,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = topBar,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "TitleFont")

	local searchHolder = Utility.create("Frame", {
		Name = "SearchHolder",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -64, 0.5, 0),
		Size = UDim2.new(0, 110, 0, 20),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {Utility.corner(4)})
	themed(searchHolder, "BackgroundColor3", "Background")
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = searchHolder
	themed(searchHolder.UIStroke, "Color", "Stroke")

	local searchInput = Utility.create("TextBox", {
		Text = "",
		PlaceholderText = "Search...",
		Font = Theme.BodyFont,
		TextSize = 10,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchHolder,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	local closeButton = Utility.create("TextButton", {
		Text = "×",
		Font = Theme.BodyFontBold,
		TextSize = 16,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		ZIndex = 5,
		Parent = topBar,
	})
	themed(closeButton, "TextColor3", "SubText")
	themed(closeButton, "Font", "BodyFontBold")

	closeButton.MouseEnter:Connect(function() Utility.tween(closeButton, {TextColor3 = Theme.Accent}, 0.1) end)
	closeButton.MouseLeave:Connect(function() Utility.tween(closeButton, {TextColor3 = Theme.SubText}, 0.1) end)
	closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)

	local minimizeButton = Utility.create("TextButton", {
		Text = "-",
		Font = Theme.BodyFontBold,
		TextSize = 16,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.5, 0),
		Size = UDim2.new(0, 20, 0, 20),
		ZIndex = 5,
		Parent = topBar,
	})
	themed(minimizeButton, "TextColor3", "SubText")
	themed(minimizeButton, "Font", "BodyFontBold")

	minimizeButton.MouseEnter:Connect(function() Utility.tween(minimizeButton, {TextColor3 = Theme.Accent}, 0.1) end)
	minimizeButton.MouseLeave:Connect(function() Utility.tween(minimizeButton, {TextColor3 = Theme.SubText}, 0.1) end)

	Utility.drag(topBar, main)

	local tabBar = Utility.create("Frame", {
		Name = "TabBar",
		Position = UDim2.new(0, 0, 0, 32),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = main,
	})
	themed(tabBar, "BackgroundColor3", "Background")
	
	local tabLine = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = tabBar,
	})
	themed(tabLine, "BackgroundColor3", "Stroke")

	local tabList = Utility.create("ScrollingFrame", {
		Size = UDim2.new(1, -12, 1, -1),
		Position = UDim2.new(0, 6, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		Parent = tabBar,
	}, {
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
		}),
	})
	
	-- We need to update tabList CanvasSize dynamically
	tabList.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabList.CanvasSize = UDim2.new(0, tabList.UIListLayout.AbsoluteContentSize.X, 0, 0)
	end)

	local pageContainer = Utility.create("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 0, 0, 59),
		Size = UDim2.new(1, 0, 1, -79),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local footer = Utility.create("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		Utility.corner(6),
	})
	themed(footer, "BackgroundColor3", "Panel")

	Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = footer,
	})

	local statsLabel = Utility.create("TextLabel", {
		Text = "FPS: ... | Ping: ... ms | Executor: ...",
		Font = Theme.BodyFont,
		TextSize = 9,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(0.7, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})
	themed(statsLabel, "TextColor3", "SubText")
	themed(statsLabel, "Font", "BodyFont")

	local timeLabel = Utility.create("TextLabel", {
		Text = "12:00:00 AM",
		Font = Theme.BodyFont,
		TextSize = 9,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(1, -120, 0, 0),
		Size = UDim2.new(0, 108, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = footer,
	})
	themed(timeLabel, "TextColor3", "SubText")
	themed(timeLabel, "Font", "BodyFont")

	local fpsCount = 0
	local lastFpsUpdate = os.clock()
	local fps = 60
	local telemetryConn = RunService.RenderStepped:Connect(function()
		fpsCount = fpsCount + 1
		local now = os.clock()
		if now - lastFpsUpdate >= 1 then
			fps = fpsCount
			fpsCount = 0
			lastFpsUpdate = now
		end
	end)

	local function getPing()
		local ok, ping = pcall(function()
			return Player:GetNetworkPing() * 1000
		end)
		if ok then return math.round(ping) end
		return "N/A"
	end

	local function getExecutorName()
		if identifyexecutor then
			local name = identifyexecutor()
			return name or "Unknown"
		elseif getexecutorname then
			return getexecutorname()
		elseif syn then
			return "Synapse"
		else
			return "Studio"
		end
	end

	task.spawn(function()
		while task.wait(1) do
			if not main.Parent then break end
			local curTime = os.date("%I:%M:%S %p")
			timeLabel.Text = curTime
			statsLabel.Text = string.format("FPS: %d | Ping: %s ms | Executor: %s", fps, tostring(getPing()), getExecutorName())
		end
	end)

	local resizeHandle = Utility.create("ImageButton", {
		Name = "ResizeHandle",
		Size = UDim2.new(0, 12, 0, 12),
		Position = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		Image = "rbxassetid://10651037303",
		ImageColor3 = Theme.SubText,
		ZIndex = 12,
		Parent = main,
	})
	themed(resizeHandle, "ImageColor3", "SubText")
	Utility.resize(resizeHandle, main, Vector2.new(480, 320), Vector2.new(960, 720))

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
		controls = {},
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
	}, Zyren)

	self:RegisterConnection(toolTipConn)
	self:RegisterConnection(telemetryConn)

	local function filterControls(query)
		query = string.lower(query)
		local tabHasMatches = {}
		local sectionHasMatches = {}

		for _, ctrl in ipairs(self.controls) do
			local match = query == "" or string.find(string.lower(ctrl.text), query, 1, true) ~= nil
			ctrl.instance.Visible = match
			
			local stroke = ctrl.instance:FindFirstChildOfClass("UIStroke")
			if stroke then
				Utility.tween(stroke, {Color = (match and query ~= "") and Theme.Accent or Theme.Stroke}, 0.15)
			end

			if match then
				tabHasMatches[ctrl.tab] = true
				sectionHasMatches[ctrl.section] = true
			end
		end

		for _, tab in ipairs(self.tabs) do
			for _, sec in ipairs(tab.sections) do
				sec.container.Visible = (query == "" or sectionHasMatches[sec] == true)
			end
		end

		if query ~= "" then
			for _, tab in ipairs(self.tabs) do
				if tabHasMatches[tab] then
					self:SelectTab(tab)
					break
				end
			end
		end
	end

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		filterControls(searchInput.Text)
	end)

	minimizeButton.MouseButton1Click:Connect(function()
		if isMinimizing then return end
		isMinimizing = true

		self.minimized = not self.minimized
		main.ClipsDescendants = true

		local targetHeight = self.minimized and 32 or originalHeight
		if self.minimized then
			sidebar.Visible = false
			pageContainer.Visible = false
			footer.Visible = false
			resizeHandle.Visible = false
		end

		local tween = Utility.tween(main, {Size = UDim2.new(0, main.AbsoluteSize.X, 0, targetHeight)}, 0.2)
		tween.Completed:Connect(function()
			isMinimizing = false
			if not self.minimized then
				sidebar.Visible = true
				pageContainer.Visible = true
				footer.Visible = true
				resizeHandle.Visible = true
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

function Zyren:RegisterConnection(connection)
	table.insert(self.connections, connection)
end

function Zyren:Toggle()
	self.screenGui.Enabled = not self.screenGui.Enabled
end

function Zyren:Destroy()
	self.screenGui:Destroy()
end

function Zyren:ShowToolTip(text)
	if text and text ~= "" then
		self.toolTipLabel.Text = text
		self.toolTip.Visible = true
	else
		self.toolTip.Visible = false
	end
end

function Zyren:HideToolTip()
	self.toolTip.Visible = false
end

function Zyren:SaveConfig(name)
	name = name or "default"
	local folder = "zyren_configs"
	if makefolder then
		pcall(makefolder, folder)
	end
	
	local filePath = folder .. "/" .. name .. ".json"
	local data = {}
	for flagName, flagInfo in pairs(self.flags) do
		data[flagName] = flagInfo.Get()
	end
	
	local success, err = pcall(function()
		local json = HttpService:JSONEncode(data)
		if writefile then
			writefile(filePath, json)
		else
			error("Executor does not support writefile API")
		end
	end)
	
	return success, err
end

function Zyren:LoadConfig(name)
	name = name or "default"
	local filePath = "zyren_configs/" .. name .. ".json"
	
	if not isfile or not isfile(filePath) then
		return false, "Config profile does not exist."
	end
	
	local success, err = pcall(function()
		local json = readfile(filePath)
		local data = HttpService:JSONDecode(json)
		for flagName, val in pairs(data) do
			local flagInfo = self.flags[flagName]
			if flagInfo then
				flagInfo.Set(val)
			end
		end
	end)
	
	return success, err
end

function Zyren:AddTab(name, options)
	local button = Utility.create("TextButton", {
		Text = name,
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = self.tabList,
	}, {
		Utility.pad(10, 10, 0, 0)
	})
	themed(button, "TextColor3", "SubText")
	themed(button, "Font", "BodyFont")

	local indicator = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 1, -2),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = button,
	})
	themed(indicator, "BackgroundColor3", "Accent")

	local function updateTabStyle()
		local isActive = (self.activeTab == tab)
		button.TextColor3 = isActive and Theme.Text or Theme.SubText
		Utility.tween(indicator, {Size = UDim2.new(1, 0, 0, isActive and 2 or 0)}, 0.1)
	end
	themed(button, "TextColor3", updateTabStyle)

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
	})
	themed(page, "ScrollBarImageColor3", "Accent")

	local leftColumn = Utility.create("Frame", {
		Name = "LeftColumn",
		Size = UDim2.new(0.5, -6, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)}),
	})

	local rightColumn = Utility.create("Frame", {
		Name = "RightColumn",
		Size = UDim2.new(0.5, -6, 0, 0),
		Position = UDim2.new(0.5, 6, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)}),
	})

	local tab = setmetatable({
		window = self,
		button = button,
		indicator = indicator,
		page = page,
		leftColumn = leftColumn,
		rightColumn = rightColumn,
		pageWrapper = pageWrapper,
		sections = {},
	}, Tab)

	function tab:UpdateLayout(expanded)
	end

	button.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)

	table.insert(self.tabs, tab)

	if not self.activeTab then
		self:SelectTab(tab)
	end

	return tab
end

local SECTION_PAD_TOP = 14
local SECTION_PAD_TOP_START = SECTION_PAD_TOP + 12

local function revealSection(section, index)
	local container = section.container
	task.delay((index - 1) * 0.03, function()
		if container and container.Parent then
			Utility.tween(container, {GroupTransparency = 0}, 0.15)
			if container:FindFirstChildOfClass("UIPadding") then
				Utility.tween(container.UIPadding, {PaddingTop = UDim.new(0, SECTION_PAD_TOP)}, 0.15)
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

function Zyren:SelectTab(tab)
	if self.activeTab == tab then return end

	if self.activeTab then
		local old = self.activeTab
		Utility.tween(old.indicator, {Size = UDim2.new(0, 2, 0, 0)}, 0.15)
		Utility.tween(old.pageWrapper, {GroupTransparency = 1, Position = UDim2.new(0, -12, 0, 0)}, 0.15)
		task.delay(0.15, function()
			if self.activeTab ~= old then
				old.pageWrapper.Visible = false
				hideAllSectionsInstant(old)
			end
		end)
	end

	tab.pageWrapper.Position = UDim2.new(0, 12, 0, 0)
	tab.pageWrapper.Visible = true
	Utility.tween(tab.pageWrapper, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}, 0.15)
	
	Utility.tween(tab.indicator, {Size = UDim2.new(0, 2, 0, 16)}, 0.15)
	revealAllSections(tab)

	self.activeTab = tab
	

	for _, t in ipairs(self.tabs) do
		local isActive = (t == tab)
		t.button.TextColor3 = isActive and Theme.Text or Theme.SubText
	end
end

function Zyren:SetTheme(newTheme)
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
				Utility.tween(entry.instance, {[entry.property] = Theme[entry.key]}, 0.2)
			end
		end
	end
	ThemeRegistry = activeRegistry
end

function Zyren:Notify(title, text, typeName, duration)
	if type(typeName) == "number" then
		duration = typeName
		typeName = "Info"
	end
	typeName = typeName or "Info"
	duration = duration or 3.5

	local accentColor = Theme.Accent
	if typeName == "Success" then
		accentColor = Color3.fromRGB(46, 204, 113)
	elseif typeName == "Warning" then
		accentColor = Color3.fromRGB(241, 196, 15)
	elseif typeName == "Error" then
		accentColor = Color3.fromRGB(231, 76, 60)
	end

	local notif = Utility.create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.notifHolder,
	}, {
		Utility.corner(4),
	})
	themed(notif, "BackgroundColor3", "Elevated")
	local stroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	stroke.Parent = notif
	themed(stroke, "Color", "Stroke")

	local indicator = Utility.create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = accentColor,
		BorderSizePixel = 0,
		Parent = notif,
	})

	local content = Utility.create("Frame", {
		Size = UDim2.new(1, -12, 0, 0),
		Position = UDim2.new(0, 12, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = notif,
	}, {
		Utility.pad(8, 8, 8, 8),
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		})
	})

	local titleLabel = Utility.create("TextLabel", {
		Text = title,
		Font = Theme.BodyFontBold,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		Parent = content,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontBold")

	local descLabel = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFont,
		TextSize = 10,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Parent = content,
	})
	themed(descLabel, "TextColor3", "SubText")
	themed(descLabel, "Font", "BodyFont")

	local progressContainer = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = content,
	})
	themed(progressContainer, "BackgroundColor3", "Stroke")

	local progressBar = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = accentColor,
		BorderSizePixel = 0,
		Parent = progressContainer,
	})

	notif.Position = UDim2.new(0, 30, 0, 0)
	Utility.tween(notif, {Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0}, 0.2)
	Utility.tween(progressBar, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

	task.delay(duration, function()
		if notif and notif.Parent then
			Utility.tween(notif, {Position = UDim2.new(0, 30, 0, 0), GroupTransparency = 1}, 0.15)
			task.wait(0.15)
			notif:Destroy()
		end
	end)
end

function Tab:AddSection(name)

	local targetColumn = self.leftColumn
	if self.leftColumn.UIListLayout.AbsoluteContentSize.Y > self.rightColumn.UIListLayout.AbsoluteContentSize.Y then
		targetColumn = self.rightColumn
	end

	local sectionWrapper = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = targetColumn,
	})

	local container = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 6),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = sectionWrapper,
	})
	local stroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	stroke.Parent = container
	themed(stroke, "Color", "Stroke")

	local sectionLabel = Utility.create("TextLabel", {
		Text = " " .. name .. " ",
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 10),
		Position = UDim2.new(0, 12, 0, 1),
		ZIndex = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sectionWrapper,
	})
	themed(sectionLabel, "TextColor3", "Text")
	themed(sectionLabel, "BackgroundColor3", "Background")
	themed(sectionLabel, "Font", "BodyFont")

	local contentHolder = Utility.create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = container,
	}, {
		Utility.pad(8, 8, 12, 8),
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
	})



	local section = setmetatable({
		tab = self,
		container = container,
		contentHolder = contentHolder,
	}, Section)

	table.insert(self.sections, section)

	if self.window.activeTab == self then
		revealSection(section, #self.sections)
	end

	return section
end

function Section:AddButton(text, callback)
	local section = self
	local btn = card(26)
	btn.Parent = section.contentHolder

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
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = btn,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	click.MouseButton1Click:Connect(function()
		Utility.tween(btn, {BackgroundColor3 = Theme.HoverStroke}, 0.05)
		task.delay(0.05, function()
			Utility.tween(btn, {BackgroundColor3 = Theme.Elevated}, 0.1)
		end)
		if callback then callback() end
	end)

	local api = {instance = btn}
	function api:AddToolTip(toolTipText)
		addToolTipToInstance(btn, section.tab.window, toolTipText)
		return api
	end

	table.insert(section.tab.window.controls, {text = text, instance = btn, section = section, tab = section.tab})
	return api
end

function Section:AddToggle(text, default, callback, flag)
	local defaultVal = default
	local flagName = flag
	if type(default) == "table" then
		defaultVal = default.default
		flagName = default.flag
	elseif type(default) == "function" then
		callback = default
		defaultVal = false
		flagName = nil
	end

	local section = self
	local toggle = card(26)
	toggle.Parent = section.contentHolder

	local track = Utility.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = toggle,
	})
	local trackStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	trackStroke.Parent = track
	themed(trackStroke, "Color", "Stroke")

	local fill = Utility.create("Frame", {
		Size = UDim2.new(1, -2, 1, -2),
		Position = UDim2.new(0, 1, 0, 1),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = track,
	})
	themed(fill, "BackgroundColor3", "Accent")

	local label = Utility.create("TextLabel", {
		Text = text,
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 30, 0, 0),
		Size = UDim2.new(1, -90, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toggle,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFont")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = toggle,
	})

	local state = defaultVal or false

	local function updateToggleStyle()
		Utility.tween(fill, {BackgroundTransparency = state and 0 or 1}, 0.1)
	end
	themed(track, "BackgroundColor3", updateToggleStyle)

	local api = {instance = toggle}
	function api:Set(value)
		state = value
		updateToggleStyle()
	end
	function api:Get() return state end

	api:Set(state)

	click.MouseButton1Click:Connect(function()
		api:Set(not state)
		if callback then callback(state) end
	end)

	function api:AddToolTip(toolTipText)
		addToolTipToInstance(toggle, section.tab.window, toolTipText)
		return api
	end

	function api:CreateKeybind(defaultBind, toggleCallback)
		local keybindHolder = Utility.create("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.new(0, 60, 0, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = toggle,
		})

		local keyLabel = Utility.create("TextLabel", {
			Text = defaultBind and ("[ " .. defaultBind.Name .. " ]") or "[ NONE ]",
			Font = Theme.BodyFontBold,
			TextSize = 9,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Parent = keybindHolder,
		})
		themed(keyLabel, "TextColor3", "SubText")
		themed(keyLabel, "Font", "BodyFontBold")

		local bindClick = Utility.create("TextButton", {
			Text = "", BackgroundTransparency = 1, ZIndex = 6, Size = UDim2.new(1, 0, 1, 0), Parent = keybindHolder,
		})

		local currentKey = defaultBind
		local listening = false
		local bindConn
		local gameplayConn

		local function updateGameplayListener()
			if gameplayConn then gameplayConn:Disconnect(); gameplayConn = nil end
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
			keyLabel.Text = "[ ... ]"
			if gameplayConn then gameplayConn:Disconnect(); gameplayConn = nil end

			bindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					currentKey = input.KeyCode
					keyLabel.Text = "[ " .. currentKey.Name .. " ]"
					listening = false
					bindConn:Disconnect()
					updateGameplayListener()
				end
			end)
		end)

		local keybindApi = {}
		function keybindApi:SetBind(key)
			currentKey = key
			keyLabel.Text = key and ("[ " .. key.Name .. " ]") or "[ NONE ]"
			updateGameplayListener()
		end
		function keybindApi:GetBind() return currentKey end
		return keybindApi
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = toggle, section = section, tab = section.tab})
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
	local flagName = options.flag

	min, max = min or 0, max or 100

	local function round(v)
		if step then v = math.round(v / step) * step end
		local mult = 10^precision
		return math.round(v * mult) / mult
	end

	local value = math.clamp(round(default or min), min, max)

	local slider = card(38)
	slider.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 3),
		Size = UDim2.new(1, -78, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slider,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local valueBox = Utility.create("TextBox", {
		Text = string.format("%." .. tostring(precision) .. "f", value) .. suffix,
		Font = Theme.BodyFontBold, TextSize = 10, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 3),
		Size = UDim2.new(0, 62, 0, 14), TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		Parent = slider,
	})
	themed(valueBox, "TextColor3", "SubText")
	themed(valueBox, "Font", "BodyFontBold")

	local bar = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 22), Size = UDim2.new(1, -16, 0, 4),
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = slider,
	})
	Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = bar

	local fill = Utility.create("Frame", {
		Size = UDim2.new((max - min) > 0 and ((value - min) / (max - min)) or 0, 0, 1, 0),
		BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Parent = bar,
	})
	themed(fill, "BackgroundColor3", "Accent")

	local dragButton = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 16),
		Position = UDim2.new(0, 0, 0, -8), Parent = bar,
	})

	local api = {instance = slider}
	local dragging = false
	local dragChangedConn, dragEndedConn

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
	end

	function api:Set(v)
		v = math.clamp(round(v), min, max)
		value = v
		local percent = (max - min) > 0 and ((v - min) / (max - min)) or 0
		Utility.tween(fill, {Size = UDim2.new(percent, 0, 1, 0)}, 0.1)
		valueBox.Text = string.format("%." .. tostring(precision) .. "f", v) .. suffix
	end
	function api:Get() return value end

	valueBox.FocusLost:Connect(function(enterPressed)
		local cleaned = valueBox.Text
		if suffix ~= "" then cleaned = string.gsub(cleaned, suffix, "") end
		local num = tonumber(cleaned)
		if num then
			api:Set(num)
			if callback then callback(value) end
		else
			api:Set(value)
		end
	end)

	dragButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromInput(input.Position.X)
			disconnectDrag()

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

	function api:AddToolTip(toolTipText)
		addToolTipToInstance(slider, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = slider, section = section, tab = section.tab})
	return api
end

function Section:AddTextbox(text, placeholder, callback, flag)
	local flagName = flag
	if type(placeholder) == "table" then
		flagName = placeholder.flag
		placeholder = placeholder.default or ""
	elseif type(placeholder) == "function" then
		callback = placeholder
		placeholder = ""
	end

	local section = self
	local box = card(26)
	box.Parent = section.contentHolder

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFont")

	local inputHolder = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.5, -8, 0, 18), BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0, Parent = box,
	})
	themed(inputHolder, "BackgroundColor3", "Background")
	local inputStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	inputStroke.Parent = inputHolder
	themed(inputStroke, "Color", "Stroke")

	local input = Utility.create("TextBox", {
		Text = "", PlaceholderText = placeholder or "",
		Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 4, 0, 0),
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
		instance = box,
		Set = function(_, text2) input.Text = text2 end,
		Get = function() return input.Text end,
	}
	function api:AddToolTip(toolTipText)
		addToolTipToInstance(box, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = box, section = section, tab = section.tab})
	return api
end

function Section:AddKeybind(text, default, callback, flag)
	local flagName = flag
	if type(default) == "table" then
		flagName = default.flag
		default = default.default
	end

	local section = self
	local bind = card(26)
	bind.Parent = section.contentHolder

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -98, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bind,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFont")

	local keyHolder = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 60, 0, 16), BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = bind,
	})
	local keyStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	keyStroke.Parent = keyHolder
	themed(keyStroke, "Color", "Stroke")

	local keyLabel = Utility.create("TextLabel", {
		Text = default and ("[ " .. default.Name:upper() .. " ]") or "[ NONE ]", Font = Theme.BodyFontBold, TextSize = 9,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0), Parent = keyHolder,
	})
	themed(keyLabel, "TextColor3", "SubText")
	themed(keyLabel, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.new(1, 0, 1, 0), Parent = bind,
	})

	local currentKey = default
	local listening = false
	local connection
	local gameplayConnection

	local function updateGameplayListener()
		if gameplayConnection then gameplayConnection:Disconnect(); gameplayConnection = nil end
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
		keyLabel.Text = "[ ... ]"
		if gameplayConnection then gameplayConnection:Disconnect(); gameplayConnection = nil end

		connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				currentKey = input.KeyCode
				keyLabel.Text = "[ " .. currentKey.Name:upper() .. " ]"
				listening = false
				connection:Disconnect()
				updateGameplayListener()
			end
		end)
	end)

	local api = {
		instance = bind,
		Set = function(_, key)
			currentKey = key
			keyLabel.Text = key and ("[ " .. key.Name:upper() .. " ]") or "[ NONE ]"
			updateGameplayListener()
		end,
		Get = function() return currentKey end,
	}
	function api:AddToolTip(toolTipText)
		addToolTipToInstance(bind, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName, 
		function() return currentKey and currentKey.Name or "None" end,
		function(val)
			if val == "None" then
				api:Set(nil)
			else
				api:Set(Enum.KeyCode[val])
			end
		end
	)
	table.insert(section.tab.window.controls, {text = text, instance = bind, section = section, tab = section.tab})
	return api
end

function Section:AddDropdown(text, options, default, callback, flag)
	local flagName = flag
	if type(default) == "table" then
		flagName = default.flag
		default = default.default
	end

	local section = self
	options = options or {}

	local CLOSED_HEIGHT = 38
	local ITEM_HEIGHT = 22
	local ITEM_SPACING = 3
	local SEARCH_BOX_HEIGHT = 20
	local LIST_TOP = 40
	local LIST_BOTTOM_PAD = 6

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
		Parent = section.contentHolder,
	}, {Utility.corner(4)})
	themed(dropdown, "BackgroundColor3", "Elevated")
	local dropdownStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	dropdownStroke.Parent = dropdown
	themed(dropdownStroke, "Color", "Stroke")
	Utility.hoverGlow(dropdown, dropdownStroke)

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 3),
		Size = UDim2.new(1, -16, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dropdown,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local selector = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 18), Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = dropdown,
	}, {Utility.corner(2)})
	themed(selector, "BackgroundColor3", "Panel")
	local selectorStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	selectorStroke.Parent = selector
	themed(selectorStroke, "Color", "Stroke")

	local selectedLabel = Utility.create("TextLabel", {
		Text = tostring(default or "Select"), Font = Theme.BodyFont, TextSize = 10,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -28, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = selector,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("TextLabel", {
		Text = "v", Font = Theme.BodyFontBold, TextSize = 9, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.new(0, 12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = selector,
	})
	themed(arrow, "TextColor3", "Text")
	themed(arrow, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = selector,
	})

	local searchHolder = Utility.create("Frame", {
		Size = UDim2.new(1, -16, 0, SEARCH_BOX_HEIGHT),
		Position = UDim2.new(0, 8, 0, LIST_TOP),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = dropdown,
	}, {Utility.corner(3)})
	themed(searchHolder, "BackgroundColor3", "Panel")
	local searchStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	searchStroke.Parent = searchHolder
	themed(searchStroke, "Color", "Stroke")

	local searchInput = Utility.create("TextBox", {
		Text = "", PlaceholderText = "Search...",
		Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Parent = searchHolder,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	local list = Utility.create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 8, 0, LIST_TOP + SEARCH_BOX_HEIGHT + 6),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = dropdown,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ITEM_SPACING)}),
		Utility.create("UIPadding", {PaddingBottom = UDim.new(0, LIST_BOTTOM_PAD)}),
	})

	local noResults = Utility.create("TextLabel", {
		Text = "No matches", Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, LayoutOrder = 9999,
		Parent = list,
	})
	themed(noResults, "TextColor3", "SubText")
	themed(noResults, "Font", "BodyFont")

	local open = false
	local activeSearchText = ""
	local api = {instance = dropdown}

	local function filterItems()
		local visibleCount = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local match = string.find(string.lower(child.Text), string.lower(activeSearchText), 1, true) ~= nil
				child.Visible = match
				if match then visibleCount = visibleCount + 1 end
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
				Text = tostring(opt), Font = Theme.BodyFont, TextSize = 11,
				TextColor3 = Theme.Text, BackgroundColor3 = Theme.Panel,
				AutoButtonColor = false, Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
				BorderSizePixel = 0, Parent = list,
			}, {Utility.corner(3)})
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

	function api:AddToolTip(toolTipText)
		addToolTipToInstance(dropdown, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = dropdown, section = section, tab = section.tab})
	return api
end

function Section:AddMultiDropdown(text, options, defaults, callback, flag)
	local flagName = flag
	if type(defaults) == "table" and not defaults[1] and defaults.default then
		flagName = defaults.flag
		defaults = defaults.default
	end

	local section = self
	options = options or {}

	local CLOSED_HEIGHT = 38
	local ITEM_HEIGHT = 22
	local ITEM_SPACING = 3
	local SEARCH_BOX_HEIGHT = 20
	local LIST_TOP = 40
	local LIST_BOTTOM_PAD = 6

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
		Parent = section.contentHolder,
	}, {Utility.corner(4)})
	themed(dropdown, "BackgroundColor3", "Elevated")
	local dropdownStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	dropdownStroke.Parent = dropdown
	themed(dropdownStroke, "Color", "Stroke")
	Utility.hoverGlow(dropdown, dropdownStroke)

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 3),
		Size = UDim2.new(1, -16, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dropdown,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local selector = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 18), Size = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = dropdown,
	}, {Utility.corner(2)})
	themed(selector, "BackgroundColor3", "Panel")
	local selectorStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	selectorStroke.Parent = selector
	themed(selectorStroke, "Color", "Stroke")

	local selectedLabel = Utility.create("TextLabel", {
		Text = "None", Font = Theme.BodyFont, TextSize = 10,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -28, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = selector,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("TextLabel", {
		Text = "v", Font = Theme.BodyFontBold, TextSize = 9, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(1, -18, 0, 0),
		Size = UDim2.new(0, 12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = selector,
	})
	themed(arrow, "TextColor3", "Text")
	themed(arrow, "Font", "BodyFontBold")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5,
		Size = UDim2.new(1, 0, 1, 0), Parent = selector,
	})

	local searchHolder = Utility.create("Frame", {
		Size = UDim2.new(1, -16, 0, SEARCH_BOX_HEIGHT),
		Position = UDim2.new(0, 8, 0, LIST_TOP),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = dropdown,
	}, {Utility.corner(3)})
	themed(searchHolder, "BackgroundColor3", "Panel")
	local searchStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	searchStroke.Parent = searchHolder
	themed(searchStroke, "Color", "Stroke")

	local searchInput = Utility.create("TextBox", {
		Text = "", PlaceholderText = "Search...",
		Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
		Parent = searchHolder,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	local list = Utility.create("Frame", {
		Size = UDim2.new(1, -16, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, 8, 0, LIST_TOP + SEARCH_BOX_HEIGHT + 6),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = dropdown,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, ITEM_SPACING)}),
		Utility.create("UIPadding", {PaddingBottom = UDim.new(0, LIST_BOTTOM_PAD)}),
	})

	local noResults = Utility.create("TextLabel", {
		Text = "No matches", Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.SubText,
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
	local api = {instance = dropdown}

	for _, v in ipairs(defaults or {}) do selected[tostring(v)] = true end

	local function currentSelection()
		local result = {}
		for _, opt in ipairs(options) do
			if selected[tostring(opt)] then table.insert(result, opt) end
		end
		return result
	end

	local function updateSelectedLabel()
		local picks = currentSelection()
		if #picks == 0 then selectedLabel.Text = "None"
		elseif #picks == 1 then selectedLabel.Text = tostring(picks[1])
		else selectedLabel.Text = #picks .. " selected" end
	end

	local function filterItems()
		local visibleCount = 0
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then
				local match = string.find(string.lower(child.Text), string.lower(activeSearchText), 1, true) ~= nil
				child.Visible = match
				if match then visibleCount = visibleCount + 1 end
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
				Text = key, TextTransparency = 1, Font = Theme.BodyFont, TextSize = 11,
				BackgroundColor3 = Theme.Panel, AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, ITEM_HEIGHT), BorderSizePixel = 0, Parent = list,
			}, {Utility.corner(3)})
			themed(item, "BackgroundColor3", "Panel")

			local box = Utility.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Theme.Panel,
				BorderSizePixel = 0, Parent = item,
			}, {Utility.corner(2)})
			Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {}).Parent = box
			themed(box.UIStroke, "Color", "Stroke")

			local check = Utility.create("TextLabel", {
				Text = "✓", Font = Theme.BodyFontBold, TextSize = 10, TextColor3 = Theme.Accent,
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center, Visible = selected[key] == true,
				Parent = box,
			})
			themed(check, "TextColor3", "Accent")

			local label = Utility.create("TextLabel", {
				Text = key, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
				BackgroundTransparency = 1, Position = UDim2.new(0, 26, 0, 0),
				Size = UDim2.new(1, -32, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
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
		for _, opt in ipairs(options) do stillValid[tostring(opt)] = true end
		for key in pairs(selected) do
			if not stillValid[key] then selected[key] = nil end
		end
		rebuild(options)
		updateSelectedLabel()
		if open then
			local visibleCount = 0
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then visibleCount = visibleCount + 1 end
			end
			dropdown.Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))
		end
	end

	function api:Get() return currentSelection() end

	function api:Set(values)
		selected = {}
		for _, v in ipairs(values or {}) do selected[tostring(v)] = true end
		for key, check in pairs(checkboxes) do check.Visible = selected[key] == true end
		updateSelectedLabel()
	end

	click.MouseButton1Click:Connect(function()
		if open then close()
		else
			open = true
			list.Visible = true
			searchHolder.Visible = true
			local visibleCount = 0
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") and child.Visible then visibleCount = visibleCount + 1 end
			end
			Utility.tween(dropdown, {Size = UDim2.new(1, 0, 0, openHeightFor(visibleCount))}, 0.15)
			Utility.tween(arrow, {Rotation = 180}, 0.15)
		end
	end)

	function api:AddToolTip(toolTipText)
		addToolTipToInstance(dropdown, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = dropdown, section = section, tab = section.tab})
	return api
end

function Section:AddColorPicker(text, default, callback, flag)
	local flagName = flag
	if type(default) == "table" and not default.R then
		flagName = default.flag
		default = default.default
	end

	local section = self
	default = default or Color3.fromRGB(140, 20, 20)

	local picker = card(26)
	picker.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 12, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = picker,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local swatch = Utility.create("TextButton", {
		Text = "", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 32, 0, 14), BackgroundColor3 = default,
		BorderSizePixel = 0, Parent = picker,
	}, {Utility.corner(2)})
	local swatchStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	swatchStroke.Parent = swatch
	themed(swatchStroke, "Color", "Stroke")

	local panel = Utility.create("Frame", {
		Size = UDim2.new(0, 180, 0, 205),
		BackgroundColor3 = Theme.Elevated,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9999,
		Parent = section.tab.window.screenGui,
	}, {Utility.corner(4), Utility.pad(10)})
	themed(panel, "BackgroundColor3", "Elevated")
	local panelStroke = Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1, Transparency = 0.4}, {})
	panelStroke.Parent = panel
	themed(panelStroke, "Color", "Accent")

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
		BorderSizePixel = 0, ZIndex = 26, Parent = svBox,
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
		BorderSizePixel = 0, ZIndex = 26, Parent = hueBar,
	}, {Utility.corner(2)})

	local svCapture = Utility.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 25,
		Parent = svBox,
	})

	local hueCapture = Utility.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 25,
		Parent = hueBar,
	})

	local rgbInputHolder = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 126),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = panel,
	}, {Utility.corner(2)})
	themed(rgbInputHolder, "BackgroundColor3", "Panel")
	local rgbStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	rgbStroke.Parent = rgbInputHolder
	themed(rgbStroke, "Color", "Stroke")

	local rgbInput = Utility.create("TextBox", {
		Text = "", PlaceholderText = "RGB: 140, 20, 20",
		Font = Theme.BodyFont, TextSize = 10, TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText, BackgroundTransparency = 1,
		Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center, ClearTextOnFocus = false,
		Parent = rgbInputHolder,
	})
	themed(rgbInput, "TextColor3", "Text")
	themed(rgbInput, "PlaceholderColor3", "SubText")
	themed(rgbInput, "Font", "BodyFont")

	local presets = {
		Color3.fromRGB(68, 90, 255),
		Color3.fromRGB(156, 39, 176),
		Color3.fromRGB(33, 150, 243),
		Color3.fromRGB(76, 175, 80),
		Color3.fromRGB(244, 67, 54),
		Color3.fromRGB(255, 152, 0),
	}

	local presetsHolder = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 154),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Utility.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})

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

	for _, col in ipairs(presets) do
		local presetBtn = Utility.create("TextButton", {
			Text = "",
			Size = UDim2.new(0, 14, 0, 14),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			Parent = presetsHolder,
		}, {Utility.corner(7)})

		presetBtn.MouseButton1Click:Connect(function()
			hue, sat, val = Color3.toHSV(col)
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			updateColor()
		end)
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
					math.clamp((input.Position.X - svCapture.AbsolutePosition.X) / svCapture.AbsoluteSize.X, 0, 1),
					math.clamp((input.Position.Y - svCapture.AbsolutePosition.Y) / svCapture.AbsoluteSize.Y, 0, 1)
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

	svCapture.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragSV = true
			local rel = Vector2.new(
				math.clamp((input.Position.X - svCapture.AbsolutePosition.X) / svCapture.AbsoluteSize.X, 0, 1),
				math.clamp((input.Position.Y - svCapture.AbsolutePosition.Y) / svCapture.AbsoluteSize.Y, 0, 1)
			)
			sat, val = rel.X, 1 - rel.Y
			svCursor.Position = UDim2.new(rel.X, 0, rel.Y, 0)
			updateColor()
			startDrag()
		end
	end)

	hueCapture.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragHue = true
			local percent = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
			hue = percent
			hueCursor.Position = UDim2.new(percent, 0, 0.5, 0)
			updateColor()
			startDrag()
		end
	end)

	local open = false
	swatch.MouseButton1Click:Connect(function()
		open = not open
		if open then
			panel.Position = UDim2.new(0, swatch.AbsolutePosition.X - 190, 0, swatch.AbsolutePosition.Y)
			panel.Visible = true
		else
			panel.Visible = false
		end
	end)

	local visibilityConn
	pcall(function()
		visibilityConn = swatch:GetPropertyChangedSignal("AbsoluteVisible"):Connect(function()
			if not swatch.AbsoluteVisible then
				open = false
				panel.Visible = false
			end
		end)
	end)
	if visibilityConn then
		section.tab.window:RegisterConnection(visibilityConn)
	end

	local api = {
		instance = picker,
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

	function api:AddToolTip(toolTipText)
		addToolTipToInstance(picker, section.tab.window, toolTipText)
		return api
	end

	registerFlag(section.tab.window, flagName,
		function()
			local col = api:Get()
			return {col.R, col.B, col.G}
		end,
		function(valTable)
			if type(valTable) == "table" then
				api:Set(Color3.new(valTable[1], valTable[2], valTable[3]))
			end
		end
	)
	table.insert(section.tab.window.controls, {text = text, instance = picker, section = section, tab = section.tab})
	return api
end

function Section:AddLabel(text)
	local section = self
	local labelFrame = Utility.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		BorderSizePixel = 0,
		Parent = self.contentHolder,
	})

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 4, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Parent = labelFrame,
	})
	themed(label, "TextColor3", "SubText")
	themed(label, "Font", "BodyFont")

	local api = {instance = labelFrame}
	function api:SetText(newText) label.Text = newText end
	function api:AddToolTip(toolTipText)
		addToolTipToInstance(labelFrame, section.tab.window, toolTipText)
		return api
	end
	return api
end

function Section:AddParagraph(title, desc)
	local section = self
	local para = Utility.create("Frame", {
		BackgroundColor3 = Theme.Elevated, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
		Parent = self.contentHolder,
	}, {
		Utility.corner(4),
		Utility.pad(6),
	})
	themed(para, "BackgroundColor3", "Elevated")
	local paraStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	paraStroke.Parent = para
	themed(paraStroke, "Color", "Stroke")

	local titleLabel = Utility.create("TextLabel", {
		Text = title, Font = Theme.BodyFontBold, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = para,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontBold")

	local descLabel = Utility.create("TextLabel", {
		Text = desc, Font = Theme.BodyFont, TextSize = 10, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Position = UDim2.new(0, 0, 0, 16), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		Parent = para,
	})
	themed(descLabel, "TextColor3", "SubText")
	themed(descLabel, "Font", "BodyFont")

	local api = {instance = para}
	function api:Set(newTitle, newDesc)
		titleLabel.Text = newTitle
		descLabel.Text = newDesc
	end
	function api:AddToolTip(toolTipText)
		addToolTipToInstance(para, section.tab.window, toolTipText)
		return api
	end
	return api
end

function Section:AddDivider()
	local section = self
	local div = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundTransparency = 1,
		Parent = section.contentHolder,
	}, {
		Utility.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -12, 0, 1),
			BackgroundColor3 = Theme.Stroke,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
		})
	})
	themed(div.Frame, "BackgroundColor3", "Stroke")
	return div
end

function Section:AddConsole(height)
	local section = self
	height = height or 100
	
	local consoleFrame = card(height)
	consoleFrame.Parent = section.contentHolder
	
	local scroll = Utility.create("ScrollingFrame", {
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.new(0, 5, 0, 5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = consoleFrame,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}),
	})
	themed(scroll, "ScrollBarImageColor3", "Accent")
	
	local consoleApi = {instance = consoleFrame}
	
	function consoleApi:Log(logText, typeName)
		typeName = typeName or "Info"
		local color = Theme.Text
		if typeName == "Success" then
			color = Color3.fromRGB(46, 204, 113)
		elseif typeName == "Warning" then
			color = Color3.fromRGB(241, 196, 15)
		elseif typeName == "Error" then
			color = Color3.fromRGB(231, 76, 60)
		elseif typeName == "Info" then
			color = Theme.SubText
		end
		
		local timestamp = os.date("%H:%M:%S")
		local lineText = string.format("[%s] [%s] %s", timestamp, typeName:upper(), logText)
		
		local label = Utility.create("TextLabel", {
			Text = lineText,
			Font = Theme.BodyFont,
			TextSize = 9,
			TextColor3 = color,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = scroll,
		})
		themed(label, "Font", "BodyFont")
		
		task.delay(0.05, function()
			scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
		end)
	end
	
	function consoleApi:Clear()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextLabel") then child:Destroy() end
		end
	end
	
	return consoleApi
end

function Section:AddGraph(title, minVal, maxVal, height)
	local section = self
	height = height or 60
	minVal = minVal or 0
	maxVal = maxVal or 100
	
	local graphFrame = card(height + 24)
	graphFrame.Parent = section.contentHolder
	
	local titleLabel = Utility.create("TextLabel", {
		Text = title,
		Font = Theme.BodyFontMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 3),
		Size = UDim2.new(1, -16, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = graphFrame,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")
	
	local plotArea = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 20),
		Size = UDim2.new(1, -16, 1, -26),
		BackgroundTransparency = 1,
		Parent = graphFrame,
	})
	
	local points = {}
	local maxPoints = 20
	
	local graphApi = {instance = graphFrame}
	
	function graphApi:AddValue(val)
		table.insert(points, val)
		if #points > maxPoints then table.remove(points, 1) end
		
		for _, child in ipairs(plotArea:GetChildren()) do child:Destroy() end
		
		local areaSize = plotArea.AbsoluteSize
		local pointCount = #points
		if pointCount < 2 then return end
		
		local stepX = areaSize.X / (maxPoints - 1)
		
		for i = 1, pointCount do
			local currentVal = points[i]
			local percentY = math.clamp((currentVal - minVal) / (maxVal - minVal), 0, 1)
			
			local bar = Utility.create("Frame", {
				BackgroundColor3 = Theme.Accent,
				BorderSizePixel = 0,
				Position = UDim2.new(0, (i - 1) * stepX, 1 - percentY, 0),
				Size = UDim2.new(0, math.max(2, stepX - 2), percentY, 0),
				Parent = plotArea,
			}, {
				Utility.corner(1),
			})
			themed(bar, "BackgroundColor3", "Accent")
		end
	end
	
	return graphApi
end

Zyren.Theme = Theme
return Zyren
