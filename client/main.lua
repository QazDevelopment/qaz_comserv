local Keys = {
  ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57, 
  ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177, 
  ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
  ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
  ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
  ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70, 
  ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
  ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
  ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX = nil
INPUT_CONTEXT = 51

local isSentenced = false
local communityServiceFinished = false
local actionsRemaining = 0
local availableActions = {}
local disable_actions = false

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
        end)
        Citizen.Wait(0)
    end
end)

AddEventHandler('playerSpawned', function()
    Citizen.Wait(2000)
    TriggerServerEvent('esx_comserv:checkIfSentenced')
end)

function FillActionTable(last_action)

    while #availableActions < 5 do

        local service_does_not_exist = true

        local random_selection = Config.ServiceLocations[math.random(1, #Config.ServiceLocations)]

        for i = 1, #availableActions do
            if random_selection.coords.x == availableActions[i].coords.x and random_selection.coords.y ==
                availableActions[i].coords.y and random_selection.coords.z == availableActions[i].coords.z then

                service_does_not_exist = false

            end
        end

        if last_action ~= nil and random_selection.coords.x == last_action.coords.x and random_selection.coords.y ==
            last_action.coords.y and random_selection.coords.z == last_action.coords.z then
            service_does_not_exist = false
        end

        if service_does_not_exist then table.insert(availableActions, random_selection) end

    end

end

RegisterNetEvent('esx_comserv:inCommunityService')
AddEventHandler('esx_comserv:inCommunityService', function(actions_remaining)
    local target = GetPlayerServerId(PlayerId())
    TriggerServerEvent('esx_comserv:clearInventory', target)
    LocalPlayer.state:set('teleport', true, true)

    local playerPed = GetPlayerPed(target)

    if isSentenced then return end

    actionsRemaining = actions_remaining

    FillActionTable()

    ApplyPrisonerSkin()
    ESX.Game.Teleport(playerPed, Config.ServiceLocation)
    isSentenced = true
    communityServiceFinished = false

    while actionsRemaining > 0 and communityServiceFinished ~= true do

        if IsPedInAnyVehicle(playerPed, false) then ClearPedTasksImmediately(playerPed) end

        Citizen.Wait(20000)

        if GetDistanceBetweenCoords(GetEntityCoords(playerPed), Config.ServiceLocation.x, Config.ServiceLocation.y,
            Config.ServiceLocation.z) > 45 then
            ESX.Game.Teleport(playerPed, Config.ServiceLocation)
            TriggerEvent('chat:addMessage', {
                template = '<div class="chat-message system"><i class="fas fa-cog"></i><b><span style="color: #df7b00">{0}:</span><span style="margin-top: 5px; font-weight: 300;">{1}</span></div>',
                args = { 'SYSTEM', _U('escape_attempt') }
            })
            TriggerServerEvent('esx_comserv:extendService')
            actionsRemaining = actionsRemaining + Config.ServiceExtensionOnEscape
        end

    end

    TriggerServerEvent('esx_comserv:finishCommunityService', -1)
    ESX.Game.Teleport(playerPed, Config.ReleaseLocation)
    isSentenced = false

    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        TriggerEvent('skinchanger:loadSkin', skin)
    end)

    LocalPlayer.state:set('teleport', false, true)
end)

RegisterNetEvent('esx_comserv:finishCommunityService')
AddEventHandler('esx_comserv:finishCommunityService', function(source)
    communityServiceFinished = true
    isSentenced = false
    actionsRemaining = 0
end)

Citizen.CreateThread(function()
    while true do
        ::start_over::
        Citizen.Wait(1)

        if actionsRemaining > 0 and isSentenced then
            draw2dText(_U('remaining_msg', ESX.Math.Round(actionsRemaining)), {0.37, 0.955})
            DrawAvailableActions()
            DisableViolentActions()

            local pCoords = GetEntityCoords(PlayerPedId())

            for i = 1, #availableActions do
                local distance = GetDistanceBetweenCoords(pCoords, availableActions[i].coords, true)

                if distance < 1.5 then
                    DisplayHelpText("Press ~INPUT_CONTEXT~ to start.")

                    if (IsControlJustReleased(1, 38)) then
                        tmp_action = availableActions[i]
                        RemoveAction(tmp_action)
                        FillActionTable(tmp_action)
                        disable_actions = true

                        TriggerServerEvent('esx_comserv:completeService')
                        actionsRemaining = actionsRemaining - 1

                        if (tmp_action.type == "cleaning") then

                            ExecuteCommand('e broom')

                        end

                        if (tmp_action.type == "gardening") then
                            TaskStartScenarioInPlace(PlayerPedId(), "world_human_gardener_plant", 0, false)
                        end

                        ESX.SetTimeout(10000, function()
                            disable_actions = false
                            ClearPedTasks(PlayerPedId())
                        end)

                        goto start_over
                    end
                end
            end
        else
            Citizen.Wait(1000)
        end
    end
end)

function RemoveAction(action)

    local action_pos = -1

    for i = 1, #availableActions do
        if action.coords.x == availableActions[i].coords.x and action.coords.y == availableActions[i].coords.y and
            action.coords.z == availableActions[i].coords.z then action_pos = i end
    end

    if action_pos ~= -1 then
        table.remove(availableActions, action_pos)
    else
        print("User tried to remove an unavailable action")
    end

end

function DisplayHelpText(str)
    SetTextComponentFormat("STRING")
    AddTextComponentString(str)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

function DrawAvailableActions()
    for i = 1, #availableActions do
        DrawMarker(21, availableActions[i].coords, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.2, 255, 127, 80, 100, false, true, 2, true, false, false, false)
    end
end

function DisableViolentActions()
    local playerPed = PlayerPedId()
    if disable_actions == true then DisableAllControlActions(0) end
    RemoveAllPedWeapons(playerPed, true)
    DisableControlAction(2, 37, true) -- disable weapon wheel (Tab)
    DisablePlayerFiring(playerPed, true) -- Disables firing all together if they somehow bypass inzone Mouse Disable
    DisableControlAction(0, 106, true) -- Disable in-game mouse controls
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    if IsDisabledControlJustPressed(2, 37) then -- if Tab is pressed, send error message
        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true) -- if tab is pressed it will set them to unarmed (this is to cover the vehicle glitch until I sort that all out)
    end
    if IsDisabledControlJustPressed(0, 106) then -- if LeftClick is pressed, send error message
        SetCurrentPedWeapon(playerPed, GetHashKey("WEAPON_UNARMED"), true) -- If they click it will set them to unarmed
    end
end

function ApplyPrisonerSkin()

    local playerPed = PlayerPedId()

    if DoesEntityExist(playerPed) then

        Citizen.CreateThread(function()

            TriggerEvent('skinchanger:getSkin', function(skin)
                if skin.sex == 0 then
                    TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms['prison_wear'].male)
                else
                    TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms['prison_wear'].female)
                end
            end)

            SetPedArmour(playerPed, 0)
            ClearPedBloodDamage(playerPed)
            ResetPedVisibleDamage(playerPed)
            ClearPedLastWeaponDamage(playerPed)
            ResetPedMovementClipset(playerPed, 0)

        end)
    end
end

function draw2dText(text, pos)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.45, 0.45)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()

    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(table.unpack(pos))
end
