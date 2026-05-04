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
