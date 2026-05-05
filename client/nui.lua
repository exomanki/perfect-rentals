NUI = {}

local isOpen = false

function NUI.IsOpen() return isOpen end

function NUI.Send(action, data)
    SendNUIMessage({ action = action, data = data or {} })
end

function NUI.Open(page, extra)
    isOpen = true
    SetNuiFocus(true, true)
    NUI.Send('applyTheme', Config.Theme or {})
    NUI.Send('open', { page = page, extra = extra or {}, bootstrap = PR.NuiBootstrap() })
end

function NUI.Close()
    isOpen = false
    SetNuiFocus(false, false)
    NUI.Send('close', {})
end

RegisterNUICallback('closeUI', function(_, cb)
    NUI.Close()
    cb('ok')
end)

RegisterNUICallback('requestConfirm', function(data, cb)
    local choice = lib.alertDialog({
        header = data.title or 'Confirmation',
        content = data.message or 'Confirmer ?',
        centered = true,
        cancel = true,
    })
    cb({ confirmed = choice == 'confirm' })
end)

RegisterNUICallback('requestInput', function(data, cb)
    local input = lib.inputDialog(data.title or 'Saisie', {
        { type = 'input', label = data.label or 'Valeur', default = data.default or '', required = true }
    })
    if not input then
        cb({ value = nil })
        return
    end
    cb({ value = input[1] })
end)

RegisterNUICallback('requestLocationDeleteChoice', function(data, cb)
    local first = lib.alertDialog({
        header = 'Point de location',
        content = 'Supprimer ce point de location ?',
        centered = true,
        cancel = true,
        labels = { confirm = 'Oui', cancel = 'Annuler' },
    })
    if first ~= 'confirm' then
        cb({ action = 'cancel' })
        return
    end
    local second = lib.alertDialog({
        header = 'Type de suppression',
        content = 'Désactiver uniquement (réversible) ou supprimer définitivement de la base de données ?',
        centered = true,
        cancel = true,
        labels = { confirm = 'Supprimer de la BDD', cancel = 'Désactiver uniquement' },
    })
    if second == 'confirm' then
        cb({ action = 'delete' })
    else
        cb({ action = 'deactivate' })
    end
end)

RegisterNUICallback('getVehicles', function(data, cb)
    local vehicles = lib.callback.await('perfect_rentals:getVehicles', false, data.locationId)
    cb(vehicles or {})
end)

RegisterNUICallback('getActiveContract', function(_, cb)
    local c = lib.callback.await('perfect_rentals:getActiveContract', false)
    if c and c.serverTime then SyncServerTime(c.serverTime) end
    cb(c)
end)

RegisterNUICallback('getHistory', function(_, cb)
    local h = lib.callback.await('perfect_rentals:getHistory', false)
    cb(h or {})
end)

RegisterNUICallback('calculatePrice', function(data, cb)
    local r = lib.callback.await('perfect_rentals:calculatePrice', false, data)
    cb(r)
end)

RegisterNUICallback('getPlayerInfo', function(_, cb)
    local r = lib.callback.await('perfect_rentals:getPlayerInfo', false)
    cb(r or {})
end)

RegisterNUICallback('rent', function(data, cb)
    DestroyPreview()
    local result = lib.callback.await('perfect_rentals:rent', false, data)
    if result and result.ok then
        NUI.Close()
        Wait(500)
        SpawnRentalVehicle(result)
    end
    cb(result or { ok = false })
end)

RegisterNUICallback('returnVehicle', function(_, cb)
    local pp = PlayerPedId()
    local scan = lastScanData
    if not scan then
        cb({ ok = false, msg = 'Aucun scan effectué' })
        return
    end

    local engineHealth = (scan.engine or 0) * 10
    local bodyHealth   = (scan.body or 0) * 10
    local fuelLevel    = scan.fuel or 0
    local isDestroyed  = scan.destroyed or false
    local wheelsOk     = (scan.wheels or 0) >= 50

    if LoadAnimDict('mp_common') then
        TaskPlayAnim(pp, 'mp_common', 'givetake1_a', 8.0, -8.0, 2000, 48, 0, false, false, false)
    end

    local result = lib.callback.await('perfect_rentals:returnVehicle', false, {
        engineHealth = engineHealth, bodyHealth = bodyHealth,
        fuelLevel = fuelLevel, isDestroyed = isDestroyed, wheelsIntact = wheelsOk,
    })

    Wait(1500)
    ClearPedTasks(pp)

    if result and result.ok then
        local veh = rentalVehicle
        if veh and DoesEntityExist(veh) and not isDestroyed then
            DoScreenFadeOut(500) Wait(600)
            DeleteVehicle(veh)
            Wait(200)
            DoScreenFadeIn(500)
        end
        rentalVehicle = nil
        activeToken = nil
        lastScanData = nil
        StopRentalTimer()
        if deliveryBlip and DoesBlipExist(deliveryBlip) then RemoveBlip(deliveryBlip) deliveryBlip = nil end
    end

    cb(result or { ok = false })
end)

RegisterNUICallback('extend', function(data, cb)
    local r = lib.callback.await('perfect_rentals:extend', false, data)
    if r and r.ok and r.newEndTs then
        if r.serverTime then SyncServerTime(r.serverTime) end
        StartRentalTimer(r.newEndTs)
    end
    cb(r or { ok = false })
end)

RegisterNetEvent('perfect_rentals:openAdminPanel', function()
    isOpen = true
    SetNuiFocus(true, true)
    NUI.Send('applyTheme', Config.Theme or {})
    NUI.Send('openAdmin', {})
end)

RegisterNUICallback('adminGetAll', function(_, cb)
    local r = lib.callback.await('perfect_rentals:admin:getAll', false)
    cb(r or {})
end)

RegisterNUICallback('adminSaveVehicle', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:saveVehicle', false, data)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminDeleteVehicle', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:deleteVehicle', false, data.id)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminForceReturn', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:forceReturn', false, data.id)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminRefund', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:refund', false, data.id, data.amount)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminSaveLocation', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:saveLocation', false, data)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminDeleteLocation', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:deleteLocation', false, data.id, data.action)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminGetLocationVehicles', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:getLocationVehicles', false, data.locationId)
    cb(r or {})
end)

RegisterNUICallback('adminSetLocationVehicle', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:setLocationVehicle', false, data)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminRemoveLocationVehicle', function(data, cb)
    local r = lib.callback.await('perfect_rentals:admin:removeLocationVehicle', false, data)
    cb(r or { ok = false })
end)

RegisterNUICallback('adminGetPlayerCoords', function(_, cb)
    local pp = PlayerPedId()
    local pos = GetEntityCoords(pp)
    local heading = GetEntityHeading(pp)
    cb({ x = math.floor(pos.x * 100) / 100, y = math.floor(pos.y * 100) / 100, z = math.floor(pos.z * 100) / 100, h = math.floor(heading * 100) / 100 })
end)

RegisterNUICallback('adminStartPlacement', function(data, cb)
    cb('ok')
    local pType = data.type

    isOpen = false
    SetNuiFocus(false, false)

    local active = true
    local placed = {}
    local labels = { pnj = 'PNJ', ['return'] = 'Point de retour', showroom = 'Showroom' }

    CreateThread(function()
        while active do
            Wait(0)
            local pp = PlayerPedId()
            local pos = GetEntityCoords(pp)
            local heading = GetEntityHeading(pp)

            DisableControlAction(0, 200, true)

            DrawMarker(25, pos.x, pos.y, pos.z - 0.97,
                0.0,0.0,0.0, 0.0,0.0,0.0,
                2.0,2.0,0.5, 59,130,246,100,
                false,true,2, false,nil,nil,false)

            for i, sp in ipairs(placed) do
                DrawMarker(25, sp.x, sp.y, sp.z - 0.97,
                    0.0,0.0,0.0, 0.0,0.0,0.0,
                    1.5,1.5,0.5, 46,204,113,140,
                    false,true,2, false,nil,nil,false)
                DrawText3D(sp.x, sp.y, sp.z + 0.5, 'Spawn #'..i)
            end

            if pType == 'spawn' then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(
                    '~INPUT_CONTEXT~ Placer un spawn (~b~'..#placed..'~s~ placé(s))~n~'..
                    '~INPUT_CELLPHONE_CANCEL~ Terminer')
                EndTextCommandDisplayHelp(0, false, true, -1)
            else
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName(
                    '~INPUT_CONTEXT~ Confirmer la position du ~b~'..(labels[pType] or pType)..'~s~~n~'..
                    '~INPUT_CELLPHONE_CANCEL~ Annuler')
                EndTextCommandDisplayHelp(0, false, true, -1)
            end

            local function capturePos()
                return {
                    x = math.floor(pos.x * 100) / 100,
                    y = math.floor(pos.y * 100) / 100,
                    z = math.floor(pos.z * 100) / 100,
                    h = math.floor(heading * 100) / 100,
                }
            end

            if IsControlJustReleased(0, 38) then
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                if pType == 'spawn' then
                    placed[#placed+1] = capturePos()
                else
                    active = false
                    Wait(300)
                    isOpen = true
                    SetNuiFocus(true, true)
                    SendNUIMessage({
                        action = 'placementResult',
                        data = { type = pType, coords = capturePos() }
                    })
                end
            end

            if IsDisabledControlJustReleased(0, 177) then
                active = false
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
                Wait(300)
                isOpen = true
                SetNuiFocus(true, true)
                if pType == 'spawn' and #placed > 0 then
                    SendNUIMessage({
                        action = 'placementResult',
                        data = { type = 'spawn', points = placed }
                    })
                else
                    SendNUIMessage({
                        action = 'placementResult',
                        data = { type = 'cancelled' }
                    })
                end
            end
        end
    end)
end)
