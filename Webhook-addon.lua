local WEBHOOK_URL = "PASTE_YOUR_DISCORD_WEBHOOK_URL_HERE"

local oldPrint = print

print = function(...)
    local args = {...}
    oldPrint(...)

    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = tostring(v)
    end

    task.spawn(function()
        pcall(function()
            local body = HttpService:JSONEncode({
                content = table.concat(parts, " "):sub(1, 1900)
            })

            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = body
            })
        end)
    end)
end
