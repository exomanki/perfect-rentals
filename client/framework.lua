CFW = {}

-- Réf. cores (arborescence locale) : resources/autres framework/[qbcore]/qb-core, [Qbox]/qbx_core
local framework = Config.Framework

local function isQBFamily()
    return framework == 'qbcore' or framework == 'qbox'
end

local function qbBridgeResourceStarted()
    return GetResourceState('qb-core') == 'started' or GetResourceState('qbx_core') == 'started'
end

local function tryLoadQBCore()
    local ok, obj = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    return (ok and obj) or nil
end

if framework == 'esx' then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
elseif isQBFamily() then
    if qbBridgeResourceStarted() then
        QBCore = tryLoadQBCore()
        if not QBCore then
            print('^1[perfect_rentals]^0 qbcore/qbox: GetCoreObject failed. Ensure qb-core or qbx_core is running.')
        end
    else
        print('^1[perfect_rentals]^0 qbcore/qbox but no qb-core / qbx_core resource started.')
    end
end

function CFW.GetPlayerData()
    if framework == 'esx' then
        if ESX then return ESX.GetPlayerData() end
        return {}
    elseif isQBFamily() and QBCore then
        return QBCore.Functions.GetPlayerData()
    end
    return {}
end

function CFW.Notify(msg, nType)
    nType = nType or 'info'
    local mode = PR.NotifyModeCanonical()

    if mode == 'custom' then
        local c = Config.NotificationCustom or {}
        if c.clientLocalEvent and c.clientLocalEvent ~= '' then
            TriggerEvent(c.clientLocalEvent, msg, nType)
            return
        end
        mode = 'framework'
    end

    if mode == 'framework' then
        if framework == 'esx' and ESX then
            ESX.ShowNotification(msg)
            return
        end
        if isQBFamily() and QBCore then
            QBCore.Functions.Notify(msg, nType)
            return
        end
        return
    end

    if mode == 'ox_lib' then
        if GetResourceState('ox_lib') == 'started' then
            lib.notify({ description = msg, type = nType })
            return
        end
        if framework == 'esx' and ESX then
            ESX.ShowNotification(msg)
            return
        end
        if isQBFamily() and QBCore then
            QBCore.Functions.Notify(msg, nType)
        end
        return
    end
end

function CFW.GetFuelLevel(vehicle)
    if GetResourceState('ox_fuel') == 'started' then
        return exports['ox_fuel']:GetFuel(vehicle)
    elseif GetResourceState('LegacyFuel') == 'started' then
        return exports['LegacyFuel']:GetFuel(vehicle)
    end
    return GetVehicleFuelLevel(vehicle)
end

function CFW.SetFuelLevel(vehicle, level)
    if GetResourceState('ox_fuel') == 'started' then
        exports['ox_fuel']:SetFuel(vehicle, level)
    elseif GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, level)
    else
        SetVehicleFuelLevel(vehicle, level + 0.0)
    end
end
