-- Client entry.
local Players = game:GetService("Players")

local DevPanel = require(script.Parent.DevPanel)
local Duels = require(script.Parent.Duels)
local FaceCamera = require(script.Parent.FaceCamera)
local Guide = require(script.Parent.Guide)
local HeadMesh = require(script.Parent.HeadMesh)
local Hud = require(script.Parent.Hud)
local Menu = require(script.Parent.Menu)
local MirrorView = require(script.Parent.MirrorView)
local Shop = require(script.Parent.Shop)
local Store = require(script.Parent.Store)
local Workout = require(script.Parent.Workout)

local player = Players.LocalPlayer

-- Wait until server has loaded data so the menu shows real rank.
if player:GetAttribute("Rating") == nil then
	player:GetAttributeChangedSignal("Rating"):Wait()
end

local actions = {
	shop = Shop.init(),
	duels = Duels.init(),
	store = Store.init(),
}
local hudGui = Hud.init(actions)
actions.menu = function()
	Menu.show(hudGui)
end
Menu.show(hudGui)
FaceCamera.init()
MirrorView.init()
HeadMesh.init()
Guide.init()
Workout.init()
DevPanel.init()
