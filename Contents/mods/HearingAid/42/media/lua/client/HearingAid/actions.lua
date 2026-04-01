local versionNumber = 1.0;

if HearingAidAction then
	if HearingAidAction.versionNumber >= versionNumber then
		return;
	end
end

require "TimedActions/ISBaseTimedAction"

HearingAidAction = ISBaseTimedAction:derive("HearingAidAction");
HearingAidAction.versionNumber = versionNumber;

function HearingAidAction:isValid()
	if self.doAction and self.manager then
		return self["isValid"..self.doAction](self);
	end
	return false;
end

function HearingAidAction:perform()
	if self.doAction and self.manager then
		self["perform"..self.doAction](self);
	end
	ISBaseTimedAction.perform(self)
end

function HearingAidAction:isValidAddBattery()
	if self.doAction and self.manager and self.item then
		return (not self.manager:hasBattery());
	end
	return false;
end

function HearingAidAction:performAddBattery()
	if self:isValidAddBattery() and self.item then
		self.manager:addBattery(self.item);
	end
end

function HearingAidAction:isValidRemoveBattery()
	if self.doAction and self.manager then
		return self.manager:hasBattery();
	end
	return false;
end

function HearingAidAction:performRemoveBattery()
	if self:isValidRemoveBattery() then
		self.manager:removeBattery();
	end
end

function HearingAidAction:update()

end

function HearingAidAction:new(player, manager, doAction, item, item2, item3, item4, arg1, arg2, arg3, arg4)
	local o = {};
	setmetatable(o, self);
	self.__index = self;

	-- ISBaseTimedAction expects player to be called character.
	o.character = player;
	o.manager = manager;
	o.doAction = doAction;
	o.item = item;
	o.item2 = item2;
	o.item3 = item3;
	o.item4 = item4;
	o.arg1 = arg1;
	o.arg2 = arg2;
	o.arg3 = arg3;
	o.arg4 = arg4;
	o.stopOnWalk = false;
	o.stopOnRun = true;
	o.maxTime = 30;

	return o;
end
