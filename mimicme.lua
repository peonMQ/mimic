local mq = require('mq')
local ImGui = require('ImGui')
local actors = require('actors')
local mimicSpellbar = require('mimicSpellbar')
local mimicGroup = require('mimicGroupWindow')
local mimicXTarget = require('mimicXTargetWindow')
local mimicTarget = require('mimicTargetWindow')
local mimicPet = require('mimicPetWindow')
local mimicControlDash = require('mimicControlDash')
local running = true


local UIToggles = {
    ['openGroupWindow'] = true,
    ['showGroupWindow'] = true,
    ['openPetWindow'] = true,
    ['showPetWindow'] = true,
    ['openTargetWindow'] = true,
    ['showTargetWindow'] = true,
    ['openXTargetWindow'] = true,
    ['showXTargetWindow'] = true,
    ['openSpellbar'] = true,
    ['showSpellbar'] = true,
    ['openMimicControlDash'] = true,
    ['showMimicControlDash'] = true,
    ['showMimicSettings'] = false,
    ['openMimicSettings'] = false
}



local followMATarget = false
local chaseToggle = false
local groupIds = {}
local mimicSitting = "Sit"
local previousGroup = { 'Empty', 'Empty', 'Empty', 'Empty', 'Empty', 'Empty', }

local spellbarIds = {}
local previousSpellbar = {}

local xtargetList = {}
local previousXTarget = {}

local groupIds = {}
local spellbarIds = {}
local xtargetIds = {}
local mimicTargetId = {}

local mimicTargetId = 'Empty'
local previousTarget = 'Empty'

local previousPetId = 'Empty'
local previousPetTarget = 'Empty'
local previousPetCombat = false

local mimicPetId = 'Empty'
local mimicPetTarget = 'Empty'
local mimicPetCombat = false
local tauntToggle = false
local petGuardToggle = false

local mimicActor = actors.register('mimic', function(message)
    if message.content.id == 'updateChase' then
        chaseToggle = message.content.chaseAssist
    elseif message.content.id == 'updateFollowMATarget' then
        followMATarget = message.content.followMATarget
    elseif message.content.id == 'castSpell' and message.content.charName == mq.TLO.Me.Name() then
        mq.cmdf('/cast %i', message.content.gem)
    elseif message.content.id == 'newTarget' and message.content.charName == mq.TLO.Me.Name() then
        mq.cmdf('/target %s', message.content.targetId)
    elseif message.content.id == 'petModeUpdate' and message.content.charName == mq.TLO.Me.Name() then
        if message.content.mode == 'Follow' then mq.cmd('/pet guard') end
        if message.content.mode == 'Guard' then mq.cmd('/pet Follow') end
    elseif message.content.id == 'petTauntUpdate' and message.content.charName == mq.TLO.Me.Name() then
        if message.content.taunt == true then mq.cmd('/pet taunt on') end
        if message.content.taunt == false then mq.cmd('/pet taunt off') end
    elseif message.content.id == 'petAttack' and message.content.charName == mq.TLO.Me.Name() then
        mq.cmd('/pet attack')
    elseif message.content.id == 'petBackOff' and message.content.charName == mq.TLO.Me.Name() then
        mq.cmd('/pet stop')
        mq.cmd('/pet back')
    elseif message.content.id == 'switchSitting' and message.content.charName == mq.TLO.Me.Name() then
        if mq.TLO.Me.Sitting() then
            mq.cmd('/stand')
        elseif not mq.TLO.Me.Sitting() then
            mq.cmd('/sit')
        end
    end
end)
local function updateDriver()
    mimicActor:send({ mailbox = 'Driver', script = 'mimic' },
        {
            id = 'greetDriver',
            charName = mq.TLO.Me.Name(),
            openGroupWindow = UIToggles['openGroupWindow'],
            showGroupWindow = UIToggles['showGroupWindow'],
            openPetWindow = UIToggles['openPetWindow'],
            showPetWindow = UIToggles['showPetWindow'],
            openTargetWindow = UIToggles['openTargetWindow'],
            showTargetWindow = UIToggles['showTargetWindow'],
            openXTargetWindow = UIToggles['openXTargetWindow'],
            showXTargetWindow = UIToggles['showXTargetWindow'],
            openSpellbar = UIToggles['openSpellbar'],
            showSpellbar = UIToggles['showSpellbar'],
            showMimicControlDash = UIToggles['showMimicControlDash'],
            openMimicControlDash = UIToggles['openMimicControlDash'],
        })
end




local function updateSpellbarIds()
    local sendUpdate = false
    for i = 1, mq.TLO.Me.NumGems() do
        if mq.TLO.Me.Gem(i).ID() == nil then
            previousSpellbar[i] = 'Empty'
        end
        if mq.TLO.Me.Gem(i).ID() ~= nil then
            previousSpellbar[i] = mq.TLO.Me.Gem(i).ID()
        end
    end
    for i = 1, #previousSpellbar do
        if spellbarIds[i] ~= previousSpellbar[i] or spellbarIds[i] == nil then
            spellbarIds[i] = previousSpellbar[i]
            print(spellbarIds[i])
            sendUpdate = true
        end
    end
    if sendUpdate then
        mimicActor:send({ mailbox = 'Driver', script = 'mimic' },
            { id = 'updateSpellbar', charName = mq.TLO.Me.Name(), spellbar = spellbarIds })
    end
end

local function updateGroupIds()
    local selfIncluded = false
    local sendUpdate = false
    for i = 0, 5 do
        if mq.TLO.Group.Member(i).ID() == nil then
            previousGroup[i] = 'Empty'
        end
        if mq.TLO.Group.Member(i).ID() ~= nil then
            previousGroup[i] = mq.TLO.Group.Member(i).ID()
        end
    end
    for i = 1, #previousGroup do
        if groupIds[i] ~= previousGroup[i] then
            sendUpdate = true
            groupIds[i] = previousGroup[i]
        end
        if previousGroup[i] == mq.TLO.Me.ID() then selfIncluded = true end
    end
    if not selfIncluded then
        groupIds[0] = mq.TLO.Me.ID()
    end
    if sendUpdate then
        mimicActor:send({ mailbox = 'Driver', script = 'mimic' },
            { id = 'updateGroup', charName = mq.TLO.Me.Name(), groupIds = groupIds })
    end
end

local function updateXTarget()
    local sendUpdate = false
    for i = 1, mq.TLO.Me.XTargetSlots() do
        if mq.TLO.Me.XTarget(i).ID() == nil or mq.TLO.Me.XTarget(i).ID() == 0 then
            previousXTarget[i] = 'Empty'
        end
        if mq.TLO.Me.XTarget(i).ID() ~= nil and mq.TLO.Me.XTarget(i).ID() ~= 0 then
            previousXTarget[i] = mq.TLO.Me.XTarget(i).ID()
        end
    end
    for i = 1, # previousXTarget do
        if xtargetList[i] ~= previousXTarget[i] then
            sendUpdate = true
            xtargetList[i] = previousXTarget[i]
        end
    end
    if sendUpdate then
        mimicActor:send({ mailbox = 'Driver', script = 'mimic' },
            { id = 'updateXTarget', charName = mq.TLO.Me.Name(), xtarget = xtargetList })
    end
end
local function updateTarget()
    local sendUpdate = false
    if mq.TLO.Target.ID() == nil or mq.TLO.Target.ID() == 0 then
        previousTarget = 'Empty'
    end
    if mq.TLO.Target.ID() ~= nil and mq.TLO.Target.ID() ~= 0 then
        previousTarget = mq.TLO.Target.ID()
    end
    if mimicTargetId ~= previousTarget then
        sendUpdate = true
        mimicTargetId = previousTarget
    end

    if sendUpdate then
        mimicActor:send({ mailbox = 'Driver', script = 'mimic' },
            { id = 'updateTarget', charName = mq.TLO.Me.Name(), target = mimicTargetId })
    end
end

local function mirrorTarget()
    if mq.TLO.Group.MainAssist.ID() ~= nil and not (mq.TLO.Group.MainAssist.OtherZone() or mq.TLO.Group.MainAssist.Offline() or mq.TLO.Group.MainAssist.Name() == mq.TLO.Me.Name()) then
        if mq.TLO.Target.ID() ~= mq.TLO.Me.GroupAssistTarget.ID() then
            mq.TLO.Me.GroupAssistTarget.DoTarget()
        end
    end
end
local function updatePet()
    local sendUpdate = false
    if mq.TLO.Me.Pet() == "NO PET" then
        mimicPetId = 'Empty'
        if UIToggles['showPetWindow'] == true and UIToggles['openPetWindow'] == true then
            UIToggles['showPetWindow'], UIToggles['openPetWindow'] = false, false
            updateDriver()
        end
    end
    -- Pet Summoned
    if mq.TLO.Me.Pet() ~= 'NO PET' then
        if UIToggles['showPetWindow'] == false and UIToggles['openPetWindow'] == false then
            UIToggles['showPetWindow'], UIToggles['openPetWindow'] = true, true
            updateDriver()
        end

        previousPetId = mq.TLO.Spawn(mq.TLO.Me.Pet()).ID()
        if mimicPetId ~= previousPetId then
            sendUpdate = true
            mimicPetId = previousPetId
        end
        -- in combat
        if mq.TLO.Me.Pet.Combat() ~= mimicPetCombat then
            previousPetCombat = mq.TLO.Me.Pet.Combat()
            if mimicPetCombat ~= previousPetCombat then
                sendUpdate = true
                mimicPetCombat = previousPetCombat
            end
        end
        -- Target
        if mq.TLO.Me.Pet.Target.ID() == nil or mq.TLO.Me.Pet.Target.ID() == 0 then
            previousPetTarget = 'Empty'
        end
        if mq.TLO.Me.Pet.Target.ID() ~= nil and mq.TLO.Me.Pet.Target.ID() ~= 0 then
            previousPetTarget = mq.TLO.Me.Pet.Target.ID()
            if mimicPetTarget ~= previousPetTarget then
                sendUpdate = true
                mimicPetTarget = previousPetTarget
            end
        end
    end

    if sendUpdate and mq.TLO.Me.Pet() ~= "NO PET" then
        mimicActor:send({ mailbox = 'Driver', script = 'mimic',
        }, {
            id = 'petUpdate',
            charName = mq.TLO.Me.Name(),
            inCombat = mimicPetCombat,
            petTarget = mimicPetTarget,
            petId = mimicPetId,
        })
    end
end

local function doChase()
    if mq.TLO.Group.MainAssist.ID() ~= nil and not (mq.TLO.Group.MainAssist.OtherZone() or mq.TLO.Group.MainAssist.Offline() or mq.TLO.Group.MainAssist() == mq.TLO.Me.Name())
    then
        if mq.TLO.Group.MainAssist.Distance() > 20 and not mq.TLO.Me.Casting() then
            mq.cmdf("/squelch /nav id %i", mq.TLO.Group.MainAssist.ID())
            while mq.TLO.Navigation.Active() do
                mq.delay(50)
            end
        end
    end
end



if mq.TLO.Me.Pet() == "NO PET" then
    mimicPetId = 'Empty'
    if UIToggles['showPetWindow'] == true and UIToggles['openPetWindow'] == true then
        UIToggles['showPetWindow'], UIToggles['openPetWindow'] = false, false
    end
end

updateDriver()
updateGroupIds()
updateSpellbarIds()
updateXTarget()
updateTarget()
updatePet()



if chaseToggle == true then doChase() end
if followMATarget == true then mirrorTarget() end

local function main()
    while running == true do
        if chaseToggle == true then doChase() end
        if followMATarget then mirrorTarget() end



        updateGroupIds()
        updateSpellbarIds()
        updateXTarget()
        updateTarget()
        if mq.TLO.Me.Pet() ~= 'NO PET' then
            UIToggles['showPetWindow'], UIToggles['openPetWindow'] = true, true
            updatePet()
        else
            UIToggles['showPetWindow'], UIToggles['openPetWindow'] = false, false
        end
    end
    mq.delay(100)
end


main()