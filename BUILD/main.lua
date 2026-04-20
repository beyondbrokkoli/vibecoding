require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")
function love.load()
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
Sequence.RunPhase("Cull", MainCamera)
Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
end
