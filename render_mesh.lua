-- ========================================================================
-- render_mesh.lua
-- Pure 3D-to-2D Projection & Culling Pipeline.
-- Slop-Gate Closure Edition.
-- ========================================================================
local max, min, floor, abs = math.max, math.min, math.floor, math.abs
local RasterizeTriangle = require("rasterize")

return function(
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
    -- Returns the compiled projection loop
    return function(start_id, end_id, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        local cam_fov = MainCamera.fov
        local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5

        for id = start_id, end_id do
            local r = Obj_Radius[id]
            local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]

            local cz_center = (ox-cpx)*cfw_x + (oy-cpy)*cfw_y + (oz-cpz)*cfw_z
            if cz_center + r < 0.1 then goto skip_tile end

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
                
                if cz < 0.1 then 
                    Vert_Valid[idx] = false 
                else
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
                    
                    if (px2-px1)*(py3-py1) - (py2-py1)*(px3-px1) < 0 then
                        RasterizeTriangle(px1,py1,pz1, px2,py2,pz2, px3,py3,pz3, Tri_BakedColor[idx], CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
                    end
                end
            end
            ::skip_tile::
        end
    end
end
