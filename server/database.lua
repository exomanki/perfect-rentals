DB = {}

function DB.GetVehicles()
    return MySQL.query.await('SELECT * FROM rentals_vehicles WHERE enabled = 1 ORDER BY category, label')
end

function DB.GetVehicle(model)
    local rows = MySQL.query.await('SELECT * FROM rentals_vehicles WHERE model = ? AND enabled = 1 LIMIT 1', { model })
    return rows and rows[1] or nil
end

function DB.GetVehicleForLocation(locationId, model)
    if not locationId or not model then return nil end
    local hasFleet = DB.HasLocationVehicles(locationId)
    if hasFleet then
        local rows = MySQL.query.await([[
            SELECT v.*,
                   lv.override_price,
                   lv.override_deposit,
                   lv.stock_override,
                   lv.vehicle_id AS lv_vehicle_id
            FROM rentals_location_vehicles lv
            JOIN rentals_vehicles v ON v.id = lv.vehicle_id
            WHERE lv.location_id = ? AND v.model = ? AND lv.enabled = 1 AND v.enabled = 1
            LIMIT 1
        ]], { locationId, model })
        if not rows or not rows[1] then return nil end
        local r = rows[1]
        local m = {}
        for k, v in pairs(r) do m[k] = v end
        if r.override_price then m.price_per_day = r.override_price end
        if r.override_deposit then m.deposit = r.override_deposit end
        local stockScope
        if r.stock_override ~= nil then
            m.stock = r.stock_override
            stockScope = 'location_override'
        else
            m.stock = r.stock
            stockScope = (r.stock ~= nil and r.stock >= 0) and 'global_at_location' or 'unlimited'
        end
        if m.stock ~= nil and m.stock < 0 then stockScope = 'unlimited' end

        local meta = {
            locationId           = locationId,
            lvVehicleId          = r.lv_vehicle_id,
            stockScope           = stockScope,
        }
        return m, meta
    end

    local v = DB.GetVehicle(model)
    if not v then return nil end
    local stockScope = (v.stock ~= nil and v.stock >= 0) and 'global' or 'unlimited'
    if v.stock ~= nil and v.stock < 0 then stockScope = 'unlimited' end
    return v, {
        stockScope           = stockScope,
    }
end

function DB.TryConsumeFleetStock(locationId, mergedVehicle, meta)
    if not mergedVehicle then return false end
    if not meta or meta.stockScope == 'unlimited' then return true end
    if meta.stockScope == 'location_override' then
        local affected = MySQL.update.await([[
            UPDATE rentals_location_vehicles
            SET stock_override = stock_override - 1
            WHERE location_id = ?
              AND vehicle_id = ?
              AND stock_override IS NOT NULL AND stock_override > 0
        ]], { locationId, meta.lvVehicleId })
        return affected and affected > 0
    end
    if meta.stockScope == 'global_at_location' or meta.stockScope == 'global' then
        local gid = mergedVehicle.id
        if not gid then return false end
        local affected = MySQL.update.await(
            [[UPDATE rentals_vehicles SET stock = stock - 1 WHERE id = ? AND stock > 0]],
            { gid })
        return affected and affected > 0
    end
    return true
end

function DB.RestoreFleetStock(locationId, model)
    local veh, meta = DB.GetVehicleForLocation(locationId, model)
    if not veh or not meta or meta.stockScope == 'unlimited' then return end
    if meta.stockScope == 'location_override' then
        MySQL.update.await([[
            UPDATE rentals_location_vehicles
            SET stock_override = stock_override + 1
            WHERE location_id = ? AND vehicle_id = ?
              AND stock_override IS NOT NULL]], { locationId, meta.lvVehicleId })
    elseif meta.stockScope == 'global_at_location' or meta.stockScope == 'global' then
        local rows = MySQL.query.await('SELECT id FROM rentals_vehicles WHERE model = ? LIMIT 1', { model })
        local gid = rows and rows[1] and rows[1].id
        if gid then
            MySQL.update.await('UPDATE rentals_vehicles SET stock = stock + 1 WHERE id = ? AND stock >= 0', { gid })
        end
    end
end

function DB.GetLocations()
    return MySQL.query.await('SELECT * FROM rentals_locations WHERE enabled = 1')
end

function DB.GetLocation(id)
    local rows = MySQL.query.await('SELECT * FROM rentals_locations WHERE id = ? AND enabled = 1 LIMIT 1', { id })
    return rows and rows[1] or nil
end

function DB.GetLocationVehicles(locationId)
    local rows = MySQL.query.await([[
        SELECT v.*, lv.override_price, lv.override_deposit, lv.stock_override, lv.sort_order
        FROM rentals_location_vehicles lv
        JOIN rentals_vehicles v ON v.id = lv.vehicle_id
        WHERE lv.location_id = ? AND lv.enabled = 1 AND v.enabled = 1
        ORDER BY lv.sort_order ASC, v.label ASC
    ]], { locationId })
    if rows then
        for i, r in ipairs(rows) do
            if r.override_price then rows[i].price_per_day = r.override_price end
            if r.override_deposit then rows[i].deposit = r.override_deposit end
            if r.stock_override then rows[i].stock = r.stock_override end
        end
    end
    return rows
end

function DB.HasLocationVehicles(locationId)
    local rows = MySQL.query.await('SELECT COUNT(*) as cnt FROM rentals_location_vehicles WHERE location_id = ? AND enabled = 1', { locationId })
    return rows and rows[1] and rows[1].cnt > 0
end

function DB.PlateExists(plate)
    local rows = MySQL.query.await('SELECT 1 FROM rentals_contracts WHERE plate = ? AND status = ? LIMIT 1', { plate, 'active' })
    return rows and #rows > 0
end

function DB.GenerateContractNum()
    local num = 'PR-' .. os.date('%y%m') .. '-' .. string.format('%04d', math.random(1, 9999))
    return num
end

function DB.CreateContract(data)
    return MySQL.insert.await([[
        INSERT INTO rentals_contracts
            (contract_num, identifier, player_name, location_id, vehicle_model, plate, token, start_ts, end_ts, price_total, deposit, insurance, fuel_policy, delivery, payment_method, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active')
    ]], {
        data.contract_num, data.identifier, data.player_name or '', data.location_id,
        data.vehicle_model, data.plate, data.token, data.start_ts, data.end_ts,
        data.price_total, data.deposit, data.insurance, data.fuel_policy, data.delivery and 1 or 0,
        data.payment_method or 'bank',
    })
end

function DB.GetActiveContract(identifier)
    local rows = MySQL.query.await('SELECT * FROM rentals_contracts WHERE identifier = ? AND status = ? LIMIT 1', { identifier, 'active' })
    return rows and rows[1] or nil
end

function DB.GetActiveContractByToken(token)
    local rows = MySQL.query.await('SELECT * FROM rentals_contracts WHERE token = ? AND status = ? LIMIT 1', { token, 'active' })
    return rows and rows[1] or nil
end

function DB.GetActiveContractById(id)
    local rows = MySQL.query.await('SELECT * FROM rentals_contracts WHERE id = ? AND status = ? LIMIT 1', { id, 'active' })
    return rows and rows[1] or nil
end

function DB.UpdateContractStatus(id, status)
    MySQL.update.await('UPDATE rentals_contracts SET status = ? WHERE id = ?', { status, id })
end

function DB.UpdateContractNetId(id, netid)
    MySQL.update.await('UPDATE rentals_contracts SET vehicle_netid = ? WHERE id = ?', { netid, id })
end

function DB.ExtendContract(id, newEndTs, newPrice)
    MySQL.update.await('UPDATE rentals_contracts SET end_ts = ?, price_total = ? WHERE id = ?', { newEndTs, newPrice, id })
end

function DB.IncrementPopularity(model)
    MySQL.update.await('UPDATE rentals_vehicles SET popularity = popularity + 1 WHERE model = ?', { model })
end

function DB.CreateHistory(data)
    MySQL.insert.await([[
        INSERT INTO rentals_history
            (contract_id, contract_num, identifier, vehicle_model, plate, penalties_json, scan_json, total_penalties, refunded_deposit, returned_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    ]], {
        data.contract_id, data.contract_num or '', data.identifier, data.vehicle_model, data.plate,
        json.encode(data.penalties), json.encode(data.scan or {}),
        data.total_penalties, data.refunded_deposit
    })
end

function DB.GetHistory(identifier)
    return MySQL.query.await([[
        SELECT h.*, c.start_ts, c.end_ts, c.insurance, c.fuel_policy, c.deposit, c.price_total, c.player_name
        FROM rentals_history h
        JOIN rentals_contracts c ON c.id = h.contract_id
        WHERE h.identifier = ?
        ORDER BY h.returned_at DESC LIMIT 50
    ]], { identifier })
end

function DB.GetAllActiveContracts()
    return MySQL.query.await('SELECT * FROM rentals_contracts WHERE status = ? ORDER BY created_at DESC', { 'active' })
end

function DB.AdminGetAllVehicles()
    return MySQL.query.await('SELECT * FROM rentals_vehicles ORDER BY category, label')
end

function DB.AdminCreateVehicle(data)
    return MySQL.insert.await([[
        INSERT INTO rentals_vehicles (model, label, category, tags, price_per_day, deposit, image_url, seats, trunk, speed, handling, braking, enabled, stock)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.model, data.label, data.category or 'sedan', data.tags or '',
        data.price_per_day or 500, data.deposit or 1000, data.image_url or '',
        data.seats or 4, data.trunk or 40, data.speed or 50, data.handling or 50, data.braking or 50,
        data.enabled and 1 or 0, data.stock or -1
    })
end

function DB.AdminUpdateVehicle(id, data)
    MySQL.update.await([[
        UPDATE rentals_vehicles SET
            label=?, category=?, tags=?, price_per_day=?, deposit=?,
            image_url=?, seats=?, trunk=?, speed=?, handling=?, braking=?, enabled=?, stock=?
        WHERE id=?
    ]], {
        data.label, data.category, data.tags or '', data.price_per_day, data.deposit,
        data.image_url or '', data.seats, data.trunk, data.speed, data.handling or 50, data.braking or 50,
        data.enabled and 1 or 0, data.stock, id
    })
end

function DB.AdminDeleteVehicle(id)
    MySQL.update.await('UPDATE rentals_vehicles SET enabled = 0 WHERE id = ?', { id })
end

function DB.AdminGetAllLocations()
    return MySQL.query.await('SELECT * FROM rentals_locations ORDER BY name')
end

function DB.AdminCreateLocation(data)
    return MySQL.insert.await([[
        INSERT INTO rentals_locations (name, coords_json, spawnpoints_json, return_point_json, showroom_json,
            blip_sprite, blip_color, blip_scale, ped_model, enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        data.name, json.encode(data.coords), json.encode(data.spawnpoints),
        data.return_point and json.encode(data.return_point) or nil,
        data.showroom and json.encode(data.showroom) or nil,
        data.blip_sprite or 226, data.blip_color or 3, data.blip_scale or 0.7,
        data.ped_model or 's_m_m_autoshop_02', data.enabled and 1 or 0,
    })
end

function DB.AdminUpdateLocation(id, data)
    MySQL.update.await([[
        UPDATE rentals_locations SET
            name=?, coords_json=?, spawnpoints_json=?, return_point_json=?, showroom_json=?,
            blip_sprite=?, blip_color=?, blip_scale=?, ped_model=?, enabled=?
        WHERE id=?
    ]], {
        data.name, json.encode(data.coords), json.encode(data.spawnpoints),
        data.return_point and json.encode(data.return_point) or nil,
        data.showroom and json.encode(data.showroom) or nil,
        data.blip_sprite or 226, data.blip_color or 3, data.blip_scale or 0.7,
        data.ped_model or 's_m_m_autoshop_02', data.enabled and 1 or 0, id,
    })
end

function DB.AdminDeactivateLocation(id)
    MySQL.update.await('UPDATE rentals_locations SET enabled = 0 WHERE id = ?', { id })
end

function DB.AdminHardDeleteLocation(id)
    MySQL.update.await('DELETE FROM rentals_location_vehicles WHERE location_id = ?', { id })
    MySQL.update.await('DELETE FROM rentals_locations WHERE id = ?', { id })
end

function DB.AdminDeleteLocation(id)
    MySQL.update.await('UPDATE rentals_locations SET enabled = 0 WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM rentals_location_vehicles WHERE location_id = ?', { id })
end

function DB.AdminGetLocationVehicles(locationId)
    return MySQL.query.await([[
        SELECT lv.*, v.model, v.label, v.category, v.price_per_day AS global_price, v.deposit AS global_deposit, v.image_url
        FROM rentals_location_vehicles lv
        JOIN rentals_vehicles v ON v.id = lv.vehicle_id
        WHERE lv.location_id = ?
        ORDER BY lv.sort_order ASC, v.label ASC
    ]], { locationId })
end

function DB.AdminSetLocationVehicle(locationId, vehicleId, enabled, overridePrice, overrideDeposit, stockOverride, sortOrder)
    MySQL.query.await([[
        INSERT INTO rentals_location_vehicles (location_id, vehicle_id, enabled, override_price, override_deposit, stock_override, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE enabled=VALUES(enabled), override_price=VALUES(override_price),
            override_deposit=VALUES(override_deposit), stock_override=VALUES(stock_override), sort_order=VALUES(sort_order)
    ]], { locationId, vehicleId, enabled and 1 or 0, overridePrice, overrideDeposit, stockOverride, sortOrder or 0 })
end

function DB.AdminRemoveLocationVehicle(locationId, vehicleId)
    MySQL.update.await('DELETE FROM rentals_location_vehicles WHERE location_id = ? AND vehicle_id = ?', { locationId, vehicleId })
end
