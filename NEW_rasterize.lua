-- ========================================================================
-- rasterize.lua
-- Pure, branchless, flat-top/flat-bottom triangle rasterization.
-- Fully optimized for LuaJIT trace compilation (No FFI pointer math).
-- ========================================================================
local max, min, floor, ceil = math.max, math.min, math.floor, math.ceil

return function(x1, y1, z1, x2, y2, z2, x3, y3, z3, shadedColor, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    if y1 > y2 then x1, x2 = x2, x1; y1, y2 = y2, y1; z1, z2 = z2, z1 end
    if y1 > y3 then x1, x3 = x3, x1; y1, y3 = y3, y1; z1, z3 = z3, z1 end
    if y2 > y3 then x2, x3 = x3, x2; y2, y3 = y3, y2; z2, z3 = z3, z2 end

    local total_height = y3 - y1
    if total_height <= 0 then return end

    local inv_total = 1.0 / total_height
    local y_start = max(0, ceil(y1))
    local y_end   = min(CANVAS_H - 1, floor(y3))

    -- ==========================================
    -- UPPER TRIANGLE
    -- ==========================================
    local dy_upper = y2 - y1
    if dy_upper > 0 then
        local inv_upper = 1.0 / dy_upper
        local limit_y = min(y_end, floor(y2))

        for y = y_start, limit_y do
            local t_total = (y - y1) * inv_total
            local t_half  = (y - y1) * inv_upper
            local ax, az = x1 + (x3 - x1) * t_total, z1 + (z3 - z1) * t_total
            local bx, bz = x1 + (x2 - x1) * t_half,  z1 + (z2 - z1) * t_half

            if ax > bx then ax, bx = bx, ax; az, bz = bz, az end

            local row_width = bx - ax
            if row_width > 0 then
                local z_step = (bz - az) / row_width
                local start_x = max(0, ceil(ax))
                local end_x   = min(CANVAS_W - 1, floor(bx))
                local current_z = az + z_step * (start_x - ax)

                -- The God-Tier LuaJIT Indexing
                local off = y * CANVAS_W
                for x = start_x, end_x do
                    if current_z < ZBuffer[off + x] then
                        ZBuffer[off + x] = current_z
                        ScreenPtr[off + x] = shadedColor
                    end
                    current_z = current_z + z_step
                end
            end
        end
    end

    -- ==========================================
    -- LOWER TRIANGLE
    -- ==========================================
    local dy_lower = y3 - y2
    if dy_lower > 0 then
        local inv_lower = 1.0 / dy_lower
        local start_y = max(y_start, ceil(y2))

        for y = start_y, y_end do
            local t_total = (y - y1) * inv_total
            local t_half  = (y - y2) * inv_lower
            local ax, az = x1 + (x3 - x1) * t_total, z1 + (z3 - z1) * t_total
            local bx, bz = x2 + (x3 - x2) * t_half,  z2 + (z3 - z2) * t_half

            if ax > bx then ax, bx = bx, ax; az, bz = bz, az end

            local row_width = bx - ax
            if row_width > 0 then
                local z_step = (bz - az) / row_width
                local start_x = max(0, ceil(ax))
                local end_x   = min(CANVAS_W - 1, floor(bx))
                local current_z = az + z_step * (start_x - ax)

                -- The God-Tier LuaJIT Indexing
                local off = y * CANVAS_W
                for x = start_x, end_x do
                    if current_z < ZBuffer[off + x] then
                        ZBuffer[off + x] = current_z
                        ScreenPtr[off + x] = shadedColor
                    end
                    current_z = current_z + z_step
                end
            end
        end
    end
end
