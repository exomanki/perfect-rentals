Webhook = {}

function Webhook.Send(title, message, color)
    if not Config.Webhook.enabled or Config.Webhook.url == '' then return end

    local embed = {
        {
            title       = title,
            description = message,
            color       = color or Config.Webhook.color,
            footer      = { text = Config.Webhook.botName .. ' | ' .. os.date('%d/%m/%Y %H:%M') },
        }
    }

    PerformHttpRequest(Config.Webhook.url, function(err, text, headers) end, 'POST',
        json.encode({ username = Config.Webhook.botName, embeds = embed }),
        { ['Content-Type'] = 'application/json' }
    )
end

function Webhook.Rental(identifier, model, plate, price, locationName)
    Webhook.Send(
        'Nouvelle Location',
        ('**Joueur:** `%s`\n**Véhicule:** %s\n**Plaque:** `%s`\n**Prix total:** $%s\n**Agence:** %s'):format(
            identifier, model, plate, price, locationName
        ),
        3066993
    )
end

function Webhook.Return(identifier, model, plate, penalties, refund)
    Webhook.Send(
        'Restitution',
        ('**Joueur:** `%s`\n**Véhicule:** %s\n**Plaque:** `%s`\n**Pénalités:** $%s\n**Caution remboursée:** $%s'):format(
            identifier, model, plate, penalties, refund
        ),
        15105570
    )
end

function Webhook.AdminAction(admin, action, detail)
    Webhook.Send(
        'Action Admin',
        ('**Admin:** `%s`\n**Action:** %s\n**Détails:** %s'):format(admin, action, detail),
        15158332
    )
end
