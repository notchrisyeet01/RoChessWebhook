local WEBHOOK_URL = "Paste_Webhook_URL_Here"
local webhookEnabled = false  -- toggled from UI

local function sendToWebhook(message, fen, backend)
    if not webhookEnabled or not WEBHOOK_URL or WEBHOOK_URL == "" then return end
    local content = string.format(
        "**[RoChess · Stockfish %s]**\n%s\n```\n%s\n```",
        backend or "?",
        message,
        fen or ""
    )
    local payload = HttpService:JSONEncode({ content = content })
    -- fire and forget — non-blocking via task.spawn so it never stalls the game loop
    task.spawn(function()
        httppost(WEBHOOK_URL, payload, "application/json")
    end)
end
