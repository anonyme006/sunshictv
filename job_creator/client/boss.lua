function JC_C.OpenBossMenu(marker)
    local job = JC_C.GetJob()
    if not job then return end

    TriggerServerEvent('job_creator:getSociety', job.name)
    TriggerServerEvent('job_creator:getEmployees', job.name)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'playerMenu',
        data = {
            type = 'boss',
            title = (marker.label or 'Menu Patron') .. ' — ' .. job.label,
            job = job.name,
            grade = job.grade,
        },
    })
end

RegisterNUICallback('bossDeposit', function(data, cb)
    TriggerServerEvent('job_creator:societyDeposit', data.job, data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('bossWithdraw', function(data, cb)
    TriggerServerEvent('job_creator:societyWithdraw', data.job, data.amount)
    cb({ ok = true })
end)

RegisterNUICallback('bossHire', function(data, cb)
    TriggerServerEvent('job_creator:hire', data.targetId, data.job, data.grade)
    cb({ ok = true })
end)

RegisterNUICallback('bossFire', function(data, cb)
    TriggerServerEvent('job_creator:fire', data.targetId, data.identifier)
    Wait(200)
    TriggerServerEvent('job_creator:getEmployees', data.job)
    cb({ ok = true })
end)

RegisterNUICallback('bossSetGrade', function(data, cb)
    TriggerServerEvent('job_creator:setGrade', data.targetId, data.identifier, data.grade)
    Wait(200)
    TriggerServerEvent('job_creator:getEmployees', data.job)
    cb({ ok = true })
end)

RegisterNUICallback('bossRefresh', function(data, cb)
    TriggerServerEvent('job_creator:getSociety', data.job)
    TriggerServerEvent('job_creator:getEmployees', data.job)
    TriggerServerEvent('job_creator:getNearbyPlayers')
    cb({ ok = true })
end)
