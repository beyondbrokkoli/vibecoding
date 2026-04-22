require("memory")
local ffi = require("ffi")
local Sequence = require("sequence")
local CANVAS_W, CANVAS_H
local ScreenBuffer, ScreenImage, ScreenPtr
local ZBuffer
require("bench")
local print_timer = 0
function love.load()
CANVAS_W, CANVAS_H = love.graphics.getPixelDimensions()
MainCamera.fov = (CANVAS_W / 800) * 600
ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
ScreenImage = love.graphics.newImage(ScreenBuffer)
ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())
ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)
Sequence.LoadModule("modules.camera", MainCamera)
Sequence.LoadModule("modules.smales_paradox",
Memory, MainCamera,
Obj_X, Obj_Y, Obj_Z, Obj_Radius,
Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor
)
Sequence.RunPhase("Init")
end
function love.update(dt)
dt = math.min(dt, 0.033)
Sequence.RunPhase("Tick", dt)
print_timer = print_timer + dt
end
function love.draw()
ffi.fill(ScreenPtr, CANVAS_W * CANVAS_H * 4, 0)
ffi.fill(ZBuffer, CANVAS_W * CANVAS_H * 4, 0x7F)
Sequence.RunPhase("Cull", MainCamera)
BENCH.Begin("Rasterizer")
Sequence.RunPhase("Raster", CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
BENCH.End("Rasterizer")
ScreenImage:replacePixels(ScreenBuffer)
love.graphics.setColor(1, 1, 1, 1)
love.graphics.setBlendMode("replace")
love.graphics.draw(ScreenImage, 0, 0)
love.graphics.setBlendMode("alpha")
if print_timer >= 2.0 then
BENCH.PrintAndReset("Rasterizer")
print_timer = 0
end
end
function love.keypressed(key)
if key == "escape" then love.event.quit() end
Sequence.RunPhase("KeyPressed", key)
end
