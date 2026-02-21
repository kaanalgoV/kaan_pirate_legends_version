-- InputController.luau — Central input binding and routing
-- Q = Rasur links, E = Rasur rechts, H = Haki Toggle

local UserInputService = game:GetService("UserInputService")

local InputController = {}

local bindings: { [string]: any } = {}
local heldKeys: { [Enum.KeyCode]: boolean } = {}

function InputController.init(callbacks: {
	onM1: () -> (),
	onBlock: (boolean) -> (),
	onAbility: (number) -> (),
	onHakiToggle: () -> (),
	onDodgeLeft: () -> (),
	onDodgeRight: () -> (),
	onSprint: (boolean) -> (),
	onGeppo: () -> (),
	onSoru: () -> (),
	onWaver: () -> (),
	onAwaken: (() -> ())?,
})
	bindings = callbacks

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		InputController.handleInput(input, true)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		InputController.handleInput(input, false)
	end)
end

function InputController.handleInput(input: InputObject, pressed: boolean)
	local key = input.KeyCode
	local inputType = input.UserInputType

	if pressed then
		heldKeys[key] = true
	else
		heldKeys[key] = nil
	end

	-- M1 Click
	if inputType == Enum.UserInputType.MouseButton1 and pressed then
		if bindings.onM1 then bindings.onM1() end
		return
	end

	-- Block (F key hold)
	if key == Enum.KeyCode.F then
		if bindings.onBlock then bindings.onBlock(pressed) end
		return
	end

	-- Sprint (LeftShift hold)
	if key == Enum.KeyCode.LeftShift then
		if bindings.onSprint then bindings.onSprint(pressed) end
		return
	end

	if not pressed then return end

	-- Q = Rasur LINKS (dodge left)
	if key == Enum.KeyCode.Q then
		if bindings.onDodgeLeft then bindings.onDodgeLeft() end

	-- E = Rasur RECHTS (dodge right)
	elseif key == Enum.KeyCode.E then
		if bindings.onDodgeRight then bindings.onDodgeRight() end

	-- H = Haki Toggle
	elseif key == Enum.KeyCode.H then
		if bindings.onHakiToggle then bindings.onHakiToggle() end

	-- Abilities (1-6)
	elseif key == Enum.KeyCode.One then
		if bindings.onAbility then bindings.onAbility(1) end
	elseif key == Enum.KeyCode.Two then
		if bindings.onAbility then bindings.onAbility(2) end
	elseif key == Enum.KeyCode.Three then
		if bindings.onAbility then bindings.onAbility(3) end
	elseif key == Enum.KeyCode.Four then
		if bindings.onAbility then bindings.onAbility(4) end
	elseif key == Enum.KeyCode.Five then
		if bindings.onAbility then bindings.onAbility(5) end
	elseif key == Enum.KeyCode.Six then
		if bindings.onAbility then bindings.onAbility(6) end

	-- Geppo / Air Jump (Space in air)
	elseif key == Enum.KeyCode.Space then
		if bindings.onGeppo then bindings.onGeppo() end

	-- Soru (V = teleport dash)
	elseif key == Enum.KeyCode.V then
		if bindings.onSoru then bindings.onSoru() end

	-- Waver (U = cloud surfer)
	elseif key == Enum.KeyCode.U then
		if bindings.onWaver then bindings.onWaver() end

	-- Awakening (T = transformation toggle)
	elseif key == Enum.KeyCode.T then
		if bindings.onAwaken then bindings.onAwaken() end
	end
end

function InputController.isKeyHeld(key: Enum.KeyCode): boolean
	return heldKeys[key] == true
end

function InputController.getMovementDirection(): Vector3
	local dir = Vector3.zero
	if heldKeys[Enum.KeyCode.W] then dir = dir + Vector3.new(0, 0, -1) end
	if heldKeys[Enum.KeyCode.S] then dir = dir + Vector3.new(0, 0, 1) end
	if heldKeys[Enum.KeyCode.A] then dir = dir + Vector3.new(-1, 0, 0) end
	if heldKeys[Enum.KeyCode.D] then dir = dir + Vector3.new(1, 0, 0) end

	if dir.Magnitude > 0 then
		local camera = workspace.CurrentCamera
		if camera then
			local look = camera.CFrame.LookVector
			local flat = CFrame.new(Vector3.zero, Vector3.new(look.X, 0, look.Z).Unit)
			dir = flat:VectorToWorldSpace(dir).Unit
		end
	end

	return dir
end

function InputController.getLeftDodgeDirection(): Vector3
	local camera = workspace.CurrentCamera
	if camera then
		local right = camera.CFrame.RightVector
		return Vector3.new(-right.X, 0, -right.Z).Unit
	end
	return Vector3.new(-1, 0, 0)
end

function InputController.getRightDodgeDirection(): Vector3
	local camera = workspace.CurrentCamera
	if camera then
		local right = camera.CFrame.RightVector
		return Vector3.new(right.X, 0, right.Z).Unit
	end
	return Vector3.new(1, 0, 0)
end

return InputController
