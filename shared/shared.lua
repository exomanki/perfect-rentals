PR = PR or {}

PR.Categories = {
    compact     = { label = 'Compact',     icon = 'car' },
    sedan       = { label = 'Berline',     icon = 'car-side' },
    suv         = { label = 'SUV',         icon = 'truck' },
    sport       = { label = 'Sport',       icon = 'flag-checkered' },
    super       = { label = 'Super',       icon = 'rocket' },
    utilitaire  = { label = 'Utilitaire',  icon = 'truck-pickup' },
}

function PR.GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums  = '0123456789'
    local plate = Config.PlatePrefix
    for _ = 1, 3 do
        local i = math.random(1, #nums)
        plate = plate .. nums:sub(i, i)
    end
    for _ = 1, (8 - #plate) do
        local i = math.random(1, #chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate:sub(1, 8):upper()
end

function PR.GenerateToken()
    local hex = '0123456789abcdef'
    local token = ''
    for _ = 1, 64 do
        local i = math.random(1, #hex)
        token = token .. hex:sub(i, i)
    end
    return token
end

function PR.CalculatePrice(pricePerDay, durationMinutes, insurance, fuelPolicy, delivery)
    local durationConf = nil
    for _, d in ipairs(Config.Durations) do
        if d.minutes == durationMinutes then
            durationConf = d
            break
        end
    end
    if not durationConf then return nil end

    local basePrice = math.floor(pricePerDay * durationConf.multiplier)

    local insuranceConf = Config.Insurance[insurance]
    if not insuranceConf then return nil end
    local insuranceCost = math.floor(basePrice * insuranceConf.multiplier)

    local fuelCost = 0
    local fpConf = Config.FuelPolicies[fuelPolicy]
    if fpConf and fpConf.flatCost then
        fuelCost = fpConf.flatCost
    end

    local deliveryCost = 0
    if delivery then
        deliveryCost = Config.DeliveryCost
    end

    local total = basePrice + insuranceCost + fuelCost + deliveryCost
    return {
        base       = basePrice,
        insurance  = insuranceCost,
        fuel       = fuelCost,
        delivery   = deliveryCost,
        total      = total,
    }
end

function PR.CalculatePenalties(contract, engineHealth, bodyHealth, fuelLevel, isDestroyed)
    local now = os.time() * 1000
    local penalties = { late = 0, damage = 0, fuel = 0, destroyed = 0, wheels = 0 }
    local conf = Config.Penalties

    if isDestroyed then
        penalties.destroyed = math.floor(contract.deposit * conf.destroyedMultiplier)
        return penalties
    end

    local lateMs = now - contract.end_ts
    if lateMs > (conf.lateGracePeriod * 60 * 1000) then
        local lateMinutes = math.ceil(lateMs / 60000)
        penalties.late = lateMinutes * conf.latePerMinute
    end

    local insuranceConf = Config.Insurance[contract.insurance] or Config.Insurance.none
    local damageReduction = insuranceConf.damageReduction or 0

    local engineDmg = math.max(0, 1000 - engineHealth) / 10
    local bodyDmg   = math.max(0, 1000 - bodyHealth) / 10
    local totalDmg  = (engineDmg + bodyDmg) / 2
    local rawDamagePenalty = math.floor(totalDmg * conf.damagePerPercent)
    penalties.damage = math.floor(rawDamagePenalty * (1 - damageReduction))

    if contract.fuel_policy == 'full_to_full' then
        local missingFuel = math.max(0, 100 - fuelLevel)
        penalties.fuel = math.floor(missingFuel * conf.fuelPerPercent)
    end

    return penalties
end

function PR.TotalPenalties(p)
    return (p.late or 0) + (p.damage or 0) + (p.fuel or 0) + (p.destroyed or 0) + (p.wheels or 0)
end

function PR.IsValidDuration(minutes)
    for _, d in ipairs(Config.Durations) do
        if d.minutes == minutes then return true end
    end
    return false
end

function PR.IsValidInsurance(ins)
    return Config.Insurance[ins] ~= nil
end

function PR.IsValidFuelPolicy(fp)
    return Config.FuelPolicies[fp] ~= nil
end

function PR.IsPaymentAllowed(mode)
    local want = (mode == 'cash') and 'cash' or 'bank'
    for _, pm in ipairs(Config.PaymentMethods or { 'bank' }) do
        if pm == want then return true, want end
    end
    return false
end

function PR.ResolvePayment(mode)
    local allowed, canon = PR.IsPaymentAllowed(mode)
    if allowed then return canon end
    local methods = Config.PaymentMethods or { 'bank' }
    local fb = Config.DefaultPayment == 'cash' and 'cash' or 'bank'
    allowed, canon = PR.IsPaymentAllowed(fb)
    if allowed then return canon end
    local first = methods[1] or 'bank'
    return (first == 'cash') and 'cash' or 'bank'
end

local function bootstrapInsOrder()
    return { 'none', 'standard', 'premium' }
end

local function bootstrapFuelSortedKeys()
    local keys = {}
    for k in pairs(Config.FuelPolicies or {}) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function PR.NuiBootstrap()
    local localeTag = (Config.Locale == 'en') and 'en-US' or 'fr-FR'
    local durations = {}
    for _, d in ipairs(Config.Durations or {}) do
        durations[#durations + 1] = { minutes = d.minutes, label = L('dur_m' .. d.minutes) }
    end
    local quickExtend = {}
    for _, q in ipairs(Config.QuickExtend or {}) do
        quickExtend[#quickExtend + 1] = { minutes = q.minutes, label = L('qext_m' .. q.minutes) }
    end
    local insurance = {}
    for _, k in ipairs(bootstrapInsOrder()) do
        if Config.Insurance[k] then
            insurance[#insurance + 1] = {
                key = k,
                label = L('insurance_opt_' .. k),
            }
        end
    end
    local fuel = {}
    for _, k in ipairs(bootstrapFuelSortedKeys()) do
        local fv = Config.FuelPolicies[k]
        if fv then fuel[#fuel + 1] = { key = k, label = L('fuel_opt_' .. k) } end
    end
    local payment = {}
    for _, pk in ipairs(Config.PaymentMethods or { 'bank' }) do
        payment[#payment + 1] = {
            key = pk,
            label = pk == 'cash' and L('pay_cash') or L('pay_bank'),
        }
    end
    local categories = { all = L('cat_all') }
    for ck in pairs(PR.Categories or {}) do
        categories[ck] = L('category_' .. ck)
    end
    return {
        localeTag = localeTag,
        defaultPayment = (Config.DefaultPayment == 'cash' and 'cash' or 'bank'),
        durations = durations,
        quickExtend = quickExtend,
        insurance = insurance,
        fuel = fuel,
        payment = payment,
        categories = categories,
        locale = {
            expired = L('ui_expired'),
            minutes_short = L('ui_minutes_short'),
            hours_short = L('ui_hours_short'),
            days_short = L('ui_days_short'),
            timer_seconds_unit = L('ui_timer_seconds_unit'),
            nav_catalog = L('ui_nav_catalog'),
            nav_active = L('ui_nav_active'),
            nav_history = L('ui_nav_history'),
            search_ph = L('ui_search_ph'),
            sort_default = L('ui_sort_default'),
            sort_price_asc = L('ui_sort_price_asc'),
            sort_price_desc = L('ui_sort_price_desc'),
            sort_name = L('ui_sort_name'),
            sort_speed = L('ui_sort_speed'),
            cat_title = L('ui_cat_title'),
            detail_back = L('ui_detail_back'),
            showroom_3d = L('ui_showroom_3d'),
            sec_duration = L('ui_sec_duration'),
            sec_insurance = L('ui_sec_insurance'),
            sec_fuel = L('ui_sec_fuel'),
            sec_payment = L('ui_sec_payment'),
            select_duration = L('ui_select_duration'),
            price_err = L('ui_price_err'),
            price_base = L('ui_price_base'),
            price_insurance = L('ui_price_insurance'),
            price_fuel_flat = L('ui_price_fuel_flat'),
            price_delivery = L('ui_price_delivery'),
            price_deposit = L('ui_price_deposit'),
            price_total = L('ui_price_total'),
            per_day = L('ui_per_day'),
            stat_speed = L('ui_stat_speed'),
            stat_handling = L('ui_stat_handling'),
            stat_braking = L('ui_stat_braking'),
            stat_seats = L('ui_stat_seats'),
            stat_trunk = L('ui_stat_trunk'),
            stat_deposit = L('ui_stat_deposit'),
            cat_empty_title = L('ui_cat_empty_title'),
            cat_empty_hint = L('ui_cat_empty_hint'),
            contract_title_doc = L('ui_contract_title_doc'),
            ctr_tenant = L('ui_ctr_tenant'),
            ctr_datetime = L('ui_ctr_datetime'),
            ctr_vehicle = L('ui_ctr_vehicle'),
            ctr_duration = L('ui_ctr_duration'),
            ctr_rent_price = L('ui_ctr_rent_price'),
            ctr_insurance = L('ui_ctr_insurance'),
            ctr_fuel = L('ui_ctr_fuel'),
            ctr_deposit = L('ui_ctr_deposit'),
            ctr_total = L('ui_ctr_total'),
            ctr_terms = L('ui_ctr_terms'),
            ctr_accept = L('ui_ctr_accept'),
            sign_contract = L('ui_sign_contract'),
            sign_pay = L('ui_sign_pay'),
            processing = L('ui_processing'),
            signed_ok = L('ui_signed_ok'),
            sign_err = L('ui_sign_err'),
            rental_none = L('ui_rental_none'),
            timer_label = L('ui_timer_label'),
            rental_contract = L('ui_rental_contract'),
            rental_start = L('ui_rental_start'),
            rental_end = L('ui_rental_end'),
            rental_insurance = L('ui_rental_insurance'),
            rental_fuel = L('ui_rental_fuel'),
            rental_deposit_lbl = L('ui_rental_deposit_lbl'),
            extend_title = L('ui_extend_title'),
            btn_gps = L('ui_btn_gps'),
            btn_extend = L('ui_btn_extend'),
            btn_return = L('ui_btn_return'),
            scan_title = L('ui_scan_title'),
            scan_body = L('ui_scan_body'),
            scan_engine = L('ui_scan_engine'),
            scan_fuel = L('ui_scan_fuel'),
            scan_wheels = L('ui_scan_wheels'),
            confirm_return = L('ui_confirm_return'),
            returning = L('ui_returning'),
            hist_title = L('ui_hist_title'),
            toast_loading_showroom = L('ui_toast_loading_showroom'),
            toast_esc_showroom = L('ui_toast_esc_showroom'),
            toast_gps = L('ui_toast_gps'),
            toast_extend_err = L('ui_toast_extend_err'),
            toast_scan_fail = L('ui_toast_scan_fail'),
            toast_destroyed = L('ui_toast_destroyed'),
            toast_scan_done = L('ui_toast_scan_done'),
            toast_return_ok = L('ui_toast_return_ok'),
            toast_return_fail = L('ui_toast_return_fail'),
            btn_done = L('ui_btn_done'),
            pen_late = L('ui_pen_late'),
            pen_damage = L('ui_pen_damage'),
            pen_fuel = L('ui_pen_fuel'),
            pen_wheels = L('ui_pen_wheels'),
            pen_destroyed = L('ui_pen_destroyed'),
            pen_none = L('ui_pen_none'),
            sum_pen_total = L('ui_sum_pen_total'),
            sum_deposit_init = L('ui_sum_deposit_init'),
            sum_refund = L('ui_sum_refund'),
            sum_extra = L('ui_sum_extra'),
            hist_empty = L('ui_hist_empty'),
            extend_done = L('ui_extend_done'),
            cp_company = L('ui_cp_company'),
            cp_service = L('ui_cp_service'),
            cp_title = L('ui_cp_title'),
            cp_sub_mine = L('ui_cp_sub_mine'),
            cp_sub_other = L('ui_cp_sub_other'),
            cp_licensee = L('ui_cp_licensee'),
            cp_vehicle = L('ui_cp_vehicle'),
            cp_plate = L('ui_cp_plate'),
            cp_valid_until = L('ui_cp_valid_until'),
            cp_insurance = L('ui_cp_insurance'),
            cp_legal = L('ui_cp_legal'),
            cp_stamp = L('ui_cp_stamp'),
            cp_close = L('ui_cp_close'),
        },
    }
end

--- Mode notifications configurable : voir `Config.NotificationMode`.
function PR.NotifyModeCanonical()
    local m = Config.NotificationMode or 'framework'
    if m == 'ox_lib' or m == 'script' then return 'ox_lib' end
    if m == 'custom' then return 'custom' end
    return 'framework'
end

function PR.UsesQBFramework()
    local f = Config.Framework
    return f == 'qbcore' or f == 'qbox'
end
