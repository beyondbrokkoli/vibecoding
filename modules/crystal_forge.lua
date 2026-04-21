local bit = require("bit")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local sqrt, abs, floor, min, max = math.sqrt, math.abs, math.floor, math.min, math.max

local RenderMeshFactory = require("render_mesh")

return function(
    Memory, MainCamera,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    local Forge = {}
    local my_obj_start, my_obj_end

    local DrawMesh = RenderMeshFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    local MAX_TILES = 150
    local CHUNK_LENGTH = 400
    local SEGMENTS = 12
    local SIDES = 16 -- Keep it a multiple of 4 to make sharp crosses/stars
    local BASE_RADIUS = 350
    local VCOUNT = (SEGMENTS + 1) * SIDES
    local TCOUNT = SEGMENTS * SIDES * 2
    local spawn_count, next_spawn_s, spawn_timer = 0, 0, 0
    local SPAWN_DELAY = 0.04

    -- A highly chaotic, unpredictable Lissajous path
    local function getSpine(s)
        local t = s * 0.00015
        local x = math_sin(t * 3.0) * 5000 + math_cos(t * 7.1) * 1500
        local y = 4000 + math_sin(t * 4.2) * 3500 + math_cos(t * 5.5) * 1000
        local z = math_cos(t * 3.0) * 5000 + math_sin(t * 8.3) * 1500
        return x, y, z
    end

    function Forge.Init()
        my_obj_start, my_obj_end = Memory.ClaimObjects(MAX_TILES)
        for id = my_obj_start, my_obj_end do
            local vStart, tStart = Memory.ClaimGeometry(VCOUNT, TCOUNT)
            Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
            Obj_TriStart[id], Obj_TriCount[id] = tStart, TCOUNT
            Obj_Radius[id] = 2500 -- Large culling radius for the huge spikes
            
            Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
            Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
            Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

            local tIdx = tStart
            for i = 0, SEGMENTS - 1 do
                for j = 0, SIDES - 1 do
                    local next_j = (j + 1) % SIDES
                    local a = vStart + i * SIDES + j
                    local b = vStart + (i + 1) * SIDES + j
                    local c = vStart + (i + 1) * SIDES + next_j
                    local d = vStart + i * SIDES + next_j
                    Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b; tIdx = tIdx + 1
                    Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; tIdx = tIdx + 1
                end
            end
            Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, -99999, 0
        end
    end

    function Forge.Tick(dt)
        spawn_timer = spawn_timer + dt
        while spawn_timer >= SPAWN_DELAY do
            spawn_timer = spawn_timer - SPAWN_DELAY
            local slot = spawn_count % MAX_TILES
            local id = my_obj_start + slot

            local cx, cy, cz = getSpine(next_spawn_s + CHUNK_LENGTH * 0.5)
            Obj_X[id], Obj_Y[id], Obj_Z[id] = cx, cy, cz

            local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]

            -- Metallic Synthwave Color Palette (Magenta / Gold / Obsidian)
            local tIdx = tStart
            for i = 0, SEGMENTS - 1 do
                local global_s = next_spawn_s + (i / SEGMENTS) * CHUNK_LENGTH
                for j = 0, SIDES - 1 do
                    -- Fake harsh directional light by alternating face colors
                    local is_ridge = (j % 4 == 0)
                    local r, g, b = 20, 20, 25 -- Obsidian base
                    
                    if is_ridge then
                        -- Bright glowing ridges
                        local glow = (math_sin(global_s * 0.005) * 0.5 + 0.5)
                        r = floor(255 * glow)
                        g = floor(150 * glow)
                        b = 255
                    else
                        -- Gold/Bronze side panels
                        r, g, b = 180, 120, 40
                    end
                    
                    -- Add a geometric shadow pattern
                    if (i + j) % 2 == 0 then
                        r, g, b = floor(r * 0.6), floor(g * 0.6), floor(b * 0.6)
                    end

                    local face_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)
                    Tri_BakedColor[tIdx] = face_color; tIdx = tIdx + 1
                    Tri_BakedColor[tIdx] = face_color; tIdx = tIdx + 1
                end
            end

            -- The Crystalline Extrusion Math
            for i = 0, SEGMENTS do
                local segment_s = next_spawn_s + (i / SEGMENTS) * CHUNK_LENGTH
                local px, py, pz = getSpine(segment_s)
                local nx, ny, nz = getSpine(segment_s + 1.0)
                local tx, ty, tz = nx - px, ny - py, nz - pz
                local upx, upy, upz = 0, 1, 0
                if abs(ty) > 0.99 then upx, upy, upz = 1, 0, 0 end

                local bx, by, bz = ty * upz - tz * upy, tz * upx - tx * upz, tx * upy - ty * upx
                local bLen = sqrt(bx*bx + by*by + bz*bz); if bLen == 0 then bLen = 1 end
                bx, by, bz = bx/bLen, by/bLen, bz/bLen

                local normX, normY, normZ = by * tz - bz * ty, bz * tx - bx * tz, bx * ty - by * tx
                local nLen = sqrt(normX*normX + normY*normY + normZ*normZ); if nLen == 0 then nLen = 1 end
                normX, normY, normZ = normX/nLen, normY/nLen, normZ/nLen

                -- This is where the magic happens: We morph the cross-section!
                local twist_factor = segment_s * 0.002 -- The whole shape spirals
                local pulse_factor = math_sin(segment_s * 0.001) -- It thickens and thins

                for j = 0, SIDES - 1 do
                    local base_angle = (j / SIDES) * math_pi * 2
                    local v_angle = base_angle + twist_factor
                    
                    -- Create a 4-pointed star/crystal shape
                    local spike_multiplier = 1.0 + 0.8 * math_sin(base_angle * 4) * pulse_factor
                    local final_radius = BASE_RADIUS * spike_multiplier

                    local cosV, sinV = math_cos(v_angle) * final_radius, math_sin(v_angle) * final_radius
                    local vIdx = vStart + i * SIDES + j
                    
                    Vert_LX[vIdx] = (px - cx) + normX * cosV + bx * sinV
                    Vert_LY[vIdx] = (py - cy) + normY * cosV + by * sinV
                    Vert_LZ[vIdx] = (pz - cz) + normZ * cosV + bz * sinV
                end
            end
            spawn_count = spawn_count + 1
            next_spawn_s = next_spawn_s + CHUNK_LENGTH
        end
    end

    function Forge.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_end, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Forge
end
