local Accounts = {}

CreateThread(function()
    Wait(500)
    local result = exports.oxmysql:fetchSync('SELECT * FROM bossmenu_accounts')
    if not result then
        return
    end
    for k, v in pairs(result) do
        local job = v.account
        local money = tonumber(v.money)
        if job and money then
            Accounts[job] = money
        end
    end
end)

QBCore.Functions.CreateCallback('qb-bossmenu:server:GetAccount', function(source, cb, jobname)
    local result = GetAccount(jobname)
    cb(result)
end)

-- Export
function GetAccount(account)
    return Accounts[account] or 0
end

function UpdateAccountMoney(account, money)
    exports.oxmysql:insert('UPDATE bossmenu_accounts SET money = :money WHERE account = :account', {
        ['money'] = tostring(money),
        ['account'] = account
    })
end

-- Withdraw Money
RegisterNetEvent("qb-bossmenu:server:withdrawMoney")
AddEventHandler("qb-bossmenu:server:withdrawMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local job = Player.PlayerData.job.name

    if not Accounts[job] then
        Accounts[job] = 0
    end

    if Accounts[job] >= amount and amount > 0 then
        Accounts[job] = Accounts[job] - amount
        Player.Functions.AddMoney("cash", amount)
    else
        TriggerClientEvent('QBCore:Notify', src, 'Not Enough Money', 'error')
        return
    end
    UpdateAccountMoney(job, Accounts[job])
    TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Withdraw Money', "Successfully withdrawn $" .. amount .. ' (' .. job .. ')', src)
end)

-- Deposit Money
RegisterNetEvent("qb-bossmenu:server:depositMoney")
AddEventHandler("qb-bossmenu:server:depositMoney", function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local job = Player.PlayerData.job.name

    if not Accounts[job] then
        Accounts[job] = 0
    end

    if Player.Functions.RemoveMoney("cash", amount) then
        Accounts[job] = Accounts[job] + amount
    else
        TriggerClientEvent('QBCore:Notify', src, 'Not Enough Money', "error")
        return
    end
    UpdateAccountMoney(job, Accounts[job])
    TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Deposit Money', "Successfully deposited $" .. amount .. ' (' .. job .. ')', src)
end)

RegisterNetEvent("qb-bossmenu:server:addAccountMoney")
AddEventHandler("qb-bossmenu:server:addAccountMoney", function(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end
    
    Accounts[account] = Accounts[account] + amount
    TriggerClientEvent('qb-bossmenu:client:refreshSociety', -1, account, Accounts[account])
    UpdateAccountMoney(account, Accounts[account])
end)

RegisterNetEvent("qb-bossmenu:server:removeAccountMoney")
AddEventHandler("qb-bossmenu:server:removeAccountMoney", function(account, amount)
    if not Accounts[account] then
        Accounts[account] = 0
    end

    if Accounts[account] >= amount then
        Accounts[account] = Accounts[account] - amount
    end

    TriggerClientEvent('qb-bossmenu:client:refreshSociety', -1, account, Accounts[account])
    UpdateAccountMoney(account, Accounts[account])
end)

-- Get Employees
QBCore.Functions.CreateCallback('qb-bossmenu:server:GetEmployees', function(source, cb, jobname)
    local employees = {}
    if not Accounts[jobname] then
        Accounts[jobname] = 0
    end
    local players = exports.oxmysql:fetchSync("SELECT * FROM `players` WHERE `job` LIKE '%".. jobname .."%'")
    if players[1] ~= nil then
        for key, value in pairs(players) do
            local isOnline = QBCore.Functions.GetPlayerByCitizenId(value.citizenid)

            if isOnline then
                table.insert(employees, {
                    source = isOnline.PlayerData.citizenid, 
                    grade = isOnline.PlayerData.job.grade,
                    isboss = isOnline.PlayerData.job.isboss,
                    name = isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
                })
            else
                table.insert(employees, {
                    source = value.citizenid, 
                    grade =  json.decode(value.job).grade,
                    isboss = json.decode(value.job).isboss,
                    name = json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
                })
            end
        end
    end
    cb(employees)
end)

-- Grade Change
RegisterNetEvent('qb-bossmenu:server:updateGrade')
AddEventHandler('qb-bossmenu:server:updateGrade', function(target, grade)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Employee = QBCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        if Employee.Functions.SetJob(Player.PlayerData.job.name, grade) then
            TriggerClientEvent('QBCore:Notify', src, "Grade Changed Successfully!", "success")
            TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, "Your Job Grade Is Now [" ..grade.."].", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Grade Does Not Exist", "error")
        end
    else
        local player = exports.oxmysql:fetchSync('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] ~= nil then
            Employee = player[1]
            local job = QBCore.Shared.Jobs[Player.PlayerData.job.name]
            local employeejob = json.decode(Employee.job)
            employeejob.grade = job.grades[data.grade]
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(employeejob), target })
            TriggerClientEvent('QBCore:Notify', src, "Grade Changed Successfully!", "success")
        else
            TriggerClientEvent('QBCore:Notify', src, "Player Does Not Exist", "error")
        end
    end
end)

-- Fire Employee
RegisterNetEvent('qb-bossmenu:server:fireEmployee')
AddEventHandler('qb-bossmenu:server:fireEmployee', function(target)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Employee = QBCore.Functions.GetPlayerByCitizenId(target)
    if Employee then
        if Employee.Functions.SetJob("unemployed", '0') then
            TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Job Fire', "Successfully fired " .. GetPlayerName(Employee.PlayerData.source) .. ' (' .. Player.PlayerData.job.name .. ')', src)
            TriggerClientEvent('QBCore:Notify', src, "Fired successfully!", "success")
            TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source , "You Were Fired", "error")
        else
            TriggerClientEvent('QBCore:Notify', src, "Contact Server Developer", "error")
        end
    else
        local player = exports.oxmysql:fetchSync('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
        if player[1] ~= nil then
            Employee = player[1]
            local job = {}
            job.name = "unemployed"
            job.label = "Unemployed"
            job.payment = 10
            job.onduty = true
            job.isboss = false
            job.grade = {}
            job.grade.name = nil
            job.grade.level = 0
            exports.oxmysql:execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), target })
            TriggerClientEvent('QBCore:Notify', src, "Fired successfully!", "success")
            TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Fire', "Successfully fired " .. data.source .. ' (' .. Player.PlayerData.job.name .. ')', src)
        else
            TriggerClientEvent('QBCore:Notify', src, "Player Does Not Exist", "error")
        end
    end
end)

-- Recruit Player
RegisterNetEvent('qb-bossmenu:server:giveJob')
AddEventHandler('qb-bossmenu:server:giveJob', function(recruit)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(recruit)
    if Player.PlayerData.job.isboss == true then
        if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
            TriggerClientEvent('QBCore:Notify', src, "You Recruited " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. " To " .. Player.PlayerData.job.label .. "", "success")
            TriggerClientEvent('QBCore:Notify', Target.PlayerData.source , "You've Been Recruited To " .. Player.PlayerData.job.label .. "", "success")
            TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Recruit', "Successfully recruited " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', src)
        end
    end
end)
