local prefs = {}

local exclude_tags = { "INLIMBO", "companion", "wall", "abigail", "shadowminion" }
if not TheNet:GetPVPEnabled() then
    table.insert(exclude_tags, "player")
end

--------------------------------------------------------------------------
--[[ 通用函数 ]]
--------------------------------------------------------------------------

local function StartTimer_attach(buff, target, timekey, timedefault)
    --因为是新加buff，不需要考虑buff时间问题
    if timekey == nil or target[timekey] == nil then
        if not buff.components.timer:TimerExists("buffover") then --因为onsave比这里先加载，所以不能替换先加载的
            buff.components.timer:StartTimer("buffover", timedefault)
        end
    else
        if not buff.components.timer:TimerExists("buffover") then
            local times = target[timekey]
            if times.add ~= nil then
                times = times.add
            elseif times.replace ~= nil then
                times = times.replace
            elseif times.replace_min ~= nil then
                times = times.replace_min
            else
                buff:DoTaskInTime(0, function()
                    buff.components.debuff:Stop()
                end)
                target[timekey] = nil
                return
            end
            buff.components.timer:StartTimer("buffover", times)
        end
        target[timekey] = nil
    end
end

local function StartTimer_extend(buff, target, timekey, timedefault)
    --因为是续加buff，需要考虑buff时间的更新方式
        buff.components.timer:StopTimer("buffover")
    if timekey == nil or target[timekey] == nil then
        buff.components.timer:StartTimer("buffover", timedefault)
    else
        local times = target[timekey]
        target[timekey] = nil
        if times.add ~= nil then --增加型：在已有时间上增加，可设置最大时间限制
            local timeleft = buff.components.timer:GetTimeLeft("buffover") or 0
            timeleft = timeleft + times.add

            if times.max ~= nil and timeleft > times.max then
                timeleft = times.max
            end
            buff.components.timer:StopTimer("buffover")
            buff.components.timer:StartTimer("buffover", timeleft)
        elseif times.replace ~= nil then --替换型：不管已有时间，直接设置
            buff.components.timer:StopTimer("buffover")
            buff.components.timer:StartTimer("buffover", times.replace)
        elseif times.replace_min ~= nil then --最小替换型：若已有时间<该时间时才设置新时间（比较建议的类型）
            local timeleft = buff.components.timer:GetTimeLeft("buffover") or 0
            if timeleft < times.replace_min then
                buff.components.timer:StopTimer("buffover")
                buff.components.timer:StartTimer("buffover", times.replace_min)
            end
        end
    end
end

local function InitTimerBuff(inst, data)
    inst.components.debuff:SetAttachedFn(function(inst, target, ...)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0) --in case of loading
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        StartTimer_attach(inst, target, data.time_key, data.time_default)

        if data.fn_start ~= nil then
            data.fn_start(inst, target, ...)
        end
    end)
    inst.components.debuff:SetDetachedFn(function(inst, target)
        if data.fn_end ~= nil then
            data.fn_end(inst, target)
        end
        inst:Remove()
    end)
    inst.components.debuff:SetExtendedFn(function(inst, target, ...)
        StartTimer_extend(inst, target, data.time_key, data.time_default)

        if data.fn_again ~= nil then
            data.fn_again(inst, target, ...)
        end
    end)

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", function(inst, data)
        if data.name == "buffover" then
            inst.components.debuff:Stop()
        end
    end)
end

local function InitNoTimerBuff(inst, data)
    inst.components.debuff:SetAttachedFn(function(inst, target, ...)
        inst.entity:SetParent(target.entity)
        inst.Transform:SetPosition(0, 0, 0) --in case of loading
        inst:ListenForEvent("death", function()
            inst.components.debuff:Stop()
        end, target)

        if data.fn_start ~= nil then
            data.fn_start(inst, target, ...)
        end
    end)
    inst.components.debuff:SetDetachedFn(function(inst, target)
        if data.fn_end ~= nil then
            data.fn_end(inst, target)
        end
        inst:Remove()
    end)
    inst.components.debuff:SetExtendedFn(function(inst, target, ...)
        if data.fn_again ~= nil then
            data.fn_again(inst, target, ...)
        end
    end)
end

local function MakeBuff(data)
	table.insert(prefs, Prefab(
		data.name,
		function()
            local inst = CreateEntity()

            if data.addnetwork then --带有网络组件
                inst.entity:AddTransform()
                inst.entity:AddNetwork()
                -- inst.entity:Hide()
                inst.persists = false

                -- inst:AddTag("CLASSIFIED")
                inst:AddTag("NOCLICK")
                inst:AddTag("NOBLOCK")

                if data.fn_common ~= nil then
                    data.fn_common(inst)
                end

                inst.entity:SetPristine()
                if not TheWorld.ismastersim then
                    return inst
                end
            else --无网络组件
                if not TheWorld.ismastersim then
                    --Not meant for client!
                    inst:DoTaskInTime(0, inst.Remove)
                    return inst
                end
                inst.entity:AddTransform()
                --Non-networked entity
                inst.entity:Hide()
                inst.persists = false
                inst:AddTag("CLASSIFIED")
            end

            inst:AddComponent("debuff")
            inst.components.debuff.keepondespawn = true
            if data.notimer then
                InitNoTimerBuff(inst, data)
            else
                InitTimerBuff(inst, data)
            end

            if data.fn_server ~= nil then
                data.fn_server(inst)
            end

            return inst
		end,
		data.assets,
		data.prefabs
	))
end

-----

local function BuffTalk_start(target, buff)
    target:PushEvent("foodbuffattached", { buff = "ANNOUNCE_ATTACH_"..string.upper(buff.prefab), priority = 1 })
end
local function BuffTalk_end(target, buff)
    target:PushEvent("foodbuffdetached", { buff = "ANNOUNCE_DETACH_"..string.upper(buff.prefab), priority = 1 })
end

local function IsAlive(inst)
    return inst.components.health ~= nil and not inst.components.health:IsDead() and not inst:HasTag("playerghost")
end

--------------------------------------------------------------------------
--[[ 體內爆破：持續造成無視防禦的單體傷害 ]]
--------------------------------------------------------------------------
local function OnTick_innerexplode_default(inst, target)
    if IsAlive(target) then
		SpawnPrefab("explode_small").Transform:SetPosition(target.Transform:GetWorldPosition())
		
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local ents = TheSim:FindEntities(x1, y1, z1,  TUNING.GUNPOWDER_RANGE, { "_combat" }, exclude_tags) --3的攻击范围
		for i, ent in ipairs(ents) do
			if ent ~= target and ent.components.health ~= nil then
				local damageNum = 0
				if target.components.health.currenthealth - inst.TickDamage > 0 then
					damageNum = inst.TickDamage * 0.5
				else
					damageNum = inst.TotalDamage
				end
				ent.components.health:DoDelta(-damageNum, nil, "BlazeRip", true, target, false)
				ent:PushEvent("attacked", { attacker = target, damage = damageNum, damageresolved = damageNum, noimpactsound = target.components.combat.noimpactsound })
			end
		end
		
		target.components.health:DoDelta(-inst.TickDamage, nil, "BlazeRip", true, target, true)
		target:PushEvent("attacked", { attacker = target, damage = inst.TickDamage, damageresolved = inst.TickDamage, noimpactsound = target.components.combat.noimpactsound })
		
        inst.TotalDamage = inst.TotalDamage - inst.TickDamage
        if inst.TotalDamage <= 0 then
            inst.components.debuff:Stop()
        end
    else
        inst.components.debuff:Stop()
    end
end

MakeBuff({
    name = "buff_innerexplode_default",
    assets = nil,
    prefabs = nil,
    time_key = nil,
    time_default = nil,
    notimer = true,
    fn_start = function(buff, target)
        if target.buff_innerexplode_stacked ~= nil then
            buff.TotalDamage = buff.TotalDamage + target.buff_innerexplode_stacked
			buff.TickDamage = buff.TotalDamage * 0.25
            target.buff_innerexplode_stacked = nil
        end
        if buff.TotalDamage > 0 then
            buff.task = buff:DoPeriodicTask(2, OnTick_innerexplode_default, nil, target)
        end
    end,
    fn_again = function(buff, target)
        if target.buff_innerexplode_stacked ~= nil then --buff次数可以无限叠加
            buff.TotalDamage = buff.TotalDamage + target.buff_innerexplode_stacked
			buff.TickDamage = buff.TotalDamage * 0.25
            target.buff_innerexplode_stacked = nil
        end
--[[
        if buff.task ~= nil then
            buff.task:Cancel()
        end
        if buff.TotalDamage > 0 then
            buff.task = buff:DoPeriodicTask(2, OnTick_innerexplode, nil, target)
        end
]]
    end,
    fn_end = function(buff, target)
        if buff.task ~= nil then
            buff.task:Cancel()
            buff.task = nil
        end
    end,
    fn_server = function(buff)
        buff.TotalDamage = 0

        buff.OnSave = function(inst, data)
            if inst.TotalDamage ~= nil and inst.TotalDamage > 0 then
                data.TotalDamage = inst.TotalDamage
            end
        end
        buff.OnLoad = function(inst, data) --这个比OnAttached更早执行
            if data ~= nil and data.TotalDamage ~= nil and data.TotalDamage > 0 then
                inst.TotalDamage = data.TotalDamage
				inst.TickDamage = inst.TotalDamage * 0.25
            end
        end
    end,
})

--------------------------------------------------------------------------
--[[ 體內爆破(月光)：持續造成無視防禦的單體傷害 (對暗影生物傷害提升)]]
--------------------------------------------------------------------------
local function OnTick_innerexplode_lunar(inst, target)
    if IsAlive(target) then
		SpawnPrefab("bomb_lunarplant_explode_fx").Transform:SetPosition(target.Transform:GetWorldPosition())
		
		local innerexplode_lunar_vs_target = 1
		if target:HasTag("shadow_aligned") then
			innerexplode_lunar_vs_target = 1.1
		else
			innerexplode_lunar_vs_target = 1
		end
		
		local x1, y1, z1 = target.Transform:GetWorldPosition()
		local ents = TheSim:FindEntities(x1, y1, z1, TUNING.BOMB_LUNARPLANT_RANGE, { "_combat" }, exclude_tags) --3的攻击范围
		for i, ent in ipairs(ents) do
			if ent ~= target and ent.components.health ~= nil then
				local innerexplode_lunar_vs_ent = 1
				if ent:HasTag("shadow_aligned") then
					innerexplode_lunar_vs_ent = 1.1
				else
					innerexplode_lunar_vs_ent = 1
				end
					
				local damageNum = 0
				if target.components.health.currenthealth - inst.TickDamage * innerexplode_lunar_vs_target> 0 then
					damageNum = inst.TickDamage * innerexplode_lunar_vs_ent * 0.5
				else
					damageNum = inst.TotalDamage * innerexplode_lunar_vs_ent
				end
				ent.components.health:DoDelta(-damageNum, nil, "BlazeRip", true, target, false)
				ent:PushEvent("attacked", { attacker = target, damage = damageNum, damageresolved = damageNum, noimpactsound = target.components.combat.noimpactsound })
			end
		end
		
		target.components.health:DoDelta(-inst.TickDamage * innerexplode_lunar_vs_target, nil, "BlazeRip", true, target, true)
		target:PushEvent("attacked", { attacker = target, damage = inst.TickDamage * innerexplode_lunar_vs_target, damageresolved = inst.TickDamage * innerexplode_lunar_vs_target, noimpactsound = target.components.combat.noimpactsound })
		
        inst.TotalDamage = inst.TotalDamage - inst.TickDamage
        if inst.TotalDamage <= 0 then
            inst.components.debuff:Stop()
        end
    else
        inst.components.debuff:Stop()
    end
end

MakeBuff({
    name = "buff_innerexplode_lunar",
    assets = nil,
    prefabs = nil,
    time_key = nil,
    time_default = nil,
    notimer = true,
    fn_start = function(buff, target)
        if target.buff_innerexplode_stacked ~= nil then
            buff.TotalDamage = buff.TotalDamage + target.buff_innerexplode_stacked
			buff.TickDamage = buff.TotalDamage * 0.25
            target.buff_innerexplode_stacked = nil
        end
        if buff.TotalDamage > 0 then
            buff.task = buff:DoPeriodicTask(2, OnTick_innerexplode_lunar, nil, target)
        end
    end,
    fn_again = function(buff, target)
        if target.buff_innerexplode_stacked ~= nil then --buff次数可以无限叠加
            buff.TotalDamage = buff.TotalDamage + target.buff_innerexplode_stacked
			buff.TickDamage = buff.TotalDamage * 0.25
            target.buff_innerexplode_stacked = nil
        end
--[[
        if buff.task ~= nil then
            buff.task:Cancel()
        end
        if buff.TotalDamage > 0 then
            buff.task = buff:DoPeriodicTask(2, OnTick_innerexplode_lunar, nil, target)
        end
]]
    end,
    fn_end = function(buff, target)
        if buff.task ~= nil then
            buff.task:Cancel()
            buff.task = nil
        end
    end,
    fn_server = function(buff)
        buff.TotalDamage = 0

        buff.OnSave = function(inst, data)
            if inst.TotalDamage ~= nil and inst.TotalDamage > 0 then
                data.TotalDamage = inst.TotalDamage
            end
        end
        buff.OnLoad = function(inst, data) --这个比OnAttached更早执行
            if data ~= nil and data.TotalDamage ~= nil and data.TotalDamage > 0 then
                inst.TotalDamage = data.TotalDamage
				inst.TickDamage = inst.TotalDamage * 0.25
            end
        end
    end,
})

return unpack(prefs)
