--!strict
-- Ciclo da rodada: Aguardando -> EmIncursao -> Encerrando -> Aguardando.
-- O servidor decide tudo. O estado e o horário de fim ficam em atributos do
-- workspace (RoundState, RoundEndsAt); o cliente calcula o tempo restante.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RoundConfig = require(Shared:WaitForChild("Config"):WaitForChild("Round"))
local RoundStates = require(Shared:WaitForChild("RoundStates"))

type RoundState = RoundStates.RoundState

local POLL_INTERVAL = 0.25
local ROOT_PART_TIMEOUT = 10

local RoundService = {}

local state: RoundState = RoundStates.Aguardando
local stateChangedEvent = Instance.new("BindableEvent")

-- Jogadores que estão na incursão atual.
local participants: { [Player]: true } = {}
-- Spawn sorteado para cada participante no início da incursão.
local raidSpawnOf: { [Player]: BasePart } = {}
-- Personagem com que cada participante nasceu na incursão (para validar a morte).
local raidCharacterOf: { [Player]: Model } = {}

local warnedMissingTag: { [string]: true } = {}
local rng = Random.new()

--- Sinal disparado com o novo estado sempre que a fase muda.
RoundService.StateChanged = stateChangedEvent.Event

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setEndsAt(endsAt: number)
	workspace:SetAttribute(RoundStates.EndsAtAttribute, endsAt)
end

local function setPhase(newState: RoundState, endsAt: number)
	setEndsAt(endsAt)
	workspace:SetAttribute(RoundStates.StateAttribute, newState)
	if state ~= newState then
		state = newState
		stateChangedEvent:Fire(newState)
	end
end

-- Espera até endsAt; retorna true se shouldAbort() ficou verdadeiro antes.
local function waitUntil(endsAt: number, shouldAbort: (() -> boolean)?): boolean
	while now() < endsAt do
		if shouldAbort and shouldAbort() then
			return true
		end
		task.wait(POLL_INTERVAL)
	end
	return false
end

local function getSpawnParts(tag: string): { BasePart }
	local parts: { BasePart } = {}
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
			table.insert(parts, instance)
		end
	end
	if #parts == 0 and not warnedMissingTag[tag] then
		warnedMissingTag[tag] = true
		warn(`RoundService: nenhuma BasePart com a tag "{tag}" no workspace`)
	end
	return parts
end

local function shuffle(list: { BasePart })
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- Distribui os spawns sem repetir enquanto houver spawns livres.
local function assignRaidSpawns(players: { Player })
	table.clear(raidSpawnOf)
	local spawns = getSpawnParts(RoundConfig.RaidSpawnTag)
	if #spawns == 0 then
		return
	end
	local pool: { BasePart } = {}
	for _, player in players do
		if #pool == 0 then
			pool = table.clone(spawns)
			shuffle(pool)
		end
		raidSpawnOf[player] = table.remove(pool) :: BasePart
	end
end

local function pickLobbySpawn(): BasePart?
	local spawns = getSpawnParts(RoundConfig.LobbySpawnTag)
	if #spawns == 0 then
		return nil
	end
	return spawns[rng:NextInteger(1, #spawns)]
end

local function getTargetSpawn(player: Player): (BasePart?, boolean)
	if state == RoundStates.EmIncursao and participants[player] then
		local raidSpawn = raidSpawnOf[player]
		if raidSpawn and raidSpawn:IsDescendantOf(workspace) then
			return raidSpawn, true
		end
		-- Sem RaidSpawn válido: cai no lobby (o aviso já saiu em getSpawnParts).
	end
	return pickLobbySpawn(), false
end

local function removeParticipant(player: Player)
	participants[player] = nil
	raidSpawnOf[player] = nil
	raidCharacterOf[player] = nil
end

local function onCharacterAdded(player: Player, character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", ROOT_PART_TIMEOUT)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		warn(`RoundService: HumanoidRootPart de {player.Name} não apareceu`)
		return
	end
	-- O personagem pode ter sido trocado enquanto esperávamos.
	if player.Character ~= character or not character:IsDescendantOf(workspace) then
		return
	end

	local target, isRaid = getTargetSpawn(player)
	if isRaid then
		raidCharacterOf[player] = character
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			-- Só conta a morte do personagem da incursão atual.
			if participants[player] and raidCharacterOf[player] == character then
				removeParticipant(player)
			end
		end)
	end

	if target then
		local top = target.Position + Vector3.new(0, target.Size.Y / 2 + RoundConfig.SpawnHeightOffset, 0)
		character:PivotTo(CFrame.new(top))
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function respawn(player: Player)
	task.spawn(function()
		if player.Parent ~= Players then
			return
		end
		local ok, err = pcall(player.LoadCharacter, player)
		if not ok then
			warn(`RoundService: falha ao recarregar {player.Name}: {err}`)
		end
	end)
end

local function hasEnoughPlayers(): boolean
	return #Players:GetPlayers() >= RoundConfig.MinPlayers
end

local function runWaiting()
	setPhase(RoundStates.Aguardando, 0)
	while true do
		while not hasEnoughPlayers() do
			task.wait(POLL_INTERVAL)
		end
		local endsAt = now() + RoundConfig.WaitDuration
		setEndsAt(endsAt)
		local cancelled = waitUntil(endsAt, function()
			return not hasEnoughPlayers()
		end)
		if not cancelled then
			return
		end
		setEndsAt(0)
	end
end

local function runRaid()
	-- 1. Lista de participantes e spawns ANTES de qualquer LoadCharacter.
	table.clear(participants)
	table.clear(raidCharacterOf)
	local players = Players:GetPlayers()
	for _, player in players do
		participants[player] = true
	end
	assignRaidSpawns(players)

	-- 2. Estado já em EmIncursao, para o CharacterAdded mandar para o RaidSpawn.
	local endsAt = now() + RoundConfig.RaidDuration
	setPhase(RoundStates.EmIncursao, endsAt)

	-- 3. Personagens novos para todos os participantes.
	for _, player in players do
		respawn(player)
	end

	-- Termina no tempo ou quando ninguém mais estiver na incursão.
	waitUntil(endsAt, function()
		return next(participants) == nil
	end)
end

local function runEnding()
	local endsAt = now() + RoundConfig.EndDuration
	setPhase(RoundStates.Encerrando, endsAt)
	waitUntil(endsAt)

	local survivors: { Player } = {}
	for player in participants do
		table.insert(survivors, player)
	end
	table.clear(participants)
	table.clear(raidSpawnOf)
	table.clear(raidCharacterOf)

	-- Volta para Aguardando antes de recarregar, para nascerem no lobby.
	setPhase(RoundStates.Aguardando, 0)
	for _, player in survivors do
		respawn(player)
	end
end

--- Estado atual da rodada.
function RoundService.GetState(): RoundState
	return state
end

--- true se o jogador está na incursão atual.
function RoundService.IsParticipant(player: Player): boolean
	return participants[player] == true
end

function RoundService.Init()
	setPhase(RoundStates.Aguardando, 0)
end

function RoundService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(removeParticipant)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			runWaiting()
			runRaid()
			runEnding()
		end
	end)
end

return RoundService
