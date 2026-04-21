local max, min, floor, ceil, abs = math.max, math.min, math.floor, math.ceil, math.abs

return function (x1,y1,z1, x2,y2,z2, x3,y3,z3, shadedColor, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    if y1 > y2 then x1,x2 = x2,x1
        y1,y2 = y2,y1
        z1,z2 = z2,z1 end
    if y1 > y3 then x1,x3 = x3,x1
        y1,y3 = y3,y1
        z1,z3 = z3,z1 end
    if y2 > y3 then x2,x3 = x3,x2
        y2,y3 = y3,y2
        z2,z3 = z3,z2 end
    local total_height = y3 - y1
    if total_height <= 0 then return end
    local inv_total = 1.0 / total_height
    local y_start, y_end = max(0, ceil(y1)), min(CANVAS_H - 1, floor(y3))
    for y = y_start, y_end do
        local is_upper = y < y2
        local x_a, x_b, z_a, z_b
        if is_upper then
            local dy = y2 - y1
            if dy == 0 then dy = 1 end
            local t_a, t_b = (y-y1)*inv_total, (y-y1)/dy
            x_a, z_a = x1+(x3-x1)*t_a, z1+(z3-z1)*t_a
            x_b, z_b = x1+(x2-x1)*t_b, z1+(z2-z1)*t_b
        else
            local dy = y3 - y2
            if dy == 0 then dy = 1 end
            local t_a, t_b = (y-y1)*inv_total, (y-y2)/dy
            x_a, z_a = x1+(x3-x1)*t_a, z1+(z3-z1)*t_a
            x_b, z_b = x2+(x3-x2)*t_b, z2+(z3-z2)*t_b
        end
        if x_a > x_b then x_a,x_b = x_b,x_a
            z_a,z_b = z_b,z_a end
        local rw = x_b - x_a
        if rw > 0 then
            local z_step = (z_b - z_a) / rw
            local start_x, end_x = max(0, ceil(x_a)), min(CANVAS_W - 1, floor(x_b))
            local cz = z_a + z_step * (start_x - x_a)
            local off = y * CANVAS_W
            for x = start_x, end_x do
                if cz < ZBuffer[off + x] then ZBuffer[off + x] = cz
                    ScreenPtr[off + x] = shadedColor end
                cz = cz + z_step
            end
        end
    end
end
