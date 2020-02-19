#include <sourcemod>
#include <colorlib>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Show Online Admins",
    author = "Ilusion9",
    description = "Show online admins by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

#define MAX_GROUPS		65
enum struct GroupInfo
{
	char name[64];
	char color[64];
	int flag;
	bool useTranslation;
}

bool g_IsHiddenAdmin[MAXPLAYERS + 1];
GroupInfo g_Groups[MAX_GROUPS];
int g_GroupsArrayLength;

public void OnPluginStart()
{
	LoadTranslations("groups_online.phrases");
	LoadTranslations("groups_name.phrases");
	
	RegAdminCmd("sm_admins", Command_Admins, ADMFLAG_GENERIC, "Usage: sm_admins [visible|hidden] - Show online admins by groups");
}

public void OnConfigsExecuted()
{
	g_GroupsArrayLength = 0;
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/groups_online.cfg");
	KeyValues kv = new KeyValues("Groups"); 
	
	if (!kv.ImportFromFile(path))
	{
		delete kv;
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (!kv.JumpToKey("Admin Groups"))
	{
		delete kv;
		LogError("The configuration file is corrupt (\"Admin Groups\" section could not be found).");
		return;
	}
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			char buffer[65];
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			
			kv.GetString("flag", buffer, sizeof(buffer));
			if (!FindFlagByChar(buffer[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			kv.GetString("color", group.color, sizeof(GroupInfo::color));
			
			kv.GetString("translation", buffer, sizeof(buffer));
			if (StrEqual(buffer, "yes", false))
			{
				group.useTranslation = true;
			}
			else
			{
				group.useTranslation = false;
			}
			
			g_Groups[g_GroupsArrayLength] = group;
			g_GroupsArrayLength++;
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public void OnClientConnected(int client)
{
	g_IsHiddenAdmin[client] = false;
}

public Action Command_Admins(int client, int args)
{
	if (!g_GroupsArrayLength)
	{
		return Plugin_Handled;
	}
	
	if (args)
	{
		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));
		
		if (StrEqual(arg, "visible", false))
		{
			if (IsClientMemberOfAnyGroup(client))
			{
				g_IsHiddenAdmin[client] = false;
				CReplyToCommand(client, "[SM] %t", "Visible Admin Command");
			}
			else
			{
				CReplyToCommand(client, "[SM] %t", "No Feature Access");
			}
			
			return Plugin_Handled;
		}
		
		if (StrEqual(arg, "hidden", false))
		{
			if (IsClientMemberOfAnyGroup(client))
			{
				g_IsHiddenAdmin[client] = true;
				CReplyToCommand(client, "[SM] %t", "Hidden Admin Command");
			}
			else
			{
				CReplyToCommand(client, "[SM] %t", "No Feature Access");
			}
			
			return Plugin_Handled;
		}
	}
	
	bool membersOnline = false;
	int groupCount[MAX_GROUPS];
	int groupMembers[MAX_GROUPS][MAXPLAYERS + 1];
	
	for (int player = 1; player <= MaxClients; player++)
	{
		if (!IsClientInGame(player) || IsFakeClient(player))
		{
			continue;
		}
		
		for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
		{
			if (!CheckCommandAccess(player, "", g_Groups[groupIndex].flag, true))
			{
				continue;
			}
			
			membersOnline = true;
			groupMembers[groupIndex][groupCount[groupIndex]] = player;
			groupCount[groupIndex]++;
			break;
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
		return Plugin_Handled;
	}
	
	membersOnline = false;
	for (int groupIndex = 0; groupIndex < g_GroupsArrayLength; groupIndex++)
	{
		if (!groupCount[groupIndex])
		{
			continue;
		}
		
		int msgLength, playersShown;
		char name[33], buffer[256];
		bool clientHasAccess = CheckCommandAccess(client, "", g_Groups[groupIndex].flag, true);
		
		if (g_Groups[groupIndex].useTranslation)
		{
			Format(buffer, sizeof(buffer), "{%s}%t:{default}", g_Groups[groupIndex].color, g_Groups[groupIndex].name);
		}
		else
		{
			Format(buffer, sizeof(buffer), "{%s}%s:{default}", g_Groups[groupIndex].color, g_Groups[groupIndex].name);
		}
		
		msgLength = strlen(buffer);
		for (int index = 0; index < groupCount[groupIndex]; index++)
		{
			int player = groupMembers[groupIndex][index];
			if (g_IsHiddenAdmin[player] && !clientHasAccess)
			{
				continue;
			}
			
			membersOnline = true;
			GetClientName(player, name, sizeof(name));
			CRemoveTags(name, sizeof(name));
			msgLength += strlen(name) + 2;
			
			if (msgLength > 192)
			{
				CReplyToCommand(client, "%s", buffer);
				if (g_Groups[groupIndex].useTranslation)
				{
					Format(buffer, sizeof(buffer), "{%s}%t:{default}", g_Groups[groupIndex].color, g_Groups[groupIndex].name);
				}
				else
				{
					Format(buffer, sizeof(buffer), "{%s}%s:{default}", g_Groups[groupIndex].color, g_Groups[groupIndex].name);
				}
				
				msgLength += strlen(buffer);
				playersShown = 1;
			}
			
			Format(buffer, sizeof(buffer), "%s%s %s", buffer, playersShown ? "," : "", name);
			playersShown++;
		}
		
		if (playersShown)
		{
			CReplyToCommand(client, "%s", buffer);
		}
	}
	
	if (!membersOnline)
	{
		CReplyToCommand(client, "%t", "No Admins Online");
	}
	
	return Plugin_Handled;
}

bool IsClientMemberOfAnyGroup(int client)
{
	for (int i = 0; i < g_GroupsArrayLength; i++)
	{
		if (CheckCommandAccess(client, "", g_Groups[i].flag, true))
		{
			return true;
		}
	}
	
	return false;
}
