--!strict
-- Rebilium Studio Bridge v1: opt-in connection heartbeat only.
--
-- This plugin does NOT execute scripts, alter the DataModel, change
-- Player binaries, or use undocumented APIs. It sends only a versioned
-- hello request to the local test host after explicit pairing.

local HttpService = game:GetService("HttpService")

local URL = "http://127.0.0.1:37828/v1/studio/hello"
local INTERVAL = 10

local toolbar = plugin:CreateToolbar("Rebilium")
local toolbarButton = toolbar:CreateButton(
    "Rebilium Connection",
    "Pair Roblox Studio with the Rebilium localhost backend",
    ""
)

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    false,
    false,
    420,
    236,
    320,
    190
)
local widget = plugin:CreateDockWidgetPluginGuiAsync(
    "RebiliumStudioHandshakeV1",
    widgetInfo
)
widget.Title = "Rebilium · Studio Connection"

local frame = Instance.new("Frame")
frame.BackgroundColor3 = Color3.fromRGB(29, 31, 43)
frame.BorderSizePixel = 0
frame.Size = UDim2.fromScale(1, 1)
frame.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 16)
padding.PaddingLeft = UDim.new(0, 16)
padding.PaddingRight = UDim.new(0, 16)
padding.Parent = frame

local flow = Instance.new("UIListLayout")
flow.Padding = UDim.new(0, 10)
flow.Parent = frame

local function addLabel(text: string, height: number, size: number): TextLabel
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, height)
    label.Text = text
    label.TextSize = size
    label.TextColor3 = Color3.fromRGB(230, 231, 246)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.GothamMedium
    label.TextWrapped = true
    label.Parent = frame
    return label
end

addLabel("Pair with Rebilium", 24, 18)
addLabel(
    "Run the Rebilium Terminal host and paste its one-time Studio pairing token.",
    36,
    12
)

local tokenField = Instance.new("TextBox")
tokenField.Name = "PairingToken"
tokenField.PlaceholderText = "Paste the token printed in Terminal"
tokenField.Text = ""
tokenField.ClearTextOnFocus = false
tokenField.TextSize = 13
tokenField.Font = Enum.Font.Code
tokenField.TextColor3 = Color3.fromRGB(249, 249, 255)
tokenField.PlaceholderColor3 = Color3.fromRGB(146, 149, 168)
tokenField.BackgroundColor3 = Color3.fromRGB(49, 50, 67)
tokenField.BorderSizePixel = 0
tokenField.Size = UDim2.new(1, 0, 0, 36)
tokenField.Parent = frame

local connectButton = Instance.new("TextButton")
connectButton.Name = "ConnectButton"
connectButton.Text = "Connect to local backend"
connectButton.TextSize = 13
connectButton.Font = Enum.Font.GothamBold
connectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
connectButton.BackgroundColor3 = Color3.fromRGB(102, 85, 212)
connectButton.BorderSizePixel = 0
connectButton.Size = UDim2.new(1, 0, 0, 35)
connectButton.Parent = frame

local status = addLabel("Disconnected — no requests sent", 32, 12)

local paired = false
local pairingToken = ""
local generation = 0
local requestPending = false

local function setStatus(text: string, ok: boolean)
    status.Text = text
    status.TextColor3 = ok
        and Color3.fromRGB(146, 230, 188)
        or Color3.fromRGB(245, 176, 182)
end

local function heartbeat(token: string): (boolean, string)
    local requestBody = HttpService:JSONEncode({
        version = 1,
        client = "RebiliumStudioPlugin",
    })

    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Rebilium-Token"] = token,
            },
            Body = requestBody,
        })
    end)

    if not success then
        return false, "Host unreachable or HTTP permission denied"
    end
    if not response.Success then
        if response.StatusCode == 403 then
            return false, "Pairing token rejected — check Terminal"
        end
        return false, "Host refused request (HTTP " .. tostring(response.StatusCode) .. ")"
    end

    local decodedOK, payload = pcall(function()
        return HttpService:JSONDecode(response.Body)
    end)
    if not decodedOK or type(payload) ~= "table"
        or payload.version ~= 1 or payload.ok ~= true then
        return false, "Unexpected backend response"
    end
    return true, "Paired — Studio heartbeat delivered"
end

local function connect()
    if requestPending then
        return
    end
    local candidate = tokenField.Text:gsub("%s+", "")
    if #candidate < 20 then
        setStatus("Paste the one-time token from Terminal", false)
        return
    end

    requestPending = true
    generation += 1
    local myGeneration = generation
    paired = false
    setStatus("Connecting to 127.0.0.1…", false)

    task.spawn(function()
        local ok, message = heartbeat(candidate)
        if generation ~= myGeneration then
            return
        end
        requestPending = false
        setStatus(message, ok)
        if not ok then
            return
        end

        paired = true
        pairingToken = candidate
        tokenField.Text = "" -- don't leave the token visible in the widget
        while paired and generation == myGeneration do
            task.wait(INTERVAL)
            if paired and generation == myGeneration then
                local heartbeatOK, heartbeatMessage = heartbeat(pairingToken)
                if not heartbeatOK then
                    paired = false
                    pairingToken = ""
                    setStatus(heartbeatMessage, false)
                    break
                end
            end
        end
    end)
end

connectButton.MouseButton1Click:Connect(connect)
toolbarButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)
plugin.Unloading:Connect(function()
    paired = false
    pairingToken = ""
    generation += 1
end)
