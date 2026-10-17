-- Creates RemoteEvents in ReplicatedStorage.Remotes. Client waits for them by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "Click", "Buy", "Equip", "Rebirth" }

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local Remotes = {}
for _, name in NAMES do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

folder.Parent = ReplicatedStorage

return Remotes :: { [string]: RemoteEvent }
