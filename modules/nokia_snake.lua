-- modules/nokia_snake.lua
local bit = require("bit")
local SnakeModule = {}

-- Local registers to hold this module's exclusive memory boundaries
local my_obj_start, my_obj_end
local MAX_SNAKE_TILES = 100

-- Phase 1: Engine Startup
function SnakeModule.Init()
    -- Checkout 100 objects from the global heap
    my_obj_start, my_obj_end = Memory.ClaimObjects(MAX_SNAKE_TILES)
    
    -- Iterate ONLY over my specific memory slice to set up geometry boundaries
    for id = my_obj_start, my_obj_end do
        -- Each tile wants 100 verts and 200 tris (example)
        local v_start, t_start = Memory.ClaimGeometry(100, 200)
        Obj_VertStart[id] = v_start
        Obj_TriStart[id] = t_start
        Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, -99999, 0 -- Hide initially
    end
end

-- Phase 2: Game Loop
function SnakeModule.Tick(dt)
    -- Put your mathematical spine generator here!
    -- You only loop from my_obj_start to my_obj_end. 
    -- You write directly to Obj_X[id] and Vert_LX[v_idx]. 
    -- It is mathematically impossible for you to overwrite the text decals or donuts.
end

-- Phase 3/4: Cull & Raster
-- (You would pull your rasterizer/culling kernels in here, 
-- passing my_obj_start and my_obj_end as the arguments)

return SnakeModule
