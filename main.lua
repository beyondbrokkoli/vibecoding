require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")

local CANVAS_W, CANVAS_H
local ScreenBuffer, ScreenImage, ScreenPtr
local ZBuffer

require("bench") -- Load the global BENCH suite
local print_timer = 0

function love.load()
    CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
    MainCamera.fov = (CANVAS_W / 800) * 600

    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)

    -- 1. The Camera
    Sequence.LoadModule("modules.camera", MainCamera)

    -- 2. The Procedural Geometry (Snake & Crystal Forge)
    --Sequence.LoadModule("modules.nokia_snake",
        --Memory, MainCamera,
        --Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        --Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        --Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        --Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        --Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    --)

    -- Drop your new crystal_forge.lua into the modules folder, and it will load perfectly here!
    --Sequence.LoadModule("modules.crystal_forge",
        --Memory, MainCamera,
        --Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        --Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        --Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        --Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        --Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    --)

    -- 3. The 3D UI Layer (Load, cache, and hold reference)
    --Sequence.LoadModule("modules.text")
    --local TextModule = require("modules.text")

    -- 4. The Interactive Physics Layer (Tooltip Donuts!)
    -- Notice we explicitly load "tooltip_with_donuts" so we know exactly which one is running!
    --Sequence.LoadModule("modules.donuts",
        --Memory, MainCamera, UniverseCage, TextModule,
        --Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
        --Obj_VelX, Obj_VelY, Obj_VelZ, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        --Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        --Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        --Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        --Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
        --Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
        --Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
        --BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
    --)
    Sequence.LoadModule("modules.smales_paradox",
        Memory, MainCamera,
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )
    --Sequence.LoadModule("modules.cube_chorus",
        --Memory, MainCamera, UniverseCage, TextModule,
        --Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
        --Obj_VelX, Obj_VelY, Obj_VelZ, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        --Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        --Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        --Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        --Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
        --Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
        --Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
        --BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
    --)

    Sequence.RunPhase("Init")
    --love.mouse.setRelativeMode(true)
end



function love.update(dt)
    dt = math.min(dt, 0.033)
    Sequence.RunPhase("Tick", dt)
    
    -- Accumulate time for our sparse benchmark printing
    print_timer = print_timer + dt
end

function love.draw()
    ffi.fill(ScreenPtr, CANVAS_W * CANVAS_H * 4, 0)
    ffi.fill(ZBuffer, CANVAS_W * CANVAS_H * 4, 0x7F)

    Sequence.RunPhase("Cull", MainCamera)

    -- THE BENCHMARK WRAPPER
    BENCH.Begin("Rasterizer")
    Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    BENCH.End("Rasterizer")

    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")

    -- SPARSE TERMINAL OUTPUT (Every 2 seconds)
    if print_timer >= 2.0 then
        BENCH.PrintAndReset("Rasterizer")
        print_timer = 0
    end
end



function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    Sequence.RunPhase("KeyPressed", key)
end
