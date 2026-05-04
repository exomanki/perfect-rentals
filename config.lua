Config = {}

Config.Framework    = 'esx'
Config.TargetSystem = 'none'
Config.Locale       = 'fr'

Config.AdminGroups = { 'admin', 'superadmin', 'god' }
Config.AdminJobs   = {}

Config.Durations = {
    { minutes = 30,    label = '30 minutes',  multiplier = 0.02  },
    { minutes = 60,    label = '1 heure',     multiplier = 0.042 },
    { minutes = 360,   label = '6 heures',    multiplier = 0.25  },
    { minutes = 1440,  label = '1 jour',      multiplier = 1.0   },
    { minutes = 4320,  label = '3 jours',     multiplier = 2.8   },
    { minutes = 10080, label = '7 jours',     multiplier = 6.0   },
}

Config.QuickExtend = {
    { minutes = 30,   label = '+30 min' },
    { minutes = 60,   label = '+1h' },
    { minutes = 1440, label = '+1 jour' },
}

Config.Insurance = {
    none     = { label = 'Aucune',   multiplier = 0.00, damageReduction = 0.0  },
    standard = { label = 'Standard', multiplier = 0.15, damageReduction = 0.50 },
    premium  = { label = 'Premium',  multiplier = 0.30, damageReduction = 0.90 },
}

Config.FuelPolicies = {
    full_to_full = { label = 'Plein → Plein', fuelCostPerPercent = 5 },
    flat_rate    = { label = 'Forfait',        flatCost = 150        },
}

Config.DeliveryCost = 200

Config.Penalties = {
    latePerMinute       = 2,
    lateGracePeriod     = 5,
    damagePerPercent    = 10,
    fuelPerPercent      = 5,
    destroyedMultiplier = 2.0,
}

Config.PaymentMethods = { 'bank', 'cash' }
Config.DefaultPayment = 'bank'

Config.ShowRentalTimerHud = true

Config.FuelLevel    = 100.0
Config.PlatePrefix  = 'RNT'
Config.SpawnDistance = 80.0

Config.Showroom = {
    enabled       = true,
    camDistance    = 6.0,
    camHeight     = 1.5,
    rotateSpeed   = 0.5,
}

Config.RateLimit = {
    rentCooldown   = 5000,
    returnCooldown = 5000,
    extendCooldown = 5000,
}

Config.Webhook = {
    enabled = false,
    url     = '',
    botName = 'Perfect Rentals',
    color   = 3447003,
}

Config.BlipNamesPerLocation = true

Config.Blip = {
    sprite = 226,
    color  = 3,
    scale  = 0.7,
    label  = 'Location de véhicules',
}

Config.InteractDistance = 2.5
Config.DrawDistance     = 15.0
Config.ReturnZoneRadius = 20.0

Config.Theme = {
    accent        = '#6366f1',
    accentLight   = '#818cf8',
    green         = '#34d399',
    red           = '#f87171',
    orange        = '#fbbf24',
    bgPrimary     = '#0a0a12',
    bgSecondary   = '#121220',
    bgCard        = '#161628',
    textPrimary   = '#eef0f6',
    textSecondary = '#c8cddc',
}

Locales = {}

function L(key, ...)
    local str = Locales[Config.Locale] and Locales[Config.Locale][key]
    if not str then
        str = Locales['fr'] and Locales['fr'][key] or key
    end
    if ... then
        return string.format(str, ...)
    end
    return str
end
