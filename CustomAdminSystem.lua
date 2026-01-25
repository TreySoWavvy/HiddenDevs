--// NAME: CUSTOM ADMINISTRATION SYSTEM
--// CLASS: SERVICE
--// TIMESTAMP: 25 DEC 2025
--// DESCRIPTOR: HANDLES THE CUSTOM ADMIN SYSTEM AND ITS USAGE.

--// BY: TreySoWavvy (Don)
----


--// FRAMEWORK
local Client_Dependents = game.ReplicatedStorage["Client/Dependents"];
local Server_Dependents = game.ServerStorage["Server/Dependents"];
local Framework = require(Client_Dependents.Framework.FrameworkCore);

local System = Framework.CreateService{
	Name = "Administration";
	Client = {
	};
}

--// SERVICES
local DataStoreService = game:GetService("DataStoreService");
local DataStore = DataStoreService:GetDataStore("Administration");
local HttpService = game:GetService("HttpService");
local GlobalChatService = game:GetService("Chat");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local MarketplaceService = game:GetService("MarketplaceService");
local TextService = game:GetService("TextService");
local MS = game:GetService("MessagingService");
local RS = game:GetService("RunService");
local IS = game:GetService("InsertService");
local TS = game:GetService("TextService");


--// FRAMEWORK SERVICES
local Global;
local LogService;
local UIService;
local DataService;
local TeleportService;
local Music;
local Environment;
local Economy;
local ItemService;



--// MODULES
local Debris = require(Framework.Modules.Debris);
local Library = require(Framework.Modules.Library);
local GoodSignal = require(Framework.Modules.GoodSignal);
local Janitor = require(Framework.Modules.Janitor);
local Format = require(Framework.Modules.Format);
local Promise = require(Framework.Modules.Promise);
local DateUtil = require(Framework.Modules.Date);
local Accessory = require(Framework.Modules.AccessoryService);
local ProfileStore = require(Framework.ServerModules.ProfileStore);


--// SYSTEM VARIABLES
System["Prefix"] = string.format("%s »", string.upper(script.Name));

System["Moderation_Logs"] = ProfileStore.New("TF_Moderation", {Logs = {}, Version = 1.0});

System["Server_Locked"] = false;

System["Log_Command_Usage"] = true;

System["Log_Chat_Messages"] = true;

System["Staff_Group"] = Library.GroupId;


System["Command_Prefix"] = ":";

System["Commands"] = {};

System["Elevated_Users"] = {};

System["Server_Bans"] = {};

System["Temporary"] = {};

System["Manual_List"] = {};

System["Lore_Shout_Cooldown_Enabled"] = true;

System["Lore_Shout_Cooldown"] = 10;

System["Last_Lore_Shout"] = {};

System["Client_Index"] = {}

System["Roles"] = {
	["Player"] = {
		Name = "Player";

		Level = 1;

		Color = Color3.fromRGB(255, 255, 255);
	};
	
	["Moderator"] = {
		Name = "Moderator";
		
		Level = 2;
		
		Color = Color3.fromRGB(255, 85, 0);
		
		GroupId = Library.GroupId;

		Rank = {9, 10, 13};
	};
	
	["Administrator"] = {
		Name = "Administrator";

		Level = 3;

		Color = Color3.fromRGB(170, 0, 0);
		
		GroupId = Library.GroupId;

		Rank = {14, 15, 234};
	};
	
	["Owner"] = {
		Name = "Owner";

		Level = 4;

		Color = Color3.fromRGB(170, 170, 255);
		
		GroupId = Library.GroupId;

		Rank = {255, 253};
	};
	
	["Developer"] = {
		Name = "Developer";

		Level = 5;

		Color = Color3.fromRGB(170, 85, 255);
		
		GroupId = Library.GroupId;
		
		Rank = 245;
	};
};

System["Command_Types"] = {
	["Moderation"] = Color3.fromRGB(255, 0, 0);
	["Utility"] = Color3.fromRGB(255, 255, 0);
	["Lore"] = Color3.fromRGB(170, 170, 255);
	["Information"] = Color3.fromRGB(85, 170, 255)
};


--// ADMINISTRATIVE CHECKERS & UTILITY COMMANDS
function System:IsMuted(Player)
	
end

function System:IsServerBanned(Player)
	return self.Server_Bans[Player.UserId]
end;

function System:GetTarget(Player : Player, Reference : any)
	local Role = self:GetCurrentRole(Player);
	
	if typeof(Reference) == "table" and Reference[1].ClassName == "Player" then
		return Reference
	end

	--| If NO Player was specified, only allow their command to affect them.
	if (not Reference) or (string.lower(Reference) == "me") then 
		return {Player} 
	end

	--| Additionally, If the Player has a non staff role, only allow their command to affect them.
	if Role.Level < self.Roles["Moderator"].Level then
		return {Player}
	end

	---
	
	--| All Players	
	if (string.lower(Reference) == "all") and Role.Level >= self.Roles["Moderator"].Level then
		return game.Players:GetPlayers()
	end

	--| All players excluding the original command user.
	if (string.lower(Reference) == "others") and Role.Level >= self.Roles["Moderator"].Level then
		local Players = {}
		for _, Plr in pairs(game.Players:GetPlayers()) do
			if Plr ~= Player then
				table.insert(Players, Plr)
			end
		end
		return Players
	end

	--| All players on a specific team.
	if (string.sub(Reference, 1, 1) == "@" and Role.Level >= self.Roles["Moderator"].Level) then
		local PartialName = string.sub(Reference, 2)
		for _, Team in pairs(game.Teams:GetTeams()) do
			if string.lower(string.sub(Team.Name, 1, PartialName:len())) == string.lower(PartialName) then
				return Team:GetPlayers()
			end
		end
	end

	--| A specific user in the server.
	for _, OtherPlayer in pairs(game.Players:GetPlayers()) do
		if string.lower(string.sub(OtherPlayer.Name, 1, string.len(Reference))) == string.lower(Reference) then
			if OtherPlayer.Name ~= Player.Name and Role.Level >= self.Roles["Moderator"].Level then
				return {OtherPlayer}
			end	
		end
	end

	return {Player}
end;

function System:GetTeam(Reference : string)
	for _, Team in pairs(game.Teams:GetTeams()) do
		if string.lower(string.sub(Team.Name, 1, Reference:len())) == string.lower(Reference) then
			return Team
		end
	end
end;

function System:Filter(Player : Player, Raw_Text : string)
	local Success, Result = pcall(function()
		return TS:FilterStringAsync(Raw_Text, Player.UserId)
	end)
	if Success then
		return Result:GetNonChatStringForBroadcastAsync()
	end
end;


--// COMMAND RELATED METHODS
function System:DenyCommandUsage(Player : Player, Message : string)
	return UIService:Replicate(Player, {
		Task = "Alert";
		Message = Message or "You do not have permission to use this.";
		Color = Library.Color.Red;
	})
end;

function System:LogChatMessage(Player : Player, Message : Message)
	--// Otherwise, log it in the ChatLogs LogObject
	self.ChatLogs:Add(
		string.format("%s » %s", Player.Name, Message)
	)
end;

function System:LogCommand(Player, Command) --// Logs the command in the command log for viewing.
	local Current_Role = self:GetCurrentRole(Player)
	
	self.CommandLogs:Add(
		string.format("[%s] %s » %s", Current_Role.Name, Player.Name, Command)
	)
end;

function System:ProcessCommand(Player : Player, Message : string) --// This is the function that takes Player chat messages and converts them to executable commands.
	local Success, err = pcall(function()
		local Commands = string.split(Message, "|")
		local Current_Role = self:GetCurrentRole(Player)

		--// Split the command to detect if multiple commands are being used, and check them one by one.
		for Slot, Command in next, Commands do
			
			local Sections = string.split(Command, " ")
			local WhiteSpaceEnd = string.find(Command, System["Command_Prefix"])
			if WhiteSpaceEnd then
				Command = string.sub(Command, WhiteSpaceEnd + 1, string.len(Command))
			end
			for ArgSlot, String in next, Sections do
				if String == "" then table.remove(Sections, ArgSlot) end
			end

			local Name = string.sub(Sections[1]:upper(), 2)
			local Table = self.Commands[Name]


			--// If the command doesnt exist. Notify the Player.
			if (not Table) then 
				return self:DenyCommandUsage(Player, string.format("`%s` command does not exist.", Name or "")) 
			end
			
			--// If the command is a HIGHER level than they are, notify the Player.
			if (Table.Level and Current_Role.Level < Table.Level) and not RS:IsStudio() then
				return self:DenyCommandUsage(Player, "You are not a high enough level to use this.") 
			end

			--// If it's a sensitive command that requires them to be a staff member, notify the Player.
			if Table.RequiresStaff and not Global.IsDeveloper(Player) and not RS:IsStudio() then
				return self:DenyCommandUsage(Player, "You must be a Staff Member to use this.") 
			end

			
			--// Compile all the arguments they provided into a table.
			local Args = {}
			if #Sections > 1 then 
				for i = 2, #Sections do 
					table.insert(Args, Sections[i]) 
				end 
			end


			--// Log the command's usage, notify the Player it was ran, and execute the command.
			self:LogCommand(Player, Command)
			
			UIService:Replicate(Player, {
				Task = "Alert";
				Message = "Command has been executed!";
				Color = Library.Color.Green
			})
			Table.Function(Player, unpack(Args))
		end
	end)
	
	if not Success then
		warn(self.Prefix, "Command Error:", err)
	end
end;



--// USER ROLE MANAGEMENT
function System:GetRoleInfo(Role : string)
	for RoleName, Info in next, self.Roles do
		if Info.Name == Role or Info.Level == Role then
			return Info, Info.Level
		end
	end
end;

function System:GetLevelFromRole(Role : string)
	for Role_Name, Info in next, self.Roles do
		if Role_Name == Role then
			return Info.Level
		end
	end
end;

function System:GetCurrentRole(Player : Player)
	local Saved = DataService:GetValue(Player, "UserData", "Admin Level")
	local SavedRole = self:GetRoleInfo(Saved)
	
	if self.Elevated_Users[Player] then
		return self:GetRoleInfo(self.Elevated_Users[Player])
	else
		if (not SavedRole) or (SavedRole == "") then
			return self.Roles.Player
		else
			return self:GetRoleInfo(SavedRole)
		end
	end
end;

function System:SetRole(Player : Player, New_Role_Name : string, Is_Temporary : boolean)
	local Current_Role = self:GetCurrentRole(Player);
	local New_Role = self:GetRoleInfo(New_Role_Name);
	
	--// No point in changing it if the user already has that role.
	if New_Role and Current_Role and New_Role.Name == Current_Role.Name then
		--task.delay(5, function()
		--	UIService:SendUIPrompt(Player, "Narration", {
		--		Message = "You have been retained your authority as a " .. New_Role.Name
		--	})
		--end)
		return
	end
	
	self["Elevated_Users"][Player] = New_Role_Name;
	
	--// If this is a permanent change, change their userdata too.
	if not Is_Temporary and New_Role then
		DataService:SetValue(Player, "UserData", "Admin_Level", New_Role_Name)
		self.RoleChanged:Fire(Player, New_Role_Name)
	end
end;

function System:GetRoleAsync(Player : Player)
	return Promise.new(function(resolve, reject)
		
		local Group_Rank = Player:GetRankInGroupAsync(Library.GroupId);
		local Current_Role = self:GetCurrentRole(Player);
		local Qualified_Roles = {self.Roles.Player};
		
		
		if not Current_Role then
			Current_Role = self.Roles.Player
		end

		--// If their name is hard coded into this script with a certain Admin Level, give it to them no matter what.
		for Identifier, New_Role in next, self.Manual_List do
			if Player.Name == Identifier or Player.UserId == Identifier then
				return self:SetRole(Player, New_Role)
			end
		end


		--// Otherwise, calculate all the roles the Player qualifies for, and get the highest priority one.
		for Name, Role in pairs(self.Roles) do
			if (not Role.GroupId and not Role.Rank) then
				table.insert(Qualified_Roles, Role)
			else
				local Current_Rank = (Role.GroupId and Player:GetRankInGroupAsync(Role.GroupId));
				
				if not (Role.Rank) then
					table.insert(Qualified_Roles, Role)
				elseif typeof(Role.Rank) == "number" then
					if Role.Rank == Current_Rank then
							table.insert(Qualified_Roles, Role)
					end
				elseif typeof(Role.Rank) == "table" then
					for _, Rank in pairs(Role.Rank) do
						if Current_Rank == Rank then
							table.insert(Qualified_Roles, Role)
						end
					end
				end
			end
		end

		if #Qualified_Roles > 0 then
			--// Now that we have a list of all the roles they qualify for, sort them by order of importance.
			table.sort(Qualified_Roles, function(Role1, Role2)
				return Role1.Level > Role2.Level
			end);

			--// Take the highest one, and give it to the Player.
			self:SetRole(Player, Qualified_Roles[1].Name);
		end
		
		resolve()
	end)
end;



--// DIRECT MODERATION FUNCTIONS
function System:ConvertTimeToSeconds(Amount : number, Measurement : string)
	local Seconds = 1
	local Minute = Seconds * 60
	local Hour = Minute * 60
	local Day = Hour * 24
	local Week = Day * 7
	local Month = Day * 30
	local Year = Month * 12

	Measurement = string.lower(Measurement)
	if Measurement == "min" then
		return Amount * Minute
	elseif Measurement == "h" then
		return Amount * Hour
	elseif Measurement == "d" then
		return Amount * Day
	elseif Measurement == "w" then
		return Amount * Week
	elseif Measurement == "m" then
		return Amount * Month
	elseif Measurement == "y" then
		return Amount * Year
	end
end

function System:IsBanned(Player : Player) --// To be fixed
	local IsBanned, BanMessage
	local Success, Result = pcall(function()
		self.BanList = self.Moderation_Logs:ViewProfileAsync("Bans")

		if self.BanList.Data then
			for UserId, Meta in pairs(self.BanList.Data) do
				if typeof(Meta) == "table" and (Meta.UserId == Player.UserId or Meta.Name == Player.Name) then
					IsBanned = true
					BanMessage = string.format(
						self.TempBanMessage,
						Meta.StaffRole,
						Player.Name,
						Meta.Reason,
						Meta.Date,
						Meta.Time
					) 
				end
			end
		end
	end)

	if Success and Result then
		return IsBanned, BanMessage
	end
end

function System:ServerBan(Moderator : Player, Player : Player, Reason : string)
	return Promise.new(function(resolve, reject)
		if self:IsServerBanned(Player) then reject("User is already server banned.") end

		self.Server_Bans[Player.UserId] = {
			Enabled = true;
			Username = Player.Name;
			Reason = Reason or "Unspecified";
			Moderator = Moderator and Moderator.Name or "SYSTEM";
		};

		Player:Kick(string.format([[
		You have been temporarily banned from this Server Instance by %s.
		
		You may still play the game, in a different server.

		Reason: %s
	]], Moderator and Moderator.Name or "SYSTEM", Reason or "No Reason Specified"))
	
		resolve(true)
	end)
end;

function System:UnServerBan(Moderator : Player, Reference : string)
	return Promise.new(function(resolve, reject)
		for UserId, Entry in pairs(self.Server_Bans) do
			if string.lower(string.sub(Entry.Username, 1, Reference:len())) == string.lower(Reference) then
				self.Server_Bans[UserId] = nil
				resolve(true, Entry.Username)
				return
			end
		end
		
		reject(Reference .. " was never Server Banned.")
	end)
end

function System:Ban(Moderator : Player, Reference : string, Options : any)
	return Promise.new(function(resolve, reject)
		
		local UserId;
		local Ban_Config = {
			UserIds = {};
			Duration = Options.Permanent and -1 or 0;
			DisplayReason = "";
			PrivateReason = "";
			ApplyToUniverse = true;
		}
		
		--// Attempt to get their info if they are already in game.
		for _, OtherPlayer in pairs(game.Players:GetPlayers()) do
			if string.lower(string.sub(OtherPlayer.Name, 1, string.len(Reference))) == string.lower(Reference) then
				--if OtherPlayer ~= Moderator then
					UserId = OtherPlayer.UserId;
				--end
			end
		end
		
		--// Attempt to get a direct reference to them by username. Exact Usernames must be provided.
		if not UserId then
			UserId = game.Players:GetUserIdFromNameAsync(Reference)
		end
		
		if not UserId then
			reject("Could not find the Player with the name: " .. Reference)
			return
		end
		
		--
		
		Ban_Config.UserIds = {UserId};
		Ban_Config.Duration = (Options.Duration and os.time() + self:ConvertTimeToSeconds(Options.Duration, Options.Measurement));
		Ban_Config.PrivateReason = "Ban was executed by: " .. (Moderator and Moderator.Name or "SYSTEM");
		
		
		local Success, err = pcall(function()
			game.Players:BanAsync(Ban_Config)
		end)
		
		if Success then
			resolve(true)
		end
	end)
end;

function System:Unban(Moderator : Player, Reference : string)
	return Promise.new(function(resolve, reject)
		local UserId = game.Players:GetUserIdFromNameAsync(Reference)
		
		if UserId then
			local Success, err = pcall(function()
				game.Players:UnbanAsync({
					UserIds = {UserId};
					ApplyToUniverse = true;
				})
			end)
			if Success then
				resolve(true)
			end
		else
			reject("Could not find the Player with the name: " .. Reference)
		end
	end)
end;


--// CLIENT METHODS
function System:CanLoreShout(Player : Player)
	if Global.IsDeveloper(Player) then return true end
	return
end
function System:LoreShout(Player : Player, ...)
	if self:CanLoreShout(Player) and Player.Character then


		--// Prevent repeated lore shouting and add a cooldown.
		if self["Lore_Shout_Cooldown_Enabled"] then
			if self["Last_Lore_Shout"][Player] and (os.clock() - self["Last_Lore_Shout"][Player]) <= self["Lore_Shout_Cooldown"] then
				UIService:SendUIPrompt(Player, "Narration", {
					Message = "You feel your voice crackle and pop.. the words can't escape your lungs..."
				})
				return
			end
		end


		--// Get the Lore Name of the sender, as well as filter the message they sent properly.
		local OriginCharacter = Player.Character
		local Message = table.concat({...}, " ")
		local Reciepients = {};
		local Potential_Cadets = {};
		
		Message = self:Filter(Player, Message);


		--// Calculate which players are nearby and add them to a table
		for _, User in pairs(game.Players:GetPlayers()) do
			if User.Character then
				local Distance = User:DistanceFromCharacter(OriginCharacter.PrimaryPart.Position)
				
				if Distance <= 100 then
					table.insert(Reciepients, User)
				end
			end
		end

		--// Record the shout and send it out to all nearby players.
		self["Last_Lore_Shout"][Player] = os.clock();
		UIService:Replicate(Reciepients, {
			Task = "Message";
			Type = "User";
			UserId = Player.UserId;
			Message = Message;
		})
	end
end


function System.Client:Fire(Player, Key, ...)
	--| Exploitation checks.
	if (not Key) or (Key == "") or (typeof(Key) ~= "string") then
		warn(self.Server.Prefix, "Incorrect or nil key.")
		return
	end

	local Action_Name = self.Server["Client_Index"][Key]

	if Action_Name == "AdminPanelAction" then
		return self.Server:ProcessAdminPanelAction(Player, ...)
	end
end


--// FRAMEWORK METHODS
function System:FrameworkStart()
	Global = Framework.GetService("Global");
	LogService = Framework.GetService("Logs");
	UIService = Framework.GetService("UI");
	DataService = Framework.GetService("Data");
	Music = Framework.GetService("Music");
	Environment = Framework.GetService("Environment");
	Economy = Framework.GetService("Economy");
	ItemService = Framework.GetService("Items");
	TeleportService = Framework.GetService("Teleport");
	
	self:LoadCommands()
	
	self.CommandLogs = LogService:Create({
		Name = "Commands";
		Tags = {"Command"}
	})
	self.ChatLogs = LogService:Create({
		Name = "Chat";
		Tags = {"Message"}
	})
	
	
	self.RoleChanged:Connect(function(Player, New_Role)
		if New_Role then
			warn(self.Prefix, Player.Name, "has just been elevated to", New_Role)
			--UIService:SendUIPrompt(Player, "Narration", {
			--	Message = "You have been elevated to " .. New_Role.Name
			--})
		end
	end)
	
	game.Players.PlayerRemoving:Connect(function(Player)
		self.Elevated_Users[Player] = nil
	end)
end
function System:FrameworkInit()
	self.RoleChanged = GoodSignal.new();
end


----------- ADMIN COMMANDS -------------
--// The mag dump list of all possible commands in game.
--// I put it down here for organization purposes.

--[[
	Founder = 8;
	
	Department_Head = 7;
	
	Senior_Staff = 6;
	
	Administrator = 5;
	
	Moderator = 4;
	
	Intern = 3;
	
	Player = 1
]]

function System:LoadCommands() 
	
	--// MODERATION COMMANDS
	self.Commands["KICK"] = {
		Name = "KICK";
		Description = "Kicks a user from the server for an offense.";
		CommandType = "Moderation";
		Level = 4; 
		Arguments = "[Target] (Reason)";
		RequiresStaff = true;
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)	
			local Message = "You have been kicked from the game by %s for: %s"
			local Reason = ""

			for i,v in pairs({...}) do Reason = Reason .. " " .. v end	
			if Reason == "" then Reason = "Unspecified Reason." end

			if Targets then
				for _, User in pairs(Targets) do 
					task.spawn(function()
						User:Kick(string.format(Message, Player.Name, Reason)) 	
					end)
				end
			end
		end
	}

	self.Commands["SBAN"] = { -- Done
		Name = "SBAN";
		Description = "Server Bans a user from the current server instance.";
		CommandType = "Moderation";
		Level = 4; 
		Arguments = "[Target] (Reason)", 
		RequiresStaff = true;
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)	
			local Reason = ""
			for i,v in pairs({...}) do Reason = Reason .. " " .. v end
			Reason = self:Filter(Reason);
			
			if Targets then
				for i = 1, #Targets do
					local User = Targets[i]
					--if User == Player then return end
					
					local Target_Role = self:GetRole(User)
					local Staff_Role = self:GetRole(Player)
					local Date = DateUtil.new()
					
					if Target_Role.Level > Staff_Role.Level then
						return UIService:Replicate(Player, {
							Task = "Alert";
							Message = string.format("%s has a higher admin level than you, and can't be server banned.", User.Name);
							MessageColor3 = Library.Color.Gold;
						})
					end
					
					self:ServerBan(Player, User, Reason)
				end
			end
		end
	}
	self.Commands["UNSBAN"] = {
		Name = "BAN";
		Description = "Removes a server ban for a specific user.";
		CommandType = "Moderation";
		Level = 4; 
		Arguments = "[Target]", 
		RequiresStaff = true;
		Function = function(Player, TargetName)
			
			--// Remove ALL server bans.
			if string.lower(TargetName) == "all" then
				local Count = 0
				for UserId, Info in next, self.Server_Bans do
					self.Server_Bans[UserId] = nil
					Count += 1
				end 	
				
				
				return UIService:Replicate(Player, {
					Task = "Alert";
					Message = "You have lifted all server bans in this server. the individuals will be able to rejoin this server.";
					Color = Library.Color.Green;
				})
			else
				self:UnServerBan(Player, TargetName):andThen(function(Was_Successful, Username)
					if Was_Successful then
						UIService:Replicate(Player, {
							Task = "Alert";
							Message = string.format("You have lifted the server ban on (%s). this individual will be able to rejoin this server.", Username);
							Color = Library.Color.Green;
						})
					end
				end)
			end
		end
	}
	self.Commands["SBANS"] = {
		Name = "SBANS";
		Description = "Shows a list of all users who are currently banned from this specific server."; 
		CommandType = "Information";
		Level = 4; 
		Function = function(Player)
			local Properties = {
				Title = "Current Server Bans";
				Entries = {
					{"Subtitle", "Important Note", "These are all the users currently banned from this server, not the game entirely."}
				}
			}
			for UserId, Info in pairs(self.Server_Bans) do
				local Title = string.format("« %s (by: %s %s) »", Info.Username, Info.StaffRole, Info.StaffMember)
				local SubTitle = string.format("Reason » %s", Info.Reason)
				table.insert(Properties.Entries, {"Subtitle", Title, SubTitle, Library.Color.LBlue})
			end
			UIService.Client.Interface:Fire(Player, "CreateSmallList", Properties)
		end
	}


	--( To be worked on )
	self.Commands["BAN"] = {
		Name = "BAN";
		Description = "Temporarily or permanently bans a user from the universe.";
		CommandType = "Moderation";
		Level = 5; 
		Arguments = "[Target] [Time] (Reason)", 
		Function = function(Player, Target, Time, ...)
			local Targets = self:GetTarget(Player, Target)
			local Role = self:GetCurrentRole(Player)

			if Targets and Targets[1] then
				local TargetRole = self:GetRoleInfo(self:GetCurrentRole(Targets[1]))
				local StaffRole = self:GetRoleInfo(self:GetCurrentRole(Player))

				if TargetRole and StaffRole and (TargetRole.Level > StaffRole.Level) then
					return 	UIService.Client.Interface:Fire(Player, "Alert", "You cannot ban someone who has a higher ranking than you.", {
						Color = Color3.fromRGB(170, 85, 255);
						Italic = true
					})
				end

				local Reason = ""
				local Meta = Global.CopyTable(self.BanTemplate)
				
				local Properties = {}
				Meta.Username = Targets[1].Name;
				Meta.UserId = Targets[1].UserId;
				Meta.StaffUserId = Player.UserId;
				Meta.StaffRole = StaffRole.Name;
				Meta.Type = "Temporary";
				Meta.Reason = "No reason has been specified.";
				Meta.Expiration = os.clock();


				-- Compile the reason.
				local Reason = {...}
				if #Reason > 0 then
					Meta.Reason = ""
					for i,v in pairs({...}) do Meta.Reason =  Meta.Reason .. " " .. v end	 
					Meta.Reason = game.Chat:FilterStringAsync(Meta.Reason, Player, Player)	
				end			

				-- Format the time.
				local TimeNumber = string.match(Time, "%d+")
				local TimeUnit = string.match(Time, "%a+")
				print(Time, "->", TimeNumber, TimeUnit)
				Meta.Expiration = os.time() + self:ConvertTo(TimeNumber, TimeUnit)

				local Date = DateUtil.new(Meta.Expiration)
				Meta.Date = string.format("%s, %s %s%s",
					Library.WeekDay[Date.Weekday],
					Library.Month[Date.Month],
					Date.Day,
					Library.DaySuffix[tonumber(string.sub(Date.Day, string.len(Date.Day)))]
				)
				Meta.Time = Date:ToTimeString()
				local Success, BanList = pcall(function()
					return self.Moderation:LoadProfileAsync(
						"Bans",
						"ForceLoad"
					)
				end)

				if Success and BanList then
					BanList.Data[Targets[1].UserId] = Meta
					BanList:Release()
					UIService.Client.Interface:Fire(Player, "Alert", "Successfully banned " .. Target[1].Name, {
						Color = Color3.fromRGB(0, 170, 255);
						Italic = true
					})
					Targets[1]:Kick(string.format(
						self.TempBanMessage,
						Meta.StaffRole,
						Player.Name,
						Meta.Reason,
						Meta.Date,
						Meta.Time
						)) 		
				elseif not Success then
					UIService.Client.Interface:Fire(Player, "Alert", "Error Banning " .. Target[1].Name .. ": " .. BanList, {
						Color = Color3.fromRGB(255, 170, 0);
						Italic = true
					})
				end					
			end
		end
	}
	self.Commands["UNBAN"] = {
		Name = "UNBAN";
		Description = "Unbans a user from TA:O Databases.";
		CommandType = "Moderation";
		Level = 12; 
		Arguments = "[Username]", 
		Function = function(Player, Name)
			local TargetUserId = game.Players:GetUserIdFromNameAsync(Name)
			if not TargetUserId then 
				return UIService.Client.Interface:Fire(Player, "Alert", string.format([['%s' is not a valid roblox Player.]], Name), {
					Color = Color3.fromRGB(255, 170, 0);
					Italic = true
				})
			end	

			if not self.BanList then
				self.BanList = self.Moderation:ViewProfileAsync("Bans")
			end

			if self.BanList then
				for UserId, Meta in pairs(self.BanList.Data) do
					if typeof(Meta) == "table" then
						if UserId == TargetUserId or string.lower(string.sub(Meta.Username, 1, string.len(Name))) == string.lower(Name) then
							UIService.Client.Interface:Fire(Player, "Alert", "Successfully unbanned " .. Meta.Username, {
								Color = Color3.fromRGB(0, 170, 255);
								Italic = true
							})
							Meta = nil
							self.BanList.Data[UserId] = nil
							self.BanList:OverwriteAsync()
							break
						end
					end
				end
			end
		end
	} 
	self.Commands["BANS"] = {
		Name = "BANS";
		Description = "View a list of all banned players.";
		CommandType = "Information";
		Level = 12; 
		Function = function(Player)

			self.BanList = self.Moderation:ViewProfileAsync("Bans")
			if self.BanList.Data then
				local Properties = {
					Title = "TAO Banned Users";
					Entries = {}
				}	
				for UserId, Meta in pairs(self.BanList.Data) do
					if typeof(Meta) == "table" then
						local StaffUsername = game.Players:GetNameFromUserIdAsync(Meta.StaffUserId)
						local StaffRole = self:GetRoleInfo(self:GetCurrentRole(Player))
						local Subtitle = string.format("(%s) %s | Reason: %s", Meta.StaffRole, StaffUsername, Meta.Reason)
						table.insert(Properties.Entries, {"Subtitle", string.format("(%s) %s", Meta.UserId, Meta.Username), Subtitle, Library.Color.LBlue})	
					end
				end
				UIService.Client.Interface:Fire(Player, "CreateSmallList", Properties)
			end

		end
	}


	--// TELEPORTATION COMMANDS
	self.Commands["TO"] = {
		Name = "TO";
		Description = "Teleport to another user within the world.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Target]"; 
		Function = function(Player, Target)
			local Users = self:GetTarget(Player, Target)
			if Users and Users[1].Character and Player.Character then
				if Player.Character and Users[1].Character then 
					if not Users[1].Character then
						return UIService:Alert(Player, {
							Message = Users[1].Name .. "'s body does not exist.";
						})
					end
					Player.Character:PivotTo(Users[1].Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -1.5))
				end
			end
		end
	}
	self.Commands["TP"] = {
		Name = "TP";
		Description = "Bring / Send one user to another's location.";
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]"; 
		Function = function(Player, Target1, Target2)
			local Users = self:GetTarget(Player, Target1)
			local Target = self:GetTarget(Player, Target2)
			if Users and Target then
				for _, User in pairs(Users) do
					if User.Character and Target[1].Character then 
						if User.Character:GetAttribute("Detained") and not Global.IsStaffMember(Player) then
							return UIService:Alert(Player, {
								Message = string.format("You cannot teleport %s while they are detained", User.Name);
								Color = Library.Color.Red;
							})
						end
						User.Character:PivotTo(Target[1].Character.HumanoidRootPart.CFrame  * CFrame.new(0, 0, -1.5))
					end
				end
			end
		end
	}
	self.Commands["BRING"] = {
		Name = "BRING";
		Description = "Bring a user to your current location.";
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for Slot, User in pairs(Targets) do
					if User.Character then 
						if User.Character:GetAttribute("Detained") and not Global.IsStaffMember(Player) then
							return 	UIService:Alert(Player, {
								Message = string.format("You cannot bring %s while they are detained", User.Name);
								MessageColor3 = Color3.fromRGB(170, 85, 255);
							})
						end
						User.Character:PivotTo(Player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -3.5))
					end
				end			
			end		
		end
	}
	
	
	self.Commands["SPEED"] = {
		Name = "SPEED";
		Description = "Sets your walk speed to a specified number.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Target] (WalkSpeed)", 
		Function = function(Player, Target, Speed)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then 
						User.Character.Humanoid.WalkSpeed = (Speed or 16)
					end
				end	
			end	
		end
	}


	--// HEALTH RELATED
	self.Commands["HEAL"] = {
		Name = "HEAL";
		Description = "Fully restores the health of the specified user.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then User.Character.Humanoid.Health = User.Character.Humanoid.MaxHealth	end
				end			
			end	
		end
	}
	self.Commands["KILL"] = {
		Name = "KILL";
		Description = "Instantly terminates the specified user.";
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then User.Character.Humanoid:TakeDamage(10000) end
				end			
			end	
		end
	}
	self.Commands["DAMAGE"] = {
		Name = "DAMAGE";
		Description = "Inflicts a specified amount of damage on a user.";
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Target] (Amount)", 
		Function = function(Player, Target, Amount)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then User.Character.Humanoid:TakeDamage(Amount or 10) end
				end	
			end	
		end
	}
	self.Commands["GOD"] = {
		Name = "GOD";
		Description = "Enables god mode for the provided user(s)."; 
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then
						User.Character:SetAttribute("GodMode", true)
						task.delay(.5, function()
							User.Character.Humanoid.MaxHealth = math.huge
							User.Character.Humanoid.Health = math.huge
						end)
					end
				end
			end
		end
	}
	self.Commands["UNGOD"] = {
		Name = "UNGOD";
		Description = "Disables god mode for the provided user(s)."; 
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then
						User.Character:SetAttribute("GodMode", nil)
						task.delay(.5, function()
							User.Character.Humanoid.MaxHealth = 100
						end)
					end
				end
			end
		end
	}
	
	
	
	self.Commands["TEAM"] = {
		Name = "TEAM";
		Description = "Assigns a user to a specified team.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Target] [Team Name]", 
		Function = function(Player, Target, TeamName)
			local Targets = self:GetTarget(Player, Target)
			local Team = self:GetTeam(TeamName)
			if Targets and Team then
				for _, User in pairs(Targets) do
					User.Team = Team
				end
			end	
		end
	}
	self.Commands["GIVE"] = {
		Name = "GIVE";
		Description = "Gives the specified user an item.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Target] [ItemName]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)
			local Tools = Server_Dependents.Tools:GetDescendants()
			local SearchResult = string.lower(table.concat({...}, " "))
			local FoundTool
			
			print("Searching For", SearchResult)
			for i = 1, #Tools do
				local Tool = Tools[i]
				if Tool.ClassName == "Tool" then
					if string.find(string.lower(Tool.Name), SearchResult) then
						SearchResult = Tool
						break
					end
				end
			end
			
			for _, User in pairs(Targets) do
				ItemService:GiveItem(User, SearchResult.Name)
			end
		end
	}

	
	--// RESPAWNING/REFRESHING/REJOINING
	self.Commands["RE"] = {
		Name = "RE";
		Description = "Refreshes the specified user with a new character."; 
		CommandType = "Utility";
		Level = 2; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then
						if User.Character:GetAttribute("Detained") then
							return UIService:Alert(User, {
								Message = "You cannot refresh while detained.";
								MessageColor3 = Library.Color.Red;
							})
						end

						task.spawn(function()
							local PivotC0 = User.Character:GetPivot()
							User:LoadCharacter()
							task.delay(1, function()
								User.Character:PivotTo(PivotC0)
							end)
						end)
					end
				end
			end
		end
	}
	self.Commands["RESPAWN"] = {
		Name = "RESPAWN";
		Description = "Complete respawns the provided user(s)"; 
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do User:LoadCharacter() end
			end
		end
	}
	self.Commands["REJOIN"] = {
		Name = "REJOIN";
		Description = "Rejoin the current server you are in."; 
		CommandType = "Utility";
		Level = 1; 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				TeleportService:Teleport({Targets}, game.PlaceId)
			end
		end
	}
	
	
	--// PLAYER OBSERVATION
	self.Commands["WATCH"] = {
		Name = "WATCH";
		Description = "Allows you to spectate a specific user freely."; 
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets and Targets[1] and Targets[1].Character then
				UIService:SendUIPrompt(Player, "Watch", {
					Enabled = true;
					Model = Targets[1].Character
				})
			else
				UIService:SendUIPrompt(Player, "Watch", {
					Enabled = false;
				})
			end
		end
	}
	self.Commands["UNWATCH"] = {
		Name = "UNWATCH";
		Description = "Stop watching a specified user."; 
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			UIService:SendUIPrompt(Player, "Watch", {
				Enabled = false;
			})
		end
	}
	self.Commands["FLY"] = {
		Name = "FLY";
		Description = "Grants the ability of flight on a target."; 
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character and not User.Character:FindFirstChild("SoulMode_Client") then
						local SoulModeClient = Server_Dependents.Scripts.Local.SoulMode_Client:Clone()
						SoulModeClient:SetAttribute("Flight_Enabled", true)
						SoulModeClient:SetAttribute("NoClip_Enabled", false)
						SoulModeClient.Parent = User.Character
						SoulModeClient.Enabled = true
						
						UIService:Narration(User, {
							Message = "You have obtained the gift of flight...";
						})
					end
				end
			end
		end
	}
	self.Commands["UNFLY"] = {
		Name = "UNFLY";
		Description = "Removes the ability of flight from a target."; 
		CommandType = "Utility";
		Level = 3; 
		Arguments = "[Target]", 
		Function = function(Player, Target)
			local Targets = self:GetTarget(Player, Target)
			if Targets then
				for _, User in pairs(Targets) do
					if User.Character then
						local SoulModeClient = User.Character:FindFirstChild("SoulMode_Client")
						if SoulModeClient then
							SoulModeClient:SetAttribute("Removing", true)
							task.delay(1, function()
								Debris(SoulModeClient)
							end)
						end
					end
				end
			end
		end
	}
	
	--//ENVIRONMENTAL COMMANDS
	self.Commands["WEATHER"] = {
		Name = "WEATHER";
		Description = "Override the current weather pattern with a specified type."; 
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Type]";
		Function = function(Player, Type)
			Environment:SetWeather(Type)
		end
	}
	self.Commands["TIME"] = {
		Name = "TIME";
		Description = "Override the current time period with a specified type."; 
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Time]", 
		Function = function(Player, Arg)
			Environment:SetTime(Arg)
		end
	}
	
	
	--// SOUND/MUSIC RELATED
	self.Commands["MUSIC"] = {
		Name = "MUSIC";
		Description = "Plays a certain sound id for all to hear musically.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[SubCommand] (Args)", 
		Function = function(Player, SubCommand, ...)
			local Args = {...}
			--TrackId, Volume, FadeInTime
			SubCommand = string.lower(SubCommand)
			
			if SubCommand == "tracks" then
				return UIService.Client.Interface:Fire(Player, {
					Task = "CreateMusicSheet";
				})
			elseif SubCommand == "track" then
				Music:PlayTrack(...)
			elseif SubCommand == "stop" then
				Music:StopTrack() --// TrackId Arg in this case is fade out volume.
			elseif SubCommand == "volume" then
				Music:SetTrackVolume(...)
			end
			
		end
	}
	self.Commands["PLAY"] = {
		Name = "PLAY";
		Description = "Plays a certain sound effect for all to hear.";
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Distance] [SoundType] [Args]", 
		Function = function(Player, SubCommand, SoundType, ...)
			local Targets = {}
			--TrackId, Volume, FadeInTime
			SubCommand = string.lower(SubCommand)
			SoundType = string.lower(SoundType)
			
			if SubCommand == "all" then
				Targets = game.Players:GetPlayers()
			elseif SubCommand == "near" and Player.Character then
				for _, User in pairs(game.Players:GetPlayers()) do
					if User.Character and Player:DistanceFromCharacter(User.Character.PrimaryPart.Position) <= 250 then
						table.insert(Targets, User)
					end
				end
			end
			
			if SoundType == "id" then
				Music:Effect(Targets, {
					Type = "Id";
					SoundId = (...);
				})
			elseif SoundType == "name" then
				Music:Effect(Targets, {
					Type = "Name";
					Name = table.concat({...}, " ");
				})
			end

		end
	}
	
	--// SERVER MANAGEMENT
	self.Commands["HELP"] = {
		Name = "HELP";
		Description = "Summon any in game staff member to assist you!"; 
		CommandType = "Utility";
		Level = 1; 
		Arguments = "[Request]";
		Function = function(Player, Target, ...)
			UIService:SendUIPrompt(Player, "Narration", {
				Message = "My request for help has been sent..."
			})
			task.delay(.25, function()
				for _, User in pairs(game.Players:GetPlayers()) do
					if Global.IsStaffMember(User) then
						UIService:SendUIPrompt(User, "Narration", {
							Message = string.format("( %s ) has request staff assistance...", Player.Name)
						})
					end
				end
			end)
		end
	}
	self.Commands["FT"] = {
		Name = "FT";
		Description = ""; 
		CommandType = "Utility";
		RequiresStaff = true;
		Level = 5; 
		Arguments = "[Map Name]";
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)		
			local MapName = ""
			for i,v in pairs({...}) do MapName = MapName .. " " .. v end
			local MapInfo = TeleportService:GetDestination(MapName)
			
			if MapInfo and Targets then
				UIService:Alert(Player, {
					Message = string.format("Teleport to '%s' has begun. Please wait.", MapName)
				})
				task.delay(1, function()
					TeleportService:Teleport(Targets, MapName)
				end)
			end
		end
	}
	self.Commands["LOCK"] = {
		Name = "LOCK";
		Description = "Locks this server and prevents other players from joining.";
		CommandType = "Utility";
		IsHidden = true;
		Level = 4; 
		Arguments = "", 
		Function = function(Player)
			self:ToggleServerLock(true)
		end
	}
	self.Commands["UNLOCK"] = {
		Name = "UNLOCK";
		Description = "Unlocks this server and allows other players to join.";
		CommandType = "Utility";
		IsHidden = true;
		Level = 4; 
		Arguments = "", 
		Function = function(Player)
			self:ToggleServerLock(false)
		end
	}
	self.Commands["SHUTDOWN"] = {
		Name = "SHUTDOWN";
		Description = "Shuts down the server entirely, and removes all players."; 
		CommandType = "Utility";
		Level = 5; 
		Arguments = "[Shutdown Reason]", 
		Function = function(Player, ...)
			local Reason = table.concat({...}, " ")
			if Reason == "" then 
				Reason = "This server has been scheduled to shut down in a few seconds. Your data has been saved. Please rejoin the game. Thank you!" 
			end
			
			TeleportService:Teleport(game.Players:GetPlayers(), "Lobby")
			game:GetService("Players").PlayerAdded:Connect(function(NewPlayer)
				NewPlayer:Kick(Reason)
			end)
		end
	}
	self.Commands["GSHUTDOWN"] = {
		Name = "GSHUTDOWN";
		Description = "Simultaneously shuts down all servers across ALL TAO Maps."; 
		CommandType = "Utility";
		IsHidden = true;
		Level = 7; 
		Function = function(Player, ...)
			local Message = ""
			for i,v in pairs({...}) do Message = Message .. " " .. v end
			if Message == "" then Message = "A Lore Worldwide reboot is commencing. Please rejoin in a few minutes." end
			MS:PublishAsync("Global", {"Shutdown", Message})
		end
	}
	self.Commands["CLEAR"] = {
		Name = "CLEAR";
		Description = "Clears specific entities from the game."; 
		CommandType = "Utility";
		Arguments = "[EntityType]";
		Level = 4; 
		Function = function(Player, Type)
			Type = string.lower(Type)
		end
	}
	
	
	--// ECONOMY COMMANDS
	self.Commands["CREDITS"] = {
		Name = "CREDITS";
		Description = "The overhead money management command";
		CommandType = "Utility";
		IsHidden = true;
		Level = 5; 
		Arguments = "[SubCommand] [Target] (Amount)", 
		Function = function(Player, SubCommand, Target, Amount)
			local Targets = (Target and self:GetTarget(Player, Target))
			SubCommand = string.lower(SubCommand)
			
			if Amount then
				Amount = tonumber(string.match(Amount, "%d+"))
			end
			
			if not Amount or Amount == 0 then return end
			if not Targets then return warn("No targets") end


			for i = 1, #Targets do
				if SubCommand == "add" then
					Economy:Add(Targets[i], Amount)
				elseif SubCommand == "take" then
					Economy:Take(Targets[i], Amount)
				elseif SubCommand == "clear" then
					Economy:Clear(Targets[i])
				elseif SubCommand == "set" then
					Economy:Set(Targets[i], Amount)
				end
			end
		end
	}
	self.Commands["PAY"] = {
		Name = "PAY";
		Description = "Pays a nearby Player a set amount of cull."; 
		CommandType = "Utility";
		Level = 1; 
		Arguments = "[Target] [Amount]";
		Function = function(Player, Target, Amount)
			local Targets = (Target and self:GetTarget(Player, Target))
			Amount = (Amount and string.match(Amount, "%d+"))
			
			if Amount ~= "" then
				Amount = (Amount and tonumber(Amount))
			end
			
			
			if Targets and Targets[1] and Amount then
				Economy:StartTransfer(Player, Targets[1], Amount)
			end
		end
	}


	
	--// LORE RELATED
	self.Commands["ADDEXP"] = {
		Name = "ADDEXP";
		Description = "Gives the user a specified lore experience"; 
		CommandType = "Lore";
		Level = 5; 
		Type = "Lore Management";
		Arguments = "[Target] [Experience Name]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)	
			local Experience = table.concat({...}, " ")
			if Targets then
				for i = 1, #Targets do
					LoreExperiences:Add(Targets[i], Experience, Player)
				end
			end
		end
	}
	self.Commands["DELEXP"] = {
		Name = "DELEXP";
		Description = "Removes a specified lore experience from a user."; 
		CommandType = "Lore";
		Level = 5; 
		Type = "Lore Management";
		Arguments = "[Target] [Experience Name]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)	
			local Experience = table.concat({...}, " ")

			if Targets then
				for i = 1, #Targets do
					LoreExperiences:Remove(Targets[i], Experience, Player)
				end
			end
		end
	}
	self.Commands["NAME"] = {
		Name = "NAME";
		Description = "Gives the user a specified lore name"; 
		CommandType = "Lore";
		Level = 4; 
		Type = "Lore Management";
		Arguments = "[New Name]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)
			local NewName = table.concat({...}, " ")
			local Result = (NewName and TextService:FilterStringAsync(NewName, Player.UserId))
			
			if Result and Targets then
				NewName = Result:GetNonChatStringForUserAsync(Player.UserId)
				for i = 1, #Targets do
					Targets[i]:SetAttribute("LoreName", NewName)
			
					--if User.Character and User.Character:FindFirstChild("Nametag") then
					--	local Title = User.Character.Nametag:FindFirstChild("Title", true)
					--	if Title then
					--		Title.Text = NewName
					--	end
					--end
				end
			end
		end
	}
	self.Commands["ROLE"] = {
		Name = "ROLE";
		Description = "Gives the user a specified lore title/occupation/role"; 
		CommandType = "Lore";
		Level = 4; 
		Type = "Lore Management";
		Arguments = "[New Role]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)
			local NewRole = table.concat({...}, " ")
			local Result = (NewRole and TextService:FilterStringAsync(NewRole, Player.UserId))
			
			if Result and Targets then
				NewRole = Result:GetNonChatStringForUserAsync(Player.UserId)
				for i = 1, #Targets do
					Targets[i]:SetAttribute("LoreTitle", NewRole)
				end
			end
		end
	}
	self.Commands["WIPE"] = {
		Name = "WIPE";
		Description = "Wipe's a particular user's data."; 
		CommandType = "Lore";
		Level = 5; 
		Type = "Lore Management";
		Arguments = "[Username]", 
		Function = function(Player, Reference)
			
			local Success, Result = pcall(function()
				local UserId = game.Players:GetUserIdFromNameAsync(Reference)
				local Player = (UserId and game.Players:GetPlayerByUserId(UserId))
				
				if UserId then
					DataService:WipeProfile(UserId):andThen(function()
						UIService:SendUIPrompt(Player, "Narration", {
							Message = string.format("Successfully cleared %s's User Data.", Reference)
						})
						
						if Player then
							Player:Kick("Your UserData has been wiped manually by a T:F Staff Member. Please rejoin.")
						end
					end):catch(function()
						UIService:SendUIPrompt(Player, "Narration", {
							Message = string.format("Could not clear %s's User Data.", Reference)
						})
					end)
				end
				
				return
			end)
		end
	}
	
	
	--// MESSAGES & NOTIFICATIONS
	self.Commands["M"] = { -- // Done
		Name = "M";
		Description = "Sends a server-wide message to all users."; 
		CommandType = "Utility";
		Level = 2; 
		Arguments = "[Message]", 
		Function = function(Player, ...)
			local Message = table.concat({...}, " ")
			Message = self:Filter(Player, Message)
			
			print(Message)
			UIService:Replicate("All", {
				Task = "Message";
				Type = "User";
				UserId = Player.UserId;
				Message = Message;
			});
			
		end
	}
	self.Commands["SM"] = { -- // Done
		Name = "M";
		Description = "Sends a server-wide system message to all users."; 
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Message]", 
		Function = function(Player, ...)
			local Message = table.concat({...}, " ")
			Message = self:Filter(Player, Message)

			UIService:Replicate("All", {
				Task = "Message";
				Type = "System";
				Message = Message;
			});
			
		end
	}
	self.Commands["N"] = { -- // Done
		Name = "N";
		Description = "Creates a banner message for all players."; 
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Message]", 
		Function = function(Player, ...)
			local Message = table.concat({...}, " ")
			local FilteredTextResult = game.TextService:FilterStringAsync(Message, Player.UserId)
			if FilteredTextResult then
				Message = string.gsub(FilteredTextResult:GetNonChatStringForUserAsync(Player.UserId), "#", ".")
			end
			
			self.Notice = {
				Enabled = (Message ~= "");
				Message = Message
			}
			
			UIService:Replicate("All", {
				Task = "Notice";
				SubTask = "Create";
				Is_Priority = false;
				Message = Message;
			});
		end
	}
	self.Commands["PN"] = { -- // Done
		Name = "PN";
		Description = "Adds a priority banner to the tops of Player's screens."; 
		CommandType = "Utility";
		Level = 4; 
		Arguments = "[Message]", 
		Function = function(Player, ...)
			local Message = table.concat({...}, " ")
			local FilteredTextResult = game.TextService:FilterStringAsync(Message, Player.UserId)
			if FilteredTextResult then
				Message = string.gsub(FilteredTextResult:GetNonChatStringForUserAsync(Player.UserId), "#", ".")
			end
			
			self.Notice = {
				Enabled = (Message ~= "");
				Message = string.format("«!» %s «!»", Message);
				IsPriority = true;
			}
			
			UIService:Replicate("All", {
				Task = "Notice";
				SubTask = "Create";
				Is_Priority = true;
				Message = string.format("«!» %s «!»", Message);
			});
		end
	}
	self.Commands["RN"] = { -- // Done
		Name = "RN";
		Description = "Removes the banner message from all players."; 
		CommandType = "Utility";
		Level = 4; 
		Arguments = "", 
		Function = function(Player, ...)
			local Message = table.concat({...}, " ")
			local FilteredTextResult = game.TextService:FilterStringAsync(Message, Player.UserId)
			if FilteredTextResult then
				Message = string.gsub(FilteredTextResult:GetNonChatStringForUserAsync(Player.UserId), "#", ".")
			end

			self.Notice = {
				Enabled = false;
			}
			
			UIService:Replicate("All", {
				Task = "Notice";
				SubTask = "Destroy";
			});
		end
	}
	
	
	self.Commands["ADDACCESSORY"] = { --// Done
		Name = "ADDACCESSORY";
		Description = "Gives the user a specified Accessory from the model folder."; 
		CommandType = "Utility";
		Level = 5; 
		Type = "Lore Management";
		Arguments = "[Target] [Accessory Name]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)
			local Name = table.concat({...}, " ")
			if Targets then
				for i = 1, #Targets do
					local User = Targets[i]
					for _, Accessory in pairs(Server_Dependents.Accessories:GetChildren()) do
						if string.lower(Accessory.Name) == string.lower(Name) then
							if User.Character and not User.Character:FindFirstChild(Accessory.Name) then
								Accessory:Clone().Parent = User.Character
							end
						end
					end
				end
			end
		end
	}
	self.Commands["DELACCESSORY"] = { --// Done
		Name = "DELACCESSORY";
		Description = "Removes a specified accessory from a user."; 
		CommandType = "Utility";
		Level = 5; 
		Type = "Lore Management";
		Arguments = "[Target] [Accessory Name]", 
		Function = function(Player, Target, ...)
			local Targets = self:GetTarget(Player, Target)	
			local Name = table.concat({...}, " ")

			if Targets then
				for i = 1, #Targets do
					local User = Targets[i]
					if User.Character then
						for _, Accessory in pairs(User.Character:GetChildren()) do
							if Accessory.ClassName == "Accessory" and string.find(string.lower(Accessory.Name), string.lower(Name)) then
								Debris(Accessory)
							end
						end
					end
				end
			end
		end
	}
	
	
	--// LISTS
	self.Commands["COMMANDS"] = {
		Name = "COMMANDS";
		Description = "View a list of all commands."; 
		CommandType = "Information";
		Level = 1;
		Type = "List";
		Function = function(Player)
			local Current_Role = self:GetCurrentRole(Player)
			local Listed = {}
			local Properties = {
				Task = "List";
				Title = "United Paths Commands";
				Description = "This is a filtered list of commands at your disposal. Usage is strictly monitored.";
				List = {};
			}
			
			for _, Command in pairs(self.Commands) do
				if (not Command.Level or Command.Level and Current_Role.Level >= Command.Level) then
					if Listed[Command.Name] then continue end
					
					local Minimum_Role = self:GetRoleInfo(Command.Level) or self:GetRoleInfo(1)
					local Arguments = Command.Arguments or ""
					local Role_Tag = Format(Minimum_Role.Name, {Color = Minimum_Role.Color})
					local Command_Type_Tag = Command.CommandType or "Utility"
					
					Listed[Command.Name] = true
					table.insert(Properties.List, {
						Title = Command.Name;
						Level = Command.Level or 1;
						Tags = {{Minimum_Role.Name, Minimum_Role.Color}, {Command_Type_Tag, System.Command_Types[Command_Type_Tag]}};
					})
				end
			end

			table.sort(Properties.List, function(a, b)
				return (a.Level and b.Level and a.Level > b.Level)
			end)
			
			UIService:Replicate(Player, Properties)
		end
	}
	self.Commands.CMDS = self.Commands.COMMANDS -- alias
	
	self.Commands["TOOLS"] = {
		Name = "COMMANDS";
		Description = "View a list of all items."; 
		CommandType = "Information";
		Level = 3;
		Type = "List";
		Function = function(Player)
			local Listed = {}
			local Properties = {
				Task = "List";
				Title = "Unified Paths: Items";
				Description = "A list of all known items within The Unified Paths";
				TagsEnabled = true;
				List = {};
			}
			
			for _, Tool in pairs(Server_Dependents.Tools:GetDescendants()) do
				if Tool.ClassName == "Tool" and not Listed[Tool.Name] then
					Listed[Tool.Name] = true
					table.insert(Properties.List, {
						Title = Tool.Name;
						Tags = {{"Tool"}};
					})
				end
			end
			
			UIService:Replicate(Player, Properties)
		end
	}
	self.Commands["EXPERIENCES"] = {
		Name = "EXPERIENCES";
		Description = "View all game experiences."; 
		CommandType = "Information";
		Level = 4;
		Type = "List";
		Function = function(Player)
			local Current_Role = self:GetCurrentRole(Player)
			local Listed = {}
			local Properties = {
				Title = "The Fall: Lore Experiences";
				Description = "This is a list of all the unlockable lore experiences/achievements in the game.";
				TagsEnabled = true;
				List = {};
			}
			
			if not ExperienceIndex then
				ExperienceIndex = require(Framework.Information.Experiences);
			end
			
			for Name, Info in pairs(ExperienceIndex) do
				if type(Info) ~= "table" then continue end
				if Listed[Name] then continue end
				
				local Color = Info.Color ~= nil and Info.Color or Library.Color.White
				local Organization = Info.Organization and Format(Info.Organization, {Color = Color})
				local ID = Info.Id and string.format("ID: %s", Format(Info.Id, {Color = Color}))
				
				Listed[Name] = true
				table.insert(Properties.List, {
					Title = Format(Name, {Color = Color});
					Level = Info.Level or 1;
					Tags = {Organization, ID};
				})
			end
			
			table.sort(Properties.List, function(a, b)
				return (a.Level and b.Level and a.Level > b.Level)
			end)

			UIService:SendUIPrompt(Player, "List", Properties)
		end
	}
	self.Commands["ACCESSORIES"] = {
		Name = "ACCESSORIES";
		Description = "View all game Accessories."; 
		CommandType = "Information";
		Level = 4;
		Type = "List";
		Function = function(Player)
			local Current_Role = self:GetCurrentRole(Player)
			local Listed = {}
			local Properties = {
				Title = "The Fall: Accessories";
				Description = "This is a list of all the accessories that can be toggled onto an avatar.";
				TagsEnabled = true;
				List = {};
			}

			for _, Accessory in pairs(Server_Dependents.Models.Accessory:GetDescendants()) do
				if Accessory.ClassName == "Accessory" then
					if Listed[Accessory.Name] then continue end
					Listed[Accessory.Name] = true
					table.insert(Properties.List, {
						Title = Accessory.Name;
						Tags = {"Lore Accessory"};
					})
				end
			end
			
			UIService:SendUIPrompt(Player, "List", Properties)
		end
	}
end

return System
