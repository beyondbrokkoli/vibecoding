local SwarmFactory = require("swarm")
local MetalFactory = require("metal")

return function(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)

    local Manager = {}
    
    -- Instantiate both sub-modules
    local swarm_scene = SwarmFactory(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)
    local metal_scene = MetalFactory(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)

    -- The "Dumb", Explicit State
    local shared_time_alive = 0.0
    local is_solid_metal = false
    local enter_pressed_last = false

    function Manager.Init()
        swarm_scene.Init()
        metal_scene.Init()
    end

    function Manager.Tick(dt)
        -- 1. Advance the one true global clock
        shared_time_alive = shared_time_alive + dt

        -- 2. Hot-Swap Logic
        local enter_down = love.keyboard.isDown("return")
        if enter_down and not enter_pressed_last then
            is_solid_metal = not is_solid_metal
        end
        enter_pressed_last = enter_down

        -- 3. Explicit Dispatch (Passing the shared clock downwards!)
        if is_solid_metal then
            metal_scene.Tick(dt, shared_time_alive)
        else
            swarm_scene.Tick(dt, shared_time_alive)
        end
    end

    function Manager.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        if is_solid_metal then
            metal_scene.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        else
            swarm_scene.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        end
    end

    return Manager
end
