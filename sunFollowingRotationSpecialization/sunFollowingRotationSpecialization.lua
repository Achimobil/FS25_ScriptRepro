--[[
Copyright (C) Achimobil, since 2022

Author: Achimobil
Date: 23.02.2025
Version: 0.2.0.0

Important:
You are allowed to use this script without any changes in your own FS25 mods.
Publish mods with this script is generall allowed for all mods which are not behind a "paywall".
So using in Mods published over patreon or similar ways is complete forbidden.

Usage in placable xml:

<placeable>
    <sunFollowers>
        <sunFollower headNode="8>0|0" randomHeadOffsetRange="0" rotationSpeed="5"/>
        <sunFollower headNode="8>1|0" randomHeadOffsetRange="0" rotationSpeed="5"/>
    </sunFollowers>
</placeable>
]]

SunFollowingRotationSpecialization = {
    prerequisitesPresent = function (specializations)
        return true
    end,
    Version = "0.2.0.0",
    Name = "SunFollowingRotationSpecialization",
}
print(g_currentModName .. " - init " .. SunFollowingRotationSpecialization.Name .. "(Version: " .. SunFollowingRotationSpecialization.Version .. ")");

--- register the overwritten functions for this spec
-- @param any placeableType
function SunFollowingRotationSpecialization.registerOverwrittenFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "getNeedHourChanged", SunFollowingRotationSpecialization.getNeedHourChanged)
end

--- register the functions for this spec
-- @param any placeableType
function SunFollowingRotationSpecialization.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "updateHeadRotation", SunFollowingRotationSpecialization.updateHeadRotation)
end

--- register the event listeners for this spec
-- @param any placeableType
function SunFollowingRotationSpecialization.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", SunFollowingRotationSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SunFollowingRotationSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onReadStream", SunFollowingRotationSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onWriteStream", SunFollowingRotationSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onHourChanged", SunFollowingRotationSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onUpdate", SunFollowingRotationSpecialization)
end

---
-- @param XMLSchema schema
-- @param string basePath
function SunFollowingRotationSpecialization.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("SunFollower")

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".sunFollowers.sunFollower(?)#headNode", "Head Node")
    schema:register(XMLValueType.ANGLE, basePath .. ".sunFollowers.sunFollower(?)#randomHeadOffsetRange", "Range of random offset", 15)
    schema:register(XMLValueType.ANGLE, basePath .. ".sunFollowers.sunFollower(?)#rotationSpeed", "Rotation Speed (deg/sec)", 5)

    schema:setXMLSpecializationType()
end

---Called on loading
-- @param table savegame savegame
function SunFollowingRotationSpecialization:onLoad(savegame)
    self.spec_sunFollower = {};
    local spec = self.spec_sunFollower
    local xmlFile = self.xmlFile

    spec.followerList = {};
    local i = 0;

    while true do
        local currentKey = string.format("placeable.sunFollowers.sunFollower(%d)", i);

        if not xmlFile:hasProperty(currentKey) then
            break;
        end

        local follower = {}
        follower.headNode = xmlFile:getValue(currentKey .. "#headNode", nil, self.components, self.i3dMappings)
        follower.randomHeadOffsetRange = xmlFile:getValue(currentKey .. "#randomHeadOffsetRange", 15)
        follower.rotationSpeed = xmlFile:getValue(currentKey .. "#rotationSpeed", 5) / 1000

        if follower.headNode ~= nil then
            local rotVariation = follower.randomHeadOffsetRange * 0.5
            follower.headRotationRandom = math.random(-1, 1) * rotVariation
            follower.currentRotation = follower.headRotationRandom
            follower.targetRotation = follower.headRotationRandom
        end

        table.insert(spec.followerList, follower);

        i = i + 1;
    end
end

--- called by base class when placement is finialzing
-- @param table savegame savegame
function SunFollowingRotationSpecialization:onFinalizePlacement(savegame)
    self:updateHeadRotation()
end

---new connected players get information here
-- @param integer streamId network stream identification
-- @param table connection connection information
function SunFollowingRotationSpecialization:onReadStream(streamId, connection)
    local spec = self.spec_sunFollower

    for _, follower in pairs(spec.followerList) do
        if follower.headNode ~= nil then
            follower.headRotationRandom = NetworkUtil.readCompressedAngle(streamId)
        end
    end
end

---Send information to new connected players
-- @param integer streamId network stream identification
-- @param table connection connection information
function SunFollowingRotationSpecialization:onWriteStream(streamId, connection)
    local spec = self.spec_sunFollower

    for _, follower in pairs(spec.followerList) do
        if follower.headNode ~= nil then
            NetworkUtil.writeCompressedAngle(streamId, follower.headRotationRandom)
        end
    end
end

---
-- @param float dt time since last call in ms
function SunFollowingRotationSpecialization:onUpdate(dt)
    local spec = self.spec_sunFollower

    for _, follower in pairs(spec.followerList) do
        if follower.targetRotation ~= follower.currentRotation then
            local limitFunc = math.min
            local direction = 1

            if follower.targetRotation < follower.currentRotation then
                limitFunc = math.max
                direction = -1
            end

            follower.currentRotation = limitFunc(follower.currentRotation + follower.rotationSpeed * dt * direction, follower.targetRotation)
            local dx, _, dz = worldDirectionToLocal(getParent(follower.headNode), math.sin(follower.currentRotation), 0, math.cos(follower.currentRotation))

            setDirection(follower.headNode, dx, 0, dz, 0, 1, 0)

            if follower.targetRotation ~= follower.currentRotation then
                self:raiseActive()
            end
        end
    end
end

---
function SunFollowingRotationSpecialization:onHourChanged()
    self:updateHeadRotation()
end

--- Update the rotation target to follow the sun
function SunFollowingRotationSpecialization:updateHeadRotation()
    local spec = self.spec_sunFollower;

    if g_currentMission ~= nil and g_currentMission.environment ~= nil then
        local sunLight = g_currentMission.environment.lighting.sunLightId;
        if sunLight ~= nil then
            local dx, _, dz = localDirectionToWorld(sunLight, 0, 0, 1);
            local headRotation = math.atan2(dx, dz);
            if g_currentMission.environment.isSunOn then
                for _, follower in pairs(spec.followerList) do
                    follower.targetRotation = headRotation + follower.headRotationRandom
                    self:raiseActive()
                end
            end
        end
    end
end

---
-- @param function superFunc
-- @return boolean true if hour changed event is needed
function SunFollowingRotationSpecialization:getNeedHourChanged(superFunc)
    return true
end
