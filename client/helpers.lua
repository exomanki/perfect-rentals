rentalVehicle = nil
activeToken = nil
deliveryBlip = nil
lastScanData = nil

local serverTimeOffset = 0

function GetServerTime()
    return GetGameTimer() + serverTimeOffset
end

function SyncServerTime(ts)
    if ts and ts > 0 then serverTimeOffset = ts - GetGameTimer() end
end

--- Temps restant lisible pour le HUD / affichages (millisecondes).
function FormatRentalRemainMs(remMs)
    if remMs <= 0 then return L('timer_hud_expired') end
    local totalSec = math.floor(remMs / 1000)
    local days = math.floor(totalSec / 86400)
    totalSec = totalSec % 86400
    local h = math.floor(totalSec / 3600)
    local m = math.floor((totalSec % 3600) / 60)
    local s = totalSec % 60
    if days >= 1 then
        return string.format('%d %s · %d %s %02d %s',
            days, L('ui_days_short'), h, L('ui_hours_short'), m, L('ui_minutes_short'))
    elseif h >= 1 then
        return string.format('%d %s %02d %s %02d %s',
            h, L('ui_hours_short'), m, L('ui_minutes_short'), s, L('ui_timer_seconds_unit'))
    elseif m >= 1 then
        return string.format('%d %s %02d %s',
            m, L('ui_minutes_short'), s, L('ui_timer_seconds_unit'))
    end
    return string.format('%d %s', s, L('ui_timer_seconds_unit'))
end

function PlayerInRentalVehicle()
    if not rentalVehicle or rentalVehicle == 0 or not DoesEntityExist(rentalVehicle) then
        return false
    end
    local ped = PlayerPedId()
    return GetVehiclePedIsIn(ped, false) == rentalVehicle
end

function LoadAnimDict(dict)
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 50 do Wait(100) t = t + 1 end
    return HasAnimDictLoaded(dict)
end

function PlayAnim(ped, dict, anim, dur, flag)
    if LoadAnimDict(dict) then TaskPlayAnim(ped, dict, anim, 8.0, -8.0, dur or 3000, flag or 0, 0, false, false, false) end
end

function StopAnim(ped, dict, anim)
    StopAnimTask(ped, dict, anim, 1.0)
    RemoveAnimDict(dict)
end

function FaceEntity(ped, tc)
    local p = GetEntityCoords(ped)
    local h = math.deg(math.atan(tc.x - p.x, tc.y - p.y))
    if h < 0 then h = h + 360.0 end
    SetEntityHeading(ped, h)
    Wait(200)
end

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.30, 0.30)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(sx, sy)
end
