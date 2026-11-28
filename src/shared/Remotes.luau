--!strict
-- Cria (servidor) ou aguarda (cliente) os RemoteEvents do jogo.
-- Para adicionar um evento, inclua o nome em EVENT_NAMES.
-- Acessar um nome que não existe gera erro, para pegar erros de digitação cedo.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES: { string } = {
	-- Nenhum evento nesta sprint: o estado da rodada vai por atributos do workspace.
}

local function getFolder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local folder = getFolder()
local events: { [string]: RemoteEvent } = {}

for _, name in EVENT_NAMES do
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			events[name] = existing
		else
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
			events[name] = event
		end
	else
		local event = folder:WaitForChild(name)
		assert(event:IsA("RemoteEvent"), `Remotes: {name} não é um RemoteEvent`)
		events[name] = event
	end
end

setmetatable(events, {
	__index = function(_, key)
		error(`Remotes: evento desconhecido "{tostring(key)}"`, 2)
	end,
})

return table.freeze(events)
