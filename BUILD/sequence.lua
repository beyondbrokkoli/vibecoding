local Sequence = {
Modules = {},
Phases = {
Init = {},
Tick = {},
KeyPressed = {},
MouseMoved = {},
Cull = {},
Raster = {}
}
}
function Sequence.LoadModule(filepath, ...)
package.loaded[filepath] = nil
local success, result = pcall(require, filepath)
if not success then
print("[FATAL] Module Error: " .. filepath .. "\n" .. tostring(result))
return false
end
local mod
if type(result) == "function" then
mod = result(...)
else
mod = result
end
table.insert(Sequence.Modules, mod)
if type(mod.Init) == "function" then table.insert(Sequence.Phases.Init, mod.Init) end
if type(mod.Tick) == "function" then table.insert(Sequence.Phases.Tick, mod.Tick) end
if type(mod.KeyPressed) == "function" then table.insert(Sequence.Phases.KeyPressed, mod.KeyPressed) end
if type(mod.MouseMoved) == "function" then table.insert(Sequence.Phases.MouseMoved, mod.MouseMoved) end
if type(mod.Cull) == "function" then table.insert(Sequence.Phases.Cull, mod.Cull) end
if type(mod.Raster) == "function" then table.insert(Sequence.Phases.Raster, mod.Raster) end
print("[SEQUENCE] Loaded Module: " .. filepath)
return true
end
function Sequence.RunPhase(phase_name, ...)
local phase = Sequence.Phases[phase_name]
for i = 1, #phase do
phase[i](...)
end
end
return Sequence
