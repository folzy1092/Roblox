-- Client entry.
local Players = game:GetService("Players")

local FaceCamera = require(script.Parent.FaceCamera)
local Hud = require(script.Parent.Hud)
local Menu = require(script.Parent.Menu)
local MirrorView = require(script.Parent.MirrorView)
local Shop = require(script.Parent.Shop)

local player = Players.LocalPlayer

-- Wait until server has loaded data so the menu shows real rank.
if player:GetAttribute("Rating") == nil then
	player:GetAttributeChangedSignal("Rating"):Wait()
end

local toggleShop = Shop.init()
local hudGui = Hud.init(toggleShop)
Menu.show(hudGui)
FaceCamera.init()
MirrorView.init()
