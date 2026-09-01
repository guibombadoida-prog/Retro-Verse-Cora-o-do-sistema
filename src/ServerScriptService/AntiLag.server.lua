-- Anti-Lag V2 Script by GUIBOMBADOIDA
-- Nome: "AntiLag"
-- Optimized for performance without removing materials or VFX

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Configuration
local CONFIG = {
	MaxPartsPerFrame = 50, -- Process parts in batches to avoid lag
	ScanInterval = 5, -- Seconds between checks
	DebugMode = false, -- Enable for detailed logs
}

-- List of suspicious patterns (case-insensitive)
local SUSPICIOUS_PATTERNS = {
	{pattern = "lag", antiPatterns = {"anti", "no", "remover", "killer", "fix"}},
}

-- Safe logging function
local function log(message, isWarning)
	if CONFIG.DebugMode or isWarning then
		print(string.format("[Anti-Lag] %s: %s", 
			isWarning and "WARNING" or "INFO", 
			tostring(message)))
	end
end

-- Check if an object is suspicious
local function isSuspiciousObject(obj)
	if not obj or not obj:IsA("Instance") then return false end
	if obj == script then return false end

	local name = string.lower(obj.Name)

	for _, patternData in ipairs(SUSPICIOUS_PATTERNS) do
		local hasMainPattern = string.find(name, patternData.pattern) ~= nil

		if hasMainPattern then
			for _, antiPattern in ipairs(patternData.antiPatterns) do
				if string.find(name, antiPattern) ~= nil then
					return true
				end
			end
		end
	end

	return false
end

-- Remove suspicious objects safely
local function removeSuspiciousObject(obj)
	local success, err = pcall(function()
		if obj and obj.Parent then
			log("Removing suspicious object: " .. obj:GetFullName(), true)
			obj:Destroy()
			return true
		end
	end)

	if not success then
		log("Error removing object: " .. tostring(err), true)
	end

	return success
end

-- Process objects in batches to avoid lag
local function processObjectsBatch(objects, startIndex)
	local processed = 0
	local removed = 0

	for i = startIndex, math.min(startIndex + CONFIG.MaxPartsPerFrame - 1, #objects) do
		if objects[i] and objects[i].Parent then
			processed = processed + 1

			if isSuspiciousObject(objects[i]) then
				if removeSuspiciousObject(objects[i]) then
					removed = removed + 1
				end
			end
		end
	end

	return processed, removed, startIndex + processed
end

-- Scan Workspace asynchronously
local function scanWorkspace()
	log("Starting Workspace scan...")

	local allObjects = Workspace:GetDescendants()
	local totalObjects = #allObjects
	local currentIndex = 1
	local totalRemoved = 0

	log(string.format("Total objects to scan: %d", totalObjects))

	-- Process in batches across multiple frames
	while currentIndex <= totalObjects do
		local processed, removed, nextIndex = processObjectsBatch(allObjects, currentIndex)
		totalRemoved = totalRemoved + removed
		currentIndex = nextIndex

		-- Wait for next frame to avoid freezing the game
		RunService.Heartbeat:Wait()
	end

	log(string.format("Scan completed. Objects removed: %d/%d", 
		totalRemoved, totalObjects))

	return totalRemoved
end

-- Monitor newly added objects
local function setupContinuousMonitoring()
	Workspace.DescendantAdded:Connect(function(obj)
		task.wait(0.1) -- Small delay to ensure object is fully loaded

		if isSuspiciousObject(obj) then
			log("New suspicious object detected: " .. obj:GetFullName(), true)
			removeSuspiciousObject(obj)
		end
	end)

	log("Continuous monitoring enabled")
end

-- Main function
local function main()
	log("Anti-Lag V2 started!")
	log("Waiting 1 second before starting...")
	task.wait(1)

	-- Initial scan
	local removed = scanWorkspace()

	-- Setup continuous monitoring
	setupContinuousMonitoring()

	-- Periodic scans
	task.spawn(function()
		while true do
			task.wait(CONFIG.ScanInterval)
			log("Running periodic scan...")
			scanWorkspace()
		end
	end)

	log(string.format("Anti-lag system fully operational! (Removed: %d)", removed))
end

-- Error protection
local success, err = pcall(main)

if not success then
	warn("[Anti-Lag] CRITICAL ERROR: " .. tostring(err))
end
