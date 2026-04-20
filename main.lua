-- main.lua
require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")

function love.load()
    -- Dynamically load all module files
    local files = love.filesystem.getDirectoryItems("modules")
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            Sequence.LoadModule("modules." .. file:sub(1, -5))
        end
    end

    Sequence.RunPhase("Init")
end

function love.update(dt)
    dt = math.min(dt, 0.033)
    Sequence.RunPhase("Tick", dt)
end

function love.draw()
    -- 1. Pre-Raster: Clear the FFI Buffers
    ffi.fill(ScreenPtr, CANVAS_W * CANVAS_H * 4, 0)
    ffi.fill(ZBuffer, CANVAS_W * CANVAS_H * 4, 0x7F)
    
    -- 2. Execute Math
    Sequence.RunPhase("Cull", MainCamera)
    Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    
    -- 3. Commit to Hardware
    ScreenImage:replacePixels(ScreenBuffer)
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")
    
    -- Basic HUD
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
