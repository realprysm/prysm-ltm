local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WALK_SPEED = 60
local FLOAT_SPEED = 400

-- trampoline settings
local TRAMPOLINE_RISE = 5
local TRAMPOLINE_SCAN_DISTANCE = 10000
local TRAMPOLINE_STEP_TIME = 0.12
local TRAMPOLINE_SETTLE_TIME = 0.045
local TRAMPOLINE_HORIZONTAL_TOLERANCE = 2.5

local trampolineEnabled = false
local floatEnabled = false
local unwalkEnabled = false
local antiDieEnabled = false

local character
local humanoid
local root
local animateScript

local trampolineThread
local floatConnection
local antiDieConnection
local antiDieStateConnection
local characterAddedConnection
local characterRemovingConnection
local heartbeatConnection
local viewportConnection

local RED = Color3.fromRGB(255, 35, 55)
local RED_BRIGHT = Color3.fromRGB(255, 65, 80)
local BLACK = Color3.fromRGB(5, 5, 8)
local DARK2 = Color3.fromRGB(16, 16, 22)
local DARK3 = Color3.fromRGB(23, 23, 31)
local WHITE = Color3.fromRGB(245, 245, 250)
local MUTED = Color3.fromRGB(135, 135, 150)

local oldGui = playerGui:FindFirstChild("PrysmLTM")

if oldGui then
	oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "PrysmLTM"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function corner(object, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
	return c
end

local function stroke(object, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local function tween(object, time, properties, style, direction)
	if not object or not object.Parent then
		return nil
	end

	local info = TweenInfo.new(
		time,
		style or Enum.EasingStyle.Quad,
		direction or Enum.EasingDirection.Out
	)

	local t = TweenService:Create(object, info, properties)
	t:Play()

	return t
end

local function stopAnimations()
	if not humanoid or not humanoid.Parent then
		return
	end

	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		if track.IsPlaying then
			track:Stop(0)
		end
	end
end

local function applyUnwalk()
	if not character or not character.Parent then
		return
	end

	animateScript = character:FindFirstChild("Animate")

	if animateScript then
		animateScript.Disabled = unwalkEnabled
	end

	if unwalkEnabled then
		stopAnimations()
	end
end

local function forceWalkSpeed()
	if humanoid and humanoid.Parent and humanoid.Health > 0 then
		if humanoid.WalkSpeed ~= WALK_SPEED then
			humanoid.WalkSpeed = WALK_SPEED
		end
	end
end

local function setProtectedStates()
	if not humanoid or not humanoid.Parent then
		return
	end

	humanoid.BreakJointsOnDeath = false

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Dead,
		false
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.FallingDown,
		false
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Ragdoll,
		false
	)
end

local function restoreNormalStates()
	if not humanoid or not humanoid.Parent then
		return
	end

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Dead,
		true
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.FallingDown,
		true
	)

	humanoid:SetStateEnabled(
		Enum.HumanoidStateType.Ragdoll,
		true
	)
end

local function protectCharacter()
	if not antiDieEnabled then
		return
	end

	if not humanoid or not humanoid.Parent then
		return
	end

	setProtectedStates()

	if humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end

	if humanoid.Health <= 0 then
		humanoid.Health = humanoid.MaxHealth
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function stopAntiDie()
	if antiDieConnection then
		antiDieConnection:Disconnect()
		antiDieConnection = nil
	end

	if antiDieStateConnection then
		antiDieStateConnection:Disconnect()
		antiDieStateConnection = nil
	end
end

local function startAntiDie()
	stopAntiDie()

	if not humanoid or not humanoid.Parent then
		return
	end

	setProtectedStates()
	protectCharacter()

	local thisHumanoid = humanoid

	antiDieConnection = RunService.Heartbeat:Connect(function()
		if not antiDieEnabled then
			return
		end

		if humanoid ~= thisHumanoid then
			return
		end

		if not thisHumanoid.Parent then
			return
		end

		protectCharacter()
	end)

	antiDieStateConnection = thisHumanoid.StateChanged:Connect(function(_, state)
		if not antiDieEnabled then
			return
		end

		if humanoid ~= thisHumanoid then
			return
		end

		if state == Enum.HumanoidStateType.Dead
			or state == Enum.HumanoidStateType.FallingDown
			or state == Enum.HumanoidStateType.Ragdoll then

			setProtectedStates()

			if thisHumanoid.Health <= 0 then
				thisHumanoid.Health = thisHumanoid.MaxHealth
			end

			thisHumanoid:ChangeState(
				Enum.HumanoidStateType.GettingUp
			)
		end
	end)
end

local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	root = char:WaitForChild("HumanoidRootPart")
	animateScript = char:FindFirstChild("Animate")

	humanoid.WalkSpeed = WALK_SPEED

	if antiDieEnabled then
		task.defer(function()
			if character == char
				and humanoid
				and humanoid.Parent then

				startAntiDie()
			end
		end)
	end

	if unwalkEnabled then
		task.defer(function()
			if character == char and character.Parent then
				applyUnwalk()
			end
		end)
	end
end

if player.Character then
	setupCharacter(player.Character)
end

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0)
main.Position = UDim2.new(0.5, 0, 0, 105)
main.Size = UDim2.new(0, 780, 0, 128)
main.BackgroundColor3 = BLACK
main.BackgroundTransparency = 0.02
main.BorderSizePixel = 0
main.ZIndex = 10
main.Parent = gui

corner(main, 22)

local mainScale = Instance.new("UIScale")
mainScale.Scale = 1
mainScale.Parent = main

local function updateResponsiveScale()
	local camera = workspace.CurrentCamera

	if not camera then
		return
	end

	local viewport = camera.ViewportSize

	local scale = math.min(
		1,
		(viewport.X - 20) / 780
	)

	mainScale.Scale = math.max(scale, 0.55)
end

updateResponsiveScale()

local function connectViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = workspace.CurrentCamera

	if camera then
		viewportConnection =
			camera:GetPropertyChangedSignal(
				"ViewportSize"
			):Connect(updateResponsiveScale)
	end
end

connectViewport()

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	connectViewport()
	updateResponsiveScale()
end)

local outerRing = stroke(
	main,
	RED,
	2.5,
	0.05
)

local outerRing2 = stroke(
	main,
	RED_BRIGHT,
	6,
	0.78
)

task.spawn(function()
	while main.Parent do
		tween(
			outerRing,
			0.8,
			{
				Transparency = 0.28
			}
		)

		tween(
			outerRing2,
			0.8,
			{
				Transparency = 0.62
			}
		)

		task.wait(0.8)

		if not main.Parent then
			break
		end

		tween(
			outerRing,
			0.8,
			{
				Transparency = 0.02
			}
		)

		tween(
			outerRing2,
			0.8,
			{
				Transparency = 0.82
			}
		)

		task.wait(0.8)
	end
end)

local topGlow = Instance.new("Frame")
topGlow.AnchorPoint = Vector2.new(0.5, 0)
topGlow.Position = UDim2.new(0.5, 0, 0, 0)
topGlow.Size = UDim2.new(0, 400, 0, 2)
topGlow.BackgroundColor3 = RED
topGlow.BorderSizePixel = 0
topGlow.ZIndex = 11
topGlow.Parent = main

corner(topGlow, 5)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 27, 0, 8)
title.Size = UDim2.new(0, 250, 0, 34)
title.Font = Enum.Font.GothamBlack
title.Text = "prysm"
title.TextColor3 = WHITE
title.TextSize = 26
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 12
title.Parent = main

local titleAccent = Instance.new("TextLabel")
titleAccent.BackgroundTransparency = 1
titleAccent.Position = UDim2.new(0, 112, 0, 8)
titleAccent.Size = UDim2.new(0, 100, 0, 34)
titleAccent.Font = Enum.Font.GothamBlack
titleAccent.Text = "ltm"
titleAccent.TextColor3 = RED
titleAccent.TextSize = 26
titleAccent.TextXAlignment = Enum.TextXAlignment.Left
titleAccent.ZIndex = 12
titleAccent.Parent = main

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 29, 0, 40)
subtitle.Size = UDim2.new(0, 300, 0, 18)
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = "movement • utility • control"
subtitle.TextColor3 = MUTED
subtitle.TextSize = 10
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.ZIndex = 12
subtitle.Parent = main

local liveDot = Instance.new("Frame")
liveDot.Position = UDim2.new(0, 30, 0, 69)
liveDot.Size = UDim2.new(0, 7, 0, 7)
liveDot.BackgroundColor3 = RED
liveDot.BorderSizePixel = 0
liveDot.ZIndex = 12
liveDot.Parent = main

corner(liveDot, 10)

local liveText = Instance.new("TextLabel")
liveText.BackgroundTransparency = 1
liveText.Position = UDim2.new(0, 44, 0, 64)
liveText.Size = UDim2.new(0, 130, 0, 18)
liveText.Font = Enum.Font.GothamBold
liveText.Text = "system online"
liveText.TextColor3 = MUTED
liveText.TextSize = 9
liveText.TextXAlignment = Enum.TextXAlignment.Left
liveText.ZIndex = 12
liveText.Parent = main

local function createButton(name, displayText, x, key)
	local button = Instance.new("TextButton")

	button.Name = name
	button.AutoButtonColor = false
	button.AnchorPoint = Vector2.new(0.5, 0.5)

	button.Position = UDim2.new(
		0,
		x + 67.5,
		0,
		94.5
	)

	button.Size = UDim2.new(0, 135, 0, 45)
	button.BackgroundColor3 = DARK2
	button.BorderSizePixel = 0
	button.Text = ""
	button.Active = true
	button.Selectable = true
	button.ZIndex = 20
	button.Parent = main

	corner(button, 12)

	local buttonRing = stroke(
		button,
		Color3.fromRGB(55, 55, 65),
		1.3,
		0.15
	)

	local side = Instance.new("Frame")
	side.Position = UDim2.new(0, 8, 0.5, -10)
	side.Size = UDim2.new(0, 3, 0, 20)
	side.BackgroundColor3 = RED
	side.BorderSizePixel = 0
	side.ZIndex = 21
	side.Parent = button

	corner(side, 5)

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, 19, 0, 2)
	text.Size = UDim2.new(1, -55, 0, 24)
	text.Font = Enum.Font.GothamBold
	text.Text = displayText
	text.TextColor3 = WHITE
	text.TextSize = 14
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 21
	text.Parent = button

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0, 19, 0, 27)
	status.Size = UDim2.new(1, -55, 0, 14)
	status.Font = Enum.Font.GothamMedium
	status.Text = "disabled"
	status.TextColor3 = MUTED
	status.TextSize = 9
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.ZIndex = 21
	status.Parent = button

	local keyBox = Instance.new("TextLabel")
	keyBox.AnchorPoint = Vector2.new(1, 0.5)
	keyBox.Position = UDim2.new(1, -7, 0.5, 0)
	keyBox.Size = UDim2.new(0, 24, 0, 24)
	keyBox.BackgroundColor3 = DARK3
	keyBox.BorderSizePixel = 0
	keyBox.Text = key
	keyBox.Font = Enum.Font.GothamBold
	keyBox.TextColor3 = MUTED
	keyBox.TextSize = 9
	keyBox.ZIndex = 21
	keyBox.Parent = button

	corner(keyBox, 7)

	stroke(
		keyBox,
		Color3.fromRGB(65, 65, 75),
		1,
		0.2
	)

	button.MouseEnter:Connect(function()
		tween(
			button,
			0.12,
			{
				BackgroundColor3 = Color3.fromRGB(25, 18, 22)
			}
		)

		tween(
			buttonRing,
			0.12,
			{
				Color = RED,
				Transparency = 0.05,
				Thickness = 1.8
			}
		)

		tween(
			side,
			0.12,
			{
				Size = UDim2.new(0, 4, 0, 25)
			}
		)
	end)

	button.MouseLeave:Connect(function()
		local enabled = false

		if name == "Trampoline" then
			enabled = trampolineEnabled
		elseif name == "Float" then
			enabled = floatEnabled
		elseif name == "Unwalk" then
			enabled = unwalkEnabled
		elseif name == "AntiDie" then
			enabled = antiDieEnabled
		end

		tween(
			button,
			0.12,
			{
				BackgroundColor3 =
					enabled
					and Color3.fromRGB(25, 18, 22)
					or DARK2
			}
		)

		tween(
			buttonRing,
			0.12,
			{
				Color =
					enabled
					and RED
					or Color3.fromRGB(55, 55, 65),

				Transparency =
					enabled
					and 0.02
					or 0.15,

				Thickness =
					enabled
					and 1.8
					or 1.3
			}
		)

		tween(
			side,
			0.12,
			{
				Size = UDim2.new(0, 3, 0, 20)
			}
		)
	end)

	button.MouseButton1Down:Connect(function()
		tween(
			button,
			0.07,
			{
				Size = UDim2.new(0, 131, 0, 43)
			}
		)
	end)

	button.MouseButton1Up:Connect(function()
		tween(
			button,
			0.12,
			{
				Size = UDim2.new(0, 135, 0, 45)
			},
			Enum.EasingStyle.Back
		)
	end)

	return button, status, buttonRing
end

local trampolineButton, trampolineStatus, trampolineRing =
	createButton(
		"Trampoline",
		"trampoline farm",
		12,
		"q"
	)

local floatButton, floatStatus, floatRing =
	createButton(
		"Float",
		"float",
		155,
		"f"
	)

local instaButton, instaStatus, instaRing =
	createButton(
		"InstaSteal",
		"insta steal",
		298,
		"r"
	)

local unwalkButton, unwalkStatus, unwalkRing =
	createButton(
		"Unwalk",
		"unwalk",
		441,
		"g"
	)

local antiDieButton, antiDieStatus, antiDieRing =
	createButton(
		"AntiDie",
		"anti die",
		584,
		"t"
	)

local function updateButton(
	button,
	status,
	ring,
	enabled
)
	if enabled then
		status.Text = "active"
		status.TextColor3 = RED

		ring.Color = RED
		ring.Transparency = 0.02
		ring.Thickness = 1.8

		tween(
			button,
			0.15,
			{
				BackgroundColor3 =
					Color3.fromRGB(25, 18, 22)
			}
		)
	else
		status.Text = "disabled"
		status.TextColor3 = MUTED

		ring.Color =
			Color3.fromRGB(55, 55, 65)

		ring.Transparency = 0.15
		ring.Thickness = 1.3

		tween(
			button,
			0.15,
			{
				BackgroundColor3 = DARK2
			}
		)
	end
end

local function updateInstaReady()
	instaStatus.Text = "ready"
	instaStatus.TextColor3 = MUTED

	instaRing.Color =
		Color3.fromRGB(55, 55, 65)

	instaRing.Transparency = 0.15
	instaRing.Thickness = 1.3
end

----------------------------------------------------------------
-- NEW TRAMPOLINE FARM LOGIC
----------------------------------------------------------------

local function createTrampolineRayParams()
	local params = RaycastParams.new()

	params.FilterType =
		Enum.RaycastFilterType.Exclude

	params.FilterDescendantsInstances = {
		character
	}

	params.IgnoreWater = true

	return params
end

local function getGroundBelow(position, rayLength)
	if not character or not character.Parent then
		return nil
	end

	local params = createTrampolineRayParams()

	return workspace:Raycast(
		position,
		Vector3.new(
			0,
			-rayLength,
			0
		),
		params
	)
end

local function getBestGroundBelow(position)
	-- Multiple rays make the farm much less likely to
	-- miss thin platforms or choose a weird surface.
	local offsets = {
		Vector3.zero,

		Vector3.new(
			TRAMPOLINE_HORIZONTAL_TOLERANCE,
			0,
			0
		),

		Vector3.new(
			-TRAMPOLINE_HORIZONTAL_TOLERANCE,
			0,
			0
		),

		Vector3.new(
			0,
			0,
			TRAMPOLINE_HORIZONTAL_TOLERANCE
		),

		Vector3.new(
			0,
			0,
			-TRAMPOLINE_HORIZONTAL_TOLERANCE
		)
	}

	local bestResult = nil

	for _, offset in ipairs(offsets) do
		local result = getGroundBelow(
			position + offset,
			TRAMPOLINE_SCAN_DISTANCE
		)

		if result
			and result.Instance
			and result.Instance:IsA("BasePart")
			and result.Instance.CanCollide then

			if not bestResult then
				bestResult = result
			elseif result.Position.Y > bestResult.Position.Y then
				bestResult = result
			end
		end
	end

	return bestResult
end

local function getSafeSurfacePosition(result)
	if not result then
		return nil
	end

	if not result.Instance
		or not result.Instance:IsA("BasePart")
		or not result.Instance.CanCollide then
		return nil
	end

	local hitPosition = result.Position

	-- Keep the character directly over the surface,
	-- but put them 5 studs higher than the normal top
	-- position so the next cycle has room to work.
	return Vector3.new(
		hitPosition.X,
		hitPosition.Y + TRAMPOLINE_RISE,
		hitPosition.Z
	)
end

local function stopVerticalMotion()
	if not root or not root.Parent then
		return
	end

	local velocity = root.AssemblyLinearVelocity

	root.AssemblyLinearVelocity = Vector3.new(
		velocity.X,
		0,
		velocity.Z
	)

	root.AssemblyAngularVelocity = Vector3.zero
end

local function moveToTrampolineSurface(result)
	if not root
		or not root.Parent
		or not result then
		return false
	end

	local target = getSafeSurfacePosition(result)

	if not target then
		return false
	end

	-- Preserve the player's horizontal facing direction.
	local look = root.CFrame.LookVector

	root.CFrame = CFrame.lookAt(
		target,
		target + Vector3.new(
			look.X,
			0,
			look.Z
		)
	)

	stopVerticalMotion()

	return true
end

local function trampolineCycle()
	if not root
		or not root.Parent
		or not humanoid
		or not humanoid.Parent
		or humanoid.Health <= 0 then
		return
	end

	local startingRoot = root
	local startingCharacter = character

	-- Find the actual surface before moving.
	local startingGround = getBestGroundBelow(
		root.Position
	)

	if not startingGround then
		return
	end

	-- Start from a controlled position above the surface.
	local startingTarget = getSafeSurfacePosition(
		startingGround
	)

	if not startingTarget then
		return
	end

	local look = root.CFrame.LookVector

	root.CFrame = CFrame.lookAt(
		startingTarget,
		startingTarget + Vector3.new(
			look.X,
			0,
			look.Z
		)
	)

	stopVerticalMotion()

	-- Wait slightly longer than before.
	-- This makes the farm slower and gives physics
	-- more time to settle.
	task.wait(TRAMPOLINE_STEP_TIME)

	if not trampolineEnabled
		or character ~= startingCharacter
		or root ~= startingRoot
		or not root.Parent then
		return
	end

	-- Search from the player's current position.
	-- We intentionally do NOT blindly teleport to
	-- whatever the first ray happens to hit.
	local nextGround = getBestGroundBelow(
		root.Position
	)

	if nextGround then
		moveToTrampolineSurface(nextGround)
	end

	task.wait(TRAMPOLINE_SETTLE_TIME)
end

local function toggleTrampoline()
	trampolineEnabled = not trampolineEnabled

	updateButton(
		trampolineButton,
		trampolineStatus,
		trampolineRing,
		trampolineEnabled
	)

	if trampolineThread then
		task.cancel(trampolineThread)
		trampolineThread = nil
	end

	if not trampolineEnabled then
		return
	end

	local thisCharacter = character

	trampolineThread = task.spawn(function()
		while trampolineEnabled do
			if character ~= thisCharacter then
				break
			end

			trampolineCycle()

			-- Prevent the loop from running at an
			-- unnecessarily aggressive rate.
			task.wait(0.04)
		end

		trampolineThread = nil
	end)
end

----------------------------------------------------------------
-- FLOAT
----------------------------------------------------------------

local function toggleFloat()
	floatEnabled = not floatEnabled

	updateButton(
		floatButton,
		floatStatus,
		floatRing,
		floatEnabled
	)

	if floatConnection then
		floatConnection:Disconnect()
		floatConnection = nil
	end

	if floatEnabled then
		local thisCharacter = character
		local thisRoot = root

		floatConnection =
			RunService.Heartbeat:Connect(function()
				if character ~= thisCharacter
					or root ~= thisRoot then
					return
				end

				if root
					and root.Parent
					and humanoid
					and humanoid.Parent
					and humanoid.Health > 0 then

					local velocity =
						root.AssemblyLinearVelocity

					root.AssemblyLinearVelocity =
						Vector3.new(
							velocity.X,
							FLOAT_SPEED,
							velocity.Z
						)
				end
			end)
	else
		if root and root.Parent then
			local velocity =
				root.AssemblyLinearVelocity

			root.AssemblyLinearVelocity =
				Vector3.new(
					velocity.X,
					0,
					velocity.Z
				)
		end
	end
end

----------------------------------------------------------------
-- ONE-TIME INSTA STEAL
----------------------------------------------------------------

local function instaStealOnce()
	if not root
		or not root.Parent
		or not humanoid
		or not humanoid.Parent
		or humanoid.Health <= 0 then
		return
	end

	local result = getBestGroundBelow(
		root.Position
	)

	if result then
		-- Insta steal goes down to the surface once.
		local hitPosition = result.Position

		root.CFrame = CFrame.new(
			hitPosition.X,
			hitPosition.Y + 2.5,
			hitPosition.Z
		)

		stopVerticalMotion()
	end

	tween(
		instaRing,
		0.08,
		{
			Color = RED,
			Transparency = 0.02,
			Thickness = 1.8
		}
	)

	task.delay(0.12, function()
		if instaButton and instaButton.Parent then
			tween(
				instaRing,
				0.12,
				{
					Color = Color3.fromRGB(55, 55, 65),
					Transparency = 0.15,
					Thickness = 1.3
				}
			)
		end
	end)

	updateInstaReady()
end

----------------------------------------------------------------
-- UNWALK
----------------------------------------------------------------

local function toggleUnwalk()
	unwalkEnabled = not unwalkEnabled

	updateButton(
		unwalkButton,
		unwalkStatus,
		unwalkRing,
		unwalkEnabled
	)

	applyUnwalk()
end

----------------------------------------------------------------
-- ANTI DIE
----------------------------------------------------------------

local function toggleAntiDie()
	antiDieEnabled = not antiDieEnabled

	updateButton(
		antiDieButton,
		antiDieStatus,
		antiDieRing,
		antiDieEnabled
	)

	if antiDieEnabled then
		startAntiDie()
	else
		stopAntiDie()
		restoreNormalStates()
	end
end

----------------------------------------------------------------
-- BUTTONS
----------------------------------------------------------------

trampolineButton.Activated:Connect(
	toggleTrampoline
)

floatButton.Activated:Connect(
	toggleFloat
)

instaButton.Activated:Connect(
	instaStealOnce
)

unwalkButton.Activated:Connect(
	toggleUnwalk
)

antiDieButton.Activated:Connect(
	toggleAntiDie
)

updateInstaReady()

----------------------------------------------------------------
-- INPUT
----------------------------------------------------------------

UserInputService.InputBegan:Connect(
	function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if UserInputService:GetFocusedTextBox() then
			return
		end

		if input.KeyCode == Enum.KeyCode.Q then
			toggleTrampoline()

		elseif input.KeyCode == Enum.KeyCode.F then
			toggleFloat()

		elseif input.KeyCode == Enum.KeyCode.R then
			instaStealOnce()

		elseif input.KeyCode == Enum.KeyCode.G then
			toggleUnwalk()

		elseif input.KeyCode == Enum.KeyCode.T then
			toggleAntiDie()
		end
	end
)

----------------------------------------------------------------
-- CHARACTER
----------------------------------------------------------------

characterAddedConnection =
	player.CharacterAdded:Connect(function(char)

		stopAntiDie()

		if trampolineThread then
			task.cancel(trampolineThread)
			trampolineThread = nil
		end

		if floatConnection then
			floatConnection:Disconnect()
			floatConnection = nil
		end

		trampolineEnabled = false
		floatEnabled = false

		updateButton(
			trampolineButton,
			trampolineStatus,
			trampolineRing,
			false
		)

		updateButton(
			floatButton,
			floatStatus,
			floatRing,
			false
		)

		setupCharacter(char)

		task.defer(function()
			task.wait(0.15)

			if character ~= char then
				return
			end

			if humanoid and humanoid.Parent then
				humanoid.WalkSpeed = WALK_SPEED
			end

			if antiDieEnabled then
				startAntiDie()
			end

			applyUnwalk()
		end)
	end)

----------------------------------------------------------------
-- GLOBAL HEARTBEAT
----------------------------------------------------------------

heartbeatConnection =
	RunService.Heartbeat:Connect(function()
		forceWalkSpeed()

		if unwalkEnabled then
			applyUnwalk()
		end

		if antiDieEnabled then
			protectCharacter()
		end
	end)

----------------------------------------------------------------
-- BADGE
----------------------------------------------------------------

local badge = Instance.new("Frame")

badge.Name = "PrysmBadge"
badge.AnchorPoint = Vector2.new(0.5, 1)
badge.Position = UDim2.new(0.5, 0, 1, -78)
badge.Size = UDim2.new(0, 175, 0, 38)
badge.BackgroundColor3 = BLACK
badge.BackgroundTransparency = 0.03
badge.BorderSizePixel = 0
badge.ZIndex = 15
badge.Parent = gui

corner(badge, 14)

stroke(
	badge,
	RED,
	1.6,
	0.15
)

local badgeText = Instance.new("TextLabel")

badgeText.BackgroundTransparency = 1
badgeText.Size = UDim2.new(1, 0, 1, 0)
badgeText.Font = Enum.Font.GothamBlack
badgeText.Text = "✦ prysm ltm ✦"
badgeText.TextColor3 = WHITE
badgeText.TextSize = 14
badgeText.ZIndex = 16
badgeText.Parent = badge

----------------------------------------------------------------
-- CORE
----------------------------------------------------------------

local core = Instance.new("Frame")

core.Name = "Core"
core.AnchorPoint = Vector2.new(1, 1)
core.Position = UDim2.new(1, -18, 1, -18)
core.Size = UDim2.new(0, 105, 0, 38)
core.BackgroundColor3 = BLACK
core.BackgroundTransparency = 0.02
core.BorderSizePixel = 0
core.ZIndex = 15
core.Parent = gui

corner(core, 14)

stroke(
	core,
	RED,
	1.5,
	0.25
)

local coreDot = Instance.new("Frame")

coreDot.AnchorPoint = Vector2.new(0, 0.5)
coreDot.Position = UDim2.new(0, 11, 0.5, 0)
coreDot.Size = UDim2.new(0, 8, 0, 8)
coreDot.BackgroundColor3 = RED
coreDot.BorderSizePixel = 0
coreDot.ZIndex = 16
coreDot.Parent = core

corner(coreDot, 10)

local coreText = Instance.new("TextLabel")

coreText.BackgroundTransparency = 1
coreText.Position = UDim2.new(0, 28, 0, 0)
coreText.Size = UDim2.new(1, -32, 1, 0)
coreText.Font = Enum.Font.GothamBlack
coreText.Text = "core"
coreText.TextColor3 = WHITE
coreText.TextSize = 10
coreText.ZIndex = 16
coreText.Parent = core

local coreWords = {
	"core",
	"prysm",
	"ltm",
	"active",
	"sync",
	"online",
	"ready"
}

task.spawn(function()
	local index = 1

	while gui.Parent do
		coreText.Text = coreWords[index]

		tween(
			coreDot,
			0.55,
			{
				Size = UDim2.new(0, 11, 0, 11)
			}
		)

		task.wait(0.55)

		if not gui.Parent then
			break
		end

		tween(
			coreDot,
			0.55,
			{
				Size = UDim2.new(0, 8, 0, 8)
			}
		)

		task.wait(0.55)

		index += 1

		if index > #coreWords then
			index = 1
		end
	end
end)

----------------------------------------------------------------
-- INTRO
----------------------------------------------------------------

local intro = Instance.new("Frame")

intro.Name = "Intro"
intro.Size = UDim2.new(1, 0, 1, 0)
intro.BackgroundColor3 = Color3.fromRGB(2, 2, 5)
intro.BackgroundTransparency = 0
intro.BorderSizePixel = 0
intro.ZIndex = 100
intro.Parent = gui

local introRing = Instance.new("Frame")

introRing.AnchorPoint = Vector2.new(0.5, 0.5)
introRing.Position = UDim2.new(0.5, 0, 0.5, 0)
introRing.Size = UDim2.new(0, 210, 0, 210)
introRing.BackgroundTransparency = 1
introRing.ZIndex = 101
introRing.Parent = intro

corner(introRing, 200)

local introRingStroke = stroke(
	introRing,
	RED,
	3,
	0.1
)

local introTitle = Instance.new("TextLabel")

introTitle.AnchorPoint = Vector2.new(0.5, 0.5)
introTitle.Position = UDim2.new(0.5, 0, 0.46, 0)
introTitle.Size = UDim2.new(0, 600, 0, 90)
introTitle.BackgroundTransparency = 1
introTitle.Font = Enum.Font.GothamBlack
introTitle.Text = "prysm"
introTitle.TextColor3 = WHITE
introTitle.TextSize = 68
introTitle.TextTransparency = 0
introTitle.ZIndex = 102
introTitle.Parent = intro

local introSub = Instance.new("TextLabel")

introSub.AnchorPoint = Vector2.new(0.5, 0.5)
introSub.Position = UDim2.new(0.5, 0, 0.55, 0)
introSub.Size = UDim2.new(0, 300, 0, 30)
introSub.BackgroundTransparency = 1
introSub.Font = Enum.Font.GothamBold
introSub.Text = "l  t  m"
introSub.TextColor3 = RED
introSub.TextSize = 18
introSub.TextTransparency = 0
introSub.ZIndex = 102
introSub.Parent = intro

local introLine = Instance.new("Frame")

introLine.AnchorPoint = Vector2.new(0.5, 0.5)
introLine.Position = UDim2.new(0.5, 0, 0.60, 0)
introLine.Size = UDim2.new(0, 0, 0, 2)
introLine.BackgroundColor3 = RED
introLine.BackgroundTransparency = 0
introLine.BorderSizePixel = 0
introLine.ZIndex = 102
introLine.Parent = intro

corner(introLine, 5)

tween(
	introLine,
	0.5,
	{
		Size = UDim2.new(0, 260, 0, 2)
	}
)

task.spawn(function()
	for i = 1, 20 do
		if not intro.Parent then
			return
		end

		introTitle.Position = UDim2.new(
			0.5,
			math.random(-5, 5),
			0.46,
			math.random(-3, 3)
		)

		task.wait(0.025)
	end

	if not intro.Parent then
		return
	end

	introTitle.Position =
		UDim2.new(
			0.5,
			0,
			0.46,
			0
		)

	task.wait(0.25)

	if not intro.Parent then
		return
	end

	tween(
		intro,
		0.6,
		{
			BackgroundTransparency = 1
		}
	)

	tween(
		introTitle,
		0.5,
		{
			TextTransparency = 1
		}
	)

	tween(
		introSub,
		0.5,
		{
			TextTransparency = 1
		}
	)

	tween(
		introLine,
		0.5,
		{
			BackgroundTransparency = 1
		}
	)

	tween(
		introRing,
		0.6,
		{
			Size = UDim2.new(
				0,
				400,
				0,
				400
			)
		}
	)

	tween(
		introRingStroke,
		0.6,
		{
			Transparency = 1
		}
	)

	task.wait(0.7)

	if intro and intro.Parent then
		intro:Destroy()
	end
end)

----------------------------------------------------------------
-- CAMERA
----------------------------------------------------------------

RunService:BindToRenderStep(
	"PrysmLTM_Camera",
	Enum.RenderPriority.Camera.Value + 1,
	function(dt)
		if humanoid and humanoid.Parent then
			humanoid.CameraOffset =
				humanoid.CameraOffset:Lerp(
					Vector3.zero,
					math.clamp(
						dt * 12,
						0,
						1
					)
				)
		end
	end
)

----------------------------------------------------------------
-- CHARACTER REMOVING
----------------------------------------------------------------

characterRemovingConnection =
	player.CharacterRemoving:Connect(function(char)

		if character ~= char then
			return
		end

		if trampolineThread then
			task.cancel(trampolineThread)
			trampolineThread = nil
		end

		if floatConnection then
			floatConnection:Disconnect()
			floatConnection = nil
		end

		stopAntiDie()

		character = nil
		humanoid = nil
		root = nil
		animateScript = nil
	end)

----------------------------------------------------------------
-- CLEANUP
----------------------------------------------------------------

gui.Destroying:Connect(function()

	if trampolineThread then
		task.cancel(trampolineThread)
		trampolineThread = nil
	end

	if floatConnection then
		floatConnection:Disconnect()
		floatConnection = nil
	end

	stopAntiDie()

	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end

	if characterAddedConnection then
		characterAddedConnection:Disconnect()
		characterAddedConnection = nil
	end

	if characterRemovingConnection then
		characterRemovingConnection:Disconnect()
		characterRemovingConnection = nil
	end

	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	pcall(function()
		RunService:UnbindFromRenderStep(
			"PrysmLTM_Camera"
		)
	end)
end)
