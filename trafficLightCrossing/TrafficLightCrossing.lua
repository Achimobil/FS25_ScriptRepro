--[[
Copyright (C) Achimobil, since 2022

Author: Achimobil
Date: 01.03.2025
Version: see object

Contact/Help/Tutorials:
https://github.com/Achimobil/FS25_ScriptRepro

Usage:
Create Traffic Light with these structure. Example has 2 traffic lights in the crossing:
- Crossing - transform group containing all traffic lights for this crossing.
  Attributes:
    script with name "onCreate" and value "modOnCreate.TrafficLightCrossing".
    string with name "phaseSeconds" and comma seperated list of green light phase length in full seconds.
    integer with name "trafficLightId". Must contain a unique id for the crossing for syncing in multiplayer
-- TrafficLight - transform group for one traffic light in the crossing. create one including all content for every traffic light. Attributes: integer with the number of phase the traffic light belongs to inside the crossing
--- YourModelNode - put your model of the traffic light in here
--- Lights - transform group for the lights
---- red - transform group for the red lights of this traffic light. Can contain multiple lights. Every node inside will be changed in visibility during the phases.
---- orange - transform group for the orange lights like the red lights
---- green - transform group for the green lights like the red lights
--- aiBlocker - transform group for the ai traffic blocker. Has to be a kinematic rigid body with activated collision. Collision value is set by the script.
-- TrafficLight
--- YourModelNode
--- Lights
---- red
---- orange
---- green
--- aiBlocker

You can add multiple TrafficLight nodes. Also multiple of them with the same phase.
Make sure that your phaseSeconds has the same amount of times than you use as numbers in the TrafficLight nodes.
Phases are started with 1 and can be up to unlimited for big crossings.


Important:
You are allowed to use this script without any changes in your own FS25 mods.
Publish mods with this script is generall allowed for all mods which are not behind a "paywall".
So using in Mods published over patreon or similar ways is complete forbidden.

Changelog
1.1.2.0 Making my 22er Skript running in 25.
]]

TrafficLightCrossing = {}
TrafficLightCrossing.debug = false;
TrafficLightCrossing.version = "1.2.0.0";
TrafficLightCrossing.trafficLights = {}
TrafficLightCrossingPhase = {
    GREEN = 1,
    ORANGE = 2,
    RED = 3,
    REDORANGE = 4
}

--- Print the given Table to the log
-- @param string text parameter Text before the table
-- @param table myTable The table to print
-- @param number maxDepth depth of print, default 2
function TrafficLightCrossing.DebugTable(text, myTable, maxDepth)
    if not TrafficLightCrossing.Debug then return end
    if myTable == nil then
        Logging.info("TrafficLightCrossingDebug: " .. text .. " is nil");
    else
        Logging.info("TrafficLightCrossingDebug: " .. text)
        DebugUtil.printTableRecursively(myTable,"_",0, maxDepth or 2);
    end
end

---Print the text to the log. Example: TrafficLightCrossing.DebugText("Alter: %s", age);
-- @param string text the text to print formated
-- @param any ... format parameter
function TrafficLightCrossing.DebugText(text, ...)
    if not TrafficLightCrossing.debug then return end
    Logging.info("TrafficLightCrossingDebug: " .. string.format(text, ...));
end

Logging.info(string.format("TrafficLightCrossing Version %s by Achimobil loaded", TrafficLightCrossing.version));

---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
function TrafficLightCrossing.prerequisitesPresent(specializations)
    TrafficLightCrossing.DebugText(" TrafficLightCrossing.prerequisitesPresent(%s)", specializations);

    return true
end

local TrafficLightCrossing_mt = Class(TrafficLightCrossing)

function TrafficLightCrossing.onCreate(id)
    TrafficLightCrossing.DebugText(" TrafficLightCrossing.onCreate(%s)", id);

    local newItem = TrafficLightCrossing.new(id);
    if g_server ~= nil then
        g_currentMission:addUpdateable(newItem);
    end
end

function TrafficLightCrossing.new(id)
    TrafficLightCrossing.DebugText(" TrafficLightCrossing.new(%s)", id);

    local instance = {};
    instance.phases = {};
    instance.currentPhase = 1;
    instance.numPhases = 0;

    setmetatable(instance, TrafficLightCrossing_mt);

    -- auslesen der Daten um diese dann einfach zu schalten
    local phaseSecondsString = getUserAttribute(id, "phaseSeconds");
    instance.trafficLightId = getUserAttribute(id, "trafficLightId");

    if phaseSecondsString ~= nil then
        local phaseSecondsList = phaseSecondsString:split(",");

        for i = 1, #phaseSecondsList do
            local phase = {};
            phase.redLights = {};
            phase.orangeLights = {};
            phase.greenLights = {};
            phase.aiBlockers = {};
            phase.innerPhase = TrafficLightCrossingPhase.RED;
            phase.greenMiliSeconds = tonumber(phaseSecondsList[i]) * 1000;

            table.insert(instance.phases, phase);
            instance.numPhases = instance.numPhases + 1;
        end
    end

    local numTrafficLights = getNumOfChildren(id);
    for i = 0, numTrafficLights - 1 do
        local trafficLightNodeId = getChildAt(id, i)
        local phaseNumber = Utils.getNoNil(getUserAttribute(trafficLightNodeId, "phase"), 0);
        if phaseNumber == 0 or instance.phases[phaseNumber] == nil then
            local nodePath = I3DUtil.getNodePath(trafficLightNodeId);
            Logging.error("TrafficLightCrossing: Phase missing or wrong in '%s'. Must be 1 or greater", nodePath);
        end

        if instance.phases[phaseNumber] ~= nil then
            local phase = instance.phases[phaseNumber];

            -- einfügen der Lampen knoten in die Phase pro Lampe
            local lightsNodeId = getChildAt(trafficLightNodeId, 1)

            local redLightsNode = getChildAt(lightsNodeId, 0);
            local numRedLights = getNumOfChildren(redLightsNode);
            for j = 0, numRedLights - 1 do
                local redLightNode = getChildAt(redLightsNode, j);
                table.insert(phase.redLights, redLightNode);
            end

            local orangeLightsNode = getChildAt(lightsNodeId, 1);
            local numOrangeLights = getNumOfChildren(orangeLightsNode);
            for j = 0, numOrangeLights - 1 do
                local orangeLightNode = getChildAt(orangeLightsNode, j);
                table.insert(phase.orangeLights, orangeLightNode);
            end

            local greenLightsNode = getChildAt(lightsNodeId, 2);
            local numGreenLights = getNumOfChildren(greenLightsNode);
            for j = 0, numGreenLights - 1 do
                local greenLightNode = getChildAt(greenLightsNode, j);
                table.insert(phase.greenLights, greenLightNode);
            end

            local aiBlockerNodeId = getChildAt(trafficLightNodeId, 2)
            local numAiBlocker = getNumOfChildren(aiBlockerNodeId);
            for j = 0, numAiBlocker - 1 do
                local aiBlockerNode = getChildAt(aiBlockerNodeId, j);
                table.insert(phase.aiBlockers, aiBlockerNode);
            end
        end
    end
    instance.initCount = 0

    if TrafficLightCrossing.trafficLights[instance.trafficLightId] ~= nil then
        Logging.error("TrafficLightCrossing: trafficLightId '%s' duplicate defined.", instance.trafficLightId)
    else
        TrafficLightCrossing.trafficLights[instance.trafficLightId] = instance;
    end

    return instance
end

function TrafficLightCrossing:delete()
end

function TrafficLightCrossing.SendState(trafficLightId, phase, state)
    TrafficLightCrossing.DebugText("TrafficLightCrossing.SendState(" .. tostring(trafficLightId) .. ", " .. tostring(phase) .. ", " .. tostring(state) .. ")");

    g_client:getServerConnection():sendEvent(TrafficLightCrossingStateChangedEvent.new(trafficLightId, phase, state));
end

function TrafficLightCrossing.SetState(trafficLightId, currentPhase, state)
    TrafficLightCrossing.DebugText("TrafficLightCrossing.SetState(" .. tostring(trafficLightId) .. ", " .. tostring(currentPhase) .. ", " .. tostring(state) .. ")");

    local phase = TrafficLightCrossing.trafficLights[trafficLightId].phases[currentPhase];

    for _, redLight in pairs(phase.redLights) do
        setVisibility(redLight, state == TrafficLightCrossingPhase.RED or state == TrafficLightCrossingPhase.REDORANGE);
    end
    for _, orangeLight in pairs(phase.orangeLights) do
        setVisibility(orangeLight, state == TrafficLightCrossingPhase.ORANGE or state == TrafficLightCrossingPhase.REDORANGE);
    end
    for _, greenLight in pairs(phase.greenLights) do
        setVisibility(greenLight, state == TrafficLightCrossingPhase.GREEN);
    end
    local collisionFilterFlag = 0;
    if state ~= TrafficLightCrossingPhase.GREEN then
--         collisionFilterFlag = CollisionFlag.AI_BLOCKING + CollisionFlag.TRAFFIC_VEHICLE_BLOCKING;
        collisionFilterFlag = CollisionFlag.TRAFFIC_VEHICLE_BLOCKING;
    end

    for _, aiBlocker in pairs(phase.aiBlockers) do
--         setCollisionFilterGroup(aiBlocker, collisionFilterFlag);
        setCollisionFilter(aiBlocker, collisionFilterFlag, CollisionFlag.VEHICLE);
    end
    phase.innerPhase = state;
end

function TrafficLightCrossing:switchToNextPhase()
    if self.currentPhase == self.numPhases then
        self.currentPhase = 1;
    else
        self.currentPhase = self.currentPhase + 1;
    end
end

function TrafficLightCrossing:aiBlockerOverlapCallback(transformId)
    if transformId ~= nil then
        self.oneIsBlocked = true;
    end
end

function TrafficLightCrossing:update(dt)
    -- print("TrafficLightCrossing.update(" .. tostring(dt) .. ")");
-- print("loadingPattern")
-- DebugUtil.printTableRecursively(self,"_",0,3)
    if self.initCount > 0 then

        -- zeit runter rechnen
        self.timeLeft = self.timeLeft - dt;

        if self.timeLeft <= 0 then
            local activePhase = self.phases[self.currentPhase];

            -- aktuelle phase durchschalten
            if activePhase.innerPhase == TrafficLightCrossingPhase.GREEN then
                -- do not switch to orange when one green is not free
                self.oneIsBlocked = false;
                for _, aiBlocker in pairs(activePhase.aiBlockers) do
                    local x, y, z = localToWorld(aiBlocker, 0, 0, 0);
                    local rotX, rotY, rotZ = getWorldRotation(aiBlocker)
                    local extendX, extendY, extendZ = 0.5, 0.5, 0.5
                    local r = 0;
                    local g = 0.8;
                    local b = 0.8;
                    if TrafficLightCrossing.debug then
                        DebugUtil.drawOverlapBox(x, y, z, rotX, rotY, rotZ, extendX, extendY, extendZ, r, g, b)
                    end
                    overlapBox(x, y, z, rotX, rotY, rotZ, extendX, extendY, extendZ, "aiBlockerOverlapCallback", self, CollisionFlag.VEHICLE + CollisionFlag.DYNAMIC_OBJECT, true, false, true)
                end

                if self.oneIsBlocked then
                    self.timeLeft = 100;
                    TrafficLightCrossing.DebugText("TrafficLightCrossing blocked. Wait for beeing free")
                else
                    TrafficLightCrossing.SendState(self.trafficLightId, self.currentPhase, TrafficLightCrossingPhase.ORANGE);
                    self.timeLeft = 1000;
                end
            elseif activePhase.innerPhase == TrafficLightCrossingPhase.ORANGE then
                TrafficLightCrossing.SendState(self.trafficLightId, self.currentPhase, TrafficLightCrossingPhase.RED);
                self.timeLeft = 1000;
                -- nächste Phalse starten
                self:switchToNextPhase()
            elseif activePhase.innerPhase == TrafficLightCrossingPhase.RED then
                TrafficLightCrossing.SendState(self.trafficLightId, self.currentPhase, TrafficLightCrossingPhase.REDORANGE);
                self.timeLeft = 1000;
            elseif activePhase.innerPhase == TrafficLightCrossingPhase.REDORANGE then
                TrafficLightCrossing.SendState(self.trafficLightId, self.currentPhase, TrafficLightCrossingPhase.GREEN);
                self.timeLeft = activePhase.greenMiliSeconds;
            end

        end

    else
        -- hier start zustand erstellen, alle grünen lichter der phase 1 und alle roten der anderen phasen an. rest aus
        for i=1, #self.phases do
            TrafficLightCrossing.SendState(self.trafficLightId, i, TrafficLightCrossingPhase.RED);
        end

        TrafficLightCrossing.SendState(self.trafficLightId, self.currentPhase, TrafficLightCrossingPhase.GREEN);
        self.timeLeft = self.phases[self.currentPhase].greenMiliSeconds;
        self.phases[self.currentPhase].innerPhase = TrafficLightCrossingPhase.GREEN;

        self.initCount = self.initCount + 1
    end
end

-- modOnCreate.TrafficLightCrossing
g_onCreateUtil.addOnCreateFunction("TrafficLightCrossing", TrafficLightCrossing.onCreate);

TrafficLightCrossingStateChangedEvent = {}
TrafficLightCrossingStateChangedEvent_mt = Class(TrafficLightCrossingStateChangedEvent, Event)
InitEventClass(TrafficLightCrossingStateChangedEvent, "TrafficLightCrossingStateChangedEvent")

function TrafficLightCrossingStateChangedEvent.emptyNew()
    local self = Event.new(TrafficLightCrossingStateChangedEvent_mt);
    return self
end

function TrafficLightCrossingStateChangedEvent.new(trafficLightId, currentPhase, state)
    TrafficLightCrossing.DebugText("TrafficLightCrossingStateChangedEvent:new(" .. tostring(trafficLightId) .. ", " .. tostring(currentPhase) .. ", " .. tostring(state) .. ")");

    local self = TrafficLightCrossingStateChangedEvent.emptyNew();
    self.trafficLightId = trafficLightId;
    self.currentPhase = currentPhase;
    self.state = state;
    return self;
end

function TrafficLightCrossingStateChangedEvent:readStream(streamId, connection)
    TrafficLightCrossing.DebugText("TrafficLightCrossingStateChangedEvent:readStream");

    self.trafficLightId = streamReadInt32(streamId)
    self.currentPhase = streamReadInt32(streamId)
    self.state = streamReadInt32(streamId)

    self:run(connection)
end

function TrafficLightCrossingStateChangedEvent:writeStream(streamId, connection)

    TrafficLightCrossing.DebugText("TrafficLightCrossingStateChangedEvent:writeStream");

    streamWriteInt32(streamId, self.trafficLightId)
    streamWriteInt32(streamId, self.currentPhase)
    streamWriteInt32(streamId, self.state)
end

function TrafficLightCrossingStateChangedEvent:run(connection)
    TrafficLightCrossing.DebugText("TrafficLightCrossingStateChangedEvent:run");

    if not connection:getIsServer() then
        g_server:broadcastEvent(TrafficLightCrossingStateChangedEvent.new(self.trafficLightId, self.currentPhase, self.state), false);
    end

    TrafficLightCrossing.SetState(self.trafficLightId, self.currentPhase, self.state)
end