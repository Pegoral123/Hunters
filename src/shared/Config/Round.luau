--!strict
-- Valores de ajuste da rodada. Durações em segundos.

local Round = table.freeze({
	WaitDuration = 15, -- contagem em Aguardando antes da incursão
	RaidDuration = 120, -- duração da incursão (valor de teste)
	EndDuration = 10, -- duração de Encerrando
	MinPlayers = 1, -- mínimo de jogadores para a contagem começar

	SpawnHeightOffset = 3, -- studs acima do topo da peça de spawn
	RaidSpawnTag = "RaidSpawn",
	LobbySpawnTag = "LobbySpawn",
})

return Round
