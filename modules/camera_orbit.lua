-- ========================================================================
-- modules/camera_orbit.lua
-- Pure Cinematic Orbit Camera for Deterministic Benchmarking
-- ========================================================================
local max, min = math.max, math.min
local cos, sin, atan2, sqrt = math.cos, math.sin, math.atan2, math.sqrt

return function(MainCamera)
    local OrbitModule = {}

    -- ORBIT SETTINGS
    local orbit_angle = 0
    local orbit_speed = 0.3      -- Radians per second
    local orbit_radius = 12000    -- Distance from the target
    
    -- TARGET COORDINATES (Center of the Megaknot/Snake area)
    local target_x = 0
    local target_y = 3500
    local target_z = 0

    local function UpdateBasis()
        local cy, sy = cos(MainCamera.yaw), sin(MainCamera.yaw)
        local cp, sp = cos(MainCamera.pitch), sin(MainCamera.pitch)
        
        MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
        MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
        MainCamera.upx = MainCamera.fwy * MainCamera.rtz
        MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
        MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
    end

    function OrbitModule.Init()
        orbit_angle = 0
    end

    function OrbitModule.Tick(dt)
        -- 1. Advance the orbit
        orbit_angle = orbit_angle + (dt * orbit_speed)

        -- 2. Calculate the new 3D position on the circle
        MainCamera.x = target_x + sin(orbit_angle) * orbit_radius
        MainCamera.z = target_z + cos(orbit_angle) * orbit_radius
        
        -- Add a gentle cinematic vertical bobbing motion
        MainCamera.y = target_y + sin(orbit_angle * 0.6) * 3000

        -- 3. The "LookAt" Math (Aiming the lens at the target)
        local dx = target_x - MainCamera.x
        local dy = target_y - MainCamera.y
        local dz = target_z - MainCamera.z

        -- Yaw is the 2D angle on the XZ plane
        MainCamera.yaw = atan2(dx, dz)
        
        -- Pitch is the angle between the Y distance and the flat 2D distance
        local dist2D = sqrt(dx*dx + dz*dz)
        MainCamera.pitch = atan2(dy, dist2D)

        -- 4. Update the matrix vectors for the rasterizer
        UpdateBasis()
    end

    -- We leave MouseMoved empty so user input doesn't interfere with the benchmark!
    function OrbitModule.MouseMoved(x, y, dx, dy) 
    end

    -- Optional: Allow the user to zoom in and out with the mouse wheel
    function OrbitModule.KeyPressed(key)
        if key == "up" then orbit_radius = max(2000, orbit_radius - 500) end
        if key == "down" then orbit_radius = orbit_radius + 500 end
    end

    return OrbitModule
end
