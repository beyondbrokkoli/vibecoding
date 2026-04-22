local ffi = require("ffi")
local VibeMath = require("load_simd")
local max, min, floor, abs, sqrt = math.max, math.min, math.floor, math.abs, math.sqrt
local RasterizeTriangle = require("rasterize")
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
local sun_x, sun_y, sun_z = 0.577, -0.577, 0.577
for id = start_id, end_id do
local r = Obj_Radius[id]
local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]
local cz_center = (ox-cpx)*cfw_x + (oy-cpy)*cfw_y + (oz-cpz)*cfw_z
if cz_center + r < 0.1 then goto skip_tile end
local rx, ry, rz = Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id]
local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]
local vStart, vCount = Obj_VertStart[id], Obj_VertCount[id]
VibeMath.simd_project_vertices(
vCount,
Vert_LX + vStart, Vert_LY + vStart, Vert_LZ + vStart,
Vert_PX + vStart, Vert_PY + vStart, Vert_PZ + vStart, Vert_Valid + vStart,
ox, oy, oz, rx, ry, rz, ux, uy, uz, fx, fy, fz,
cpx, cpy, cpz, cfw_x, cfw_y, cfw_z, crt_x, crt_z, cup_x, cup_y, cup_z,
cam_fov, HALF_W, HALF_H
)
local tStart, tCount = Obj_TriStart[id], Obj_TriCount[id]
for i = 0, tCount - 1 do
local idx = tStart + i
local i1, i2, i3 = Tri_V1[idx], Tri_V2[idx], Tri_V3[idx]
if Vert_Valid[i1] and Vert_Valid[i2] and Vert_Valid[i3] then
local px1, py1, pz1 = Vert_PX[i1], Vert_PY[i1], Vert_PZ[i1]
local px2, py2, pz2 = Vert_PX[i2], Vert_PY[i2], Vert_PZ[i2]
local px3, py3, pz3 = Vert_PX[i3], Vert_PY[i3], Vert_PZ[i3]
local cross = (px2-px1)*(py3-py1) - (py2-py1)*(px3-px1)
local is_inside = cross >= 0
local orig_col = Tri_BakedColor[idx]
if is_inside then
orig_col = bit.bor(0xFF000000, bit.lshift(255, 16), bit.lshift(0, 8), 170)
end
local lx1, ly1, lz1 = Vert_LX[i1], Vert_LY[i1], Vert_LZ[i1]
local lx2, ly2, lz2 = Vert_LX[i2], Vert_LY[i2], Vert_LZ[i2]
local lx3, ly3, lz3 = Vert_LX[i3], Vert_LY[i3], Vert_LZ[i3]
local ax, ay, az = lx2 - lx1, ly2 - ly1, lz2 - lz1
local bx, by, bz = lx3 - lx1, ly3 - ly1, lz3 - lz1
local lnx = ay * bz - az * by
local lny = az * bx - ax * bz
local lnz = ax * by - ay * bx
local wnx = lnx * rx + lny * ux + lnz * fx
local wny = lnx * ry + lny * uy + lnz * fy
local wnz = lnx * rz + lny * uz + lnz * fz
local nLen = sqrt(wnx*wnx + wny*wny + wnz*wnz)
if nLen == 0 then nLen = 1 end
wnx, wny, wnz = wnx/nLen, wny/nLen, wnz/nLen
local dot = wnx * sun_x + wny * sun_y + wnz * sun_z
if is_inside then dot = -dot end
local light = max(0.2, min(1.0, dot))
local b = floor(bit.band(bit.rshift(orig_col, 16), 0xFF) * light)
local g = floor(bit.band(bit.rshift(orig_col, 8), 0xFF) * light)
local r = floor(bit.band(orig_col, 0xFF) * light)
local shaded_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)
RasterizeTriangle(px1,py1,pz1, px2,py2,pz2, px3,py3,pz3, shaded_color, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
end
end
::skip_tile::
end
end
end
