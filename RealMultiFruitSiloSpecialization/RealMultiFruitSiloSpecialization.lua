--[[
Copyright (C) Achimobil, since 2022

Author: Achimobil
Date: 06.06.2025
Version: 0.2.0.0

Contact:
https://discord.gg/Va7JNnEkcW

History:
V 0.1.0.0 @ 08.07.2022 - First Version.
V 0.2.0.0 @ 06.06.2025 - Compatible for FS25

Important:
You are allowed to use this script without any changes in your own FS25 mods.
Publish mods with this script is generall allowed for all mods which are not behind a "paywall".
So using in Mods published over patreon or similar ways is complete forbidden.
]]

RealMultiFruitSiloSpecialization = {
    prerequisitesPresent = function (specializations)
        return SpecializationUtil.hasSpecialization(PlaceableSilo, specializations);
    end,
    Version = "0.2.0.0",
    Name = "RealMultiFruitSiloSpecialization"
}
print(g_currentModName .. " - init " .. RealMultiFruitSiloSpecialization.Name .. "(Version: " .. RealMultiFruitSiloSpecialization.Version .. ")");

--- register the event listeners for this spec
-- @param any placeableType
function RealMultiFruitSiloSpecialization.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", RealMultiFruitSiloSpecialization);
end

---Called on loading
-- @param table savegame savegame
function RealMultiFruitSiloSpecialization:onLoad(savegame)
    local spec = self.spec_silo;

    for _, storage in ipairs(spec.storages) do
        local totalCapacity = 0;
        for fillType, accepted in pairs(storage.fillTypes) do
            if(accepted and storage.capacities[fillType] == nil) then
                storage.capacities[fillType] = storage.capacity;
            end
            if(storage.capacities[fillType] ~= nil) then
                totalCapacity = totalCapacity + storage.capacities[fillType];
            end
        end
        storage.capacity = totalCapacity;
    end
end