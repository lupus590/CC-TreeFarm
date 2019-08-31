require("treeFarm.libs.argChecker")
local utils = require("treeFarm.libs.utils")
local itemUtils = utils.itemUtils
local itemIds = itemUtils.itemIds
local daemonManager = require("treeFarm.libs.daemonManager")
local config = require("treeFarm.libs.config")
local taskManager = require("treeFarm.libs.taskManager")
local checkpoint = require("treeFarm.libs.checkpoint")


local chestMap = {}


local function fuelValueForFurnace(turtleFuelValue)
  argChecker(1, turtleFuelValue, {"number"})
  return turtleFuelValue/10
end

-- NOTE: don't fill the turtle refuel chest, just keep a stack of both items in there.

local function init()
  -- TODO: how to diffienciate input from output and locate the turtle restock chests
  -- will have to ask the user
  -- ask user to put unique item into each chest and to label them

  -- NOTE: i can tell automatically, get the turtle to drop and suck from the chests, the two that change in the right way are the refuel and drop off chests
end

local function emptyCollectionChest()
  -- TODO: implement
  -- for each slot in the imput chest
    -- if the item stack is saplings then put as much as possible in the turtle's refuel chest and move the rest to the output chests
    -- elseif the item is logs then move half of it to the furnaces input (make multiples of 8) and the other half to the output chests
    -- else move the item to the output chests

end

local function refuelfurnaces() -- NOTE: can I get this to use different fuels?
  -- TODO: implement
  -- if a furnace has 8 items or more that will not get smelted due to insufficent fuel then search output chests and furnace output slots and add a charcoal
end

local function emptyFurnaces()
  -- TODO: implement
  -- just dump everything in the output slot into the output chests
  -- don't forget the turtle refuel chest
end

local function refillTurtleChest()
  -- TODO: implement
  -- move stuff from the output chests to fill the turtle chest
end

-- TODO: farm manager watchdog for if the farm manager forwards an error to us
local function farmerWatchdog()
  -- listen for specific rednet messages
  -- mark the screen if one such message is recived
end

local function run()
  -- TODO: pcall things and for any uncaught errors mark the screen
end


local furnaceManager = {
  loadThisFurnace = loadThisFurnace,
  getResources = getResources,
  putAwayNotWood = putAwayNotWood,
  run = run
}

return furnaceManager
