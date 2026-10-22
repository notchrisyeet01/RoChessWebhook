
local FLIP_BOARD = false
local SCAN_DELAY = 0.15
local API_URL = "https://rochess-gateway.vercel.app/api/analyze"
local API_KEY = ""
local ANALYSIS_DEPTH = 12
local PLAY_AS = "White" -- "White", "Black", or "Any"

if UI and UI.AddTab then
    UI.AddTab("Chess Detector", function(tab)
        local settings = tab:Section("Settings", "Left")
        settings:Combo("chess_play_as", "Play as", {"White", "Black", "Any"}, 0, function(_, text)
            PLAY_AS = text
        end)
        settings:Text("Choose your color before starting a game.")
    end)
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

local function child(parent, name)
    return parent and parent:FindFirstChild(name) or nil
end

local function squareName(index)
    if FLIP_BOARD then
        index = 65 - index
    end
    return string.char(97 + (index - 1) % 8) .. tostring(math.floor((index - 1) / 8) + 1)
end

local function pieceAtStart(square)
    local file, rank = square:sub(1, 1), tonumber(square:sub(2, 2))
    local back = {a="Rook", b="Knight", c="Bishop", d="Queen", e="King", f="Bishop", g="Knight", h="Rook"}
    if rank == 1 then return "White " .. back[file] end
    if rank == 2 then return "White Pawn" end
    if rank == 7 then return "Black Pawn" end
    if rank == 8 then return "Black " .. back[file] end
end

local function pieceCode(pieceType)
    local color, kind = pieceType:match("^(%a+) (.+)$")
    local codes = {Pawn="p", Knight="n", Bishop="b", Rook="r", Queen="q", King="k"}
    local code = codes[kind]
    return color == "White" and string.upper(code) or code
end

local function getBoard()
    local gui = child(player, "PlayerGui")
    local board = child(child(child(gui, "ChessUI"), "Root"), "Board")
    local squares, pieces = child(board, "Squares"), child(board, "Pieces")
    assert(squares and pieces, "Chess board not found. Open RoChess first.")
    return squares, pieces
end

local function getToken(piece)
    local ok, address = pcall(function() return piece.Address end)
    if ok and type(address) == "number" and address > 0 then
        return "address:" .. tostring(address)
    end
    return piece
end

local function scan()
    local squareFolder, pieceFolder = getBoard()
    local squares, byIndex = {}, {}
    for _, square in ipairs(squareFolder:GetChildren()) do
        local index = tonumber(square.Name:match("^S(%d+)$"))
        if index and index >= 1 and index <= 64 then
            local p = square.AbsolutePosition
            squares[#squares + 1] = {index=index, x=p.X, y=p.Y}
            byIndex[index] = squares[#squares]
        end
    end
    assert(#squares == 64, "Expected 64 squares named S1 through S64.")
    local spacing = math.huge
    for i = 1, #squares do
        for j = i + 1, #squares do
            local dx, dy = squares[i].x - squares[j].x, squares[i].y - squares[j].y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 1 and d < spacing then
                spacing = d
            end
        end
    end
    assert(spacing < math.huge and spacing >= 4, "Could not calculate board spacing.")
    local tokens, occupied = {}, {}
    for _, piece in ipairs(pieceFolder:GetChildren()) do
        if piece.ClassName == "ImageLabel" or piece.ClassName == "ImageButton" then
            local p, nearest, best = piece.AbsolutePosition, nil, math.huge
            for _, square in ipairs(squares) do
                local dx, dy = p.X - square.x, p.Y - square.y
                local d = math.sqrt(dx * dx + dy * dy)
                if d < best then
                    nearest, best = square.index, d
                end
            end
            assert(nearest and best <= spacing * 0.4, "Piece is moving; wait for animation.")
            local name = squareName(nearest)
            assert(not occupied[name], "Overlapping pieces detected; wait for animation.")
            local token = getToken(piece)
            assert(tokens[token] == nil, "Duplicate piece identity; cannot track reliably.")
            occupied[name], tokens[token] = true, name
        end
    end
    return tokens
end

local function sameSnapshot(a, b)
    for token, square in pairs(a) do
        if b[token] ~= square then return false end
    end
    for token, square in pairs(b) do
        if a[token] ~= square then return false end
    end
    return true
end

local function makeFen(snapshot, pieceTypes, whiteToMove, halfmove, fullmove)
    local board = {}
    for token, square in pairs(snapshot) do
        if pieceTypes[token] then board[square] = pieceCode(pieceTypes[token]) end
    end
    local ranks = {}
    for rank = 8, 1, -1 do
        local row, empty = "", 0
        for file = 1, 8 do
            local piece = board[string.char(96 + file) .. tostring(rank)]
            if piece then
                if empty > 0 then row, empty = row .. tostring(empty), 0 end
                row = row .. piece
            else empty = empty + 1 end
        end
        if empty > 0 then row = row .. tostring(empty) end
        ranks[#ranks + 1] = row
    end
    return table.concat(ranks, "/") .. " " .. (whiteToMove and "w" or "b") .. " - - " .. tostring(halfmove) .. " " .. tostring(fullmove)
end

local function askStockfish(fen)
    local body = HttpService:JSONEncode({fen=fen, depth=ANALYSIS_DEPTH})
    local headers = nil
    if API_KEY ~= "" then
        headers = { ["X-API-Key"] = API_KEY }
    end
    local raw = httppost(API_URL, body, "application/json", headers)
    if raw == "" then return nil, "No response from the public Render API" end
    local ok, result = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(result) ~= "table" then return nil, "Invalid API response: " .. tostring(raw) end
    if not result.bestmove then return nil, result.detail or "API returned no best move" end
    return result
end

local ok, previous = pcall(scan)
if not ok then print("[Chess Detect] Initialization failed: " .. tostring(previous)); return end
local pieceTypes, known = {}, 0
local unknownTokens = {}
local startedAfterOpening = false
for token, square in pairs(previous) do
    pieceTypes[token] = pieceAtStart(square)
    if pieceTypes[token] then
        known = known + 1
    else
        unknownTokens[#unknownTokens + 1] = token
    end
end

if known == 31 and #unknownTokens == 1 and PLAY_AS ~= "Any" then
    local expected = {}
    local files = {"a", "b", "c", "d", "e", "f", "g", "h"}
    local back = {a="Rook", b="Knight", c="Bishop", d="Queen", e="King", f="Bishop", g="Knight", h="Rook"}
    for _, file in ipairs(files) do
        local types = {"White " .. back[file], "White Pawn", "Black Pawn", "Black " .. back[file]}
        for _, kind in ipairs(types) do expected[kind] = (expected[kind] or 0) + 1 end
    end
    for _, kind in pairs(pieceTypes) do expected[kind] = expected[kind] - 1 end
    local missing
    for kind, count in pairs(expected) do
        if count == 1 then
            if missing then
                missing = nil
                break
            end
            missing = kind
        elseif count ~= 0 then
            missing = nil
            break
        end
    end
    if missing then
        pieceTypes[unknownTokens[1]] = missing
        known = 32
        startedAfterOpening = true
    end
end

assert(known == 32, "Start before the first move, or start immediately after exactly one opening move.")

local whiteToMove = startedAfterOpening and (PLAY_AS == "White") or (not startedAfterOpening)
local halfmove, fullmove = 0, startedAfterOpening and 2 or 1
while true do
    wait(SCAN_DELAY)
    local success, current = pcall(scan)
    if success and not sameSnapshot(previous, current) then
        wait(SCAN_DELAY)
        local stable, confirmed = pcall(scan)
        if stable and sameSnapshot(current, confirmed) then
            local moved, capture = {}, false
            for token, newSquare in pairs(confirmed) do
                local oldSquare = previous[token]
                if oldSquare and oldSquare ~= newSquare then moved[#moved + 1] = {token=token, from=oldSquare, to=newSquare, piece=pieceTypes[token]} end
            end
            for token in pairs(previous) do
                if not confirmed[token] then
                    capture = true
                    pieceTypes[token] = nil
                end
            end
            if #moved > 0 then
                local move = moved[1]
                if PLAY_AS == "White" or PLAY_AS == "Black" then
                    local wantedColor = PLAY_AS == "White" and "Black" or "White"
                    for _, candidate in ipairs(moved) do
                        if candidate.piece and candidate.piece:sub(1, 5) == wantedColor then
                            move = candidate
                            break
                        end
                    end
                    if not (move.piece and move.piece:sub(1, 5) == wantedColor) then
                        previous = confirmed
                        continue
                    end
                end
                if move.piece and move.piece:find("Pawn") then
                    local destinationRank = tonumber(move.to:sub(2, 2))
                    if destinationRank == 1 or destinationRank == 8 then
                        local color = move.piece:sub(1, 5)
                        pieceTypes[move.token] = color .. " Queen"
                        move.piece = pieceTypes[move.token]
                    end
                end
                print(string.format("[Chess] %s: %s -> %s", move.piece or "Unknown piece", move.from, move.to))
                whiteToMove = not (move.piece and move.piece:sub(1, 5) == "White")
                if (move.piece and move.piece:find("Pawn")) or capture then
                    halfmove = 0
                else
                    halfmove = halfmove + 1
                end
                if whiteToMove then
                    fullmove = fullmove + 1
                end
                local yourTurn = PLAY_AS == "Any"
                    or (PLAY_AS == "White" and whiteToMove)
                    or (PLAY_AS == "Black" and not whiteToMove)
                if yourTurn then
                    local fen = makeFen(confirmed, pieceTypes, whiteToMove, halfmove, fullmove)
                    local result, errorMessage = askStockfish(fen)
                    if result then
                        local fromSquare = result.bestmove:sub(1, 2)
                        local toSquare = result.bestmove:sub(3, 4)
                        local wantedPiece = "Unknown piece"
                        for token, square in pairs(confirmed) do
                            if square == fromSquare and pieceTypes[token] then
                                wantedPiece = pieceTypes[token]
                                break
                            end
                        end
                        local promotion = result.bestmove:sub(5, 5)
                        local suffix = promotion ~= "" and promotion ~= " " and " (promote)" or ""
                        local message = string.format("Move %s: %s -> %s%s", wantedPiece, fromSquare, toSquare, suffix)
                        print("[Stockfish] " .. message)
                        if notify then
                            notify(message, "Stockfish recommendation", 8)
                        else
                            print(message)
                        end
                    else
                        warn("Stockfish unavailable: " .. tostring(errorMessage))
                    end
                end
            end
            previous = confirmed
        end
    end
end

