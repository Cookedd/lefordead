#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <collisionhook>

#define ENTITY_NAME_MAX_LENGTH			32
#define PLUGIN_PREFIX					"CollisionHook"

#define DEBUG_FLAG_NONE					0
#define DEBUG_FLAG_SHOULDCOLLIDE		(1 << 0)
#define DEBUG_FLAG_PASSFILTER			(1 << 1)
#define DEBUG_FLAGS_ALL					DEBUG_FLAG_SHOULDCOLLIDE|DEBUG_FLAG_PASSFILTER

#define DEBUG_FLAG_RESULT_FALSE			(1 << 0)
#define DEBUG_FLAG_RESULT_TRUE			(1 << 1)
#define DEBUG_FLAGS_RESULT_ALL			DEBUG_FLAG_RESULT_TRUE|DEBUG_FLAG_RESULT_FALSE

#define DEBUG_MESSAGE_CHAT				(1 << 0)
#define DEBUG_MESSAGE_SERVER_CONSOLE	(1 << 1)

bool
	g_bNotePrinted = false;

StringMap
	g_hAllowedEntitiesMap = null;

ConVar
	g_hDebugFlags = null,
	g_hDebugReturnFlags = null,
	g_hDebugMsgType = null;

public Plugin myinfo = 
{
	name = "CollisionHook - Tester",
	author = "A1m`",
	description = "Testing the functionality of CollisionHook API.",
	version = "2.2",
	url = "https://github.com/L4D-Community/Collisionhook"
};

public void OnPluginStart()
{
	g_hAllowedEntitiesMap = new StringMap();

	char sValue[16], sDescription[128];

	IntToString(DEBUG_FLAGS_ALL, sValue, sizeof(sValue));
	Format(sDescription, sizeof(sDescription), "Show debug messages for: %d - disable messages, %d - ShouldCollide, %d - PassFilter, %d - for all.", \
											DEBUG_FLAG_NONE, DEBUG_FLAG_SHOULDCOLLIDE, DEBUG_FLAG_PASSFILTER, DEBUG_FLAGS_ALL);
	
	g_hDebugFlags = CreateConVar("ch_debug_flags", sValue, sDescription, _, true, float(DEBUG_FLAG_NONE), true, float(DEBUG_FLAGS_ALL));

	IntToString(DEBUG_FLAGS_RESULT_ALL, sValue, sizeof(sValue));
	Format(sDescription, sizeof(sDescription), "Show only cases where entities: %d - do not collide, %d - collide, %d - all cases.", \
											DEBUG_FLAG_RESULT_FALSE, DEBUG_FLAG_RESULT_TRUE, DEBUG_FLAGS_RESULT_ALL);

	g_hDebugReturnFlags = CreateConVar("ch_debug_return_flags", sValue, sDescription, _, true, float(DEBUG_FLAG_NONE), true, float(DEBUG_FLAGS_RESULT_ALL));

	IntToString(DEBUG_MESSAGE_SERVER_CONSOLE, sValue, sizeof(sValue));
	Format(sDescription, sizeof(sDescription), "Where to show debug messages: %d - in the chat for players, %d - in the server console.", \
											DEBUG_MESSAGE_CHAT, DEBUG_MESSAGE_SERVER_CONSOLE);

	g_hDebugMsgType = CreateConVar("ch_debug_msg_type", sValue, sDescription, _, true, float(DEBUG_MESSAGE_CHAT), true, float(DEBUG_MESSAGE_SERVER_CONSOLE));

	// Debug messages will only be printed when the specified entities collide.
	RegAdminCmd("ch_add_entity", Cmd_AddAllowedEntity, ADMFLAG_ROOT);
	RegAdminCmd("ch_remove_entity", Cmd_RemoveAllowedEntity, ADMFLAG_ROOT);
	RegAdminCmd("ch_remove_all", Cmd_RemoveAllAllowedEntities, ADMFLAG_ROOT);
}

public Action CH_ShouldCollide(int iEntity1, int iEntity2, bool &bResult)
{
	DebugMessage(DEBUG_FLAG_SHOULDCOLLIDE, "CH_ShouldCollide", iEntity1, iEntity2, bResult);

	return Plugin_Continue;
}

public Action CH_PassFilter(int iEntity1, int iEntity2, bool &bResult)
{
	DebugMessage(DEBUG_FLAG_PASSFILTER, "CH_PassFilter", iEntity1, iEntity2, bResult);

	return Plugin_Continue;
}

Action Cmd_AddAllowedEntity(int iClient, int iArgs)
{
	PrintNote(iClient);

	if (iArgs != 1) {
		ReplyToCommand(iClient, "[%s] You did not enter an entity name!", PLUGIN_PREFIX);
		
		return Plugin_Handled;
	}

	char sEntityName[ENTITY_NAME_MAX_LENGTH];
	GetCmdArg(1, sEntityName, sizeof(sEntityName));

	int iValue;
	if (g_hAllowedEntitiesMap.GetValue(sEntityName, iValue)) {
		ReplyToCommand(iClient, "[%s] The specified entity '%s' has already been added!", PLUGIN_PREFIX, sEntityName);

		return Plugin_Handled;
	}

	g_hAllowedEntitiesMap.SetValue(sEntityName, 0, false);

	ReplyToCommand(iClient, "[%s] The specified entity '%s' was added successfully!", PLUGIN_PREFIX, sEntityName);

	return Plugin_Handled;
}

Action Cmd_RemoveAllowedEntity(int iClient, int iArgs)
{
	PrintNote(iClient);

	if (g_hAllowedEntitiesMap.Size <= 0) {
		ReplyToCommand(iClient, "[%s] The array is completely empty you cannot remove any entity from it!", PLUGIN_PREFIX);

		return Plugin_Handled;
	}

	if (iArgs != 1) {
		ReplyToCommand(iClient, "[%s] You did not enter an entity name!", PLUGIN_PREFIX);

		return Plugin_Handled;
	}

	char sEntityName[ENTITY_NAME_MAX_LENGTH];
	GetCmdArg(1, sEntityName, sizeof(sEntityName));

	int iValue;
	if (!g_hAllowedEntitiesMap.GetValue(sEntityName, iValue)) {
		ReplyToCommand(iClient, "[%s] The specified entity '%s' was not found in the array and could not be removed!", PLUGIN_PREFIX, sEntityName);

		return Plugin_Handled;
	}

	g_hAllowedEntitiesMap.Remove(sEntityName);

	ReplyToCommand(iClient, "[%s] The specified entity '%s' was deleted successfully!", PLUGIN_PREFIX, sEntityName);

	return Plugin_Handled;
}

Action Cmd_RemoveAllAllowedEntities(int iClient, int iArgs)
{
	PrintNote(iClient);

	if (g_hAllowedEntitiesMap.Size <= 0) {
		ReplyToCommand(iClient, "[%s] The array is completely empty you cannot remove any entity from it!", PLUGIN_PREFIX);

		return Plugin_Handled;
	}

	g_hAllowedEntitiesMap.Clear();
	g_bNotePrinted = false;

	ReplyToCommand(iClient, "[%s] The array is completely cleared!", PLUGIN_PREFIX);

	return Plugin_Handled;
}

void PrintNote(int iClient)
{
	if (g_bNotePrinted) {
		return;
	}

	ReplyToCommand(iClient, "[%s] Debug messages will only be printed when the specified entities collide!", PLUGIN_PREFIX);

	g_bNotePrinted = true;
}

void DebugMessage(int iDebugFlag, const char[] sFuncName, int iEntity1, int iEntity2, bool bResult)
{
	if (!(g_hDebugFlags.IntValue & iDebugFlag)) {
		return;
	}

	int iReturnResultFlag = (!bResult) ? DEBUG_FLAG_RESULT_FALSE : DEBUG_FLAG_RESULT_TRUE;
	if (!(g_hDebugReturnFlags.IntValue & iReturnResultFlag)) {
		return;
	}

	char sEntityName1[ENTITY_NAME_MAX_LENGTH], sEntityName2[ENTITY_NAME_MAX_LENGTH];
	GetEntityNameIsValid(iEntity1, sEntityName1, sizeof(sEntityName1));
	GetEntityNameIsValid(iEntity2, sEntityName2, sizeof(sEntityName2));

	if (g_hAllowedEntitiesMap.Size > 0) {
		int iValue = 0;

		if (!g_hAllowedEntitiesMap.GetValue(sEntityName1, iValue) && !g_hAllowedEntitiesMap.GetValue(sEntityName2, iValue)) {
			return;
		}
	}

	if (g_hDebugMsgType.IntValue & DEBUG_MESSAGE_CHAT) {
		PrintToChatAll("[%s] iEntity1: %s (%d), iEntity2: %s (%d), result: %d!", sFuncName, sEntityName1, iEntity1, sEntityName2, iEntity2, bResult);

		return;
	}

	PrintToServer("[%s] iEntity1: %s (%d), iEntity2: %s (%d), result: %d!", sFuncName, sEntityName1, iEntity1, sEntityName2, iEntity2, bResult);
}

bool GetEntityNameIsValid(int iEntity, char[] sEntityName, const int iMaxLength)
{
	if (iEntity < 0 || !IsValidEntity(iEntity)) {
		FormatEx(sEntityName, iMaxLength, "Invalid entity");

		return false;
	}

	// world and entities
	if (iEntity == 0 || iEntity > MaxClients) {
		GetEntityClassname(iEntity, sEntityName, iMaxLength);

		return true;
	}

	GetClientName(iEntity, sEntityName, iMaxLength);

	return true;
}