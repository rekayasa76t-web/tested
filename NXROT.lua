-- NXROT DUPE STANDALONE — Ringan, hanya Dupe tab
-- [KEY VALIDATION] — similar to Mine A Mountain v3.1

local __nxrEnv = (type(getgenv)=="function" and getgenv()) or _G
if __nxrEnv.__nxrDupeStandaloneActive then
	return
end
__nxrEnv.__nxrDupeStandaloneActive = true

local DEV_MODE = (rawget(_G, "__nxr_dev") ~= nil) or false

local LOCAL_KEY = "NXROT"

local function validateStartupKey()
	if DEV_MODE == true then
		return true
	end

	local env = (type(getgenv)=="function" and getgenv()) or _G
	local key = nil
	pcall(function() key = env.key end)
	if key == nil then pcall(function() key = _G.key end) end
	key = tostring(key or ""):match("^%s*(.-)%s*$") or ""

	return key ~= "" and key == LOCAL_KEY
end

if not validateStartupKey() then
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "NXROT Dupe",
			Text = "Wrong Key",
			Duration = 2
		})
	end)
	task.wait(1)
	pcall(function() game.Players.LocalPlayer:Kick("NXROT Dupe | Wrong Key") end)
	return
end

-- ===== ORIGINAL SCRIPT BELOW (unchanged) =====

local S = {
    Players           = game:GetService("Players"),
    CoreGui           = game:GetService("CoreGui"),
    RunService        = game:GetService("RunService"),
    UserInputService  = game:GetService("UserInputService"),
    TweenService      = game:GetService("TweenService"),
    HttpService       = game:GetService("HttpService"),
    TeleportService   = game:GetService("TeleportService"),
    GuiService        = game:GetService("GuiService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
}
local LocalPlayer = S.Players.LocalPlayer

local function resolveGuiRoot()
    local ok, h = pcall(function() return gethui() end)
    if ok and typeof(h) == "Instance" then return h end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then return pg end
    return LocalPlayer:WaitForChild("PlayerGui", 10) or S.CoreGui
end
local GuiRoot = resolveGuiRoot()

pcall(function()
    local old = GuiRoot:FindFirstChild("nxrDupeStandalone")
        or S.CoreGui:FindFirstChild("nxrDupeStandalone")
    if old then old:Destroy() end
end)

local function Notify(text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NXROT Dupe", Text = tostring(text), Duration = duration or 3
        })
    end)
end

local C = {
    BASE    = Color3.fromRGB(5, 15, 35),
    SURFACE = Color3.fromRGB(10, 30, 65),
    ELEVATED= Color3.fromRGB(15, 45, 90),
    BORDER  = Color3.fromRGB(25, 100, 180),
    DIVIDER = Color3.fromRGB(12, 45, 85),
    TEXT_1  = Color3.fromRGB(235,245,255),
    TEXT_2  = Color3.fromRGB(160,200,255),
    TEXT_3  = Color3.fromRGB(100,150,210),
    ACCENT  = Color3.fromRGB(0,170,255),
    ACCENT_D= Color3.fromRGB(0,110,200),
}

local function Corner(p, r)
    local c = Instance.new("UICorner", p)
    c.CornerRadius = UDim.new(0, r or 6)
end
local function Stroke(p, col, th)
    local s = Instance.new("UIStroke", p)
    s.Color = col or C.BORDER; s.Thickness = th or 1
    return s
end
local function MakeDraggable(frame, handle)
    local drag, ds, sp
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            drag = true; ds = inp.Position; sp = frame.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    S.UserInputService.InputChanged:Connect(function(inp)
        if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X,
                sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)
end

local MainSG = Instance.new("ScreenGui", GuiRoot)
MainSG.Name = "nxrDupeStandalone"
MainSG.ResetOnSpawn = false

local activeDropdown = nil

local function BuatSection(parent, text)
    local Lbl = Instance.new("TextLabel", parent)
    Lbl.Size = UDim2.new(1, 0, 0, 20); Lbl.BackgroundTransparency = 1
    Lbl.Font = Enum.Font.GothamBold; Lbl.TextColor3 = C.TEXT_2
    Lbl.Text = text:upper(); Lbl.TextSize = 11
    Lbl.TextXAlignment = Enum.TextXAlignment.Left
end

local function BuatLabel(parent, defaultText)
    local Row = Instance.new("Frame", parent)
    Row.Size = UDim2.new(1, 0, 0, 30); Row.BackgroundColor3 = C.SURFACE; Corner(Row, 6)
    local Lbl = Instance.new("TextLabel", Row)
    Lbl.Size = UDim2.new(1, -20, 1, 0); Lbl.Position = UDim2.new(0, 14, 0, 0)
    Lbl.BackgroundTransparency = 1; Lbl.Text = defaultText
    Lbl.TextColor3 = C.TEXT_1; Lbl.Font = Enum.Font.GothamMedium
    Lbl.TextSize = 12; Lbl.TextXAlignment = Enum.TextXAlignment.Left
    return Lbl
end

local function BuatToggle(parent, label, defaultState)
    local Row = Instance.new("Frame", parent)
    Row.Size = UDim2.new(1, 0, 0, 42); Row.BackgroundColor3 = C.SURFACE; Corner(Row, 6)
    local RowStroke = Stroke(Row, C.BORDER)
    local LeftAccent = Instance.new("Frame", Row)
    LeftAccent.Size = UDim2.new(0, 2, 0, 18); LeftAccent.Position = UDim2.new(0, 0, 0.5, -9)
    LeftAccent.BackgroundColor3 = C.BORDER; Corner(LeftAccent, 1)
    local LabelTxt = Instance.new("TextLabel", Row)
    LabelTxt.Size = UDim2.new(1, -70, 1, 0); LabelTxt.Position = UDim2.new(0, 14, 0, 0)
    LabelTxt.BackgroundTransparency = 1; LabelTxt.Text = label
    LabelTxt.TextColor3 = C.TEXT_2; LabelTxt.Font = Enum.Font.GothamMedium
    LabelTxt.TextSize = 12; LabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    local Pill = Instance.new("Frame", Row)
    Pill.Size = UDim2.new(0, 38, 0, 20); Pill.Position = UDim2.new(1, -50, 0.5, -10)
    Pill.BackgroundColor3 = C.DIVIDER; Corner(Pill, 10)
    local PillDot = Instance.new("Frame", Pill)
    PillDot.Size = UDim2.new(0, 14, 0, 14); PillDot.Position = UDim2.new(0, 3, 0.5, -7)
    PillDot.BackgroundColor3 = C.TEXT_3; Corner(PillDot, 7)
    local Btn = Instance.new("TextButton", Row)
    Btn.Size = UDim2.new(1, 0, 1, 0); Btn.BackgroundTransparency = 1; Btn.Text = ""
    local function SetTween(on)
        S.TweenService:Create(Row, TweenInfo.new(0.2), {
            BackgroundColor3 = on and C.ELEVATED or C.SURFACE
        }):Play()
        RowStroke.Color = on and C.ACCENT_D or C.BORDER
        LabelTxt.TextColor3 = on and C.TEXT_1 or C.TEXT_2
        LeftAccent.BackgroundColor3 = on and C.ACCENT or C.BORDER
        S.TweenService:Create(Pill, TweenInfo.new(0.2), {
            BackgroundColor3 = on and C.ACCENT_D or C.DIVIDER
        }):Play()
        S.TweenService:Create(PillDot, TweenInfo.new(0.2), {
            Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
            BackgroundColor3 = on and C.ACCENT or C.TEXT_3,
        }):Play()
    end
    SetTween(defaultState == true)
    return Btn, SetTween
end

local function BuatButton(parent, label)
    local Row = Instance.new("TextButton", parent)
    Row.Size = UDim2.new(1, 0, 0, 36); Row.BackgroundColor3 = C.SURFACE
    Row.Text = ""; Row.AutoButtonColor = false; Corner(Row, 6); Stroke(Row, C.BORDER)
    local LeftAccent = Instance.new("Frame", Row)
    LeftAccent.Size = UDim2.new(0, 2, 0, 18); LeftAccent.Position = UDim2.new(0, 0, 0.5, -9)
    LeftAccent.BackgroundColor3 = C.BORDER; Corner(LeftAccent, 1)
    local LabelTxt = Instance.new("TextLabel", Row)
    LabelTxt.Size = UDim2.new(1, -20, 1, 0); LabelTxt.Position = UDim2.new(0, 14, 0, 0)
    LabelTxt.BackgroundTransparency = 1; LabelTxt.Text = label
    LabelTxt.TextColor3 = C.TEXT_1; LabelTxt.Font = Enum.Font.GothamMedium
    LabelTxt.TextSize = 12; LabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    return Row
end

local function BuatSlider(parent, label, min, max, default, callback)
    local Row = Instance.new("Frame", parent)
    Row.Size = UDim2.new(1, 0, 0, 50); Row.BackgroundColor3 = C.SURFACE
    Corner(Row, 6); Stroke(Row, C.BORDER)
    local LabelTxt = Instance.new("TextLabel", Row)
    LabelTxt.Size = UDim2.new(0.7, 0, 0, 20); LabelTxt.Position = UDim2.new(0, 14, 0, 5)
    LabelTxt.BackgroundTransparency = 1; LabelTxt.Text = label .. ": " .. tostring(default)
    LabelTxt.TextColor3 = C.TEXT_1; LabelTxt.Font = Enum.Font.GothamMedium
    LabelTxt.TextSize = 11; LabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    local Track = Instance.new("Frame", Row)
    Track.Size = UDim2.new(1, -28, 0, 4); Track.Position = UDim2.new(0, 14, 1, -12)
    Track.BackgroundColor3 = C.DIVIDER; Corner(Track, 2)
    local Progress = Instance.new("Frame", Track)
    Progress.Size = UDim2.new(0, 0, 1, 0); Progress.BackgroundColor3 = C.ACCENT; Corner(Progress, 2)
    local Thumb = Instance.new("Frame", Track)
    Thumb.Size = UDim2.new(0, 12, 0, 12); Thumb.Position = UDim2.new(0, -6, 0.5, -6)
    Thumb.BackgroundColor3 = C.TEXT_1; Corner(Thumb, 6)
    local Dragger = Instance.new("TextButton", Track)
    Dragger.Size = UDim2.new(1, 0, 3, 0); Dragger.Position = UDim2.new(0, 0, -1, 0)
    Dragger.BackgroundTransparency = 1; Dragger.Text = ""
    local function UpdateSlider(value)
        local pct = math.clamp((value - min) / (max - min), 0, 1)
        Progress.Size = UDim2.new(pct, 0, 1, 0)
        Thumb.Position = UDim2.new(pct, -6, 0.5, -6)
        LabelTxt.Text = label .. ": " .. string.format("%d", value)
        callback(math.floor(value))
    end
    UpdateSlider(default)
    local dragging = false
    Dragger.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    Dragger.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    S.UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local relX = i.Position.X - Track.AbsolutePosition.X
            local pct = math.clamp(relX / Track.AbsoluteSize.X, 0, 1)
            UpdateSlider(min + (max - min) * pct)
        end
    end)
end

local function BuatInput(parent, label, placeholder, default, callback)
    local Row = Instance.new("Frame", parent)
    Row.Size = UDim2.new(1, 0, 0, 42); Row.BackgroundColor3 = C.SURFACE
    Corner(Row, 6); Stroke(Row, C.BORDER)
    local LabelTxt = Instance.new("TextLabel", Row)
    LabelTxt.Size = UDim2.new(0.5, -20, 1, 0); LabelTxt.Position = UDim2.new(0, 14, 0, 0)
    LabelTxt.BackgroundTransparency = 1; LabelTxt.Text = label
    LabelTxt.TextColor3 = C.TEXT_1; LabelTxt.Font = Enum.Font.GothamMedium
    LabelTxt.TextSize = 12; LabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    local InputBox = Instance.new("TextBox", Row)
    InputBox.Size = UDim2.new(0.4, 0, 0, 24); InputBox.Position = UDim2.new(0.6, -14, 0.5, -12)
    InputBox.BackgroundColor3 = C.ELEVATED; Corner(InputBox, 4); Stroke(InputBox, C.DIVIDER)
    InputBox.Text = default or ""; InputBox.PlaceholderText = placeholder or ""
    InputBox.TextColor3 = C.TEXT_1; InputBox.Font = Enum.Font.Gotham; InputBox.TextSize = 11
    InputBox.FocusLost:Connect(function() callback(InputBox.Text) end)
end

local function BuatDropdown(parent, label, options, isMulti, defaultSelected, callback)
    local selected = isMulti and {} or ""
    if isMulti and type(defaultSelected) == "table" then
        for _, v in ipairs(defaultSelected) do
            if type(v) == "string" and v ~= "" then selected[v] = true end
        end
    elseif not isMulti and type(defaultSelected) == "string" then
        selected = defaultSelected
    end
    local function displayText()
        if isMulti then
            local keys = {}; for k in pairs(selected) do keys[#keys + 1] = k end
            if #keys == 0 then return "None" end
            table.sort(keys)
            if #keys == 1 then return keys[1] end
            return keys[1] .. " +" .. tostring(#keys - 1)
        else
            return selected == "" and "None" or selected
        end
    end
    local Row = Instance.new("Frame", parent)
    Row.Size = UDim2.new(1, 0, 0, 42); Row.BackgroundColor3 = C.SURFACE
    Corner(Row, 6); Stroke(Row, C.BORDER)
    local LabelTxt = Instance.new("TextLabel", Row)
    LabelTxt.Size = UDim2.new(0.42, 0, 1, 0); LabelTxt.Position = UDim2.new(0, 14, 0, 0)
    LabelTxt.BackgroundTransparency = 1; LabelTxt.Text = label
    LabelTxt.TextColor3 = C.TEXT_2; LabelTxt.Font = Enum.Font.GothamMedium
    LabelTxt.TextSize = 11; LabelTxt.TextXAlignment = Enum.TextXAlignment.Left
    local DropBtn = Instance.new("TextButton", Row)
    DropBtn.Size = UDim2.new(0.55, 0, 0, 28); DropBtn.Position = UDim2.new(0.44, 0, 0.5, -14)
    DropBtn.BackgroundColor3 = C.ELEVATED; Corner(DropBtn, 4); Stroke(DropBtn, C.DIVIDER)
    DropBtn.Text = displayText(); DropBtn.TextColor3 = C.TEXT_1
    DropBtn.Font = Enum.Font.GothamMedium; DropBtn.TextSize = 11; DropBtn.AutoButtonColor = false
    local Panel = Instance.new("Frame", MainSG)
    Panel.Size = UDim2.new(0, 220, 0, math.min(#options * 28 + 8, 180))
    Panel.BackgroundColor3 = C.ELEVATED; Corner(Panel, 6); Stroke(Panel, C.BORDER)
    Panel.Visible = false; Panel.ZIndex = 20
    local PanelScroll = Instance.new("ScrollingFrame", Panel)
    PanelScroll.Size = UDim2.new(1, -4, 1, -4); PanelScroll.Position = UDim2.new(0, 2, 0, 2)
    PanelScroll.BackgroundTransparency = 1; PanelScroll.BorderSizePixel = 0
    PanelScroll.ScrollBarThickness = 3; PanelScroll.ZIndex = 20
    local PanelLayout = Instance.new("UIListLayout", PanelScroll)
    PanelLayout.Padding = UDim.new(0, 2); PanelLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PanelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        PanelScroll.CanvasSize = UDim2.new(0, 0, 0, PanelLayout.AbsoluteContentSize.Y + 6)
    end)
    local function rebuildOptions(optList)
        for _, ch in ipairs(PanelScroll:GetChildren()) do
            if ch:IsA("TextButton") then ch:Destroy() end
        end
        local clearBtn = Instance.new("TextButton", PanelScroll)
        clearBtn.Size = UDim2.new(1, 0, 0, 26); clearBtn.BackgroundTransparency = 1
        clearBtn.Text = "None"; clearBtn.TextColor3 = C.TEXT_3
        clearBtn.Font = Enum.Font.GothamMedium; clearBtn.TextSize = 11; clearBtn.ZIndex = 21
        clearBtn.MouseButton1Click:Connect(function()
            if isMulti then table.clear(selected) else selected = "" end
            DropBtn.Text = displayText()
            Panel.Visible = false; activeDropdown = nil
            callback(isMulti and {} or "")
        end)
        for _, opt in ipairs(optList) do
            local isOn = isMulti and selected[opt] == true or selected == opt
            local OBtn = Instance.new("TextButton", PanelScroll)
            OBtn.Size = UDim2.new(1, 0, 0, 26)
            OBtn.BackgroundColor3 = isOn and C.ACCENT_D or C.ELEVATED
            OBtn.BorderSizePixel = 0; Corner(OBtn, 4)
            OBtn.Text = opt; OBtn.TextColor3 = isOn and C.TEXT_1 or C.TEXT_2
            OBtn.Font = Enum.Font.GothamMedium; OBtn.TextSize = 11; OBtn.ZIndex = 21
            OBtn.MouseButton1Click:Connect(function()
                if isMulti then
                    if selected[opt] then selected[opt] = nil else selected[opt] = true end
                    for _, child in ipairs(PanelScroll:GetChildren()) do
                        if child:IsA("TextButton") and child ~= clearBtn then
                            local on = selected[child.Text] == true
                            child.BackgroundColor3 = on and C.ACCENT_D or C.ELEVATED
                            child.TextColor3 = on and C.TEXT_1 or C.TEXT_2
                        end
                    end
                else
                    selected = (opt == "None") and "" or opt
                    Panel.Visible = false; activeDropdown = nil
                end
                DropBtn.Text = displayText()
                local result
                if isMulti then
                    result = {}; for k in pairs(selected) do result[#result + 1] = k end
                else result = selected end
                callback(result)
            end)
        end
    end
    rebuildOptions(options)
    DropBtn.MouseButton1Click:Connect(function()
        if Panel.Visible then Panel.Visible = false; activeDropdown = nil; return end
        if activeDropdown and activeDropdown ~= Panel then activeDropdown.Visible = false end
        local absPos = DropBtn.AbsolutePosition
        local absSize = DropBtn.AbsoluteSize
        Panel.Position = UDim2.fromOffset(absPos.X, absPos.Y + absSize.Y + 4)
        Panel.Visible = true; activeDropdown = Panel
    end)
    local function SetOptions(newOpts)
        rebuildOptions(newOpts)
        Panel.Size = UDim2.new(0, 220, 0, math.min(#newOpts * 28 + 36, 180))
    end
    local function SetSelected(val)
        if isMulti and type(val) == "table" then
            table.clear(selected)
            for _, v in ipairs(val) do selected[v] = true end
        elseif not isMulti and type(val) == "string" then
            selected = val
        end
        DropBtn.Text = displayText()
    end
    return Row, nil, SetOptions, SetSelected
end

S.UserInputService.InputBegan:Connect(function(input)
    if not activeDropdown or not activeDropdown.Visible then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local p = input.Position
    local pos = activeDropdown.AbsolutePosition
    local size = activeDropdown.AbsoluteSize
    if p.X >= pos.X and p.X <= pos.X + size.X
        and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then return end
    activeDropdown.Visible = false; activeDropdown = nil
end)

-- ── WINDOW ───────────────────────────────────────────────────
local Root = Instance.new("Frame", MainSG)
Root.Size = UDim2.new(0, 380, 0, 500)
Root.Position = UDim2.new(0.5, -190, 0.5, -250)
Root.BackgroundTransparency = 1

local Win = Instance.new("Frame", Root)
Win.Size = UDim2.new(1, 0, 1, 0); Win.BackgroundColor3 = C.BASE
Win.ClipsDescendants = true; Corner(Win, 8); Stroke(Win, C.BORDER, 1)

local Header = Instance.new("Frame", Win)
Header.Size = UDim2.new(1, 0, 0, 45); Header.BackgroundColor3 = C.SURFACE; Corner(Header, 8)
local HFix = Instance.new("Frame", Header)
HFix.Size = UDim2.new(1, 0, 0, 8); HFix.Position = UDim2.new(0, 0, 1, -8)
HFix.BackgroundColor3 = C.SURFACE; HFix.BorderSizePixel = 0
local AccentLine = Instance.new("Frame", Header)
AccentLine.Size = UDim2.new(0, 40, 0, 3); AccentLine.Position = UDim2.new(0, 16, 0, 0)
AccentLine.BackgroundColor3 = C.ACCENT; AccentLine.BorderSizePixel = 0; Corner(AccentLine, 2)
local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size = UDim2.new(1, -80, 1, 0); TitleLbl.Position = UDim2.new(0, 16, 0, 0)
TitleLbl.BackgroundTransparency = 1; TitleLbl.RichText = true
TitleLbl.Text = "NXROT  <font color='#EB3C3C'>DUPE</font>"
TitleLbl.TextColor3 = C.TEXT_1; TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 14; TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
MakeDraggable(Root, Header)

local minimized = false
local normalSize = Root.Size
local miniSize   = UDim2.new(0, 380, 0, 45)
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.new(0, 24, 0, 24); MinBtn.Position = UDim2.new(1, -34, 0.5, -12)
MinBtn.BackgroundColor3 = C.SURFACE; MinBtn.BorderSizePixel = 0; MinBtn.Text = "—"
MinBtn.TextColor3 = C.TEXT_2; MinBtn.Font = Enum.Font.GothamBold; MinBtn.TextSize = 14
MinBtn.AutoButtonColor = false; Corner(MinBtn, 4)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    MinBtn.Text = minimized and "□" or "—"
    S.TweenService:Create(Root, TweenInfo.new(0.2), {
        Size = minimized and miniSize or normalSize
    }):Play()
    Win.ClipsDescendants = true
end)

local Content = Instance.new("ScrollingFrame", Win)
Content.Size = UDim2.new(1, 0, 1, -45); Content.Position = UDim2.new(0, 0, 0, 45)
Content.BackgroundTransparency = 1; Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4; Content.ScrollBarImageColor3 = C.DIVIDER

local Layout = Instance.new("UIListLayout", Content)
Layout.Padding = UDim.new(0, 8); Layout.SortOrder = Enum.SortOrder.LayoutOrder
local Pad = Instance.new("UIPadding", Content)
Pad.PaddingTop = UDim.new(0, 15); Pad.PaddingBottom = UDim.new(0, 15)
Pad.PaddingLeft = UDim.new(0, 15); Pad.PaddingRight = UDim.new(0, 15)
Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Content.CanvasSize = UDim2.new(0, 0, 0, Layout.AbsoluteContentSize.Y + 30)
end)

-- ── CONFIG ────────────────────────────────────────────────────
local CONFIG_FILE = "nxr_DupesConfig.json"
local savedConfig = {}
if writefile and readfile and isfile and isfile(CONFIG_FILE) then
    pcall(function()
        savedConfig = S.HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
end

local function saveMyConfig(data)
    if writefile then
        pcall(function()
            writefile(CONFIG_FILE, S.HttpService:JSONEncode(data))
        end)
    end
end

local selectedCrystals       = savedConfig.selectedCrystals       or {}
local selectedRunes          = savedConfig.selectedRunes          or {}
local selectedRarities       = savedConfig.selectedRarities       or {}
local selectedRunesToCollect = savedConfig.selectedRunesToCollect or {}
local crystalOptions         = {}
local runeOptions            = {}
local collectRuneOptions     = {}

local isAutoDropOnKick  = savedConfig.isAutoDropOnKick  or false
local isAutoCollect     = savedConfig.isAutoCollect     or false
local isAutoRejoin      = savedConfig.isAutoRejoin      or false
local rejoinDelay       = savedConfig.rejoinDelay       or 5
local rejoinMethod      = savedConfig.rejoinMethod      or "Current Server"
local privateServerLink = savedConfig.privateServerLink or ""
local collectRadius     = savedConfig.collectRadius     or 100

local function updateConfig()
    saveMyConfig({
        selectedCrystals       = selectedCrystals,
        selectedRunes          = selectedRunes,
        selectedRarities       = selectedRarities,
        selectedRunesToCollect = selectedRunesToCollect,
        isAutoDropOnKick       = isAutoDropOnKick,
        isAutoCollect          = isAutoCollect,
        isAutoRejoin           = isAutoRejoin,
        rejoinDelay            = rejoinDelay,
        rejoinMethod           = rejoinMethod,
        privateServerLink      = privateServerLink,
        collectRadius          = collectRadius,
    })
end

local rarityList = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Empyrean","Pulsar","Quasar"}

local function isCrystalTool(child)
    if not child:IsA("Tool") then return false end
    return child:GetAttribute("CrystalName") ~= nil
        or child:GetAttribute("Tier") ~= nil
        or child.Name:find("Crystal") ~= nil
end
local function isRuneTool(child)
    if not child:IsA("Tool") then return false end
    return child:GetAttribute("RuneId") ~= nil
        or child:GetAttribute("RuneName") ~= nil
        or child:GetAttribute("IsRune") == true
        or child.Name:find("Rune", 1, true) ~= nil
end

local crystalSetOpts, runeSetOpts, runeCollectSetOpts

local function scanInventory()
    table.clear(crystalOptions)
    table.clear(runeOptions)
    table.clear(collectRuneOptions)
    local crystalMap, runeMap = {}, {}
    local function checkItem(child)
        if isRuneTool(child) then
            if not runeMap[child.Name] then
                runeMap[child.Name] = true
                table.insert(runeOptions, child.Name)
                table.insert(collectRuneOptions, child.Name)
            end
        elseif isCrystalTool(child) then
            if not crystalMap[child.Name] then
                crystalMap[child.Name] = true
                table.insert(crystalOptions, child.Name)
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then for _, c in ipairs(bp:GetChildren()) do checkItem(c) end end
    local char = LocalPlayer.Character
    if char then for _, c in ipairs(char:GetChildren()) do checkItem(c) end end
    table.sort(crystalOptions); table.sort(runeOptions); table.sort(collectRuneOptions)
end

scanInventory()

-- ── REMOTES ──────────────────────────────────────────────────
local dropRemoteCache = nil
local function getDropRemote()
    if dropRemoteCache and dropRemoteCache.Parent then return dropRemoteCache end
    local r = S.ReplicatedStorage:FindFirstChild("Remotes")
    dropRemoteCache = r and r:FindFirstChild("CrystalDropRequest")
    return dropRemoteCache
end

-- ── CACHE SYSTEM (pre-scan, tidak jalan saat drop) ───────────
local runeDropCache    = {}
local crystalDropCache = {}

local labelRuneCache    = nil  -- di-assign setelah UI dibuat
local labelCrystalCache = nil

local function readCountFromAttr(tool)
    local attrNames = {"Amount","Count","UsesLeft","Stack","Quantity","StackSize","Uses","Charges","Stacks"}
    for _, attr in ipairs(attrNames) do
        local val = tool:GetAttribute(attr)
        if type(val) == "number" and val > 0 then return math.floor(val) end
    end
    return nil
end

local function readCountFromUI()
    local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local function searchLabels(parent, depth)
        if depth > 6 then return nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("TextLabel") then
                local lname = child.Name:lower()
                if lname:find("uses") or lname:find("count")
                    or lname:find("amount") or lname:find("stack") then
                    local num = tonumber(child.Text)
                    if num and num > 0 then return math.floor(num) end
                end
            end
            local found = searchLabels(child, depth + 1)
            if found then return found end
        end
        return nil
    end
    return searchLabels(playerGui, 0)
end

local function updateCrystalCacheLabel()
    if not labelCrystalCache then return end
    if #selectedCrystals == 0 then
        labelCrystalCache.Text = "Crystal: None dipilih"
        return
    end
    local total = 0
    local parts = {}
    for name, count in pairs(crystalDropCache) do
        total = total + count
        parts[#parts + 1] = name .. " x" .. count
    end
    if total == 0 then
        labelCrystalCache.Text = "Crystal: tidak ada di inv"
    else
        table.sort(parts)
        labelCrystalCache.Text = "Crystal total: " .. total .. "  (" .. table.concat(parts, " | ") .. ")"
    end
end

local function updateRuneCacheLabel()
    if not labelRuneCache then return end
    if #selectedRunes == 0 then
        labelRuneCache.Text = "Rune: None dipilih"
        return
    end
    local total = 0
    local parts = {}
    for name, count in pairs(runeDropCache) do
        total = total + count
        parts[#parts + 1] = name .. " x" .. count
    end
    if total == 0 then
        labelRuneCache.Text = "Rune: scanning... / tidak ditemukan"
    else
        table.sort(parts)
        labelRuneCache.Text = "Rune total: " .. total .. "  (" .. table.concat(parts, " | ") .. ")"
    end
end

local function buildCrystalCache()
    table.clear(crystalDropCache)
    if #selectedCrystals == 0 then updateCrystalCacheLabel(); return end
    local targetSet = {}
    for _, name in ipairs(selectedCrystals) do targetSet[name] = true end
    local function countFrom(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Tool") and isCrystalTool(child) and targetSet[child.Name] then
                crystalDropCache[child.Name] = (crystalDropCache[child.Name] or 0) + 1
            end
        end
    end
    countFrom(LocalPlayer:FindFirstChildOfClass("Backpack"))
    countFrom(LocalPlayer.Character)
    updateCrystalCacheLabel()
end

-- ── RUNE SCAN: tiga lapis penjaga loop ───────────────────────
-- Lapis 1: scanRuneLock     — mutex, cegah dua scan jalan bersamaan
-- Lapis 2: lastRuneScanTime — cooldown 3 detik post-scan
-- Lapis 3: knownRunes       — ChildAdded hanya trigger scan nama baru
local scanRuneLock    = false
local lastRuneScanTime = 0
local RUNE_SCAN_COOLDOWN = 3  -- detik

local function buildRuneCache()
    local now = os.clock()
    if scanRuneLock or (now - lastRuneScanTime) < RUNE_SCAN_COOLDOWN then return end
    scanRuneLock = true

    table.clear(runeDropCache)
    if #selectedRunes == 0 then
        updateRuneCacheLabel()
        lastRuneScanTime = os.clock()
        scanRuneLock = false
        return
    end
    if labelRuneCache then labelRuneCache.Text = "Rune: scanning..." end

    task.spawn(function()
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local bp   = LocalPlayer:FindFirstChildOfClass("Backpack")

        local targetSet = {}
        for _, name in ipairs(selectedRunes) do targetSet[name] = true end

        -- Satu tool per nama: prioritas backpack, fallback char
        local toolsToScan = {}
        local function collectFrom(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and isRuneTool(child)
                    and targetSet[child.Name]
                    and not toolsToScan[child.Name] then
                    toolsToScan[child.Name] = child
                end
            end
        end
        collectFrom(bp)
        collectFrom(char)

        for runeName, runeTool in pairs(toolsToScan) do
            -- Prioritas 1: baca attribute (tanpa equip, instan, tidak trigger ChildAdded)
            local count = readCountFromAttr(runeTool)
            if count then
                runeDropCache[runeName] = count
            elseif hum then
                -- Attribute tidak ada → equip, baca UI, unequip
                -- Lock sudah aktif: ChildAdded dari equip/unequip akan diblok cooldown
                pcall(function() hum:EquipTool(runeTool) end)
                task.wait(0.15)
                local uiCount = readCountFromUI()
                runeDropCache[runeName] = uiCount or 1
                pcall(function() hum:UnequipTools() end)
                task.wait(0.05)
            else
                runeDropCache[runeName] = 1
            end
        end

        updateRuneCacheLabel()
        lastRuneScanTime = os.clock()  -- catat timestamp selesai
        scanRuneLock = false
    end)
end

local function buildAllCache()
    buildCrystalCache()
    buildRuneCache()
end

-- ── AUTO HOOK: ChildAdded hanya trigger scan nama baru ───────
task.spawn(function()
    local knownRunes    = {}  -- nama rune yang sudah di-scan session ini
    local knownCrystals = {}  -- nama crystal yang sudah dicount

    local function hookBackpack(bp)
        if not bp then return end

        bp.ChildAdded:Connect(function(child)
            task.wait(0.1)
            if isCrystalTool(child) then
                -- Crystal tidak perlu equip, rebuild count langsung
                buildCrystalCache()

            elseif isRuneTool(child) then
                -- Cek apakah nama ini ada di selectedRunes
                local inSelection = false
                for _, name in ipairs(selectedRunes) do
                    if name == child.Name then inSelection = true; break end
                end
                -- Hanya scan kalau nama baru DAN ada di selection
                -- Ini blok re-trigger dari equip/unequip di buildRuneCache
                if inSelection and not knownRunes[child.Name] then
                    knownRunes[child.Name] = true
                    buildRuneCache()
                end
            end
        end)

        bp.ChildRemoved:Connect(function(child)
            if isCrystalTool(child) then
                buildCrystalCache()
            end
            -- Reset known supaya scan ulang kalau item ini datang lagi nanti
            if isRuneTool(child) then
                knownRunes[child.Name] = nil
            end
        end)
    end

    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        -- Populate known dari inventory awal sebelum hook aktif
        for _, child in ipairs(bp:GetChildren()) do
            if isRuneTool(child) then knownRunes[child.Name] = true end
            if isCrystalTool(child) then knownCrystals[child.Name] = true end
        end
        hookBackpack(bp)
    end

    LocalPlayer.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            table.clear(knownRunes)
            table.clear(knownCrystals)
            hookBackpack(child)
        end
    end)
end)

-- ── EXECUTE DROP: baca cache, tidak equip, tidak scan ────────
local function executeDropItems()
    local remote = getDropRemote()
    if not remote then return end

    local hasCrystal = next(crystalDropCache) ~= nil
    local hasRune    = next(runeDropCache) ~= nil
    if not hasCrystal and not hasRune then return end

    local bp   = LocalPlayer:FindFirstChildOfClass("Backpack")
    local char = LocalPlayer.Character

    if hasCrystal then
        local function dropFrom(container)
            if not container then return end
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") and crystalDropCache[child.Name] then
                    pcall(function() remote:FireServer(child.Name) end)
                end
            end
        end
        dropFrom(bp); dropFrom(char)
    end

    if hasRune then
        task.spawn(function()
            for runeName, count in pairs(runeDropCache) do
                for i = 1, count do
                    pcall(function() remote:FireServer(runeName) end)
                end
            end
        end)
    end
end

-- ── COLLECT ──────────────────────────────────────────────────
local holdRemote = nil
local function getHoldRemote()
    if holdRemote and holdRemote.Parent then return holdRemote end
    local r = S.ReplicatedStorage:FindFirstChild("Remotes")
    holdRemote = r and r:FindFirstChild("CrystalHoldComplete")
    return holdRemote
end

local function fireCrystalPickup(part)
    local hold = getHoldRemote()
    if hold then pcall(function() hold:FireServer(part) end) end
    local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        pcall(function()
            prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false
            prompt.Enabled = true; prompt.MaxActivationDistance = 9999
        end)
        if typeof(fireproximityprompt) == "function" then
            pcall(function() fireproximityprompt(prompt, 1) end)
            pcall(function() fireproximityprompt(prompt, 0) end)
        end
        pcall(function() prompt:InputHoldBegin(); prompt:InputHoldEnd() end)
    end
    local det = part:FindFirstChildWhichIsA("ClickDetector", true)
    if det and typeof(fireclickdetector) == "function" then
        pcall(function() fireclickdetector(det, 0) end)
    end
end

local function fireRunePickup(obj)
    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
        or (obj:IsA("BasePart") and obj:FindFirstChildOfClass("ProximityPrompt"))
    if prompt then
        pcall(function()
            prompt.HoldDuration = 0; prompt.RequiresLineOfSight = false
            prompt.Enabled = true; prompt.MaxActivationDistance = 9999
        end)
        if typeof(fireproximityprompt) == "function" then
            pcall(function() fireproximityprompt(prompt, 1) end)
            pcall(function() fireproximityprompt(prompt, 0) end)
        end
        pcall(function() prompt:InputHoldBegin(); prompt:InputHoldEnd() end)
    end
    local hold = getHoldRemote()
    if hold then
        if obj:IsA("BasePart") then
            pcall(function() hold:FireServer(obj) end)
        else
            local part = obj:FindFirstChildWhichIsA("BasePart", true)
            if part then pcall(function() hold:FireServer(part) end) end
        end
    end
end

local function getCrystalRarity(child)
    local tierName = child:GetAttribute("TierName")
    if type(tierName) == "string" and tierName ~= "" then return tierName end
    local tier = tonumber(child:GetAttribute("Tier")) or 0
    return rarityList[tier] or "Unknown"
end

local function rarityAllowed(child)
    if #selectedRarities == 0 then return true end
    local r = getCrystalRarity(child)
    for _, sel in ipairs(selectedRarities) do
        if sel == r then return true end
    end
    return false
end

local function isRuneInWorld(obj)
    if obj:GetAttribute("RuneId") ~= nil then return true end
    if obj:GetAttribute("IsRune") == true then return true end
    if obj:GetAttribute("RuneName") ~= nil then return true end
    if obj.Name:find(" Rune", 1, true) ~= nil then return true end
    return false
end

local function runeNameAllowed(obj)
    if #selectedRunesToCollect == 0 then return true end
    for _, name in ipairs(selectedRunesToCollect) do
        if obj.Name == name then return true end
    end
    return false
end

task.spawn(function()
    while task.wait(0.25) do
        if not isAutoCollect then continue end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end
        local WS = game:GetService("Workspace")
        local containers = {WS}
        local dropped = WS:FindFirstChild("DroppedCrystals") or WS:FindFirstChild("Crystals")
        if dropped then table.insert(containers, dropped) end
        local things = WS:FindFirstChild("Things")
        if things then
            local dc = things:FindFirstChild("DroppedCrystals") or things:FindFirstChild("Crystals")
            if dc then table.insert(containers, dc) end
        end
        for _, container in ipairs(containers) do
            for _, child in ipairs(container:GetChildren()) do
                if not isAutoCollect then break end
                if not child:IsA("BasePart") then continue end
                local isValid = child:GetAttribute("Value") ~= nil
                    and (child:GetAttribute("CrystalName") ~= nil or child:GetAttribute("Tier") ~= nil)
                if not isValid then continue end
                if child:GetAttribute("Collected") == true then continue end
                if not rarityAllowed(child) then continue end
                local dist = (child.Position - root.Position).Magnitude
                if dist > collectRadius then continue end
                root.CFrame = CFrame.new(child.Position + Vector3.new(0, 3, 0))
                task.wait(0.05); fireCrystalPickup(child); task.wait(0.1)
            end
        end
        if not isAutoCollect then continue end
        local runeContainers = {}
        local droppedRunes = WS:FindFirstChild("DroppedRunes")
        if droppedRunes then table.insert(runeContainers, droppedRunes) end
        if things then
            local dr = things:FindFirstChild("DroppedRunes")
            if dr then table.insert(runeContainers, dr) end
        end
        if #runeContainers == 0 then table.insert(runeContainers, WS) end
        for _, container in ipairs(runeContainers) do
            for _, obj in ipairs(container:GetChildren()) do
                if not isAutoCollect then break end
                if not isRuneInWorld(obj) then continue end
                if not runeNameAllowed(obj) then continue end
                local pos = nil
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") then
                    local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
                    if pp then pos = pp.Position end
                end
                if not pos then continue end
                local dist = (pos - root.Position).Magnitude
                if dist > collectRadius then continue end
                root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                task.wait(0.05); fireRunePickup(obj); task.wait(0.1)
            end
        end
    end
end)

-- ── BUILD UI ─────────────────────────────────────────────────
BuatSection(Content, "Drop Selection")

local _,_,cSetOpts,_ = BuatDropdown(Content, "Crystals to Drop", crystalOptions, true, selectedCrystals, function(sel)
    selectedCrystals = sel; updateConfig()
    task.spawn(function() task.wait(0.1); buildCrystalCache() end)
end)
crystalSetOpts = cSetOpts

labelCrystalCache = BuatLabel(Content, "Crystal: belum di-scan")
labelCrystalCache.TextColor3 = C.TEXT_3
labelCrystalCache.TextSize = 10

local _,_,rSetOpts,_ = BuatDropdown(Content, "Runes to Drop", runeOptions, true, selectedRunes, function(sel)
    selectedRunes = sel; updateConfig()
    -- Reset knownRunes agar nama yang baru dipilih bisa di-scan
    -- buildRuneCache langsung karena user sengaja ubah selection
    lastRuneScanTime = 0  -- reset cooldown supaya scan jalan sekarang
    task.spawn(function() task.wait(0.1); buildRuneCache() end)
end)
runeSetOpts = rSetOpts

labelRuneCache = BuatLabel(Content, "Rune: belum di-scan")
labelRuneCache.TextColor3 = C.TEXT_3
labelRuneCache.TextSize = 10

local ScanBtn = BuatButton(Content, "⟳ Scan Ulang Count (Crystal + Rune)")
ScanBtn.MouseButton1Click:Connect(function()
    lastRuneScanTime = 0  -- bypass cooldown untuk manual scan
    buildAllCache()
    Notify("Scanning cache...", 2)
end)

local RefreshBtn = BuatButton(Content, "↻ Refresh Inventory")
RefreshBtn.MouseButton1Click:Connect(function()
    scanInventory()
    if crystalSetOpts then crystalSetOpts(crystalOptions) end
    if runeSetOpts    then runeSetOpts(runeOptions) end
    if runeCollectSetOpts then runeCollectSetOpts(collectRuneOptions) end
    lastRuneScanTime = 0  -- bypass cooldown setelah refresh
    task.spawn(function() task.wait(0.2); buildAllCache() end)
    Notify("Inventory di-refresh", 2)
end)

BuatSection(Content, "Auto Collect (Map Scanner)")
BuatDropdown(Content, "Rarity to Collect", rarityList, true, selectedRarities, function(sel)
    selectedRarities = sel; updateConfig()
end)
local _,_,rcSetOpts,_ = BuatDropdown(Content, "Runes to Collect", collectRuneOptions, true, selectedRunesToCollect, function(sel)
    selectedRunesToCollect = sel; updateConfig()
end)
runeCollectSetOpts = rcSetOpts

BuatSlider(Content, "Collect Radius", 10, 5000, collectRadius, function(v)
    collectRadius = math.floor(v); updateConfig()
end)
local CollectBtn, CollectSet = BuatToggle(Content, "Auto Collect Selected", isAutoCollect)
CollectBtn.MouseButton1Click:Connect(function()
    isAutoCollect = not isAutoCollect; CollectSet(isAutoCollect); updateConfig()
end)

BuatSection(Content, "Auto Drop")
local DropBtn, DropSet = BuatToggle(Content, "Auto Drop On Kick", isAutoDropOnKick)
DropBtn.MouseButton1Click:Connect(function()
    isAutoDropOnKick = not isAutoDropOnKick; DropSet(isAutoDropOnKick); updateConfig()
end)

BuatSection(Content, "Rejoin Settings")
BuatInput(Content, "Rejoin Delay [s]", "Contoh: 5", tostring(rejoinDelay), function(val)
    local num = tonumber(val)
    if num then rejoinDelay = num; updateConfig(); Notify("Delay: " .. val .. "s", 2) end
end)

local _,_,methodSetOpts,_ = BuatDropdown(Content, "Rejoin Method",
    {"Current Server","Private Server Link","Random Server"}, false, rejoinMethod, function(sel)
        rejoinMethod = sel; updateConfig()
    end)

BuatInput(Content, "Link Private Server", "Paste full URL VIP", privateServerLink, function(val)
    privateServerLink = val; updateConfig(); Notify("Link di-update", 2)
end)

local RejoinBtn, RejoinSet = BuatToggle(Content, "Auto Rejoin", isAutoRejoin)
RejoinBtn.MouseButton1Click:Connect(function()
    isAutoRejoin = not isAutoRejoin; RejoinSet(isAutoRejoin); updateConfig()
end)

-- ── KICK DETECTION ────────────────────────────────────────────
local connectionTriggered = false
local coreGui = S.CoreGui

local function handleRejoin()
    if not isAutoRejoin then return end
    task.spawn(function()
        task.wait(rejoinDelay)
        local TS = S.TeleportService
        local placeId = game.PlaceId
        while task.wait(3) do
            if rejoinMethod == "Current Server" then
                pcall(function() TS:TeleportToPlaceInstance(placeId, game.JobId, LocalPlayer) end)
            elseif rejoinMethod == "Random Server" then
                pcall(function() TS:Teleport(placeId, LocalPlayer) end)
            elseif rejoinMethod == "Private Server Link" then
                if privateServerLink ~= "" then
                    local code = privateServerLink:match("privateServerLinkCode=([^&]+)")
                    if code then
                        pcall(function() TS:Teleport(placeId, LocalPlayer) end)
                    else
                        pcall(function() TS:TeleportToPlaceInstance(placeId, privateServerLink, LocalPlayer) end)
                    end
                end
            end
        end
    end)
end

local function triggerDropAndRejoin()
    if connectionTriggered then return end
    connectionTriggered = true
    if isAutoDropOnKick then executeDropItems() end
    handleRejoin()
end

S.GuiService.ErrorMessageChanged:Connect(function()
    local ok, msg = pcall(function() return S.GuiService:GetErrorMessage() end)
    if not ok or type(msg) ~= "string" or msg == "" then return end
    msg = msg:lower()
    if msg:find("same account") or msg:find("another device")
        or msg:find("profile session") or msg:find("please rejoin")
        or msg:find("error code: 267") or msg:find("(267)") then
        triggerDropAndRejoin()
    end
end)

task.spawn(function()
    while task.wait(0.05) do
        if connectionTriggered then break end
        pcall(function()
            local promptGui = coreGui:FindFirstChild("RobloxPromptGui")
            if promptGui then
                local overlay = promptGui:FindFirstChild("promptOverlay")
                if overlay then
                    for _, child in ipairs(overlay:GetChildren()) do
                        if child.Name:find("ErrorPrompt") then
                            for _, label in ipairs(child:GetDescendants()) do
                                if label:IsA("TextLabel") then
                                    local text = label.Text:lower()
                                    if text:find("profile session") or text:find("please rejoin")
                                        or text:find("267") or text:find("same account")
                                        or text:find("another device") then
                                        triggerDropAndRejoin(); return
                                    end
                                end
                            end
                        end
                    end
                end
            end
            for _, child in ipairs(coreGui:GetChildren()) do
                if child:IsA("ScreenGui") and child.Enabled then
                    local lname = child.Name:lower()
                    if lname:find("disconnect") or lname:find("error") then
                        for _, label in ipairs(child:GetDescendants()) do
                            if label:IsA("TextLabel") then
                                local text = label.Text:lower()
                                if text:find("profile session") or text:find("please rejoin")
                                    or text:find("267") or text:find("same account")
                                    or text:find("another device") then
                                    triggerDropAndRejoin(); return
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end)

BuatSection(Content, "Misc")
local ManualBtn = BuatButton(Content, "🗑 Manual Drop Selected")
ManualBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        executeDropItems()
        Notify("Manual drop selesai", 2)
    end)
end)
local ResetBtn = BuatButton(Content, "⟳ Reset Character")
ResetBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum.Health = 0 end) end
end)

-- Auto scan on load — rune di background, crystal langsung
task.spawn(function()
    task.wait(1.5)
    buildAllCache()
    Notify("Cache siap!", 2)
end)