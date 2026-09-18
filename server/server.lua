ESX = nil
QBCore = nil

if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local function sendDiscordLog(title, description, color)
    if not Config.DiscordWebhook then return end

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            title = title,
            description = description,
            color = color
        }}
    }), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent('rs_drugsell:checkInventory', function()
    local src = source
    local inventory = {}

    if GetResourceState('nord_inventory') == 'started' then
        for _, drug in ipairs(Config.Drugs) do
            local count = exports.nord_inventory:GetItemCount(src, drug.name) or 0
            if count > 0 then
                inventory[drug.name] = count
            end
        end
    else
        local xPlayer = ESX and ESX.GetPlayerFromId(src) or QBCore.Functions.GetPlayer(src)
        if xPlayer then
            for _, drug in ipairs(Config.Drugs) do
                local itemData = xPlayer.getInventoryItem and xPlayer.getInventoryItem(drug.name)
                local count = itemData and (itemData.count or itemData.amount) or 0
                if count > 0 then
                    inventory[drug.name] = count
                end
            end
        end
    end

    TriggerClientEvent('rs_drugsell:openMenu', src, inventory)
end)

RegisterServerEvent('rs_drugsell:sellDrug', function(drugName)
    local src = source
    local xPlayer = ESX and ESX.GetPlayerFromId(src) or QBCore.Functions.GetPlayer(src)
    local drug = nil

    for _, d in ipairs(Config.Drugs) do
        if d.name == drugName then
            drug = d
            break
        end
    end

    if not drug then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Translate["invalid_drug"] })
        sendDiscordLog(Translate["discord_invalid_drug_title"], Translate["discord_invalid_drug_desc"]:format(GetPlayerName(src), drugName), 16711680)
        return
    end

    local hasDrug = false
    if GetResourceState('nord_inventory') == 'started' then
        local count = exports.nord_inventory:GetItemCount(src, drug.name) or 0
        if count > 0 then
            local removed = exports.nord_inventory:RemoveItem(src, drug.name, 1)
            if removed then
                hasDrug = true
            end
        end
    else
        if xPlayer then
            local itemData = xPlayer.getInventoryItem and xPlayer.getInventoryItem(drug.name)
            local count = itemData and (itemData.count or itemData.amount) or 0
            if count > 0 then
                xPlayer.removeInventoryItem(drug.name, 1)
                hasDrug = true
            end
        end
    end

    if hasDrug then
        if xPlayer then
            if xPlayer.addMoney then
                xPlayer.addMoney(drug.price)
            elseif xPlayer.Functions and xPlayer.Functions.AddMoney then
                xPlayer.Functions.AddMoney('cash', drug.price)
            end
        else
            if GetResourceState('nord_inventory') == 'started' then
                exports.nord_inventory:AddCash(src, drug.price)
            end
        end
        TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = Translate["sold_drug"]:format(drug.label, drug.price) })
        sendDiscordLog(Translate["discord_sold_drug_title"], Translate["discord_sold_drug_desc"]:format(GetPlayerName(src), drug.label, drug.price), 65280)
    else
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = Translate["no_drug"]:format(drug.label) })
        sendDiscordLog(Translate["discord_no_drug_title"], Translate["discord_no_drug_desc"]:format(GetPlayerName(src), drug.label), 16711680)
    end
end)


RegisterServerEvent('rs_drugsell:callPolice', function(coords)
    local xPlayers = ESX.GetPlayers()

    for _, playerId in ipairs(xPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer.job.name == 'police' then
            TriggerClientEvent('ox_lib:notify', playerId, { type = 'info', description = Translate["police_alert"] })
            TriggerClientEvent('rs_drugsell:policeBlip', playerId, coords)
        end
    end
end)



RegisterServerEvent('rs_drugsell:stealMoney', function(amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    xPlayer.addMoney(amount)
    sendDiscordLog(Translate["discord_steal_money_title"], Translate["discord_steal_money_desc"]:format(GetPlayerName(source), amount), 16776960) -- Žlutá barva
end)
