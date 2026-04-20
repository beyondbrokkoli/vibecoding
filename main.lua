-- main.lua
require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")

function love.load()
    -- 1. Initialize Window & Canvas Buffers here...
    
    -- 2. Auto-load all modules in the directory!
    -- LÖVE can scan the directory dynamically, so you don't even need to hardcode paths.
    local files = love.filesystem.getDirectoryItems("modules")
    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            Sequence.LoadModule("modules." .. file:sub(1, -5))
        end
    end

    -- 3. Fire the Init phase. All modules claim their memory now.
    Sequence.RunPhase("Init")
end

function love.update(dt)
    dt = math.min(dt, 0.033)
    
    -- Trigger Physics & Procedural Generation
    Sequence.RunPhase("Tick", dt)
end

function love.draw()
    -- Clear Software Buffers here...
    
    -- Trigger Math
    Sequence.RunPhase("Cull", MainCamera)
    Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
    
    -- Commit to VRAM & Draw ScreenImage...
end
