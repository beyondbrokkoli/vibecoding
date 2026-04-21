require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")

-- 1. HARDWARE LAYER LOCALS (No more _G!)
local CANVAS_W, CANVAS_H
local ScreenBuffer, ScreenImage, ScreenPtr
local ZBuffer

function love.load()
    -- Initialize the Hardware Buffers locally
    CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
    local HALF_W, HALF_H = CANVAS_W * 0.5, CANVAS_H * 0.5
    MainCamera.fov = (CANVAS_W / 800) * 600

    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)

    -- Bind Modules through the Slop Gate
    Sequence.LoadModule("modules.camera", MainCamera)
    -- ... (Load your snake and donuts here as before) ...
    Sequence.LoadModule("modules.nokia_snake",
        Memory, MainCamera,
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )
    Sequence.LoadModule("modules.donuts",
        Memory, MainCamera, UniverseCage,
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
    Sequence.LoadModule("modules.megaknot",
        Memory, MainCamera,
        Obj_X, Obj_Y, Obj_Z, Obj_Radius, Obj_Yaw, Obj_Pitch,
        Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
    )
    -- If you convert Text to this format, you bind it here!
    Sequence.LoadModule("modules.text", Memory, MainCamera, Obj_X, Obj_Y, Obj_Z)
    Sequence.RunPhase("Init")
    love.mouse.setRelativeMode(true)
end

function love.update(dt)
    dt = math.min(dt, 0.033)
    Sequence.RunPhase("Tick", dt)
end

function love.draw()
    -- Clear the buffers using our safe locals
    ffi.fill(ScreenPtr, CANVAS_W * CANVAS_H * 4, 0)
    ffi.fill(ZBuffer, CANVAS_W * CANVAS_H * 4, 0x7F)
    
    Sequence.RunPhase("Cull", MainCamera)
    -- Pass the hardware pointers directly to the rasterizers!
    Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    
    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")
    
    love.graphics.setColor(0, 1, 0, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 20)
end

function love.keypressed(key)
    if key == "escape" then love.event.quit() end
    if key == "j" then love.mouse.setRelativeMode(not love.mouse.getRelativeMode()) end
    Sequence.RunPhase("KeyPressed", key)
end

function love.mousemoved(x, y, dx, dy)
    Sequence.RunPhase("MouseMoved", x, y, dx, dy)
end
