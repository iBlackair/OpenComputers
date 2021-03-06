API = require("buttonAPI")
local filesystem = require("filesystem")
local component = require("component")
local keyboard = require("keyboard")
local event = require("event")
local gpu = component.gpu
local reactor = component.induction_matrix

local versionType = "NEW"

local DEBUG = false
local debugList = {}
local debugVars = {}


local colors = { blue = 0x4286F4, purple = 0xB673d6, red = 0xC14141, green = 0xDA841,
  black = 0x000000, white = 0xFFFFFF, grey = 0x47494C, lightGrey = 0xBBBBBB}
-- set size of the screen for lvl 3
gpu.setResolution(132,38)
gpu.setBackground(colors.black)
gpu.fill(1, 1, 132, 38, " ")

local sections = {}
local graphs = {}
local infos = {}


-- defninitions
reactor["stats"] = {}
local running = true
local maxRF = 0
local reactorRodsLevel = {}
local currentRodLevel = 0
local currentRf = 0
local currentRfTick = 0
local currenFuel = 0

local minPowerRod = 0
local maxPowerRod = 100


-- functions

function toint(n)
    local s = tostring(n)
    local i, j = s:find('%.')
    if i then
        return tonumber(s:sub(1, i-1))
    else
        return n
    end
end

function setSections()
  sections["graph"] = { x = 5, y = 3, width = 78, height= 33, title = "  INFOS  "}
  sections["controls"] = { x = 88, y = 3, width = 40, height = 20, title = "  CONTROLS  "}
  sections["info"] = { x = 88, y = 26, width = 40, height= 10, title = "  NUMBERS  "}
end

function setGraphs()
  graphs["tick"] = { x = 8, y = 6, width = 73, height= 8, title = "ENERGY LAST TICK"}
  graphs["stored"] = { x = 8, y = 16, width = 73, height = 8, title = "ENERGY STORED"}
  graphs["rods"] = { x = 8, y = 26, width = 73, height= 8, title = "CONTROL RODS LEVEL"}
end

function setInfos()
  infos["tick"] = { x = 92, y = 28, width = 73, height= 1, title = "INPUT : ", unit = " RF/T"}
  infos["rods"] = { x = 92, y = 30, width = 73, height = 1, title = "OUTPUT : ", unit = " RF/T"}
  infos["stored"] = { x = 92, y = 32, width = 73, height= 1, title = "STORED :", unit = " RF"}
  --infos["fuel"] = { x = 92, y = 34, width = 73, height= 1, title = "FUEL USAGE : ", unit = " Mb/t"}
end

function debugInfos()  
  debug["print"] = { x = 1, y = 38, width = 73, height= 1, title = "DBG : "}
end

function setButtons()
  API.setTable("ON", powerOn, 91, 5, 106, 7,"ON", {on = colors.green, off = colors.green})
  API.setTable("OFF", powerOff, 109, 5, 125, 7,"OFF", {on = colors.red, off = colors.red})

  API.setTable("lowerMinLimit", lowerMinLimit, 91, 15, 106, 17,"-10", {on = colors.blue, off = colors.blue})
  API.setTable("lowerMaxLimit", lowerMaxLimit, 109, 15, 125, 17,"-10", {on = colors.purple, off = colors.purple})

  API.setTable("augmentMinLimit", augmentMinLimit, 91, 19, 106, 21,"+10", {on = colors.blue, off = colors.blue})
  API.setTable("augmentMaxLimit", augmentMaxLimit, 109, 19, 125, 21,"+10", {on = colors.purple, off = colors.purple})
end

function printBorders(sectionName)
  local s = sections[sectionName]

  -- set border
  gpu.setBackground(colors.grey)
  gpu.fill(s.x, s.y, s.width, 1, " ")
  gpu.fill(s.x, s.y, 1, s.height, " ")
  gpu.fill(s.x, s.y + s.height, s.width, 1, " ")
  gpu.fill(s.x + s.width, s.y, 1, s.height + 1, " ")

  -- set title
  gpu.setBackground(colors.black)
  gpu.set(s.x + 2, s.y, s.title)
end

function printGraphs(graphName)
  local g = graphs[graphName]

  -- set graph
  gpu.setBackground(colors.lightGrey)
  gpu.fill(g.x, g.y, g.width, g.height, " ")

  -- set title
  gpu.setBackground(colors.black)
  gpu.set(g.x, g.y - 1, g.title)
end

function printActiveGraphs(activeGraph)
  local g = activeGraph

  -- set graph
  gpu.setBackground(colors.green)
  gpu.fill(g.x, g.y, g.width, g.height, " ")
  gpu.setBackground(colors.black)
end

function printStaticControlText()
gpu.setForeground(colors.blue)
  gpu.set(97,12, "MIN")
  gpu.setForeground(colors.purple)
  gpu.set(116,12, "MAX")
  gpu.setForeground(colors.white)
  gpu.set(102,10, "AUTO-CONTROL")
  gpu.set(107,13, "--")
end

function printControlInfos()

  gpu.setForeground(colors.blue)
  gpu.set(97,13, minPowerRod .. "% ")
  gpu.setForeground(colors.purple)
  gpu.set(116,13, maxPowerRod .. "% ")
  gpu.setForeground(colors.white)
end

function printInfos(infoName)
  local maxLength = 15
  local i = infos[infoName]
  local spaces = string.rep(" ", maxLength - string.len(reactor.stats[infoName] .. i.unit))
  gpu.set(i.x, i.y , i.title .. reactor.stats[infoName] .. i.unit .. spaces)
end

function getInfoFromReactor()
  reactor.stats["tick"] = shrink(reactor.getInput() / 2.5)
  reactor.stats["rods"] = shrink(reactor.getOutput() / 2.5)
  reactor.stats["stored"] = shrink(reactor.getEnergy()/ 2.5) 
  currentRf = reactor.stats["stored"]
end
function getInfoFromReactorOLD()
  reactor.stats["tick"] = shrink(reactor.getInput() / 2.5)
  reactor.stats["rods"] = shrink(reactor.getOutput() / 2.5)
  reactor.stats["stored"] = shrink(reactor.getEnergy()/ 2.5) 
  currentRf = reactor.stats["stored"]
end

function draw()
--[[
  if maxRF < reactor.stats["tick"] then
    maxRF = reactor.stats["tick"]
  end
--]]
  --[[if currentRfTick ~= reactor.stats["tick"] then
    currentRfTick = reactor.stats["tick"]
	
    local max = math.ceil(graphs["tick"].width * (currentRfTick/maxRF))
    local currentRFTickObj = {x = graphs["tick"].x, y = graphs["tick"].y, width = max, height = graphs["tick"].height}
	--]]
    printInfos("tick")
	printInfo("rods")
	--[[
    printGraphs("tick")
    printActiveGraphs(currentRFTickObj)
  end--]]

  if currentRF ~= toint(reactor.stats["stored"]) then
    currentRF = toint(reactor.stats["stored"])
	local inductionEnergyStored = reactor.getEnergy()/(reactor.getMaxEnergy()/100)
    local max = math.ceil(graphs["stored"].width * (currentRF/reactor.getMaxEnergy()))
    local currentRFObj = {x = graphs["stored"].x, y = graphs["stored"].y, width = max, height = graphs["stored"].height}
    printInfos("stored")
    printGraphs("stored")
    printActiveGraphs(currentRFObj)
  end
  
  printControlInfos()
  if DEBUG == true then
    printDebug()
  end
end

function startup()
  if versionType == "NEW" then
    getInfoFromReactor()
  else
    getInfoFromReactorOLD()
  end
  setSections()
  setGraphs()
  setInfos()
  setButtons()
  if DEBUG == true then
    debugInfos()
    printDebug()
  end

  for name, data in pairs(sections) do
    printBorders(name)
  end
  for name, data in pairs(graphs) do
    printGraphs(name)
  end
  for name, data in pairs(infos) do
    printInfos(name)
  end
  printStaticControlText()


end


-- helpers
function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

function shrink(number)
  if number >= 10^12 then
    return string.format("%.2ft", number / 10^12)
  elseif number >= 10^9 then
    return string.format("%.2fb", number / 10^9)
  elseif number >= 10^6 then
    return string.format("%.2fm", number / 10^6)
  elseif number >= 10^3 then
    return string.format("%.2fk", number / 10^3)
  else
    return tostring(number)
  end
end


function testVersion()
  reactor.getEnergyStats()
end

function setOldVersion()
  versionType = "OLD"
end
-- starting
xpcall(testVersion, setOldVersion)
startup()
API.screen()

event.listen("touch", API.checkxy)

while event.pull(0.1, "interrupted") == nil do
  if versionType == "NEW" then
    if reactor.mbIsConnected() == true and reactor.mbIsAssembled() == true then
      getInfoFromReactor()
    end
  else
    getInfoFromReactorOLD()
  end
  --calculateAdjustRodsLevel()
  draw()
  local event, address, arg1, arg2, arg3 = event.pull(1)
  if type(address) == "string" and component.isPrimary(address) then
    if event == "key_down" and arg2 == keyboard.keys.q then
      os.exit()
    end
  end
end