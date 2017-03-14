/*  SM Decapitation
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>




//new g_Hat[MAXPLAYERS+1] = { 0, ...};
new cabeza[MAXPLAYERS+1];
new mochas[MAXPLAYERS+1];
new bool:decapitado[MAXPLAYERS+1];
//new bool:erroneo[MAXPLAYERS+1];
new Handle:cvar_sonido;
new Handle:cvar_mochas;
new Handle:cvar_tiempo;
new Handle:cvar_fov;

//new Handle:g_hLookupAttachment = INVALID_HANDLE;


public Plugin:myinfo =
{
	name = "SM Decapitation",
	author = "Franc1sco Steam: franug",
	description = "Decapite",
	version = "v1.0",
	url = "http://steamcommunity.com/id/franug"
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_hurt", Event_PlayerHurt);
	CreateConVar("sm_Decapitation", "v1.0", "ver", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	//HookEvent("player_death", PlayerDeath);
	cvar_sonido = CreateConVar("sm_decapitation_sound", "decapitation/scream.wav", "decapitation sound");
	cvar_mochas = CreateConVar("sm_decapitation_hits", "5", "headshots for decapitation");
	cvar_tiempo = CreateConVar("sm_decapitation_viewtime", "3.0", "time for first person on head");
	cvar_fov = CreateConVar("sm_decapitation_fov", "110", "Fov for decapitated clients (default is 90)");
	
	/*new Handle:hGameConf = LoadGameConfigFile("decapitation.gamedata");
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "LookupAttachment");
	g_hLookupAttachment = EndPrepSDKCall();*/

}

public OnMapStart()
{
	decl String:sonido_de[128];
	decl String:sonido[128];
	GetConVarString(cvar_sonido, sonido, 128);
	Format(sonido_de, 128, "sound/%s", sonido);
	AddFileToDownloadsTable(sonido_de);	
	
	

	PrecacheSound(sonido,true);	
	
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	mochas[client] = 0;
	decapitado[client] = false;
	SetClientViewEntity(client,client);
	//erroneo[client] = false;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[],bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!attacker) return;
	
	new hitgroup = GetEventInt(event, "hitgroup");
	if(hitgroup != 1) return;
	
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(decapitado[client]) return;
	
	//if(!ZR_IsClientZombie(client)) return;
	
	mochas[client]++;
	if(mochas[client] >= GetConVarInt(cvar_mochas)) 
	{
		decapitado[client] = true;
		Decapitate(client);
	}
	
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
		cabeza[i] = -1;
}

Decapitate(client)
{
	decl String:sonido[128];
	GetConVarString(cvar_sonido, sonido, 128);
	new Float:pos[3];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitSoundToAll(sonido, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);

	decl String:fullModel[PLATFORM_MAX_PATH];
	GetClientModel(client, fullModel, PLATFORM_MAX_PATH);
	
	
	decl String:headlessModel[PLATFORM_MAX_PATH];
	strcopy(headlessModel, PLATFORM_MAX_PATH, fullModel);
	ReplaceString(headlessModel, PLATFORM_MAX_PATH, ".mdl", "_hs.mdl");

	

	decl String:headModel[PLATFORM_MAX_PATH];
	strcopy(headModel, PLATFORM_MAX_PATH, fullModel);
	ReplaceString(headModel, PLATFORM_MAX_PATH, ".mdl", "_head.mdl");


	if (!FileExists(headlessModel) || !FileExists(headModel))
	{
		return; 
	}
	
	
	if(!IsModelPrecached(headlessModel)) PrecacheModel(headlessModel);	

	
	SetEntityModel(client, headlessModel);
	
	/*if(erroneo[client])
	{
		if (g_Hat[client] != 0 && IsValidEdict(g_Hat[client]))
		{
			decl String:m_ModelName[PLATFORM_MAX_PATH];
			GetEntPropString(g_Hat[client], Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
			strcopy(headModel, PLATFORM_MAX_PATH, m_ModelName);
		}
	}*/
	
	SpawnHead(headModel, client);
	
	CreateTimer(GetConVarFloat(cvar_tiempo), Fin, client, TIMER_FLAG_NO_MAPCHANGE);
	
}

public Action:Fin(Handle:timer, any:client)
{
	if(IsValidClient(client) && IsPlayerAlive(client) && decapitado[client]) 
	{
		SetClientViewEntity(client,client);
		SetEntProp(client, Prop_Send, "m_iFOV", GetConVarInt(cvar_fov));
	}
}


SpawnHead(String:headModel[], client)
{
	
	if(!IsModelPrecached(headModel)) PrecacheModel(headModel);
	
	
	new Float:vecPos[3];
	GetClientAbsOrigin(client, vecPos);
	vecPos[2] += GetRandomFloat(20.0, 30.0);
	
	
	new headEnt = CreateEntityByName("prop_physics_override");
	SetEntityModel(headEnt, headModel);
	TeleportEntity(headEnt, vecPos, NULL_VECTOR, NULL_VECTOR);
	
	DispatchSpawn(headEnt);
	
	SetEntProp(headEnt, Prop_Data, "m_CollisionGroup", 2); 
	SDKHook(headEnt, SDKHook_OnTakeDamage, OnTakeDamage);
	
	
	cabeza[client] = headEnt;
	
	SetClientViewEntity(client, headEnt);
	
}

public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public Action:OnTakeDamage(ent, &inflictor, &attacker, &Float:damage, &damagetype)
{
	if(!IsValidEntity(ent) || !IsValidEdict(ent)) return Plugin_Continue;
	
	
	if(ent == cabeza[attacker]) 
	{
		decl String:fullModel[PLATFORM_MAX_PATH];
		GetClientModel(attacker, fullModel, PLATFORM_MAX_PATH);
	
	
		decl String:headModel[PLATFORM_MAX_PATH];
		strcopy(headModel, PLATFORM_MAX_PATH, fullModel);
		ReplaceString(headModel, PLATFORM_MAX_PATH, "_hs.mdl", ".mdl");
		SetEntityModel(attacker, headModel);
		
		SetClientViewEntity(attacker, attacker);
		
		RemoveEdict(ent);
		
		decapitado[attacker] = false;
		mochas[attacker] = 0;
		SetEntProp(attacker, Prop_Send, "m_iFOV", 90);
	}
	/*else if(decapitado[attacker])
	{
	
		erroneo[attacker] = true;
		decl String:m_ModelName[PLATFORM_MAX_PATH];
		GetEntPropString(ent, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
		CreateHat(attacker,m_ModelName);
		
		RemoveEdict(ent);
		
		
	}*/
	return Plugin_Continue;
}


/*CreateHat(client,String:modelo[])
{	
	if(!LookupAttachment(client, "forward"))
		return;
		
	if(GetClientTeam(client) == 1)
		return;

	new Float:or[3];
	new Float:ang[3];
	new Float:fForward[3];
	new Float:fRight[3];
	new Float:fUp[3];
	GetClientAbsOrigin(client,or);
	GetClientAbsAngles(client,ang);
	
	ang[0] += 0.0;
	ang[1] += 0.0;
	ang[2] += 0.0;

	new Float:fOffset[3];
	fOffset[0] = 0.0;
	fOffset[1] = 0.0;
	fOffset[2] -= 5.0;

	GetAngleVectors(ang, fForward, fRight, fUp);

	or[0] += fRight[0]*fOffset[0]+fForward[0]*fOffset[1]+fUp[0]*fOffset[2];
	or[1] += fRight[1]*fOffset[0]+fForward[1]*fOffset[1]+fUp[1]*fOffset[2];
	or[2] += fRight[2]*fOffset[0]+fForward[2]*fOffset[1]+fUp[2]*fOffset[2];
	
	new ent = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(ent, "model", modelo);
	DispatchKeyValue(ent, "spawnflags", "4");
	SetEntProp(ent, Prop_Data, "m_CollisionGroup", 2);
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	DispatchSpawn(ent);	
	AcceptEntityInput(ent, "TurnOn", ent, ent, 0);
	
	g_Hat[client] = ent;
	
	SDKHook(ent, SDKHook_SetTransmit, ShouldHide);
	
	TeleportEntity(ent, or, ang, NULL_VECTOR); 
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent, 0);
	
	SetVariantString("forward");
	AcceptEntityInput(ent, "SetParentAttachmentMaintainOffset", ent, ent, 0);
}


public Action:ShouldHide(ent, client)
{
			
	if(ent == g_Hat[client])
		return Plugin_Handled;
			
	if(IsClientInGame(client))
		if(GetEntProp(client, Prop_Send, "m_iObserverMode") == 4 && GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")>=0)
			if(ent == g_Hat[GetEntPropEnt(client, Prop_Send, "m_hObserverTarget")])
				return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (g_Hat[client] != 0 && IsValidEdict(g_Hat[client]))
	{
		AcceptEntityInput(g_Hat[client], "Kill");
		SDKUnhook(g_Hat[client], SDKHook_SetTransmit, ShouldHide);
		g_Hat[client] = 0;
	}
}

stock LookupAttachment(client, String:point[])
{
    if(g_hLookupAttachment==INVALID_HANDLE) return 0;
    if( client<=0 || !IsClientInGame(client) ) return 0;
    return SDKCall(g_hLookupAttachment, client, point);
}*/