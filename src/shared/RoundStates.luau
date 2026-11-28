--!strict
-- Nomes dos estados da rodada e dos atributos do workspace que os carregam.
-- Compartilhado entre servidor e cliente para não haver strings soltas.

export type RoundState = "Aguardando" | "EmIncursao" | "Encerrando"

local RoundStates = table.freeze({
	Aguardando = "Aguardando" :: RoundState,
	EmIncursao = "EmIncursao" :: RoundState,
	Encerrando = "Encerrando" :: RoundState,

	-- Atributos em workspace
	StateAttribute = "RoundState", -- string: um dos estados acima
	EndsAtAttribute = "RoundEndsAt", -- number: horário de fim (GetServerTimeNow); 0 = sem contagem
})

return RoundStates
