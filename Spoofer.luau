-- name spoofer module
-- listens to getgenv() variables for dynamic configuration

local NameSpoofer = {}

-- private storage
local state = {
    originalTexts = {},
    leaderboardConnections = {},
    escMenuConnections = {},
    isRunning = false,
    watcherThread = nil
}

-- utility functions
local function cleanupOriginalTexts()
    for label, _ in pairs(state.originalTexts) do
        if not label or not label.Parent then
            state.originalTexts[label] = nil
        end
    end
end

local function getCurrentConfig()
    return {
        nameTarget = getgenv().nameTarget or "DynamicHub",
        spoofOthers = getgenv().spoofOthers or false
    }
end

local function forceSpoofNameLabel(nameLabel, targetText)
    if not nameLabel or not nameLabel:IsA("TextLabel") then
        return false
    end
    
    if state.originalTexts[nameLabel] == nil then
        state.originalTexts[nameLabel] = nameLabel.Text
    end
    
    nameLabel.Text = targetText
    
    if state.leaderboardConnections[nameLabel] then
        state.leaderboardConnections[nameLabel]:Disconnect()
    end
    
    state.leaderboardConnections[nameLabel] = nameLabel:GetPropertyChangedSignal("Text"):Connect(function()
        if nameLabel and nameLabel.Parent then
            local currentTarget = getgenv().nameTarget or "DynamicHub"
            if nameLabel.Text ~= currentTarget then
                nameLabel.Text = currentTarget
            end
        end
    end)
    
    return true
end

local function revertNameLabel(nameLabel)
    if nameLabel and state.leaderboardConnections[nameLabel] then
        state.leaderboardConnections[nameLabel]:Disconnect()
        state.leaderboardConnections[nameLabel] = nil
    end
    
    if nameLabel and state.originalTexts[nameLabel] then
        nameLabel.Text = state.originalTexts[nameLabel]
        state.originalTexts[nameLabel] = nil
    end
end

-- leaderboard spoofing
local function spoofLeaderboardEntry(entry, isLocalPlayer)
    local config = getCurrentConfig()
    local shouldSpoof = config.spoofOthers or isLocalPlayer
    local targetText = config.nameTarget
    
    local function findAndSpoofName()
        local entryContent = entry:FindFirstChild("PlayerEntryContentFrame")
        if entryContent then
            local overlayFrame = entryContent:FindFirstChild("OverlayFrame")
            if overlayFrame then
                local nameFrame = overlayFrame:FindFirstChild("NameFrame")
                if nameFrame then
                    local playerName = nameFrame:FindFirstChild("PlayerName")
                    if playerName then
                        local innerLabel = playerName:FindFirstChild("PlayerName")
                        local targetLabel = innerLabel or playerName
                        if targetLabel then
                            if shouldSpoof then
                                forceSpoofNameLabel(targetLabel, targetText)
                            else
                                revertNameLabel(targetLabel)
                            end
                        end
                    end
                end
            end
        end
    end
    
    findAndSpoofName()
    
    entry.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "PlayerName" or descendant.Name == "PlayerEntryContentFrame" then
            findAndSpoofName()
        end
    end)
end

-- esc menu spoofing
local function spoofEscNameContainer(nameContainer)
    local current = nameContainer.Parent
    local virtualizedItem = nil
    
    while current do
        if string.find(current.Name, "VirtualizedItem") then
            virtualizedItem = current
            break
        end
        current = current.Parent
    end
    
    local config = getCurrentConfig()
    local isLocalPlayer = virtualizedItem and virtualizedItem.Name == "VirtualizedItem_1"
    local shouldSpoof = config.spoofOthers or isLocalPlayer
    local targetText = config.nameTarget
    
    local nameLabel = nameContainer:FindFirstChild("Name")
    local handleLabel = nameContainer:FindFirstChild("Handle")
    
    if shouldSpoof then
        if nameLabel and nameLabel:IsA("TextLabel") then
            if state.originalTexts[nameLabel] == nil then
                state.originalTexts[nameLabel] = nameLabel.Text
            end
            
            if state.escMenuConnections[nameLabel] then
                state.escMenuConnections[nameLabel]:Disconnect()
            end
            
            local connection = nameLabel:GetPropertyChangedSignal("Text"):Connect(function()
                if nameLabel and nameLabel.Parent then
                    local currentTarget = getgenv().nameTarget or "DynamicHub"
                    if nameLabel.Text ~= currentTarget then
                        nameLabel.Text = currentTarget
                    end
                end
            end)
            state.escMenuConnections[nameLabel] = connection
            nameLabel.Text = targetText
        end
        
        if handleLabel and handleLabel:IsA("TextLabel") then
            if state.originalTexts[handleLabel] == nil then
                state.originalTexts[handleLabel] = handleLabel.Text
            end
            
            if state.escMenuConnections[handleLabel] then
                state.escMenuConnections[handleLabel]:Disconnect()
            end
            
            local connection = handleLabel:GetPropertyChangedSignal("Text"):Connect(function()
                if handleLabel and handleLabel.Parent then
                    local currentTarget = getgenv().nameTarget or "DynamicHub"
                    local expected = "@" .. currentTarget
                    if handleLabel.Text ~= expected then
                        handleLabel.Text = expected
                    end
                end
            end)
            state.escMenuConnections[handleLabel] = connection
            handleLabel.Text = "@" .. targetText
        end
    else
        if nameLabel and nameLabel:IsA("TextLabel") then
            if state.escMenuConnections[nameLabel] then
                state.escMenuConnections[nameLabel]:Disconnect()
                state.escMenuConnections[nameLabel] = nil
            end
            if state.originalTexts[nameLabel] then
                nameLabel.Text = state.originalTexts[nameLabel]
                state.originalTexts[nameLabel] = nil
            end
        end
        
        if handleLabel and handleLabel:IsA("TextLabel") then
            if state.escMenuConnections[handleLabel] then
                state.escMenuConnections[handleLabel]:Disconnect()
                state.escMenuConnections[handleLabel] = nil
            end
            if state.originalTexts[handleLabel] then
                handleLabel.Text = state.originalTexts[handleLabel]
                state.originalTexts[handleLabel] = nil
            end
        end
    end
    
    return true
end

-- watcher functions
local function watchLeaderboard()
    local playerList = game:GetService("CoreGui"):FindFirstChild("PlayerList")
    if not playerList then
        return
    end
    
    for label, connection in pairs(state.leaderboardConnections) do
        connection:Disconnect()
    end
    state.leaderboardConnections = {}
    
    local LocalPlayer = game:GetService("Players").LocalPlayer
    
    for _, child in ipairs(playerList:GetDescendants()) do
        if child:IsA("Frame") and string.match(child.Name, "PlayerEntry") then
            local isLocalPlayer = string.find(child.Name, tostring(LocalPlayer.UserId)) ~= nil
            spoofLeaderboardEntry(child, isLocalPlayer)
        end
    end
    
    playerList.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("Frame") and string.match(descendant.Name, "PlayerEntry") then
            local isLocalPlayer = string.find(descendant.Name, tostring(LocalPlayer.UserId)) ~= nil
            spoofLeaderboardEntry(descendant, isLocalPlayer)
        end
    end)
end

local function watchEscMenuFast()
    local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
    if not robloxGui then
        return
    end
    
    robloxGui.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "NameContainer" then
            task.defer(function()
                spoofEscNameContainer(descendant)
            end)
        end
    end)
    
    for _, nameContainer in ipairs(robloxGui:GetDescendants()) do
        if nameContainer.Name == "NameContainer" then
            spoofEscNameContainer(nameContainer)
        end
    end
end

-- reapply all spoofs when config changes
local function reapplyAllSpoofs()
    if not state.isRunning then
        return
    end
    
    local playerList = game:GetService("CoreGui"):FindFirstChild("PlayerList")
    if playerList then
        for label, connection in pairs(state.leaderboardConnections) do
            connection:Disconnect()
        end
        state.leaderboardConnections = {}
        
        local LocalPlayer = game:GetService("Players").LocalPlayer
        
        for _, child in ipairs(playerList:GetDescendants()) do
            if child:IsA("Frame") and string.match(child.Name, "PlayerEntry") then
                local isLocalPlayer = string.find(child.Name, tostring(LocalPlayer.UserId)) ~= nil
                spoofLeaderboardEntry(child, isLocalPlayer)
            end
        end
    end
    
    local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
    if robloxGui then
        for _, nameContainer in ipairs(robloxGui:GetDescendants()) do
            if nameContainer.Name == "NameContainer" then
                spoofEscNameContainer(nameContainer)
            end
        end
    end
end

-- watch for changes to getgenv() variables
local function watchGlobalVariables()
    local lastConfig = getCurrentConfig()
    
    while state.isRunning do
        task.wait(0.1)
        local currentConfig = getCurrentConfig()
        
        if currentConfig.nameTarget ~= lastConfig.nameTarget or currentConfig.spoofOthers ~= lastConfig.spoofOthers then
            lastConfig = currentConfig
            reapplyAllSpoofs()
        end
        
        cleanupOriginalTexts()
    end
end

-- public api
function NameSpoofer:reapply()
    reapplyAllSpoofs()
end

function NameSpoofer:stop()
    if not state.isRunning then
        return
    end
    
    state.isRunning = false
    
    if state.watcherThread then
        state.watcherThread = nil
    end
    
    -- clean up leaderboard connections
    for label, connection in pairs(state.leaderboardConnections) do
        connection:Disconnect()
    end
    state.leaderboardConnections = {}
    
    -- clean up esc menu connections
    for label, connection in pairs(state.escMenuConnections) do
        connection:Disconnect()
    end
    state.escMenuConnections = {}
    
    -- revert all text labels
    for label, originalText in pairs(state.originalTexts) do
        if label and label.Parent then
            label.Text = originalText
        end
    end
    state.originalTexts = {}
end

function NameSpoofer:start()
    if state.isRunning then
        return
    end
    
    state.isRunning = true
    local coreGui = game:GetService("CoreGui")
    
    -- set up event listeners
    coreGui.ChildAdded:Connect(function(child)
        if child.Name == "PlayerList" then
            task.defer(watchLeaderboard)
        end
    end)
    
    coreGui.ChildRemoved:Connect(function(child)
        if child.Name == "PlayerList" then
            for label, connection in pairs(state.leaderboardConnections) do
                connection:Disconnect()
            end
            state.leaderboardConnections = {}
        end
    end)
    
    -- set up esc menu cleanup
    local function setupEscMenuCleanup()
        local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
        if robloxGui then
            robloxGui.ChildRemoved:Connect(function(child)
                if child.Name == "SettingsClippingShield" then
                    for label, connection in pairs(state.escMenuConnections) do
                        connection:Disconnect()
                    end
                    state.escMenuConnections = {}
                end
            end)
        end
    end
    
    -- start watcher thread
    task.spawn(function()
        watchGlobalVariables()
    end)
    
    -- initialize
    task.spawn(function()
        watchLeaderboard()
        watchEscMenuFast()
        setupEscMenuCleanup()
        
        -- check for robloxgui on startup
        local robloxGui = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
        if not robloxGui then
            coreGui.ChildAdded:Connect(function(child)
                if child.Name == "RobloxGui" then
                    task.defer(function()
                        watchEscMenuFast()
                        setupEscMenuCleanup()
                    end)
                end
            end)
        end
    end)
    
    -- start initial checks
    if game:GetService("CoreGui"):FindFirstChild("PlayerList") then
        task.defer(watchLeaderboard)
    end
    
    if game:GetService("CoreGui"):FindFirstChild("RobloxGui") then
        task.defer(function()
            watchEscMenuFast()
            setupEscMenuCleanup()
        end)
    end
    
    -- periodic cleanup
    task.spawn(function()
        while state.isRunning do
            task.wait(10)
            cleanupOriginalTexts()
        end
    end)
end

function NameSpoofer:isRunning()
    return state.isRunning
end

-- auto-start if getgenv().autoStart is true or if called directly
local function autoStart()
    if getgenv().autoStart == true or getgenv().nameTarget ~= nil then
        NameSpoofer:start()
    end
end

-- return the module
return NameSpoofer, autoStart
