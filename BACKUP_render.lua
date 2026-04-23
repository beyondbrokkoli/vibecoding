-- ========================================================================
-- render_mesh_twotone.lua
-- Pure 3D-to-2D Projection & Culling Pipeline.
-- Dynamic Face-Color Swapping & Real-Time Lambertian Flat Shading
-- ========================================================================
local ffi = require("ffi")

local VibeMath = require("load")

local max, min, floor, abs, sqrt = math.max, math.min, math.floor, math.abs, math.sqrt

return function(
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    return function(start_id, end_id, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        local cam_fov = MainCamera.fov
        local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

        -- [THE SUN] Directional Light pointing Down, Right, and Forward
        local sun_x, sun_y, sun_z = 0.577, -0.577, 0.577

        for id = start_id, end_id do
            local r = Obj_Radius[id]
            local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]

            local cz_center = (ox-cpx)*cfw_x + (oy-cpy)*cfw_y + (oz-cpz)*cfw_z
            if cz_center + r < 0.1 then goto skip_tile end

            -- Cache the Object's Rotation Matrix
            local rx, ry, rz = Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id]
            local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
            local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]
            local vStart, vCount = Obj_VertStart[id], Obj_VertCount[id]

            -- THE SIMD VOLLEY: Local -> World -> Screen in one shot
            -- ==========================================================
            VibeMath.simd_project_vertices(
                vCount,
                Vert_LX + vStart, Vert_LY + vStart, Vert_LZ + vStart,
                Vert_PX + vStart, Vert_PY + vStart, Vert_PZ + vStart, Vert_Valid + vStart,
                ox, oy, oz, rx, ry, rz, ux, uy, uz, fx, fy, fz,
                cpx, cpy, cpz, cfw_x, cfw_y, cfw_z, crt_x, crt_z, cup_x, cup_y, cup_z,
                cam_fov, HALF_W, HALF_H
            )

            -- ==========================================================
            -- PASS 3: Triangle Assembly & Lighting (C-Kernel)
            -- ==========================================================
            local tStart, tCount = Obj_TriStart[id], Obj_TriCount[id]

            VibeMath.process_triangles_cull(
                tCount,
                Tri_V1 + tStart, Tri_V2 + tStart, Tri_V3 + tStart, Vert_Valid,
                Vert_PX, Vert_PY, Vert_PZ,
                Vert_LX, Vert_LY, Vert_LZ,
                Tri_BakedColor + tStart, Tri_ShadedColor + tStart, Tri_Valid + tStart,
                rx, ry, rz, ux, uy, uz, fx, fy, fz,
                sun_x, sun_y, sun_z
            )

            -- ==========================================================
            -- PASS 4: Rasterization Dispatch (C-Batch)
            -- ==========================================================
            VibeMath.rasterize_triangles_batch(
                tCount,
                Tri_V1 + tStart, Tri_V2 + tStart, Tri_V3 + tStart, Tri_Valid + tStart,
                Vert_PX, Vert_PY, Vert_PZ,
                Tri_ShadedColor + tStart,
                ScreenPtr, ZBuffer,
                CANVAS_W, CANVAS_H
            )
            ::skip_tile::
        end
    end
end
