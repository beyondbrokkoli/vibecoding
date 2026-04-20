local Sequence = {
Modules = {},
Phases = {
Init = {},
Tick = {},
Cull = {},
Raster = {}
}
}
function Sequence.LoadModule(filepath)
package.loaded[filepath] = nil
local success, mod = pcall(require, filepath)
if not success then
print("[FATAL] Module Error: " .. filepath .. "\n" .. tostring(mod))
return false
end
table.insert(Sequence.Modules, mod)
if type(mod.Init) == "function" then table.insert(Sequence.Phases.Init, mod.Init) end
if type(mod.Tick) == "function" then table.insert(Sequence.Phases.Tick, mod.Tick) end
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
