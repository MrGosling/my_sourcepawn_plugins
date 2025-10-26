#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
    name = "L4D ChargerTank",
    author = "MrGosling",
    description = "Increases Tank speed if health is below a certain threshold on spawn.",
    version = PLUGIN_VERSION,
    url = "not url - 46.174.52.3:27201"
};

ConVar g_hEnabled;
ConVar g_hHealthThreshold;
ConVar g_hTankSpeed;

public void OnPluginStart()
{
    g_hEnabled = CreateConVar("l4d_chargertank_enabled", "1", "Enable/disable the plugin. 0 = off, 1 = on.", _, true, 0.0, true, 1.0);
    g_hHealthThreshold = CreateConVar("l4d_chargertank_health", "2000", "If Tank spawns with less than this much health, speed will be changed.", _, true, 1.0);
    g_hTankSpeed = CreateConVar("l4d_chargertank_speed", "300", "The speed to set for the low-health Tank.", _, true, 1.0);

    HookEvent("tank_spawn", Event_TankSpawn);

    PrintToServer("[L4D ChargerTank] Plugin loaded. Version: %s", PLUGIN_VERSION);
    PrintToChatAll("[L4D ChargerTank] Plugin loaded. Version: %s", PLUGIN_VERSION);
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
    PrintToChatAll("[L4D ChargerTank] tank_spawn event fired.");

    if (!g_hEnabled.BoolValue)
    {
        PrintToChatAll("[L4D ChargerTank] Plugin is disabled, skipping.");
        return;
    }

    int tank = event.GetInt("tankid");
    PrintToChatAll("[L4D ChargerTank] Tank entity id: %d", tank);

    if (tank > 0 && IsValidEntity(tank))
    {
        int class = GetEntProp(tank, Prop_Send, "m_zombieClass");
        PrintToChatAll("[L4D ChargerTank] Zombie class of entity: %d", class);

        if (class != 5) // 5 is tank
        {
            PrintToChatAll("[L4D ChargerTank] Entity is not a Tank, skipping.");
            return;
        }

        CreateTimer(0.1, Timer_SetTankSpeed, tank, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        PrintToChatAll("[L4D ChargerTank] Invalid tank entity, skipping.");
    }
}

public Action Timer_SetTankSpeed(Handle timer, any tank)
{
    if (tank > 0 && IsValidEntity(tank))
    {
        int health = GetEntProp(tank, Prop_Data, "m_iHealth");
        PrintToChatAll("[L4D ChargerTank] Tank health on spawn: %d", health);

        if (health < g_hHealthThreshold.IntValue && health > 0)
        {
            float speedScale = g_hTankSpeed.FloatValue / 210.0;
            SetEntPropFloat(tank, Prop_Send, "m_flLaggedMovementValue", speedScale);
            PrintToChatAll("[L4D ChargerTank] Setting Tank speed to %.2f (scale %.3f) due to low health.", g_hTankSpeed.FloatValue, speedScale);
            PrintToChatAll("[L4D ChargerTank] Tank speed changed to %.2f because health is low (%d).", g_hTankSpeed.FloatValue, health);
        }
        else
        {
            PrintToChatAll("[L4D ChargerTank] Tank health above threshold, speed not changed.");
        }
    }
    else
    {
        PrintToChatAll("[L4D ChargerTank] Tank entity invalid on timer, skipping.");
    }
    return Plugin_Continue;
}
