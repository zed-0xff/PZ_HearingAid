
local versionNumber = 1.0;

if HearingAidManager then
	if HearingAidManager.versionNumber >= versionNumber then
		return;
	end
end

HearingAidManager = ISUIElement:derive("HearingAidManager");
HearingAidManager.versionNumber = versionNumber;
HearingAidManager.managers = {};
HearingAidManager.activeManagers = {};

local HA_WORKING_FULL_TYPES = {"hearing_aid.InefficientHearingAid", "hearing_aid.EfficientHearingAid", "hearing_aid.BoostedHearingAid"}
local HA_CHANGED_TRAITS = "hearing_aid_changed_traits";
local HA_ACTIVE = "hearing_aid_battery_active";
local HA_ACTIVE_TIME = "hearing_aid_battery_active_time";
local HA_INITIALIZED = "hearing_aid_battery_initialized";
local HA_BATTERY_MANAGER_VERSION = "hearing_aid_battery_version";
local HA_HAS_BATTERY = "hearing_aid_has_battery";
local HA_BATTERY_LEVEL = "hearing_aid_battery_level";

local function traitFromString(traitName)
	if traitName == nil or traitName == "" then return nil end
	if CharacterTrait == nil then return traitName end
	if traitName == "Deaf" then return CharacterTrait.DEAF end
	if traitName == "HardOfHearing" then return CharacterTrait.HARD_OF_HEARING end
	if traitName == "KeenHearing" then return CharacterTrait.KEEN_HEARING end
	return traitName
end

local function hasTraitCompat(player, traitName)
	if player == nil or traitName == nil or traitName == "" then return false end
	local trait = traitFromString(traitName)
	if CharacterTrait ~= nil and player.hasTrait and trait ~= nil then
		return player:hasTrait(trait)
	end
	local traits = player:getTraits()
	return traits and traits.contains and traits:contains(traitName) or false
end

local function addTraitCompat(player, traitName)
	if player == nil or traitName == nil or traitName == "" then return end
	local trait = traitFromString(traitName)
	local traits = player.getCharacterTraits and player:getCharacterTraits() or player:getTraits()
	if traits == nil then return end
	traits:add(trait)
end

local function removeTraitCompat(player, traitName)
	if player == nil or traitName == nil or traitName == "" then return end
	local trait = traitFromString(traitName)
	local traits = player.getCharacterTraits and player:getCharacterTraits() or player:getTraits()
	if traits == nil then return end
	traits:remove(trait)
end

local function isWorkingHearingAid(item)
	local fullType = item:getFullType();
	for _, workingType in ipairs(HA_WORKING_FULL_TYPES) do
		if fullType == workingType then
			return true;
		end
	end
	return false;
end

local function buildActiveIndex(player)
    return player:getDisplayName() .. player:getPlayerNum()
end

local function getItemID(item)
	return item:getType() .. item:getID();
end

local function initializeHearingAid(itemID, playerID, item)
	-- print(string.format("HearingAid: initializeHearingAid: itemID=%s, playerID=%s, item=%s", tostring(itemID), tostring(playerID), tostring(item)));
	local runTime = 400;
	if item:getFullType() == "hearing_aid.InefficientHearingAid" then
		runTime = 48;
	end
	local hearingAid = {
		playerID = playerID,
		item = item,
		runTime = runTime,
		target = nil,
		adjustablePower = false,
		itemWeightNoBattery = 0.01,
		itemWeightWithBattery = 0.11,
	};
	HearingAidManager.managers[itemID] = HearingAidManager:new(hearingAid);
	HearingAidManager.managers[itemID]:initialize();
end

local function createMenuHearingAid(playerIDOrObj, context, items)
	local playerID = playerIDOrObj
	if playerIDOrObj ~= nil and type(playerIDOrObj) ~= "number" and playerIDOrObj.getPlayerNum then
		playerID = playerIDOrObj:getPlayerNum()
	end
	-- print(string.format("HearingAid: createMenuHearingAid: playerID=%s, context=%s, items=%s", tostring(playerID), tostring(context), tostring(items)));
	for i, e in ipairs(items) do
        local item;
        if instanceof(e, "InventoryItem") then item = e; else item = e.items[1]; end;

        if isWorkingHearingAid(item) then
            local itemID = getItemID(item);
            if not HearingAidManager.managers[itemID] then
                initializeHearingAid(itemID, playerID, item);
            end
            HearingAidManager.managers[itemID]:doBatteryMenu(context);
        end
    end
end

local function ensureWornHearingAidManagers(playerObj)
	if playerObj == nil or playerObj:getWornItems() == nil then return end
	local playerID = playerObj:getPlayerNum()
	local wornItems = playerObj:getWornItems()
	for i = 0, wornItems:size() - 1 do
		local wornItem = wornItems:get(i):getItem()
		if wornItem ~= nil and isWorkingHearingAid(wornItem) then
			local itemID = getItemID(wornItem)
			if not HearingAidManager.managers[itemID] then
				initializeHearingAid(itemID, playerID, wornItem)
			end
		end
	end
end

local function isValid(_, playerID, item)
	local player = getPlayer(playerID)
	if player and item then
		-- Clothing items (like hearing aids) can be worn without item:isEquipped() being true on load.
		return player:isEquipped(item) or player:isEquippedClothing(item)
	end
	return nil
end

local function onActivate(_, playerID, item, manager)
	local player = getPlayer(playerID);
	-- print(string.format("HearingAid: onActivate playerID=%s, player=%s, item=%s, manager=%s, activeIndex=%s", tostring(playerID), tostring(player), tostring(item), tostring(manager), tostring(buildActiveIndex(player))));
	HearingAidManager.activeManagers[buildActiveIndex(player)] = manager;
	local handleDeafness = SandboxVars.HearingAid.HandleDeafness;
	local isBoosted = item:getFullType() == "hearing_aid.BoostedHearingAid";
	local modData = item:getModData();
	-- print(string.format("HearingAid: onActivate: modData=%s, changedTraits=%s", tostring(modData), tostring(modData[HA_CHANGED_TRAITS])));
	modData[HA_CHANGED_TRAITS] = nil;
	if hasTraitCompat(player, "Deaf") then
		if handleDeafness == 2 then
			removeTraitCompat(player, "Deaf");
			if isBoosted then
				modData[HA_CHANGED_TRAITS] = {"Deaf", ""};
			else
				modData[HA_CHANGED_TRAITS] = {"Deaf", "HardOfHearing"};
				addTraitCompat(player, "HardOfHearing");
			end
		elseif handleDeafness == 3 then
			if isBoosted then
				modData[HA_CHANGED_TRAITS] = {"Deaf", "HardOfHearing"};
				removeTraitCompat(player, "Deaf");
				addTraitCompat(player, "HardOfHearing");
			end
		end
	elseif hasTraitCompat(player, "HardOfHearing") then
		removeTraitCompat(player, "HardOfHearing");
		if isBoosted then
			modData[HA_CHANGED_TRAITS] = {"HardOfHearing", "KeenHearing"};
			addTraitCompat(player, "KeenHearing");
		else
			modData[HA_CHANGED_TRAITS] = {"HardOfHearing", ""};
		end
	elseif hasTraitCompat(player, "KeenHearing") then
		-- Congrats! You already have great hearing.
	else
		if isBoosted then
			modData[HA_CHANGED_TRAITS] = {"", "KeenHearing"};
			addTraitCompat(player, "KeenHearing");
		else
			modData[HA_CHANGED_TRAITS] = {"", ""};
		end
	end

	if modData[HA_CHANGED_TRAITS] ~= nil then
		modData[HA_CHANGED_TRAITS][3] = playerID;
	end
end

local function onDeactivate(_, playerID, item, manager)
	local player = getPlayer(playerID);
	-- print(string.format("HearingAid: onDeactivate playerID=%s, player=%s, item=%s, manager=%s", tostring(playerID), tostring(player), tostring(item), tostring(manager)));
	HearingAidManager.activeManagers[buildActiveIndex(player)] = nil;
	local changedTraits = item:getModData()[HA_CHANGED_TRAITS];
	if changedTraits ~= nil then
		local removedTrait, addedTrait, activePlayerID = changedTraits[1], changedTraits[2], changedTraits[3];
		local activePlayer = getPlayer(activePlayerID);
		if player ~= activePlayer then
			-- I think it's possible for this to happen if a player dies while wearing this
			error("HearingAid for " .. buildActiveIndex(activePlayer) .. " deactivated on " .. buildActiveIndex(player));
		end
		if addedTrait ~= "" then
			removeTraitCompat(activePlayer, addedTrait);
		end
		if removedTrait ~= "" then
			addTraitCompat(activePlayer, removedTrait);
		end
	end
end

local function onBatteryDead(_, playerID, item, manager)
	onDeactivate(_, playerID, item, manager);
end

local function initHearingAid()
	-- print("HearingAid: initHearingAid");
	for _, workingType in ipairs(HA_WORKING_FULL_TYPES) do
		HearingAidInventoryBar.registerItem(workingType, HA_BATTERY_LEVEL, getTextOrNull("IGUI_invpanel_Remaining") or "Remaining: ");
	end

	Events.OnFillInventoryObjectContextMenu.Add(createMenuHearingAid);
	Events.OnPlayerUpdate.Add(ensureWornHearingAidManagers);
end

Events.OnGameStart.Add(initHearingAid);

function HearingAidManager:activate()
	local modData = self.item:getModData();
	if not modData[HA_ACTIVE] then
		modData[HA_ACTIVE] = true;
		modData[HA_ACTIVE_TIME] = getGameTime():getWorldAgeHours();
		onActivate(self.target, self.playerID, self.item, self);
	end
end

function HearingAidManager:deactivate()
	local modData = self.item:getModData();
	if modData[HA_ACTIVE] == true then
		modData[HA_ACTIVE] = false;
		-- print("HearingAid: deactivate target=" .. tostring(self.target) .. ", playerID=" .. tostring(self.playerID) .. ", item=" .. tostring(self.item));
		onDeactivate(self.target, self.playerID, self.item, self);
	end
end

local function predicateNotEmpty(item)
	return item:getCurrentUsesFloat() > 0
end

function HearingAidManager:doBatteryMenu(context)
	if self:hasBattery() then
		context:addOption(getTextOrNull("ContextMenu_Remove_Battery") or "Remove Battery", self, HearingAidManager.queueAction, "RemoveBattery");
	else
		if self:getPlayer():getInventory():containsTypeRecurse("Battery") then
			local battery, batteryLevel;
			local addedSubmenu = false;
			local addBatteryOption = context:addOption(getTextOrNull("ContextMenu_AddBattery") or "Add Battery", self.item);
			local subcontext = context:getNew(context);
			context:addSubMenu(addBatteryOption, subcontext);
			local batteries = self:getPlayer():getInventory():getAllTypeEvalRecurse("Battery", predicateNotEmpty);
			for i = 0, batteries:size() - 1 do
				battery = batteries:get(i);
				batteryLevel = math.floor(battery:getCurrentUsesFloat() * 100);
				if batteryLevel > 0 then
					subcontext:addOption(battery:getName() .. " (" .. batteryLevel .. "%)", self, HearingAidManager.queueAction, "AddBattery", battery);
					addedSubmenu = true;
				end
			end
			if not addedSubmenu then context:removeLastOption(); end;
		end
	end
end

function HearingAidManager:getPlayer()
	return getPlayer(self.playerID);
end

function HearingAidManager:getItem()
	return self.item;
end

function HearingAidManager:isActive()
	return self.item:getModData()[HA_ACTIVE] == true;
end

function HearingAidManager:hasPower()
	return self.item:getModData()[HA_BATTERY_LEVEL] > 0 or false;
end

function HearingAidManager:hasBattery()
	return self.item:getModData()[HA_HAS_BATTERY] or false;
end

function HearingAidManager:addBattery(battery)
	self.item:getModData()[HA_HAS_BATTERY] = true;
	self.item:getModData()[HA_BATTERY_LEVEL] = battery:getCurrentUsesFloat();
	self.item:setActualWeight(self.itemWeightWithBattery);
	self.item:setCustomWeight(true);
	self:getPlayer():getInventory():DoRemoveItem(battery);
end

function HearingAidManager:removeBattery()
	local battery = instanceItem("Base.Battery");
	battery:setCurrentUsesFloat(self.item:getModData()[HA_BATTERY_LEVEL]);
	self:getPlayer():getInventory():AddItem(battery);
	self.item:getModData()[HA_HAS_BATTERY] = false;
	self.item:getModData()[HA_BATTERY_LEVEL] = 0;
	self.item:setActualWeight(self.itemWeightNoBattery);
	self.item:setCustomWeight(true);
	self:deactivate();
end

function HearingAidManager:prerender()
	--TODO: HUD battery meter?
end

function HearingAidManager:render()
	--TODO: HUD battery meter?
end

LuaEventManager.AddEvent("UI_Update");

function HearingAidManager:queueAction(action, item, item2, item3, item4, arg1, arg2, arg3, arg4)
	local timedAction = HearingAidAction:new(self:getPlayer(), self, action, item, item2, item3, item4, arg1, arg2, arg3, arg4);
	ISTimedActionQueue.add(timedAction);
end

function HearingAidManager:update()
	local isValid = isValid(self.target, self.playerID, self.item);
	local shouldBeActive = isValid and self:hasBattery() and self:hasPower()
	if shouldBeActive and not self:isActive() then
		self:activate()
	elseif not shouldBeActive and self:isActive() then
		self:deactivate(isValid == nil)
	end
	if not isValid then return end
	if self:isActive() then
		local batteryLevel = self.item:getModData()[HA_BATTERY_LEVEL] or 0;
		local reductionThisFrame = 0;

		local isPaused = UIManager.getSpeedControls() and UIManager.getSpeedControls():getCurrentGameSpeed() == 0;
		if isPaused then
			return
		end
		if batteryLevel > 0 then
			local worldTime = getGameTime():getWorldAgeHours();
			local activeTime = self.item:getModData()[HA_ACTIVE_TIME];
			reductionThisFrame = (worldTime - activeTime) / self.runTime;
			batteryLevel = batteryLevel - reductionThisFrame;
			if batteryLevel < 0 then batteryLevel = 0; end;
			if batteryLevel == 0 then
				self.item:getModData()[HA_ACTIVE] = false;
				onBatteryDead(self.target, self.playerID, self.item, self);
			end
			self.item:getModData()[HA_BATTERY_LEVEL] = batteryLevel;
			self.item:getModData()[HA_ACTIVE_TIME] = worldTime;
			-- print("activeTime " ..activeTime);
			-- print("worldTime " ..worldTime);
			-- print("powerLevel = "..powerLevel);
			-- print("batterylevel = "..batterylevel);
			-- print("reductionThisFrame = "..reductionThisFrame);
		end
	end

	triggerEvent("UI_Update");
end

function HearingAidManager:initialize()
	-- EURO SPELLING DETECTED
	ISUIElement.initialise(self);
	local modData = self.item:getModData();
	local alreadyInitialized = modData[HA_INITIALIZED];
	local shouldUpgrade = not modData[HA_BATTERY_MANAGER_VERSION] or modData[HA_BATTERY_MANAGER_VERSION] < versionNumber;
	if not alreadyInitialized or shouldUpgrade then
		-- May have had battery when upgrading
		local hadBattery = modData[HA_HAS_BATTERY];
		local hasBattery = hadBattery or (alreadyInitialized and ZombRandBetween(0, 10) < 2);
		modData[HA_BATTERY_MANAGER_VERSION] = versionNumber;
		modData[HA_ACTIVE] = false;
		modData[HA_HAS_BATTERY] = hasBattery;
		modData[HA_BATTERY_LEVEL] = (hadBattery and 1) or (hasBattery and (ZombRandBetween(0, 10) / 10));
		modData[HA_INITIALIZED] = true;
	end
	if self:hasBattery() then
		self.item:setActualWeight(self.itemWeightWithBattery);
	else
		self.item:setActualWeight(self.itemWeightNoBattery);
	end
	self.item:setCustomWeight(true);
	-- Keep manager updating all the time so auto-activation/deactivation can work.
	self:addToUIManager();
end

function HearingAidManager:new(item)
	local x, y, width, height = 0, 0, 0, 0;
	local o = ISUIElement:new(x, y, width, height);
	setmetatable(o, self);
	self.__index = self;
	for k, v in pairs(item) do o[k] = v; end;
	o.target = o.target or {};
	return o;
end

HearingAidManager.DismantleHearingAid = function(items, result, player)
	for i=1, items:size() do
		local item = items:get(i-1);
		if isWorkingHearingAid(item) and item:getModData()[HA_HAS_BATTERY] == true then
			local battery = instanceItem("Base.Battery");
			battery:setCurrentUsesFloat(item:getModData()[HA_BATTERY_LEVEL]);
			player:getInventory():AddItem(battery);
			break
		end
	end
end

HearingAidManager.IsBoostValid = function(item)
	return SandboxVars.HearingAid.EnableBoosted == true;
end
