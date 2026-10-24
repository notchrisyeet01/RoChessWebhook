local WEBHOOK_URL = "Paste_Webhook_URL_Here"
local webhookEnabled = true

local function sendToWebhook(message, fen, backend)
    if not webhookEnabled or not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    local content = string.format(
        "**[RoChess · Stockfish %s]**\n%s\n```\n%s\n```",
        backend or "?",
        message,
        fen or ""
    )
    local payload = HttpService:JSONEncode({ content = content })
    task.spawn(function()
        httppost(WEBHOOK_URL, payload, "application/json")
    end)
end
