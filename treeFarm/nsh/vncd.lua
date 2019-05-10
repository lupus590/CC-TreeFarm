-- TODO: convert to API
  -- once converted copy to hive

-- TODO: allow convert from nsh to vncd and back
  -- https://github.com/lyqyd/cc-netshell/issues/1

-- TODO: scroll bars if client screen is smaller
  -- resize the remote?

--[[
Copyright (c) 2012 Christopher Beach

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

-- NOTE: has a nsh API?

local args = {...}

local connections = {}

local nshAPI = {
  connList = connections
}

nshAPI.getRemoteID = function()
  return false
end

nshAPI.send = function(msg)
  return false
end

nshAPI.receive = function(timeout)
  return false
end

nshAPI.getClientCapabilities = function()
  return false
end

nshAPI.getRemoteConnections = function()
  local remotes = {}
  for cNum, cInfo in pairs(nshAPI.connList) do
    table.insert(remotes, cNum)
    if cInfo.outbound then
      table.insert(remotes, cInfo.outbound)
    end
  end
  return remotes
end

nshAPI.packFile = function(path)
  return false
end

nshAPI.unpackAndSaveFile = function(path, data)
  return false
end

local packetConversion = {
  query = "SQ",
  response = "SR",
  data = "SP",
  close = "SC",
  textTable = "TT",
  event = "EV",
  SQ = "query",
  SR = "response",
  SP = "data",
  SC = "close",
  TT = "textTable",
  EV = "event",
}

local function openModem()
  local modemFound = false
  for _, side in ipairs(rs.getSides()) do
    if peripheral.getType(side) == "modem" then
      if not rednet.isOpen(side) then rednet.open(side) end
      modemFound = true
      break
    end
  end
  return modemFound
end

local function send(id, pType, message)
  if pType and message then
    if term.current then
      return rednet.send(id, packetConversion[pType]..":;"..message, "tror")
    else
      return rednet.send(id, packetConversion[pType]..":;"..message)
    end
  end
end

local function resumeThread(co, event)
  if not co.filter or event[1] == co.filter then
    co.filter = nil
    local _old = term.redirect(co.target)
    local passback = {coroutine.resume(co.thread, unpack(event))}
    if _old then term.redirect(_old) else term.restore() end
    if passback[1] and passback[2] then
      co.filter = passback[2]
    end
    if coroutine.status(co.thread) == "dead" then
      for cNum, cInfo in pairs(connections) do
        send(cNum, "close", "disconnect")
      end
      connections = {}
    end
    if connections[conn] and conn ~= "localShell" and framebuffer then
      for cNum, cInfo in pairs(connections) do
        send(cNum, "textTable", textutils.serialize(co.target.buffer))
      end
    end
    framebuffer.draw(co.target.buffer)
  end
end

if not openModem() then error("No modem present!") end

local framebuffer = require("framebuffer")

term.clear()
term.setCursorPos(1,1)
local x, y = term.getSize()

local redirect = framebuffer.new(x, y, term.isColor())

local shellRoutine = coroutine.create(function() shell.run("/rom/programs/shell", unpack(args)) end)
local co = {thread = shellRoutine, target = redirect}

resumeThread(co, {})

_G.nsh = nshAPI

while coroutine.status(co.thread) ~= "dead" do
  event = {os.pullEventRaw()}
  if event[1] == "rednet_message" then
    if packetConversion[string.sub(event[3], 1, 2)] then
      --this is a packet meant for us.
      conn = event[2]
      packetType = packetConversion[string.sub(event[3], 1, 2)]
      message = string.match(event[3], ";(.*)")
      if connections[conn] and connections[conn].status == "open" then
        if packetType == "event" then
          local eventTable = textutils.unserialize(message)
          resumeThread(co, eventTable)
        elseif packetType == "query" then
          connections[conn] = {status = "open"}
          send(conn, "response", "OK")
          send(conn, "textTable", textutils.serialize(co.target.buffer))
        elseif packetType == "close" then
          connections[conn] = nil
          send(conn, "close", "disconnect")
          --close connection
        end
      elseif packetType ~= "query" then
        --usually, we would send a disconnect here, but this prevents one from hosting nsh and connecting to other computers. Pass these to all shells as well.
        resumeThread(co, event)
      else
        --open new connection
        connections[conn] = {status = "open"}
        send(conn, "response", "OK")
        send(conn, "textTable", textutils.serialize(co.target.buffer))
      end
    else
      --rednet message, but not in the correct format, so pass to all shells.
      resumeThread(co, event)
    end
  elseif event[1] == "terminate" then
    break
  else
    --dispatch all other events to all shells
    resumeThread(co, event)
  end
end

for cNum, cInfo in pairs(connections) do
  send(cNum, "close", "disconnect")
end
_G.nsh = nil
