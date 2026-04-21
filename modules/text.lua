local ffi = require("ffi")
local bit = require("bit")
local max, min, floor, abs = math.max, math.min, math.floor, math.abs

local TextModule = {}

-- ========================================================================
-- [1] THE LOCAL SANDBOX & GC PROTECTION
-- ========================================================================
local my_obj_start, next_text_idx
local MAX_TEXT_NODES = 256
local TextCaches = {} -- Holds {ptr, w, h, _keepAlive, ox, oy}

local ansi_to_love = {
    ["30"] = {0.1, 0.1, 0.1}, -- Black/Dark Gray
    ["31"] = {1, 0.2, 0.2},   -- Red
    ["32"] = {0.2, 1, 0.2},   -- Green
    ["33"] = {1, 1, 0.2},     -- Yellow
    ["36"] = {0.2, 1, 1},     -- Cyan
    ["0"]  = {0, 0, 0}        -- Defaulting to Black for bright backgrounds!
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
    local currentColor, lastPos = {0, 0, 0, 1}, 1 -- Default to black text

    for startPos, colorCode, endPos in cleanText:gmatch("()\27%[([%d;]*)m()") do
        if startPos > lastPos then
            local chunk = cleanText:sub(lastPos, startPos - 1)
            table.insert(coloredTable, currentColor); table.insert(coloredTable, chunk)
            pureText = pureText .. chunk
        end
        if colorCode == "0" or colorCode == "" then currentColor = {0, 0, 0, 1}
        elseif ansi_to_love[colorCode] then currentColor = {ansi_to_love[colorCode][1], ansi_to_love[colorCode][2], ansi_to_love[colorCode][3], 1} end
        lastPos = endPos
    end
    if lastPos <= #cleanText then
        local chunk = cleanText:sub(lastPos)
        table.insert(coloredTable, currentColor); table.insert(coloredTable, chunk)
        pureText = pureText .. chunk
    end
    if #coloredTable == 0 then coloredTable = {{0, 0, 0, 1}, cleanText}; pureText = cleanText end
    return {{ text = cleanText, pureText = pureText, coloredTable = coloredTable, font = currentFont, align = currentAlign }}
end

local function BakeText(contentStr, intended_depth, has_background)
    if abs(intended_depth) < 0.05 then intended_depth = 0.05 end
    local optimal_scale = (MainCamera.fov / intended_depth)
    if optimal_scale ~= optimal_scale or optimal_scale == math.huge then optimal_scale = 1.0 end

    local virtW, virtH = 2048, 2048 

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
    local measuredWidth = 0 -- Track the actual used width

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
                
                local width, wrappedLines = colData.font:getWrap(colData.pureText, colPrintWidth)
                if width > measuredWidth then measuredWidth = width end

                local colHeight = #wrappedLines * colData.font:getHeight()
                if colHeight > maxRowHeight then maxRowHeight = colHeight end
                
                love.graphics.printf(colData.coloredTable, floor(xOffset - 2), floor(currentY), colPrintWidth, colData.align)
            end
            currentY = currentY + maxRowHeight + floor(virtH * 0.005)
        else
            currentY = currentY + fonts.body:getHeight()
        end
    end

    -- Dynamically crop to the EXACT bounds of the text for a tight HUD background
    local finalW = min(virtW, measuredWidth + (paddingX * 2))
    local finalH = min(virtH, currentY + floor(virtH * 0.05))
    
    local croppedCanvas = love.graphics.newCanvas(finalW, finalH)
    love.graphics.setCanvas(croppedCanvas)
    love.graphics.clear(0, 0, 0, 0)
    
    -- Draw the Bright HUD Plate
    if has_background then
        love.graphics.setColor(0.95, 0.95, 0.95, 0.85) -- Off-white, slightly transparent
        love.graphics.rectangle("fill", 0, 0, finalW, finalH, 12 * optimal_scale, 12 * optimal_scale)
        -- Optional: Add a crisp border
        love.graphics.setLineWidth(2 * optimal_scale)
        love.graphics.setColor(0.5, 1.0, 0.8, 0.9) -- Ubisoft Cyan Border
        love.graphics.rectangle("line", 0, 0, finalW, finalH, 12 * optimal_scale, 12 * optimal_scale)
    end

    -- Draw the text over the background
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(giantCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()

    local imgData = croppedCanvas:newImageData()
    giantCanvas:release()
    croppedCanvas:release()

    return {
        ptr = ffi.cast("uint32_t*", imgData:getPointer()),
        w = finalW, h = finalH,
        _keepAlive = imgData
    }
end

-- ========================================================================
-- [3] MODULE PUBLIC API (Spawning & GC)
-- ========================================================================
-- NEW: offsetX and offsetY allow 2D screen shifting away from the 3D anchor!
function TextModule.Spawn(x, y, z, textContent, intended_depth, offsetX, offsetY, has_background)
    if next_text_idx > my_obj_start + MAX_TEXT_NODES then return end
    local id = next_text_idx
    next_text_idx = next_text_idx + 1

    Obj_X[id], Obj_Y[id], Obj_Z[id] = x, y, z

    if TextCaches[id] and TextCaches[id]._keepAlive then
        TextCaches[id]._keepAlive:release()
    end

    TextCaches[id] = BakeText(textContent, intended_depth, has_background)
    TextCaches[id].ox = offsetX or 0
    TextCaches[id].oy = offsetY or 0
    return id
end

-- ========================================================================
-- [4] ENGINE PHASES
-- ========================================================================
function TextModule.Init()
    my_obj_start, _ = Memory.ClaimObjects(MAX_TEXT_NODES)
    next_text_idx = my_obj_start

    -- Test Spawn: Notice we are passing Screen Offsets and forcing the Background!
    TextModule.Spawn(0, 0, 0, "# TARGET AQUIRED\n~ \27[31mWARNING: Z-Buffer Anomaly Detected.", 1000, 150, -100, true)
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

        local vdx, vdy, vdz = Obj_X[id] - cpx, Obj_Y[id] - cpy, Obj_Z[id] - cpz
        local depth = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z
        
        if depth < 10 then goto continue end

        local f = cam_fov / depth
        
        -- Apply the 2D Screen Offsets here!
        local cx = HALF_W + (vdx*crt_x + vdz*crt_z) * f + cache.ox
        local cy = HALF_H + (vdx*cup_x + vdy*cup_y + vdz*cup_z) * f + cache.oy

        cx = floor(cx + 0.5)
        cy = floor(cy + 0.5)

        local ptr, tw, th = cache.ptr, cache.w, cache.h
        local sw, sh = tw, th 
        if sw <= 0 or sh <= 0 then goto continue end

        local startX, startY = floor(cx - sw * 0.5), floor(cy - sh * 0.5)
        local clipX, clipY = max(0, startX), max(0, startY)
        local endX, endY = min(CANVAS_W - 1, startX + sw - 1), min(CANVAS_H - 1, startY + sh - 1)
        
        local z_threshold = depth - 5 
        local global_a256 = 255 

        for y = clipY, endY do
            local ty = y - startY 
            if ty >= 0 and ty < th then
                local screenOff = y * CANVAS_W
                local buffOff = ty * tw
                for x = clipX, endX do
                    local tx = x - startX 
                    if tx >= 0 and tx < tw then
                        local px = ptr[buffOff + tx]
                        if px >= 0x01000000 then
                            if ZBuffer[screenOff + x] >= z_threshold then
                                -- THE TRUE ALPHA BLENDING FIX
                                local src_a = bit.rshift(px, 24)
                                local final_a = bit.rshift(src_a * global_a256, 8)
                                
                                if final_a > 0 then
                                    local src_r = bit.band(bit.rshift(px, 16), 0xFF)
                                    local src_g = bit.band(bit.rshift(px, 8), 0xFF)
                                    local src_b = bit.band(px, 0xFF)

                                    local bg = ScreenPtr[screenOff + x]
                                    local bg_r = bit.band(bit.rshift(bg, 16), 0xFF)
                                    local bg_g = bit.band(bit.rshift(bg, 8), 0xFF)
                                    local bg_b = bit.band(bg, 0xFF)
                                    
                                    local inv_a = 255 - final_a
                                    
                                    -- Blend Source and Destination cleanly
                                    local r = bit.rshift(src_r * final_a + bg_r * inv_a, 8)
                                    local g = bit.rshift(src_g * final_a + bg_g * inv_a, 8)
                                    local b = bit.rshift(src_b * final_a + bg_b * inv_a, 8)
                                    
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
