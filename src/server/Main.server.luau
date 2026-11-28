--!strict
-- Ponto de entrada do servidor: carrega todos os serviços de ./services,
-- chama Init() em todos e depois Start() em todos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Garante que os RemoteEvents existam antes de qualquer serviço.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

type Service = {
	Init: () -> (),
	Start: () -> (),
}

local servicesFolder = script.Parent:FindFirstChild("services")
assert(servicesFolder, "Main: pasta 'services' não encontrada")

local modules: { ModuleScript } = {}
for _, child in servicesFolder:GetChildren() do
	if child:IsA("ModuleScript") then
		table.insert(modules, child)
	end
end
-- Ordem fixa para o boot ser previsível.
table.sort(modules, function(a, b)
	return a.Name < b.Name
end)

local services: { { name: string, service: Service } } = {}
for _, module in modules do
	local service = (require :: any)(module)
	assert(
		type(service) == "table" and type(service.Init) == "function" and type(service.Start) == "function",
		`Main: {module.Name} precisa exportar Init() e Start()`
	)
	table.insert(services, { name = module.Name, service = service :: Service })
end

-- Init: síncrono; um erro aqui interrompe o boot.
for _, entry in services do
	entry.service.Init()
end

-- Start: cada um em sua thread, para um Start que bloqueia não travar os outros.
for _, entry in services do
	task.spawn(entry.service.Start)
end

print(`Hunters: {#services} serviço(s) iniciado(s)`)
