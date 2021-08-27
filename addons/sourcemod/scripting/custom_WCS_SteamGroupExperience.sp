// List of Includes
#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <clientprefs>
#include <SteamWorks>

// The code formatting rules we wish to follow
#pragma semicolon 1;
#pragma newdecls required;


// The retrievable information about the plugin itself 
public Plugin myinfo =
{
	name		= "[CS:GO] Steam Group Experience",
	author		= "Manifest @Road To Glory",
	description	= "Players in your steam group receives additional experience.",
	version		= "V. 1.0.0 [Beta]",
	url			= ""
};


// Booleans
bool IsMemberOfSteamGroup[MAXPLAYERS + 1];

// Config Convars
Handle cvar_SteamGroupID;
Handle cvar_SteamGroupKillExp;
Handle cvar_SteamGroupRoundStartExp;

// Cookie Variables
bool option_steamgroup_message[MAXPLAYERS + 1] = {true,...};
Handle cookie_steamgroup_message = INVALID_HANDLE;


public void OnPluginStart()
{
	// Hooks the events that we intend to use in our plugin
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);

	// Our list of Convars
	cvar_SteamGroupID = CreateConVar("mani_SteamGroupID", "35073621", "The ID of the Steam Group the player must be a member of in order to receive the bonus experience - [Default = 35073621]");
	cvar_SteamGroupKillExp = CreateConVar("mani_SteamGroupKillExp", "5", "The amount of bonus experience points to award a player with for each kill if they are a member of the Steam Group - [Default = 5]");
	cvar_SteamGroupRoundStartExp = CreateConVar("mani_SteamGroupRoundStartExp", "20", "The amount of bonus experience points to award a player with at the start of each round if they are a member of the Steam Group - [Default = 20]");

	// Cookie Stuff
	cookie_steamgroup_message = RegClientCookie("SG Messages On/Off 1", "sgmsg1337", CookieAccess_Private);
	SetCookieMenuItem(CookieMenuHandler_steamgroup_message, cookie_steamgroup_message, "SG Messages");

	// Automatically generates a config file that contains our variables
	AutoExecConfig(true, "custom_WCS_SteamGroupExperience");

	// Loads the multi-language translation file
	LoadTranslations("custom_WCS_SteamGroupExperience.phrases");
}


// This happens briefly after a client has connected to the server and been validated
public void OnClientPostAdminCheck(int client)
{
	// If the client meets our criteria of validation then execute this section
	if (IsValidClient(client))
	{
		// If the player is not a bot then execute this section
		if (!IsFakeClient(client))
		{
			// Sets the player to not be a member of the steam group
			IsMemberOfSteamGroup[client] = false;

			// 	if(!SteamWorks_GetUserGroupStatus(client, SteamGroupID.IntValue))
			if(!SteamWorks_GetUserGroupStatus(client, GetConVarInt(cvar_SteamGroupID)))
			{
				// Put out a logging error
				LogError("[WCS SteamGroup Experience] Couldn't get the group of: %N", client);
			}
		}
	}
}


// This happens every time a player spawns
public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// Creates an integer variable matching our cvar_SteamGroupKillExp convar's value
	int SteamGroupKillExp = GetConVarInt(cvar_SteamGroupKillExp);
	if(SteamGroupKillExp > 0)
	{
		// Obtains the victim and attacker's userids and store them within the respective variables: client and attacker
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		// If Both the client and the attacker meets our criteria of client validation then execute this section
		if(IsValidClient(client) && IsValidClient(attacker))
		{
			// If the player is not a bot then execute this section
			if (!IsFakeClient(attacker))
			{
				// If the player is a member of our steam group then execute this section
				if (IsMemberOfSteamGroup[attacker])
				{
					// We create a variable named attackerid which we need as Source-Python commands uses userid's instead of indexes
					int attackerid = GetEventInt(event, "attacker");

					// Creates a variable named ServerCommandMessage which we'll store our message data within
					char ServerCommandMessage[128];

					// Formats a message and store it within our ServerCommandMessage variable
					FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_givexp %i %i", attackerid, SteamGroupKillExp);

					// Executes our GiveLevel server command on the player, to award them with levels
					ServerCommand(ServerCommandMessage);

					if (option_steamgroup_message[attacker])
					{
						// Prints a message to the attacker's chat
						CPrintToChat(attacker, "%t", "Steam Group Experience Kill", SteamGroupKillExp);
					}
				}
			}
		}
	}
}


// This happens every time a new round starts
public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	// Creates an integer variable matching our cvar_SteamGroupRoundStartExp convar's value
	int SteamGroupRoundStartExp = GetConVarInt(cvar_SteamGroupRoundStartExp);
	if(SteamGroupRoundStartExp > 0)
	{
		// Execute this section if the round is a warmup round 
		if (GameRules_GetProp("m_bWarmupPeriod") == 1)
		{
			// We don't want to award players for playing the warmup round as not all players may be connected yet
			return Plugin_Handled;
		}

		// Loops through all the players online
		for(int i = 1 ;i <= MaxClients; i++)
		{
			// If the client meets our criteria of validation then execute this section
			if (IsValidClient(i))
			{
				// If the client is on either the Terrorist or Counter-Terrorist team then execute this section
				if(GetClientTeam(i) <= 2)
				{
					// If the client is alive then execute this section
					if(IsPlayerAlive(i))
					{
						// If the player is a member of our steam group then execute this section
						if (IsMemberOfSteamGroup[i])
						{
							// We create a variable named userid which we need as Source-Python commands uses userid's instead of indexes
							int userid = GetClientUserId(i);

							// Creates a variable named ServerCommandMessage which we'll store our message data within
							char ServerCommandMessage[128];

							// Formats a message and store it within our ServerCommandMessage variable
							FormatEx(ServerCommandMessage, sizeof(ServerCommandMessage), "wcs_givexp %i %i", userid, SteamGroupRoundStartExp);

							// Executes our GiveLevel server command on the player, to award them with levels
							ServerCommand(ServerCommandMessage);

							if (option_steamgroup_message[i])
							{
								// Prints a message to the player's chat
								CPrintToChat(i, "%t", "Steam Group Experience Round Start", SteamGroupRoundStartExp);
							}
						}
					}
				}
			}
		}
	}

	return Plugin_Handled;
}


public int SteamWorks_OnClientGroupStatus(int authid, int groupAccountID, bool isMember, bool isOfficer)
{
	// Calls the result of our UserAuthGrab function and store it within our variable named client
	int client = VerifyExistingID(authid);

	// If the client meets our criteria of validation then execute this section
	if (IsValidClient(client))
	{
		// If the player is not a bot then execute this section
		if (!IsFakeClient(client))
		{
			// Is the player in the steam group?
			if(isMember)
			{
				// Sets the player to be considered a member of the steam group
				IsMemberOfSteamGroup[client] = true;
			}
		}
	}

	return;
}


// This happens when we call upon our function when our steam group status is being checked
int VerifyExistingID(int authid)
{
	// Loops through all the players online
	for (int i = 1; i <= MaxClients; i++)
	{
		// If the client meets our criteria of validation then execute this section
		if (IsValidClient(i))
		{
			// If the player is not a bot then execute this section
			if (!IsFakeClient(i))
			{
				char PlayerSteamID3[64];
				char AuthenticationString[64];

				// If it is possible to obtain our clients SteamID3 then proceed 
				if(GetClientAuthId(i, AuthId_Steam3, PlayerSteamID3, sizeof(PlayerSteamID3)))
				{
					// Changes the authid from an integer to a string
					IntToString(authid, AuthenticationString, sizeof(AuthenticationString));

					// Compares the SteamID3 with our AuthenticationString
					if(StrContains(PlayerSteamID3, AuthenticationString) != -1)
					{
						return i;
					}
				}
			}
		}
	}

	return -1;
}


// We call upon this true and false statement whenever we wish to validate our player
bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}

	return true;
}


// Cookie Stuff Below
public void OnClientCookiesCached(int client)
{
	option_steamgroup_message[client] = GetCookiesteamgroup_message(client);
}


bool GetCookiesteamgroup_message(int client)
{
	char buffer[10];

	GetClientCookie(client, cookie_steamgroup_message, buffer, sizeof(buffer));
	
	return !StrEqual(buffer, "Off");
}


public void CookieMenuHandler_steamgroup_message(int client, CookieMenuAction action, any steamgroup_message, char[] buffer, int maxlen)
{	
	if (action == CookieMenuAction_DisplayOption)
	{
		char status[16];
		if (option_steamgroup_message[client])
		{
			Format(status, sizeof(status), "%s", "[ON]", client);
		}
		else
		{
			Format(status, sizeof(status), "%s", "[OFF]", client);
		}
		
		Format(buffer, maxlen, "EXP Steam Group Messages: %s", status);
	}
	else
	{
		option_steamgroup_message[client] = !option_steamgroup_message[client];
		
		if (option_steamgroup_message[client])
		{
			SetClientCookie(client, cookie_steamgroup_message, "On");
			CPrintToChat(client, "%t", "Steam Group Experience Messages Enabled");
		}
		else
		{
			SetClientCookie(client, cookie_steamgroup_message, "Off");
			CPrintToChat(client, "%t", "Steam Group Experience Messages Disabled");
		}
		
		ShowCookieMenu(client);
	}
}
