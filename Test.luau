--[[
    Cobalt
    A runtime developer tool to monitor and intercept network traffic
    coming from the roblox game engine.
]]--


-- ++++++++ WAX BUNDLED DATA BELOW ++++++++ --

-- Will be used later for getting flattened globals
local ImportGlobals

-- Holds direct closure data (defining this before the DOM tree for line debugging etc)
local ClosureBindings = {
    function()local wax,script,require=ImportGlobals(1)local ImportGlobals return (function(...)wax.shared.CobaltStartTime = tick()

local FileLogger = require(script.Utils.FileLog)

-- Environment
for _, Service in pairs({
	"ContentProvider",
	"CoreGui",
	"TweenService",
	"Players",
	"RunService",
	"HttpService",
	"UserInputService",
	"TextService",
	"StarterGui",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

wax.shared.CobaltVerificationToken = wax.shared.HttpService:GenerateGUID()
wax.shared.SaveManager = require(script.Utils.SaveManager)
wax.shared.Settings = {}

wax.shared.Hooks = {}

-- Executor Support
wax.shared.ExecutorName = identifyexecutor()
wax.shared.ExecutorSupport = require(script.ExecutorSupport)

-- Utils
require(script.Utils.Connect)
wax.shared.Hooking = require(script.Utils.Hooking)

-- UI
wax.shared.Sonner = require(script.Utils.UI.Sonner)

-- Code Generation
local LuaEncode = require(script.Utils.Serializer.LuaEncode)
wax.shared.LuaEncode = LuaEncode

local CodeGen = require(script.Utils.CodeGen.Generator)

-- Variables
if not wax.shared.Players.LocalPlayer then
	wax.shared.Players.PlayerAdded:Wait()
end
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer
local ContendingPlayerScripts = cloneref(wax.shared.LocalPlayer:QueryDescendants("PlayerScripts")[1] or wax.shared.LocalPlayer)
if ContendingPlayerScripts:IsA("PlayerScripts") then
	wax.shared.PlayerScripts = ContendingPlayerScripts
else
	wax.shared.PlayerScripts = nil

	local ChildAddedConnection
	ChildAddedConnection = wax.shared.Connect(wax.shared.LocalPlayer.ChildAdded:Connect(function(Child)
		if Child:IsA("PlayerScripts") then
			wax.shared.PlayerScripts = cloneref(Child)
			wax.shared.Disconnect(ChildAddedConnection)
		end
	end))
end

-- Functions
wax.shared.gethui = gethui or function()
	return wax.shared.CoreGui
end
wax.shared.checkcaller = checkcaller or function()
	return nil
end
wax.shared.restorefunction = function(Function: (...any) -> ...any, Silent: boolean?)
	local Original = wax.shared.Hooks[Function]

	if Silent and not Original then
		return
	end

	assert(Original, "Function not hooked")

	if restorefunction and isfunctionhooked(Function) then
		restorefunction(Function)
	else
		wax.shared.Hooking.HookFunction(Function, Original)
	end

	wax.shared.Hooks[Function] = nil
end
wax.shared.getrawmetatable = wax.shared.ExecutorSupport["getrawmetatable"].IsWorking
		and (getrawmetatable or debug.getmetatable)
	or function()
		return setmetatable({}, {
			__index = function()
				return function() end
			end,
		})
	end

wax.shared.newcclosure = wax.shared.ExecutorName == "AWP"
		and function(f, name)
			local env = getfenv(f)
			local x = setmetatable({
				__F = f,
			}, {
				__index = env,
				__newindex = env,
			})

			local nf = function(...)
				return __F(...)
			end

			setfenv(nf, x) -- set func env (env of nf gets deoptimized)
			return newcclosure(nf, name)
		end
	or newcclosure
wax.shared.queue_on_teleport = queue_on_teleport or queueonteleport or function(...) end

wax.shared.IsPlayerModule = function(Origin: LocalScript | ModuleScript, Instance: Instance): boolean
	if Instance and Instance.ClassName ~= "BindableEvent" then
		return false
	end

	if not Origin or typeof(Origin) ~= "Instance" or not Origin.IsA(Origin, "LuaSourceContainer") then
		return false
	end

	local PlayerModule = Origin and Origin.FindFirstAncestor(Origin, "PlayerModule") or nil
	if not PlayerModule then
		return false
	end

	if PlayerModule.Parent == nil then
		return true
	end

	if wax.shared.PlayerScripts then
		return compareinstances(PlayerModule.Parent, wax.shared.PlayerScripts)
	end

	return false
end
wax.shared.ShouldIgnore = function(Instance, Origin)
	return wax.shared.Settings.IgnoredRemotesDropdown.Value[Instance.ClassName] == true
		or (wax.shared.Settings.IgnorePlayerModule.Value and wax.shared.IsPlayerModule(Origin, Instance))
end

wax.shared.GetTableLength = function(Table)
	if Table["n"] then
		return Table.n
	end

	local Length = 0
	for _, _ in pairs(Table) do
		Length += 1
	end
	return Length
end
wax.shared.JoinTable = function(Table, Prefix, Suffix)
	local FinalString = ""
	for _, Value in pairs(Table) do
		FinalString ..= Prefix .. tostring(Value) .. Suffix
	end

	FinalString = string.sub(FinalString, 1, string.len(FinalString) - string.len(Suffix))

	return FinalString
end
wax.shared.GetTextBounds = function(Text: string, Font: Font, Size: number, Width: number?): (number, number)
	local Params = Instance.new("GetTextBoundsParams")
	Params.Text = Text
	Params.RichText = true
	Params.Font = Font
	Params.Size = Size
	Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

	local Bounds = wax.shared.TextService:GetTextBoundsAsync(Params)
	Params:Destroy()
	
	return Bounds.X, Bounds.Y
end

wax.shared.Unloaded = false
wax.shared.Unload = function()
	local PluginManager = wax.shared.CobaltPluginManager
	if PluginManager then
		for _, Plugin in PluginManager.Registry.Plugins do
			if not Plugin.UnloadCallbacks then
				continue
			end
			
			for _, Callback in Plugin.UnloadCallbacks or {} do
				task.spawn(pcall, Callback)
			end
		end
	end

	for _, Connection in pairs(wax.shared.Connections) do
		wax.shared.Disconnect(Connection)
	end

	local gameMetatable = wax.shared.getrawmetatable(game)

	if wax.shared.ExecutorSupport["oth"].IsWorking then
		pcall(oth.unhook, gameMetatable.__namecall)
		pcall(oth.unhook, gameMetatable.__newindex)
	else
		if wax.shared.ExecutorSupport["restorefunction"].IsWorking and not wax.shared.AlternativeEnabled then
			pcall(restorefunction, gameMetatable.__namecall)
			pcall(restorefunction, gameMetatable.__newindex)
		else
			wax.shared.Hooking.HookMetaMethod(game, "__namecall", wax.shared.NamecallHook)
			wax.shared.Hooking.HookMetaMethod(game, "__newindex", wax.shared.NewIndexHook)
		end
	end

	for Function, Original in pairs(wax.shared.Hooks) do
		if wax.shared.ExecutorSupport["oth"].IsWorking then
			task.spawn(pcall, oth.unhook, Function)
		elseif wax.shared.ExecutorSupport["restorefunction"].IsWorking then
			task.spawn(pcall, wax.shared.restorefunction, Function)
		else
			pcall(wax.shared.Hooking.HookFunction, Function, Original)
		end
	end

	if wax.shared.ActorCommunicator then
		pcall(function()
			wax.shared.ActorCommunicator:Fire("Unload")
		end)
	end

	getgenv().CobaltInitialized = false
	getgenv().Cobalt = nil

	wax.shared.Communicator:Destroy()
	wax.shared.ScreenGui:Destroy()

	wax.shared.Unloaded = true
end

local AnticheatData = require(script.Utils.Anticheats.Main)

-- Load Script
wax.shared.Communicator = Instance.new("BindableEvent")

wax.shared.SetupLoggingConnection = function()
	if wax.shared.LogConnection then
		wax.shared.LogConnection:Disconnect()
	end

	wax.shared.LogFileName = `Cobalt/Logs/{DateTime.now():ToIsoDate():gsub(":", "_")}.log`
	local FileLog = FileLogger.new(wax.shared.LogFileName, FileLogger.LOG_LEVELS.INFO, true)

	return function(RemoteInstance, Type, CallOrderInLog)
		local LogEntry = wax.shared.Logs[Type][RemoteInstance]
		if not LogEntry then
			return
		end

		local CallDataFromHook = LogEntry.Calls[CallOrderInLog]

		local success, err = pcall(function()
			local generatedCode = CodeGen:BuildCallCode(setmetatable({
				Instance = RemoteInstance,
				Type = Type,
			}, {
				__index = CallDataFromHook,
			}) :: any)

			local comprehensiveDataToSerialize = {
				RemoteInstanceInfo = {
					Name = RemoteInstance and RemoteInstance.Name,
					ClassName = RemoteInstance and RemoteInstance.ClassName,
					Path = RemoteInstance and CodeGen.GetFullPath(RemoteInstance, {
						DisableNilParentHandler = true,
					}),
				},
				EventType = Type,
				CallOrderInLog = CallOrderInLog,
				DataFromHook = CallDataFromHook,
			}

			local serializedEventData = LuaEncode(
				comprehensiveDataToSerialize,
				{ Prettify = true, InsertCycles = true, UseInstancePaths = true }
			)

			local instanceName = RemoteInstance and RemoteInstance.Name or "UnknownInstance"
			local instanceClassName = RemoteInstance and RemoteInstance.ClassName or "UnknownClass"
			local instancePath = RemoteInstance and CodeGen.GetFullPath(RemoteInstance, {
				DisableNilParentHandler = true
			}) or "UnknownPath"

			local logParts = {
				("Instance: %s (%s)"):format(instanceName, instanceClassName),
				("Path: %s"):format(instancePath),
				("Status: %s"):format(CallDataFromHook and CallDataFromHook.Blocked and "Blocked" or "Allowed"),
				("Call Order In Log: %s"):format(CallOrderInLog or "N/A"),
				"-------------------- Event Data --------------------",
				serializedEventData,
				"-------------------- Generated Code --------------------",
				generatedCode,
			}
			local logMessage = table.concat(logParts, "\n\t")
			local threadId = ("%s:%s"):format(Type or "S", instanceName)

			FileLog:Info(threadId, logMessage)
		end)

		if not success then
			local instanceNameForError = RemoteInstance and RemoteInstance.Name or "Unknown"
			FileLog:Error(
				"Logger",
				("Failed to log remote communication for %s:%s - %s"):format(
					Type or "UnknownType",
					instanceNameForError,
					tostring(err)
				)
			)

			warn(
				("Cobalt: Failed to log remote communication for %s:%s - %s"):format(
					Type or "UnknownType",
					instanceNameForError,
					tostring(err)
				)
			)
		end
	end
end

if wax.shared.SaveManager:GetState("EnableLogging", false) then
	local LogConnection = wax.shared.SetupLoggingConnection()
	wax.shared.LogConnection = wax.shared.Connect(wax.shared.Communicator.Event:Connect(LogConnection))
end

wax.shared.Log = require(script.Utils.Log)
wax.shared.Logs = {
	Outgoing = {},
	Incoming = {},
}

wax.shared.NewLog = function(Instance, Type, Method, CallingScript)
	local Log =
		wax.shared.Log.new(Instance, Type, Method, wax.shared.GetTableLength(wax.shared.Logs[Type]) + 1, CallingScript)
	wax.shared.Logs[Type][Instance] = Log
	return Log
end

require(script.Window)
require(script.Spy.Init)

local PluginManager = require(script.Utils.Plugins.Manager)
PluginManager.SetupPlugins()

wax.shared.CobaltPluginManager = PluginManager

wax.shared.Connect(wax.shared.LocalPlayer.OnTeleport:Connect(function()
	if not wax.shared.SaveManager:GetState("ExecuteOnTeleport", false) then
		return
	end

	local CobaltURL = getgenv().COBALT_LATEST_URL
		or "https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"
	wax.shared.queue_on_teleport(string.format(
		[[
		if getgenv().CobaltAutoExecuted then
			return
		end

		getgenv().CobaltAutoExecuted = true
		loadstring(game:HttpGet("%s"))()
	]],
		CobaltURL
	))
end))

getgenv().Cobalt = wax

task.wait(1)
if AnticheatData.Disabled then
	wax.shared.Sonner.success(`Cobalt has bypassed {AnticheatData.Name} (anticheat detected)`)
end

end)() end,
function()local wax,script,require=ImportGlobals(2)local ImportGlobals return (function(...)

local ExecutorSupport = {
	FailedChecks = {
		Essential = {},
		NonEssential = {},
	},
}

local BrokenFeatures = {
	["Volcano"] = { "oth", "run_on_actor" },
	["Potassium"] = { "oth" }
}

local function CheckFFlagValue(Name: string, Value: any)
	local Success, Result = pcall(getfflag, Name)
	if not Success then
		return false
	end

	if typeof(Result) == "boolean" then
		return Result
	end

	if typeof(Result) == "string" then
		return Result == tostring(Value)
	end

	return false
end

local function test(name, Callback, CheckType, Essential)
	local TestFunction = not CheckType and Callback or function()
		assert(typeof(Callback) == "function", string.format("%s is not a function.", name))
		return "Passed nil check."
	end

	if Essential == nil then
		Essential = true
	end

	local Success, Result
	if BrokenFeatures[wax.shared.ExecutorName] and table.find(BrokenFeatures[wax.shared.ExecutorName], name) then
		Success = false
		Result = "This function/library is broken or can crash your game on this executor."
	else
		Success, Result = pcall(TestFunction)
	end

	ExecutorSupport[name] = {
		IsWorking = Success,
		Details = Result,
		Essential = Essential,
	}

	if not Success then
		if Essential then
			table.insert(ExecutorSupport.FailedChecks.Essential, name)
		else
			table.insert(ExecutorSupport.FailedChecks.NonEssential, name)
		end
	end
end

-- FFlag Library
test("getfflag", getfflag, true)
test("setfflag", setfflag, true)

-- Actor Library
test("getactors", getactors, true)
test("run_on_actor", run_on_actor, true)
test("create_comm_channel", create_comm_channel, true)

-- Closure Library
test("newcclosure", function()
	assert(typeof(newcclosure) == "function", "newcclosure is not a function")
	local CClosure = newcclosure(function()
		return true
	end)

	assert(typeof(CClosure) == "function", "newcclosure did not return a function")
	assert(CClosure() == true, "Failed to create a new closure")

	assert(debug.info(CClosure, "s") == "[C]", "newcclosure did not create a C closure")
end, true)

test("checkcaller", checkcaller, true)
test("getcallingscript", getcallingscript, true)

test("hookfunction", function()
	assert(typeof(hookfunction) == "function", "hookfunction is not a function")

	local function Original(a, b)
		return a + b
	end

	local ref = hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "Failed to hook a function and change the return value")
	assert(ref(2, 3) == 5, "Did not return the original function")
end)
test("isfunctionhooked", function()
	assert(typeof(isfunctionhooked) == "function", "isfunctionhooked is not a function")
	assert(typeof(hookfunction) == "function", "hookfunction is required for this test")

	local function Original(a, b)
		return a + b
	end

	assert(isfunctionhooked(Original) == false, "isfunctionhooked returned true for an unhooked function")

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(isfunctionhooked(Original) == true, "isfunctionhooked returned false for a hooked function")
end)
test("restorefunction", function()
	assert(typeof(restorefunction) == "function", "restorefunction is not a function")
	assert(typeof(hookfunction) == "function", "hookfunction is required for this test")

	local function Original(a, b)
		return a + b
	end

	hookfunction(Original, function(a, b)
		return a * b
	end)

	assert(Original(2, 3) == 6, "Failed to hook a function and change the return value")

	restorefunction(Original)

	assert(Original(2, 3) == 5, "restorefunction did not restore the original function")
end)

test("setstackhidden", function()
	assert(typeof(setstackhidden) == "function", "setstackhidden is not a function")

	local StackCheck = {}

	local CallerFunctionSource = [[
		local StackCheck = ...
		local function CallerFunction()
			return StackCheck[1]()
		end
		return CallerFunction
	]]

	local CallerFunction = (loadstring(CallerFunctionSource, "=CallerFunction") :: (...any) -> ...any)(StackCheck)

	setstackhidden(CallerFunction, true)

	StackCheck[1] = function()
		return debug.info(2, "f") ~= CallerFunction
	end

	local IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (debug.info)")

	StackCheck[1] = function()
		return not debug.traceback():find("CallerFunction")
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (debug.traceback)")

	local TestTable = { math.huge, 0 / 0, 123, 58913 } :: { any }
	setfenv(CallerFunction, TestTable)

	StackCheck[1] = function()
		return getfenv(2) ~= TestTable
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (getfenv)")

	StackCheck[1] = function()
		return not select(2, pcall(error, "", 3)):find("CallerFunction")
	end

	IsHidden = CallerFunction()
	assert(IsHidden == true, "setstackhidden did not hide the function from the stack (error with level traceback)")
end, false, false)

test("oth", function()
	assert(oth ~= nil, "oth library not found")

	assert(typeof(oth.hook) == "function", "oth.hook is not a function")
	assert(hookfunction ~= oth.hook, "oth.hook is an alias of hookfunction")

	assert(typeof(oth.unhook) == "function", "oth.unhook is not a function")
	assert(restorefunction ~= oth.unhook, "oth.unhook is an alias of restorefunction")

	assert(typeof(oth.is_hook_thread) == "function", "oth.is_hook_thread is not a function")
	assert(typeof(oth.get_original_thread) == "function", "oth.get_original_thread is not a function")

	local VIM = Instance.new("VirtualInputManager")
	local Origin = coroutine.running()

	local Working = nil

	local Old
	Old = oth.hook(VIM.SendGravityEvent, function(...)
		if Working == nil then
			Working = (Origin ~= coroutine.running() and oth.is_hook_thread() and oth.get_original_thread() == Origin)
			return
		end

		return Old(...)
	end)

	pcall(VIM.SendGravityEvent, VIM, 0, 0, 0)

	repeat
		task.wait()
	until Working ~= nil
	local Success, Error = pcall(oth.unhook, VIM.SendGravityEvent, Old)

	VIM:Destroy()

	assert(Working, "oth.hook is not running on a seperate thread")
	assert(Success, "oth.unhook failed: " .. tostring(Error))

	assert(typeof(getrawmetatable) == "function", "getrawmetatable is required to validate oth __namecall returns")
	assert(typeof(getnamecallmethod) == "function", "getnamecallmethod is required to validate oth __namecall returns")

	local function CheckInvokeResult(Result, Context)
		if Result.n ~= 4 then
			return false, `{Context}: returned {Result.n} values instead of 4`
		end
		if Result[1] ~= "expected" then
			return false, `{Context}: did not preserve the first return value`
		end
		if Result[2] ~= 123 then
			return false, `{Context}: did not preserve the second return value`
		end
		if Result[3] ~= nil then
			return false, `{Context}: did not preserve the nil return value`
		end
		if Result[4] ~= "tail" then
			return false, `{Context}: did not preserve the tail return value`
		end

		return true
	end

	local Bindable = Instance.new("BindableFunction")
	Bindable.OnInvoke = function() return "expected", 123, nil, "tail" end

	local SuccededInsideHook, InsideError = false, nil

	local OldNamecall
	OldNamecall = oth.hook(getrawmetatable(game).__namecall, function(...)
		local self = ...
		local Method = getnamecallmethod()

		if self == Bindable and Method == "Invoke" then
			pcall(function() end)
			
			local Result = table.pack(OldNamecall(...))

			SuccededInsideHook, InsideError = CheckInvokeResult(
				Result,
				"Result corruption in __namecall oth hook"
			)

			return table.unpack(Result, 1, Result.n)
		end

		return OldNamecall(...)
	end)

	local Result = table.pack(Bindable:Invoke())
	pcall(oth.unhook, getrawmetatable(game).__namecall)
	Bindable:Destroy()

	assert(SuccededInsideHook, InsideError)
	assert(CheckInvokeResult(
		Result,
		"Result corruption post oth hook and pcall"
	))
end, false, false)

test("hookmetamethod", function()
	assert(typeof(hookmetamethod) == "function", "hookmetamethod is not a function")

	local object = setmetatable({}, {
		__index = newcclosure(function()
			return false
		end),
		__metatable = "Locked!",
	})

	local ref = hookmetamethod(object, "__index", function()
		return true
	end)

	assert(object.test == true, "Failed to hook a metamethod and change the return value")
	assert(ref() == false, "Did not return the original function")
end)
test("getnamecallmethod", function()
	assert(typeof(getnamecallmethod) == "function", "getnamecallmethod is not a function")

	pcall(function()
		game:TEST_NAMECALL_METHOD()
	end)

	assert(getnamecallmethod() == "TEST_NAMECALL_METHOD", "getnamecallmethod did not return the real namecall method")
end)
test("getrawmetatable", function()
	assert(typeof(getrawmetatable) == "function", "getrawmetatable is not a function")

	local BaseLockedMetatable = {
		__index = function()
			return false
		end,
		__metatable = "Locked!",
	}

	local TestMetatable = setmetatable({}, BaseLockedMetatable)

	local FetchedMetatable = getrawmetatable(TestMetatable)
	assert(typeof(FetchedMetatable) == "table", "getrawmetatable did not return a table")

	assert(FetchedMetatable.__index() == false, "getrawmetatable did not return the correct metatable [__index()]")
	assert(
		FetchedMetatable.__metatable == "Locked!",
		"getrawmetatable did not return the correct metatable [locked mt check]"
	)

	assert(
		FetchedMetatable == BaseLockedMetatable,
		"getrawmetatable did not return the correct metatable [mt eq check]"
	)
end)

test("getcallbackvalue", function()
	assert(typeof(getcallbackvalue) == "function", "getcallbackvalue is not a function")

	local bindable = Instance.new("BindableFunction")
	local InvokeRan = false
	local InvokeFunction = function(value)
		InvokeRan = true
		return value * 2
	end
	bindable.OnInvoke = InvokeFunction

	local FetchedInvoke = getcallbackvalue(bindable, "OnInvoke")
	bindable:Destroy()

	assert(typeof(FetchedInvoke) == "function", "getcallbackvalue did not return a function")

	assert(FetchedInvoke(5) == 10, "getcallbackvalue's function return did not match expected value")
	assert(InvokeRan, "getcallbackvalue's function did not run")
end)
test("getnilinstances", function()
	assert(typeof(getnilinstances) == "function", "getnilinstances is not a function")

	local NilInstances = getnilinstances()
	assert(typeof(NilInstances) == "table", "getnilinstances did not return a table")
end)
test("getconnections", function()
	assert(typeof(getconnections) == "function", "getconnections is not a function")

	local Event = Instance.new("BindableEvent")
	local ConnectionFunction = function() end
	local OnceFunction = function() end

	Event.Event:Connect(ConnectionFunction)
	Event.Event:Once(OnceFunction)
	task.spawn(function()
		Event.Event:Wait()
	end)

	local Connections = getconnections(Event.Event)

	assert(typeof(Connections) == "table", "getconnections did not return a table")
	assert(#Connections == 3, "getconnections did not return the correct number of connections")

	local FoundFunctions = {}
	for _, Connection in Connections do
		local _, ConnFunc = pcall(function()
			return Connection.Function
		end)

		if typeof(ConnFunc) == "function" then
			table.insert(FoundFunctions, ConnFunc)
		end
	end

	assert(
		table.find(FoundFunctions, ConnectionFunction) ~= nil,
		"getconnections did not return the correct connection [:Connect()]"
	)
	assert(
		table.find(FoundFunctions, OnceFunction) ~= nil,
		"getconnections did not return the correct connection [:Once()]"
	)

	Event:Destroy()
end)
test("firesignal", function()
	assert(typeof(firesignal) == "function", "firesignal is not a function")

	local event = Instance.new("BindableEvent")
	local fired = false

	event.Event:Once(function(value)
		fired = value
	end)

	firesignal(event.Event, true)
	task.wait(0.1)
	event:Destroy()

	assert(fired, "Failed to fire a BindableEvent")
end)
test("cloneref", function()
	assert(typeof(cloneref) == "function", "cloneref is not a function")

	local ref = cloneref(game)
	assert(ref ~= game, "cloneref did not create a ref to instance")
	assert(typeof(ref) == "Instance", "cloneref did not return an instance")
end)
test("compareinstances", function()
	assert(typeof(compareinstances) == "function", "compareinstances is not a function")
	assert(typeof(cloneref) == "function", "cloneref is required for this test")

	assert(compareinstances(game, cloneref(game)) == true, "compareinstances did not return true for the same instance")
	assert(compareinstances(game, workspace) == false, "compareinstances did not return false for different instances")
end)

return ExecutorSupport

end)() end
}

-- Execute main entry point closure
if ClosureBindings[1] then
    ClosureBindings[1]()
end

-- OVERRIDE DECOMPILER WITH BYTEFALL ENDPOINT
local ENDPOINT = "https://decompiler.bytefall.dev/decompile"

local base64 = (function()
    local a = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function b(c)
        return (c:gsub('.', function(d)
            local e, x = '', d:byte()
            for f = 8, 1, -1 do
                e = e .. (x % 2 ^ f - x % 2 ^ (f - 1) > 0 and '1' or '0')
            end
            return e
        end) .. '0000'):gsub('%d%d%d?%d?%d?', function(d)
            if #d < 6 then return '' end
            local g = 0
            for f = 1, 6 do
                g = g + (d:sub(f, f) == '1' and 2 ^ (6 - f) or 0)
            end
            return a:sub(g + 1, g + 1)
        end) .. ({ '', '==', '=' })[#c % 3 + 1]
    end
    return { encode = b }
end)()

local getscriptbytecode = getscriptbytecode
local request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

if request then
    local function decompile(s)
        local bc = getscriptbytecode(s)
        if not bc or bc == "" then
            return "-- ByteFall: getscriptbytecode returned empty"
        end

        local body = '{"script":"' .. base64.encode(bc) .. '"}'

        local response = request {
            Url = ENDPOINT,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        }

        local code = response.StatusCode or response.Status or 0
        if code == 200 then
            return response.Body
        elseif code == 400 then
            return "-- ByteFall (400 bad request): " .. tostring(response.Body)
        elseif code == 500 then
            return "-- ByteFall (500 decompilation failed): " .. tostring(response.Body)
        elseif code == 404 then
            return "-- ByteFall (404 not found): wrong endpoint?"
        else
            return "-- ByteFall (HTTP " .. tostring(code) .. "): " .. tostring(response.Body)
        end
    end

    getgenv().decompile = decompile
end
