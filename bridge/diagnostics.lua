-- Bridge - startup diagnostics (framework / database check).

RegisterCommand('ddev_bridge_test', function(source)
    if not RequireFarmAdmin(source) then return end

    local isConsole = source == 0

    local dbOk, dbErr = false, 'timeout'
    local dbDone = false

    CreateThread(function()
        local ok, err = pcall(function()
            local result = MySQL.query.await('SELECT 1 AS ok')
            assert(result and result[1] and result[1].ok == 1, 'unexpected query result')
        end)
        dbOk = ok
        dbErr = err
        dbDone = true
    end)

    local waited = 0
    while not dbDone and waited < 5000 do
        Citizen.Wait(100)
        waited = waited + 100
    end

    print(('^2[ddev_farm]^7 bridge: %s | ready: %s | db: %s'):format(
        Bridge.GetFrameworkName(),
        tostring(Bridge.IsReady()),
        dbOk and 'connected' or ('error: ' .. tostring(dbErr))))

    print(('^2[ddev_farm]^7 deps: mysql=%s lib=%s inventory=%s'):format(
        GetResourceState('oxmysql'),
        GetResourceState('ox_lib'),
        GetResourceState('ox_inventory')))

    if not isConsole then
        local job = Bridge.GetJob(source)

        print(('^2[ddev_farm]^7 player: %s | id: %s | job: %s | cash: %s | bank: %s'):format(
            tostring(Bridge.GetName(source)),
            tostring(Bridge.GetIdentifier(source)),
            tostring(job and job.name),
            Shared.FormatMoney(Bridge.GetMoney(source, 'money')),
            Shared.FormatMoney(Bridge.GetMoney(source, 'bank'))))

        Bridge.Notify(source, 'Bridge diagnostics printed to the console.', 'inform')
    end
end, false)

CreateThread(function()
    if GetConvar('ddev_bridge_diagnostics', 'true') ~= 'true' then return end

    Citizen.Wait(5000)

    ExecuteCommand('ddev_bridge_test')
end)
