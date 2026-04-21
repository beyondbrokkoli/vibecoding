local bit = require("bit")

local PhysicsFactory = require("physics")
local RenderMeshFactory = require("render_mesh")
local math_sin, math_cos, math_sqrt = math.sin, math.cos, math.sqrt

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
    local Swarm = {}
    local my_obj_start
    local SWARM_COUNT = 1500
    local time_alive = 0

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

    function Swarm.Init()
        my_obj_start, _ = Memory.ClaimObjects(SWARM_COUNT)
        
        -- Spawn the Lore Anchor for the Swarm
        if TextModule then
            TextModule.Spawn(0, 11000, 0, "# CLASS-X ANOMALY\n~ \27[35mSTRANGE ATTRACTOR SWARM\n| \27[36mBEHAVIOR: FLUIDIC CHAOS", 3000, 0, 0, true)
        end

        for i = 0, SWARM_COUNT - 1 do
            local id = my_obj_start + i
            local vStart, tStart = Memory.ClaimGeometry(4, 4) -- Tiny 4-vertex Tetrahedrons!
            
            -- Spawn in a tight sphere high up in the sky
            Obj_X[id] = (math.random() - 0.5) * 500
            Obj_Y[id] = 8000 + (math.random() - 0.5) * 500
            Obj_Z[id] = (math.random() - 0.5) * 500
            
            Obj_Yaw[id], Obj_Pitch[id] = math.random() * 6, math.random() * 6
            Obj_Radius[id] = 100
            Obj_VertStart[id], Obj_VertCount[id] = vStart, 4
            Obj_TriStart[id], Obj_TriCount[id] = tStart, 4

            -- Geometry: A simple crystalline pyramid
            local r = 60
            Vert_LX[vStart+0], Vert_LY[vStart+0], Vert_LZ[vStart+0] = 0, r, 0
            Vert_LX[vStart+1], Vert_LY[vStart+1], Vert_LZ[vStart+1] = -r, -r, r
            Vert_LX[vStart+2], Vert_LY[vStart+2], Vert_LZ[vStart+2] = r, -r, r
            Vert_LX[vStart+3], Vert_LY[vStart+3], Vert_LZ[vStart+3] = 0, -r, -r

            -- Faces
            Tri_V1[tStart+0], Tri_V2[tStart+0], Tri_V3[tStart+0] = vStart+0, vStart+1, vStart+2
            Tri_V1[tStart+1], Tri_V2[tStart+1], Tri_V3[tStart+1] = vStart+0, vStart+2, vStart+3
            Tri_V1[tStart+2], Tri_V2[tStart+2], Tri_V3[tStart+2] = vStart+0, vStart+3, vStart+1
            Tri_V1[tStart+3], Tri_V2[tStart+3], Tri_V3[tStart+3] = vStart+1, vStart+3, vStart+2

            -- Vaporwave Gradient Color Bake based on ID index
            local blend = i / SWARM_COUNT
            local red = math.floor(255 * blend)
            local blue = math.floor(255 * (1 - blend))
            local color = bit.bor(0xFF000000, bit.lshift(blue, 16), bit.lshift(50, 8), red)
            
            Tri_BakedColor[tStart+0] = color
            Tri_BakedColor[tStart+1] = color
            Tri_BakedColor[tStart+2] = color
            Tri_BakedColor[tStart+3] = bit.bor(0xFF000000, bit.lshift(20,16), bit.lshift(20,8), bit.lshift(20,0)) -- Dark bottom
        end
    end

    function Swarm.Tick(dt)
        time_alive = time_alive + dt
        
        -- Chaos Theory Parameters (Morphing slightly over time)
        local sigma = 10.0
        local rho = 28.0 + math_sin(time_alive * 0.5) * 5.0
        local beta = 8.0 / 3.0

        -- The Space Mapping
        local scale = 150.0 
        local center_y = 8000
        local center_z = 25.0 * scale -- Push it into the center of the attractor lobes
        local speed = 2.0 -- CHANGED: Removed the '* dt' so physics.lua handles it cleanly!

        for i = 0, SWARM_COUNT - 1 do
            local id = my_obj_start + i
            
            -- Map World Space to Math Space
            local x = Obj_X[id] / scale
            local y = (Obj_Y[id] - center_y) / scale
            local z = (Obj_Z[id] + center_z) / scale

            -- The Lorenz Attractor Equations
            local dx = sigma * (y - x)
            local dy = x * (rho - z) - y
            local dz = x * y - beta * z

            -- Inject intent directly into velocity arrays!
            Obj_VelX[id] = dx * speed * scale
            Obj_VelY[id] = dy * speed * scale
            Obj_VelZ[id] = dz * speed * scale
            
            -- Make the shards spin wildly based on chaotic pressure
            Obj_RotSpeedYaw[id] = dx * 0.05
            Obj_RotSpeedPitch[id] = dy * 0.05
        end

        -- Run physics without the cage constraint
        RunPhysics(my_obj_start, my_obj_start + SWARM_COUNT - 1, dt)
    end

    function Swarm.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(my_obj_start, my_obj_start + SWARM_COUNT - 1, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Swarm
end
