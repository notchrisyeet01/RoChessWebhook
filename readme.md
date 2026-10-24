# RoChessM (Forked)
FORKED FROM: [youziwing/RoChessM](https://github.com/youziwing/RoChessM)

**The Main.lua file is customized to add the webhook integration feature. The added lines are in [WebhookAddon.lua](https://github.com/notchrisyeet01/RoChessWebhook/blob/main/WebhookAddon.lua)**

## Part 1: How to create the Webhook
1. Create a new Discord server (or use an existing one).
2. Go to Server Settings > Integrations > Webhooks > New Webhook
3. Customize it however you'd like.
4. Copy the Webhook URL for later.

## Part 2: How to connect your Webhook to the script
1. If Main.lua is updated to the latest script version, go to it and copy everything. If it isn't, go to the next section briefly.
2. Paste the entire script into Matcha's LuaU environment.
3. As of 10/23/26, line 19 is where you can paste your webhook URL.
4. Run your script and you should see your webhook send what outputs in Matcha's UI, so you don't have to go back and forth checking which moves to make! (if you have 2+ monitors)

## What if Main.lua isn't updated to the original script?
1. Paste [WebhookAddon.lua](https://github.com/notchrisyeet01/RoChessWebhook/blob/main/WebhookAddon.lua) in between "local promotionNames = {q="Queen", r="Rook", b="Bishop", n="Knight"}" and "local function removeArrow()". (If the script changes its layout or code in the future, reach out to me on Discord (@Chrisyeet01) so the addon can be updated.)
2. Continue at step 2 of part 2

## Credits
Original: [youziwing](https://github.com/youziwing)
