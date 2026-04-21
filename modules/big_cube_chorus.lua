local bit = require("bit")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local floor, sqrt = math.floor, math.sqrt

local PhysicsFactory = require("physics")
local RenderMeshFactory = require("render_mesh")

return function(
    Memory, MainCamera, UniverseCage, TextModule,
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
    local Chorus = {}
    local my_obj_start
    local CUBE_COUNT = 1000 -- SCALED UP!
    local time_alive = 0

    local RunPhysics = PhysicsFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
        Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        nil, -- Pass nil so they don't bounce off the universe cage!
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

    local function normalize_angle(angle)
        while angle > math_pi do angle = angle - (math_pi * 2) end
        while angle < -math_pi do angle = angle + (math_pi * 2) end
        return angle
    end

    function Chorus.Init()
        my_obj_start, _ = Memory.ClaimObjects(CUBE_COUNT)

        if TextModule then
            TextModule.Spawn(0, 11000, 0, "# KINEMATIC CHORUS\n~ \27[33mTITAN-CLASS DOUBLE HELIX\n| \27[36mBEHAVIOR: POOL DIVER SYNCHRONICITY", 5000, 0, 0, true)
        end

        local s = 150 -- SCALED UP CUBES

        for i = 0, CUBE_COUNT - 1 do
            local id = my_obj_start + i
            local vStart, tStart = Memory.ClaimGeometry(8, 12)

            -- Spawn them all in a massive chaotic pile at the bottom.
            Obj_X[id] = (math.random() - 0.5) * 8000
            Obj_Y[id] = -3500 + (math.random() - 0.5) * 1000
            Obj_Z[id] = (math.random() - 0.5) * 8000
            Obj_Yaw[id], Obj_Pitch[id] = 0, 0
            Obj_Radius[id] = s * 2.0

            Obj_VertStart[id], Obj_VertCount[id] = vStart, 8
            Obj_TriStart[id], Obj_TriCount[id] = tStart, 12

            local verts = {
                {-s, -s, -s}, {s, -s, -s}, {s, s, -s}, {-s, s, -s},
                {-s, -s,  s}, {s, -s,  s}, {s, s,  s}, {-s, s,  s}
            }
            for v = 0, 7 do
                Vert_LX[vStart+v], Vert_LY[vStart+v], Vert_LZ[vStart+v] = verts[v+1][1], verts[v+1][2], verts[v+1][3]
            end

            local indices = {
                0,2,1, 0,3,2, -- Front
                5,7,4, 5,6,7, -- Back
                3,6,2, 3,7,6, -- Top
                4,1,5, 4,0,1, -- Bottom
                1,6,5, 1,2,6, -- Right
                4,3,0, 4,7,3  -- Left
            }

            local base_r, base_g, base_b = 200, 200, 200
            if i % 2 == 0 then base_r, base_g, base_b = 40, 200, 255 end

            local tIdx = tStart
            for f = 1, #indices, 3 do
                Tri_V1[tIdx] = vStart + indices[f]
                Tri_V2[tIdx] = vStart + indices[f+1]
                Tri_V3[tIdx] = vStart + indices[f+2]

                local face_idx = floor((f-1)/6)
                local shade = 1.0
                if face_idx == 0 then shade = 0.9
                elseif face_idx == 1 then shade = 0.7
                elseif face_idx == 2 then shade = 1.0
                elseif face_idx == 3 then shade = 0.4
                elseif face_idx == 4 then shade = 0.8
                elseif face_idx == 5 then shade = 0.6
                end

                local cr, cg, cb = floor(base_r * shade), floor(base_g * shade), floor(base_b * shade)
                Tri_BakedColor[tIdx] = bit.bor(0xFF000000, bit.lshift(cb, 16), bit.lshift(cg, 8), cr)
                tIdx = tIdx + 1
            end
        end
    end

    function Chorus.Tick(dt)
        time_alive = time_alive + dt

        -- Slightly looser spring (4.0 instead of 6.0) so the massive macro-leaps 
        -- have a beautiful, weighty hang-time before snapping back.
        local spring = 4.0

        for i = 0, CUBE_COUNT - 1 do
            local id = my_obj_start + i

            -- [A] THE TITAN CHOREOGRAPHY
            local is_second_helix = i % 2 == 0
            local step_idx = floor(i / 2)

            -- Slower twist to account for the massive height
            local theta = step_idx * 0.10 + (is_second_helix and math_pi or 0) + (time_alive * 0.4)
            local r = 8000 -- Pushing the very edges of the Universe Cage
            local base_y = step_idx * 35 - 3800 -- Stretch from the floor to the ceiling
            
            -- [B] THE POOL DIVER RIPPLE
            -- Travel slightly faster to cross the immense distance
            local wave_phase = step_idx * 0.12 - time_alive * 1.0 --5.0
            local wave = math_sin(wave_phase)

            local target_x = math_cos(theta) * r
            local target_y = base_y
            local target_z = math_sin(theta) * r

            local target_yaw = -theta
            local target_pitch = 0

            -- If the ripple hits the step, LEAP out of formation!
            if wave > 0.85 then
                local leap_power = (wave - 0.85) * (1.0 / 0.15)

                -- Massive leap scaled to the giant radius
                target_x = target_x + math_cos(theta) * (leap_power * 3000) 
                target_y = target_y + (leap_power * 2500)                  
                target_z = target_z + math_sin(theta) * (leap_power * 3000)

                -- Synchronized Backflip
                target_pitch = leap_power * math_pi * 2.0
            end

            -- [C] KINEMATIC INJECTION
            Obj_VelX[id] = (target_x - Obj_X[id]) * spring
            Obj_VelY[id] = (target_y - Obj_Y[id]) * spring
            Obj_VelZ[id] = (target_z - Obj_Z[id]) * spring

            local diff_yaw = normalize_angle(target_yaw - Obj_Yaw[id])
            local diff_pitch = normalize_angle(target_pitch - Obj_Pitch[id])
            Obj_RotSpeedYaw[id] = diff_yaw * spring
            Obj_RotSpeedPitch[id] = diff_pitch * spring
        end

        RunPhysics(my_obj_start, my_obj_start + CUBE_COUNT - 1, dt)
    end

    function Chorus.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_start + CUBE_COUNT - 1, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Chorus
end
