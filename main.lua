require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")
local VibeMath = require("load")

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
    Sequence.LoadModule("camera", MainCamera)

    Sequence.LoadModule("metal",
        Memory, MainCamera,
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
        Tri_Valid, Tri_ShadedColor -- <--- ADD THESE TWO!
    )

    Sequence.RunPhase("Init")
end



function love.update(dt)
    dt = math.min(dt, 0.033)
    Sequence.RunPhase("Tick", dt)

    -- Accumulate time for our sparse benchmark printing
    print_timer = print_timer + dt
end

function love.draw()
    -- 0xFF000000 = Solid Black Color
    -- 99999.0 = A massive float to reset the Depth Buffer
    -- CANVAS_W * CANVAS_H = Total number of pixels
    VibeMath.simd_clear_buffers(ScreenPtr, ZBuffer, 0xFF000000, 99999.0, CANVAS_W * CANVAS_H)
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
    love.graphics.setColor(0, 1, 0.5, 1)
    love.graphics.print(love.timer.getFPS())
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
