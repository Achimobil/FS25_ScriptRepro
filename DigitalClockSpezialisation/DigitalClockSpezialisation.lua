--[[
Copyright (C) Achimobil, since 2022

Author: Achimobil
Date: 06.06.2025
Version: 0.2.0.0

Contact:
https://discord.gg/Va7JNnEkcW

History:
V 0.1.0.0 @ 26.07.2022 - First Version.
V 0.2.0.0 @ 06.06.2025 - Compatible for FS25

Important:
You are allowed to use this script without any changes in your own FS25 mods.
Publish mods with this script is generall allowed for all mods which are not behind a "paywall".
So using in Mods published over patreon or similar ways is complete forbidden.

Usage in placable xml:

<placeable>
    <digitalClocks>
        <digitalClock node="clock1" color="0 0.8 0" />
        <digitalClock node="clock2" color="0 0.8 0" />
    </digitalClocks>
</placeable>
]]

DigitalClockSpezialisation = {
    prerequisitesPresent = function (specializations)
        return true;
    end,
    Version = "0.2.0.0",
    Name = "DigitalClockSpezialisation"
}
print(g_currentModName .. " - init " .. DigitalClockSpezialisation.Name .. "(Version: " .. DigitalClockSpezialisation.Version .. ")");

--- register the event listeners for this spec
-- @param any placeableType
function DigitalClockSpezialisation.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", DigitalClockSpezialisation);
    SpecializationUtil.registerEventListener(placeableType, "onMinuteChanged", DigitalClockSpezialisation);
end

--- register the functions for this spec
-- @param any placeableType
function DigitalClockSpezialisation.registerFunctions(placeableType)
    SpecializationUtil.registerOverwrittenFunction(placeableType, "getNeedMinuteChanged", DigitalClockSpezialisation.getNeedMinuteChanged)
end

--- returns if spec need MINUTE_CHANGED event for placable
-- @return boolean minuteChangeNeeded
function DigitalClockSpezialisation:getNeedMinuteChanged()
    return true;
end

---
-- @param XMLSchema schema
-- @param string basePath
function DigitalClockSpezialisation.registerXMLPaths(schema, basePath)
    schema:setXMLSpecializationType("DigitalClock");

    schema:register(XMLValueType.NODE_INDEX, basePath .. ".digitalClocks.digitalClock(?)#node", "Node which contains all digital clock nodes");
    schema:register(XMLValueType.STRING, basePath .. ".digitalClocks.digitalClock(?)#font", "Display font name");
    schema:register(XMLValueType.STRING, basePath .. ".digitalClocks.digitalClock(?)#alignment", "Display text alignment");
    schema:register(XMLValueType.FLOAT, basePath .. ".digitalClocks.digitalClock(?)#size", "Display text size");
    schema:register(XMLValueType.FLOAT, basePath .. ".digitalClocks.digitalClock(?)#scaleX", "Display text x scale");
    schema:register(XMLValueType.FLOAT, basePath .. ".digitalClocks.digitalClock(?)#scaleY", "Display text y scale");
    schema:register(XMLValueType.STRING, basePath .. ".digitalClocks.digitalClock(?)#mask", "Display text mask");
    schema:register(XMLValueType.FLOAT, basePath .. ".digitalClocks.digitalClock(?)#emissiveScale", "Display emissive scale");
    schema:register(XMLValueType.COLOR, basePath .. ".digitalClocks.digitalClock(?)#color", "Display text color");
    schema:register(XMLValueType.COLOR, basePath .. ".digitalClocks.digitalClock(?)#hiddenColor", "Display text hidden color");
    schema:register(XMLValueType.STRING, basePath .. ".digitalClocks.digitalClock(?)#fillType", "Filltype name for the Display to show amount");

    schema:setXMLSpecializationType();
end

---Called on loading
-- @param table savegame savegame
function DigitalClockSpezialisation:onLoad(savegame)
    self.spec_digitalClock = {};
    local spec = self.spec_digitalClock;
    local xmlFile = self.xmlFile;

    spec.digitalClocks = {};
    local i = 0;

    while true do
        local clockKey = string.format("placeable.digitalClocks.digitalClock(%d)", i);
        if not xmlFile:hasProperty(clockKey) then
            break;
        end

        local clockNode = self.xmlFile:getValue(clockKey .. "#node", nil, self.components, self.i3dMappings);

        local fontName = self.xmlFile:getValue(clockKey .. "#font", "DIGIT"):upper();
        local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment);

        local digitalClock = {};
        local alignmentStr = self.xmlFile:getValue(clockKey .. "#alignment", "CENTER");
        local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_CENTER;
        local size = self.xmlFile:getValue(clockKey .. "#size", 0.11);
        local scaleX = self.xmlFile:getValue(clockKey .. "#scaleX", 1);
        local scaleY = self.xmlFile:getValue(clockKey .. "#scaleY", 1);
        local mask = self.xmlFile:getValue(clockKey .. "#mask", "000000");
        local emissiveScale = self.xmlFile:getValue(clockKey .. "#emissiveScale", 0.2);
        local color = self.xmlFile:getValue(clockKey .. "#color", {
            0.9,
            0.9,
            0.9
        }, true);
        local hiddenColor = self.xmlFile:getValue(clockKey .. "#hiddenColor", nil, true);
        digitalClock.clockNode = clockNode;
        digitalClock.formatStr, digitalClock.formatPrecision = Utils.maskToFormat(mask);
        digitalClock.fontMaterial = fontMaterial;

        digitalClock.characterLine = CharacterLine.new(digitalClock.clockNode, fontMaterial, mask:len());
        digitalClock.characterLine:setSizeAndScale(size, scaleX, scaleY);
        digitalClock.characterLine:setTextAlignment(alignment);
        digitalClock.characterLine:setColor(color, hiddenColor, emissiveScale);

        table.insert(spec.digitalClocks, digitalClock);

        i = i + 1;
    end


    spec.hasClocks = #spec.digitalClocks > 0
end

--- Called every ingame minute
function DigitalClockSpezialisation:onMinuteChanged()
    local spec = self.spec_digitalClock;
    if spec.hasClocks then
        local timeHoursF = g_currentMission.environment.dayTime / 3600000 + 0.0001
        local timeHours = math.floor(timeHoursF)
        local timeMinutes = math.floor((timeHoursF - timeHours) * 60)

        local value = string.format("%02d:%02d", timeHours, timeMinutes)

        for _, digitalClock in pairs(spec.digitalClocks) do
            digitalClock.characterLine:setText(value);
        end
    end
end