local locations = {}
local blips = {}
local peds = {}
local returnZoneIds = {}
local previewVehicle = nil
local previewCam = nil
local contractOpen = false

local function RemoveOxTargetZones()
    if GetResourceState('ox_target') ~= 'started' then return end
    for _, zid in ipairs(returnZoneIds) do
        pcall(function() exports.ox_target:removeZone(zid, true) end)
    end
    returnZoneIds = {}
end

local function AddLocationTargets(loc, ped)
    if Config.TargetSystem == 'ox_target' and GetResourceState('ox_target') == 'started' then
        if ped and DoesEntityExist(ped) then
            exports.ox_target:addLocalEntity(ped, {
                { name = 'rental_' .. loc.id, icon = 'fa-solid fa-car', label = loc.name,
                  onSelect = function() InteractWithPed(loc.id, ped) end }
            })
        end
        local rp = loc.return_point or loc.coords
        local zid = exports.ox_target:addSphereZone({
            coords = vector3(rp.x, rp.y, rp.z),
            radius = Config.ReturnZoneRadius or 20.0,
            options = { {
                name = 'rental_return_' .. loc.id, icon = 'fa-solid fa-flag-checkered',
                label = loc.name .. ' — Restitution',
                canInteract = function() return rentalVehicle ~= nil and DoesEntityExist(rentalVehicle) end,
                onSelect = function() NUI.Open('activeRental', {}) end,
            } },
        })
        returnZoneIds[#returnZoneIds + 1] = zid
    elseif Config.TargetSystem == 'qtarget' and GetResourceState('qtarget') == 'started' and ped then
        exports['qtarget']:AddTargetEntity(ped, {
            options = { { icon = 'fas fa-car', label = loc.name,
                action = function() InteractWithPed(loc.id, ped) end } },
            distance = 2.5,
        })
    end
end

local function StartKeyModeThread()
    CreateThread(function()
        local radius = Config.ReturnZoneRadius or 20.0
        while true do
            local sleep = 500
            local pp = PlayerPedId()
            local pos = GetEntityCoords(pp)
            local nearLocId, nearReturnLocId = nil, nil
            local nearDist, nearReturnDist = 999.0, 999.0

            for _, loc in ipairs(locations) do
                local c = loc.coords
                if not c then goto loc_cont end
                local d = #(pos - vector3(c.x, c.y, c.z))
                if d < Config.InteractDistance then
                    sleep = 0
                    if not nearLocId or d < nearDist then
                        nearLocId = loc.id
                        nearDist = d
                    end
                end

                local rp = loc.return_point or c
                local dret = #(pos - vector3(rp.x, rp.y, rp.z))
                if dret < radius and rentalVehicle and DoesEntityExist(rentalVehicle) then
                    sleep = 0
                    if not nearReturnLocId or dret < nearReturnDist then
                        nearReturnLocId = loc.id
                        nearReturnDist = dret
                    end
                end
                ::loc_cont::
            end

            if sleep == 0 then
                local actionText, actionFn = nil, nil
                if nearReturnLocId and rentalVehicle and DoesEntityExist(rentalVehicle) then
                    local loc = nil
                    for _, l in ipairs(locations) do if l.id == nearReturnLocId then loc = l break end end
                    if loc then
                        actionText = '~INPUT_CONTEXT~ ' .. loc.name .. ' — Restitution'
                        actionFn = function() NUI.Open('activeRental', {}) end
                    end
                end
                if not actionText and nearLocId then
                    local loc = nil
                    for _, l in ipairs(locations) do if l.id == nearLocId then loc = l break end end
                    if loc then
                        actionText = '~INPUT_CONTEXT~ ' .. loc.name
                        actionFn = function() InteractWithPed(nearLocId, nil) end
                    end
                end
                if actionText and actionFn then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(actionText)
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then actionFn() end
                end
            end
            Wait(sleep)
        end
    end)
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    Wait(1000)

    locations = lib.callback.await('perfect_rentals:getLocations', false) or {}

    for _, loc in ipairs(locations) do
        local c = loc.coords
        if not c then goto continue end

        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 2)
        SetBlipScale(blip, loc.blip_scale or Config.Blip.scale)
        SetBlipColour(blip, loc.blip_color or Config.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.BlipNamesPerLocation and (loc.name or Config.Blip.label) or (Config.Blip.label or loc.name))
        EndTextCommandSetBlipName(blip)
        blips[#blips+1] = blip

        local ped = nil
        if loc.ped_model then
            local model = joaat(loc.ped_model)
            RequestModel(model)
            local to = 0
            while not HasModelLoaded(model) and to < 50 do Wait(100) to = to + 1 end
            if HasModelLoaded(model) then
                ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.h or 0.0, false, true)
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                if LoadAnimDict('amb@world_human_clipboard@male@idle_a') then
                    TaskPlayAnim(ped, 'amb@world_human_clipboard@male@idle_a', 'idle_c', 1.0, -1.0, -1, 1, 0, false, false, false)
                end
                peds[#peds+1] = { entity = ped, coords = vector3(c.x, c.y, c.z), locId = loc.id }
                SetModelAsNoLongerNeeded(model)
            end
        end

        if Config.TargetSystem == 'ox_target' or Config.TargetSystem == 'qtarget' then
            AddLocationTargets(loc, ped)
        end

        ::continue::
    end

    if Config.TargetSystem == 'key' or Config.TargetSystem == 'none' then
        StartKeyModeThread()
    end

    print('^2[perfect_rentals]^0 Client loaded — ' .. #locations .. ' locations. Mode: ' .. tostring(Config.TargetSystem))
end)

function InteractWithPed(locationId, npcEntity)
    local pp = PlayerPedId()
    if npcEntity and DoesEntityExist(npcEntity) then
        FaceEntity(pp, GetEntityCoords(npcEntity))
    end
    PlayAnim(pp, 'mp_common', 'givetake1_a', 2000, 48)
    Wait(1200)
    StopAnim(pp, 'mp_common', 'givetake1_a')
    OpenRentalUI(locationId)
end

function OpenRentalUI(locationId)
    NUI.Open('catalog', { locationId = locationId })
end
exports('OpenRentalUI', OpenRentalUI)

RegisterNUICallback('showroomPreview', function(data, cb)
    if previewVehicle then DestroyPreview() end

    local locId = data.locationId
    local loc = nil
    for _, l in ipairs(locations) do
        if l.id == locId then loc = l break end
    end

    local spawnPos = loc and loc.showroom or (loc and loc.spawnpoints and loc.spawnpoints[1]) or nil
    if not spawnPos then cb({ ok = false }) return end

    local model = joaat(data.model)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(100) t = t + 1 end
    if not HasModelLoaded(model) then cb({ ok = false }) return end

    local veh = CreateVehicle(model, spawnPos.x, spawnPos.y, spawnPos.z, spawnPos.h or 0.0, false, false)
    while not DoesEntityExist(veh) do Wait(50) end

    SetEntityAsMissionEntity(veh, true, true)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetEntityCollision(veh, false, false)
    SetVehicleDirtLevel(veh, 0.0)
    SetModelAsNoLongerNeeded(model)

    previewVehicle = veh

    local vPos = GetEntityCoords(veh)
    local camDist = Config.Showroom.camDistance
    local camH = Config.Showroom.camHeight
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, vPos.x + camDist, vPos.y, vPos.z + camH)
    PointCamAtEntity(cam, veh, 0.0, 0.0, 0.0, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 800, true, false)
    previewCam = cam

    CreateThread(function()
        local angle = 0.0
        while previewVehicle and DoesEntityExist(previewVehicle) do
            angle = angle + Config.Showroom.rotateSpeed
            if angle >= 360 then angle = angle - 360 end
            local rad = math.rad(angle)
            local cx = vPos.x + camDist * math.cos(rad)
            local cy = vPos.y + camDist * math.sin(rad)
            SetCamCoord(previewCam, cx, cy, vPos.z + camH)
            PointCamAtEntity(previewCam, previewVehicle, 0.0, 0.0, 0.0, true)

            DisableControlAction(0, 200, true)
            DisableControlAction(0, 322, true)
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 322) then
                DestroyPreview()
                break
            end

            Wait(0)
        end
    end)

    cb({ ok = true })
end)

RegisterNUICallback('showroomClose', function(_, cb)
    DestroyPreview()
    cb('ok')
end)

function DestroyPreview()
    if previewVehicle and DoesEntityExist(previewVehicle) then
        DeleteVehicle(previewVehicle)
    end
    previewVehicle = nil
    if previewCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(previewCam, false)
        previewCam = nil
    end
end

RegisterNetEvent('perfect_rentals:spawnRentalVehicle', function(data)
    if not data or not data.ok then return end
    SpawnRentalVehicle(data)
end)

function SpawnRentalVehicle(data)
    local pp = PlayerPedId()
    local model = joaat(data.model)

    CFW.Notify(L('rental_vehicle_preparing'), 'info')

    local animDict = 'cellphone@'
    local animName = 'cellphone_call_listen_base'
    if LoadAnimDict(animDict) then
        TaskPlayAnim(pp, animDict, animName, 8.0, -8.0, -1, 50, 0, false, false, false)
    end

    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(100) t = t + 1 end

    ClearPedTasks(pp)

    if not HasModelLoaded(model) then CFW.Notify(L('vehicle_not_found'), 'error') return end

    local spawn = data.spawnpoints and data.spawnpoints[1]
    if not spawn then CFW.Notify(L('spawn_blocked'), 'error') return end

    for _, sp in ipairs(data.spawnpoints) do
        if not IsPositionOccupied(sp.x, sp.y, sp.z, 2.0, false, true, false, false, false, 0, false) then
            spawn = sp break
        end
    end

    Wait(2000)

    local veh = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.h or 0.0, true, false)
    while not DoesEntityExist(veh) do Wait(50) end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdCanMigrate(netId, true)
    SetVehicleNumberPlateText(veh, data.plate)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    CFW.SetFuelLevel(veh, Config.FuelLevel)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleDoorsLocked(veh, 1)
    SetModelAsNoLongerNeeded(model)

    rentalVehicle = veh
    activeToken = data.token

    TriggerServerEvent('perfect_rentals:vehicleSpawned', data.token, netId)

    if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    deliveryBlip = AddBlipForEntity(veh)
    SetBlipSprite(deliveryBlip, 326)
    SetBlipColour(deliveryBlip, 3)
    SetBlipScale(deliveryBlip, 0.9)
    SetBlipFlashes(deliveryBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('delivery_blip'))
    EndTextCommandSetBlipName(deliveryBlip)
    SetNewWaypoint(spawn.x, spawn.y)

    CFW.Notify(L('rental_vehicle_ready_gps'), 'success')
    if data.endTs then StartRentalTimer(data.endTs) end

    CreateThread(function()
        while rentalVehicle and DoesEntityExist(rentalVehicle) do
            Wait(500)
            local pped = PlayerPedId()
            if GetVehiclePedIsIn(pped, false) == rentalVehicle then
                if deliveryBlip and DoesBlipExist(deliveryBlip) then
                    RemoveBlip(deliveryBlip)
                    deliveryBlip = nil
                end
                CFW.Notify(L('rental_have_safe_trip'), 'info')
                break
            end
        end
    end)
end

local function FindRentalVehicleByPlate(plate)
    if not plate or plate == '' then return nil end
    local function trim(s)
        return (s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end
    local target = trim(plate)
    if target == '' then return nil end
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(v) then
            if trim(GetVehicleNumberPlateText(v)) == target then
                return v
            end
        end
    end
    return nil
end

RegisterNUICallback('scanVehicle', function(_, cb)
    local veh = nil

    if rentalVehicle and DoesEntityExist(rentalVehicle) then
        veh = rentalVehicle
    else
        local pp = PlayerPedId()
        local inVeh = GetVehiclePedIsIn(pp, false)
        if inVeh and inVeh ~= 0 then veh = inVeh end
    end

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        local contract = lib.callback.await('perfect_rentals:getActiveContract', false)
        if contract and contract.plate then
            veh = FindRentalVehicleByPlate(contract.plate)
            if veh then
                rentalVehicle = veh
            end
        end
    end

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        lastScanData = { engine = 0, body = 0, fuel = 0, wheels = 0, destroyed = true }
        cb(lastScanData)
        return
    end

    local eh = GetVehicleEngineHealth(veh)
    local bh = GetVehicleBodyHealth(veh)
    local fl = CFW.GetFuelLevel(veh)
    local destroyed = IsEntityDead(veh)

    local wheelsOk = true
    for i = 0, GetVehicleNumberOfWheels(veh) - 1 do
        if IsVehicleTyreBurst(veh, i, false) then wheelsOk = false break end
    end

    lastScanData = {
        engine    = math.floor(math.max(0, eh) / 10),
        body      = math.floor(math.max(0, bh) / 10),
        fuel      = math.floor(math.max(0, fl)),
        wheels    = wheelsOk and 100 or 0,
        destroyed = destroyed,
    }
    cb(lastScanData)
end)

RegisterNUICallback('gpsReturn', function(_, cb)
    local contract = lib.callback.await('perfect_rentals:getActiveContract', false)
    if not contract or not contract.location_id then
        CFW.Notify(L('no_active_rental'), 'error')
        cb('ok')
        return
    end
    local done = false
    for _, loc in ipairs(locations) do
        if loc.id == contract.location_id then
            local rp = loc.return_point or loc.coords
            if rp and rp.x and rp.y then
                SetNewWaypoint(rp.x, rp.y)
                CFW.Notify(L('gps_return_updated'), 'success')
                done = true
            end
            break
        end
    end
    if not done then CFW.Notify(L('gps_return_failed'), 'warning') end
    cb('ok')
end)

RegisterNetEvent('perfect_rentals:openLocationCmd', function(contract)
    if contract.serverTime then SyncServerTime(contract.serverTime) end
    NUI.Open('activeRental', { fromCommand = true })
end)

RegisterNetEvent('perfect_rentals:refreshLocations', function()
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _, p in ipairs(peds) do if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end end
    blips = {}
    peds = {}
    RemoveOxTargetZones()

    locations = lib.callback.await('perfect_rentals:getLocations', false) or {}

    for _, loc in ipairs(locations) do
        local c = loc.coords
        if not c then goto cont end

        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipDisplay(blip, 2)
        SetBlipScale(blip, loc.blip_scale or Config.Blip.scale)
        SetBlipColour(blip, loc.blip_color or Config.Blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.BlipNamesPerLocation and (loc.name or Config.Blip.label) or (Config.Blip.label or loc.name))
        EndTextCommandSetBlipName(blip)
        blips[#blips+1] = blip

        local ped = nil
        if loc.ped_model then
            local model = joaat(loc.ped_model)
            RequestModel(model)
            local to = 0
            while not HasModelLoaded(model) and to < 50 do Wait(100) to = to + 1 end
            if HasModelLoaded(model) then
                ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.h or 0.0, false, true)
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                if LoadAnimDict('amb@world_human_clipboard@male@idle_a') then
                    TaskPlayAnim(ped, 'amb@world_human_clipboard@male@idle_a', 'idle_c', 1.0, -1.0, -1, 1, 0, false, false, false)
                end
                peds[#peds+1] = { entity = ped, coords = vector3(c.x, c.y, c.z), locId = loc.id }
                SetModelAsNoLongerNeeded(model)
            end
        end

        if Config.TargetSystem == 'ox_target' or Config.TargetSystem == 'qtarget' then
            AddLocationTargets(loc, ped)
        end

        ::cont::
    end
    print('^2[perfect_rentals]^0 Locations refreshed — ' .. #locations .. ' active.')
end)

RegisterNetEvent('perfect_rentals:forceDeleteVehicle', function(plate)
    local function normPlate(p)
        return ((p or ''):gsub('%s+', '')):upper()
    end
    local want = normPlate(plate)
    if rentalVehicle and DoesEntityExist(rentalVehicle) then
        if normPlate(GetVehicleNumberPlateText(rentalVehicle)) == want then
            DoScreenFadeOut(300) Wait(400)
            DeleteVehicle(rentalVehicle)
            rentalVehicle = nil
            activeToken = nil
            StopRentalTimer()
            if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) deliveryBlip = nil end
            Wait(200)
            DoScreenFadeIn(500)
        end
    end
end)

local timerEndTs = nil
local timerHudShown = false
local lastTimerHudTxt = ''

function StartRentalTimer(endTs)
    timerEndTs = endTs
    lastTimerHudTxt = ''
end

function StopRentalTimer()
    timerEndTs = nil
    lastTimerHudTxt = ''
    if timerHudShown and GetResourceState('ox_lib') == 'started' then
        lib.hideTextUI()
        timerHudShown = false
    end
end

CreateThread(function()
    local function fmt(rem)
        if rem <= 0 then return L('timer_hud_expired') end
        local s = math.floor(rem / 1000)
        local h = math.floor(s / 3600)
        local m = math.floor((s % 3600) / 60)
        local sec = s % 60
        return string.format('%02d:%02d:%02d', h, m, sec)
    end
    while true do
        Wait(600)
        if not Config.ShowRentalTimerHud or not timerEndTs then
            if timerHudShown and GetResourceState('ox_lib') == 'started' then lib.hideTextUI() end
            timerHudShown = false
            lastTimerHudTxt = ''
        elseif NUI.IsOpen() or contractOpen then
            if timerHudShown and GetResourceState('ox_lib') == 'started' then lib.hideTextUI() end
            timerHudShown = false
            lastTimerHudTxt = ''
        elseif GetResourceState('ox_lib') == 'started' then
            local rem = timerEndTs - GetServerTime()
            local line = L('timer_hud_prefix') .. '  ' .. fmt(rem)
            if line ~= lastTimerHudTxt then
                lib.showTextUI(line)
                lastTimerHudTxt = line
                timerHudShown = true
            end
        end
    end
end)

CreateThread(function()
    while true do
        if timerEndTs then
            local rem = timerEndTs - GetServerTime()
            if rem <= 0 then
                StopRentalTimer()
                CFW.Notify(L('rental_expired'), 'warning')
            end
        end
        Wait(30000)
    end
end)

CreateThread(function()
    Wait(3000)
    local contract = lib.callback.await('perfect_rentals:getActiveContract', false)
    if contract then
        activeToken = contract.token
        if contract.serverTime then SyncServerTime(contract.serverTime) end
        if contract.end_ts then StartRentalTimer(contract.end_ts) end
    end
end)

CreateThread(function()
    while true do
        Wait(3000)
        if not rentalVehicle or not DoesEntityExist(rentalVehicle) then
            local contract = lib.callback.await('perfect_rentals:getActiveContract', false)
            if contract and contract.plate then
                local veh = FindRentalVehicleByPlate(contract.plate)
                if veh then
                    rentalVehicle = veh
                    if not activeToken and contract.token then activeToken = contract.token end
                end
            end
        end
    end
end)

local contractProp = nil
local contractPropModel = GetHashKey('prop_cs_documents_01')

CreateThread(function()
    RequestAnimDict('cellphone@')
    RequestModel(contractPropModel)
    while not HasAnimDictLoaded('cellphone@') or not HasModelLoaded(contractPropModel) do Wait(0) end
end)

local function AttachContractProp()
    local pp = PlayerPedId()
    TaskPlayAnim(pp, 'cellphone@', 'cellphone_text_read_base', 2.0, -2.0, -1, 49, 0, false, false, false)
    contractProp = CreateObject(contractPropModel, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(contractProp, pp, GetPedBoneIndex(pp, 36029),
        0.05, 0.02, -0.01, 10.0, 0.0, 0.0,
        true, true, false, true, 1, true)
end

local function DetachContractProp()
    local pp = PlayerPedId()
    ClearPedTasks(pp)
    if contractProp and DoesEntityExist(contractProp) then
        DetachEntity(contractProp, false, false)
        DeleteObject(contractProp)
    end
    contractProp = nil
end

RegisterNetEvent('perfect_rentals:showContract', function(data)
    AttachContractProp()

    contractOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'bootstrap', data = PR.NuiBootstrap() })
    SendNUIMessage({
        action = 'showContractPaper',
        data = {
            mine        = true,
            ownerName   = data.playerName,
            contractNum = data.contractNum,
            vehicle     = data.vehicle,
            plate       = data.plate,
            endDate     = data.endDate,
            insurance   = data.insurance,
        }
    })

    TriggerServerEvent('perfect_rentals:contractShownToNearby', data)
end)

RegisterNUICallback('closeContract', function(_, cb)
    cb('ok')
    contractOpen = false
    SetNuiFocus(false, false)
    DetachContractProp()
end)

RegisterNetEvent('perfect_rentals:seeContract', function(contractData, ownerName)
    SendNUIMessage({ action = 'bootstrap', data = PR.NuiBootstrap() })
    SendNUIMessage({
        action = 'showContractPaper',
        data = {
            mine        = false,
            ownerName   = ownerName,
            contractNum = contractData.contractNum,
            vehicle     = contractData.vehicle,
            plate       = contractData.plate,
            endDate     = contractData.endDate,
            insurance   = contractData.insurance,
        }
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _, p in ipairs(peds) do if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end end
    if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) end
    DestroyPreview()
    RemoveOxTargetZones()
    if GetResourceState('ox_lib') == 'started' then lib.hideTextUI() end
    if NUI.IsOpen() then NUI.Close() end
end)
