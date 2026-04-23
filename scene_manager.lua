local SwarmFactory = require("swarm")
local MetalFactory = require("metal")
local BubbleFactory = require("bubble")

return function(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)

    local Manager = {}
    
    local swarm_scene = SwarmFactory(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)
    local metal_scene = MetalFactory(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)
    local bubble_scene = BubbleFactory(Memory, MainCamera, Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor, Tri_Valid, Tri_ShadedColor)

    local shared_time_alive = 0.0
    local active_scene = 0 -- 0 = Swarm, 1 = Metal, 2 = Bubble
    local enter_pressed_last = false

    function Manager.Init()
        swarm_scene.Init()
        metal_scene.Init()
        bubble_scene.Init()
    end

    function Manager.Tick(dt)
        shared_time_alive = shared_time_alive + dt

        -- Scene Cycler
        local enter_down = love.keyboard.isDown("return")
        if enter_down and not enter_pressed_last then
            active_scene = active_scene + 1
            if active_scene > 2 then active_scene = 0 end
        end
        enter_pressed_last = enter_down

        -- Dispatch
        if active_scene == 0 then
            swarm_scene.Tick(dt, shared_time_alive)
        elseif active_scene == 1 then
            metal_scene.Tick(dt, shared_time_alive)
        elseif active_scene == 2 then
            bubble_scene.Tick(dt, shared_time_alive)
        end
    end

    function Manager.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        if active_scene == 0 then
            swarm_scene.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        elseif active_scene == 1 then
            metal_scene.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        elseif active_scene == 2 then
            bubble_scene.Raster(CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
        end
    end

    return Manager
end
