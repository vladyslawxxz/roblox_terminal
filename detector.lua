local BASE_URL = "https://raw.githubusercontent.com/vladyslawxxz/roblox_terminal/refs/heads/main/"
local executors = loadstring(game:HttpGet(BASE_URL .. "executors.lua"))()

local function detect()
	if identifyexecutor then
		local name = identifyexecutor():lower()
		if name:find("synapse") then return executors.synapse end
		if name:find("krnl") then return executors.krnl end
		if name:find("fluxus") then return executors.fluxus end
		if name:find("delta") then return executors.delta end
		if name:find("xeno") then return executors.xeno end
		if name:find("arceus") then return executors.arceus end
		if name:find("solara") then return executors.solara end
		if name:find("wave") then return executors.wave end
		if name:find("sirhurt") then return executors.sirhurt end
		if name:find("script.ware") or name:find("scriptware") then return executors.scriptware end
		if name:find("oxygen") then return executors.oxygenu end
		if name:find("hydrogen") then return executors.hydrogen end
	end

	if getexecutorname then
		local name = getexecutorname():lower()
		if name:find("synapse") then return executors.synapse end
		if name:find("krnl") then return executors.krnl end
		if name:find("fluxus") then return executors.fluxus end
		if name:find("delta") then return executors.delta end
		if name:find("xeno") then return executors.xeno end
		if name:find("arceus") then return executors.arceus end
		if name:find("solara") then return executors.solara end
		if name:find("wave") then return executors.wave end
		if name:find("sirhurt") then return executors.sirhurt end
		if name:find("script.ware") or name:find("scriptware") then return executors.scriptware end
		if name:find("oxygen") then return executors.oxygenu end
		if name:find("hydrogen") then return executors.hydrogen end
	end

	if syn and syn.executor then return executors.synapse end
	if KRNL_LOADED then return executors.krnl end
	if SENTINEL_LOADED then return executors.sirhurt end
	if is_sirhurt_closure then return executors.sirhurt end
	if is_protosmasher_closure then return executors.generic end
	if is_synapse_function then return executors.synapse end
	if fluxus and fluxus.writefile then return executors.fluxus end
	if DELTA_EXECUTOR then return executors.delta end
	if XENO_LOADED then return executors.xeno end
	if ARCEUSX then return executors.arceus end
	if WAVE_EXECUTOR then return executors.wave end
	if SW_VERSION then return executors.scriptware end
	if OxygenU then return executors.oxygenu end
	if Hydrogen then return executors.hydrogen end

	if writefile then return executors.generic end

	return nil
end

return detect()
