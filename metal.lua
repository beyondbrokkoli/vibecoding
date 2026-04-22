local bit = require("bit")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local RenderMeshTwoToneFactory = require("render")
local VibeMath = require("load") -- Add this!

return function(
    Memory, MainCamera,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    local Paradox = {}
    local my_obj_start
    local time_alive = 0
    
    -- Local variables for rotation so we don't need FFI arrays!
    local sphere_yaw = 0
    local sphere_pitch = 0

    -- local LATITUDES = 40
    -- local LONGITUDES = 40
    local LATITUDES = 500
    local LONGITUDES = 500
    local VCOUNT = (LATITUDES + 1) * (LONGITUDES + 1)
    local TCOUNT = LATITUDES * LONGITUDES * 2 -- PURIFIED: No double faces needed!

    local DrawMesh = RenderMeshTwoToneFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    function Paradox.Init()
        my_obj_start, _ = Memory.ClaimObjects(1)
        local id = my_obj_start

        local vStart, tStart = Memory.ClaimGeometry(VCOUNT, TCOUNT)

        Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, 3000, 0
        Obj_Radius[id] = 7000

        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

        Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
        Obj_TriStart[id], Obj_TriCount[id] = tStart, TCOUNT

        local tIdx = tStart

        -- Bake it pure Gold. The Two-Tone pipeline will handle the Purple inside.
        local col_gold = bit.bor(0xFF000000, bit.lshift(0, 16), bit.lshift(170, 8), 255)

        for i = 0, LATITUDES - 1 do
            for j = 0, LONGITUDES - 1 do
                local a = vStart + (i * (LONGITUDES + 1)) + j
                local b = vStart + (i * (LONGITUDES + 1)) + j + 1
                local c = vStart + ((i + 1) * (LONGITUDES + 1)) + j + 1
                local d = vStart + ((i + 1) * (LONGITUDES + 1)) + j

                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_BakedColor[tIdx] = col_gold; tIdx = tIdx + 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b; Tri_BakedColor[tIdx] = col_gold; tIdx = tIdx + 1
            end
        end
    end

    function Paradox.Tick(dt)
        time_alive = time_alive + dt
        local id = my_obj_start

        -- Apply local rotation
        sphere_yaw = sphere_yaw + 0.5 * dt/8
        sphere_pitch = sphere_pitch + 0.2 * dt/8

        local cy, sy = math_cos(sphere_yaw), math_sin(sphere_yaw)
        local cp, sp = math_cos(sphere_pitch), math_sin(sphere_pitch)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = sy * cp, sp, cy * cp
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = cy, 0, -sy
        Obj_UPX[id] = Obj_FWY[id] * Obj_RTZ[id]
        Obj_UPY[id] = Obj_FWZ[id] * Obj_RTX[id] - Obj_FWX[id] * Obj_RTZ[id]
        Obj_UPZ[id] = -Obj_FWY[id] * Obj_RTX[id]

        local t = time_alive * 0.05
        local eversion = math_cos(t)
        local bulge = math_sin(t)

        local vStart = Obj_VertStart[id]
        local r_base = 3500

        -- THE LIVING METAL C-KERNEL TAKEOVER
        VibeMath.generate_living_metal_vertices(
            Vert_LX + vStart, Vert_LY + vStart, Vert_LZ + vStart,
            LATITUDES, LONGITUDES,
            r_base, time_alive
        )
    end

    function Paradox.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_start, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Paradox
end
