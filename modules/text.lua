local ffi = require("ffi")
local bit = require("bit")
local max, min, floor, abs = math.max, math.min, math.floor, math.abs

local TextModule = {}

-- ========================================================================
-- [1] THE LOCAL SANDBOX & GC PROTECTION
-- ========================================================================
local my_obj_start, next_text_idx
local MAX_TEXT_NODES = 256
local TextCaches = {} -- Holds {ptr, w, h, _keepAlive, ...}

local ansi_to_love = {
    ["31"] = {1, 0.2, 0.2}, ["32"] = {0.2, 1, 0.2}, 
    ["33"] = {1, 1, 0.2},   ["36"] = {0.2, 1, 1}, 
    ["0"]  = {0, 0.8, 0}
}

-- ========================================================================
-- [2] THE STOLEN GOODIES (Lexer & Baker)
-- ========================================================================
local function ParseLine(rawText, fonts)
    if not rawText then return {} end
    local pipePos = rawText:find("|")
    if pipePos then
        local leftStr = rawText:sub(1, pipePos - 1):match("^%s*(.-)%s*$")
        local rightStr = rawText:sub(pipePos + 1):match("^%s*(.-)%s*$")
        local columns = ParseLine(leftStr, fonts)
        for _, col in ipairs(ParseLine(rightStr, fonts)) do table.insert(columns, col) end
        return columns
    end

    local cleanText = rawText
    local currentFont = fonts.body
    local currentAlign = "left"

    if cleanText:match("^~%s+") then cleanText = cleanText:gsub("^~%s+", ""); currentAlign = "center" end
    if cleanText:match("^#%s+") then cleanText = cleanText:gsub("^#%s+", ""); currentFont = fonts.head end

    local coloredTable, pureText = {}, ""
    local currentColor, lastPos = {1, 1, 1, 1}, 1

    for startPos, colorCode, endPos in cleanText:gmatch("()\27%[([%d;]*)m()") do
        if startPos > lastPos then
            local chunk = cleanText:sub(lastPos, startPos - 1)
            table.insert(coloredTable, currentColor); table.insert(coloredTable, chunk)
            pureText = pureText .. chunk
        end
        if colorCode == "0" or colorCode == "" then currentColor = {1, 1, 1, 1}
        elseif ansi_to_love[colorCode] then currentColor = {ansi_to_love[colorCode][1], ansi_to_love[colorCode][2], ansi_to_love[colorCode][3], 1} end
        lastPos = endPos
    end
    if lastPos <= #cleanText then
        local chunk = cleanText:sub(lastPos)
        table.insert(coloredTable, currentColor); table.insert(coloredTable, chunk)
        pureText = pureText .. chunk
    end
    if #coloredTable == 0 then coloredTable = {{1, 1, 1, 1}, cleanText}; pureText = cleanText end
    return {{ text = cleanText, pureText = pureText, coloredTable = coloredTable, font = currentFont, align = currentAlign }}
end

local function BakeText(contentStr, intended_depth)
    -- Borrowing the optimal scaling math from Method 1
    if abs(intended_depth) < 0.05 then intended_depth = 0.05 end
    local optimal_scale = (MainCamera.fov / intended_depth)
    if optimal_scale ~= optimal_scale or optimal_scale == math.huge then optimal_scale = 1.0 end

    -- Base virtual resolution
    local virtW, virtH = 2048, 2048 -- Large canvas for wrapping, we crop it later

    local fonts = {
        title = love.graphics.newFont(max(8, floor(100 * optimal_scale))),
        head  = love.graphics.newFont(max(8, floor(80 * optimal_scale))),
        body  = love.graphics.newFont(max(8, floor(50 * optimal_scale)))
    }

    local giantCanvas = love.graphics.newCanvas(virtW, virtH)
    love.graphics.setCanvas(giantCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    local currentY = floor(virtH * 0.05)
    local paddingX = floor(virtW * 0.05)
    local maxTextWidth = virtW - (paddingX * 2)

    -- Baking the lines
    local lines = {}
    for s in contentStr:gmatch("[^\r\n]+") do table.insert(lines, s) end

    for _, s in ipairs(lines) do
        if s ~= "" then
            local columns = ParseLine(s, fonts)
            local numCols = #columns
            local colWidth = floor(maxTextWidth / numCols)
            local maxRowHeight = 0
            
            for colIdx, colData in ipairs(columns) do
                love.graphics.setFont(colData.font)
                local xOffset = paddingX + ((colIdx - 1) * colWidth)
                local colPrintWidth = colWidth - (numCols > 1 and floor(virtW * 0.02) or 0) + 4
                
                local _, wrappedLines = colData.font:getWrap(colData.pureText, colPrintWidth)
                local colHeight = #wrappedLines * colData.font:getHeight()
                if colHeight > maxRowHeight then maxRowHeight = colHeight end
                
                love.graphics.printf(colData.coloredTable, floor(xOffset - 2), floor(currentY), colPrintWidth, colData.align)
            end
            currentY = currentY + maxRowHeight + floor(virtH * 0.005)
        else
            currentY = currentY + fonts.body:getHeight()
        end
    end

    local finalH = min(virtH, currentY + floor(virtH * 0.05))
    local croppedCanvas = love.graphics.newCanvas(virtW, finalH)
    love.graphics.setCanvas(croppedCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(giantCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()

    local imgData = croppedCanvas:newImageData()
    giantCanvas:release()
    croppedCanvas:release()

    return {
        ptr = ffi.cast("uint32_t*", imgData:getPointer()),
        w = virtW, h = finalH,
        _keepAlive = imgData,
        opt_scale = optimal_scale
    }
end

-- ========================================================================
-- [3] MODULE PUBLIC API (Spawning & GC)
-- ========================================================================
function TextModule.Spawn(x, y, z, textContent, intended_depth)
    if next_text_idx > my_obj_start + MAX_TEXT_NODES then return end
    local id = next_text_idx
    next_text_idx = next_text_idx + 1

    Obj_X[id], Obj_Y[id], Obj_Z[id] = x, y, z

    -- CRITICAL GC PROTECTION: If this slot was used before, free the VRAM/RAM!
    if TextCaches[id] and TextCaches[id]._keepAlive then
        TextCaches[id]._keepAlive:release()
    end

    TextCaches[id] = BakeText(textContent, intended_depth)
    return id
end

-- ========================================================================
-- [4] ENGINE PHASES
-- ========================================================================
function TextModule.Init()
    my_obj_start, _ = Memory.ClaimObjects(MAX_TEXT_NODES)
    next_text_idx = my_obj_start

    -- Test Spawn: A floating 3D text node
    TextModule.Spawn(0, 0, 0, "# THE PURE DOD PIPELINE\n~ \27[36mNO SLIDES. NO GLUE. JUST DATA.", 1000)
end

function TextModule.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
    local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
    local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
    local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
    local cam_fov = MainCamera.fov
    local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

    for id = my_obj_start, next_text_idx - 1 do
        local cache = TextCaches[id]
        if not cache then goto continue end

        -- 1. Project 3D World Anchor to Screen Space
        local vdx, vdy, vdz = Obj_X[id] - cpx, Obj_Y[id] - cpy, Obj_Z[id] - cpz
        local depth = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z
        
        -- Cull if it's behind the camera
        if depth < 10 then goto continue end

        -- 2. Calculate Screen Center (cx, cy)
        local f = cam_fov / depth
        local cx = HALF_W + (vdx*crt_x + vdz*crt_z) * f
        local cy = HALF_H + (vdx*cup_x + vdy*cup_y + vdz*cup_z) * f

        -- 3. Calculate Scale (Perspective relative to bake depth)
        --local draw_scale = f / cache.opt_scale

        -- OPTIMIZATION: If scale is very close to 1.0, snap it to 1.0 for perfect pixel mapping
        --if abs(draw_scale - 1.0) < 0.005 then
            draw_scale = 1.0
            cx = floor(cx + 0.5)
            cy = floor(cy + 0.5)
        --end

        -- 4. THE HYPER-OPTIMIZED UNADULTERATED FFI BLIT LOOP
        local ptr, tw, th = cache.ptr, cache.w, cache.h
        local sw, sh = floor(tw * draw_scale), floor(th * draw_scale)
        if sw <= 0 or sh <= 0 then goto continue end

        local startX, startY = floor(cx - sw * 0.5), floor(cy - sh * 0.5)
        local clipX, clipY = max(0, startX), max(0, startY)
        local endX, endY = min(CANVAS_W - 1, startX + sw - 1), min(CANVAS_H - 1, startY + sh - 1)
        
        local inv_scale = 1.0 / draw_scale
        local z_threshold = depth - 5 -- Pull it slightly forward so it doesn't z-fight its own anchor
        
        -- Default full opacity for now
        local global_a256 = 255 

        for y = clipY, endY do
            local ty = floor((y - startY) * inv_scale)
            if ty >= 0 and ty < th then
                local screenOff = y * CANVAS_W
                local buffOff = ty * tw
                for x = clipX, endX do
                    local tx = floor((x - startX) * inv_scale)
                    if tx >= 0 and tx < tw then
                        local px = ptr[buffOff + tx]
                        -- Check if text pixel is not transparent
                        if px >= 0x01000000 then
                            -- THE MAGIC: Depth check against the 3D world!
                            if ZBuffer[screenOff + x] >= z_threshold then
                                local pa = bit.rshift(px, 24)
                                local final_a = bit.rshift(pa * global_a256, 8)
                                if final_a > 0 then
                                    local bg = ScreenPtr[screenOff + x]
                                    local bg_r, bg_g, bg_b = bit.band(bit.rshift(bg, 16), 0xFF), bit.band(bit.rshift(bg, 8), 0xFF), bit.band(bg, 0xFF)
                                    local inv_a = 255 - final_a
                                    local r, g, b = bit.rshift(bg_r*inv_a, 8), bit.rshift(bg_g*inv_a, 8), bit.rshift(bg_b*inv_a, 8)
                                    ScreenPtr[screenOff + x] = bit.bor(0xFF000000, bit.lshift(r, 16), bit.lshift(g, 8), b)
                                end
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end
end

return TextModule
