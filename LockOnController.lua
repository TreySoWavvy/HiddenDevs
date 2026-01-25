--// NAME: Aim Assist
--// CLASS: SERVICE
--// TIMESTAMP: 6 JAN 2025
--// DESCRIPTOR: HANDLES A GENTLE AIM ASSIST FOR LOCK ON / DUELS.
--// BY: TREYSOWAVVY (Don)
----


--// FRAMEWORK SUPPORT
local Client_Dependents = game.ReplicatedStorage["Client/Dependents"];
local Framework = require(Client_Dependents.Framework.FrameworkCore);

Framework.OnStart():await()

--// SERVICES
local RS = game:GetService("RunService");
local UIS = game:GetService("UserInputService");


--// UTILITY MODULES
local Debris = require(Framework.Modules.Debris);
local Library = require(Framework.Modules.Library);
local GoodSignal = require(Framework.Modules.GoodSignal);
local Janitor = require(Framework.Modules.Janitor);
local Format = require(Framework.Modules.Format);
local Promise = require(Framework.Modules.Promise);

--// VARIABLES
local LocalPlayer = game.Players.LocalPlayer;
local Camera = workspace.CurrentCamera;


--// CLASS OBJECT
local LockOnController = {}
LockOnController.__index = LockOnController


function LockOnController.new(Options : any)
	local self = setmetatable({}, LockOnController)

	self.Settings = {
		Enabled = false,
		SoftLockEnabled = true,
		TargetSwappingEnabled = false;
		
		FaceTarget = true;
		CharacterTurnSpeed = 20; -- higher = snappier
		
		LockCameraPosition = true;
		
		RotationLerpSpeed = 12,
		
		-- Camera offsets
		Offsets = {
			RightShoulderOffset = CFrame.new(4.75, 1.6, 6),
			LeftShoulderOffset  = CFrame.new(-4.75, 1.6, 6),
			CenterOffset        = CFrame.new(0, 1.8, 6),
		},
		
		CameraSide = "Right";
		
		CameraLerpSpeed = 12,
		LookAtHeight = 1.5,

		-- Lock cone
		LockConeAngle = 35,
		MaxLockDistance = 40,

		-- Soft lock
		SoftLockAngle = 25,
		SoftLockStrength = 0.15,

		-- Target switching
		MouseFlickThreshold = 120,

		-- Obstruction
		CameraPushInPadding = 0.3,
	}

	-- Optional overrides
	if Options then
		for k, v in pairs(Options) do
			self.Settings[k] = v
		end
	end

	-- Runtime state
	self.Character = nil
	self.Root = nil
	self.Target = nil
	self.PotentialTargets = {}

	self._connection = nil
	self._lastMouseX = nil

	self.LockedOn = GoodSignal.new();
	
	return self
end


local function GetHRP(Entity_Model : Model)
	return Entity_Model and Entity_Model:FindFirstChild("HumanoidRootPart")
end;

local function angleBetween(a, b)
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end;


function LockOnController:Connect(Task : any, CleanupMethod : string, TaskName : string) --// The Janitor keeps track of connections that will be garbage collected at some point.
	if not self.__janitor then
		self.__janitor = Janitor.new()
	end

	return self.__janitor:Add(Task, CleanupMethod, TaskName)
end;

function LockOnController:Disconnect(TaskName : string) --// Disconnect allows you to specifically disconnect 1 connection, or all of them.
	if self.__janitor then
		if TaskName then
			self.__janitor:Remove(TaskName)
		else
			self.__janitor:Destroy()
			self.__janitor = nil
		end
	end
end;


function LockOnController:GetTargets() --// Gets a list of all Humanoid Models in game, and filters them based on specific criteria.
	return Promise.new(function(resolve, reject)
		
		local Potential_Targets = {}
		local Checked = {};

		for _, Entity in pairs(workspace:GetDescendants()) do
			if Entity.ClassName == "Model" and Entity:FindFirstChild("Humanoid") then
				local Humanoid = Entity:FindFirstChild("Humanoid");
				local HRP = Entity:FindFirstChild("HumanoidRootPart");


				--// Prevent them from being targeted if they arent alive, dont have a root part, or are out of range.
				--// Also prevents the player from targeting THEMSELVES. Ironically enough.
				if (not Humanoid) or (Humanoid and Humanoid.Health <= 0) then continue end;
				if not HRP then continue end;
				if Entity == self.Character then continue end;
				if (self.Root.Position - HRP.Position).magnitude > self.Settings["MaxLockDistance"] then continue end;


				--// If the target isnt even on screen, ignore them. Prevents targeting people not in your view.
				local Screen_Point, Is_On_Screen = Camera:WorldToScreenPoint(HRP.Position);
				if not Is_On_Screen then continue end;


				if not Checked[Entity] then
					Checked[Entity] = true;
					table.insert(Potential_Targets, Entity)
				end
			end
		end

		resolve(Potential_Targets)
		
	end)
end;

function LockOnController:GetTargetInCone(Max_Angle : number) --// Takes the list of targets from GetTargets, and selects the best one.
	return Promise.new(function(resolve, reject)
		
		local Cam_Look_Vector = Camera.CFrame.LookVector
		local Cam_Position = Camera.CFrame.Position

		self:GetTargets():andThen(function(Potential_Targets)
			print(Potential_Targets)
			if Potential_Targets then
				local Best_Target, Best_Angle = nil, Max_Angle;

				for _, Entity in ipairs(Potential_Targets) do
					local HRP = Entity.HumanoidRootPart;
					local Current_Direction = HRP.Position - Cam_Position;
					local Current_Distance = Current_Direction.Magnitude;

					if Current_Distance <= self.Settings.MaxLockDistance then
						local Current_Target_Angle = angleBetween(Cam_Look_Vector, Current_Direction.Unit)
						if Current_Target_Angle <= Best_Angle then
							Best_Angle = Current_Target_Angle;
							Best_Target = Entity;
						end
					end
				end

				print(Best_Target.Name)
				self.Target = Best_Target;
				resolve(Best_Target)
			else
				resolve()
			end
		end)
		
	end)
end;

function LockOnController:ResolveObstruction(Focus_Position : Vector3, Desired_Position : Vector3) --// Prevents the camera from clipping into walls and stuff.
	local RCP = RaycastParams.new();
	RCP.FilterDescendantsInstances = {self.Character};
	RCP.FilterType = Enum.RaycastFilterType.Exclude;

	local result = workspace:Raycast(
		Focus_Position,
		Desired_Position - Focus_Position,
		RCP
	)

	if result then
		return result.Position - (Desired_Position - Focus_Position).Unit * self.Settings.CameraPushInPadding
	else
		return Desired_Position
	end
end;


function LockOnController:HandleMouseSwitch() --// Handles when you "flick" your mouse, allows you to switch targets.
	if not self.Settings["TargetSwappingEnabled"] then return end
	local x = UIS:GetMouseLocation().X

	if self._lastMouseX then
		local delta = x - self._lastMouseX
		if math.abs(delta) > self.Settings.MouseFlickThreshold then
			self.Target = self:GetTargetInCone(
				self.PotentialTargets,
				self.Settings.LockConeAngle
			)
		end
	end

	self._lastMouseX = x
end;


function LockOnController:UpdateSoftLock(dt)
	if not self.Settings.Enabled then
		self:ApplySoftLock(dt)
	end
end;

function LockOnController:CycleShoulder() --// Switches the camera's perspective from either left, right, or top.
	self.Settings.CameraSide =
		self.Settings.CameraSide == "Right" and "Left"
		or self.Settings.CameraSide == "Left" and "Center"
		or "Right"
end;


function LockOnController:UpdateCharacterFacing(Delta_Time : number) --// Forces the player's character to consistently face the target.
	if not self.Settings.FaceTarget then return end
	if not self.Root or not self.Target then return end

	local targetRoot = self.Target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	local rootPos = self.Root.Position
	local targetPos = targetRoot.Position

	-- Flatten to XZ plane (no pitch)
	local lookDir = Vector3.new(
		targetPos.X - rootPos.X,
		0,
		targetPos.Z - rootPos.Z
	)

	if lookDir.Magnitude < 0.001 then return end

	-- Build yaw-only CFrame
	local desired = CFrame.new(rootPos, rootPos + lookDir)

	-- Lerp rotation ONLY (preserve position)
	self.Root.CFrame = self.Root.CFrame:Lerp(
		desired,
		Delta_Time * self.Settings.CharacterTurnSpeed
	)
end

function LockOnController:ApplySoftLock(Delta_Time : number) --// A soft "aim assist" style of the lock on that isnt absolute, drifts the camera instead.
	if not self.Settings.SoftLockEnabled then return end;
	if not self.Target then return end;

	local HRP = self.Target:FindFirstChild("HumanoidRootPart")

	if HRP then
		-- Auto-unlock by distance
		if (HRP.Position - self.Root.Position).Magnitude >
			self.Settings.MaxLockDistance then
			self:Disable()
			return
		end
		
		self._smoothedRootCF = (self._smoothedRootCF and self._smoothedRootCF:Lerp(self.Root.CFrame, Delta_Time * 20)) or (self.Root.CFrame)

		-- Pick shoulder offset
		local shoulderCF
		if self.Settings.CameraSide == "Right" then
			shoulderCF = self.Settings.Offsets.RightShoulderOffset
		elseif self.Settings.CameraSide == "Left" then
			shoulderCF = self.Settings.Offsets.LeftShoulderOffset
		else
			shoulderCF = self.Settings.Offsets.CenterOffset
		end
		
		local desiredCF = self._smoothedRootCF * shoulderCF


		-- Build look-at WITHOUT moving camera
		local lookTarget
		if self.Target then
			local targetRoot = self.Target:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				lookTarget = targetRoot.Position + Vector3.new(0, self.Settings.LookAtHeight, 0)
			end
		end
		
		if lookTarget then
			desiredCF = CFrame.new(desiredCF.Position, lookTarget)
		end
		
		-- Obstruction push-in (still allowed)
		local desiredPos = self:ResolveObstruction(lookTarget, desiredCF.Position)
		desiredCF = CFrame.lookAt(desiredPos, lookTarget)
	
		
		Camera.CFrame = Camera.CFrame:Lerp(
			desiredCF,
			self.Settings.SoftLockStrength
		)

	end
end;

function LockOnController:UpdateCamera(Delta_Time) --// A harder "lock on" style that keeps the camera locked on.
	if not self.Target or not self.Root then return end

	local targetRoot = self.Target:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	-- Auto-unlock by distance
	if (targetRoot.Position - self.Root.Position).Magnitude >
		self.Settings.MaxLockDistance then
		self:Disable()
		return
	end

	local shoulderOffset = self.Settings.Offsets[self.Settings.CameraSide]
	local cameraCF = self.Root.CFrame * shoulderOffset

	-- Obstruction push-in (still allowed)
	local resolvedPos = self:ResolveObstruction(
		targetRoot.Position,
		cameraCF.Position
	)

	-- Always look at target
	local desiredCF = CFrame.lookAt(
		resolvedPos,
		targetRoot.Position
	)

	-- Rotation smoothing ONLY (position is fixed)
	Camera.CFrame = Camera.CFrame:Lerp(
		desiredCF,
		Delta_Time * self.Settings.RotationLerpSpeed
	)
end


function LockOnController:Enable() --// Enables the lock on, and attempts to get the first target. If none exist, it'll just turn itself off.
	--if self.Settings.Enabled then return end

	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();
	self.Root = self.Character:WaitForChild("HumanoidRootPart");
	self.Humanoid = self.Character:FindFirstChild("Humanoid");

	self._smoothedRootCF = nil
	
	self:GetTargetInCone(self.Settings.LockConeAngle):andThen(function(New_Target)
		if not New_Target then
			warn("No Targets found to lock onto.");
			return self:Disable();
		end;
		
		local Humanoid = New_Target:FindFirstChild("Humanoid");
		
		--warn("Enabling Aim Assist.");
		Camera.CameraType = Enum.CameraType.Scriptable;
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter;
		self.Humanoid.AutoRotate = false
		self.LockedOn:Fire(true, New_Target);

		
		--// Disable lock on if the target is removed from the world.
		self:Connect(workspace.DescendantRemoving:Connect(function(Model)
			if Model == New_Target then
				self:Disable()
			end
		end), "Disconnect", "Target_Died");
		
		--// Disable Lock On if the target dies.
		self:Connect(Humanoid.Died:Connect(function()
			self:Disable()
		end), "Disconnect", "Target_Died");
		
		
		self:Connect(RS.Heartbeat:Connect(function(Delta_Time : number)
			self:UpdateCharacterFacing(Delta_Time);
			self:HandleMouseSwitch(Delta_Time);
			--self:UpdateCamera(dt);
			self:ApplySoftLock(Delta_Time);
		end), "Disconnect", "Update_Cycle");
	end);
end;

function LockOnController:Disable() --// Turns off the lock on, clears the connections and resets the camera.
	--if not self.Settings.Enabled then return end
	
	self:Disconnect()

	if self.Humanoid then
		self.Humanoid.AutoRotate = true
	end;
	
	--warn("Disabling Aim Assist.")
	self.LockedOn:Fire(false)
	self.Target = nil
	self._lastMouseX = nil

	Camera.CameraType = Enum.CameraType.Custom;
	UIS.MouseBehavior = Enum.MouseBehavior.Default;
end;

function LockOnController:Toggle(Override : boolean) --// Toggles the Lock On.
	if Override ~= nil then
		self.Settings.Enabled = Override;
	else
		self.Settings.Enabled = not self.Settings.Enabled
	end
	
	if self.Settings.Enabled then
		self:Enable()
	else
		self:Disable()
	end
end;



return LockOnController
