ESX = nil

TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
end)

local clearAllItems = true -- Set to true to clear all items, set to false to clear only weapons

ESX.RegisterCommand('comserv', 'admin', function(xPlayer, args, showError)
    TriggerEvent('esx_comserv:sendToCommunityService', args.playerId.source, args.actions)
end, false, {help = 'Give player community service', validate = true, arguments = {
    {name = 'playerId', help = 'target id', type = 'player'},
    {name = 'actions', help = 'actions count [suggested: 10-40]', type = 'number'},
}})

ESX.RegisterCommand('endcomserv', 'admin', function(xPlayer, args, showError)
    TriggerEvent('esx_comserv:endCommunityServiceCommand', args.playerId.source)
end, false, {help = 'Remove player community service', validate = true, arguments = {
    {name = 'playerId', help = 'target id', type = 'player'},
}})

ESX.RegisterCommand('ocomserv', 'admin', function(xPlayer, args, showError)
    local identifier = args.identifier
    local actions_count = args.amount
    MySQL.Async.fetchScalar('SELECT 1 FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(found)
        if found then
            MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
            }, function(result)
                if result[1] then
                    MySQL.Async.execute('UPDATE communityservice SET actions_remaining = @actions_remaining WHERE identifier = @identifier', {
                        ['@identifier'] = identifier,
                        ['@actions_remaining'] = actions_count,
                    })
                else
                    MySQL.Async.execute('INSERT INTO communityservice (identifier, actions_remaining) VALUES (@identifier, @actions_remaining)', {
                        ['@identifier'] = identifier,
                        ['@actions_remaining'] = actions_count,
                    })
                end
                local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
                if xPlayer then
                    TriggerClientEvent('esx_comserv:inCommunityService', xPlayer.source, actions_count)
                end
            end)
        else
            print('^1No player found with this identifier '..identifier..'^7')
        end
    end)
end, true, {help = 'Offline community service', validate = true, arguments = {
    {name = 'identifier', help = 'Identifier', type = 'any'},
    {name = 'amount', help = 'Amount', type = 'number'},
}})

ESX.RegisterCommand('oendcomserv', 'admin', function(xPlayer, args, showError)
    local identifier = args.identifier
    MySQL.Async.fetchScalar('SELECT 1 FROM users WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(found)
        if found then
            MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
            }, function(result)
                if result[1] then
                    MySQL.Async.execute('DELETE from communityservice WHERE identifier = @identifier', {
                        ['@identifier'] = identifier,
                    })
                end
            end)
            local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
            if xPlayer then
                TriggerClientEvent('esx_comserv:finishCommunityService', xPlayer.source)
            end
        else
            print('^1No player found with this identifier '..identifier..'^7')
        end
    end)
end, true, {help = 'Offline end community service', validate = true, arguments = {
    {name = 'identifier', help = 'Identifier', type = 'any'},
}})

RegisterNetEvent('esx_comserv:endCommunityServiceCommand', function(source)
    if source ~= nil then releaseFromCommunityService(source) end
end)

-- unjail after time served
RegisterNetEvent('esx_comserv:finishCommunityService', function()
    releaseFromCommunityService(source)
end)

RegisterNetEvent('esx_comserv:completeService', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
    }, function(result)
        if result[1] then
            MySQL.Async.execute('UPDATE communityservice SET actions_remaining = actions_remaining - 1 WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
            })
        end
    end)
end)

RegisterNetEvent('esx_comserv:extendService', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
    }, function(result)
        if result[1] then
            MySQL.Async.execute('UPDATE communityservice SET actions_remaining = actions_remaining + @extension_value WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
                ['@extension_value'] = Config.ServiceExtensionOnEscape,
            })
        end
    end)
end)

RegisterNetEvent('esx_comserv:sendToCommunityService', function(target, actions_count)
    local _source = target
    local xPlayer = ESX.GetPlayerFromId(_source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
    }, function(result)
        if result[1] then
            MySQL.Async.execute('UPDATE communityservice SET actions_remaining = @actions_remaining WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
                ['@actions_remaining'] = actions_count,
            })
        else
            MySQL.Async.execute('INSERT INTO communityservice (identifier, actions_remaining) VALUES (@identifier, @actions_remaining)', {
                ['@identifier'] = identifier,
                ['@actions_remaining'] = actions_count,
            })
        end
    end)
    TriggerClientEvent('chat:addMessage', -1, {
        template = '<div class="chat-message system"><i class="fas fa-cog"></i><b><span style="color: #df7b00">{0}:</span><span style="margin-top: 5px; font-weight: 300;">{1}</span></div>',
        args = { 'SYSTEM', _U('comserv_msg', xPlayer.get('firstName')..' '..xPlayer.get('lastName'), actions_count) }
    })
    TriggerClientEvent('esx_policejob:unrestrain', _source)
    TriggerClientEvent('esx_comserv:inCommunityService', _source, actions_count)
end)

RegisterNetEvent('esx_comserv:checkIfSentenced', function()
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
    }, function(result)
        if result[1] ~= nil and result[1].actions_remaining > 0 then
            TriggerClientEvent('esx_comserv:inCommunityService', _source, tonumber(result[1].actions_remaining))
        end
    end)
end)

function releaseFromCommunityService(target)
    local _source = target
    local xPlayer = ESX.GetPlayerFromId(_source)
    local identifier = xPlayer.identifier

    MySQL.Async.fetchAll('SELECT * FROM communityservice WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
    }, function(result)
        if result[1] then
            MySQL.Async.execute('DELETE from communityservice WHERE identifier = @identifier', {
                ['@identifier'] = identifier,
            })
            TriggerClientEvent('chat:addMessage', -1, {
                template = '<div class="chat-message system"><i class="fas fa-cog"></i><b><span style="color: #df7b00">{0}:</span><span style="margin-top: 5px; font-weight: 300;">{1}</span></div>',
                args = { 'SYSTEM', _U('comserv_finished', xPlayer.get('firstName')..' '..xPlayer.get('lastName')) }
            })
        end
    end)
    TriggerClientEvent('esx_comserv:finishCommunityService', _source)
end


RegisterNetEvent('esx_comserv:clearInventory')
AddEventHandler('esx_comserv:clearInventory', function(target)
    local xPlayer = ESX.GetPlayerFromId(target)
    
    if xPlayer then
        for _, item in ipairs(xPlayer.inventory) do
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    else
        print("Failed to get player object for ID: " .. tostring(target))
    end
end)
