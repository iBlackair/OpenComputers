API = require("buttonAPI")
local filesystem = require("filesystem")
local component = require("component")
local keyboard = require("keyboard")
local event = require("event")
local gpu = component.gpu
local reactor = component.nc_fission_reactor

local versionType = "NEW"

local DEBUG = false
local debugList = {}
local debugVars = {}


local colors = { blue = 0x4286F4, purple = 0xB673d6, red = 0xC14141, green = 0xDA841,
  black = 0x000000, white = 0xFFFFFF, grey = 0x47494C, lightGrey = 0xBBBBBB, darkblue = 0x1029CA, mudyellow =0xEBDE3A, orange = 0xEE9815,
      darkred= 0xFF0000 }
-- set size of the screen for lvl 3

gpu.setResolution(132,38)
gpu.setBackground(colors.black)
gpu.fill(1, 1, 132, 38, " ")

local sections = {}
local graphs = {}
local infos = {}

-- definitions

reactor["stats"] = {}
local running = true
local maxRF = 0
local reactorRodsLevel = {}
local currentRodLevel = 0
local currentRf = 0
local currentRfTick = 0
local currenFuel = 0
local CurrentFuelTime = 0
local TotalFuelTime = 0
local MaximumStorage = 0
local fore = darkblue
local PowerCooling = false
local HeatCooling = false

local minPowerRod = 0
local maxPowerRod = 100

local currentHeat =0
local MaxHeat = 0


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
  sections["graph"] = { x = 5, y = 3, width = 39, height= 33, title = "  INFO  "}
  sections["controls"] = { x = 47, y = 3, width = 40, height = 20, title = "  CONTROLS  "}
  sections["info"] = { x = 47, y = 25, width = 40, height= 11 , title = "  STATS  "}
end

function setGraphs()
  graphs["tick"] = { x = 8, y = 5, width = 10, height= 28, title = "FUEL"}
  graphs["stored"] = { x = 20, y = 5, width = 10, height = 28, title = "ENERGY"}
  graphs["heat"] = { x = 32, y = 5, width = 10, height= 28, title = "HEAT"}
end

function setInfos()
   infos["tick"] = { x = 49, y = 27, width = 73, height= 1, title = "RF PER TICK: ", unit = " RF"}
   infos["stored"] = { x = 49, y = 28, width = 73, height = 1, title = "ENERGY STORED: ", unit = " RF"}
   infos["efficiency"] = { x = 49, y = 29, width = 73, height = 1, title = "EFFICIENCY: ", unit = "%"}
   infos["fuelname"] = { x = 49, y = 30, width = 73, height = 1, title = "FUEL:", unit = " "}
   infos["fueldecaytime"] = { x = 62, y = 30, width = 73, height = 1, title = " (", unit = " "}
   infos["fueltotaltime"] = { x = 62, y = 30, width = 73, height = 1, title = "/", unit = ")"}
   infos["heat"] = { x = 49, y = 31, width = 73, height = 1, title = "COOLING: ", unit = " HU/t"}
   infos["heatlevel"] = { x = 49, y = 32, width = 73, height = 1, title = "HEAT:", unit = ""}
 end

function setFuelPosition()
  infos["fueltotaltime"] = { x = 62 + string.len(reactor.getCurrentProcessTime()), y = 30, width =73, hight = 1, title ="/", unit=")"}
end

function debugInfos()  
  debug["print"] = { x = 1, y = 38, width = 73, height= 1, title = "DBG : "}
end

function setButtons()
  API.setTable("ON", powerOn, 50, 5, 65, 7,"ON", {on = colors.green, off = colors.green})
  API.setTable("OFF", powerOff, 68, 5, 84, 7,"OFF", {on = colors.red, off = colors.red})

  API.setTable("lowerMinLimit", lowerMinLimit, 50, 15, 65, 17,"-10", {on = colors.blue, off = colors.blue})
  API.setTable("lowerMaxLimit", lowerMaxLimit, 68, 15, 84, 17,"-10", {on = colors.purple, off = colors.purple})

  API.setTable("augmentMinLimit", augmentMinLimit, 50, 19, 65, 21,"+10", {on = colors.blue, off = colors.blue})
  API.setTable("augmentMaxLimit", augmentMaxLimit, 68, 19, 84, 21,"+10", {on = colors.purple, off = colors.purple})
end

function printBorders(sectionName)
  local s = sections[sectionName]

  -- set border
  gpu.setBackground(colors.blue)
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
  local heatcalc = currentHeat/MaxHeat * 100

  -- set graph
  if g == graphs["heat"] and heatcalc > 15 and heatcalc <30  then
      gpu.setBackground(colors.mudyellow)
  elseif g == graphs["heat"] and heatcalc > 30 and heatcalc < 50 then
      gpu.setBackground(colors.orange)
  elseif g == graphs["heat"] and heatcalc > 50 then
      gpu.setBakcground(colors.darkred)
  else 
    gpu.setBackground(colors.green)
  end
  gpu.fill(g.x, g.y, g.width, g.height, "_")

  -- set title
  gpu.setBackground(colors.black)
  gpu.set(g.x, g.y +g.height, g.title)
end

function printActiveGraphs(activeGraph)
  local g = activeGraph

  -- set graph
  gpu.setBackground(colors.white)
  gpu.fill(g.x, g.y, g.width, g.height, " ")
  gpu.setBackground(colors.black)
end

function printStaticControlText()
  gpu.setForeground(colors.blue)
  gpu.set(56,12, "MIN")
  gpu.setForeground(colors.purple)
  gpu.set(74,12, "MAX")
  gpu.setForeground(colors.white)
  gpu.set(61,10, "AUTO-CONTROL")
  gpu.set(66,13, "--")
end

function printControlInfos()
  gpu.setForeground(colors.blue)
  gpu.set(56,13, minPowerRod .. "% ")
  gpu.setForeground(colors.purple)
  gpu.set(74,13, maxPowerRod .. "% ")
  gpu.setForeground(colors.white)
end

function printInfos(infoName)
  local maxLength = 15
  local i = infos[infoName]
  local spaces = string.rep(" ", maxLength - string.len(reactor.stats[infoName] .. i.unit))
  gpu.set(i.x, i.y , i.title .. reactor.stats[infoName] .. i.unit .. spaces)
end

function getInfoFromReactor()
  local reactorEnergyStats = reactor.getEnergyStats()
  currentRf = reactor.stats["stored"]
end

function getInfoFromReactorOLD()
     reactor.stats["tick"] = toint(math.floor(reactor.getReactorProcessPower()))

     --Fuel Information
     reactor.stats["fuelname"] = tostring(reactor.getFissionFuelName())
     reactor.stats["efficiency"] = toint(reactor.getEfficiency())
     reactor.stats["fueldecaytime"] = toint(reactor.getCurrentProcessTime())
     reactor.stats["fueltimeused"] = math.floor(reactor.getReactorProcessTime())
     reactor.stats["fueltotaltime"] =toint(reactor.getFissionFuelTime())
 
     --Energy Information
     reactor.stats["stored"] = toint(reactor.getEnergyStored())
     reactor.stats["maxenergy"] = toint(reactor.getMaxEnergyStored())
 
     --Heat Information
     reactor.stats["heat"] = toint(reactor.getReactorProcessHeat())
     reactor.stats["heatlevel"] = toint(reactor.getHeatLevel())
     reactor.stats["maxheat"] = math.floor(reactor.getMaxHeatLevel())
 
     --Graph Information
     FuelName = tostring(reactor.stats["fuelname"])
     CurrentFuelTime = math.floor(reactor.stats["fueldecaytime"])
     TotalFuelTime   = math.floor(reactor.stats["fueltotaltime"])
    
     currentRf = reactor.stats["stored"]
     MaximumStorage = reactor.stats["maxenergy"]

     currentHeat = math.floor(reactor.stats["heatlevel"])
     MaxHeat = math.floor(reactor.stats["maxheat"])

      
end

function augmentMinLimit()
  modifyRods("min", 10)
end

function lowerMinLimit()
  modifyRods("min", -10)
end

function augmentMaxLimit()
  modifyRods("max", 10)
end

function lowerMaxLimit()
  modifyRods("max", -10)
end

function powerOn()
  reactor.activate()
end

function powerOff()
  reactor.deactivate()
end

function modifyRods(limit, number)
	local tempLevel = 0

	if limit == "min" then
		tempLevel = minPowerRod + number
		if tempLevel <= 0 then
			minPowerRod = 0
		end

		if tempLevel >= maxPowerRod then
			minPowerRod = maxPowerRod -10
		end

		if tempLevel < maxPowerRod and tempLevel > 0 then
			minPowerRod = tempLevel
		end
	else
		tempLevel = maxPowerRod + number
		if tempLevel <= minPowerRod then
			maxPowerRod = minPowerRod +10
		end

		if tempLevel >= 100 then
			maxPowerRod = 100
		end

		if tempLevel > minPowerRod and tempLevel < 100 then
			maxPowerRod = tempLevel
		end
	end

  setInfoToFile()
  calculateHeatPower()
end

-- Calculate and adjusts the level of the rods
function calculateHeatPower()
	local rfTotalMax = MaximumStorage
	local PowerCalc  = currentRF/MaximumStorage * 100
	local CalcHeat   = currentHeat/MaxHeat * 100
	currentRf = reactor.stats["stored"]

	if PowerCalc >= 80 and PowerCooling == false then
		PowerCooling = true
	end

	if currentRf <= minPower then
		currentRf = minPower
	end

	currentRf = toint(currentRf - (rfTotalMax/100) * minPowerRod)
	local rfInBetween = (rfTotalMax/100) * differenceMinMax
  local rodLevel = toint(math.ceil((currentRf/rfInBetween)*100))
  
  if versionType == "NEW" then
    AdjustRodsLevel(rodLevel)
  else
    AdjustRodsLevelOLD(rodLevel)
  end
end

while PowerCooling do
	local PowerCalc  = currentRF/MaximumStorage * 100
	if PowerCalc ~= <= 30 then
		os.sleep(500)
	elseif PowerCalc <= 30 then
		PowerCooling = false
	end	
end

function AdjustRodsLevel(rodLevel)
  for key,value in pairs(reactorRodsLevel) do 
    --reactorRodsLevel[key] = rodLevel
    reactor.setControlRodLevel(key, rodLevel)
  end
  --reactor.setControlRodsLevels(reactorRodsLevel)
end

function AdjustRodsLevelOLD(rodLevel)
  reactor.setAllControlRodLevels(rodLevel)
end

function printDebug()  
  local maxLength = 132
  local i = debug["print"]
  local rodsvalues = ""
  
  rodsvalues = "[0]" .. reactorRodsLevel[0] .. "[1]" .. reactorRodsLevel[1] .. "[2]" .. reactorRodsLevel[2] .. "[Z]" .. reactor.stats["rods"]

  local debugInformations = "maxRF:" .. maxRF .. ", RodsLev:" .. rodsvalues .. ", curRodLev:" .. currentRodLevel .. ", curRf:" .. currentRf .. ", curRfT:" .. currentRfTick .. ", min-max:" .. minPowerRod .. "-" .. maxPowerRod
  local spaces = string.rep(" ", maxLength - string.len(debugInformations))
  gpu.set(i.x, i.y , i.title .. debugInformations .. spaces)
end

function updateall()
   printInfos("tick")
   printInfos("heatlevel")
   printInfos("stored")
   printInfos("efficiency")
   printInfos("fuelname")
   printInfos("fueldecaytime")
   printInfos("fueltotaltime") 
   printInfos("heat")
   setFuelPosition()
end

function draw()
  
  if FuelName == "No Fuel" then
    local currentRFTickObj = {x = graphs["tick"].x, y = graphs["tick"].y, width = graphs["tick"].width, height = graphs["tick"].height }
    printActiveGraphs(currentRFTickObj)
  end  

  if CurrentFuelTime ~= reactor.stats["TotalFuelTime"] and FuelName ~= "No Fuel" then
    currentRfTick = reactor.stats["fueldecaytime"]-1
    local max = graphs["tick"].height - graphs["tick"].height * (currentRfTick/TotalFuelTime)
    local currentRFTickObj = {x = graphs["tick"].x, y = graphs["tick"].y, width = graphs["tick"].width, height = max -1 }
    updateall()
    printGraphs("tick")
    printActiveGraphs(currentRFTickObj)
  end

  if currentRF ~= reactor.stats["stored"] then
    currentRF = reactor.stats["stored"] - 1
    local max = math.floor(graphs["stored"].height - math.floor(graphs["stored"].height * (currentRF/MaximumStorage)))
    local currentRFObj = {x = graphs["stored"].x, y = graphs["stored"].y , width = graphs["stored"].width, height = max-1}
    updateall()
    printGraphs("stored",darkblue)
    printActiveGraphs(currentRFObj)
  end

  if currentHeat ~= reactor.stats["MaxHeat"] then
    currentHeat = reactor.stats["heatlevel"] - 1
    local max = math.floor(graphs["heat"].height - math.floor(graphs["heat"].height * (currentHeat/MaxHeat)))
    local currentHeatObj = {x = graphs["heat"].x, y = graphs["heat"].y , width = graphs["heat"].width, height = max-1}
    updateall()
    printGraphs("heat")
    printActiveGraphs(currentHeatObj)
  end
  
  
  
  printControlInfos()
end


function startup()
  getInfoFromFile()
   if 1 == 1 then
    getInfoFromReactorOLD()
   end
  setSections()
  setGraphs()
  setInfos()
  setButtons()
  setFuelPosition()
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

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return false else return true end
end

function getInfoFromFile()
	 if file_exists("reactor.txt") then
	 	file = io.open("reactor.txt","w")
    file:write("0", "\n")
    file:write("100", "\n")
    file:close()
	else
		file = io.open("reactor.txt","r")
		minPowerRod = tonumber(file:read("*l"))
		maxPowerRod = tonumber(file:read("*l"))
    file:close()
	end
end

function setInfoToFile()
  file = io.open("reactor.txt","w")
  file:write(minPowerRod, "\n")
  file:write(maxPowerRod, "\n")
  file:flush()
  file:close()
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
   if 1 == 1 then
    getInfoFromReactorOLD()
   end
  draw()
  local event, address, arg1, arg2, arg3 = event.pull(1)
  if type(address) == "string" and component.isPrimary(address) then
    if event == "key_down" and arg2 == keyboard.keys.q then
      os.exit()
    end
  end
end
