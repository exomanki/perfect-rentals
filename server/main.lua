local rateLimits = {}
local cachedVehicles = nil
local cachedLocations = nil

local function RateCheck(source, action)
    local key = source .. ':' .. action
    local now = GetGameTimer()
    local cd = Config.RateLimit[action .. 'Cooldown'] or 5000
    if rateLimits[key] and (now - rateLimits[key]) < cd then return false end
    rateLimits[key] = now
    return true
end

local function GenerateUniquePlate()
    for _ = 1, 50 do
        local plate = PR.GeneratePlate()
        if not DB.PlateExists(plate) then return plate end
    end
    return nil
end

local function RefreshCache()
    local ok, err = pcall(function()
        cachedVehicles = DB.GetVehicles() or {}
        cachedLocations = DB.GetLocations() or {}
        for i, loc in ipairs(cachedLocations) do
            cachedLocations[i].coords     = type(loc.coords_json) == 'string' and json.decode(loc.coords_json) or loc.coords_json
            cachedLocations[i].spawnpoints = type(loc.spawnpoints_json) == 'string' and json.decode(loc.spawnpoints_json) or loc.spawnpoints_json
            if loc.return_point_json then
                cachedLocations[i].return_point = type(loc.return_point_json) == 'string' and json.decode(loc.return_point_json) or loc.return_point_json
            end
            if loc.showroom_json then
                cachedLocations[i].showroom = type(loc.showroom_json) == 'string' and json.decode(loc.showroom_json) or loc.showroom_json
            end
        end
    end)
    if not ok then
        print('^1[perfect_rentals] RefreshCache ERROR:^0 ' .. tostring(err))
        print('^3[perfect_rentals] As-tu bien importé sql/install.sql dans ta base de données ?^0')
        if not cachedVehicles then cachedVehicles = {} end
        if not cachedLocations then cachedLocations = {} end
    end
end

local function GetRentalPlayerName(src)
    if Config.Framework == 'esx' and ESX then
        local xP = ESX.GetPlayerFromId(src)
        if xP then return xP.getName() end
    elseif PR.UsesQBFramework() and QBCore then
        local p = QBCore.Functions.GetPlayer(src)
        if p then return p.PlayerData.charinfo.firstname .. ' ' .. p.PlayerData.charinfo.lastname end
    end
    return GetPlayerName(src) or 'Inconnu'
end

CreateThread(function()
    Wait(2000)
    RefreshCache()
    print('^2[perfect_rentals]^0 Loaded ' .. #cachedVehicles .. ' vehicles, ' .. #cachedLocations .. ' locations.')
end)

CreateThread(function()
    Wait(800)
    pcall(function()
        local cnt = MySQL.scalar.await([[
            SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'rentals_contracts'
              AND COLUMN_NAME = 'payment_method'
        ]])
        if not cnt or cnt == 0 then
            MySQL.update.await([[
                ALTER TABLE rentals_contracts
                ADD COLUMN payment_method VARCHAR(16) NOT NULL DEFAULT 'bank' AFTER delivery
            ]])
            print('^2[perfect_rentals]^0 Migration: colonne payment_method ajoutée à rentals_contracts.')
        end
    end)
end)

lib.callback.register('perfect_rentals:getVehicles', function(source, locationId)
    if locationId then
        local ok, has = pcall(DB.HasLocationVehicles, locationId)
        if ok and has then
            local ok2, locVeh = pcall(DB.GetLocationVehicles, locationId)
            if ok2 and locVeh and #locVeh > 0 then return locVeh end
        end
    end
    if not cachedVehicles or #cachedVehicles == 0 then RefreshCache() end
    return cachedVehicles or {}
end)

lib.callback.register('perfect_rentals:getLocations', function(source)
    if not cachedLocations then RefreshCache() end
    local safe = {}
    for _, loc in ipairs(cachedLocations) do
        safe[#safe+1] = {
            id = loc.id, name = loc.name, coords = loc.coords,
            spawnpoints = loc.spawnpoints, return_point = loc.return_point,
            showroom = loc.showroom,
            blip_sprite = loc.blip_sprite, blip_color = loc.blip_color,
            blip_scale = loc.blip_scale, ped_model = loc.ped_model,
        }
    end
    return safe
end)

lib.callback.register('perfect_rentals:getActiveContract', function(source)
    local id = FW.GetIdentifier(source)
    if not id then return nil end
    local c = DB.GetActiveContract(id)
    if not c then return nil end
    c.serverTime = os.time() * 1000
    return c
end)

lib.callback.register('perfect_rentals:getHistory', function(source)
    local id = FW.GetIdentifier(source)
    if not id then return {} end
    return DB.GetHistory(id)
end)

lib.callback.register('perfect_rentals:calculatePrice', function(source, data)
    if not data or not data.model or not data.duration or not data.insurance or not data.fuelPolicy or not data.locationId then return nil end
    local locId = tonumber(data.locationId)
    if not locId then return nil end
    if not PR.IsValidDuration(data.duration) then return nil end
    if not PR.IsValidInsurance(data.insurance) then return nil end
    if not PR.IsValidFuelPolicy(data.fuelPolicy) then return nil end
    if not DB.GetLocation(locId) then return nil end
    local vehicle = select(1, DB.GetVehicleForLocation(locId, data.model))
    if not vehicle then return nil end
    local deliveryStrict = data.delivery == true
    local price = PR.CalculatePrice(vehicle.price_per_day, data.duration, data.insurance, data.fuelPolicy, deliveryStrict)
    if not price then return nil end
    price.deposit = vehicle.deposit
    price.grandTotal = price.total + vehicle.deposit
    return price
end)

lib.callback.register('perfect_rentals:getPlayerInfo', function(source)
    local id = FW.GetIdentifier(source)
    local name = GetRentalPlayerName(source)
    return { identifier = id, name = name }
end)


lib.callback.register('perfect_rentals:rent', function(source, data)
    if not RateCheck(source, 'rent') then
        FW.Notify(source, L('rate_limited'), 'error')
        return { ok = false, msg = 'rate_limited' }
    end

    local identifier = FW.GetIdentifier(source)
    if not identifier then return { ok = false, msg = 'no_identifier' } end

    if DB.GetActiveContract(identifier) then
        FW.Notify(source, L('already_renting'), 'error')
        return { ok = false, msg = 'already_renting' }
    end

    if not data or not data.model or not data.duration or not data.insurance
       or not data.fuelPolicy or not data.locationId or not data.payment then
        return { ok = false, msg = 'invalid_data' }
    end

    local locId = tonumber(data.locationId)
    if not locId then return { ok = false, msg = 'invalid_location' } end

    if not PR.IsValidDuration(data.duration) then return { ok = false, msg = 'invalid_duration' } end
    if not PR.IsValidInsurance(data.insurance) then return { ok = false, msg = 'invalid_insurance' } end
    if not PR.IsValidFuelPolicy(data.fuelPolicy) then return { ok = false, msg = 'invalid_fuel_policy' } end

    local payMethod = PR.ResolvePayment(data.payment)

    local vehicle, fleetMeta = DB.GetVehicleForLocation(locId, data.model)
    if not vehicle then return { ok = false, msg = 'vehicle_not_found' } end
    if vehicle.stock ~= nil and vehicle.stock >= 0 and vehicle.stock < 1 then
        FW.Notify(source, L('out_of_stock'), 'error')
        return { ok = false, msg = 'out_of_stock' }
    end

    local location = DB.GetLocation(locId)
    if not location then return { ok = false, msg = 'location_not_found' } end

    local deliveryStrict = data.delivery == true
    local price = PR.CalculatePrice(vehicle.price_per_day, data.duration, data.insurance, data.fuelPolicy, deliveryStrict)
    if not price then return { ok = false, msg = 'price_calc_failed' } end

    local grandTotal = price.total + vehicle.deposit

    if FW.GetMoney(source, payMethod) < grandTotal then
        FW.Notify(source, L('not_enough_money'), 'error')
        return { ok = false, msg = 'not_enough_money' }
    end

    local plate = GenerateUniquePlate()
    if not plate then return { ok = false, msg = 'plate_gen_failed' } end

    if not DB.TryConsumeFleetStock(locId, vehicle, fleetMeta) then
        FW.Notify(source, L('out_of_stock'), 'error')
        return { ok = false, msg = 'out_of_stock' }
    end

    local token = PR.GenerateToken()
    local now = os.time() * 1000
    local endTs = now + (data.duration * 60 * 1000)
    local contractNum = DB.GenerateContractNum()
    local playerName = GetRentalPlayerName(source)

    if not FW.RemoveMoney(source, grandTotal, payMethod) then
        DB.RestoreFleetStock(locId, data.model)
        return { ok = false, msg = 'payment_failed' }
    end

    local insertOk, contractId = pcall(function()
        return DB.CreateContract({
            contract_num  = contractNum,
            identifier    = identifier,
            player_name   = playerName,
            location_id   = locId,
            vehicle_model = data.model,
            plate         = plate,
            token         = token,
            start_ts      = now,
            end_ts        = endTs,
            price_total   = price.total,
            deposit       = vehicle.deposit,
            insurance     = data.insurance,
            fuel_policy   = data.fuelPolicy,
            delivery      = deliveryStrict,
            payment_method = payMethod,
        })
    end)

    if not insertOk then
        print(('^1[perfect_rentals]^0 Erreur MySQL création contrat : %s'):format(tostring(contractId)))
    end

    if not insertOk or not contractId then
        FW.AddMoney(source, grandTotal, payMethod)
        DB.RestoreFleetStock(locId, data.model)
        FW.Notify(source, L('contract_creation_failed'), 'error')
        return { ok = false, msg = 'contract_failed' }
    end

    DB.IncrementPopularity(data.model)

    FW.AddItem(source, 'contract', 1, {
        label = 'Contrat #' .. contractNum,
        description = vehicle.label .. ' — ' .. plate,
    })

    local spawns = type(location.spawnpoints_json) == 'string' and json.decode(location.spawnpoints_json) or location.spawnpoints_json

    FW.Notify(source, L('rental_started', plate), 'success')
    Webhook.Rental(identifier, vehicle.label, plate, tostring(grandTotal), location.name)
    RefreshCache()

    return {
        ok = true,
        contractId   = contractId,
        contractNum  = contractNum,
        playerName   = playerName,
        plate        = plate,
        token        = token,
        model        = data.model,
        modelLabel   = vehicle.label,
        spawnpoints  = spawns,
        endTs        = endTs,
        startTs      = now,
        serverTime   = now,
        deposit      = vehicle.deposit,
        priceTotal   = price.total,
        insurance    = data.insurance,
        fuelPolicy   = data.fuelPolicy,
        duration     = data.duration,
        priceBreakdown = price,
    }
end)

RegisterNetEvent('perfect_rentals:vehicleSpawned', function(token, netId)
    local source = source
    local contract = DB.GetActiveContractByToken(token)
    if not contract then return end
    if contract.identifier ~= FW.GetIdentifier(source) then return end
    DB.UpdateContractNetId(contract.id, netId)
end)


lib.callback.register('perfect_rentals:returnVehicle', function(source, data)
    if not RateCheck(source, 'return') then
        FW.Notify(source, L('rate_limited'), 'error')
        return { ok = false, msg = 'rate_limited' }
    end

    local identifier = FW.GetIdentifier(source)
    if not identifier then return { ok = false } end

    local contract = DB.GetActiveContract(identifier)
    if not contract then
        FW.Notify(source, L('no_active_rental'), 'error')
        return { ok = false, msg = 'no_active_contract' }
    end

    local engineHealth = data and data.engineHealth or 1000
    local bodyHealth   = data and data.bodyHealth or 1000
    local fuelLevel    = data and data.fuelLevel or 100
    local isDestroyed  = data and data.isDestroyed or false
    local wheelsOk     = data and data.wheelsIntact or true

    local scan = {
        engine  = math.floor(math.max(0, engineHealth) / 10),
        body    = math.floor(math.max(0, bodyHealth) / 10),
        fuel    = math.floor(math.max(0, fuelLevel)),
        wheels  = wheelsOk and 100 or 0,
    }

    local penalties = PR.CalculatePenalties(contract, engineHealth, bodyHealth, fuelLevel, isDestroyed)
    local totalPen = PR.TotalPenalties(penalties)

    if not wheelsOk and not isDestroyed then
        penalties.wheels = 200
        totalPen = totalPen + 200
    end

    local refund = math.max(0, contract.deposit - totalPen)
    local extraCharge = math.max(0, totalPen - contract.deposit)

    local payMethod = PR.ResolvePayment(contract.payment_method)

    if refund > 0 then FW.AddMoney(source, refund, payMethod) end
    if extraCharge > 0 then FW.RemoveMoney(source, extraCharge, payMethod) end

    DB.UpdateContractStatus(contract.id, 'returned')
    if contract.location_id and contract.vehicle_model then
        DB.RestoreFleetStock(contract.location_id, contract.vehicle_model)
    end
    DB.CreateHistory({
        contract_id = contract.id, contract_num = contract.contract_num or '',
        identifier = identifier, vehicle_model = contract.vehicle_model,
        plate = contract.plate, penalties = penalties, scan = scan,
        total_penalties = totalPen, refunded_deposit = refund,
    })

    FW.RemoveItem(source, 'contract', 1)

    if totalPen > 0 then FW.Notify(source, L('return_penalties', tostring(totalPen)), 'warning') end
    FW.Notify(source, L('deposit_refunded', tostring(refund)), 'success')
    Webhook.Return(identifier, contract.vehicle_model, contract.plate, tostring(totalPen), tostring(refund))
    RefreshCache()

    return {
        ok = true, penalties = penalties, scan = scan,
        totalPen = totalPen, refund = refund, extraCharge = extraCharge,
        contractNum = contract.contract_num, deposit = contract.deposit,
    }
end)


lib.callback.register('perfect_rentals:extend', function(source, data)
    if not RateCheck(source, 'extend') then return { ok = false } end
    local identifier = FW.GetIdentifier(source)
    if not identifier then return { ok = false } end
    local contract = DB.GetActiveContract(identifier)
    if not contract then return { ok = false, msg = 'no_contract' } end
    if not data or not data.duration then return { ok = false } end
    if not PR.IsValidDuration(data.duration) then return { ok = false } end

    local payMethod = PR.ResolvePayment(data.payment or contract.payment_method)

    local vehicle
    if contract.location_id then
        vehicle = select(1, DB.GetVehicleForLocation(contract.location_id, contract.vehicle_model))
    end
    if not vehicle then
        vehicle = DB.GetVehicle(contract.vehicle_model)
    end
    if not vehicle then return { ok = false } end

    local price = PR.CalculatePrice(vehicle.price_per_day, data.duration, contract.insurance, contract.fuel_policy, false)
    if not price then return { ok = false } end

    if FW.GetMoney(source, payMethod) < price.total then
        FW.Notify(source, L('not_enough_money'), 'error')
        return { ok = false, msg = 'not_enough_money' }
    end

    if not FW.RemoveMoney(source, price.total, payMethod) then return { ok = false } end

    local newEnd = contract.end_ts + (data.duration * 60 * 1000)
    DB.ExtendContract(contract.id, newEnd, contract.price_total + price.total)
    FW.Notify(source, L('extend_success'), 'success')
    return { ok = true, newEndTs = newEnd, cost = price.total, serverTime = os.time() * 1000 }
end)


RegisterCommand('rentaladmin', function(source)
    if not FW.IsAdmin(source) then
        FW.Notify(source, L('admin_access_denied'), 'error')
        return
    end
    TriggerClientEvent('perfect_rentals:openAdminPanel', source)
end, false)

RegisterCommand('location', function(source)
    local identifier = FW.GetIdentifier(source)
    if not identifier then return end
    local contract = DB.GetActiveContract(identifier)
    if not contract then
        FW.Notify(source, L('no_active_rental'), 'info')
        return
    end
    contract.serverTime = os.time() * 1000
    TriggerClientEvent('perfect_rentals:openLocationCmd', source, contract)
end, false)


lib.callback.register('perfect_rentals:admin:getAll', function(source)
    if not FW.IsAdmin(source) then return nil end
    return {
        vehicles = DB.AdminGetAllVehicles(),
        locations = DB.AdminGetAllLocations(),
        contracts = DB.GetAllActiveContracts(),
    }
end)

lib.callback.register('perfect_rentals:admin:saveVehicle', function(source, data)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not data then return { ok = false } end
    if data.id then DB.AdminUpdateVehicle(data.id, data)
    else DB.AdminCreateVehicle(data) end
    RefreshCache()
    Webhook.AdminAction(FW.GetIdentifier(source) or tostring(source), 'saveVehicle', data.model or '?')
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:deleteVehicle', function(source, id)
    if not FW.IsAdmin(source) then return { ok = false } end
    DB.AdminDeleteVehicle(id)
    RefreshCache()
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:forceReturn', function(source, contractId)
    if not FW.IsAdmin(source) then return { ok = false } end
    local contract = DB.GetActiveContractById(contractId)
    if not contract then return { ok = false } end

    DB.UpdateContractStatus(contract.id, 'forced')
    if contract.location_id and contract.vehicle_model then
        DB.RestoreFleetStock(contract.location_id, contract.vehicle_model)
    end
    DB.CreateHistory({
        contract_id = contract.id, contract_num = contract.contract_num or '',
        identifier = contract.identifier, vehicle_model = contract.vehicle_model,
        plate = contract.plate, penalties = { admin_forced = true },
        total_penalties = 0, refunded_deposit = contract.deposit,
    })

    for _, pid in ipairs(GetPlayers()) do
        if FW.GetIdentifier(tonumber(pid)) == contract.identifier then
            local t = tonumber(pid)
            FW.AddMoney(t, contract.deposit, 'bank')
            FW.RemoveItem(t, 'contract', 1)
            FW.Notify(t, L('admin_force_return', tostring(contract.id)), 'warning')
            TriggerClientEvent('perfect_rentals:forceDeleteVehicle', t, contract.plate)
            break
        end
    end

    Webhook.AdminAction(FW.GetIdentifier(source) or tostring(source), 'forceReturn', '#' .. contractId)
    RefreshCache()
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:refund', function(source, contractId, amount)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not amount or amount <= 0 then return { ok = false } end
    local rows = MySQL.query.await('SELECT * FROM rentals_contracts WHERE id = ? LIMIT 1', { contractId })
    local contract = rows and rows[1] or nil
    if not contract then return { ok = false } end

    for _, pid in ipairs(GetPlayers()) do
        if FW.GetIdentifier(tonumber(pid)) == contract.identifier then
            FW.AddMoney(tonumber(pid), amount, 'bank')
            FW.Notify(tonumber(pid), L('admin_refund', tostring(amount)), 'success')
            break
        end
    end
    Webhook.AdminAction(FW.GetIdentifier(source) or tostring(source), 'refund', '$' .. amount .. ' → #' .. contractId)
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:saveLocation', function(source, data)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not data or not data.name or not data.coords then return { ok = false, msg = 'missing_data' } end

    if not data.coords.x or not data.coords.y or not data.coords.z then
        return { ok = false, msg = 'invalid_coords' }
    end
    if not data.spawnpoints or #data.spawnpoints == 0 then
        data.spawnpoints = { { x = data.coords.x + 3, y = data.coords.y, z = data.coords.z, h = data.coords.h or 0 } }
    end

    if data.id then
        DB.AdminUpdateLocation(data.id, data)
    else
        data.id = DB.AdminCreateLocation(data)
    end

    RefreshCache()
    TriggerClientEvent('perfect_rentals:refreshLocations', -1)
    Webhook.AdminAction(FW.GetIdentifier(source) or tostring(source), 'saveLocation', data.name or '?')
    return { ok = true, id = data.id }
end)

lib.callback.register('perfect_rentals:admin:deleteLocation', function(source, locationId, action)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not locationId then return { ok = false } end
    action = action or 'deactivate'
    if action == 'delete' then
        DB.AdminHardDeleteLocation(locationId)
    else
        DB.AdminDeactivateLocation(locationId)
    end
    RefreshCache()
    TriggerClientEvent('perfect_rentals:refreshLocations', -1)
    Webhook.AdminAction(FW.GetIdentifier(source) or tostring(source), action == 'delete' and 'hardDeleteLocation' or 'deactivateLocation', '#' .. tostring(locationId))
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:getLocationVehicles', function(source, locationId)
    if not FW.IsAdmin(source) then return nil end
    return {
        assigned = DB.AdminGetLocationVehicles(locationId),
        allVehicles = DB.AdminGetAllVehicles(),
    }
end)

lib.callback.register('perfect_rentals:admin:setLocationVehicle', function(source, data)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not data or not data.locationId or not data.vehicleId then return { ok = false } end
    DB.AdminSetLocationVehicle(data.locationId, data.vehicleId, data.enabled ~= false,
        data.overridePrice, data.overrideDeposit, data.stockOverride, data.sortOrder)
    RefreshCache()
    return { ok = true }
end)

lib.callback.register('perfect_rentals:admin:removeLocationVehicle', function(source, data)
    if not FW.IsAdmin(source) then return { ok = false } end
    if not data or not data.locationId or not data.vehicleId then return { ok = false } end
    DB.AdminRemoveLocationVehicle(data.locationId, data.vehicleId)
    RefreshCache()
    return { ok = true }
end)


CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time() * 1000
        local contracts = DB.GetAllActiveContracts()
        if contracts then
            for _, c in ipairs(contracts) do
                if c.end_ts < now then
                    local grace = (Config.Penalties.lateGracePeriod or 5) * 60 * 1000
                    if (now - c.end_ts) > (grace * 12) then
                        DB.UpdateContractStatus(c.id, 'expired')
                        if c.location_id and c.vehicle_model then
                            DB.RestoreFleetStock(c.location_id, c.vehicle_model)
                        end
                        DB.CreateHistory({
                            contract_id = c.id, contract_num = c.contract_num or '',
                            identifier = c.identifier, vehicle_model = c.vehicle_model,
                            plate = c.plate, penalties = { expired = true },
                            total_penalties = c.deposit, refunded_deposit = 0,
                        })
                    else
                        for _, pid in ipairs(GetPlayers()) do
                            if FW.GetIdentifier(tonumber(pid)) == c.identifier then
                                FW.Notify(tonumber(pid), L('rental_expired'), 'warning')
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)


exports('HasActiveRental', function(source)
    local id = FW.GetIdentifier(source)
    if not id then return false end
    local c = DB.GetActiveContract(id)
    return c ~= nil, c
end)

exports('GetActiveContract', function(source)
    local id = FW.GetIdentifier(source)
    if not id then return nil end
    return DB.GetActiveContract(id)
end)

exports('ForceReturn', function(contractId)
    local c = DB.GetActiveContractById(contractId)
    if not c then return false end
    DB.UpdateContractStatus(c.id, 'forced')
    return true
end)


local function RegisterContractItem()
    local function onUse(source)
        local id = FW.GetIdentifier(source)
        if not id then return end
        local c = DB.GetActiveContract(id)
        if not c then
            FW.Notify(source, L('no_active_rental'), 'error')
            return
        end
        local vehicle = DB.GetVehicle(c.vehicle_model)
        local vehLabel = vehicle and vehicle.label or c.vehicle_model
        local playerName = c.player_name ~= '' and c.player_name or GetPlayerName(source)
        local endDate = os.date('%d/%m/%Y %H:%M', math.floor(c.end_ts / 1000))

        TriggerClientEvent('perfect_rentals:showContract', source, {
            playerName  = playerName,
            vehicle     = vehLabel,
            plate       = c.plate,
            contractNum = c.contract_num,
            endDate     = endDate,
            insurance   = c.insurance,
        })
    end

    if Config.Framework == 'esx' and ESX then
        ESX.RegisterUsableItem('contract', function(source)
            onUse(source)
        end)
    elseif PR.UsesQBFramework() and QBCore and QBCore.Functions then
        -- API officielle QBCore / Qbox bridge : CreateUseableItem (double « e », cf. qb-core & qbx_core).
        local reg = QBCore.Functions.CreateUseableItem or QBCore.Functions.CreateUsableItem
        if reg then
            reg('contract', function(source)
                onUse(source)
            end)
        else
            print('^3[perfect_rentals]^0 QBCore: pas de CreateUseableItem — item contract non enregistré.')
        end
    end
end

CreateThread(function()
    Wait(3000)
    RegisterContractItem()
end)

RegisterNetEvent('perfect_rentals:contractShownToNearby', function(contractData)
    local source = source
    local playerName = GetPlayerName(source)
    local msg = playerName .. ' vous montre son contrat de location :\n' ..
        '📄 Contrat #' .. (contractData.contractNum or '?') .. '\n' ..
        '🚗 ' .. (contractData.vehicle or '?') .. ' [' .. (contractData.plate or '?') .. ']\n' ..
        '📅 Valide jusqu\'au ' .. (contractData.endDate or '?') .. '\n' ..
        '🛡️ Assurance : ' .. (contractData.insurance or 'none')

    local sCoords = GetEntityCoords(GetPlayerPed(source))
    for _, pid in ipairs(GetPlayers()) do
        local target = tonumber(pid)
        if target ~= source then
            local tCoords = GetEntityCoords(GetPlayerPed(target))
            if #(sCoords - tCoords) < 5.0 then
                TriggerClientEvent('perfect_rentals:seeContract', target, contractData, playerName)
            end
        end
    end
end)

print('^2[perfect_rentals]^0 Server module loaded.')
