--!strict
-- Rebilium Studio Bridge v2: paired heartbeat and manual script import.
--
-- Never executes scripts or changes Roblox Player. Users must explicitly
-- fetch, inspect and import Luau as an inert ModuleScript in ServerStorage.

local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local ScriptEditorService = game:GetService("ScriptEditorService")

local URL = "http://127.0.0.1:37828/v1/studio/hello"
local HTTP_ROOT = "http://127.0.0.1:37828"
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
    500,
    640,
    400,
    500
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

local fetchButton = Instance.new("TextButton")
fetchButton.Name = "FetchPendingScript"
fetchButton.Text = "Fetch script preview"
fetchButton.TextSize = 13
fetchButton.Font = Enum.Font.GothamBold
fetchButton.TextColor3 = Color3.fromRGB(255, 255, 255)
fetchButton.BackgroundColor3 = Color3.fromRGB(62, 94, 172)
fetchButton.BorderSizePixel = 0
fetchButton.Size = UDim2.new(1, 0, 0, 34)
fetchButton.Parent = frame

local scriptName = addLabel("No script offered by Rebilium", 24, 13)

local scriptPreview = Instance.new("TextBox")
scriptPreview.Name = "ScriptPreview"
scriptPreview.Size = UDim2.new(1, 0, 0, 220)
scriptPreview.BackgroundColor3 = Color3.fromRGB(19, 22, 34)
scriptPreview.TextColor3 = Color3.fromRGB(224, 227, 246)
scriptPreview.TextSize = 12
scriptPreview.Font = Enum.Font.Code
scriptPreview.MultiLine = true
scriptPreview.TextWrapped = false
scriptPreview.TextEditable = false
scriptPreview.ClearTextOnFocus = false
scriptPreview.TextXAlignment = Enum.TextXAlignment.Left
scriptPreview.TextYAlignment = Enum.TextYAlignment.Top
scriptPreview.Text = "No source received. Nothing will be executed."
scriptPreview.Parent = frame

local importButton = Instance.new("TextButton")
importButton.Name = "ApproveImport"
importButton.Text = "Approve: import inert ModuleScript"
importButton.TextSize = 13
importButton.Font = Enum.Font.GothamBold
importButton.TextColor3 = Color3.fromRGB(255, 255, 255)
importButton.BackgroundColor3 = Color3.fromRGB(47, 128, 112)
importButton.BorderSizePixel = 0
importButton.Size = UDim2.new(1, 0, 0, 34)
importButton.Parent = frame

local importStatus = addLabel("Import requires your explicit click.", 48, 12)


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

local pendingScript: {[string]: any}? = nil
local fetching = false
local importing = false

fetchButton.MouseButton1Click:Connect(function()
    if not paired or pairingToken == "" then
        importStatus.Text = "Pair with the local backend before fetching."
        return
    end
    if fetching then
        return
    end
    fetching = true
    importStatus.Text = "Fetching pending preview from localhost…"
    task.spawn(function()
        local success, response = pcall(function()
            return HttpService:RequestAsync({
                Url = HTTP_ROOT .. "/v1/scripts/pending",
                Method = "GET",
                Headers = {
                    ["X-Rebilium-Token"] = pairingToken,
                },
            })
        end)
        fetching = false
        if not success or not response.Success then
            importStatus.Text = "Could not fetch pending script. Check host connection."
            return
        end
        local ok, parsed = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if not ok or type(parsed) ~= "table" or parsed.version ~= 1 then
            importStatus.Text = "Backend returned invalid preview."
            return
        end
        if parsed.pending ~= true then
            pendingScript = nil
            scriptName.Text = "No pending script"
            scriptPreview.Text = "Use Rebilium's Send to Studio button first."
            importStatus.Text = "No script is waiting."
            return
        end
        if type(parsed.id) ~= "string" or type(parsed.title) ~= "string"
            or type(parsed.source) ~= "string" then
            importStatus.Text = "Incomplete script preview."
            return
        end
        pendingScript = parsed
        scriptName.Text = "Review: " .. parsed.title
        scriptPreview.Text = parsed.source
        importStatus.Text = "Review the complete source, then click Approve to import."
    end)
end)

importButton.MouseButton1Click:Connect(function()
    if importing then
        return
    end
    local proposed = pendingScript
    if not proposed then
        importStatus.Text = "Fetch and review a script before importing."
        return
    end
    importing = true
    task.spawn(function()
        -- ModuleScripts in ServerStorage are inert until explicitly required.
        -- No loadstring(), require(), or game execution is performed here.
        local cleanName = string.gsub(proposed.title, "[^%w_]", "_")
        cleanName = string.sub(cleanName, 1, 60)
        if cleanName == "" then
            cleanName = "ImportedScript"
        end
        local module = Instance.new("ModuleScript")
        module.Name = "Rebilium_" .. cleanName
        module.Parent = ServerStorage

        local ok, err = pcall(function()
            ScriptEditorService:UpdateSourceAsync(module, function(_old: string)
                return proposed.source
            end)
        end)
        if not ok then
            module:Destroy()
            importStatus.Text = "Studio import failed: " .. tostring(err)
            importing = false
            return
        end

        -- Import already happened, so an acknowledgement error must never
        -- trigger a second import. Clear the local preview either way.
        pendingScript = nil
        scriptName.Text = "Imported: " .. module.Name
        scriptPreview.Text = "Source saved into ServerStorage as ModuleScript."
        local ackOK = pcall(function()
            HttpService:RequestAsync({
                Url = HTTP_ROOT .. "/v1/scripts/ack",
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-Rebilium-Token"] = pairingToken,
                },
                Body = HttpService:JSONEncode({
                    version = 1,
                    id = proposed.id,
                }),
            })
        end)
        importStatus.Text = ackOK
            and "Imported into ServerStorage. Nothing executed."
            or "Imported locally; could not clear backend offer."
        importing = false
    end)
end)

connectButton.MouseButton1Click:Connect(connect)
toolbarButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)
plugin.Unloading:Connect(function()
    paired = false
    pairingToken = ""
    generation += 1
end)
