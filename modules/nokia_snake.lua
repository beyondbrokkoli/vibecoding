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
    local SnakeModule = {}
    local my_obj_start, my_obj_end
    
    local DrawMesh = RenderMeshFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    local MAX_TILES = 100
    local CHUNK_LENGTH = 500
    local SEGMENTS = 16
    local SIDES = 24
    local TUBE_RADIUS = 200
    local VCOUNT = (SEGMENTS + 1) * SIDES
    local TCOUNT = SEGMENTS * SIDES * 2
    local spawn_count, next_spawn_s, spawn_timer = 0, 0, 0
    local SPAWN_DELAY = 0.05

    local function getSpine(s)
        local t = s * 0.0002
        local r = 3500 + math_sin(t * 4.1) * 1500
        local x = math_sin(t * 2.5) * r
        local z = math_cos(t * 2.5) * r
        local macro_t = s * 0.00005
        local y = 4400 - math_cos(macro_t) * 4000
        y = y + math_sin(t * 3.7) * 600
        return x, y, z
    end

    function SnakeModule.Init()
        my_obj_start, my_obj_end = Memory.ClaimObjects(MAX_TILES)
        for id = my_obj_start, my_obj_end do
            local vStart, tStart = Memory.ClaimGeometry(VCOUNT, TCOUNT)
            Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
            Obj_TriStart[id], Obj_TriCount[id] = tStart, TCOUNT
            Obj_Radius[id] = 1800
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

    function SnakeModule.Tick(dt)
        spawn_timer = spawn_timer + dt
        while spawn_timer >= SPAWN_DELAY do
            spawn_timer = spawn_timer - SPAWN_DELAY
            local slot = spawn_count % MAX_TILES
            local id = my_obj_start + slot
            
            local cx, cy, cz = getSpine(next_spawn_s + CHUNK_LENGTH * 0.5)
            Obj_X[id], Obj_Y[id], Obj_Z[id] = cx, cy, cz
            
            local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
            local phase = next_spawn_s * 0.00005
            local intensity = (math_sin(phase * 15) + 1.0) * 0.5
            local r_base = (0.1 + intensity * 0.6) * 255
            local g_base = (0.4 + intensity * 0.4) * 255
            local b_base = (0.7 + intensity * 0.3) * 255
            
            local tIdx = tStart
            for i = 0, SEGMENTS - 1 do
                for j = 0, SIDES - 1 do
                    local v_angle = (j / SIDES) * math_pi * 2
                    local angle_val = (math_sin(v_angle) + math_cos(v_angle)) * 0.7071
                    local light_factor = 0.3 + 0.7 * (angle_val * 0.5 + 0.5)
                    local r = min(255, floor(r_base * light_factor))
                    local g = min(255, floor(g_base * light_factor))
                    local b = min(255, floor(b_base * light_factor))
                    local face_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)
                    Tri_BakedColor[tIdx] = face_color; tIdx = tIdx + 1
                    Tri_BakedColor[tIdx] = face_color; tIdx = tIdx + 1
                end
            end
            
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
                
                for j = 0, SIDES - 1 do
                    local v_angle = (j / SIDES) * math_pi * 2
                    local cosV, sinV = math_cos(v_angle) * TUBE_RADIUS, math_sin(v_angle) * TUBE_RADIUS
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

    function SnakeModule.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_end, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return SnakeModule
end
