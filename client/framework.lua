CFW = {}

local framework = Config.Framework

if framework == 'esx' then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
elseif framework == 'qbcore' then
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
end

function CFW.GetPlayerData()
    if framework == 'esx' then
        return ESX.GetPlayerData()
    elseif framework == 'qbcore' then
        return QBCore.Functions.GetPlayerData()
    end
    return {}
end

function CFW.Notify(msg, nType)
    nType = nType or 'info'
    if GetResourceState('ox_lib') == 'started' then
        lib.notify({ description = msg, type = nType })
    elseif framework == 'esx' then
        ESX.ShowNotification(msg)
    elseif framework == 'qbcore' then
        QBCore.Functions.Notify(msg, nType)
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
