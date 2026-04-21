-- ========================================================================
-- modules/megaknot.lua
-- The Ultimate Benchmark: 240,000 Triangles in a single object.
-- ========================================================================
local bit = require("bit")
local pi, cos, sin = math.pi, math.cos, math.sin
local floor, sqrt, abs = math.floor, math.sqrt, math.abs

local RasterizeTriangle = require("rasterize")

return function(
    Memory, MainCamera,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
    Obj_RotSpeedYaw, Obj_RotSpeedPitch,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    local Megaknot = {}
    local my_obj_start

    function Megaknot.Init()
        my_obj_start, _ = Memory.ClaimObjects(1)
        local id = my_obj_start

        local cx, cy, cz = 0, 4000, 0 -- Place it dead center, above the snake orbit
        local scale = 1500
        local tubeRadius = 400
        local p, q = 4, 9
        local segments, sides = 800, 150
        local baseColor = 0xFFFF00FF -- Hot Magenta

        local vCount, tCount = segments * sides, segments * sides * 2
        local vStart, tStart = Memory.ClaimGeometry(vCount, tCount)

        Obj_X[id], Obj_Y[id], Obj_Z[id] = cx, cy, cz
        Obj_Yaw[id], Obj_Pitch[id] = 0, 0
        Obj_RotSpeedYaw[id] = 0.8
        Obj_RotSpeedPitch[id] = -0.4
        Obj_Radius[id] = scale * 3
        
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

        Obj_VertStart[id], Obj_VertCount[id] = vStart, vCount
        Obj_TriStart[id], Obj_TriCount[id] = tStart, tCount

        local function getKnotPos(u)
            local theta = u * pi * 2
            local r = scale * (2 + cos(p * theta))
            return r * cos(q * theta), r * sin(p * theta), r * sin(q * theta)
        end

        -- 1. Calculate Frenet-Serret Frames and Vertices
        for i = 0, segments - 1 do
            local u = i / segments
            local p1 = {getKnotPos(u)}
            local p2 = {getKnotPos((i + 1) / segments)}
            local T = {p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]}
            local B = {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]}
            local N = {T[2]*B[3] - T[3]*B[2], T[3]*B[1] - T[1]*B[3], T[1]*B[2] - T[2]*B[1]}

            local lenN = sqrt(N[1]^2 + N[2]^2 + N[3]^2)
            if lenN == 0 then lenN = 1 end
            N = {N[1]/lenN, N[2]/lenN, N[3]/lenN}

            local bitan = {T[2]*N[3] - T[3]*N[2], T[3]*N[1] - T[1]*N[3], T[1]*N[2] - T[2]*N[1]}
            local lenB = sqrt(bitan[1]^2 + bitan[2]^2 + bitan[3]^2)
            if lenB == 0 then lenB = 1 end
            bitan = {bitan[1]/lenB, bitan[2]/lenB, bitan[3]/lenB}

            for j = 0, sides - 1 do
                local v_angle = (j / sides) * pi * 2
                local cosV, sinV = cos(v_angle) * tubeRadius, sin(v_angle) * tubeRadius
                local vIdx = vStart + i * sides + j
                Vert_LX[vIdx] = p1[1] + cosV * N[1] + sinV * bitan[1]
                Vert_LY[vIdx] = p1[2] + cosV * N[2] + sinV * bitan[2]
                Vert_LZ[vIdx] = p1[3] + cosV * N[3] + sinV * bitan[3]
            end
        end

        -- 2. Stitch the Triangles
        local tIdx = tStart
        for i = 0, segments - 1 do
            local next_i = (i + 1) % segments
            for j = 0, sides - 1 do
                local next_j = (j + 1) % sides
                local a, b_idx = vStart + i * sides + j, vStart + next_i * sides + j
                local c, d = vStart + next_i * sides + next_j, vStart + i * sides + next_j

                -- Checkerboard styling written directly to BakedColor
                local col = ((i + j) % 2 == 0) and baseColor or 0xFF444444
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx
                Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c
                Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
            end
        end
    end

    function Megaknot.Tick(dt)
        local id = my_obj_start
        
        -- Simple local Euler rotation (No need to invoke the whole physics engine for one object)
        local y_val = Obj_Yaw[id] + Obj_RotSpeedYaw[id] * dt
        local p_val = Obj_Pitch[id] + Obj_RotSpeedPitch[id] * dt
        Obj_Yaw[id], Obj_Pitch[id] = y_val, p_val

        local cy, sy = cos(y_val), sin(y_val)
        local cp, sp = cos(p_val), sin(p_val)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = sy * cp, sp, cy * cp
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = cy, 0, -sy
        Obj_UPX[id] = Obj_FWY[id] * Obj_RTZ[id]
        Obj_UPY[id] = Obj_FWZ[id] * Obj_RTX[id] - Obj_FWX[id] * Obj_RTZ[id]
        Obj_UPZ[id] = -Obj_FWY[id] * Obj_RTX[id]
    end

    function Megaknot.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        local cam_fov = MainCamera.fov
        local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

        local id = my_obj_start
        local r = Obj_Radius[id]
        local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]

        local cz_center = (ox-cpx)*cfw_x + (oy-cpy)*cfw_y + (oz-cpz)*cfw_z
        if cz_center + r < 0.1 then return end

        local rx, rz = Obj_RTX[id], Obj_RTZ[id]
        local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
        local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]
        local vStart, vCount = Obj_VertStart[id], Obj_VertCount[id]

        for i = 0, vCount - 1 do
            local idx = vStart + i
            local lvx, lvy, lvz = Vert_LX[idx], Vert_LY[idx], Vert_LZ[idx]
            local wx = ox + lvx*rx + lvy*ux + lvz*fx
            local wy = oy + lvy*uy + lvz*fy
            local wz = oz + lvx*rz + lvy*uz + lvz*fz
            
            local vdx, vdy, vdz = wx-cpx, wy-cpy, wz-cpz
            local cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z
            
            if cz < 0.1 then Vert_Valid[idx] = false else
                local f = cam_fov / cz
                Vert_PX[idx] = HALF_W + (vdx*crt_x + vdz*crt_z) * f
                Vert_PY[idx] = HALF_H + (vdx*cup_x + vdy*cup_y + vdz*cup_z) * f
                Vert_PZ[idx] = cz * 1.004
                Vert_Valid[idx] = true
            end
        end

        local tStart, tCount = Obj_TriStart[id], Obj_TriCount[id]
        for i = 0, tCount - 1 do
            local idx = tStart + i
            local i1, i2, i3 = Tri_V1[idx], Tri_V2[idx], Tri_V3[idx]
            
            if Vert_Valid[i1] and Vert_Valid[i2] and Vert_Valid[i3] then
                local px1, py1, pz1 = Vert_PX[i1], Vert_PY[i1], Vert_PZ[i1]
                local px2, py2, pz2 = Vert_PX[i2], Vert_PY[i2], Vert_PZ[i2]
                local px3, py3, pz3 = Vert_PX[i3], Vert_PY[i3], Vert_PZ[i3]
                
                -- Backface culling
                if (px2-px1)*(py3-py1) - (py2-py1)*(px3-px1) < 0 then
                    RasterizeTriangle(px1,py1,pz1, px2,py2,pz2, px3,py3,pz3, Tri_BakedColor[idx], CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
                end
            end
        end
    end

    return Megaknot
end
