#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.4"

public Plugin myinfo =
{
    name        = "Spawn ChargerTank",
    author      = "MrGosling",
    description = "Spawns a Tank with custom HP and speed at the point you're looking.",
    version     = PLUGIN_VERSION,
    url         = "about:blank"
};

public void OnPluginStart()
{
    RegAdminCmd("sm_chargertank", Command_SpawnTank, ADMFLAG_ROOT, "Spawn a custom Tank where you look (admin only)");
    PrintToServer("[ChargerTank] Plugin loaded. Use !chargertank or sm_chargertank");
}

//-------------------------------------------------------------
// Команда: спавн Танка в точке взгляда игрока
//-------------------------------------------------------------
public Action Command_SpawnTank(int client, int args)
{
    if (!IsClientInGame(client))
    {
        PrintToChat(client, "[ChargerTank] You must be in the game.");
        return Plugin_Handled;
    }

    float eyePos[3], eyeAng[3], endPos[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);

    GetLookEndPosition(eyePos, eyeAng, 800.0, endPos); // Найдём точку на которой взгляд пересекает мир

    int spawner = CreateEntityByName("commentary_zombie_spawner");
    if (spawner == -1)
    {
        PrintToChatAll("[ChargerTank] Failed to create zombie spawner!");
        return Plugin_Handled;
    }

    DispatchKeyValue(spawner, "spawnflags", "8");
    DispatchKeyValue(spawner, "population", "tank");
    DispatchKeyValue(spawner, "targetname", "temp_tank_spawner");

    DispatchSpawn(spawner);
    TeleportEntity(spawner, endPos, NULL_VECTOR, NULL_VECTOR);

    PrintToChatAll("[ChargerTank] Spawner created at [%.1f %.1f %.1f].", endPos[0], endPos[1], endPos[2]);

    // Команда спавна Танка
    SetVariantString("Tank");
    AcceptEntityInput(spawner, "SpawnZombie");

    // Подождём 0.5с, затем ищем Танка рядом с этой точкой
    CreateTimer(0.5, Timer_FindTankNearPoint, spawner, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
}

//-------------------------------------------------------------
// Таймер: ищем ближайшего Танка и изменяем его характеристики
//-------------------------------------------------------------
public Action Timer_FindTankNearPoint(Handle timer, any spawner)
{
    float spawnPos[3];
    GetEntPropVector(spawner, Prop_Send, "m_vecOrigin", spawnPos);

    int maxEnts = GetMaxEntities();
    int found = -1;

    for (int i = 1; i < maxEnts; i++)
    {
        if (!IsValidEntity(i)) continue;

        char cname[64];
        GetEntityClassname(i, cname, sizeof(cname));
        if (!StrEqual(cname, "tank")) continue;

        float entPos[3];
        GetEntPropVector(i, Prop_Send, "m_vecOrigin", entPos);
        if (GetVectorDistance(spawnPos, entPos) <= 200.0) // если Танк в радиусе 200 от точки спавна
        {
            found = i;
            break;
        }
    }

    if (found == -1)
    {
        PrintToChatAll("[ChargerTank] No Tank found near spawn point!");
        return Plugin_Stop;
    }

    // Изменяем HP и скорость
    SetEntProp(found, Prop_Data, "m_iHealth", 1000);
    SetEntPropFloat(found, Prop_Send, "m_flLaggedMovementValue", 300.0 / 210.0);

    // Запускаем таймер для постоянного закрепления скорости
    CreateTimer(0.3, Timer_KeepSpeed, EntIndexToEntRef(found), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    AcceptEntityInput(found, "Wake");
    PrintToChatAll("[ChargerTank] Tank %d updated: HP=1000, speed≈300.", found);
    return Plugin_Stop;
}

//-------------------------------------------------------------
// Таймер для фикса скорости Танка (если Director сбросит)
//-------------------------------------------------------------
public Action Timer_KeepSpeed(Handle timer, any ref)
{
    int ent = EntRefToEntIndex(ref);
    if (ent == INVALID_ENT_REFERENCE || !IsValidEntity(ent))
        return Plugin_Stop;

    SetEntPropFloat(ent, Prop_Send, "m_flLaggedMovementValue", 300.0 / 210.0);
    return Plugin_Continue;
}

//-------------------------------------------------------------
// Вычисляем точку пересечения взгляда с объектами (RayTrace)
//-------------------------------------------------------------
void GetLookEndPosition(const float start[3], const float angles[3], float dist, float output[3])
{
    float dir[3];
    GetAngleVectors(angles, dir, NULL_VECTOR, NULL_VECTOR);

    float end[3];
    end[0] = start[0] + dir[0] * dist;
    end[1] = start[1] + dir[1] * dist;
    end[2] = start[2] + dir[2] * dist;

    Handle trace = TR_TraceRayFilterEx(start, end, MASK_SOLID, RayType_EndPoint, TraceEntityFilterPlayers);
    if (TR_DidHit(trace))
        TR_GetEndPosition(output, trace);
    else
        output = end;

    CloseHandle(trace);
}

// Игнорируем игроков при трассе луча
public bool TraceEntityFilterPlayers(int ent, int mask)
{
    return (ent > MaxClients);
}
