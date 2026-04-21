-- ========================================================================
-- physics.lua
-- Pure Eulerian integration and bounding-volume collision math.
-- Slop-Gate Closure Edition.
-- ========================================================================
local max, min, abs = math.max, math.min, math.abs
local sqrt, cos, sin = math.sqrt, math.cos, math.sin

return function(
    Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
    Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    UniverseCage,
    Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
    Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
    BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
)
    -- The Pointers are locked as Upvalues here!
    return function(start_id, end_id, dt)
        local num_spheres = Count_BoundSphere and Count_BoundSphere[0] or 0
        local num_boxes = Count_BoundBox and Count_BoundBox[0] or 0

        for i = start_id, end_id do
            -- 1. Integrate Position and Rotation
            local vx, vy, vz = Obj_VelX[i], Obj_VelY[i], Obj_VelZ[i]
            local px, py, pz = Obj_X[i] + vx * dt, Obj_Y[i] + vy * dt, Obj_Z[i] + vz * dt

            local y_val = Obj_Yaw[i] + Obj_RotSpeedYaw[i] * dt
            local p_val = Obj_Pitch[i] + Obj_RotSpeedPitch[i] * dt
            Obj_Yaw[i], Obj_Pitch[i] = y_val, p_val

            local cy, sy = cos(y_val), sin(y_val)
            local cp, sp = cos(p_val), sin(p_val)
            local fwx, fwy, fwz = sy * cp, sp, cy * cp
            local rtx, rty, rtz = cy, 0, -sy

            Obj_FWX[i], Obj_FWY[i], Obj_FWZ[i] = fwx, fwy, fwz
            Obj_RTX[i], Obj_RTY[i], Obj_RTZ[i] = rtx, rty, rtz
            Obj_UPX[i] = fwy * rtz
            Obj_UPY[i] = fwz * rtx - fwx * rtz
            Obj_UPZ[i] = -fwy * rtx

            -- 2. Apply Global Cage (if active)
            if UniverseCage and UniverseCage.isActive then
                if px < UniverseCage.minX then px = UniverseCage.minX; vx = abs(vx) end
                if px > UniverseCage.maxX then px = UniverseCage.maxX; vx = -abs(vx) end
                if py < UniverseCage.minY then py = UniverseCage.minY; vy = abs(vy) end
                if py > UniverseCage.maxY then py = UniverseCage.maxY; vy = -abs(vy) end
                if pz < UniverseCage.minZ then pz = UniverseCage.minZ; vz = abs(vz) end
                if pz > UniverseCage.maxZ then pz = UniverseCage.maxZ; vz = -abs(vz) end
            end

            -- 3. Check Explicit Bounding Spheres
            for s = 0, num_spheres - 1 do
                local mode = BoundSphere_Mode[s]
                local sx, sy, sz = BoundSphere_X[s], BoundSphere_Y[s], BoundSphere_Z[s]
                local dx, dy, dz = px - sx, py - sy, pz - sz
                local distSq = dx*dx + dy*dy + dz*dz
                local rSq = BoundSphere_RSq[s]
                
                if mode == 3 then -- SOLID
                    if distSq < rSq then
                        local dist = sqrt(distSq)
                        if dist == 0 then dist = 1 end
                        local snx, sny, snz = dx/dist, dy/dist, dz/dist
                        local pen = sqrt(rSq) - dist
                        px, py, pz = px + snx * pen, py + sny * pen, pz + snz * pen
                        local dot = vx*snx + vy*sny + vz*snz
                        if dot < 0 then
                            local impulse = 1.75 * dot
                            vx, vy, vz = vx - impulse * snx, vy - impulse * sny, vz - impulse * snz
                            Obj_RotSpeedYaw[i] = Obj_RotSpeedYaw[i] * 0.99
                        end
                    end
                elseif mode == 1 then -- CONTAIN (Trap Inside)
                    local r = sqrt(rSq)
                    local outerShellSq = (r + 400) * (r + 400)
                    if distSq > rSq and distSq < outerShellSq then
                        local dist = sqrt(distSq)
                        if dist == 0 then dist = 1 end
                        local snx, sny, snz = dx/dist, dy/dist, dz/dist
                        local pen = dist - r
                        px, py, pz = px - snx * pen, py - sny * pen, pz - snz * pen
                        local dot = vx*snx + vy*sny + vz*snz
                        if dot > 0 then
                            local impulse = 1.75 * dot
                            vx, vy, vz = vx - impulse * snx, vy - impulse * sny, vz - impulse * snz
                            Obj_RotSpeedYaw[i] = Obj_RotSpeedYaw[i] * 0.99
                        end
                    end
                end
            end

            -- 4. Check Explicit Bounding Boxes
            for b = 0, num_boxes - 1 do
                if BoundBox_Mode[b] == 3 then -- SOLID
                    local bx, by, bz = BoundBox_X[b], BoundBox_Y[b], BoundBox_Z[b]
                    local dx, dy, dz = px - bx, py - by, pz - bz

                    local localX = dx * BoundBox_RTX[b] + dy * BoundBox_RTY[b] + dz * BoundBox_RTZ[b]
                    local localY = dx * BoundBox_UPX[b] + dy * BoundBox_UPY[b] + dz * BoundBox_UPZ[b]
                    local localZ = dx * BoundBox_FWX[b] + dy * BoundBox_FWY[b] + dz * BoundBox_FWZ[b]

                    if abs(localX) < BoundBox_HW[b] + 35 and abs(localY) < BoundBox_HH[b] + 35 and abs(localZ) < BoundBox_HT[b] + 35 then
                        local sign = localZ > 0 and 1 or -1
                        local pen = (BoundBox_HT[b] + 40) - abs(localZ)
                        px = px + BoundBox_FWX[b] * pen * sign
                        py = py + BoundBox_FWY[b] * pen * sign
                        pz = pz + BoundBox_FWZ[b] * pen * sign

                        local vDotN = vx * BoundBox_FWX[b] + vy * BoundBox_FWY[b] + vz * BoundBox_FWZ[b]
                        if (vDotN * sign) < 0 then
                            local impulse = 1.5 * vDotN
                            vx = vx - impulse * BoundBox_FWX[b]
                            vy = vy - impulse * BoundBox_FWY[b]
                            vz = vz - impulse * BoundBox_FWZ[b]
                        end
                    end
                end
            end

            -- Write final velocities and positions back to memory
            Obj_VelX[i], Obj_VelY[i], Obj_VelZ[i] = vx, vy, vz
            Obj_X[i], Obj_Y[i], Obj_Z[i] = px, py, pz
        end
    end
end
