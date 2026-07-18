local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

-- ============================================================================
-- THEME & DESIGN SYSTEM (ROSAVA DESIGN SYSTEM)
-- ============================================================================
local Theme = {
	Background = Color3.fromRGB(30, 24, 28),     -- Dark Maroon Background
	Sidebar    = Color3.fromRGB(24, 18, 22),     -- Darker Sidebar
	Panel      = Color3.fromRGB(42, 32, 39),     -- Card Panel / Section Cards
	Elevated   = Color3.fromRGB(54, 40, 50),     -- Interactive elements
	Stroke     = Color3.fromRGB(68, 48, 60),     -- Muted Borders
	HoverStroke = Color3.fromRGB(152, 60, 80),   -- Vibrant Rose Red (Hover/Active)
	Accent     = Color3.fromRGB(152, 60, 80),     -- Rose Accent
	AccentDim  = Color3.fromRGB(110, 40, 56),     -- Darker Rose
	Text       = Color3.fromRGB(245, 230, 235),   -- Off-white Cream Text
	SubText    = Color3.fromRGB(180, 150, 160),   -- Muted Pinkish Text

	TitleFont      = Enum.Font.GothamBold,
	BodyFont       = Enum.Font.Gotham,
	BodyFontMedium = Enum.Font.GothamMedium,
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

-- ============================================================================
-- UTILITIES
-- ============================================================================
local Utility = {}

function Utility.create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		if child then child.Parent = inst end
	end
	return inst
end

function Utility.corner(radius)
	return Utility.create("UICorner", {CornerRadius = UDim.new(0, radius or 8)})
end

function Utility.pad(all, right, top, bottom)
	return Utility.create("UIPadding", {
		PaddingTop = UDim.new(0, top or all),
		PaddingBottom = UDim.new(0, bottom or top or all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, right or all),
	})
end

local ActiveTweens = setmetatable({}, {__mode = "k"})

function Utility.tween(inst, props, duration, style, dir, key)
	if not inst then return end
	key = key or "_default"
	local bucket = ActiveTweens[inst]
	if not bucket then bucket = {}; ActiveTweens[inst] = bucket end
	if bucket[key] then bucket[key]:Cancel() end

	local info = TweenInfo.new(duration or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local t
	pcall(function() t = TweenService:Create(inst, info, props) end)
	if t then
		bucket[key] = t
		local success = pcall(function() t:Play() end)
		if not success then
			for k, v in pairs(props) do pcall(function() inst[k] = v end) end
		end
	else
		for k, v in pairs(props) do pcall(function() inst[k] = v end) end
	end
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
		for _, onMove in pairs(DragRegistry) do onMove(input) end
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

-- ============================================================================
-- CLASS DECLARATIONS
-- ============================================================================
local Zyren = {}
Zyren.__index = Zyren

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local Folder = {}
Folder.__index = function(self, key)
	return Folder[key] or Section[key]
end

-- ============================================================================
-- KEY VERIFICATION SYSTEM CORE
-- ============================================================================
local KeySystemUrl = "https://dami.lol"

local function getClipboard()
	if getclipboard then return getclipboard() end
	if toclipboard then return toclipboard() end
	return ""
end

local function setClipboard(text)
	if setclipboard then setclipboard(text)
	elseif toclipboard then toclipboard(text)
	elseif syn and syn.write_clipboard then syn.write_clipboard(text)
	end
end

local function verifyKey(key)
	local success, result = pcall(function()
		return game:HttpGet(KeySystemUrl .. "/api/verify?key=" .. HttpService:UrlEncode(key))
	end)
	if success and result then
		local data = HttpService:JSONDecode(result)
		if data and data.valid then
			return true
		end
	end
	return false
end

-- ============================================================================
-- CONSTRUCTOR: Zyren.new()
-- ============================================================================
function Zyren.new(options)
	local title = "Zyren"
	local config = {}
	if type(options) == "table" then
		title = options.Title or "Zyren"
		config = options
	elseif type(options) == "string" then
		title = options
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

	-- Tooltip frame
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

	-- ============================================================================
	-- MAIN OVERHAULED GUI WINDOW
	-- ============================================================================
	local main = Utility.create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 600, 0, 420),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Visible = false, -- Shown only after Key passes
		Parent = screenGui,
	}, {
		Utility.corner(16)
	})
	themed(main, "BackgroundColor3", "Background")
	
	local windowStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1, Transparency = 0.2}, {})
	windowStroke.Parent = main
	themed(windowStroke, "Color", "Stroke")

	-- SIDEBAR
	local sidebar = Utility.create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 180, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = main,
	}, {
		Utility.corner(16)
	})
	themed(sidebar, "BackgroundColor3", "Sidebar")

	-- Mask Sidebar right corners
	local sidebarMask = Utility.create("Frame", {
		Name = "SidebarMask",
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(1, -20, 0, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	themed(sidebarMask, "BackgroundColor3", "Sidebar")

	local logoText = Utility.create("TextLabel", {
		Text = "DAMI",
		Font = Theme.TitleFont,
		TextSize = 15,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 0, 20),
		Size = UDim2.new(0, 100, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})
	themed(logoText, "TextColor3", "Text")
	themed(logoText, "Font", "TitleFont")

	-- Sidebar Tab List
	local tabList = Utility.create("ScrollingFrame", {
		Name = "TabList",
		Position = UDim2.new(0, 10, 0, 65),
		Size = UDim2.new(1, -20, 1, -85),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}, {
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
	})

	-- CONTENT AREA
	local contentArea = Utility.create("Frame", {
		Name = "Content",
		Position = UDim2.new(0, 180, 0, 0),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundTransparency = 1,
		Parent = main,
	})

	-- Drag functionality for TopBar/Header
	local topBar = Utility.create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		Parent = contentArea,
	})
	Utility.drag(topBar, main)

	-- User Info Card
	local headshotImage = "rbxassetid://6077189184" -- fallback avatar
	pcall(function()
		headshotImage = game:GetService("Players"):GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	end)

	local userCard = Utility.create("Frame", {
		Name = "UserCard",
		Position = UDim2.new(0, 15, 0, 10),
		Size = UDim2.new(0, 210, 0, 34),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {
		Utility.corner(17)
	})
	themed(userCard, "BackgroundColor3", "Panel")

	local userAvatar = Utility.create("ImageLabel", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(0, 4, 0, 4),
		Image = headshotImage,
		BackgroundTransparency = 1,
		Parent = userCard,
	}, {
		Utility.corner(13)
	})

	local userDisplayName = Utility.create("TextLabel", {
		Text = Player.DisplayName,
		Font = Theme.BodyFontMedium,
		TextSize = 10,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 36, 0, 3),
		Size = UDim2.new(1, -42, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = userCard,
	})
	themed(userDisplayName, "TextColor3", "Text")
	themed(userDisplayName, "Font", "BodyFontMedium")

	local userUsername = Utility.create("TextLabel", {
		Text = "@" .. Player.Name,
		Font = Theme.BodyFont,
		TextSize = 8,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 36, 0, 15),
		Size = UDim2.new(1, -42, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = userCard,
	})
	themed(userUsername, "TextColor3", "SubText")
	themed(userUsername, "Font", "BodyFont")

	-- Header Buttons (Discord & Close)
	local discordBtn = Utility.create("TextButton", {
		Name = "DiscordBtn",
		Text = "",
		Position = UDim2.new(1, -85, 0, 10),
		Size = UDim2.new(0, 32, 0, 32),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {
		Utility.corner(16),
		Utility.create("ImageLabel", {
			Size = UDim2.new(0, 16, 0, 16),
			Position = UDim2.new(0.5, -8, 0.5, -8),
			Image = "rbxassetid://6031466847", -- Discord logo
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
		})
	})
	themed(discordBtn, "BackgroundColor3", "Panel")
	themed(discordBtn.ImageLabel, "ImageColor3", "Text")
	
	discordBtn.MouseButton1Click:Connect(function()
		setClipboard("https://discord.gg/m6YTVkRZ34")
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Dami",
			Text = "Discord link copied to clipboard!",
			Duration = 3
		})
	end)

	local closeButton = Utility.create("TextButton", {
		Name = "CloseBtn",
		Text = "",
		Position = UDim2.new(1, -45, 0, 10),
		Size = UDim2.new(0, 32, 0, 32),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {
		Utility.corner(16),
		Utility.create("ImageLabel", {
			Size = UDim2.new(0, 14, 0, 14),
			Position = UDim2.new(0.5, -7, 0.5, -7),
			Image = "rbxassetid://6031094678", -- Cross close
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
		})
	})
	themed(closeButton, "BackgroundColor3", "Panel")
	themed(closeButton.ImageLabel, "ImageColor3", "Text")
	closeButton.MouseButton1Click:Connect(function() screenGui:Destroy() end)

	-- Search Bar
	local searchHolder = Utility.create("Frame", {
		Name = "SearchHolder",
		Position = UDim2.new(0, 240, 0, 10),
		Size = UDim2.new(1, -340, 0, 32),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = topBar,
	}, {
		Utility.corner(16)
	})
	themed(searchHolder, "BackgroundColor3", "Panel")

	local searchInput = Utility.create("TextBox", {
		Text = "",
		PlaceholderText = "Search features...",
		Font = Theme.BodyFont,
		TextSize = 11,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchInput,
	})
	themed(searchInput, "TextColor3", "Text")
	themed(searchInput, "PlaceholderColor3", "SubText")
	themed(searchInput, "Font", "BodyFont")

	-- Dropdown Overlays (Popup Modals)
	local dropdownOverlay = Utility.create("Frame", {
		Name = "DropdownOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 50,
		Parent = main,
	})

	local pageContainer = Utility.create("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 0, 0, 52),
		Size = UDim2.new(1, 0, 1, -72),
		BackgroundTransparency = 1,
		Parent = contentArea,
	})

	-- Footer Bar
	local footer = Utility.create("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		Parent = contentArea,
	})
	themed(footer, "BackgroundColor3", "Sidebar")

	local statsLabel = Utility.create("TextLabel", {
		Text = "FPS: ... | Ping: ... ms | Executor: ...",
		Font = Theme.BodyFont,
		TextSize = 9,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 15, 0, 0),
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
		Size = UDim2.new(0, 105, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = footer,
	})
	themed(timeLabel, "TextColor3", "SubText")
	themed(timeLabel, "Font", "BodyFont")

	-- telemetry counters
	local fpsCount = 0
	local lastFpsUpdate = os.clock()
	local fps = 60
	local telemetryConn = RunService.RenderStepped:Connect(function()
		fpsCount += 1
		local now = os.clock()
		if now - lastFpsUpdate >= 1 then
			fps = fpsCount
			fpsCount = 0
			lastFpsUpdate = now
		end
	end)

	task.spawn(function()
		while task.wait(1) do
			if not main.Parent then break end
			timeLabel.Text = os.date("%I:%M:%S %p")
			local ping = "N/A"
			pcall(function() ping = math.round(Player:GetNetworkPing() * 1000) end)
			local executor = identifyexecutor and identifyexecutor() or (getexecutorname and getexecutorname() or "Studio")
			statsLabel.Text = string.format("FPS: %d | Ping: %s ms | Executor: %s", fps, tostring(ping), executor)
		end
	end)

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
		connections = {},
		toolTip = toolTip,
		toolTipLabel = toolTipLabel,
		dropdownOverlay = dropdownOverlay,
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

	-- Search filter
	local function filterControls(query)
		query = string.lower(query)
		local tabHasMatches = {}
		local sectionHasMatches = {}

		for _, ctrl in ipairs(self.controls) do
			local match = query == "" or string.find(string.lower(ctrl.text), query, 1, true) ~= nil
			ctrl.instance.Visible = match
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

	-- ============================================================================
	-- KEY SYSTEM GUI OVERLAY
	-- ============================================================================
	local keySystemFrame = Utility.create("Frame", {
		Name = "KeySystemFrame",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 15, 18),
		BorderSizePixel = 0,
		Parent = screenGui,
	})





	-- Centered card
	local keyCard = Utility.create("Frame", {
		Name = "KeyCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, 380, 0, 200),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = keySystemFrame,
	}, {
		Utility.corner(12),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
	})
	themed(keyCard, "BackgroundColor3", "Panel")
	themed(keyCard.UIStroke, "Color", "Stroke")

	local welcomeLabel = Utility.create("TextLabel", {
		Text = "Welcome to",
		Font = Theme.BodyFont,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 20),
		Size = UDim2.new(1, 0, 0, 16),
		Parent = keyCard,
	})
	themed(welcomeLabel, "TextColor3", "SubText")
	themed(welcomeLabel, "Font", "BodyFont")

	local brandLabel = Utility.create("TextLabel", {
		Text = "DAMI.LOL",
		Font = Theme.TitleFont,
		TextSize = 22,
		TextColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = keyCard,
	})
	themed(brandLabel, "TextColor3", "Accent")
	themed(brandLabel, "Font", "TitleFont")

	-- Key textbox wrapper
	local keyInputWrapper = Utility.create("Frame", {
		Name = "KeyInputWrapper",
		Position = UDim2.new(0, 30, 0, 80),
		Size = UDim2.new(1, -60, 0, 32),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Parent = keyCard,
	}, {
		Utility.corner(6),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
	})
	themed(keyInputWrapper, "BackgroundColor3", "Background")
	themed(keyInputWrapper.UIStroke, "Color", "Stroke")

	local shieldIcon = Utility.create("ImageLabel", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(0, 10, 0.5, -8),
		Image = "rbxassetid://6031075926",
		BackgroundTransparency = 1,
		ImageColor3 = Theme.SubText,
		Parent = keyInputWrapper,
	})
	themed(shieldIcon, "ImageColor3", "SubText")

	local keyTextBox = Utility.create("TextBox", {
		Text = "",
		PlaceholderText = "DAMI-XXXX-XXXX-XXXX",
		Font = Theme.BodyFont,
		TextSize = 11,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 32, 0, 0),
		Size = UDim2.new(1, -42, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = keyInputWrapper,
	})
	themed(keyTextBox, "TextColor3", "Text")
	themed(keyTextBox, "PlaceholderColor3", "SubText")
	themed(keyTextBox, "Font", "BodyFont")

	-- Button Group
	local buttonGroup = Utility.create("Frame", {
		Position = UDim2.new(0, 30, 0, 126),
		Size = UDim2.new(1, -60, 0, 32),
		BackgroundTransparency = 1,
		Parent = keyCard,
	}, {
		Utility.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10),
		})
	})

	local exitBtn = Utility.create("TextButton", {
		Text = "  Exit",
		Font = Theme.BodyFontMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Background,
		Size = UDim2.new(0.3, -5, 1, 0),
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = buttonGroup,
	}, {
		Utility.corner(6),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}),
		Utility.create("ImageLabel", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, 8, 0.5, -6),
			Image = "rbxassetid://6031094678",
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
		})
	})
	themed(exitBtn, "TextColor3", "Text")
	themed(exitBtn, "BackgroundColor3", "Background")
	themed(exitBtn.UIStroke, "Color", "Stroke")
	themed(exitBtn.ImageLabel, "ImageColor3", "Text")

	exitBtn.MouseButton1Click:Connect(function()
		screenGui:Destroy()
	end)

	local pasteBtn = Utility.create("TextButton", {
		Text = "  Paste",
		Font = Theme.BodyFontMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Background,
		Size = UDim2.new(0.3, -5, 1, 0),
		BorderSizePixel = 0,
		LayoutOrder = 2,
		Parent = buttonGroup,
	}, {
		Utility.corner(6),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}),
		Utility.create("ImageLabel", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, 8, 0.5, -6),
			Image = "rbxassetid://6031441267",
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
		})
	})
	themed(pasteBtn, "TextColor3", "Text")
	themed(pasteBtn, "BackgroundColor3", "Background")
	themed(pasteBtn.UIStroke, "Color", "Stroke")
	themed(pasteBtn.ImageLabel, "ImageColor3", "Text")

	local getKeyBtn = Utility.create("TextButton", {
		Text = "  Get Key",
		Font = Theme.BodyFontMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundColor3 = Theme.Background,
		Size = UDim2.new(0.4, 0, 1, 0),
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = buttonGroup,
	}, {
		Utility.corner(6),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}),
		Utility.create("ImageLabel", {
			Size = UDim2.new(0, 12, 0, 12),
			Position = UDim2.new(0, 8, 0.5, -6),
			Image = "rbxassetid://6031087568",
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
		})
	})
	themed(getKeyBtn, "TextColor3", "Text")
	themed(getKeyBtn, "BackgroundColor3", "Background")
	themed(getKeyBtn.UIStroke, "Color", "Stroke")
	themed(getKeyBtn.ImageLabel, "ImageColor3", "Text")

	local statusLabel = Utility.create("TextLabel", {
		Text = "Awaiting key verification...",
		Font = Theme.BodyFont,
		TextSize = 10,
		TextColor3 = Theme.SubText,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 168),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = keyCard,
	})
	themed(statusLabel, "TextColor3", "SubText")
	themed(statusLabel, "Font", "BodyFont")

	local function checkInputKey(key)
		statusLabel.TextColor3 = Theme.SubText
		statusLabel.Text = "Verifying key..."
		task.wait(0.5)
		if verifyKey(key) then
			statusLabel.TextColor3 = Color3.fromRGB(46, 204, 113)
			statusLabel.Text = "Success! Access Granted."
			task.wait(1)
			if writefile then
				pcall(writefile, "dami_key.txt", key)
			end
			Utility.tween(keySystemFrame, {BackgroundTransparency = 1}, 0.25)
			Utility.tween(keyCard, {Size = UDim2.new(0, 0, 0, 0)}, 0.25)
			task.wait(0.25)
			keySystemFrame:Destroy()
			main.Visible = true
		else
			statusLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
			statusLabel.Text = "Invalid or expired key. Please get a new one."
		end
	end

	pasteBtn.MouseButton1Click:Connect(function()
		local clip = getClipboard()
		if clip and clip ~= "" then
			keyTextBox.Text = clip
			checkInputKey(clip)
		end
	end)

	getKeyBtn.MouseButton1Click:Connect(function()
		local genUrl = KeySystemUrl .. "/getkey?hwid=" .. Player.UserId
		setClipboard(genUrl)
		statusLabel.TextColor3 = Theme.Accent
		statusLabel.Text = "Key link copied to clipboard!"
	end)

	keyTextBox.FocusLost:Connect(function(enterPressed)
		if keyTextBox.Text ~= "" then
			checkInputKey(keyTextBox.Text)
		end
	end)

	-- Auto verification on startup
	task.spawn(function()
		local cached = nil
		if readfile and isfile and isfile("dami_key.txt") then
			pcall(function() cached = readfile("dami_key.txt") end)
		end
		if cached and cached ~= "" then
			statusLabel.Text = "Checking cached key..."
			if verifyKey(cached) then
				statusLabel.Text = "Key verified automatically."
				task.wait(0.5)
				keySystemFrame:Destroy()
				main.Visible = true
			else
				statusLabel.Text = "Cached key expired. Please enter a new key."
			end
		end
	end)

	screenGui.Destroying:Connect(function()
		for _, conn in ipairs(self.connections) do
			if conn.Disconnect then conn:Disconnect() end
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

function Zyren:Notify(title, text, typeName, duration)
	if type(typeName) == "number" then
		duration = typeName
		typeName = "Info"
	end
	typeName = typeName or "Info"
	duration = duration or 3.5

	local accentColor = Theme.Accent
	if typeName == "Success" then accentColor = Color3.fromRGB(46, 204, 113)
	elseif typeName == "Warning" then accentColor = Color3.fromRGB(241, 196, 15)
	elseif typeName == "Error" then accentColor = Color3.fromRGB(231, 76, 60) end

	local notif = Utility.create("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Parent = self.notifHolder,
	}, {
		Utility.corner(6),
	})
	themed(notif, "BackgroundColor3", "Panel")
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

function Zyren:SaveConfig(name)
	name = name or "default"
	local folder = "zyren_configs"
	if makefolder then pcall(makefolder, folder) end
	local filePath = folder .. "/" .. name .. ".json"
	local data = {}
	for flagName, flagInfo in pairs(self.flags) do
		data[flagName] = flagInfo.Get()
	end
	local success, err = pcall(function()
		local json = HttpService:JSONEncode(data)
		if writefile then writefile(filePath, json) else error("No writefile support") end
	end)
	return success, err
end

function Zyren:LoadConfig(name)
	name = name or "default"
	local filePath = "zyren_configs/" .. name .. ".json"
	if not isfile or not isfile(filePath) then return false, "No file" end
	local success, err = pcall(function()
		local json = readfile(filePath)
		local data = HttpService:JSONDecode(json)
		for flagName, val in pairs(data) do
			local flagInfo = self.flags[flagName]
			if flagInfo then flagInfo.Set(val) end
		end
	end)
	return success, err
end

-- ============================================================================
-- ADD TAB: window:AddTab()
-- ============================================================================
function Zyren:AddTab(name, options)
	local tabIconId = options and options.Icon or "rbxassetid://10734950309"

	-- Vertical Sidebar Button
	local button = Utility.create("TextButton", {
		Text = "         " .. name, -- Offset for Icon
		Font = Theme.BodyFontMedium,
		TextSize = 12,
		TextColor3 = Theme.SubText,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(38, 28, 35),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.tabList,
	}, {
		Utility.corner(8),
		Utility.create("ImageLabel", {
			Name = "Icon",
			Size = UDim2.new(0, 16, 0, 16),
			Position = UDim2.new(0, 12, 0.5, -8),
			Image = tabIconId,
			BackgroundTransparency = 1,
			ImageColor3 = Theme.SubText,
		})
	})
	themed(button, "TextColor3", "SubText")
	themed(button, "Font", "BodyFontMedium")
	themed(button.Icon, "ImageColor3", "SubText")

	local page = Utility.create("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.new(0, 10, 0, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = self.pageContainer,
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
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)}),
	})

	local rightColumn = Utility.create("Frame", {
		Name = "RightColumn",
		Size = UDim2.new(0.5, -6, 0, 0),
		Position = UDim2.new(0.5, 6, 0, 0),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = page,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12)}),
	})

	local tab = setmetatable({
		window = self,
		button = button,
		page = page,
		leftColumn = leftColumn,
		rightColumn = rightColumn,
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

function Zyren:SelectTab(tab)
	if self.activeTab == tab then return end

	if self.activeTab then
		local old = self.activeTab
		old.page.Visible = false
		old.button.BackgroundTransparency = 1
		old.button.TextColor3 = Theme.SubText
		old.button.Icon.ImageColor3 = Theme.SubText
	end

	tab.page.Visible = true
	tab.button.BackgroundTransparency = 0
	tab.button.BackgroundColor3 = Theme.Accent
	tab.button.TextColor3 = Color3.fromRGB(255, 255, 255)
	tab.button.Icon.ImageColor3 = Color3.fromRGB(255, 255, 255)

	self.activeTab = tab
end

-- ============================================================================
-- ADD SECTION: tab:AddSection()
-- ============================================================================
function Tab:AddSection(name, columnSide)
	local targetColumn = self.leftColumn
	if columnSide == "right" then
		targetColumn = self.rightColumn
	elseif columnSide == "left" then
		targetColumn = self.leftColumn
	elseif self.leftColumn.UIListLayout.AbsoluteContentSize.Y > self.rightColumn.UIListLayout.AbsoluteContentSize.Y then
		targetColumn = self.rightColumn
	end

	-- Card section panel wrapper
	local container = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = targetColumn,
	}, {
		Utility.corner(12),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
	})
	themed(container, "BackgroundColor3", "Panel")
	themed(container.UIStroke, "Color", "Stroke")

	local sectionLabel = Utility.create("TextLabel", {
		Text = name,
		Font = Theme.TitleFont,
		TextSize = 12,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -24, 0, 30),
		Position = UDim2.new(0, 12, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = container,
	})
	themed(sectionLabel, "TextColor3", "Text")
	themed(sectionLabel, "Font", "TitleFont")

	local contentHolder = Utility.create("Frame", {
		Name = "Content",
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 34),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = container,
	}, {
		Utility.pad(10, 10, 2, 10),
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
	})

	local section = setmetatable({
		tab = self,
		container = container,
		contentHolder = contentHolder,
	}, Section)

	table.insert(self.sections, section)
	return section
end

function Section:AddFolder(name, options)
	options = options or {}
	local section = self
	local isOpen = options.default or options.open or false
	local iconId = options.Icon or options.icon

	-- The main folder container frame that holds the header and the content
	local folderFrame = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = section.contentHolder,
	}, {
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
	})

	-- The clickable header
	local header = card(30)
	header.Parent = folderFrame
	header.LayoutOrder = 1

	-- Left icon if provided
	local textPos = UDim2.new(0, 8, 0, 0)
	local textSize = UDim2.new(1, -40, 1, 0)

	if iconId then
		local icon = Utility.create("ImageLabel", {
			Size = UDim2.new(0, 14, 0, 14),
			Position = UDim2.new(0, 8, 0.5, -7),
			Image = iconId,
			BackgroundTransparency = 1,
			ImageColor3 = Theme.Text,
			Parent = header,
		})
		themed(icon, "ImageColor3", "Text")
		textPos = UDim2.new(0, 28, 0, 0)
		textSize = UDim2.new(1, -60, 1, 0)
	end

	local label = Utility.create("TextLabel", {
		Text = name,
		Font = Theme.BodyFontMedium,
		TextSize = 11,
		TextColor3 = Theme.Text,
		BackgroundTransparency = 1,
		Position = textPos,
		Size = textSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	-- Caret icon on the right
	local caret = Utility.create("ImageLabel", {
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(1, -18, 0.5, -5),
		Image = "rbxassetid://6031091007", -- Arrow down
		BackgroundTransparency = 1,
		ImageColor3 = Theme.Text,
		Rotation = isOpen and 180 or 0,
		Parent = header,
	})
	themed(caret, "ImageColor3", "Text")

	-- The content container frame
	local content = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = isOpen,
		Parent = folderFrame,
		LayoutOrder = 2,
	}, {
		Utility.pad(8, 0, 2, 4), -- Indent child elements slightly from left
		Utility.create("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
	})

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 5, Parent = header,
	})

	click.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		content.Visible = isOpen
		Utility.tween(caret, {Rotation = isOpen and 180 or 0}, 0.15)
	end)

	-- Define the folder API
	local folderApi = setmetatable({
		tab = section.tab,
		contentHolder = content,
		container = folderFrame,
	}, Folder)

	return folderApi
end

-- ============================================================================
-- SECTION CONTROLS: BUTTON, TOGGLE, SLIDER, TEXTBOX, DROPDOWNS
-- ============================================================================
function Section:AddButton(text, callback, description)
	local descText = description
	local cb = callback
	if type(callback) == "table" then
		cb = callback.callback
		descText = callback.description
	end

	local section = self
	local btnHeight = descText and 42 or 30
	local btn = card(btnHeight)
	btn.Parent = section.contentHolder

	local label
	if descText then
		label = Utility.create("TextLabel", {
			Text = text,
			Font = Theme.BodyFontMedium,
			TextSize = 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 4),
			Size = UDim2.new(1, -16, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
		local descLabel = Utility.create("TextLabel", {
			Text = descText,
			Font = Theme.BodyFont,
			TextSize = 9,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 20),
			Size = UDim2.new(1, -16, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
		themed(descLabel, "TextColor3", "SubText")
		themed(descLabel, "Font", "BodyFont")
	else
		label = Utility.create("TextLabel", {
			Text = text,
			Font = Theme.BodyFontMedium,
			TextSize = 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -16, 1, 0),
			Position = UDim2.new(0, 8, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
	end
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFontMedium")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = 5, Parent = btn,
	})

	click.MouseButton1Click:Connect(function()
		Utility.tween(btn, {BackgroundColor3 = Theme.HoverStroke}, 0.05)
		task.delay(0.05, function() Utility.tween(btn, {BackgroundColor3 = Theme.Elevated}, 0.1) end)
		if cb then cb() end
	end)

	local api = {instance = btn}
	table.insert(section.tab.window.controls, {text = text, instance = btn, section = section, tab = section.tab})
	return api
end

function Section:AddToggle(text, default, callback, flag)
	local defaultVal = default
	local flagName = flag
	local descText = nil
	if type(default) == "table" then
		defaultVal = default.default
		flagName = default.flag
		descText = default.description or default.desc
	elseif type(default) == "function" then
		callback = default
		defaultVal = false
		flagName = nil
	end

	local section = self
	local toggleHeight = descText and 42 or 30
	local toggle = card(toggleHeight)
	toggle.Parent = section.contentHolder

	local label
	if descText then
		label = Utility.create("TextLabel", {
			Text = text,
			Font = Theme.BodyFontMedium,
			TextSize = 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 4),
			Size = UDim2.new(1, -50, 0, 18),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toggle,
		})
		local descLabel = Utility.create("TextLabel", {
			Text = descText,
			Font = Theme.BodyFont,
			TextSize = 9,
			TextColor3 = Theme.SubText,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 20),
			Size = UDim2.new(1, -50, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toggle,
		})
		themed(descLabel, "TextColor3", "SubText")
		themed(descLabel, "Font", "BodyFont")
	else
		label = Utility.create("TextLabel", {
			Text = text,
			Font = Theme.BodyFont,
			TextSize = 11,
			TextColor3 = Theme.Text,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -50, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = toggle,
		})
	end
	themed(label, "TextColor3", "Text")
	themed(label, "Font", descText and "BodyFontMedium" or "BodyFont")

	-- Pill slider track
	local track = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 32, 0, 18),
		BackgroundColor3 = Color3.fromRGB(68, 48, 60),
		BorderSizePixel = 0,
		Parent = toggle,
	}, {
		Utility.corner(9)
	})

	local knob = Utility.create("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		Position = UDim2.new(0, 2, 0.5, -7),
		BackgroundColor3 = Color3.fromRGB(240, 240, 240),
		BorderSizePixel = 0,
		Parent = track,
	}, {
		Utility.corner(7)
	})

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.new(1, 0, 1, 0), Parent = toggle,
	})

	local state = defaultVal or false

	local function updateToggleStyle()
		Utility.tween(track, {BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(68, 48, 60)}, 0.15)
		Utility.tween(knob, {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}, 0.15)
	end

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

	local slider = card(42)
	slider.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 10, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 4),
		Size = UDim2.new(1, -78, 0, 14), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slider,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local valueBox = Utility.create("TextBox", {
		Text = string.format("%." .. tostring(precision) .. "f", value) .. suffix,
		Font = Theme.BodyFontBold, TextSize = 9, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 4),
		Size = UDim2.new(0, 62, 0, 14), TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		Parent = slider,
	})
	themed(valueBox, "TextColor3", "SubText")
	themed(valueBox, "Font", "BodyFontBold")

	local bar = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 26), Size = UDim2.new(1, -16, 0, 4),
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

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = slider, section = section, tab = section.tab})
	return api
end

function Section:AddTextBox(text, placeholder, callback, flag)
	local flagName = flag
	if type(placeholder) == "table" then
		flagName = placeholder.flag
		placeholder = placeholder.default or ""
	elseif type(placeholder) == "function" then
		callback = placeholder
		placeholder = ""
	end

	local section = self
	local box = card(30)
	box.Parent = section.contentHolder

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(0.45, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	themed(label, "TextColor3", "Text")
	themed(label, "Font", "BodyFont")

	local inputHolder = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.5, -8, 0, 20), BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0, Parent = box,
	}, {
		Utility.corner(4)
	})
	themed(inputHolder, "BackgroundColor3", "Background")
	local inputStroke = Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1}, {})
	inputStroke.Parent = inputHolder
	themed(inputStroke, "Color", "Stroke")

	local input = Utility.create("TextBox", {
		Text = "", PlaceholderText = placeholder or "",
		Font = Theme.BodyFont, TextSize = 10, TextColor3 = Theme.Text,
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
	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = box, section = section, tab = section.tab})
	return api
end
-- Add lowercase b fallback as well
Section.AddTextbox = Section.AddTextBox

-- ============================================================================
-- DROPDOWN: Reworked to show popup modal in center of GUI
-- ============================================================================
function Section:AddDropdown(text, options, default, callback, flag)
	local flagName = flag
	if type(default) == "table" then
		flagName = default.flag
		default = default.default
	end

	local section = self
	options = options or {}

	local dropdown = card(30)
	dropdown.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(0.5, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dropdown,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	-- The clickable selector panel
	local selector = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.5, -8, 0, 20), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = dropdown,
	}, {
		Utility.corner(4),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
	})
	themed(selector, "BackgroundColor3", "Panel")
	themed(selector.UIStroke, "Color", "Stroke")

	local selectedLabel = Utility.create("TextLabel", {
		Text = tostring(default or "Select"), Font = Theme.BodyFont, TextSize = 9,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -26, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = selector,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("ImageLabel", {
		Size = UDim2.new(0, 10, 0, 10),
		Position = UDim2.new(1, -16, 0.5, -5),
		Image = "rbxassetid://6031091007", -- Arrow down
		BackgroundTransparency = 1,
		ImageColor3 = Theme.Text,
		Parent = selector,
	})
	themed(arrow, "ImageColor3", "Text")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.new(1, 0, 1, 0), Parent = selector,
	})

	local api = {instance = dropdown}

	-- Create option card helpers
	local function createModal()
		local overlay = section.tab.window.dropdownOverlay
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		Utility.tween(overlay, {BackgroundTransparency = 0.5}, 0.2)

		-- Overlay click-away
		local overlayClick = Utility.create("TextButton", {
			Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = overlay,
		})

		local modal = Utility.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 270, 0, 290),
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			Parent = overlay,
		}, {
			Utility.corner(12),
			Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1})
		})
		themed(modal, "BackgroundColor3", "Panel")
		themed(modal.UIStroke, "Color", "Accent")

		local modalTitle = Utility.create("TextLabel", {
			Text = text, Font = Theme.TitleFont, TextSize = 13, TextColor3 = Theme.Text,
			BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0.7, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left, Parent = modal,
		})
		themed(modalTitle, "TextColor3", "Text")
		themed(modalTitle, "Font", "TitleFont")

		local close = Utility.create("TextButton", {
			Text = "", Position = UDim2.new(1, -34, 0, 10), Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = modal,
		}, {
			Utility.corner(12),
			Utility.create("ImageLabel", {
				Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0.5, -5, 0.5, -5),
				Image = "rbxassetid://6031094678", BackgroundTransparency = 1, ImageColor3 = Theme.Text
			})
		})
		themed(close, "BackgroundColor3", "Background")
		themed(close.ImageLabel, "ImageColor3", "Text")

		local list = Utility.create("ScrollingFrame", {
			Position = UDim2.new(0, 14, 0, 44), Size = UDim2.new(1, -28, 1, -85),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = modal,
		}, {
			Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}),
		})

		local function hideModal()
			Utility.tween(overlay, {BackgroundTransparency = 1}, 0.2)
			task.delay(0.2, function() overlay.Visible = false overlay:ClearAllChildren() end)
		end

		close.MouseButton1Click:Connect(hideModal)
		overlayClick.MouseButton1Click:Connect(hideModal)

		for _, opt in ipairs(options) do
			local optName = tostring(opt)
			local item = Utility.create("TextButton", {
				Text = "", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Elevated,
				BorderSizePixel = 0, Parent = list,
			}, {
				Utility.corner(6),
				Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
			})
			themed(item, "BackgroundColor3", "Elevated")
			themed(item.UIStroke, "Color", "Stroke")

			local itemTitle = Utility.create("TextLabel", {
				Text = optName, Font = Theme.BodyFontMedium, TextSize = 10, TextColor3 = Theme.Text,
				BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(0.7, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, Parent = item,
			})
			themed(itemTitle, "TextColor3", "Text")
			themed(itemTitle, "Font", "BodyFontMedium")

			local itemDesc = Utility.create("TextLabel", {
				Text = "Configure setting for " .. optName, Font = Theme.BodyFont, TextSize = 8, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 20), Size = UDim2.new(0.7, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, Parent = item,
			})
			themed(itemDesc, "TextColor3", "SubText")
			themed(itemDesc, "Font", "BodyFont")

			-- Checked indicator radio dot
			local dot = Utility.create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = item,
			}, {
				Utility.corner(7),
				Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
			})
			themed(dot, "BackgroundColor3", "Background")
			themed(dot.UIStroke, "Color", "Stroke")

			local fill = Utility.create("Frame", {
				Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0.5, -4, 0.5, -4),
				BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Visible = (selectedLabel.Text == optName), Parent = dot,
			}, {
				Utility.corner(4)
			})
			themed(fill, "BackgroundColor3", "Accent")

			item.MouseButton1Click:Connect(function()
				selectedLabel.Text = optName
				hideModal()
				if callback then callback(opt) end
			end)
		end

		-- Footer card selected status
		local cardFooter = Utility.create("Frame", {
			Size = UDim2.new(1, -28, 0, 28), Position = UDim2.new(0, 14, 1, -38),
			BackgroundColor3 = Theme.Elevated, BorderSizePixel = 0, Parent = modal,
		}, {
			Utility.corner(6),
			Utility.create("TextLabel", {
				Text = "Currently: ", Font = Theme.BodyFont, TextSize = 9, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Utility.create("TextLabel", {
				Name = "ActiveText", Text = selectedLabel.Text, Font = Theme.BodyFontBold, TextSize = 10, TextColor3 = Theme.Accent,
				BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -10, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
			})
		})
		themed(cardFooter, "BackgroundColor3", "Elevated")
		themed(cardFooter.TextLabel, "TextColor3", "SubText")
		themed(cardFooter.TextLabel, "Font", "BodyFont")
		themed(cardFooter.ActiveText, "TextColor3", "Accent")
		themed(cardFooter.ActiveText, "Font", "BodyFontBold")
	end

	click.MouseButton1Click:Connect(createModal)

	function api:Refresh(newOptions)
		options = newOptions
	end
	function api:Set(value) selectedLabel.Text = tostring(value) end
	function api:Get() return selectedLabel.Text end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = dropdown, section = section, tab = section.tab})
	return api
end

-- ============================================================================
-- MULTIDROPDOWN: Reworked standard popup selection list
-- ============================================================================
function Section:AddMultiDropdown(text, options, defaults, callback, flag)
	local flagName = flag
	if type(defaults) == "table" and not defaults[1] and defaults.default then
		flagName = defaults.flag
		defaults = defaults.default
	end

	local section = self
	options = options or {}

	local dropdown = card(30)
	dropdown.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 0),
		Size = UDim2.new(0.5, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		Parent = dropdown,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFont")

	local selector = Utility.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0.5, -8, 0, 20), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = dropdown,
	}, {
		Utility.corner(4),
		Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
	})
	themed(selector, "BackgroundColor3", "Panel")
	themed(selector.UIStroke, "Color", "Stroke")

	local selectedLabel = Utility.create("TextLabel", {
		Text = "None", Font = Theme.BodyFont, TextSize = 9,
		TextColor3 = Theme.SubText, BackgroundTransparency = 1,
		Position = UDim2.new(0, 6, 0, 0), Size = UDim2.new(1, -26, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = selector,
	})
	themed(selectedLabel, "TextColor3", "SubText")
	themed(selectedLabel, "Font", "BodyFont")

	local arrow = Utility.create("ImageLabel", {
		Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(1, -16, 0.5, -5),
		Image = "rbxassetid://6031091007", BackgroundTransparency = 1, ImageColor3 = Theme.Text, Parent = selector,
	})
	themed(arrow, "ImageColor3", "Text")

	local click = Utility.create("TextButton", {
		Text = "", BackgroundTransparency = 1, ZIndex = 5, Size = UDim2.new(1, 0, 1, 0), Parent = selector,
	})

	local selected = {}
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

	updateSelectedLabel()

	local api = {instance = dropdown}

	local function createModal()
		local overlay = section.tab.window.dropdownOverlay
		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		Utility.tween(overlay, {BackgroundTransparency = 0.5}, 0.2)

		local overlayClick = Utility.create("TextButton", {
			Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", Parent = overlay,
		})

		local modal = Utility.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 270, 0, 290), BackgroundColor3 = Theme.Panel, BorderSizePixel = 0, Parent = overlay,
		}, {
			Utility.corner(12),
			Utility.create("UIStroke", {Color = Theme.Accent, Thickness = 1})
		})
		themed(modal, "BackgroundColor3", "Panel")
		themed(modal.UIStroke, "Color", "Accent")

		local modalTitle = Utility.create("TextLabel", {
			Text = text, Font = Theme.TitleFont, TextSize = 13, TextColor3 = Theme.Text,
			BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(0.7, 0, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left, Parent = modal,
		})
		themed(modalTitle, "TextColor3", "Text")
		themed(modalTitle, "Font", "TitleFont")

		local close = Utility.create("TextButton", {
			Text = "", Position = UDim2.new(1, -34, 0, 10), Size = UDim2.new(0, 24, 0, 24),
			BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = modal,
		}, {
			Utility.corner(12),
			Utility.create("ImageLabel", {
				Size = UDim2.new(0, 10, 0, 10), Position = UDim2.new(0.5, -5, 0.5, -5),
				Image = "rbxassetid://6031094678", BackgroundTransparency = 1, ImageColor3 = Theme.Text
			})
		})
		themed(close, "BackgroundColor3", "Background")
		themed(close.ImageLabel, "ImageColor3", "Text")

		local list = Utility.create("ScrollingFrame", {
			Position = UDim2.new(0, 14, 0, 44), Size = UDim2.new(1, -28, 1, -85),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = modal,
		}, {
			Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}),
		})

		local function hideModal()
			Utility.tween(overlay, {BackgroundTransparency = 1}, 0.2)
			task.delay(0.2, function() overlay.Visible = false overlay:ClearAllChildren() end)
		end

		close.MouseButton1Click:Connect(hideModal)
		overlayClick.MouseButton1Click:Connect(hideModal)

		for _, opt in ipairs(options) do
			local optName = tostring(opt)
			local item = Utility.create("TextButton", {
				Text = "", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Theme.Elevated,
				BorderSizePixel = 0, Parent = list,
			}, {
				Utility.corner(6),
				Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
			})
			themed(item, "BackgroundColor3", "Elevated")
			themed(item.UIStroke, "Color", "Stroke")

			local itemTitle = Utility.create("TextLabel", {
				Text = optName, Font = Theme.BodyFontMedium, TextSize = 10, TextColor3 = Theme.Text,
				BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(0.7, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, Parent = item,
			})
			themed(itemTitle, "TextColor3", "Text")
			themed(itemTitle, "Font", "BodyFontMedium")

			local itemDesc = Utility.create("TextLabel", {
				Text = "Toggle select for " .. optName, Font = Theme.BodyFont, TextSize = 8, TextColor3 = Theme.SubText,
				BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 20), Size = UDim2.new(0.7, 0, 0, 16),
				TextXAlignment = Enum.TextXAlignment.Left, Parent = item,
			})
			themed(itemDesc, "TextColor3", "SubText")
			themed(itemDesc, "Font", "BodyFont")

			local checkbox = Utility.create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Theme.Background, BorderSizePixel = 0, Parent = item,
			}, {
				Utility.corner(3),
				Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})
			})
			themed(checkbox, "BackgroundColor3", "Background")
			themed(checkbox.UIStroke, "Color", "Stroke")

			local checkLabel = Utility.create("TextLabel", {
				Text = "✓", Font = Theme.BodyFontBold, TextSize = 10, TextColor3 = Theme.Accent,
				BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
				Visible = (selected[optName] == true), Parent = checkbox,
			})
			themed(checkLabel, "TextColor3", "Accent")
			themed(checkLabel, "Font", "BodyFontBold")

			item.MouseButton1Click:Connect(function()
				selected[optName] = not selected[optName] or nil
				checkLabel.Visible = (selected[optName] == true)
				updateSelectedLabel()
				if callback then callback(currentSelection()) end
			end)
		end
	end

	click.MouseButton1Click:Connect(createModal)

	function api:Refresh(newOptions)
		options = newOptions
	end
	function api:Get() return currentSelection() end
	function api:Set(values)
		selected = {}
		for _, v in ipairs(values or {}) do selected[tostring(v)] = true end
		updateSelectedLabel()
	end

	registerFlag(section.tab.window, flagName, function() return api:Get() end, function(val) api:Set(val) end)
	table.insert(section.tab.window.controls, {text = text, instance = dropdown, section = section, tab = section.tab})
	return api
end

-- ============================================================================
-- COLORPICKER: Reworked styling picker panel
-- ============================================================================
function Section:AddColorPicker(text, default, callback, flag)
	local flagName = flag
	if type(default) == "table" and not default.R then
		flagName = default.flag
		default = default.default
	end

	local section = self
	default = default or Color3.fromRGB(152, 60, 80)

	local picker = card(30)
	picker.Parent = section.contentHolder

	local titleLabel = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 11, TextColor3 = Theme.Text,
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

	-- Centered color popup modal overlay
	local panel = Utility.create("Frame", {
		Size = UDim2.new(0, 180, 0, 205),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 9999,
		Parent = section.tab.window.screenGui,
	}, {Utility.corner(8), Utility.pad(10)})
	themed(panel, "BackgroundColor3", "Panel")
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
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 25, Parent = svBox,
	})

	local hueCapture = Utility.create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 25, Parent = hueBar,
	})

	local rgbInputHolder = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 126), BackgroundColor3 = Theme.Elevated, BorderSizePixel = 0, Parent = panel,
	}, {Utility.corner(4), Utility.create("UIStroke", {Color = Theme.Stroke, Thickness = 1})})
	themed(rgbInputHolder, "BackgroundColor3", "Elevated")
	themed(rgbInputHolder.UIStroke, "Color", "Stroke")

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
		Color3.fromRGB(152, 60, 80),
		Color3.fromRGB(68, 90, 255),
		Color3.fromRGB(156, 39, 176),
		Color3.fromRGB(33, 150, 243),
		Color3.fromRGB(76, 175, 80),
		Color3.fromRGB(255, 152, 0),
	}

	local presetsHolder = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 154), BackgroundTransparency = 1, Parent = panel,
	}, {
		Utility.create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6)}),
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
			Text = "", Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = col, BorderSizePixel = 0, Parent = presetsHolder,
		}, {Utility.corner(7)})
		presetBtn.MouseButton1Click:Connect(function()
			hue, sat, val = Color3.toHSV(col)
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
			updateColor()
		end)
	end

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
	local labelFrame = Utility.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		BorderSizePixel = 0,
		Parent = self.contentHolder,
	})

	local label = Utility.create("TextLabel", {
		Text = text, Font = Theme.BodyFont, TextSize = 10, TextColor3 = Theme.SubText,
		BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 4, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
		Parent = labelFrame,
	})
	themed(label, "TextColor3", "SubText")
	themed(label, "Font", "BodyFont")

	local api = {instance = labelFrame}
	function api:SetText(newText) label.Text = newText end
	return api
end

function Section:AddParagraph(title, desc)
	local para = Utility.create("Frame", {
		BackgroundColor3 = Theme.Elevated, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0,
		Parent = self.contentHolder,
	}, {
		Utility.corner(6),
		Utility.pad(8),
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
		Text = desc, Font = Theme.BodyFont, TextSize = 9, TextColor3 = Theme.SubText,
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
	return api
end

function Section:AddDivider()
	local div = Utility.create("Frame", {
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundTransparency = 1,
		Parent = self.contentHolder,
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
		Size = UDim2.new(1, -10, 1, -10), Position = UDim2.new(0, 5, 0, 5),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = consoleFrame,
	}, {
		Utility.create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}),
	})
	themed(scroll, "ScrollBarImageColor3", "Accent")
	
	local consoleApi = {instance = consoleFrame}
	
	function consoleApi:Log(logText, typeName)
		typeName = typeName or "Info"
		local color = Theme.Text
		if typeName == "Success" then color = Color3.fromRGB(46, 204, 113)
		elseif typeName == "Warning" then color = Color3.fromRGB(241, 196, 15)
		elseif typeName == "Error" then color = Color3.fromRGB(231, 76, 60)
		elseif typeName == "Info" then color = Theme.SubText end
		
		local timestamp = os.date("%H:%M:%S")
		local label = Utility.create("TextLabel", {
			Text = string.format("[%s] [%s] %s", timestamp, typeName:upper(), logText),
			Font = Theme.BodyFont, TextSize = 8, TextColor3 = color, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
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
	minVal, maxVal = minVal or 0, maxVal or 100
	
	local graphFrame = card(height + 24)
	graphFrame.Parent = section.contentHolder
	
	local titleLabel = Utility.create("TextLabel", {
		Text = title, Font = Theme.BodyFontMedium, TextSize = 10, TextColor3 = Theme.Text,
		BackgroundTransparency = 1, Position = UDim2.new(0, 8, 0, 3), Size = UDim2.new(1, -16, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = graphFrame,
	})
	themed(titleLabel, "TextColor3", "Text")
	themed(titleLabel, "Font", "BodyFontMedium")
	
	local plotArea = Utility.create("Frame", {
		Position = UDim2.new(0, 8, 0, 20), Size = UDim2.new(1, -16, 1, -26), BackgroundTransparency = 1, Parent = graphFrame,
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
			local percentY = math.clamp((points[i] - minVal) / (maxVal - minVal), 0, 1)
			local bar = Utility.create("Frame", {
				BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
				Position = UDim2.new(0, (i - 1) * stepX, 1 - percentY, 0),
				Size = UDim2.new(0, math.max(2, stepX - 2), percentY, 0),
				Parent = plotArea,
			}, {Utility.corner(1)})
			themed(bar, "BackgroundColor3", "Accent")
		end
	end
	return graphApi
end

Zyren.Theme = Theme
return Zyren
