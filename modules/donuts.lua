local bit = require("bit")
local math_cos, math_sin, math_pi = math.cos, math.sin, math.pi
local floor, sqrt = math.floor, math.sqrt

local PhysicsFactory = require("physics")
local RenderMeshFactory = require("render_mesh")

return function(
    Memory, MainCamera, UniverseCage,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
    Obj_VelX, Obj_VelY, Obj_VelZ, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
    Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
    Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
    BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
)
    local Donuts = {}
    local my_obj_start
    local MAX_DONUTS = 500
    local current_donut_count = 0

    local RunPhysics = PhysicsFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
        Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        UniverseCage,
        Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
        Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
        BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
    )

    local DrawMesh = RenderMeshFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    local function SpawnDonut(cx, cy, cz, mainRadius, tubeRadius, segments, sides, baseColor)
        if current_donut_count >= MAX_DONUTS then return nil end
        local id = my_obj_start + current_donut_count
        current_donut_count = current_donut_count + 1

        local vCount, tCount = segments * sides, segments * sides * 2
        local vStart, tStart = Memory.ClaimGeometry(vCount, tCount)

        Obj_X[id], Obj_Y[id], Obj_Z[id] = cx, cy, cz
        Obj_Yaw[id], Obj_Pitch[id] = 0, 0
        Obj_Radius[id] = mainRadius + tubeRadius
        Obj_VertStart[id], Obj_VertCount[id] = vStart, vCount
        Obj_TriStart[id], Obj_TriCount[id] = tStart, tCount

        local r, g, b = bit.band(bit.rshift(baseColor, 16), 0xFF), bit.band(bit.rshift(baseColor, 8), 0xFF), bit.band(baseColor, 0xFF)
        local altColor = bit.bor(0xFF000000, bit.lshift(floor(r * 0.6), 16), bit.lshift(floor(g * 0.6), 8), floor(b * 0.6))

        local vIdx = vStart
        for i = 0, segments - 1 do
            local th = (i / segments) * math_pi * 2
            for j = 0, sides - 1 do
                local ph = (j / sides) * math_pi * 2
                Vert_LX[vIdx] = (mainRadius + tubeRadius * math_cos(ph)) * math_cos(th)
                Vert_LY[vIdx] = tubeRadius * math_sin(ph)
                Vert_LZ[vIdx] = (mainRadius + tubeRadius * math_cos(ph)) * math_sin(th)
                vIdx = vIdx + 1
            end
        end

        local tIdx = tStart
        for i = 0, segments - 1 do
            local i_next = (i + 1) % segments
            for j = 0, sides - 1 do
                local j_next = (j + 1) % sides
                local a, b_idx = (i * sides + j) + vStart, (i_next * sides + j) + vStart
                local c, d = (i_next * sides + j_next) + vStart, (i * sides + j_next) + vStart
                local col = (i + j) % 2 == 0 and baseColor or altColor
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx; Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_BakedColor[tIdx] = col; tIdx = tIdx + 1
            end
        end
        return id
    end

    function Donuts.Init()
        my_obj_start, _ = Memory.ClaimObjects(MAX_DONUTS)
    end

    function Donuts.KeyPressed(key)
        if key == "r" then
            for i = 1, 5 do
                local spawn_dist = 400 + (math.random() * 600)
                local px = MainCamera.x + MainCamera.fwx * spawn_dist
                local py = MainCamera.y + MainCamera.fwy * spawn_dist
                local pz = MainCamera.z + MainCamera.fwz * spawn_dist

                local r_maj = math.random(50, 150)
                local r_min = math.random(10, 40)
                local r, g, b = math.random(100, 255), math.random(100, 255), math.random(100, 255)
                local random_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)

                local id = SpawnDonut(px, py, pz, r_maj, r_min, 24, 12, random_color)
                if id then
                    local power = math.random(1500, 3500)
                    Obj_VelX[id] = (MainCamera.fwx * power) + (math.random() - 0.5) * 500
                    Obj_VelY[id] = (MainCamera.fwy * power) + (math.random() - 0.5) * 500
                    Obj_VelZ[id] = (MainCamera.fwz * power) + (math.random() - 0.5) * 500
                    Obj_RotSpeedYaw[id] = (math.random() - 0.5) * 6.0
                    Obj_RotSpeedPitch[id] = (math.random() - 0.5) * 6.0
                end
            end
        end
    end

    function Donuts.Tick(dt)
        if current_donut_count > 0 then
            RunPhysics(my_obj_start, my_obj_start + current_donut_count - 1, dt)
        end
    end

    function Donuts.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        if current_donut_count > 0 then
            DrawMesh(my_obj_start, my_obj_start + current_donut_count - 1, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        end
    end

    return Donuts
end
