--// NAME: MORPH SERVICE
--// CLASS: SERVICE
--// TIMESTAMP: 2 JAN 2026
--// DESCRIPTOR: HANDLES MORPHS ON PLAYER CHARACTERS;
----


--// FRAMEWORK
local Client_Dependents = game.ReplicatedStorage["Client/Dependents"];
local Server_Dependents = game.ServerStorage["Server/Dependents"];
local Framework = require(Client_Dependents.Framework.FrameworkCore);

local System = Framework.CreateService{
	Name = "Morphs";
	Client = {};
}


--// SERVICES
local Global;
local UIService;
local DataService;
local RenderService;


--// MODULES
local Library = require(Framework.Modules.Library);
local Debris = require(Framework.Modules.Debris);
local GoodSignal = require(Framework.Modules.GoodSignal);
local Janitor = require(Framework.Modules.Janitor);
local Format = require(Framework.Modules.Format);
local TS = require(Framework.Modules.Tween);
local Animation = require(Framework.Modules.Animation);
local Promise = require(Framework.Modules.Promise);

local Morph_Library = require(Framework.Information.Morphs);

--// VARIABLES
System["Enabled"] = true;

System["Prefix"] = string.format("%s »", string.upper(script.Name));




--| SYSTEM SETTINGS
System["Whitelisted_Head_Accessories"] = { --// Any accessories with these two attachments will be permitted to stay.
	["FaceFrontAttachment"] = true;
	["HairAttachment"] = true;
};

System["Body_Parts"] = {
	["R6"] = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"};
	
	["R15"] = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"};
}

--| SYSTEM METHODS



function System:GetUserAppearance(Player : Player)
	
end;

function System:ToggleHeadAccessories(Rig : Model, Is_Visible : boolean) --// Toggles the transparency of head accessories. Good for a helmet system.
	for _, Accessory in pairs(Rig:GetChildren()) do
		if Accessory.ClassName == "Accessory" then
			local Attachment = Accessory.Handle:FindFirstChildOfClass("Attachment")
			local IsHeadAccessory = (Attachment and self.HeadAttachmentList[Attachment.Name])
			if IsHeadAccessory then
				Attachment.Parent.Transparency = (Is_Visible and 0 or 1)

				for _, Texture in pairs(Attachment.Parent:GetChildren()) do
					if Texture.ClassName == 'Texture' then
						Texture.Transparency = (Is_Visible and .5 or 1)
					end
				end
			end
		end
	end
end;


function System:ToggleBodyPart(Rig : Model, Body_Part_Name : string, Is_Visible : boolean) --// Toggles the transparency of specific body parts. For morphs with certain exposed parts.
	local Body_Part = (Rig and Rig:FindFirstChild(Body_Part_Name))
	if Body_Part then
		Body_Part.Transparency = (Is_Visible and 0 or 1)
	end
end;

function System:ToggleBodyParts(Rig : Model, Is_Visible : boolean) --// Toggles the transparency of all body parts. Good for post morph cleanup.
	local Humanoid = Rig:FindFirstChild("Humanoid");
	local Rig_Type = (Humanoid and Humanoid.RigType);
	
	if Rig_Type and self["Body_Parts"][Rig_Type] then
		for _, Body_Part in pairs(self["Body_Parts"][Rig_Type]) do
			local Model = Rig:FindFirstChild(Body_Part)
			if Model then
				Model.Transparency = (Is_Visible and 0 or 1)
			end
		end
	end
end;

----


----------------------------------------------------
-- CLEAR ACCESSORIES METHOD
----------------------------------------------------
-- Options:
-- Allow_Facial_Features = true/false  (Whether to keep certain head accessories.)

function System:ClearAccessories(Rig : Model, Options : any)
	Options = Options or {};

	for _, Accessory in pairs(Rig:GetChildren()) do
		if Accessory.ClassName == "Accessory" then
			local Attachment = Accessory.Handle:FindFirstChildOfClass("Attachment");
			local IsWhitelisted = (Attachment and self["Whitelisted_Head_Accessories"][Attachment.Name]);

			if (not Options["Allow_Facial_Features"]) or (Options["Allow_Facial_Features"] and not IsWhitelisted) then
				Debris(Accessory)
			end
		end
	end
end;


----------------------------------------------------
-- FIND MORPH METHOD
-- Returns if the morph exists or not, if Get_Copy is provided, it returns a clone of it.
----------------------------------------------------

function System:Find(Morph_Model_Name : string, Get_Copy : boolean)
	local Morph_Model = Client_Dependents:FindFirstChild("Clothing") and Client_Dependents.Clothing:FindFirstChild(Morph_Model_Name, true);

	if Morph_Model then
		print("Found", Morph_Model_Name)
		return (Get_Copy and Morph_Model:Clone() or Morph_Model)
	else
		return
	end
end;


----------------------------------------------------
-- CLEAR MORPH METHOD
-- Clears a morph from a player and reconstructs their character.
----------------------------------------------------

function System:Clear(Rig : Model) --// Clears a Morph from a specific Rig.
	return Promise.new(function(resolve, reject)
		local Morph_Folder = Rig:FindFirstChild("Morph");
		
		--// Delete the morph folder
		if Morph_Folder then
			Debris(Morph_Folder)
		end


		--// Toggle any leftover accessories and make all the body parts visible again.
		self:ToggleHeadAccessories(Rig, true);
		self:ToggleBodyParts(Rig, true);
		
		resolve()
	end)
end


----------------------------------------------------
-- CREATE MORPH METHOD
-- Gives a morph to a player, a table of Options can be provided.
----------------------------------------------------
function System:Get(Rig : Model, Morph_Name : string, Options : any)
	return Promise.new(function(resolve, reject)
		local Player = game.Players:GetPlayerFromCharacter(Rig);
		
		Options = Options or {};
		
		--// First, we check to see if the character is eligible for a morph.
		print(Rig.Name, Morph_Name, Options)
		assert(Morph_Name, "A Morph name must be provided.");
		assert(Rig, "A Humanoid-Based Rig must be provided.");
		assert(Morph_Library:GetInfo(Morph_Name), Morph_Name .. " was not properly added to the Morph Library ModuleScript!")
		
		
		--// If the character is attached to a player, lets check to make sure they are eligible to use that morph.
		if Player then
			local Can_Use_Morph = Morph_Library:CanUseMorph(Player, Morph_Name);
			local Is_Developer = Global.IsDeveloper(Player);
			local Override_Enabled = (Options.Override);
			
			if (not Can_Use_Morph and not Override_Enabled and not Is_Developer) then
				return
			end
		end
		
		
		--// Get all the necessary instances.
		local Humanoid = Rig:FindFirstChild("Humanoid");
		local Head = Rig:FindFirstChild("Head");
		local Shirt = Rig:FindFirstChild("Shirt");
		local Pants = Rig:FindFirstChild("Pants");
		assert(Humanoid.Health > 0, "The Rig must be alive to properly add the morph.");
		
		
		--// Check to make sure the morph we are trying to get even exists.
		local Current_Morph_Model = Rig:FindFirstChild("Morph");
		local New_Morph_Model = self:Find(Morph_Name, true);
		assert(New_Morph_Model, string.format("' %s ' was not found in the morph folder.", Morph_Name));
		
		
		local Morph_Info = Morph_Library:GetInfo(Morph_Name);
		local Morph_Shirt = (New_Morph_Model and New_Morph_Model:FindFirstChild("Shirt"));
		local Morph_Pants = (New_Morph_Model and New_Morph_Model:FindFirstChild("Pants"));
		local Allow_Facial_Features = (Options.Allow_Facial_Features or Morph_Info.Allow_Facial_Features)
		
		self:ToggleBodyParts(Rig, true);
		
		--print(Rig.Name, Morph_Name, Options)
		--// Clear an old morph if one exists.
		if Current_Morph_Model then
			self:Clear(Rig):await()
		end

		
		--// If the morph has shirt & pants attached to it, replace the current ones the rig has.
		if Shirt and Morph_Shirt then
			Morph_Shirt.Parent = Rig;
			Debris(Shirt)
		end;

		if Pants and Morph_Pants then
			Morph_Pants.Parent = Rig;
			Debris(Pants)
		end


		--// Create a new clean, folder for the Morph Parts to go into.
		local Folder = Instance.new("Folder");
		Folder.Name = "Morph";
		Folder.Parent = game.ServerStorage;


		--// Toggle body part visibility
		if Morph_Info.Hidden_Body_Parts and #Morph_Info.Hidden_Body_Parts > 0 then
			for _, Body_Part in Morph_Info.Hidden_Body_Parts do
				self:ToggleBodyPart(Rig, Body_Part, false)
			end
		else
			self:ToggleBodyParts(Rig, true);
		end

		
		--// Begin attaching the morph to the matching body parts.
		for _, Sub_Model in pairs(New_Morph_Model:GetChildren()) do
			local Body_Part = Rig:FindFirstChild(Sub_Model.Name);
			
			if Body_Part and Sub_Model.ClassName == "MeshPart" then
				
				local Model = Instance.new("Model");
				
				Sub_Model.Name = "Base";
				Sub_Model.Anchored = true;
				Sub_Model.CanCollide = false;
				Sub_Model.Massless = true;
				Sub_Model.Transparency = 1;
				Sub_Model.PivotOffset = CFrame.new();
				Sub_Model.Parent = Model;
				
				Model.Name = Body_Part.Name;
				Model.Parent = Folder;
				Model.PrimaryPart = Sub_Model;
				
				--// Clear any excess instances, and weld any descendant parts to the main one.
				for _, Child in pairs(Sub_Model:GetDescendants()) do
					if Child.ClassName == "Weld" or Child.ClassName == "Motor6D" or (Child.ClassName == "WeldConstraint" and Child.Name ~= "Morph_Weld") or Child.ClassName == "Attachment" then
						Debris(Child)
					end
				end;
				
				for _, Child in pairs(Sub_Model:GetDescendants()) do
					if Child.ClassName == "Part" or Child.ClassName == "MeshPart" or Child.ClassName == "UnionOperation" then
						Child.Anchored = true;
						
						local Motor = Instance.new("Weld");
						Motor.Part0 = Sub_Model;
						Motor.Part1 = Child;
						Motor.Name = "Morph_Weld"
						local CJ = CFrame.new(Motor.Part0.Position);
						local C0 = Motor.Part0.CFrame:inverse()*CJ;
						local C1 = Child.CFrame:inverse()*CJ;
						Motor.C0 = C0;
						Motor.C1 = C1;
						Motor.Parent = Motor.Part1;
						
						
						--local Weld = Instance.new("WeldConstraint");
						--Weld.Name = "Morph_Weld"
						--Weld.Part0 = Sub_Model;
						--Weld.Part1 = Child;
						--Weld.Parent = Child;
						
						Child.Anchored = false;
						Child.CanCollide = false;
						Child.Massless = true;
						Child.PivotOffset = CFrame.new();
						Child.Parent = Model;
					end
				end
				
				
				if Options.Rescale_Factor then
					Sub_Model.Size = Sub_Model.Size * Options.Rescale_Factor
				end
				
				
				Model.PrimaryPart.PivotOffset = CFrame.new();
				Model:PivotTo(Body_Part.CFrame);
				
				local Weld = Instance.new("Weld");
				Weld.Name = "Morph_Weld";
				Weld.Part0 = Body_Part;
				Weld.Part1 = Model.PrimaryPart;
				Weld.C0 = CFrame.new();
				Weld.Parent = Model.PrimaryPart;
				
				Sub_Model.Anchored = false;
			end;
			
		end;
		
		task.wait()
		
		--// Parent the morph folder to that character, and clear any unecessary accessories for uniformity.
		Folder.Parent = Rig;
		self:ClearAccessories(Rig, {
			Allow_Facial_Features = Allow_Facial_Features;
		})
		
		Debris(New_Morph_Model);
		warn(self.Prefix, string.format("The %s Morph has been given to %s.", Morph_Name, Rig.Name))

		resolve(Folder)
	end)
end

function System.Client:Get(Player : Player, Morph_Name : string, Options : any)
	return self.Server:Get(Player.Character, Morph_Name, Options)
end;


--// FRAMEWORK MANAGEMENT
function System:FrameworkStart()
	Global = Framework.GetService("Global");
	UIService = Framework.GetService("UI");
	DataService = Framework.GetService("Data");
	RenderService = Framework.GetService("Rendering");


end;

function System:FrameworkInit()

end;



return System
