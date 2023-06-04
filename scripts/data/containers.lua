--container
local containers = require('containers') 
local params = containers.params

params.abyssweapon = {
    widget =
    {
        slotpos =
        {
            Vector3(0,   32 + 4,  0),
        },
        animbank = "ui_cookpot_1x2",
        animbuild = "ui_cookpot_1x2",
        pos = Vector3(0, 15, 0),
    },
    usespecificslotsforitems = true,
    excludefromcrafting = true,
    type = "hand_inv",
}

function params.abyssweapon.itemtestfn(container, item, slot)
    if slot and (
        item.prefab == "gunpowder"
		or item.prefab == "bomb_lunarplant"
        or item.prefab == "slurtleslime"
		--兼容legion爆炸水果蛋糕
        or item.prefab == "explodingfruitcake"
    ) then
        return true
    else 
        return false
    end
end

for k, v in pairs(params) do 
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end