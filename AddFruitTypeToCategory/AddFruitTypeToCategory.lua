--[[
Copyright (C) Achimobil, 2025

Author: Achimobil
Date: 05.02.2025
Version: 1

Simple Extender Script for adding fruit Types to a category.
no check of anything exists or such things
Author Achimobil

Important:
Free to use in any FS25 Mods without asking or need for credits. Just have fun.
]]

CategoryExtender = {};
function CategoryExtender:loadMapData(superFunc, xmlFileHandle, missionInfo, baseDirectory)
    local result = superFunc(self, xmlFileHandle, missionInfo, baseDirectory);

    g_fruitTypeManager:addFruitTypeToCategory(g_fruitTypeManager:getFruitTypeByName("POPLAR").index, g_fruitTypeManager.categories["SOWINGMACHINE"])
    g_fruitTypeManager:addFruitTypeToCategory(g_fruitTypeManager:getFruitTypeByName("POTATO").index, g_fruitTypeManager.categories["SOWINGMACHINE"])

    return result;
end
FruitTypeManager.loadMapData = Utils.overwrittenFunction(FruitTypeManager.loadMapData, CategoryExtender.loadMapData)