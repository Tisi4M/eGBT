#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Tisi4M.^"
#define PLUGIN_VERSION "1.00"

#define PLUGIN_NAME "Enhanced Bring & GoTo"
#define PLUGIN_DESC "Teleport to player or bring him to your origin."
#define PLUGIN_URL "https://github.com/tisi4m"

#include <sourcemod>
#include <sdktools>
#include <multicolors>

#pragma newdecls required

ConVar cvGoToCmds;
ConVar cvBringCmds;
ConVar cvGoToFlag;
char cGoToFlag[2];
ConVar cvBringFlag;
char cBringFlag[2];

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("ebgt.phrases");
	
	cvGoToCmds = CreateConVar("ebg_goto_commands", "egoto, ego, goto, go", "Commands for GoTo function.");
	cvBringCmds = CreateConVar("ebg_bring_commands", "ebring, ebr, bring, br", "Commands for Bring function.");
	cvGoToFlag = CreateConVar("ebg_goto_flag", "b", "Set admin flag to restrict GoTo command usage.\nLeave empty for no restriction.");
	cvBringFlag = CreateConVar("ebg_bring_flag", "b", "Set admin flag to restrict Bring command usage.\nLeave empty for no restriction.");
	
	AutoExecConfig(true, "ebgt");
}

public void OnConfigsExecuted() {
	char cCommands[255];
	cvGoToCmds.GetString(cCommands, sizeof(cCommands));
	RegisterCommands(cCommands, Command_GoTo);
	cvBringCmds.GetString(cCommands, sizeof(cCommands));
	RegisterCommands(cCommands, Command_Bring);
	cvGoToFlag.GetString(cGoToFlag, sizeof(cGoToFlag));
	cvBringFlag.GetString(cBringFlag, sizeof(cBringFlag));
}

public Action Command_GoTo(int client, int args) {
	if (client == 0) {
		PrintToServer("%t", "Command is not allowed from console");
		return Plugin_Continue;
	} else if (!HasAdminFlag(client, cGoToFlag)) {
		return Plugin_Continue;
	} else if (!IsPlayerAlive(client)) {
		CPrintToChat(client, "%t%t", "ChatTag", "You must be alive");
		return Plugin_Continue;
	}
	
	if (args > 0) {
		char arg[255];
		GetCmdArgString(arg, sizeof(arg));
		
		if (strlen(arg) <= 0)
			return Plugin_Continue;
		
		if (arg[0] == '#') {
			strcopy(arg, sizeof(arg), arg[1]);
			int target = StringToInt(arg);
			
			if (target <= 0 || !IsClientInGame(target)) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player by UserId not found" , target);
			} else if (!IsPlayerAlive(target)) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player must be alive", target);
			} else {
				float origin[3];
				GetClientAbsOrigin(target, origin);
				TeleportEntity(target, origin, NULL_VECTOR, NULL_VECTOR);
				if (client != target)
					CPrintToChat(client, "%t%t", "ChatTag", "You've been teleported", target);
			}
		} else {
			int target = -1;
			char targetName[64];
			for (int i = 1; i < MaxClients + 1; i++) {
				if (!IsClientInGame(i) || client == i)
					continue;
				
				Format(targetName, sizeof(targetName), "%N", i);
				if (StrContains(targetName, arg, false) != -1) {
					target = i;
					break;
				}
			}
			
			if (target == -1) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player by name not found", arg);
			} else {
				if (!IsPlayerAlive(target)) {
					CPrintToChat(client, "%t%t", "ChatTag", "Player must be alive", target);
				} else {
					float origin[3];
					GetClientAbsOrigin(target, origin);
					TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
				}
			}
		}	
	} else {
		Menu_GoTo(client);
	}
	
	return Plugin_Handled;
}

void Menu_GoTo(int client, int menuposition = 0) {
	Menu menu = new Menu(Menu_GoToHandler);
	char buffer[128];
	
	menu.SetTitle("%t", "Menu Title - GoTo");
	
	int total = 0;
	char cUserId[5], cNickname[12], cNicknameL[13];
	for (int i = 1; i < MaxClients + 1; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientSourceTV(i) || client == i)
			continue;
		Format(cUserId, sizeof(cUserId), "%i", i);
		Format(cNicknameL, sizeof(cNicknameL), "%N", i);
		Format(cNickname, sizeof(cNickname), "%N%s", i, strlen(cNicknameL) > sizeof(cNickname), "...", "");
		menu.AddItem(cUserId, cNickname);
		total++;
	}
	
	if (total == 0) {
		Format(buffer, sizeof(buffer), "%t", "Menu Item - No players");
		menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	}
	
	menu.DisplayAt(client, menuposition, 60);
}

public int Menu_GoToHandler(Menu menu, MenuAction action, int client, int pos) {
	if (action == MenuAction_Select) {
		char Item[5];
		menu.GetItem(pos, Item, sizeof(Item));
		int target = StringToInt(Item);
		
		if (!IsPlayerAlive(client)) {
			CPrintToChat(client, "%t%t", "ChatTag", "You must be alive");
			return;
		}
		
		float origin[3];
		GetClientAbsOrigin(target, origin);
		TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
		CPrintToChat(client, "%t%t", "ChatTag", "You've been teleported", target);
		CPrintToChat(target, "%t%t", "ChatTag", "Player teleported to your position", client);
		Menu_GoTo(client, GetMenuSelectionPosition());
	}
}

public Action Command_Bring(int client, int args) {
	if (client == 0) {
		PrintToServer("%t", "Command is not allowed from console");
		return Plugin_Continue;
	} else if (!HasAdminFlag(client, cBringFlag)) {
		return Plugin_Continue;
	} else if (!IsPlayerAlive(client)) {
		CPrintToChat(client, "%t%t", "ChatTag", "You must be alive");
		return Plugin_Continue;
	}
	
	if (args > 0) {
		char arg[255];
		GetCmdArgString(arg, sizeof(arg));
		
		if (strlen(arg) <= 0)
			return Plugin_Continue;
		
		float pos[3];
		GetAimOrigin(client, pos);
		
		if (arg[0] == '@') {
			if (StrEqual(arg, "@ct", false)) {
				for (int i = 1; i < MaxClients + 1; i++) {
					if (client == i || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
						continue;
					TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
				}
			} else if (StrEqual(arg, "@t", false)) {
				for (int i = 1; i < MaxClients + 1; i++) {
					if (client == i || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
						continue;
					TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
				}
			} else if (StrEqual(arg, "@all", false)) {
				for (int i = 1; i < MaxClients + 1; i++) {
					if (client == i || !IsClientInGame(i) || !IsPlayerAlive(i))
						continue;
					TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
				}
			} else if (StrEqual(arg, "@me", false)) {
				TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
			}
		} else if (arg[0] == '#') {
			strcopy(arg, sizeof(arg), arg[1]);
			int target = StringToInt(arg);
			
			if (target <= 0 || !IsClientInGame(target)) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player by UserId not found", target);
			} else if (!IsPlayerAlive(target)) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player must be alive", target, target);
			} else {
				TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
				CPrintToChat(client, "%t%t", "ChatTag", "You teleported player", target);
				if (client != target)
					CPrintToChat(target, "%t%t", "ChatTag", "You've been teleported by", client);
			}
			
		} else {
			int target = -1;
			char targetName[64];
			for (int i = 1; i < MaxClients + 1; i++) {
				if (!IsClientInGame(i))
					continue;
				
				Format(targetName, sizeof(targetName), "%N", i);
				if (StrContains(targetName, arg, false) != -1) {
					target = i;
					break;
				}
			}
			
			if (target == -1) {
				CPrintToChat(client, "%t%t", "ChatTag", "Player by name not found", arg);
			} else {
				if (!IsPlayerAlive(target)) {
					CPrintToChat(client, "%t%t", "ChatTag", "Player must be alive", target);
				} else {
					TeleportEntity(target, pos, NULL_VECTOR, NULL_VECTOR);
					if (client != target)
						CPrintToChat(target, "%t%t", "ChatTag", "You've been teleported by", client);
				}
			}
			
		}
	} else {
		Menu_Bring(client);
	}
	
	return Plugin_Handled;
}

void Menu_Bring(int client, int menuposition = 0) {
	Menu menu = new Menu(Menu_BringHandler);
	
	menu.SetTitle("%t", "Menu Title - Bring");
	char buffer[128];
	
	int total = 0;
	char cUserId[5], cNickname[12], cNicknameL[13];
	for (int i = 1; i < MaxClients + 1; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsClientSourceTV(i) || client == i)
			continue;
		Format(cUserId, sizeof(cUserId), "%i", i);
		Format(cNicknameL, sizeof(cNicknameL), "%N", i);
		Format(cNickname, sizeof(cNickname), "%N%s", i, strlen(cNicknameL) > sizeof(cNickname), "...", "");
		menu.AddItem(cUserId, cNickname);
		total++;
	}
	
	if (total == 0) {
		Format(buffer, sizeof(buffer), "%t", "Menu Item - No players");
		menu.AddItem("", buffer, ITEMDRAW_DISABLED);
	}
	
	menu.DisplayAt(client, menuposition, 60);
}

public int Menu_BringHandler(Menu menu, MenuAction action, int client, int pos) {
	if (action == MenuAction_Select) {
		char Item[5];
		menu.GetItem(pos, Item, sizeof(Item));
		int target = StringToInt(Item);
		
		float origin[3];
		GetAimOrigin(client, origin);
		TeleportEntity(target, origin, NULL_VECTOR, NULL_VECTOR);
		CPrintToChat(target, "%t%t", "ChatTag", "You've been teleported by", client);
		CPrintToChat(client, "%t%t", "ChatTag", "You teleported player", target);
		Menu_Bring(client, GetMenuSelectionPosition());
	}
}

public void RegisterCommands(char[] commands, ConCmd callback) {
	if (StrContains(commands, " ") != -1)
		ReplaceString(commands, 255, " ", "");
	char cCmds[12][24], cCmd[24];
	int iCmds = ExplodeString(commands, ",", cCmds, 12, 24);
	for (int i = 0; i < iCmds; i++) 
	{
		Format(cCmd, sizeof(cCmd), "sm_%s", cCmds[i]);
		if (GetCommandFlags(cCmd) == INVALID_FCVAR_FLAGS) {
			RegConsoleCmd(cCmd, callback);
		}
	}
}

bool HasAdminFlag(int client, char[] flag) {
	if (strlen(flag) == 0)
		return true;
	
	AdminId admin = GetUserAdmin(client);
	AdminFlag adminFlag;
	
	if (!FindFlagByChar(flag[0], adminFlag)) {
		return false;
	} else if (!GetAdminFlag(admin, adminFlag)) {
		CPrintToChat(client, "%t%t", "ChatTag", "No access to command");
		return false;
	}
	return true;
}


bool GetAimOrigin(int client, float endPos[3], int mask = MASK_SHOT) {
	float eyepos[3], eyeang[3];
	GetClientEyePosition(client, eyepos);
	GetClientEyeAngles(client, eyeang);
	
	TR_TraceRayFilter(eyepos, eyeang, mask, RayType_Infinite, TraceEntFilterPlayer);
	if(TR_DidHit()) {
		TR_GetEndPosition(endPos);
		return true;
	}
	return false;
}

bool TraceEntFilterPlayer(int entity, int contentsMask) {
    return entity >= MaxClients;
}
