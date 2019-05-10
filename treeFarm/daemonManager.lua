-- daemon manager
--
-- background process host
--
-- Licence: MIT Lupus590

-- TODO: proper license header #high


-- TO DO: messaging system
  -- daemons receive as an event
  -- look at how rednet works?
  -- a daemon should not be able to message itself

local daemons = {}
local raiseErrorsInDaemons = false

local function resumeDaemon(daemonName,event)
  if type(daemonName) ~= "string" then
    error("Arg[1] expected string, got "..type(daemonName), 2)
  end
  if event and type(event) ~= "table" then
    error("Arg[2] expected table or nil, got "..type(event), 2)
  end
  if coroutine.status(v) ~= "suspended" then
    local returnedValues = table.pack(coroutine.resume(daemons[newDaemonName].coroutine, event and table.unpack(event, 1, event.n) or nil))
    local ok = table.remove(returnedValues, 1)
    if not okthen
      if raiseErrorsInDaemons then
        error("daemonManager error in daemon "..daemonName.."\n"..toString(table.unpack(returnedValues, 1, returnedValues.n)))
      end
      daemos[newDaemonName] = nil
    end
    daemons[newDaemonName].eventFilter = returnedValues[1]
  end
end


local function add(newDaemonName, newdaemonFunc, replaceIfExists, stopFunction)
  if type(newDaemonName) ~= "string" then
    error("Arg[1] expected string, got "..type(newDaemonName),2)
  end
  if type(newdaemonFunc) ~= "function" then
    error("Arg[2] expected function, got "..type(newdaemonFunc),2)
  end
  if replaceIfExists and type(replaceIfExists) ~= "bool" then
    error("Arg[3] expected bool or nil, got "..type(replaceIfExists),2)
  end
  if stopFunction and type(stopFunction) ~= "function" then
    error("Arg[4] expected function or nil, got "..type(stopFunction),2)
  end
  if not replaceIfExists and daemons[newDaemonName] then
    error("daemon with name "..newDaemonName.." exists - to overwrite set arg[3] to true",2)
  end
  daemons[newDaemonName] = {coroutine = coroutine.create(newdaemonFunc), eventFilter = nil, stopFunction = stopFunction}
  resumeDaemon(newDaemonName, {})
  daemons[newDaemonName].eventFilter = returnedValues[1]
end

local function remove(daemonName)
  if type(daemonName) ~= "string" then
    error("Arg[1] expected string, got "..type(daemonName))
  end
  daemons[daemonName] = nil
end

local function stopDaemon(daemonName)
  if type(daemonName) ~= "string" then
    error("Arg[1] expected string, got "..type(daemonName), 2)
  end
  if not daemons[daemonName] then
    return false, "no daemon with that name"
  end
  if not daemons[daemonName].stopFunction then
    return false, "no stop function for this daemon"
  end
  return true, daemons[daemonName].stopFunction() -- the stop function may give it's own status info
end

local function terminateDaemon(daemonName)
  if type(daemonName) ~= "string" then
    error("Arg[1] expected string, got "..type(daemonName),2)
  end
  if not daemons[daemonName] then
    return false, "no daemon with that name"
  end
  local ok, err = pcall(resumeDaemon, newDaemonName, table.pack("terminate", "daemonManager"))
  if (not ok) and err == "Terminated" then
    return true -- we killed it
  end
  return false -- it won't die (it might on future resumes, no guarantee)
end

local function getDaemonList()
  local list = {}
  for k,v in pairs(daemons) do
    table.add(list,k) -- users can list them all with ipairs
    list[k]=true -- or index by name to see if it's there
  end
  return list
end

local function daemonHost()
  local event = table.pack(os.pullEventRaw())
  if not doLoop then
    return
  end
  for k, v in pairs(daemons)
    if coroutine.status(v) == "suspended" then
      if v.eventFilter == nil or v.eventFilter == event[1] then
        resumeDaemon(k, event))
      end
    elseif coroutine.status(v) == "dead" then
      daemons[k] = nil
    end
  end
end

local doLoop = true
local function exitLoop()
  doLoop = false
end

local running = false
local function enterLoop(raiseErrors)
  running = true
  raiseErrorsInDaemons = raiseErrors
  while doLoop do
    daemonHost()
  end
  doLoop = true -- just in case people want to start us again
  running = false
end

local function isRunning()
  return running
end


local daemonManager = {
  add = add,
  remove = remove,
  stopDaemon = stopDaemon,
  terminateDaemon = terminateDaemon
  getDaemonList = getDaemonList,
  daemonHost = daemonHost,
  exitLoop = exitLoop,
  enterLoop = enterLoop,
  run = enterLoop,
  start = enterLoop,
  stop = exitLoop,
  isRunning = isRunning,
  hasStarted = isRunning,
}

return daemonManager
