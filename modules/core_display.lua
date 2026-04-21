-- modules/core_display.lua
local ffi = require("ffi")

local DisplayModule = {}
function DisplayModule.Init()
    local pixel_w, pixel_h = love.graphics.getPixelDimensions()
    
    _G.CANVAS_W, _G.CANVAS_H = pixel_w, pixel_h
    _G.HALF_W, _G.HALF_H = pixel_w * 0.5, pixel_h * 0.5

    _G.ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    _G.ScreenImage = love.graphics.newImage(ScreenBuffer)
    _G.ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())

    _G.ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)
    
    -- 2. DELETE THIS LINE! Do not overwrite the global pointer!
    -- _G.MainCamera = ffi.new("CameraState")
    
    -- 3. Now it just configures the pointer that main.lua created!
    MainCamera.fov = (CANVAS_W / 800) * 600
    MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -1000
    MainCamera.yaw, MainCamera.pitch = 0, 0
    
    DisplayModule.UpdateCameraBasis()
end

function DisplayModule.UpdateCameraBasis()
    local cy, sy = math.cos(MainCamera.yaw), math.sin(MainCamera.yaw)
    local cp, sp = math.cos(MainCamera.pitch), math.sin(MainCamera.pitch)
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
    MainCamera.upx = MainCamera.fwy * MainCamera.rtz
    MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
    MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
end

function DisplayModule.Tick(dt)
    local s = 2000 * dt
    if love.keyboard.isDown("w") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x + MainCamera.fwx * s, MainCamera.y + MainCamera.fwy * s, MainCamera.z + MainCamera.fwz * s end
    if love.keyboard.isDown("s") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x - MainCamera.fwx * s, MainCamera.y - MainCamera.fwy * s, MainCamera.z - MainCamera.fwz * s end
    if love.keyboard.isDown("a") then MainCamera.x, MainCamera.z = MainCamera.x - MainCamera.rtx * s, MainCamera.z - MainCamera.rtz * s end
    if love.keyboard.isDown("d") then MainCamera.x, MainCamera.z = MainCamera.x + MainCamera.rtx * s, MainCamera.z + MainCamera.rtz * s end
    if love.keyboard.isDown("e") then MainCamera.y = MainCamera.y - s end
    if love.keyboard.isDown("q") then MainCamera.y = MainCamera.y + s end
    
    -- Recalculate if we moved, but rotation is handled by MouseMoved
    DisplayModule.UpdateCameraBasis()
end

function DisplayModule.MouseMoved(x, y, dx, dy)
    if love.mouse.getRelativeMode() then
        MainCamera.yaw = MainCamera.yaw + (dx * 0.002)
        MainCamera.pitch = MainCamera.pitch + (dy * 0.002)
        MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
        DisplayModule.UpdateCameraBasis()
    end
end

return DisplayModule
