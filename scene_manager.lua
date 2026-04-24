local Sequence = require("sequence")

return function(...)
    local Manager = {}
    
    -- Pack all the FFI pointers (Memory, Camera, Obj_X, etc.) into an array
    local injected_args = {...} 

    local scenes = {"swarm", "metal", "bubble", "smales_paradox"}
    local active_index = 1
    local enter_pressed_last = false

    -- Since scenes don't keep their own time anymore, we pass a global time
    local shared_time_alive = 0.0 

    function Manager.Init()
        -- Load the very first scene using unpack() to dump all 32 arguments perfectly
        local mod = Sequence.LoadModule(scenes[active_index], unpack(injected_args))
        if mod and mod.Init then mod.Init() end
    end

    function Manager.Tick(dt)
        shared_time_alive = shared_time_alive + dt

        local enter_down = love.keyboard.isDown("return")
        if enter_down and not enter_pressed_last then
            -- 1. UNLOAD THE OLD
            Sequence.UnloadModule(scenes[active_index])

            -- 2. INCREMENT
            active_index = active_index + 1
            if active_index > #scenes then active_index = 1 end

            -- 3. RESET MEMORY ALLOCATOR [NEW]
            -- injected_args[1] is the Memory module!
            injected_args[1].Reset()

            -- 4. LOAD THE NEW (SHARP CUT)
            local mod = Sequence.LoadModule(scenes[active_index], unpack(injected_args))
            
            if mod and mod.Init then mod.Init() end
        end
        
        enter_pressed_last = enter_down
    end
    -- Notice there is no Manager.Raster() anymore!
    -- Sequence.lua handles Raster automatically now because the active scene 
    -- injected its own Raster function directly into the Sequence.Phases.Raster table!

    return Manager
end
