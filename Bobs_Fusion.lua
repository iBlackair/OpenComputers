API = require("buttonAPI")
local filesystem = require("filesystem")
local component = require("component")
local event = require("event")
local gpu = component.gpu
local graph = require("bobs_graph")
local r = component.nc_fission_reactor

if not component.isAvailable("nc_fission_reactor") then
  print("Reactor not connected. Please connect the computer to the fission reactor.")
  os.exit()
end


local mr, mh 


local colors = { blue = 0x4286F4, purple = 0xB673d6, red = 0xC14141, green = 0xDA841,
  black = 0x000000, white = 0xFFFFFF, grey = 0x47494C, lightGrey = 0xBBBBBB}  
gpu.setResolution(40,20)

local heat,workV,autoV = false,true,false
function reinitialize()
 
 r.deactivate()
 r.forceUpdate()
 
 hfl, hhl, rfl, rhl = 0, 0, 0, 0
 heat,workV,autoV = false,true,false

 gpu.setBackground(colors.black)
 gpu.fill(1,1,40,20," ")

 graph.DC(2,2,3,18,{0xffffff,0x777777,0xff0000,0x555555}," ")
 
 summonHeat()

 local L = {
 "Fuel :",
 "",
 "Efficiency :",
 "Heat Multi :",
 "Heat Gen :",
 "Heat :",
 "Energy :",
 "Energy Out :"
 }

 graph.text(6,3,L,0xeeaa00,0x777777) 

end

function summonHeat()

 if r.getReactorProcessHeat() > 0 then
  graph.DC(36,2,3,18,{0xffffff,0x777777,0xffcc00,0x555555}," ")
  heat = true
 end

end

function updateFuels()

 gpu.setForeground(0xeeaa00)
 gpu.setBackground(0x777777)
 gpu.set(14,3,r.getFissionFuelName())
 gpu.set(7,4,math.floor(r.getFissionFuelPower()) .. " RF/t - " .. math.floor(r.getFissionFuelHeat()) .. " H/t")
 
end



function updateValues()

 mr, mh = r.getMaxEnergyStored(), r.getMaxHeatLevel()
 rf, ah = r.getEnergyStored(), r.getHeatLevel()
 
end

local hfl, hhl, rfl, rhl = 0, 0, 0, 0
function updateGraph()

 rhl, rfl  = graph.DGLV(rf,mr,3 ,3,1,16,rhl,rfl,0xee0000,0x555555)

 if heat then
  hhl, hfl = graph.DGLV(ah,mh,37,3,1,16,hhl,hfl,0xeecc00,0x555555)
 end
 
end

function updateM()

 local E = math.floor(r.getEfficiency() * 10) / 10
 local H = math.floor(r.getHeatMultiplier() * 10) / 10
 local HG,M = graph.EVC(r.getReactorProcessHeat())

 local M = {
 E .. "%",
 H .. "%",
 HG .. " " .. M .. "H/t"
 }

 --graph.text(M)
 
end

function updateMain()

 local H,HM   = graph.EVC(ah)
 local MH,MHM = graph.EVC(mh)
 local E,EM   = graph.EVC(rf)
 local ME,MEH = graph.EVC(mr)

 local F = {
 graph.RSATC(H) .. " " .. HM .. "H / "  .. graph.RSATC(MH) .. " " .. MHM .. "H",
 graph.RSATC(E) .. " " .. EM .. "RF / " .. graph.RSATC(ME)  .. " " .. MEH .. "RF"
 }

 gpu.setBackground(0x777777)
 gpu.set(20,10,tostring(math.floor(math.abs(r.getEnergyChange()))))
 graph.text(15,8,F,0xeeaa00)

end

local buttons = {}

function activate()
 graph.TB(nil,22,12,12,3,"Activate",0xbb1111,0xffffff,true)
 os.sleep(0.2)
 buttons[2] = graph.TB(deactivate,22,12,12,3,"Deactivate",0xbb1111,0xffffff)
 r.activate()
end

function deactivate()
 r.deactivate()
 graph.TB(nil,22,12,12,3,"Deactivate",0xbb1111,0xffffff,true)
 os.sleep(0.2)
 buttons[2] = graph.TB(activate,22,12,12,3,"Activate",0xbb1111,0xffffff)
end

function autoButton()
 if autoV then
  autoV = false
  graph.TB(nil,7,12,12,3,"Auto",0xbb1111,0xffffff,true)
  os.sleep(0.2)
  graph.TB(nil,7,12,12,3,"Auto",0xbb1111,0xffffff)
  buttons[2] = graph.TB(activate,22,12,12,3,"Activate",0xbb1111,0xffffff)
 else
  r.deactivate()
  autoV = true
  graph.TB(nil,7,12,12,3,"Auto",0x11bb11,0xffffff,true)
  os.sleep(0.2)
  graph.TB(nil,7,12,12,3,"Auto",0x11bb11,0xffffff)
  buttons[2] = graph.TB((function() os.sleep(0.25) end),22,12,12,3,"Disabled",0x999999,0xeeeeee)
 end
end

function updateAll()

 local functions = {
 updateValues,
 updateM,
 updateMain,
 updateFuels,
 buttonsDraw,
 updateGraph }
 
 for i,f in ipairs(functions)
  do f() os.sleep(0.1)
 end
 
end

function buttonsDraw()
 buttons[1] = graph.TB(autoButton,7,12,12,3,"Auto",0xbb1111,0xffffff)
API.setTable("Acitvate", poweron, 22, 12, 12, 3,"Activate", {on = colors.green, off = colors.green})
 buttons[2] = graph.TB(updateAll,22,16,12,3,"Update",0xbb1111,0xffffff)
 buttons[3] = graph.TB((function() workV = false end),7,16,12,3,"Exit",0x999999,0xeeeeee)
end

reinitialize()
updateAll()

local MHP,WSEP = 35,75
while workV do

 updateValues()
 updateMain()
 updateGraph()

 ev,ad,x,y = event.pull(1.5)
 
 if ev == "touch" then
  for i,t in ipairs(buttons)
   do if x >= t[1] and x <= t[3] and y >= t[2] and y <= t[4]
    then t[5]() break
   end
  end
 end
 
  if autoV then
 
  local SEP = rf / mr * 100
  local HP = ah / mh * 100

  if HP > MHP or SEP > WSEP
   then r.deactivate()
   else r.activate()
  end
  
 end

end

r.deactivate()
gpu.setBackground(0)
gpu.setForeground(0xffffff)
os.execute("clear")
print("Exiting")






