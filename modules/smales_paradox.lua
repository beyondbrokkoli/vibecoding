local bit = require("bit")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi

local RenderMeshFactory = require("render_mesh_twotone")( ... )
return function(
    Memory, MainCamera,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
    Obj_RotSpeedYaw, Obj_RotSpeedPitch,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    local Paradox = {}
    local my_obj_start
    local time_alive = 0

    local LATITUDES = 40
    local LONGITUDES = 40
    local VCOUNT = (LATITUDES + 1) * (LONGITUDES + 1)
    local TCOUNT = LATITUDES * LONGITUDES * 2 -- No more double faces!
    local DrawMesh = RenderMeshFactory(
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
        Obj_Yaw[id], Obj_Pitch[id] = 0, 0
        Obj_RotSpeedYaw[id] = 0.5
        Obj_RotSpeedPitch[id] = 0.2
        Obj_Radius[id] = 7000

        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

        Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
        Obj_TriStart[id], Obj_TriCount[id] = tStart, TCOUNT

        local tIdx = tStart

        local col_gold = bit.bor(0xFF000000, bit.lshift(0, 16), bit.lshift(170, 8), 255)

        for i = 0, LATITUDES - 1 do
            for j = 0, LONGITUDES - 1 do
                local a = vStart + (i * (LONGITUDES + 1)) + j
                local b = vStart + (i * (LONGITUDES + 1)) + j + 1
                local c = vStart + ((i + 1) * (LONGITUDES + 1)) + j + 1
                local d = vStart + ((i + 1) * (LONGITUDES + 1)) + j

                -- JUST OUTSIDE FACES (Gold, CCW Winding)
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_BakedColor[tIdx] = col_gold; tIdx = tIdx + 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b; Tri_BakedColor[tIdx] = col_gold; tIdx = tIdx + 1
            end
        end
    end

    function Paradox.Tick(dt)
        time_alive = time_alive + dt
        local id = my_obj_start

        local y_val = Obj_Yaw[id] + Obj_RotSpeedYaw[id] * dt
        local p_val = Obj_Pitch[id] + Obj_RotSpeedPitch[id] * dt
        Obj_Yaw[id], Obj_Pitch[id] = y_val, p_val

        local cy, sy = math_cos(y_val), math_sin(y_val)
        local cp, sp = math_cos(p_val), math_sin(p_val)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = sy * cp, sp, cy * cp
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = cy, 0, -sy
        Obj_UPX[id] = Obj_FWY[id] * Obj_RTZ[id]
        Obj_UPY[id] = Obj_FWZ[id] * Obj_RTX[id] - Obj_FWX[id] * Obj_RTZ[id]
        Obj_UPZ[id] = -Obj_FWY[id] * Obj_RTX[id]

        -- THE EVERSION DEFORMATION MATH
        local t = time_alive * 0.8
        local eversion = math_cos(t) -- Pushes the poles through the center
        local bulge = math_sin(t)    -- Expands the equator to avoid the sharp crease

        local vStart = Obj_VertStart[id]
        local idx = vStart

        for i = 0, LATITUDES do
            local theta = (i / LATITUDES) * math_pi
            local ny = math_cos(theta)
            local sin_theta = math_sin(theta)

            for j = 0, LONGITUDES do
                local phi = (j / LONGITUDES) * math_pi * 2
                local nx = sin_theta * math_cos(phi)
                local nz = sin_theta * math_sin(phi)

                local r_base = 3500
                local r_main = r_base * eversion

                -- The "Corrugations" to prevent the singularity pinch-point
                local waves = math_cos(phi * 4.0)
                local twist = math_sin(theta * 2.0)
                local r_corrugate = r_base * bulge * waves * twist * 1.2

                -- Inject dynamic vertex data back into the SoA arrays
                Vert_LX[idx] = nx * r_main + nx * r_corrugate
                Vert_LY[idx] = ny * r_main + (math_cos(theta * 3.0) * r_base * bulge * 0.5)
                Vert_LZ[idx] = nz * r_main + nz * r_corrugate
                idx = idx + 1
            end
        end
    end

    function Paradox.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_start, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Paradox
end
