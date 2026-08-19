-- ==============================================================================
-- CDID HUB - CUSTOM FLOATING DASHBOARD BUILDER (UICREATE)
-- ==============================================================================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local UICreate = {}

function UICreate.CreateFloatingDashboard(titleText)
	local guiName = "CDID_FloatingDashboard"
	local old = CoreGui:FindFirstChild(guiName) or LocalPlayer.PlayerGui:FindFirstChild(guiName)
	if old then old:Destroy() end

	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = guiName
	ScreenGui.ResetOnSpawn = false
	pcall(function() ScreenGui.Parent = CoreGui end)
	if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	-- Main Frame
	local MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = UDim2.new(0, 240, 0, 150)
	MainFrame.Position = UDim2.new(0.02, 0, 0.35, 0)
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	MainFrame.BackgroundTransparency = 0.15
	MainFrame.BorderSizePixel = 0
	MainFrame.ClipsDescendants = true
	MainFrame.Parent = ScreenGui

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = MainFrame

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(0, 162, 255)
	Stroke.Thickness = 1.2
	Stroke.Parent = MainFrame

	-- Title Bar (Drag Handler)
	local TitleBar = Instance.new("Frame")
	TitleBar.Size = UDim2.new(1, 0, 0, 30)
	TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
	TitleBar.BorderSizePixel = 0
	TitleBar.Parent = MainFrame

	local TitleCorner = Instance.new("UICorner")
	TitleCorner.CornerRadius = UDim.new(0, 10)
	TitleCorner.Parent = TitleBar

	local Title = Instance.new("TextLabel")
	Title.Size = UDim2.new(1, -35, 1, 0)
	Title.Position = UDim2.new(0, 10, 0, 0)
	Title.BackgroundTransparency = 1
	Title.Text = titleText or "BCA Courier Dashboard"
	Title.TextColor3 = Color3.fromRGB(255, 255, 255)
	Title.Font = Enum.Font.GothamBold
	Title.TextSize = 12
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = TitleBar

	-- Close Button
	local CloseBtn = Instance.new("TextButton")
	CloseBtn.Size = UDim2.new(0, 24, 0, 24)
	CloseBtn.Position = UDim2.new(1, -27, 0, 3)
	CloseBtn.BackgroundTransparency = 1
	CloseBtn.Text = "✕"
	CloseBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	CloseBtn.Font = Enum.Font.GothamBold
	CloseBtn.TextSize = 13
	CloseBtn.Parent = TitleBar

	-- Content Container
	local Content = Instance.new("Frame")
	Content.Size = UDim2.new(1, -16, 1, -38)
	Content.Position = UDim2.new(0, 8, 0, 34)
	Content.BackgroundTransparency = 1
	Content.Parent = MainFrame

	local UIList = Instance.new("UIListLayout")
	UIList.SortOrder = Enum.SortOrder.LayoutOrder
	UIList.Padding = UDim.new(0, 4)
	UIList.Parent = Content

	local function CreateRow(name, defaultVal)
		local Row = Instance.new("Frame")
		Row.Name = name
		Row.Size = UDim2.new(1, 0, 0, 24)
		Row.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
		Row.BackgroundTransparency = 0.5
		Row.Parent = Content

		local RowCorner = Instance.new("UICorner")
		RowCorner.CornerRadius = UDim.new(0, 6)
		RowCorner.Parent = Row

		local Label = Instance.new("TextLabel")
		Label.Size = UDim2.new(1, -10, 1, 0)
		Label.Position = UDim2.new(0, 6, 0, 0)
		Label.BackgroundTransparency = 1
		Label.Text = defaultVal
		Label.TextColor3 = Color3.fromRGB(220, 220, 230)
		Label.Font = Enum.Font.GothamMedium
		Label.TextSize = 11
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.Parent = Row

		return Label
	end

	local saldoLabel = CreateRow("SaldoRow", "💰 Saldo: Rp 0")
	local statusLabel = CreateRow("StatusRow", "📦 Status: Idle")
	local tripsLabel = CreateRow("TripsRow", "🏁 Trips: 0 Selesai")

	CloseBtn.MouseButton1Click:Connect(function()
		ScreenGui.Enabled = false
	end)

	-- Dragging Logic
	local dragging, dragInput, dragStart, startPos
	TitleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	TitleBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	local DashboardHandle = {}

	function DashboardHandle.SetVisible(visible)
		ScreenGui.Enabled = visible
	end

	function DashboardHandle.UpdateSaldo(text)
		if saldoLabel then saldoLabel.Text = "💰 Saldo: " .. tostring(text) end
	end

	function DashboardHandle.UpdateStatus(text)
		if statusLabel then statusLabel.Text = "📦 " .. tostring(text) end
	end

	function DashboardHandle.UpdateTrips(count)
		if tripsLabel then tripsLabel.Text = string.format("🏁 Trips: %d Selesai", count or 0) end
	end

	function DashboardHandle.Destroy()
		ScreenGui:Destroy()
	end

	return DashboardHandle
end

return UICreate
