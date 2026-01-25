--// NAME: LIGHTSABER CLIENT
--// CLASS: SERVICE
--// TIMESTAMP: 6 JAN 2025
--// DESCRIPTOR: HANDLES THE SERVER SIDE CREATION AND MANAGEMENT OF LIGHTSABERS CLIENT SIDE
--// BY: TREYSOWAVVY (Don)
----



--// FRAMEWORK SUPPORT
local Client_Dependents = game.ReplicatedStorage["Client/Dependents"];
local Framework = require(Client_Dependents.Framework.FrameworkCore);

Framework.OnStart():await()

--// SERVICES
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

Lightsaber_Service = Framework.GetService("Lightsabers");


local Character = Framework.GetController("Character");
local Global = Framework.GetController("Global");

--// UTILITY MODULES
local Debris = require(Framework.Modules.Debris);
local Library = require(Framework.Modules.Library);
local GoodSignal = require(Framework.Modules.GoodSignal);
local Janitor = require(Framework.Modules.Janitor);
local Format = require(Framework.Modules.Format);
local Animation = require(Framework.Modules.Animation);
local Ragdoll = require(Framework.Modules.Ragdoll);
local Promise = require(Framework.Modules.Promise);
local RayHitbox = require(Framework.Modules.RayHitbox);
local LockOn = require(script.LockOn);

local Lightsaber_Index = require(Framework.Information.Lightsabers);


--// DEPENDENTS
local Animations_Folder = Client_Dependents.Animations.Lightsabers;

local Forms = { --// The list of forms each lightsaber can utilize if allowed.
	["Single"] = {"Shii-Cho", "Makashi", "Soresu", "Ataru", "Djem-So", "Niman", "Shien"};
	
	["Double"] = {"Soresu"};
	
	["Dual"] = {"Jar'Kai"};
}


--// GLOBAL VARIABLES
local Player = game.Players.LocalPlayer;
local Camera = workspace.CurrentCamera;



--// LIGHTSABER CLASS OBJECT
local Lightsaber = {};
Lightsaber.__index = Lightsaber;



--// GARBAGE COLLECTION METHODS
function Lightsaber:Connect(Task : any, CleanupMethod : string, TaskName : string) --// The Janitor keeps track of connections that will be garbage collected at some point.
	if not self.__janitor then
		self.__janitor = Janitor.new()
	end

	return self.__janitor:Add(Task, CleanupMethod, TaskName)
end;

function Lightsaber:Disconnect(TaskName : string) --// Disconnect allows you to specifically disconnect 1 connection, or all of them.
	if self.__janitor then
		if TaskName then
			self.__janitor:Remove(TaskName)
		else
			self.__janitor:Destroy()
			self.__janitor = nil
		end
	end
end;

function Lightsaber:Replicate(Properties : any) --// Replicates any changes to the lightsaber to the server class object.
	Properties.Tool = self.Tool;
	Lightsaber_Service:Fire(Properties);
end;

function Lightsaber:AreDirectionalKeysDown() --// Checks to see if the character is moving.
	return UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D)
end;



--// PROPERTY MANAGEMENT: GetProperty reads the value, SetProperty changes it.
function Lightsaber:SetProperty(Name : string, New_Value : any)
	local Old_Value = self:GetProperty(Name);
	self.Tool:SetAttribute(Name, New_Value);
	
	--// Fire the custom signal so the rest of the lightsaber code can "hear" it.
	self.PropertyChanged:Fire(Name, New_Value, Old_Value);
end;

function Lightsaber:GetProperty(Name : string)
	return self.Tool:GetAttribute(Name)
end;

function Lightsaber:SetStatus(Type : string) --// Modifies a GUI object using colors to let a player know an action is taking place.
	Global.Tween(self.UI.Status, TweenInfo.new(.15, Enum.EasingStyle.Cubic), {
		BackgroundColor3 = (Type == "Parry" and Library.Color.Gold or Type == "Block" and Library.Color.White or Library.Color.Grey)
	})
end;



--// STAMINA CHANGES
function Lightsaber:SetStaminaRegenDelay(Duration : number) --// Adds a delay before stamina starts regenerating.
	return self.Character_Class:SetStaminaRegenDelay(Duration)
end;

function Lightsaber:HasEnoughStamina(Amount : number) --// Checks to make sure the player has enough stamina.
	return self.Character_Class:HasEnoughStamina(Amount)
end;

function Lightsaber:RegenStamina(Amount : number) --// Regenerate a fixed amount of stamina.
	return self.Character_Class:RegenStamina(Amount)
end;

function Lightsaber:ConsumeStamina(Amount : number) --// Consume a fixed amount of stamina.
	return self.Character_Class:ConsumeStamina(Amount)
end;



--// ANIMATION HANDLING. Functions that let you quickly manage animations.
function Lightsaber:IsPlaying(Name : string)
	if not self.Animations then return end

	if self.Animations[Name] then
		return self.Animations[Name]:IsPlaying()
	end
end;

function Lightsaber:LoadAnimations(Animation_Folder : Folder)
	assert(Animation_Folder, "A folder of animations must be provided to load.");
	
	self:UnloadAnimations():await()
	
	if not self.Animations then
		self.Animations = {}
	end
	

	for _, AnimObject in pairs(Animation_Folder:GetDescendants()) do
		if AnimObject.ClassName == "Animation" then
			local NewAnimClass = Animation.new(AnimObject, self.Character)
			self.Animations[AnimObject.Name] = NewAnimClass
		end
	end

	self:LoadAnimationEvents()
end;

function Lightsaber:GetAnimation(Name : string)
	return (self.Animations and self.Animations[Name])
end;

function Lightsaber:PlayAnimation(Name : string, FadeIn : number, Weight : number, Speed : number) --// Done
	if not self.Animations then return end

	if self.Animations[Name] and not self.Animations[Name]:IsPlaying() then
		self.Animations[Name]:Play(FadeIn or .1, Weight or 1, Speed or 1)
	end
end;

function Lightsaber:StopAnimation(Name : string, FadeOut) --// Done
	if not self.Animations then return end

	if self.Animations[Name] then
		self.Animations[Name]:Stop(FadeOut or .35)
	elseif Name == "All" then
		for Name, Animation in pairs(self.Animations) do
			Animation:Stop(FadeOut or .35)
		end
	end
end;

function Lightsaber:UnloadAnimations() --// Done
	return Promise.new(function(resolve, reject)
		if self.Animations then
			for Name, Animation in pairs(self.Animations) do
				Animation:Destroy()
				self.Animations[Name] = nil
			end
		end
		
		self.Animations = nil
		resolve()
	end)
end;

function Lightsaber:LoadAnimationEvents()
	if not self.Animations then return end
	
	self.Animations["Equip"].Track.Looped = false;
	self.Animations["Unequip"].Track.Looped = false;
end;

function Lightsaber:AdjustAnimSpeed(AnimName : string, Speed : number)
	if not self.Animations then return end

	if self.Animations[AnimName] then
		self.Animations[AnimName]:AdjustSpeed(Speed)
	end
end;




--// ACTION METHODS: The methods specifically involved with using the lightsaber.
function Lightsaber:ChangeForms() --// Changes the lightsaber's form to another animation set.
	if os.clock() - self["Last_Form_Change"] < self["Form_Change_Cooldown"] then return end;
	if not self:GetProperty("Equipped") then return end;
	if self:GetProperty("Attacking") then return end;
	if self:GetProperty("Blocking") then return end;
	
	
	local Available_Forms = Forms[self:GetProperty("Type")]
	
	
	--// Get the current slot of the form.
	local Current_Form_Slot;
	for Slot, Name in pairs(Available_Forms) do
		if Name == self:GetProperty("Form") then
			Current_Form_Slot = Slot
			break;
		end
	end
	
	
	--// Incrementally change the form until it hits the last one.
	--// Once it does, start over from the first one.
	
	if Current_Form_Slot == #Available_Forms then
		self:SetProperty("Form", Available_Forms[1])
	elseif Current_Form_Slot < #Available_Forms then
		self:SetProperty("Form", Available_Forms[math.clamp(Current_Form_Slot + 1, 1, #Available_Forms)])
	end;
	

	self["Last_Form_Change"] = os.clock();
	self.Current_Form = self:GetProperty("Form");
	self.UI.Form.Text = self:GetProperty("Form");
	self:LoadAnimations(Animations_Folder[self.Lightsaber_Type][self.Current_Form]);
	
	
	Global.Tween(self.UI.Form.UIStroke, TweenInfo.new(.15, Enum.EasingStyle.Cubic), {Transparency = 0.5})
	Global.Tween(self.UI.Form, TweenInfo.new(.15, Enum.EasingStyle.Cubic), {TextTransparency = 0}):andThen(function()
		task.wait(1)
		Global.Tween(self.UI.Form, TweenInfo.new(.5, Enum.EasingStyle.Cubic), {TextTransparency = 1})
		Global.Tween(self.UI.Form.UIStroke, TweenInfo.new(.15, Enum.EasingStyle.Cubic), {Transparency = 15})
	end)
	
	
	--// Get a time stamp of when the form changed so we can use it for a cooldown later.
	if self:GetProperty("Equipped") and self:GetProperty("Ignited") then
		if not self.Character_Class.Is_Sprinting then
			self:PlayAnimation("Idle")
		end
	end
end;

function Lightsaber:Stun() --// Stuns the player, plays an animation, applies a backward impulse, prevents them from doing anything else.
	if self.Animations["Stunned"] then
		self:SetProperty("Stunned", true);
		self:Replicate({
			Task = "Stun";
			Is_Stunned = true;
		});

		self:StopAnimation("All");
		self:PlayAnimation("Stunned");
		self:AdjustAnimSpeed("Stunned", .75);

		local Direction = self.HRP.CFrame.LookVector * 35;
		Global.Tween(self.HRP, TweenInfo.new(.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = Direction});
		self:AdjustAnimSpeed("Stunned", .75);
		task.delay(self.Animations.Stunned:GetLength(), function()
			self:SetProperty("Stunned", false);
			self:Replicate({
				Task = "Stun";
				Is_Stunned = false;
			});
		end)
	end
end;

function Lightsaber:Attack(Is_Attacking : boolean) --// Conducts an attack if possible.
	if Is_Attacking then
		
		if self:GetProperty("Attacking") then return end; --// Prevent attacking when they are already mid attack.
		if not self:GetProperty("Ignited") then return end; --// Prevent attacking when the saber isnt even ignited.
		if not self:GetProperty("Equipped") then return end; --// Prevent attacking when the saber isnt even equipped.
		if self:GetProperty("Stunned") then return end; --// Prevent attacking when stunned.
		
		if not self:HasEnoughStamina(self["Stamina_Consumption"]["Attack"]) then return end --// If they dont have enough stamina to swing, then prevent it.
		
		--// Attempt a parry if possible.
		if self:GetProperty("Blocking") then
			self:Parry();
		end;


		self:SetProperty("Parry", true);

		--// If the player's CURRENT ATTACK is within a certain time since their LAST attack, track it. This is considered a "combo"
		local Is_In_Combo_Window = (self["Last_Attack"] and os.clock() - self["Last_Attack"] <= self["Attack_Combo_Window"])
		local Attack_Index = self:GetProperty("AttackIndex");
		local Attack_Speed = 1;
		local Attack_Name = "Attack" .. Attack_Index;


		if Attack_Index + 1 > 3 or not Is_In_Combo_Window then
			Attack_Index = 1;
			Attack_Name = "Attack" .. Attack_Index;
		else
			Attack_Index = math.clamp(Attack_Index + 1, 1, 4);
			Attack_Speed += (Attack_Index * .2);
			Attack_Name = "Attack" .. Attack_Index;
		end


		--// Play the swing animation.
		self:SetProperty("Attacking", true);
		self.Attack_Name = Attack_Name;
		self.Attack_Animation = self:GetAnimation(Attack_Name);
		self:SetProperty("AttackIndex", Attack_Index);
		self:PlayAnimation(Attack_Name);
		self:AdjustAnimSpeed(Attack_Name, self["Attack_Speed"]);
		
		
		--local Direction = self.HRP.CFrame.LookVector * (self:AreDirectionalKeysDown() and 25 or 35);
		--Global.Tween(self.HRP, TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = Direction});
		
		self:ToggleHitbox(false):andThen(function()
			self:ToggleHitbox(true);
		end)
		
		self:Replicate({
			Task = "Attack";
			Is_Attacking = true;
			Attack_Name = Attack_Name;
			Attack_Index = Attack_Index;
		})

		self:ConsumeStamina(self["Stamina_Consumption"]["Attack"]);
		self:SetStaminaRegenDelay(3);
		
		--// After the animation has finished, record the end time. (So the next swing can calculate if a combo is taking place.)
		task.delay(self.Attack_Animation.Track.Length + self["Attack_Delay"], function()
			self:Attack(false)
		end)
		
	else
		
		self:ToggleHitbox(false);
		
		self:SetProperty("Attacking", false);
		self["Last_Attack"] = os.clock();

		self:Replicate({
			Task = "Attack";
			Is_Attacking = false;
		})
		
	end
end;

function Lightsaber:HeavyAttack(Is_Attacking : boolean) --// Conducts a heavy attack, if possible.
	if Is_Attacking then

		if self:GetProperty("Attacking") then return end; --// Prevent attacking when they are already mid attack.
		if not self:GetProperty("Ignited") then return end; --// Prevent attacking when the saber isnt even ignited.
		if not self:GetProperty("Equipped") then return end; --// Prevent attacking when the saber isnt even equipped.
		if self:GetProperty("Stunned") then return end; --// Prevent attacking when stunned.

		if not self:HasEnoughStamina(self["Stamina_Consumption"]["Heavy_Attack"]) then return end --// If they dont have enough stamina to swing, then prevent it.


		--// Play the swing animation.
		self:SetProperty("Attacking", true);
		self.Attack_Name = "Heavy";
		self.Attack_Animation = self:GetAnimation(self.Attack_Name);
		self:PlayAnimation(self.Attack_Name);
		self:AdjustAnimSpeed(self.Attack_Name, self["Attack_Speed"]);


		local Direction = self.HRP.CFrame.LookVector * (self:AreDirectionalKeysDown() and 25 or 35);
		Global.Tween(self.HRP, TweenInfo.new(.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Velocity = Direction});

		self:ToggleHitbox(false):andThen(function()
			self:ToggleHitbox(true);
		end)
		

		self:Replicate({
			Task = "Attack";
			Is_Attacking = true;
			Attack_Name = self.Attack_Name;
			Is_Heavy_Attack = true;
		})

		self:ConsumeStamina(self["Stamina_Consumption"]["Heavy_Attack"]);
		self:SetStaminaRegenDelay(5);

		--// After the animation has finished, record the end time. (So the next swing can calculate if a combo is taking place.)
		task.delay(self.Attack_Animation.Track.Length + self["Attack_Delay"], function()
			self:Attack(false)
		end)

	else

		self:ToggleHitbox(false);

		self:SetProperty("Attacking", false);
		self["Last_Attack"] = os.clock();

		self:Replicate({
			Task = "Attack";
			Is_Attacking = false;
		})

	end
end;

function Lightsaber:Parry(Is_Parrying : boolean, Is_Temporary : boolean) --// Initiates a parry to an incoming attack.
	return Promise.new(function(resolve, reject)
		if Is_Parrying then
			if self:GetProperty("Parrying") then resolve(false) return end;
			if self:GetProperty("Attacking") then resolve(false) return end;
			if self:GetProperty("Stunned") then resolve(false) return end;
			if (os.clock() - self["Last_Parry"]) <= self["Parry_Delay"] then resolve(false) return end;

			print("Parrying")
			
			self:SetProperty("Parry", true);
			self:SetStatus("Parry");
			self["Last_Parry"] = os.clock();


			self:Replicate({
				Task = "Parry";
				Is_Parrying = true;
			});

			task.delay(self["Parry_Window"], function()
				self:Parry(false)
			end)

			resolve(true)
		else
			print("Stopped Parrying")
			self:SetProperty("Parry", false);
			if self:GetProperty("Blocking") then
				self:SetStatus("Block");
			else
				self:SetStatus("None");
			end

			self:Replicate({
				Task = "Parry";
				Is_Parrying = false;
			});

			resolve(true);
		end
	end)
end;

function Lightsaber:Block(Is_Blocking : boolean) --// Conducts a block, if possible.
	if not self:GetProperty("Ignited") then return end; --// Prevent blocking when the saber isnt even ignited.
	if not self:GetProperty("Equipped") then return end --// Prevent blocking when the saber isnt even equipped.
	
	if Is_Blocking then
		if self:GetProperty("Attacking") then return end; --// Prevent blocking while mid attack.
		if self:GetProperty("Stunned") then return end; --// Prevent blocking while stunned
		if self.Character_Class.Is_Sprinting then return end; --// Prevent blocking while sprinting
		if self.Character:GetAttribute("Ragdolled") then return end; --// Prevent blocking while ragdolled
	end;
	
	
	self:SetProperty("Blocking", Is_Blocking);
	
	if Is_Blocking then
		self:StopAnimation("All");
		self:PlayAnimation("Block");
		
		self:Parry(true):andThen(function(Has_Parried)
			if not Has_Parried then
				self:SetStatus("Block");
			end
		end);
		
		self:Replicate({
			Task = "Block";
			Is_Blocking = true;
		});
	else
		self:StopAnimation("Block");
		self:SetStatus("None");
		self:Parry(false)
		
		if self:GetProperty("Equipped") and not self.Character_Class.Is_Sprinting then
			self:PlayAnimation("Idle");
		end
		
		self:Replicate({
			Task = "Block";
			Is_Blocking = false;
		});
		
	end
end;

function Lightsaber:Blocked() --// Cue recieved from the server, if recieved it'll consume the appropriate amount of stamina if a successful block took place.
	self:ConsumeStamina(Lightsaber["Stamina_Consumption"]["Block"]);
	self:SetStaminaRegenDelay(3);
end;

function Lightsaber:Ignite(Is_Ignited : boolean) --// Attempts to ignite or extinguish the lightsaber.
	if self:GetProperty("ChangingState") then return end
	
	local Projected_Value = (Is_Ignited ~= nil and Is_Ignited or not self:GetProperty("Ignited"))
	if Projected_Value == true and not self:GetProperty("Equipped") then return end
	
	
	self:SetProperty("Ignited", (Is_Ignited ~= nil and Is_Ignited or not self:GetProperty("Ignited")))
	
	
	if self:GetProperty("Ignited") then

		--// Debounce.
		self:SetProperty("ChangingState", true);
		task.delay(.5, function()
			self:SetProperty("ChangingState", false);
			self:Parry(true);
		end);


		self:SetProperty("Ignited", true);
		self:SetProperty("AttackIndex", 1);
		self:Replicate({
			Task = "Ignite";
			Is_Ignited = true;
		})

		self:PlayAnimation("Idle");

	else

		--// Debounce.
		self:SetProperty("ChangingState", true);
		task.delay(.5, function()
			self:SetProperty("ChangingState", false);
		end)


		self:SetProperty("Ignited", false);
		self:SetProperty("AttackIndex", 1);
		self:Replicate({
			Task = "Ignite";
			Is_Ignited = false;
		})

		self:StopAnimation("All");
		self:ToggleAimAssist(false);
	end
end;

function Lightsaber:Equip() --// Runs when the tool is equipped.
	--// Set it's equipped value to false.
	self:SetProperty("Equipped", true);
	self.UI.Parent = Player.PlayerGui;
	
	--// Stop all Animations.
	self:StopAnimation("All");
	self:PlayAnimation("Equip");
	

	
	--// Fire the server to equip it.
	self:Replicate({
		Task = "Equip";
		Is_Equipped = true;
	})
end;

function Lightsaber:Unequip() --// Runs when the tool is unequipped.
	
	if self:GetProperty("Attacking") then
		self:Attack(false);
	end;
	
	if self:GetProperty("Blocking") then
		self:Block(false);
	end;
	
	if self:GetProperty("Ignited") then
		self:Ignite(false);
		task.wait(1)
	end;
	
	--// Set it's equipped value to false.
	self:SetProperty("Equipped", false);
	self.UI.Parent = nil;
	
	--// Stop all Animations.
	self:StopAnimation("All");
	self:PlayAnimation("Unequip");

	--// Extinguish the lightsaber if it's ignited.
	if self:GetProperty("Ignited") then
		self:SetProperty("Ignited", false)
		self:Replicate({
			Task = "Ignited";
			Enabled = false;
		})
	end
	
	self:ToggleAimAssist(false);
	
	--// Fire the server to unequip it.
	self:Replicate({
		Task = "Equip";
		Is_Equipped = false;
	})
end;

function Lightsaber:ToggleAimAssist(Is_Assisting : boolean) --// Toggles the aim assist camera.
	self.LockOn_Controller:Toggle(Is_Assisting)
	self["Aim_Assist_Enabled"] = (Is_Assisting ~= nil and Is_Assisting or self.LockOn_Controller.Enabled)
end



--// USER INPUT: The functions that handle changes in user input.
function Lightsaber:InputStarted(Input : InputObject)

	
	--// Ignition
	if Input.KeyCode == Enum.KeyCode.Q then
		self:Ignite()
	end;
	
	
	--// Change Forms
	if Input.KeyCode == Enum.KeyCode.R and self["Can_Switch_Forms"] then
		self:ChangeForms();
	end;
	
	
	if Input.KeyCode == Enum.KeyCode.F and self["Heavy_Attacks_Enabled"] then
		self:HeavyAttack(true);
	end;
	
	
	if Input.KeyCode == Enum.KeyCode.V and self:GetProperty("Ignited") then
		self:ToggleAimAssist()
	end
	
	--// Attacking
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		self:Attack(true);
	end;
	
	
	--// Blocking & Parrying
	if Input.UserInputType == Enum.UserInputType.MouseButton2 and not self.Test_Lock_Enabled then
		self:Block(true);
	end;
end;

function Lightsaber:InputEnded(Input : InputObject)
	
	
	--// Stop Blocking & Parrying
	if Input.UserInputType == Enum.UserInputType.MouseButton2 and not self.Test_Lock_Enabled then
		self:Block(false);
	end;
end;


function Lightsaber:ToggleHitbox(Is_Enabled : boolean) --// Toggles the hitbox's activation on and off.
	return Promise.new(function(resolve, reject)
		for _, Hitbox in pairs(self.Hitboxes) do
			if Is_Enabled then
				Hitbox:HitStart()
				--Hitbox:ViewRays(true)
			else
				Hitbox:HitStop()
				Hitbox:ViewRays(false)
			end
		end
		resolve()
	end)
end;

function Lightsaber:CreateHitboxes() --// Creates hitboxes using the lightsaber models as the reference.
	self.Hitboxes = {};
	
	for _, Lightsaber_Table in pairs(self.Lightsabers) do
		local Hitbox = RayHitbox:Initialize(Lightsaber_Table.Model, {
			IgnoreList = {workspace.Terrain, Player.Character};
			AutoStopDetection = false;
		})

		Hitbox.OnHit:Connect(function(Hit_Properties)
			Hit_Properties.Task = "ProcessDamage";
			self:Replicate(Hit_Properties);
			
			if Hit_Properties.Entity then
				Hitbox:HitStop()
			end
		end)
		
		table.insert(self.Hitboxes, Hitbox);
	end;
end;




--// GET CONNECTIONS: Gets all of the events (connections) that the lightsaber needs to operate.
function Lightsaber:ProcessEvent(Properties : any)
	if Properties.Task == "Stunned" then
		self:Stun()
	elseif Properties.Task == "Blocked" then
		self:Blocked()
	elseif Properties.Task == "ConsumeStamina" then
		self:ConsumeStamina(self["Stamina_Consumption"][Properties.Type or "Attack"])
	end
end;

function Lightsaber:LoadConnections() --// Loads any and all connections needed to make this class object work.
	
	self.PropertyChanged = self:Connect(GoodSignal.new(), "DisconnectAll", "Property_Changed");
	self.PropertyChanged:Connect(function(Property : any, NewValue : any)

	end);
	
	--// Input Began Connection
	self:Connect(UserInputService.InputBegan:Connect(function(Input, GPE)
		if GPE then return end
		self:InputStarted(Input)
	end), "Disconnect", "Input_Began");
	
	--// Input Began Connection
	self:Connect(UserInputService.InputEnded:Connect(function(Input, GPE)
		if GPE then return end
		self:InputEnded(Input)
	end), "Disconnect", "Input_Ended");
	
	
	self:Connect(self.Humanoid.Died:Connect(function()
		self:ToggleAimAssist(false)
	end));
	
	self:Connect(Player.CharacterRemoving:Connect(function()
		self:ToggleAimAssist(false)
	end));


	self.LockOn_Controller.LockedOn:Connect(function(Is_Locked_On : boolean, Target : Model)
		if Is_Locked_On and Target then
			self.UI.Target.Title.Text = Target.Name;
			self.UI.Target.Visible = true;
			self:Connect(Target.Humanoid:GetPropertyChangedSignal("Health"):Connect(function()
				local Current_Health = (Target.Humanoid.Health / Target.Humanoid.MaxHealth);
				Global.Tween(self.UI.Target.Health.Bar, TweenInfo.new(.05, Enum.EasingStyle.Cubic), {Size = UDim2.fromScale(Current_Health, 1)});
				Global.Tween(self.UI.Target.Health.Change, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.fromScale(Current_Health, 1)});
			end), "Disconnect", "Target_Health_Tracking")
		else
			self.UI.Target.Visible = false;
			self.UI.Target.Title.Text = "";
			self.UI.Target.Health.Bar.Size = UDim2.fromScale(1, 1);
			self.UI.Target.Health.Change.Size = UDim2.fromScale(1, 1);
			self:Disconnect("Target_Health_Tracking");
		end
	end);
	
	
	self:Connect(self.Tool.Equipped:Connect(function()
		self:Equip()
	end), "Disconnect", "Tool_Equipped");
	
	self:Connect(self.Tool.Unequipped:Connect(function()
		self:Unequip()
	end), "Disconnect", "Tool_Unequipped");
	
	
	Lightsaber_Service.Event:Connect(function(Properties)
		if Properties.Tool ~= self.Tool then return end
		self:ProcessEvent(Properties);
	end);
	
	self.PropertyChanged:Connect(function(Property : any, NewValue : any)

	end);
	
	self.Character_Class.Sprinting:Connect(function(Is_Sprinting)
		if not self:GetProperty("Equipped") or not self:GetProperty("Ignited") then return end
		
		if Is_Sprinting then
			--// If they were blocking, stop the block
			if self:GetProperty("Blocking") then
				self:Block(false)
			end
			
			self:StopAnimation("Idle")
		else
			self:PlayAnimation("Idle")
		end
	end)
end;

--// DetermineDeviceType : Determines what kind of device the player is using the lightsabers on.
function Lightsaber:DetermineDeviceType()
	if UserInputService.TouchEnabled then
		self.DeviceType = "Mobile"
	elseif UserInputService.GamepadEnabled then
		self.DeviceType = "Console"
	elseif UserInputService.KeyboardEnabled then
		self.DeviceType = "Desktop"
	end
end;



function Lightsaber:Destroy() --// Destroys the class object.
	return Promise.new(function(resolve, reject)
		self:Disconnect() -- Garbage collects all the connections
		self = nil
		
		--// Resolve the promise so the game knows this one was successfully deleted.
		resolve()
	end)
end;

function Lightsaber.new(Lightsaber_Tool : Tool, Options : any) --// Creates a new Tool Class Object.
	return Promise.new(function(resolve, reject)
		if not Lightsaber_Index:GetInfo(Lightsaber_Tool.Name) then
			warn(Lightsaber_Tool.Name, "Is not properly configured in the Lightsaber Database Module.")
			reject()
			return
		end
		
		local self = setmetatable({}, Lightsaber);
		
		repeat RunService.Heartbeat:Wait() until Character:Get()

		--// INSTANCES
		self["Tool"] = Lightsaber_Tool;
		self["Character"] = Player.Character;
		self["Humanoid"] = (self.Character:FindFirstChildOfClass("Humanoid"));
		self["HRP"] = self.Character:FindFirstChild("HumanoidRootPart");
		self["Animator"] = self.Character:FindFirstChild("Animator", true);
		self["Character_Class"] = Character:Get();
		
		
		--// TABLES
		self["Lightsabers"] = {};
		self["Models"] = {};
		self["Properties"] = Lightsaber_Index:GetInfo(Lightsaber_Tool.Name);
		self["Lightsaber_Type"] = (self.Properties["Type"] or self:GetProperty("Type"));
		self["Stamina_Consumption"] = self.Properties["Lightsaber_Consumption"] or Lightsaber_Index["Default_Stamina_Consumption"];
		
		--// VALUES
		
		self["Current_Form"] = (self.Properties["Default_Form"] or self:GetProperty("Form"));
		self["Can_Switch_Forms"] = self.Properties["Form_Switching_Enabled"] ~= nil and self.Properties["Form_Switching_Enabled"] or true;
		self["Last_Form_Change"] = os.clock();
		self["Form_Change_Cooldown"] = 1;
		
		
		self["Last_Parry"] = os.clock();
		self["Parry_Delay"] = self.Properties["Parry_Delay"] or 3;
		self["Parry_Window"] = self.Properties["Parry_Window"] or .75;
		

		self["Last_Attack"] = os.clock();
		self["Attack_Delay"] = self.Properties["Attack_Delay"] or -.1;
		self["Attack_Speed"] = self.Properties["Attack_Speed"] or 1;
		self["Heavy_Attacks_Enabled"] = self.Properties["Heavy_Attacks_Enabled"] or false;
		self["Attack_Combo_Window"] = .5;
		self["Current_Attack"] = 1;
		
		
		--// INTERFACE
		self["UI"] = Client_Dependents.UI.Lightsaber_UI:Clone();
		self.UI.Form.Text = self["Current_Form"];
		self.UI.Parent = nil;
		
		
		--// LOCK ON 
		self.LockOn_Controller = LockOn.new({
			SoftLockStrength = 0.15, --// How strong the soft lock on attempts to move the camera.
		})
		
		
		--// LOADER FUNCTIONS
		--self:DetermineForm();
		self:DetermineDeviceType();
		self:LoadAnimations(Animations_Folder[self.Lightsaber_Type][self.Current_Form]);
		self:LoadConnections();
		
		
		--// Tell the server to set up the lightsaber as well.
		Lightsaber_Service:Fire({
			Task = "Initialize";
			Tool = self.Tool;
		}):andThen(function(Lightsabers)
			self["Lightsabers"] = Lightsabers;
			self:CreateHitboxes();
		end);
		
		resolve(self)
	end)
end;


return Lightsaber
