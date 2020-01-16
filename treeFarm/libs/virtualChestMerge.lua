--[[
-- @Name: VirtualChestMerge
-- @Author: Lupus590
-- @License: MIT
-- @URL: https://github.com/CC-Hive/Checkpoint
--
-- If you are interested in the above format: http://www.computercraft.info/forums2/index.php?/topic/18630-rfc-standard-for-program-metadata-for-graphical-shells-use/
--
-- Makes multiple plethora inventories look like one big inventory
--
-- Note, you have to wrap every inventory that will interact with the merged one so that the single inventories can push to the merged inventory peripheral name string.
-- I'm working on allowing virtuals peripherals to interact with real ones directly
--
-- VirtualChestMerge's License:
--
--  The MIT License (MIT)
--
--  Copyright (c) 2019 Lupus590
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions: The above copyright
-- notice and this permission notice shall be included in all copies or
-- substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
-- ]]




-- TODO: override peipheral api?
-- TODO: add fluid support #bonus
-- https://squiddev-cc.github.io/plethora/methods.html#targeted-methods-net.minecraftforge.common.capabilities.ICapabilityProvider
-- https://squiddev-cc.github.io/plethora/methods.html#targeted-methods-net.minecraftforge.fluids.capability.IFluidHandler
-- https://squiddev-cc.github.io/plethora/methods.html#targeted-methods-net.minecraftforge.items.IItemHandler
-- https://squiddev-cc.github.io/plethora/methods.html#org.squiddev.plethora.integration.MethodTransferLocations

-- TODO: there is quite a bit of duplicated code, can this be reduced?

-- TODO: can some of the peripheral calls be done in parallel? someone on discord noticed a speed increase and some commands seemed slow in testing
-- add a flag on the vitual peripheral to parallelise stuff which can be turned off later?

local function argChecker(position, value, validTypesList, level)
  -- check our own args first, sadly we can't use ourself for this
  if type(position) ~= "number" then
    error("argChecker: arg[1] expected number got "..type(position),2)
  end
  -- value could be anything, it's what the caller wants us to check for them
  if type(validTypesList) ~= "table" then
    error("argChecker: arg[3] expected table got "..type(validTypesList),2)
  end
  if not validTypesList[1] then
    error("argChecker: arg[3] table must contain at least one element",2)
  end
  for k, v in ipairs(validTypesList) do
    if type(v) ~= "string" then
      error("argChecker: arg[3]["..tostring(k).."] expected string got "..type(v),2)
    end
  end
  if type(level) ~= "nil" and type(level) ~= "number" then
    error("argChecker: arg[4] expected number or nil got "..type(level),2)
  end
  level = level and level + 1 or 3

  -- check the client's stuff
  for k, v in ipairs(validTypesList) do
    if type(value) == v then
      return
    end
  end

  local expectedTypes
  if #validTypesList == 1 then
      expectedTypes = validTypesList[1]
  else
      expectedTypes = table.concat(validTypesList, ", ", 1, #validTypesList - 1) .. " or " .. validTypesList[#validTypesList]
  end

  error("arg["..tostring(position).."] expected "..expectedTypes
  .." got "..type(value), level)
end

local function numberRangeChecker(argPosition, value, lowerBound, upperBound, level)
  argChecker(1, argPosition, {"number"})
  argChecker(2, value, {"number"})
  argChecker(3, lowerBound, {"number", "nil"})
  argChecker(4, upperBound, {"number", "nil"})
  argChecker(5, level, {"number", "nil"})
  level = level and level +1 or 3

  if lowerBound > upperBound then
    local temp = upperBound
    upperBound = lowerBound
    lowerBound = temp
  end

  if value < lowerBound or value > upperBound then
    error("arg["..argPosition.."] must be between "..lowerBound.." and "..upperBound,level)
  end
end

local virtualPeripheralList = {}

local function translateSlot(virtualPeripheral, virtualSlot) -- returns peripheralWithVirtualSlot, physicalSlotNumber
  argChecker(1, virtualPeripheral, {"table"})
  argChecker(2, virtualSlot, {"number"})

  if virtualSlot > virtualPeripheral.size() or virtualSlot < 1 then
    error("arg[1] number out of range, must be between 1 and "..virtualPeripheral.size(), 2)
  end

  local scannedSize = 0
  for k, v in ipairs(virtualPeripheral._backingPeripheralList) do
    local currentBackerSize = virtualPeripheral._backingPeripheralList[k].size()
    if virtualSlot <= scannedSize + currentBackerSize then
      -- this is our backer peripheral
      return virtualPeripheral._backingPeripheralList[k], virtualSlot-scannedSize -- peripheralWithVirtualSlot, physicalSlotNumber
    end
    scannedSize = scannedSize + currentBackerSize
  end
  error("virtualChestMerge:translateSlot got to that line that we shouldn't have been able to get to")
end

-- wrap all
local function wrap(...)
  local backingPeripheralsList = {}
  if type(arg[1]) == "table" then -- allow users to give one table argument instead of multiple arguments
    arg = arg[1]
  end
  for k, v in ipairs(arg) do
    argChecker(k, v, {"string"})
    if not (peripheral.isPresent(v) or virtualPeripheralList[v]) then
      error("arg["..k.."] not a valid peripheral side/name, got"..v)
    end
    backingPeripheralsList[k] = peripheral.wrap(v) or virtualPeripheralList[v]
    backingPeripheralsList[k]._peripheralName = v
  end

  -- create new virtual peripheral which links all of the arg peripherals together and translates the vitual names

  local thisVirtualPeripheral = {}

  function thisVirtualPeripheral.size()
    local total = 0
    for k, v in ipairs(backingPeripheralsList) do
      total = total + backingPeripheralsList[k].size()
    end
    return total
  end

  function thisVirtualPeripheral.getItem(slot)
    argChecker(1, slot, {"number"})
    numberRangeChecker(1, slot, 1, thisVirtualPeripheral.size())

    -- locate backer with this slot
    local backer, trueSlot = translateSlot(thisVirtualPeripheral, slot)
    return backer.getItem(trueSlot)
  end

  function thisVirtualPeripheral.getItemMeta(slot)
    argChecker(1, slot, {"number"})
    numberRangeChecker(1, slot, 1, thisVirtualPeripheral.size())

    -- locate backer with this slot
    local backer, trueSlot = translateSlot(thisVirtualPeripheral, slot)
    return backer.getItemMeta(trueSlot)
  end

  function thisVirtualPeripheral.list()
    local list = {}
    local listSize = 0
    for k, v in ipairs(backingPeripheralsList) do
      local currentBackerSize = backingPeripheralsList[k].size()
      local additions = backingPeripheralsList[k].list()
      for i=1, currentBackerSize do
        list[listSize+i] = additions[i]
      end
      listSize = listSize + currentBackerSize
    end
    return list
  end

  function thisVirtualPeripheral.pushItems(virtualToName, virtualFromSlot, limit, virtualToSlot)
    argChecker(1, virtualToName, {"string"})
    argChecker(2, virtualFromSlot, {"number"})
    numberRangeChecker(1, virtualFromSlot, 1, thisVirtualPeripheral.size())
    argChecker(3, limit, {"number", "nil"})
    argChecker(4, virtualToSlot, {"number", "nil"})


    local virtualToPeripheral = virtualPeripheralList[virtualToName] or (function()
      -- make a fake virtualPeripheral so that we can unwrap it latter, because the item manipulation assumes that the remote peripheral is virtual
      if !peripheral.isPresent(virtualToName) then
        return nil
      end
      local realPeripheralName = virtualToName
      local p = peripheral.wrap(realPeripheralName)
      p._backingPeripheralList = {p} -- circular loop, will this break things?
      p._peripheralName = realPeripheralName
      return p
    end)() -- TODO: test this #homeOnly
    -- should allow virtual to interact with real peripherals 'directly'
    -- then copy to pullItems

    if not virtualToPeripheral then
      error("arg[1] no virtual peripheral with name "..virtualToName,2)
    end
    if virtualToSlot then
      numberRangeChecker(1, virtualToSlot, 1, thisVirtualPeripheral.size())
    end

    virtualFromSlot = math.floor(virtualFromSlot)
    numberRangeChecker(2, virtualFromSlot, 1, thisVirtualPeripheral.size())
    limit = limit and math.floor(limit)
    virtualToSlot = virtualToSlot and (function()
      local r = math.floor(virtualToSlot)
      numberRangeChecker(4, r, 1, virtualToPeripheral.size())
      return r
    end)()

    local realFromPeripheral = thisVirtualPeripheral
    local realFromSlot = virtualFromSlot
    repeat
      realFromPeripheral, realFromSlot= translateSlot(realFromPeripheral, realFromSlot)
    until not realFromPeripheral._isVirtual

    if not limit then
      local item = realFromPeripheral.getItemMeta(realFromSlot)
      if item then
        limit = item.count
      else
        return 0 -- nothing to move
      end
    end
    if limit < 1 then
      error("arg[3] limit must be 1 or greater")
    end

    if virtualToSlot then
      local realToPeripheral = virtualToPeripheral
      local realToSlot = virtualToSlot
      repeat
        realToPeripheral, realToSlot= translateSlot(realToPeripheral, realToSlot)
      until not realToPeripheral._isVirtual

      return realFromPeripheral.pushItems(realToPeripheral._peripheralName, realFromSlot, limit, realToSlot)
    end

    local targets = virtualToPeripheral._backingPeripheralList
    local totalMoved = 0
    for i = 1, #targets do
      local moved = 0
      if targets[i]._isVirtual then
        moved = thisVirtualPeripheral.pushItems(targets[i]._peripheralName, virtualFromSlot, limit)
      else
        moved = realFromPeripheral.pushItems(targets[i]._peripheralName, realFromSlot, limit)
      end
      totalMoved = totalMoved + moved
      limit = limit - moved
      if limit == 0 then
        break
      end
    end
    return totalMoved
  end

  function thisVirtualPeripheral.pullItems(virtualFromName, virtualFromSlot, limit, virtualToSlot)
    argChecker(1, virtualFromName, {"string"})
    argChecker(2, virtualFromSlot, {"number"})
    argChecker(3, limit, {"number", "nil"})
    argChecker(4, virtualToSlot, {"number", "nil"})

    local virtualFromPeripheral = virtualPeripheralList[virtualFromName]

    if not virtualFromPeripheral then
      error("arg[1] no virtual peripheral with name "..virtualFromName,2)
    end

    if virtualToSlot then
      numberRangeChecker(1, virtualToSlot, 1, thisVirtualPeripheral.size())
    end

    virtualFromSlot = math.floor(virtualFromSlot)
    numberRangeChecker(2, virtualFromSlot, 1, virtualFromPeripheral.size())
    limit = limit and math.floor(limit)
    virtualToSlot = virtualToSlot and (function()
      local r = math.floor(virtualToSlot)
      numberRangeChecker(4, r, 1, thisVirtualPeripheral.size())
      return r
    end)()

    local realFromPeripheral = virtualFromPeripheral
    local realFromSlot = virtualFromSlot
    repeat
      realFromPeripheral, realFromSlot= translateSlot(realFromPeripheral, realFromSlot)
    until not realFromPeripheral._isVirtual

    if not limit then
      local item = realFromPeripheral.getItemMeta(realFromSlot)
      if item then
        limit = item.count
      else
        return 0 -- nothing to move
      end
    end
    if limit < 1 then
      error("arg[3] limit must be 1 or greater")
    end

    if virtualToSlot then
      local realToPeripheral = thisVirtualPeripheral
      local realToSlot = virtualToSlot
      repeat
        realToPeripheral, realToSlot= translateSlot(realToPeripheral, realToSlot)
      until not realToPeripheral._isVirtual

      return realToPeripheral.pullItems(realFromPeripheral._peripheralName, realFromSlot, limit, realToSlot)
    end

    local targets = thisVirtualPeripheral._backingPeripheralList
    local totalMoved = 0
    for i = 1, #targets do
      local moved = 0
      if targets[i]._isVirtual then
        moved = thisVirtualPeripheral.pullItems(targets[i]._peripheralName, virtualFromSlot, limit)
      else
        moved = targets[i].pullItems(realFromPeripheral._peripheralName, realFromSlot, limit)
      end
      totalMoved = totalMoved + moved
      limit = limit - moved
      if limit == 0 then
        break
      end
    end
    return totalMoved
  end



  thisVirtualPeripheral._backingPeripheralList = backingPeripheralsList -- lua needs read only tables which play nice
  thisVirtualPeripheral._translateSlot = function(slot)
    local ok, peripheralOrErr
    ok, peripheral, slot = pcall(translateSlot, thisVirtualPeripheral, slot)
    if not ok then
      err = string.sub(peripheralOrErr, 8)
      error(err, 2)
    end
    local peripheral = peripheralOrErr
    return peripheral, slot
  end

  thisVirtualPeripheral._peripheralName = "virtualItemHandler_"..string.format("%08x", math.random(1, 2147483647))

  thisVirtualPeripheral._isVirtual = true

  virtualPeripheralList[thisVirtualPeripheral._peripheralName] = thisVirtualPeripheral

  return thisVirtualPeripheral
end


local virtualChestMerge = {
  wrap = wrap,
}

return virtualChestMerge
