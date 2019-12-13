-- TODO: serverless?
  -- remote just broadcasts
  -- remote only needs to talk to the main turtle
  -- still have multiple farming turtles?

 -- TODO: take from config
 -- multiple server names? remote has one and the furnace has one?
 -- turtle and furnace manager pair like bluetooth
local rootProtocol = "lupus590:TreeFarm"

local modem = -- TODO: locate wireless modem
rednet.open(modem)

local function send(id, message, subProtocol)
  argChecker(1, id, {"number"})
  argChecker(1, id, {"number"})


  if subProtocol and string.sub(subProtocol, 1, 1) ~=":" then
    subProtocol = ":"..subProtocol
  end

  local fullProtocol = rootProtocol..subProtocol

  rednet.send(id, message, fullProtocol)
end

local function pair(id)

end

local function ping(id)
  argChecker()

  -- send ping message

  -- listen for responce

  if responce then
    return true
  else
    return false
  end
end

local function run()
  while true do
    local message = table.pack(rednet.recive())

    if message is ping then
      repond to ping
    elseif message is pairing request then
      check pairing state
        pair if appropiate
    end

  end
end

local rednetUtils = {
  rootProtocol = rootProtocol,
  send = send,
  ping = ping,
  run = run,
}

return rednetUtils
