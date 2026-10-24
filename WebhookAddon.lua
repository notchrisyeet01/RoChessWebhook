local WEBHOOK_URL = "PASTE_WEBHOOK_URL_HERE"
local webhookEnabled = true

local function sendToWebhook(message, fen, backend)
    if not webhookEnabled then return end
    local HS = game:GetService("HttpService")
	local content = string.format(
    	"**[RoChess \xc2\xb7 Stockfish %s]**\n%s",
    	tostring(backend or "?"),
    	tostring(message)
    )
    local ok, payload = pcall(function() return HS:JSONEncode({ content = content }) end)
    if not ok then print("[Webhook] encode error: " .. tostring(payload)); return end
    pcall(function() httppost(WEBHOOK_URL, payload, "application/json") end)
end
