#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
    name        = "Spawn ChargerTank (Working)",
    author      = "MrGosling (fixed by AI)",
    description = "Spawns a Tank using commentary_zombie_spawner with custom HP and speed",
    version     = PLUGIN_VERSION,
    url         = "about:blank"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_chargertank", Command_SpawnTank, ADMFLAG_ROOT, "Spawn a custom Tank (admin only)");
    PrintToServer("[ChargerTank] Plugin loaded. Use !chargertank or sm_chargertank");
}

/**
 * Command entry point
 */
public Action Command_SpawnTank(int client, int args)
{
    if (!IsClientInGame(client))
    {
        PrintToChat(client, "[ChargerTank] You need to be in game.");
        return Plugin_Handled;
    }

    float pos[3], ang[3];
    GetClientAbsOrigin(client, pos);
    GetClientAbsAngles(client, ang);

    pos[0] += 100.0; // spawn in front
    pos[2] += 10.0;  // slightly above ground

    int spawner = CreateEntityByName("commentary_zombie_spawner");
    if (spawner == -1)
    {
        PrintToChatAll("[ChargerTank] Failed to create commentary_zombie_spawner entity!");
        return Plugin_Handled;
    }

    // Apply parameters
    DispatchKeyValue(spawner, "spawnflags", "8");   // prevent removing after spawn
    DispatchKeyValue(spawner, "classname", "commentary_zombie_spawner");
    DispatchKeyValue(spawner, "population", "tank"); // tank type
    DispatchKeyValue(spawner, "targetname", "temp_tank_spawner");

    DispatchSpawn(spawner);
    TeleportEntity(spawner, pos, ang, NULL_VECTOR);

    PrintToChatAll("[ChargerTank] Spawner created at [%.1f %.1f %.1f], spawning Tank...", pos[0], pos[1], pos[2]);

    // Устанавливаем тип зомби через Variant
    SetVariantString("Tank");
    AcceptEntityInput(spawner, "SpawnZombie");

    // Проверяем спустя секунду
    CreateTimer(0.5, Timer_FindTank, _, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

/**
 * Locate and modify the spawned Tank
 */
public Action Timer_FindTank(Handle timer)
{
    int maxEnts = GetMaxEntities();
    int found = 0;

    for (int i = 1; i < maxEnts; i++)
    {
        if (!IsValidEntity(i)) continue;

        char classname[64];
        GetEntityClassname(i, classname, sizeof(classname));

        if (StrEqual(classname, "tank"))
        {
            found++;
            int health = GetEntProp(i, Prop_Data, "m_iHealth");
            PrintToChatAll("[ChargerTank] Found Tank: entity %d, HP=%d", i, health);

            SetEntProp(i, Prop_Data, "m_iHealth", 1000);
            SetEntPropFloat(i, Prop_Send, "m_flLaggedMovementValue", 300.0 / 210.0);

            AcceptEntityInput(i, "Wake");
            PrintToChatAll("[ChargerTank] Tank modified: HP=1000, speed≈300");
        }
    }

    if (found == 0)
        PrintToChatAll("[ChargerTank] No Tank entities found after spawn!");

    return Plugin_Stop;
}
