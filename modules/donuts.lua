local bit = require("bit")
local math_cos, math_sin, math_pi = math.cos, math.sin, math.pi
local floor, sqrt = math.floor, math.sqrt

local PhysicsFactory = require("physics")
local RenderMeshFactory = require("render_mesh")

return function(
    Memory, MainCamera, UniverseCage, TextModule, -- INJECTED TEXT MODULE
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

    -- Tracking Variables for Lore Element
    local target_donut_id = nil
    local target_text_id = nil

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
            -- Standard Random Spawning
            for i = 1, 5 do
                local spawn_dist = 400 + (math.random() * 600)
                local px = MainCamera.x + MainCamera.fwx * spawn_dist
                local py = MainCamera.y + MainCamera.fwy * spawn_dist
                local pz = MainCamera.z + MainCamera.fwz * spawn_dist

                local r_maj, r_min = math.random(50, 150), math.random(10, 40)
                local random_color = bit.bor(0xFF000000, bit.lshift(math.random(100,255), 16), bit.lshift(math.random(100,255), 8), math.random(100,255))

                local id = SpawnDonut(px, py, pz, r_maj, r_min, 24, 12, random_color)
                if id then
                    local power = math.random(1500, 3500)
                    Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = (MainCamera.fwx * power) + (math.random() - 0.5) * 500, (MainCamera.fwy * power) + (math.random() - 0.5) * 500, (MainCamera.fwz * power) + (math.random() - 0.5) * 500
                    Obj_RotSpeedYaw[id], Obj_RotSpeedPitch[id] = (math.random() - 0.5) * 6.0, (math.random() - 0.5) * 6.0
                end
            end
        end

        -- NEW TARGETING INTERACTION
        if key == "t" then
            local px = MainCamera.x + MainCamera.fwx * 800
            local py = MainCamera.y + MainCamera.fwy * 800
            local pz = MainCamera.z + MainCamera.fwz * 800

            -- Create a distinctly visible "Golden Torus" (ABGR format)
            local gold_color = bit.bor(0xFF000000, bit.lshift(0, 16), bit.lshift(200, 8), 255)
            target_donut_id = SpawnDonut(px, py, pz, 160, 40, 32, 16, gold_color)
            
            if target_donut_id and TextModule then
                Obj_VelX[target_donut_id] = (MainCamera.fwx * 1500) 
                Obj_VelY[target_donut_id] = (MainCamera.fwy * 1500)
                Obj_VelZ[target_donut_id] = (MainCamera.fwz * 1500)
                Obj_RotSpeedYaw[target_donut_id] = 2.0
                
                -- Spawn the Lore Text UI (Offsets: Shift it Right and Up on screen so it doesn't block the Donut)
                local lore_text = "# ANOMALY DETECTED\n~ \27[33mCLASS-V GOLDEN TORUS\n| \27[36mSCANNING...| \27[32mCONTAINED"
                target_text_id = TextModule.Spawn(px, py, pz, lore_text, 1200, 150, -100, true)
            end
        end
    end

    function Donuts.Tick(dt)
        if current_donut_count > 0 then
            RunPhysics(my_obj_start, my_obj_start + current_donut_count - 1, dt)
        end

        -- SYNC TEXT TO DONUT
        if target_donut_id and target_text_id and TextModule then
            TextModule.UpdateAnchor(
                target_text_id, 
                Obj_X[target_donut_id], 
                Obj_Y[target_donut_id], 
                Obj_Z[target_donut_id]
            )
        end
    end

    function Donuts.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        if current_donut_count > 0 then
            DrawMesh(my_obj_start, my_obj_start + current_donut_count - 1, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        end
    end

    return Donuts
end
