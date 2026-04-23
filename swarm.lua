local ffi = require("ffi")
local bit = require("bit")
local VibeMath = require("load")
local RenderMeshFactory = require("render")

return function(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)

    local Swarm = {}
    local swarm_obj_id
    local PCOUNT = 10000
    local VCOUNT = PCOUNT * 4
    local TCOUNT = PCOUNT * 4

    -- Dedicated Physics Arrays (Bypassing main SoA for maximum speed)
    local p_px = ffi.new("float[?]", PCOUNT)
    local p_py = ffi.new("float[?]", PCOUNT)
    local p_pz = ffi.new("float[?]", PCOUNT)
    local p_vx = ffi.new("float[?]", PCOUNT)
    local p_vy = ffi.new("float[?]", PCOUNT)
    local p_vz = ffi.new("float[?]", PCOUNT)
    local p_seed = ffi.new("float[?]", PCOUNT) -- NEW

    local current_shape = 0
    local space_pressed_last = false
    local time_alive = 0.0

    local DrawMesh = RenderMeshFactory(
        Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, 
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, 
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, 
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )

    function Swarm.Init()
        swarm_obj_id, _ = Memory.ClaimObjects(1)
        local id = swarm_obj_id
        local vStart, tStart = Memory.ClaimGeometry(VCOUNT, TCOUNT)

        -- One Giant Object to hold the entire swarm
        Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, 0, 0
        Obj_Radius[id] = 999999 -- So large it never gets culled by the camera
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0
        Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
        Obj_TriStart[id], Obj_TriCount[id] = tStart, TCOUNT

        -- Scatter the particles
        for i = 0, PCOUNT - 1 do
            p_px[i] = (math.random() - 0.5) * 20000
            p_py[i] = (math.random() - 0.5) * 10000 + 5000
            p_pz[i] = (math.random() - 0.5) * 20000
            p_vx[i] = (math.random() - 0.5) * 5000
            p_vy[i] = (math.random() - 0.5) * 5000
            p_vz[i] = (math.random() - 0.5) * 5000
            p_seed[i] = i / (PCOUNT - 1) -- Assign identity (0.0 to 1.0)
        end

        -- Build the Triangles permanently
        local tIdx = tStart
        local col1 = bit.bor(0xFF000000, bit.lshift(255, 16), 0, 0) -- Blue
        local col2 = bit.bor(0xFF000000, 0, bit.lshift(255, 8), 0)  -- Green
        local col3 = bit.bor(0xFF000000, 0, 0, 255)                 -- Red
        local col4 = bit.bor(0xFF000000, 0, bit.lshift(255, 8), 255)-- Yellow

        for i = 0, PCOUNT - 1 do
            local base = vStart + (i * 4)
            -- Front Left
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = base+0, base+1, base+2
            Tri_BakedColor[tIdx] = col1; tIdx = tIdx + 1
            -- Front Right
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = base+0, base+2, base+3
            Tri_BakedColor[tIdx] = col2; tIdx = tIdx + 1
            -- Back
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = base+0, base+3, base+1
            Tri_BakedColor[tIdx] = col3; tIdx = tIdx + 1
            -- Bottom
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = base+1, base+3, base+2
            Tri_BakedColor[tIdx] = col4; tIdx = tIdx + 1
        end
    end

function Swarm.Tick(dt)
        time_alive = time_alive + dt

        -- Shape State Machine
        local space_down = love.keyboard.isDown("space")
        if space_down and not space_pressed_last then
            current_shape = current_shape + 1
            if current_shape > 4 then current_shape = 0 end -- Loop back to Physics
        end
        space_pressed_last = space_down

        -- Explosions (Still work in ALL modes!)
        if love.mouse.isDown(1) then
            local ex = MainCamera.x + MainCamera.fwx * 10000
            local ey = MainCamera.y + MainCamera.fwy * 10000
            local ez = MainCamera.z + MainCamera.fwz * 10000
            VibeMath.simd_apply_explosion(PCOUNT, p_px, p_py, p_pz, p_vx, p_vy, p_vz, ex, ey, ez, 5000000.0 * dt, 15000.0)
        end
        if love.mouse.isDown(2) then
            local ex = MainCamera.x + MainCamera.fwx * 10000
            local ey = MainCamera.y + MainCamera.fwy * 10000
            local ez = MainCamera.z + MainCamera.fwz * 10000
            VibeMath.simd_apply_explosion(PCOUNT, p_px, p_py, p_pz, p_vx, p_vy, p_vz, ex, ey, ez, -4000000.0 * dt, 20000.0)
        end

        -- KERNEL DISPATCH
        if current_shape == 0 then
            -- MODE 0: Free-fall Physics
            local cage = UniverseCage
            VibeMath.simd_update_physics_swarm(
                PCOUNT, p_px, p_py, p_pz, p_vx, p_vy, p_vz,
                cage.minX, cage.maxX, cage.minY, cage.maxY, cage.minZ, cage.maxZ,
                dt, -8000.0
            )
        else
            -- MODE 1-4: Attractor Shapes
            -- Target the center of the cage (0, 5000, 0)
            VibeMath.simd_update_swarm_attractors(
                PCOUNT, p_px, p_py, p_pz, p_vx, p_vy, p_vz, p_seed,
                0, 5000, 0, time_alive, dt, current_shape
            )
        end

        -- Generate final triangles
        local vStart = Obj_VertStart[swarm_obj_id]
        VibeMath.generate_swarm_geometry(
            PCOUNT, p_px, p_py, p_pz,
            Vert_LX + vStart, Vert_LY + vStart, Vert_LZ + vStart,
            120.0
        )
    end

    function Swarm.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        DrawMesh(swarm_obj_id, swarm_obj_id, MainCamera, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    end

    return Swarm
end
