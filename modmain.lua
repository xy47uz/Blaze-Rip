-- modmain
GLOBAL.setmetatable(env, {__index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end})
modimport("scripts/data/containers")
Assets = {
    Asset("ATLAS", "images/inventoryimages/abyssweapon.xml"),
	Asset("IMAGE", "images/inventoryimages/abyssweapon.tex")
}

PrefabFiles = {
	"abyssweapon",
	"buffs_BlazeRip",
}

AddRecipe2("abyssweapon", {
	Ingredient("goldenpickaxe", 1),Ingredient("thulecite", 10)
},TECH.ANCIENT_FOUR,{
	atlas = "images/inventoryimages/abyssweapon.xml",
	image = "abyssweapon.tex",
	numtogive = 1
},{
	"CRAFTING_STATION",
	"TOOLS",
	"WEAPONS",
})

TUNING.BLAZERIPEXPLODEMULT = 2.0