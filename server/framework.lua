FW = {}
--[[
  Références frameworks (copies locales hors chargement automatique — comparer APIs si besoin) :
  • resources/autres framework/[qbcore]/qb-core
  • resources/autres framework/[Qbox]/qbx_core (pont qb-core, export GetCoreObject)
  Casier « usable item » QBCore / Qbox : QBCore.Functions.CreateUseableItem (orthographe « Useable », voir qb-core/server/functions.lua et qbx_core bridge).
]]

local framework = Config.Framework
local fwObj = nil

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

--- Joueur QB (nil si core indisponible).
local function qbPlayer(src)
    if not QBCore then return nil end
    return QBCore.Functions.GetPlayer(src)
end

if framework == 'esx' then
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
        fwObj = ESX
    end
elseif isQBFamily() then
    if qbBridgeResourceStarted() then
        QBCore = tryLoadQBCore()
        fwObj = QBCore
        if not QBCore then
            print('^1[perfect_rentals]^0 qbcore/qbox: GetCoreObject failed. Ensure qb-core or qbx_core is running.')
        end
    else
        print('^1[perfect_rentals]^0 qbcore/qbox: no qb-core / qbx_core resource started.')
    end
end

function FW.GetIdentifier(source)
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif isQBFamily() then
        local player = qbPlayer(source)
        return player and player.PlayerData.citizenid or nil
    else
        for _, id in ipairs(GetPlayerIdentifiers(source)) do
            if string.find(id, 'license:') then return id end
        end
        return nil
    end
end

function FW.GetMoney(source, account)
    account = account or 'bank'
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return 0 end
        if account == 'cash' then
            return xPlayer.getMoney()
        else
            return xPlayer.getAccount('bank').money
        end
    elseif isQBFamily() then
        local player = qbPlayer(source)
        if not player then return 0 end
        if account == 'cash' then
            return player.PlayerData.money.cash or 0
        else
            return player.PlayerData.money.bank or 0
        end
    else
        return 999999
    end
end

function FW.RemoveMoney(source, amount, account)
    account = account or 'bank'
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        if account == 'cash' then
            if xPlayer.getMoney() < amount then return false end
            xPlayer.removeMoney(amount)
        else
            if xPlayer.getAccount('bank').money < amount then return false end
            xPlayer.removeAccountMoney('bank', amount)
        end
        return true
    elseif isQBFamily() then
        local player = qbPlayer(source)
        if not player then return false end
        local moneyType = account == 'cash' and 'cash' or 'bank'
        if (player.PlayerData.money[moneyType] or 0) < amount then return false end
        player.Functions.RemoveMoney(moneyType, amount, 'perfect_rentals')
        return true
    else
        return true
    end
end

function FW.AddMoney(source, amount, account)
    account = account or 'bank'
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        if account == 'cash' then
            xPlayer.addMoney(amount)
        else
            xPlayer.addAccountMoney('bank', amount)
        end
        return true
    elseif isQBFamily() then
        local player = qbPlayer(source)
        if not player then return false end
        local moneyType = account == 'cash' and 'cash' or 'bank'
        player.Functions.AddMoney(moneyType, amount, 'perfect_rentals')
        return true
    else
        return true
    end
end

function FW.IsAdmin(source)
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then return false end
        local group = xPlayer.getGroup()
        for _, g in ipairs(Config.AdminGroups) do
            if group == g then return true end
        end
    elseif isQBFamily() then
        if QBCore then
            for _, g in ipairs(Config.AdminGroups) do
                if QBCore.Functions.HasPermission(source, g) then return true end
            end
        end
    else
        for _, g in ipairs(Config.AdminGroups) do
            if IsPlayerAceAllowed(source, 'group.' .. g) then return true end
        end
    end
    for _, job in ipairs(Config.AdminJobs) do
        if FW.GetJob(source) == job then return true end
    end
    return false
end

function FW.GetJob(source)
    if framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.getJob().name or 'unemployed'
    elseif isQBFamily() then
        local player = qbPlayer(source)
        return player and player.PlayerData.job.name or 'unemployed'
    end
    return 'unemployed'
end

function FW.AddItem(source, item, count, metadata)
    count = count or 1
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:AddItem(source, item, count, metadata)
    elseif GetResourceState('qs-inventory') == 'started' then
        return exports['qs-inventory']:AddItem(source, item, count, nil, metadata)
    elseif framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then xPlayer.addInventoryItem(item, count) return true end
    elseif isQBFamily() then
        local player = qbPlayer(source)
        if player then return player.Functions.AddItem(item, count, nil, metadata) end
    end
    return false
end

function FW.RemoveItem(source, item, count)
    count = count or 1
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:RemoveItem(source, item, count)
    elseif GetResourceState('qs-inventory') == 'started' then
        return exports['qs-inventory']:RemoveItem(source, item, count)
    elseif framework == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then xPlayer.removeInventoryItem(item, count) return true end
    elseif isQBFamily() then
        local player = qbPlayer(source)
        if player then return player.Functions.RemoveItem(item, count) end
    end
    return false
end

function FW.Notify(source, msg, nType)
    nType = nType or 'info'
    local mode = PR.NotifyModeCanonical()

    if mode == 'custom' then
        local evt = Config.NotificationCustom and Config.NotificationCustom.serverToClientEvent
        if evt and evt ~= '' then
            TriggerClientEvent(evt, source, msg, nType)
            return
        end
        mode = 'framework'
    end

    if mode == 'framework' then
        if framework == 'esx' then
            TriggerClientEvent('esx:showNotification', source, msg)
            return
        elseif isQBFamily() then
            TriggerClientEvent('QBCore:Notify', source, msg, nType)
            return
        end
        return
    end

    if mode == 'ox_lib' then
        if GetResourceState('ox_lib') == 'started' then
            TriggerClientEvent('ox_lib:notify', source, { description = msg, type = nType })
            return
        end
        if framework == 'esx' then
            TriggerClientEvent('esx:showNotification', source, msg)
        elseif isQBFamily() then
            TriggerClientEvent('QBCore:Notify', source, msg, nType)
        end
        return
    end
end
