local assets =     {
	Asset("ANIM", "anim/abyssweapon.zip"),
	Asset("ANIM", "anim/swap_abyssweapon.zip"),
	Asset("IMAGE", "images/inventoryimages/abyssweapon.tex"),
	Asset("ATLAS", "images/inventoryimages/abyssweapon.xml"),
}

local prefabs = {
    "buff_innerexplode"
}

local function OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "swap_abyssweapon", "abyssweapon")
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
		
    if inst.components.container ~= nil then
        inst.components.container:Open(owner)
    end
end

local function OnUnequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
	
    if inst.components.container ~= nil then
        inst.components.container:Close()
    end
end

local function onattack(inst, owner, target)	
	if inst:HasTag("ammoloaded")
	and target ~= nil and target:IsValid()
	and not target:HasTag("alwaysblock") --有了这个标签，什么天神都伤害不了
	and target.prefab ~= "laozi" --无法伤害神话书说里的太上老君
	and target.components.health ~= nil
	and not target.components.health:IsDead() then
		
		if inst.components.container ~= nil then
			local ammo_stack = inst.components.container:GetItemInSlot(1)
			local item = inst.components.container:RemoveItem(ammo_stack, false)
		
			if item.prefab == "slurtleslime" then		
				target.buff_innerexplode_stacked = TUNING.SLURTLESLIME_EXPLODE_DAMAGE * TUNING.BLAZERIPEXPLODEMULT
				target:AddDebuff("buff_innerexplode_default", "buff_innerexplode_default")
			elseif item.prefab == "gunpowder" then
				target.buff_innerexplode_stacked = TUNING.GUNPOWDER_DAMAGE * TUNING.BLAZERIPEXPLODEMULT
				target:AddDebuff("buff_innerexplode_default", "buff_innerexplode_default")
			elseif item.prefab == "bomb_lunarplant" then
				target.buff_innerexplode_stacked = TUNING.BOMB_LUNARPLANT_PLANAR_DAMAGE * TUNING.BLAZERIPEXPLODEMULT
				target:AddDebuff("buff_innerexplode_lunar", "buff_innerexplode_lunar")
			elseif item.prefab == "explodingfruitcake" then
				target.buff_innerexplode_stacked = 500 * TUNING.BLAZERIPEXPLODEMULT
				target:AddDebuff("buff_innerexplode_default", "buff_innerexplode_default")
			else
				target.buff_innerexplode_stacked = 0 * TUNING.BLAZERIPEXPLODEMULT
				target:AddDebuff("buff_innerexplode_default", "buff_innerexplode_default")
			end
		end
	end
end

local function OnAmmoLoaded(inst, data)
	if inst.components.weapon ~= nil then
		if data ~= nil and data.item ~= nil then
			inst:AddTag("ammoloaded")
		end
	end
end

local function OnAmmoUnloaded(inst, data)
	if inst.components.weapon ~= nil then
		inst:RemoveTag("ammoloaded")
	end
end

local function fn()
	local inst = CreateEntity()
	
	inst.entity:AddTransform()
	inst.entity:AddAnimState()
	inst.entity:SetPristine()
	inst.entity:AddNetwork()
	
	MakeInventoryPhysics(inst)
	
	inst.AnimState:SetBank("abyssweapon")
	inst.AnimState:SetBuild("abyssweapon")
	inst.AnimState:PlayAnimation("idle")
	
    MakeInventoryFloatable(inst)

    inst:AddTag("sharp")
    inst:AddTag("pointy")
	
    inst.entity:SetPristine()
	
	if not TheWorld.ismastersim then
		return inst
	end
	inst:AddComponent("inspectable")
	
	inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "abyssweapon"
	inst.components.inventoryitem.atlasname = "images/inventoryimages/abyssweapon.xml"
	
	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(OnEquip)
	inst.components.equippable:SetOnUnequip(OnUnequip)
	
	inst:AddComponent("weapon")
	inst.components.weapon:SetDamage(51)
	inst.components.weapon:SetOnAttack(onattack)

    inst:AddComponent("container")
    inst.components.container:WidgetSetup("abyssweapon")
	inst.components.container.canbeopened = false
    inst:ListenForEvent("itemget", OnAmmoLoaded)
    inst:ListenForEvent("itemlose", OnAmmoUnloaded)
	
	MakeHauntableLaunch(inst)

	-- Lyza's pickaxe is mining-able
	inst:AddComponent("tool")
	inst.components.tool:SetAction(ACTIONS.MINE, 3)
	
	return inst
end

STRINGS.NAMES.ABYSSWEAPON = "無盡鎚"
STRINGS.RECIPE_DESC.ABYSSWEAPON = "無盡鎚的複製品，可裝填各種爆裂物"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.ABYSSWEAPON = "曾經被萊莎所持有的一級遺物，殺傷性極高"
return Prefab( "abyssweapon", fn, assets)
