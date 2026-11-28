--!strict
-- HUD mínimo: mostra o estado da rodada e o tempo restante.
-- Só lê os atributos do workspace; o tempo é calculado localmente com GetServerTimeNow.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundStates = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundStates"))

local REFRESH_INTERVAL = 0.2

local STATE_LABELS: { [string]: string } = {
	[RoundStates.Aguardando] = "Aguardando",
	[RoundStates.EmIncursao] = "Incursão",
	[RoundStates.Encerrando] = "Encerrando",
}

local RoundHud = {}

local function formatTime(seconds: number): string
	local total = math.ceil(seconds)
	return string.format("%d:%02d", total // 60, total % 60)
end

local function buildText(): string
	local stateValue = workspace:GetAttribute(RoundStates.StateAttribute)
	if type(stateValue) ~= "string" then
		return "Conectando..."
	end
	local label = STATE_LABELS[stateValue] or stateValue

	local endsAtValue = workspace:GetAttribute(RoundStates.EndsAtAttribute)
	local endsAt = if type(endsAtValue) == "number" then endsAtValue else 0
	if endsAt <= 0 then
		if stateValue == RoundStates.Aguardando then
			return "Aguardando jogadores"
		end
		return label
	end

	local remaining = math.max(0, endsAt - workspace:GetServerTimeNow())
	return `{label} — {formatTime(remaining)}`
end

function RoundHud.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "RoundHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local label = Instance.new("TextLabel")
	label.Name = "RoundText"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 8)
	label.Size = UDim2.fromOffset(320, 40)
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.4
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 22
	label.Text = "Conectando..."
	label.Parent = gui

	gui.Parent = playerGui

	local function render()
		label.Text = buildText()
	end

	workspace:GetAttributeChangedSignal(RoundStates.StateAttribute):Connect(render)
	workspace:GetAttributeChangedSignal(RoundStates.EndsAtAttribute):Connect(render)
	render()

	task.spawn(function()
		while gui.Parent do
			render()
			task.wait(REFRESH_INTERVAL)
		end
	end)
end

return RoundHud
