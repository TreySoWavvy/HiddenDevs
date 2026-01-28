--// NAME: CORPSES
--// CLASS: SERVICE
--// TIMESTAMP: 31 JULY 2025
--// DESCRIPTOR: HANDLES THE CREATION AND MANAGEMENT OF PSUEDO CORPSES / DEAD BODIES
----

--// FRAMEWORK
local Client_Dependents = game.ReplicatedStorage["Client/Dependents"];
local Server_Dependents = game.ServerStorage["Server/Dependents"];
local Framework = require(Client_Dependents.Framework.FrameworkCore);

local System = Framework.CreateService{
	Name = "Corpses";
	Client = {};
}


--// SERVICES
local RS = game:GetService("RunService");
local CS = game:GetService("CollectionService");
local Physics = game:GetService("PhysicsService");

local Global;
local Administration;
local UIService;
local DataService;

--// MODULES
local Library = require(Framework.Modules.Library);
local Debris = require(Framework.Modules.Debris);
local Janitor = require(Framework.Modules.Janitor);
local GoodSignal = require(Framework.Modules.GoodSignal);
local Promise = require(Framework.Modules.Promise);
local Format = require(Framework.Modules.Format);
local Date = require(Framework.Modules.Date);


--// GLOBAL VARIABLES


--// SYSTEM VARIABLES
System["Prefix"] = string.format("%s »", string.upper(script.Name));

System["Auto_Clear_Corpses"] = true;

System["Clear_Previous_Body"] = false;


System["Lifespan"] = 120;


System["List"] = {};

System["Trash_Instances"] = {
	["AnimSaves"] = true;
	["LocalScript"] = true;
	["Script"] = true;
	["Sound"] = true;
	["Motor6D"] = true;
	["BillboardGui"] = true;
	["HumanoidRootPart"] = true;
};


--// CORPSE CLASS
local Corpse = {};
Corpse["__index"] = Corpse;


--// METHODS
function Corpse:Connect(Task : any, MethodOfCleanup : string, TaskName : string)
	if not self.__janitor then
		self.__janitor = Janitor.new()
	end
	return self.__janitor:Add(Task, MethodOfCleanup, TaskName)
end;

function Corpse:Disconnect(TaskName : string)
	if self.__janitor then
		if TaskName then
			self.__janitor:Remove(TaskName)
		else
			self.__janitor:Destroy()
			self.__janitor = nil
		end
	end
end;

function Corpse:SetProperty(Name, Value)
	self.Properties[Name] = Value
end;

function Corpse:GetProperty(Name)
	return self.Properties[Name]
end;

function Corpse:FormatBody()
	return Promise.new(function(resolve, reject)
		
		-- Configure the corpse to mimic a corpse, Disable Humanoid States, remove excess items, etc.
		self.Model.Name = (System["Enable_Anonymous_Bodies"] and "Unknown Individual" or string.format("%s's Model", self.Name))
		self.Model.PrimaryPart = self.Model:FindFirstChild("Torso")
		--Model.PrimaryPart.Anchored = true
		self.Model.Archivable = false
		self.Model.Parent = nil
		task.delay(game.Players.RespawnTime + 0.1, function()
			self.Model.Parent = System.Folder
		end)

		-- Attach some information.
		CS:RemoveTag(self.Model, "Human")
		CS:AddTag(self.Model, "Corpse")


		-- Disable humanoid states to make the Corpse not do any excess calculations.
		pcall(function()
			if self.Humanoid then
				self.Humanoid.DisplayDistanceType = "None"
				self.Humanoid.HealthDisplayType = "AlwaysOff"
				self.Humanoid.Health = 0
				self.Humanoid.AutoRotate = false
				self.Humanoid.PlatformStand = true
				self.Humanoid.AutoJumpEnabled = false

				for _,Track in pairs(self.Humanoid:GetPlayingAnimationTracks()) do
					Track:Stop()
					Track:Destroy()
				end

				for _,State in pairs(Enum.HumanoidStateType:GetEnumItems()) do
					if State ~= Enum.HumanoidStateType.Ragdoll then
						self.Humanoid:SetStateEnabled(State, false)
					end
				end
				self.Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
				Debris(self.Humanoid)
			end
		end)

		self.Prompt = Server_Dependents.Models.WorldPrompt:Clone()
		self.Prompt.MaxActivationDistance = 8
		self.Prompt.Parent = self.Model.PrimaryPart
		self.Prompt:SetAttribute("PromptName", "Corpse")
		self:Connect(self.Model)

		local BodyInstances = self.Model:GetDescendants()
		for i = 1, #BodyInstances do
			local Inst = BodyInstances[i]
			if System["Trash_Instances"][Inst.ClassName] or  System["Trash_Instances"][Inst.Name] then
				Debris(Inst)
			end

			if Inst.Parent == self.Model and (Inst:IsA("BasePart") or Inst:IsA("MeshPart")) then
				Inst.CollisionGroup = "Corpse"
				Inst.Anchored = false
				Inst.CanCollide = true
				Inst.BottomSurface = Enum.SurfaceType.Smooth
				Inst.TopSurface = Enum.SurfaceType.Smooth
			elseif Inst.Parent.ClassName == "Accessory" then
				Inst.CanCollide = false
			end
		end
		
		resolve()
	end)
end;

function Corpse.new(Player : Player, Properties)
	return Promise.new(function(resolve, reject)
		local Success, Result = pcall(function()
			local self = setmetatable({}, Corpse)
			local Character = Player.Character
			Character.Archivable = true

			self.Player = Player;
			self.Model = Character:Clone();
			self.Humanoid = self.Model:FindFirstChildOfClass("Humanoid");
			self.HRP = self.Model:FindFirstChild("HumanoidRootPart");

			self.SpawnTime = os.clock();
			self.Timestamp = Date:ToLocal();
			self.Status = "Deceased";

			self.StatusChanged = self:Connect(GoodSignal.new(), "DisconnectAll", "StatusChanged_Signal");
			
			self:FormatBody():await()
			
			return self
		end)
		
		if Result then
			resolve(Result)
		else
			reject(Result)
		end
	end)
end;



function System:GetRecent(Player : Player)
	if self.List[Player] then
		return self.List[Player][1]
	end
end;

function System:Get(Identifier : any)
	for Player, Corpses in pairs(self.List) do
		for Slot, Corpse in pairs(Corpses) do
			if Corpse.Model == Identifier or Identifier:IsDescendantOf(Corpse.Model) then
				return Corpse
			end
		end
	end
end;

function System:Clear(Player : Player)
	local Count = 0
	
	for User, List in pairs(self.List) do
		for _, Corpse in pairs(List) do
			Corpse:Destroy()
			Count += 1
		end
	end
	
	for _, Model in pairs(CS:GetTagged("Corpse")) do
		Debris(Model)
		Count += 1
	end
	
	if Player then
		UIService:SendUIPrompt(Player, "Narration", {
			Message = string.format("You have cleared %s corpses from the world.", tostring(Count))
		})
	end
end;

function System:Create(Player : Player, Properties : any)
	--// If they have another corpse somewhere in the world, clear the previous one before creating a new one.
	local Previous_Corpse = System:Get(Player)
	if Previous_Corpse and System["Clear_Previous_Body"] then
		Previous_Corpse:Destroy()
	end
	
	Corpse.new(Player, Properties):andThen(function(New_Corpse)
		if not self.List[Player] then
			self.List[Player] = {}
		end
		
		table.insert(self.List[Player], New_Corpse)
		self.Added:Fire(Player, New_Corpse)
	end):catch(function(err)
		warn(self.Prefix, "Issue creating corpse for", Player.Name, ":", err)
	end)

end;



--// FRAMEWORK
function System:FrameworkStart()
	Global = Framework.GetService("Global");
	DataService = Framework.GetService("Data");
	UIService = Framework.GetService("UI");
	
	if Global.IsLobby() then return end
	
	
	self.Added = GoodSignal.new();
	self.Removed = GoodSignal.new();
	
	
	self.Folder = workspace:FindFirstChild("Corpses", true)
	if not self.Folder then
		self.Folder = Instance.new("Folder")
		self.Folder.Name = "Corpses"
		self.Folder.Parent = workspace:FindFirstChild("Interactive") or workspace
	end
	
	if self["Auto_Clear_Corpses"] then
		RS.Heartbeat:Connect(function()
			for _, Corpse in next, self.List do
				if Corpse.SpawnTime and (os.clock() - Corpse.SpawnTime >= self.Lifespan) then
					Corpse:Destroy()
				end
			end
		end)
	end
	
	print(self.Prefix, "Are Live.")
end;

return System
