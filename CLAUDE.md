# Hunters — regras do projeto
- Jogo de extração PvP no Roblox. Escopo e plano: ver os docs do projeto.
- Código em Luau, todo script começa com --!strict.
- O servidor decide tudo (dano, loot, venda, extração). Nunca confiar em dados vindos do cliente.
- Um serviço por sistema em src/server/services, como ModuleScript.
- Dados salvos só passam pelo DataService.
- Não editar mapa ou modelos no Studio sem pedido explícito.
- Antes de codar, propor um plano e esperar aprovação.
- Rodar selene e stylua antes de dizer que terminou.