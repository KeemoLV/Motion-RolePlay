//***************************************
//			Motion RolePlay
//			   By Keemo
//     Started 2017.11.25 23:09
//***************************************

#include <a_samp>
#include <a_mysql>
//#include <nex-ac>
#include <izcmd>
#include <foreach>
#include <sscanf2>
#include <easyDialog>
#include <log-plugin>
#include <streamer>

#define SQL_HOST						"127.0.0.1" 			// MySQL server's host IP
#define SQL_USER 						"root"					// MySQL server's user name
#define SQL_PASS						""						// MySQL server's user password
#define SQL_DB							"motion"				// MySQL server's database name

#define SERVER_NAME						"Motion RolePlay"
#define SERVER_MODE						"Motion RP"
#define SERVER_VERSION					"v0.1"

#define CMD_NOT_AVAILABLE				"You don't have access to this command!"
#define PLAYER_NOT_ONLINE				"Specified player isn't online right now!"
#define PLAYER_NOT_LOGGED				"Specified player hasn't logged in yet!"
#define NOT_IN_VEHICLE					"You are not in a vehicle!"
#define NOT_ENOUGH_MONEY_BANK			"You don't have enough money on your bank account!"
#define YOU_HAVE_A_HOUSE				"You already have a house!"

#define	SECONDS_TO_LOGIN 				(30)					// Max allowed time for login before getting kicked

#define DEFAULT_POS_X 					(1958.3783)
#define DEFAULT_POS_Y 					(1343.1572)
#define DEFAULT_POS_Z 					(15.3746)
#define DEFAULT_POS_A 					(270.1425)

#define MAX_HOUSES						(300)

#define COLOR_LIGHTRED 					(0xFF6347AA)
#define COLOR_ORANGE        			(0xFF9900FF)
#define COLOR_GREY 						(0xAFAFAFAA)
#define COLOR_PURPLE 					(0xC2A2DAAA)
#define COLOR_FADE1 					(0xFFFFFFFF)
#define COLOR_FADE2 					(0xC8C8C8C8)
#define COLOR_FADE3 					(0xAAAAAAAA)
#define COLOR_FADE4 					(0x8C8C8C8C)
#define COLOR_FADE5 					(0x6E6E6E6E)

#if !defined IsValidVehicle
     native IsValidVehicle(vehicleid);
#endif

new 
	MySQL: g_SQL,
	g_MysqlRaceCheck[MAX_PLAYERS];

new 
	String[2048],
	query[1024];

new 
	gmLoaded = 0;

new 
	Logger: adminlog;

new 
	Iterator: admin_vehicle<MAX_VEHICLES-1>;

new 
	TOTAL_HOUSES, 
	TOTAL_PVEHICLES;

enum pData
{
	ID,
	Name[MAX_PLAYER_NAME],
	Password[65],
	Salt[17],
	Admin,
	Skin,
	Float: Health,
	Float: Armor,
	Money, 
	BankMoney,
	Float: X_Pos,
	Float: Y_Pos,
	Float: Z_Pos,
	Float: A_Pos,
	Interior,
	Cache: Cache_ID,
	bool: LoggedIn,
	LoginAttempts,
	LoginTimer
};
new Player[MAX_PLAYERS][pData];

enum hInfo
{
	hID,
	Float: hEntranceX,
	Float: hEntranceY,
	Float: hEntranceZ,
	Float: hExitX,
	Float: hExitY,
	Float: hExitZ,
	hOwner[MAX_PLAYER_NAME],
	hClass[16],
	hInterior,
	hWorld,
	hPrice,
	hIcon, 
	hPickup,
	hPickupExit
};
new House[MAX_HOUSES][hInfo];

enum vInfo
{
	vID,
	vOwner[MAX_PLAYER_NAME],
	vModel,
	vColor_1,
	vColor_2,
	Float: vX,
	Float: vY,
	Float: vZ,
	Float: vAngle,
	vVehicle,
	vLocked,
	Float: vFuel,
	vActive
};
new pVehicle[MAX_VEHICLES][vInfo];

main()
{
	print("\n_____________________________________");
	print(" ");
	print(" Starting Motion RolePlay "SERVER_VERSION"");
	print(" By Keemo (RageCraftLV)");
	print("_____________________________________\n");
}

public OnGameModeInit()
{
	new MySQLOpt: option_id = mysql_init_options();

	mysql_set_option(option_id, AUTO_RECONNECT, true);

	g_SQL = mysql_connect(SQL_HOST, SQL_USER, SQL_PASS, SQL_DB, option_id);
	if (g_SQL == MYSQL_INVALID_HANDLE || mysql_errno(g_SQL) != 0)
	{
		print("MySQL connection failed. Server is shutting down.");
		SendRconCommand("exit");
		return 1;
	}
	print("MySQL connection is successful.");

	SetGameModeText(""SERVER_MODE" "SERVER_VERSION"");

	mysql_tquery(g_SQL, "SELECT * FROM `houses` ORDER BY  `houses`.`ID` ASC ", "LoadHouses", "");
	mysql_tquery(g_SQL, "SELECT * FROM `vehicles` ORDER BY  `vehicles`.`ID` ASC ", "LoadPVehicles", "");

	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);

	adminlog = CreateLog("admin", INFO);

	gmLoaded = 1;
	return 1;
}

public OnGameModeExit()
{
	for(new i = 0, j = GetPlayerPoolSize(); i <= j; i++)
	{
		if (IsPlayerConnected(i))
		{
			OnPlayerDisconnect(i, 1);
		}
	}
	mysql_close(g_SQL);

	DestroyLog(adminlog);
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraLookAt(playerid, 1958.3783, 1343.1572, 15.3746);
	return 1;
}

public OnPlayerConnect(playerid)
{
	if(gmLoaded == 0)
	{
		SendClientMessage(playerid, -1, "Server is not running yet!");
		Kick(playerid);
	}
	
	g_MysqlRaceCheck[playerid]++;

	static const empty_player[pData];
	Player[playerid] = empty_player;

	GetPlayerRPName(playerid, Player[playerid][Name], MAX_PLAYER_NAME);

	mysql_format(g_SQL, query, 103, "SELECT * FROM `players` WHERE `Name` = '%e' LIMIT 1", pName(playerid));
	mysql_tquery(g_SQL, query, "OnPlayerDataLoaded", "dd", playerid, g_MysqlRaceCheck[playerid]);
	
	format(String, 100, "[A] %s [ID: %d] joined the server.", Player[playerid][Name], playerid);
	SendAdminMessage(COLOR_LIGHTRED, String);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	g_MysqlRaceCheck[playerid]++;

	UpdatePlayerData(playerid, reason);

	if (cache_is_valid(Player[playerid][Cache_ID]))
	{
		cache_delete(Player[playerid][Cache_ID]);
		Player[playerid][Cache_ID] = MYSQL_INVALID_CACHE;
	}

	if (Player[playerid][LoginTimer])
	{
		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
	}

	Player[playerid][LoggedIn] = false;

	new disconnectReason[3][] =
    {
        "Timeout/Crash",
        "Quit",
        "Kick/Ban"
    };

	format(String, 100, "[A] %s [ID: %d] left the server with reason: {FF9900}%s", Player[playerid][Name], disconnectReason[reason]);
	SendAdminMessage(COLOR_LIGHTRED, String);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	SetPlayerInterior(playerid, Player[playerid][Interior]);
	SetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
	SetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	
	SetCameraBehindPlayer(playerid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
	format(String, 128, "%s says: %s", Player[playerid][Name], text);
	SendLocalMessage(30.0, playerid, -1, String);
	if(!IsPlayerInAnyVehicle(playerid)) ApplyAnimation(playerid, "PED", "IDLE_CHAT", 4.1, 0, 1, 1, 1, 1);
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	for(new idx = 1; idx <= TOTAL_HOUSES; idx++)
	{
		if(pickupid == House[idx][hPickup])
		{
			SetPVarInt(playerid, "PlayerHouse", idx);
		   	if(!strcmp(House[idx][hOwner], "None", true))
		  	{
				format(String, 256, "\
					House nr. %d\n\n\
					Price: %d$\n\
					Class: %s", idx, House[idx][hPrice], House[idx][hClass]);
			   	return Dialog_Show(playerid, BuyHouse, 0, "Buy house", String, "Buy", "Cancel");
			}
			else
			{
				format(String, 256, "\
					House nr. %d\n\n\
					Owner: %s\n\
					Class: %s", idx, House[idx][hOwner], House[idx][hClass]);
			    return Dialog_Show(playerid, EnterHouse, 0, "Buy house", String, "Enter", "Cancel");
			}
		}
		if(pickupid == House[idx][hPickupExit])
    	{
		    SetPVarInt(playerid, "PlayerHouse", idx);
		    return Dialog_Show(playerid, ExitHouse, 0, "Exit house", "Do you want to exit your house?", "Yes", "No");
    	}
	}
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}

forward OnPlayerDataLoaded(playerid, race_check);
public OnPlayerDataLoaded(playerid, race_check)
{
	if (race_check != g_MysqlRaceCheck[playerid]) return Kick(playerid);

	if(cache_num_rows() > 0)
	{
		cache_get_value(0, "Password", Player[playerid][Password], 65);
		cache_get_value(0, "Salt", Player[playerid][Salt], 17);

		Player[playerid][Cache_ID] = cache_save();

		format(String, 115, "This account %s is registered. Please login by entering your password in the field below:", Player[playerid][Name]);
		Dialog_Show(playerid, Login, DIALOG_STYLE_PASSWORD, "Login", String, "Login", "Abort");

		Player[playerid][LoginTimer] = SetTimerEx("OnLoginTimeout", SECONDS_TO_LOGIN * 1000, false, "d", playerid);
	}
	else
	{
		format(String, sizeof String, "Welcome %s, you can register by entering your password in the field below:", Player[playerid][Name]);
		Dialog_Show(playerid, Register, DIALOG_STYLE_PASSWORD, "Registration", String, "Register", "Abort");
	}
	return 1;
}

forward OnLoginTimeout(playerid);
public OnLoginTimeout(playerid)
{
	Player[playerid][LoginTimer] = 0;
	
	Dialog_Show(playerid, Null, DIALOG_STYLE_MSGBOX, "Login", "You have been kicked for taking too long to login successfully to your account.", "Okay", "");
	DelayedKick(playerid);
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	Player[playerid][ID] = cache_insert_id();

	Dialog_Show(playerid, Null, DIALOG_STYLE_MSGBOX, "Registration", "Account successfully registered, you have been automatically logged in.", "Okay", "");

	Player[playerid][LoggedIn] = true;

	Player[playerid][X_Pos] = DEFAULT_POS_X;
	Player[playerid][Y_Pos] = DEFAULT_POS_Y;
	Player[playerid][Z_Pos] = DEFAULT_POS_Z;
	Player[playerid][A_Pos] = DEFAULT_POS_A;
	
	SetSpawnInfo(playerid, NO_TEAM, 0, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}

forward _KickPlayerDelayed(playerid);
public _KickPlayerDelayed(playerid)
{
	Kick(playerid);
	return 1;
}

forward public LoadHouses();
public LoadHouses()
{
	static rows;
	cache_get_row_count(rows);
	if(rows)
	{
		for(new idx = 1; idx <= rows; idx++)
		{
			cache_get_value_name_int(idx-1, "ID", House[idx][hID]);
			cache_get_value_name_float(idx-1, "EntranceX", House[idx][hEntranceX]);
			cache_get_value_name_float(idx-1, "EntranceY", House[idx][hEntranceY]);
			cache_get_value_name_float(idx-1, "EntranceZ", House[idx][hEntranceZ]);
			cache_get_value_name_float(idx-1, "ExitX", House[idx][hExitX]);
			cache_get_value_name_float(idx-1, "ExitY", House[idx][hExitY]);
			cache_get_value_name_float(idx-1, "ExitZ", House[idx][hExitZ]);
			cache_get_value_name(idx-1, "Owner", House[idx][hOwner]);
			cache_get_value_name_int(idx-1, "Interior", House[idx][hInterior]);
			cache_get_value_name_int(idx-1, "World", House[idx][hWorld]);
			cache_get_value_name_int(idx-1, "Price", House[idx][hPrice]);
			if(!strcmp(House[idx][hOwner], "None", true))
           	{
           		House[idx][hIcon] = CreateDynamicMapIcon(House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ], 31, 0, -1, -1, -1, 200.0);
           		House[idx][hPickup] = CreatePickup(1273, 1, House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ]);
           	}
           	else
           	{
           		House[idx][hIcon] = CreateDynamicMapIcon(House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ], 32, 0, -1, -1, -1, 200.0);
           		House[idx][hPickup] = CreatePickup(1272, 1, House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ]);
           	}
           	House[idx][hPickupExit] = CreatePickup(19134, 1, House[idx][hExitX], House[idx][hExitY], House[idx][hExitZ], House[idx][hWorld]);
			TOTAL_HOUSES++;
		}
	}
	printf( "Loaded %d houses", TOTAL_HOUSES);
	return 1;
}

forward public LoadPVehicles();
public LoadPVehicles()
{
	static rows;
	cache_get_row_count(rows);
	if(rows)
	{
		for(new idx = 1; idx <= rows; idx++)
		{
			cache_get_value_name_int(idx-1, "ID", pVehicle[idx][vID]);
			cache_get_value_name(idx-1, "Owner", pVehicle[idx][vOwner]);
			cache_get_value_name_int(idx-1, "Model", pVehicle[idx][vModel]);
			cache_get_value_name_int(idx-1, "Color_1", pVehicle[idx][vColor_1]);
			cache_get_value_name_int(idx-1, "Color_2", pVehicle[idx][vColor_2]);
			cache_get_value_name_float(idx-1, "X", pVehicle[idx][vX]);
			cache_get_value_name_float(idx-1, "Y", pVehicle[idx][vY]);
			cache_get_value_name_float(idx-1, "Z", pVehicle[idx][vZ]);
			cache_get_value_name_float(idx-1, "Angle", pVehicle[idx][vAngle]);
			cache_get_value_name_int(idx-1, "Active", pVehicle[idx][vActive]);
			if(pVehicle[idx][vActive] == 1)
			{
				pVehicle[idx][vVehicle] = CreateVehicle(pVehicle[idx][vModel], pVehicle[idx][vX], pVehicle[idx][vY], pVehicle[idx][vZ], pVehicle[idx][vAngle], pVehicle[idx][vColor_1], pVehicle[idx][vColor_2], -1);
				TOTAL_PVEHICLES++;
			}
		}
	}
	printf( "Loaded %d player vehicles", TOTAL_PVEHICLES);
	return 1;
}

AssignPlayerData(playerid)
{
	cache_get_value_int(0, "ID", Player[playerid][ID]);

	cache_get_value_int(0, "Admin", Player[playerid][Admin]);
	cache_get_value_int(0, "Skin", Player[playerid][Skin]);
	cache_get_value_float(0, "Health", Player[playerid][Health]);
	cache_get_value_float(0, "Armor", Player[playerid][Armor]);
	cache_get_value_int(0, "Money", Player[playerid][Money]);
	cache_get_value_int(0, "BankMoney", Player[playerid][BankMoney]);
	
	cache_get_value_float(0, "X", Player[playerid][X_Pos]);
	cache_get_value_float(0, "Y", Player[playerid][Y_Pos]);
	cache_get_value_float(0, "Z", Player[playerid][Z_Pos]);
	cache_get_value_float(0, "Angle", Player[playerid][A_Pos]);
	cache_get_value_int(0, "Interior", Player[playerid][Interior]);

	SetMoney(playerid, Player[playerid][Money]);
	SetPlayerSkin(playerid, Player[playerid][Skin]);
	SetHealth(playerid, Player[playerid][Health]);
	SetArmor(playerid, Player[playerid][Armor]);
	return 1;
}

DelayedKick(playerid, time = 500)
{
	SetTimerEx("_KickPlayerDelayed", time, false, "d", playerid);
	return 1;
}

UpdatePlayerData(playerid, reason)
{
	if(Player[playerid][LoggedIn] == false) return 0;

	GetPlayerHealth(playerid, Player[playerid][Health]);
	GetPlayerArmour(playerid, Player[playerid][Armor]);

	if(reason == 1)
	{
		GetPlayerPos(playerid, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos]);
		GetPlayerFacingAngle(playerid, Player[playerid][A_Pos]);
	}
	
	mysql_format(g_SQL, query, 250, "UPDATE `players` SET `Money` = %d, `BankMoney` = %d, `Health` = %f, `Armor` = %f, `X` = %f, `Y` = %f, `Z` = %f, `Angle` = %f, `Interior` = %d WHERE `ID` = %d LIMIT 1", 
		Player[playerid][Money], 
		Player[playerid][BankMoney],
		Player[playerid][Health],
		Player[playerid][Armor], 
		Player[playerid][X_Pos], 
		Player[playerid][Y_Pos], 
		Player[playerid][Z_Pos], 
		Player[playerid][A_Pos], 
		GetPlayerInterior(playerid), 
		Player[playerid][ID]);
	mysql_tquery(g_SQL, query);
	return 1;
}

SendAdminMessage(color, str[])
{
	foreach(new i: Player)
	{
		if(!Player[i][LoggedIn]) continue;
		if(Player[i][Admin] > 0) SendClientMessage(i, color, str);
	}
	return 1;
}

SendErrorMessage(playerid, color, str[])
{
	format(String, 128, "[ERROR]: %s", str);
	return SendClientMessage(playerid, color, String);
}

SendSyntaxMessage(playerid, color, str[])
{
	format(String, 128, "[SYNTAX]: %s", str);
	return SendClientMessage(playerid, color, String);
}

SendLocalMessage(Float:radi, playerid, color, string[])
{
	new Float: X, Float: Y, Float: Z;
	GetPlayerPos(playerid, X, Y, Z);
	foreach(Player, i)
	{
		new Float: X2, Float: Y2, Float: Z2;
		GetPlayerPos(i, X2, Y2, Z2);
		if(IsPlayerInRangeOfPoint(i, radi, X, Y, Z)) { SendClientMessage(i, color, string); }
	}
	return 1;
}

GetPlayerRPName(playerid, name[], len)
{
	GetPlayerName(playerid, name, len);
	for(new i = 0; i < len; i++)
	{
		if (name[ i ] == '_')
		name[i] = ' ';
	}
}

pName(playerid)
{
	new name[MAX_PLAYER_NAME];
	GetPlayerName(playerid, name, sizeof name);
	return name;
}

UpdateHouse(idx)
{
    DestroyDynamicMapIcon(House[idx][hIcon]);
    DestroyPickup(House[idx][hPickup]);
    DestroyPickup(House[idx][hPickupExit]);
   	if(!strcmp(House[idx][hOwner], "None", true))
	{
		House[idx][hIcon] = CreateDynamicMapIcon(House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ], 31, 0,-1,-1,-1,200.0);
		House[idx][hPickup] = CreatePickup(1273, 1, House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ]);
 	}
	else
	{
		House[idx][hIcon] = CreateDynamicMapIcon(House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ], 32, 0,-1,-1,-1,200.0);
		House[idx][hPickup] = CreatePickup(1272, 1, House[idx][hEntranceX], House[idx][hEntranceY], House[idx][hEntranceZ]);
	}
	House[idx][hPickupExit] = CreatePickup(19134, 1, House[idx][hExitX], House[idx][hExitY], House[idx][hExitZ], House[idx][hWorld]);
	return 1;
}

SetHealth(playerid, Float: health)
{
	Player[playerid][Health] = health;
	SetPlayerHealth(playerid, health);
}

SetArmor(playerid, Float: armor)
{
	Player[playerid][Armor] = armor;
	SetPlayerArmour(playerid, armor);
}

GiveMoney(playerid, money)
{
	Player[playerid][Money] += money;
	GivePlayerMoney(playerid, money);
}

SetMoney(playerid, money)
{
	Player[playerid][Money] = money;
	ResetPlayerMoney(playerid);
	GivePlayerMoney(playerid, money);
}

ResetMoney(playerid)
{
	Player[playerid][Money] = 0;
	ResetPlayerMoney(playerid);
}

Dialog:Null(playerid, response, listitem, inputtext[]) return 1;

Dialog:Register(playerid, response, listitem, inputtext[])
{
	if(!response) return Kick(playerid);

	if(strlen(inputtext) <= 5) return Dialog_Show(playerid, Register, DIALOG_STYLE_PASSWORD, "Registration", "Your password must be longer than 5 characters!\nPlease enter your password in the field below:", "Register", "Abort");

	for(new i = 0; i < 16; i++) Player[playerid][Salt][i] = random(94) + 33;
	SHA256_PassHash(inputtext, Player[playerid][Salt], Player[playerid][Password], 65);

	mysql_format(g_SQL, query, 221, "INSERT INTO `players` (`Name`, `Password`, `Salt`) VALUES ('%e', '%s', '%e')", pName(playerid), Player[playerid][Password], Player[playerid][Salt]);
	mysql_tquery(g_SQL, query, "OnPlayerRegister", "d", playerid);
	return 1;
}

Dialog:Login(playerid, response, listitem, inputtext[])
{
	if(!response) return Kick(playerid);

	new hashed_pass[65];
	SHA256_PassHash(inputtext, Player[playerid][Salt], hashed_pass, 65);

	if(strcmp(hashed_pass, Player[playerid][Password]) == 0)
	{
		Dialog_Show(playerid, Null, DIALOG_STYLE_MSGBOX, "Login", "You have been successfully logged in.", "Okay", "");

		cache_set_active(Player[playerid][Cache_ID]);

		AssignPlayerData(playerid);

		cache_delete(Player[playerid][Cache_ID]);
		Player[playerid][Cache_ID] = MYSQL_INVALID_CACHE;

		KillTimer(Player[playerid][LoginTimer]);
		Player[playerid][LoginTimer] = 0;
		Player[playerid][LoggedIn] = true;

		SetSpawnInfo(playerid, NO_TEAM, 0, Player[playerid][X_Pos], Player[playerid][Y_Pos], Player[playerid][Z_Pos], Player[playerid][A_Pos], 0, 0, 0, 0, 0, 0);
		SpawnPlayer(playerid);
	}
	else
	{
		Player[playerid][LoginAttempts]++;

		if (Player[playerid][LoginAttempts] >= 3)
		{
			Dialog_Show(playerid, Null, DIALOG_STYLE_MSGBOX, "Login", "You have mistyped your password too often (3 times).", "Okay", "");
			DelayedKick(playerid);
		}
		else Dialog_Show(playerid, Login, DIALOG_STYLE_PASSWORD, "Login", "Wrong password!\nPlease enter your password in the field below:", "Login", "Abort");
	}
	return 1;
}

Dialog:ControlPanel(playerid, response, listitem, inputtext[])
{
	if(!response) return 1;
	switch(listitem)
	{
		case 0: Dialog_Show(playerid, ChangeHostname, DIALOG_STYLE_INPUT, "Input hostname", "Please, input your desired hostname:", "Done", "Back");
		case 1: Dialog_Show(playerid, SetPassword, DIALOG_STYLE_INPUT, "Input password", "(Set 0 for no password)\nPlease, input your desired servers password:", "Done", "Back");
		case 2: Dialog_Show(playerid, ChangeMode, DIALOG_STYLE_INPUT, "Input mode", "Please, input your desired servers mode:", "Done", "Back");
		case 3: Dialog_Show(playerid, ChangeLang, DIALOG_STYLE_INPUT, "Input language", "Please, input your desired servers language:", "Done", "Back");
		case 4: SendRconCommand("gmx");
	}
	return 1;
}

Dialog:ChangeHostname(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, ControlPanel, DIALOG_STYLE_LIST, "Server control panel", "\
		Change server hostname\n\
		Set servers password\n\
		Change servers 'mode'\n\
		Change servers 'language'\n\
		Restart server", "OK", "Cancel");
	new cmd[256];
	format(cmd, sizeof cmd, "hostname %s", inputtext);
	SendRconCommand(cmd);
	format(String, 300, "You changed servers hostname to %s", cmd);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s changed servers hostname to %s", Player[playerid][Name], cmd);
	return 1;
}

Dialog:SetPassword(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, ControlPanel, DIALOG_STYLE_LIST, "Server control panel", "\
		Change server hostname\n\
		Set servers password\n\
		Change servers 'mode'\n\
		Change servers 'language'\n\
		Restart server", "OK", "Cancel");
	new cmd[64];
	format(cmd, sizeof cmd, "password %s", inputtext);
	SendRconCommand(cmd);
	format(String, 300, "You set servers password to %s", cmd);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s set servers password to %s", Player[playerid][Name], cmd);
	return 1;
}

Dialog:ChangeMode(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, ControlPanel, DIALOG_STYLE_LIST, "Server control panel", "\
		Change server hostname\n\
		Set servers password\n\
		Change servers 'mode'\n\
		Change servers 'language'\n\
		Restart server", "OK", "Cancel");
	new cmd[32];
	format(cmd, sizeof cmd, "gamemodetext %s", inputtext);
	SendRconCommand(cmd);
	format(String, 300, "You changed servers 'mode' to %s", cmd);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s changed servers 'mode' to %s", Player[playerid][Name], cmd);
	return 1;
}

Dialog:ChangeLang(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, ControlPanel, DIALOG_STYLE_LIST, "Server control panel", "\
		Change server hostname\n\
		Set servers password\n\
		Change servers 'mode'\n\
		Change servers 'language'\n\
		Restart server", "OK", "Cancel");
	new cmd[32];
	format(cmd, sizeof cmd, "language %s", inputtext);
	SendRconCommand(cmd);
	format(String, 300, "You changed servers 'language' to %s", cmd);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s changed servers to %s", Player[playerid][Name], cmd);
	return 1;
}

Dialog:EnterHouse(playerid, response, listitem, inputtext[])
{
	if(response)
	{
	    new idx = GetPVarInt(playerid, "PlayerHouse");
      	SetPlayerPos(playerid, House[idx][hExitX], House[idx][hExitY], House[idx][hExitZ]);
		SetPlayerInterior(playerid, House[idx][hInterior]);
		SetPlayerVirtualWorld(playerid, House[idx][hWorld]);
	}
	return 1;
}

Dialog:ExitHouse(playerid, response, listitem, inputtext[]) 
{
	if(response) 
	{
	    new house = GetPVarInt(playerid, "PlayerHouse");
	    SetPlayerPos(playerid, House[house][hEntranceX], House[house][hEntranceY], House[house][hEntranceZ]);
		SetPlayerInterior(playerid, 0);
		SetPlayerVirtualWorld(playerid, 0);
		return 1;
	}
	return 1;
}

Dialog:BuyHouse(playerid, response, listitem, inputtext[]) {
	if(response) {
	    new idx = GetPVarInt(playerid, "PlayerHouse");
       	if(Player[playerid][BankMoney] < House[idx][hPrice]) return SendErrorMessage(playerid, COLOR_GREY, NOT_ENOUGH_MONEY_BANK);
		else 
		{
			new house = 0;
			for(new i = 1; i <= TOTAL_HOUSES; i++) 
			{
				if(!strcmp(House[i][hOwner], pName(playerid), true)) house++;
			}
			if(house != 0) return SendErrorMessage(playerid, COLOR_GREY, YOU_HAVE_A_HOUSE);
			Player[playerid][BankMoney] -= House[idx][hPrice];
			format(String, 32, "You bought a house!");
			GameTextForPlayer(playerid, String, 3000, 5);
			format(String, 256, "You bought a house for %d$! Money left in bank: %d$.", House[idx][hPrice], Player[playerid][BankMoney]);
			SendClientMessage(playerid, -1, String);
			strmid(House[idx][hOwner], pName(playerid), 0, strlen(pName(playerid)), MAX_PLAYER_NAME);
			format(String, 256, "UPDATE `houses` SET Owner = '%s' WHERE ID = '%d' LIMIT 1", House[idx][hOwner], idx);
			mysql_tquery(g_SQL, String, "", "");
			
		    SetPlayerPos(playerid, House[idx][hExitX], House[idx][hExitY], House[idx][hExitZ]);
			SetPlayerInterior(playerid, House[idx][hInterior]);
			SetPlayerVirtualWorld(playerid, House[idx][hWorld]);
			UpdateHouse(idx);
			return true;
		}
	}
	return 1;
}

Dialog:AddMenu(playerid, response, listitem, inputtext[])
{
	if(response)
	{
		switch(listitem)
		{
			case 0:
			{
				new String1[1000];
				strcat(String1,"\
				Syntax: price, number\n\n\
				Sample: 24000, 19\n\n");
				strcat(String1,"1. [Class: A]\t12. [Class: C]\t23. [Class: C]\t34. [Class: C]\n");
				strcat(String1,"2. [Class: C]\t13. [Class: C]\t24. [Class: B]\t35. [Class: C]\n");
				strcat(String1,"3. [Class: B]\t14. [Class: B]\t25. [Class: B]\n");
				strcat(String1,"4. [Class: D]\t15. [Class: C]\t26. [Class: D]\n");
				strcat(String1,"5. [Class: B]\t16. [Class: B]\t27. [Class: D]\n");
				strcat(String1,"6. [Class: B]\t17. [Class: B]\t28. [Class: D]\n");
				strcat(String1,"7. [Class: D]\t18. [Class: A]\t29. [Class: C]\n");
				strcat(String1,"8. [Class: B]\t19. [Class: C]\t30. [Class: A]\n");
				strcat(String1,"9. [Class: A]\t20. [Class: D]\t31. [Class: C]\n");
				strcat(String1,"10. [Class: B]\t21. [Class: A]\t32. [Class: C]\n");
				strcat(String1,"11. [Class: C]\t22. [Class: B]\t33. [Class: D]\n");
				Dialog_Show(playerid, AddHouse, 1, "Add house", String1, "Add", "Back");
			}
			case 1: return 1;
		}
	}
	return 1;
}

Dialog:AddHouse(playerid, response, listitem, inputtext[]) {
	if(!response) return Dialog_Show(playerid, AddMenu, DIALOG_STYLE_LIST, "Add menu", "\
   			Add house\n\
   			Add bussiness", "OK", "Cancel");
	new price, type, Float: X, Float: Y, Float: Z;
	if(sscanf(inputtext,"p<,>ii", price, type))
	{
		new String1[1000];
		strcat(String1,"\
		Syntax: price, number\n\n\
		Sample: 24000, 19\n\n");
		strcat(String1,"1. [Class: A]\t12. [Class: C]\t23. [Class: C]\t34. [Class: C]\n");
		strcat(String1,"2. [Class: C]\t13. [Class: C]\t24. [Class: B]\t35. [Class: C]\n");
		strcat(String1,"3. [Class: B]\t14. [Class: B]\t25. [Class: B]\n");
		strcat(String1,"4. [Class: D]\t15. [Class: C]\t26. [Class: D]\n");
		strcat(String1,"5. [Class: B]\t16. [Class: B]\t27. [Class: D]\n");
		strcat(String1,"6. [Class: B]\t17. [Class: B]\t28. [Class: D]\n");
		strcat(String1,"7. [Class: D]\t18. [Class: A]\t29. [Class: C]\n");
		strcat(String1,"8. [Class: B]\t19. [Class: C]\t30. [Class: A]\n");
		strcat(String1,"9. [Class: A]\t20. [Class: D]\t31. [Class: C]\n");
		strcat(String1,"10. [Class: B]\t21. [Class: A]\t32. [Class: C]\n");
		strcat(String1,"11. [Class: C]\t22. [Class: B]\t33. [Class: D]\n");
		return Dialog_Show(playerid, AddHouse, 1, "Add house", String1, "Add", "Back");
	}
	TOTAL_HOUSES++;
	GetPlayerPos(playerid, X, Y, Z);
	House[TOTAL_HOUSES][hEntranceX] = X;
	House[TOTAL_HOUSES][hEntranceY] = Y;
	House[TOTAL_HOUSES][hEntranceZ] = Z;
	switch(type)
	{
		case 1: format(String, 90, "435.4139, 1315.7772, 1615.5118, A, 5");
		case 2: format(String, 90, "-376.3782, 1026.7642, 1713.0265, C, 9");	
		case 3: format(String, 90, "2163.3025, 2821.6401, 1716.2335, B, 6");	
		case 4: format(String, 90, "-1181.7406, 2080.4648, 2741.2014, D, 15");	
		case 5: format(String, 90, "2237.5413, -1081.1516, 1049.04, B, 2");
		case 6: format(String, 90, "24.0716, 1340.1615, 1084.3750, B, 10");	
		case 7: format(String, 90, "2259.5068, -1135.9337, 1050.6328, D, 10");	
		case 8: format(String, 90, "2196.8469, -1204.3524, 1049.0234, B, 6");	
		case 9: format(String, 90, "2317.7983, -1026.7651, 1050.2178, A, 9");	
		case 10: format(String, 90, "2365.3345, -1135.5907, 1050.8826, B, 8");	
		case 11: format(String, 90, "2282.8831, -1140.0713, 1050.8984, C, 11");	
		case 12: format(String, 90, "2218.3875, -1076.1580, 1050.4844, C, 1");	
		case 13: format(String, 90, "-68.8411, 1351.3397, 1080.2109, C, 6");	
		case 14: format(String, 90, "-283.6001, 1471.2211, 1084.3750, B, 15");	
		case 15: format(String, 90, "-42.5525, 1405.6432, 1084.4297, C, 8");	
		case 16: format(String, 90, "83.0791, 1322.2808, 1083.8662, B, 9");	
		case 17: format(String, 90, "447.2238, 1397.2926, 1084.3047, B, 2");	
		case 18: format(String, 90, "235.2748, 1186.6809, 1080.2578, A, 3");	
		case 19: format(String, 90, "226.4436, 1239.9277, 1082.1406, C, 2");	
		case 20: format(String, 90, "244.0883, 305.0291, 999.1484, D, 1");	
		case 21: format(String, 90, "226.2956, 1114.1615, 1080.9929, A, 5");	
		case 22: format(String, 90, "295.2479, 1472.2650, 1080.2578, B, 15");	
		case 23: format(String, 90, "261.1874, 1284.2982, 1080.2578, C, 4");	
		case 24: format(String, 90, "-260.4934, 1456.8430, 1084.3672, B, 4");	
		case 25: format(String, 90, "22.9848, 1403.3345, 1084.4370, B, 5");	
		case 26: format(String, 90, "2468.2080, -1698.2988, 1013.5078, D, 2");	
		case 27: format(String, 90, "266.9498, 304.9866, 999.1484, D, 2");	
		case 28: format(String, 90, "422.3438, 2536.4980, 10.0000, D, 10");	
		case 29: format(String, 90, "443.4504, 509.2181, 1001.4195, C, 12");	
		case 30: format(String, 90, "2324.3977, -1149.0601, 1050.7101, A, 12");
		case 31: format(String, 90, "2807.6919, -1174.2933, 1025.5703, C, 8");	
		case 32: format(String, 90, "2233.6965, -1115.1270, 1050.8828, C, 5");
		case 33: format(String, 90, "221.7789, 1140.1970, 1082.6094, D, 4");
		case 34: format(String, 90, "387.1313, 1471.7137, 1080.1949, C, 15");
		case 35: format(String, 90, "377.1231, 1417.3163, 1081.3281, C, 15"); // [интерьер 4 звёздочный](меню) int 4
	}
	sscanf(String,"p<,>fffsi",
	House[TOTAL_HOUSES][hExitX],
	House[TOTAL_HOUSES][hExitY],
	House[TOTAL_HOUSES][hExitZ],
	House[TOTAL_HOUSES][hClass],
	House[TOTAL_HOUSES][hInterior]);

	House[TOTAL_HOUSES][hWorld] = TOTAL_HOUSES;
	House[TOTAL_HOUSES][hPrice] = price;

	strmid(House[TOTAL_HOUSES][hOwner], "None", 0, strlen("None"), MAX_PLAYER_NAME);
	House[TOTAL_HOUSES][hIcon] = CreateDynamicMapIcon(House[TOTAL_HOUSES][hEntranceX], House[TOTAL_HOUSES][hEntranceY], House[TOTAL_HOUSES][hEntranceZ], 31, 0, -1, -1, -1, 200.0);
	House[TOTAL_HOUSES][hPickup] = CreatePickup(1273,1, House[TOTAL_HOUSES][hEntranceX], House[TOTAL_HOUSES][hEntranceY], House[TOTAL_HOUSES][hEntranceZ]);
	House[TOTAL_HOUSES][hPickupExit] = CreatePickup(19134, 1, House[TOTAL_HOUSES][hExitX], House[TOTAL_HOUSES][hExitY], House[TOTAL_HOUSES][hExitZ], House[TOTAL_HOUSES][hWorld]);

	format(String, 512, "INSERT INTO `houses` (ID, EntranceX, EntranceY, EntranceZ, ExitX, ExitY, ExitZ, Class, Price, Interior, World)\
	VALUES (%d, '%f', '%f', '%f', '%f', '%f', '%f', '%s', %d, %d, %d)",
	TOTAL_HOUSES,
	House[TOTAL_HOUSES][hEntranceX],
	House[TOTAL_HOUSES][hEntranceY],
	House[TOTAL_HOUSES][hEntranceZ],
	House[TOTAL_HOUSES][hExitX],
	House[TOTAL_HOUSES][hExitY],
	House[TOTAL_HOUSES][hExitZ],
	House[TOTAL_HOUSES][hClass],
	House[TOTAL_HOUSES][hPrice],
	House[TOTAL_HOUSES][hInterior],
	House[TOTAL_HOUSES][hWorld]);
	mysql_tquery(g_SQL, String, "", "");
	format(String, 64, "House nr. %d created", TOTAL_HOUSES);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	return 1;
}

Dialog:Teleports(playerid, response, listitem, inputtext[])
{
	if(!response) return 1;
	switch(listitem)
	{
		case 0: Dialog_Show(playerid, LS_Teleports, DIALOG_STYLE_LIST, "Los Santos teleports", "\
			Unity station\n\
			Airport\n\
			Bank\n\
			Car dealership\n\
			Hospital\n\
			Police departament\n\
			Docks", "Choose", "Back");
		case 1: Dialog_Show(playerid, SF_Teleports, DIALOG_STYLE_LIST, "San Fierro teleports", "\
			Train station\n\
			Car dealership\n\
			Bank\n\
			Hospital\n\
			Police departament\n\
			Docks", "Choose", "Back");
		case 2: Dialog_Show(playerid, LV_Teleports, DIALOG_STYLE_LIST, "Las Venturas teleports", "\
			Train station\n\
			Car dealership\n\
			Bank\n\
			Casino Four Dragons\n\
			FBI\n\
			Hospital", "Choose", "Back");
	}
	return 1;
}

Dialog:LS_Teleports(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, Teleports, DIALOG_STYLE_LIST, "Teleports", "\
		Los Santos\n\
		San Fierro\n\
		Las Venturas", "OK", "Cancel");
	new Float: X, Float: Y, Float: Z;
	switch(listitem)
	{
		case 0: X = 1792.6862, Y = -1924.5055, Z = 13.3904;		// Unity station
		case 1: X = 1681.5308, Y = -2319.1914, Z = 13.3828; 	// Airport
		case 2: X = 1749.5062, Y = -1668.5699, Z = 13.3828; 	// Bank
		case 3: X = 558.0125, Y = -1243.7642, Z = 17.0432; 		// Car dealership
		case 4: X = 1201.1337, Y = -1327.0913, Z = 13.3984; 	// Hospital
		case 5: X = 1529.3977, Y = -1671.9962, Z = 13.3828; 	// Police departament
		case 6: X = 2320.9243, Y = -2336.6333, Z = 13.3828; 	// Docks
	}
	if(GetPlayerState(playerid) == 2) SetVehiclePos(GetPlayerVehicleID(playerid), X, Y, Z);
	else SetPlayerPos(playerid, X, Y, Z);
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	return 1;
}

Dialog:SF_Teleports(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, Teleports, DIALOG_STYLE_LIST, "Teleports", "\
		Los Santos\n\
		San Fierro\n\
		Las Venturas", "OK", "Cancel");
	new Float: X, Float: Y, Float: Z;
	switch(listitem)
	{
		case 0: X = -1990.0402, Y = 136.6163, Z = 27.5391; 		// Train station
		case 1: X = -2004.2463, Y = 293.7323, Z = 34.3055; 		// Car dealership
		case 2: X = -2003.5768, Y = 472.4563, Z = 35.0156; 		// Bank
		case 3: X = 0, Y = 0, Z = 0; 							// Airport
		case 4: X = -2669.4023, Y = 588.1659, Z = 14.4531; 		// Hospital
		case 5: X = -1600.3721, Y = 725.8822, Z = 10.8759; 		// Police departament
		case 6: X = -1742.4924, Y = -91.5269, Z = 3.5547; 		// Docks
	}
	if(GetPlayerState(playerid) == 2) SetVehiclePos(GetPlayerVehicleID(playerid), X, Y, Z);
	else SetPlayerPos(playerid, X, Y, Z);
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	return 1;
}

Dialog:LV_Teleports(playerid, response, listitem, inputtext[])
{
	if(!response) return Dialog_Show(playerid, Teleports, DIALOG_STYLE_LIST, "Teleports", "\
		Los Santos\n\
		San Fierro\n\
		Las Venturas", "OK", "Cancel");
	new Float: X, Float: Y, Float: Z;
	switch(listitem)
	{
		case 0: X = 2809.0369, Y = 1280.9080, Z = 10.7500; 		// Train station
		case 1: X = 0, Y = 0, Z = 0; 							// Car dealership
		case 2: X = 2039.6333, Y = 1913.1333, Z = 12.170;     	// Bank
		case 3: X = 2039.8375, Y = 1009.5300, Z = 10.6719; 		// Casino Four Dragons
		case 4: X = 2289.5801, Y = 2418.1296, Z = 11.1030; 		// FBI
		case 5: X = 2127.9524, Y = 2349.3767, Z = 10.6719;    	// Hospital
	}
	if(GetPlayerState(playerid) == 2) SetVehiclePos(GetPlayerVehicleID(playerid), X, Y, Z);
	else SetPlayerPos(playerid, X, Y, Z);
	SetPlayerInterior(playerid, 0);
	SetPlayerVirtualWorld(playerid, 0);
	return 1;
}

// 1337 ADMIN COMMANDS

CMD:setadmin(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 1337 || !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to LVL 1337 admins!");
	if(sscanf(params, "ud", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/setadmin [Player's ID/Name] [Admin LVL]");
	if(params[0] == playerid) return SendErrorMessage(playerid, COLOR_GREY, "You cannot set your own admin lvl!");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	if(params[1] > 1337 || params[1] < 0) return SendErrorMessage(playerid, COLOR_GREY, "Admin LVL from 0 to 1337!");
	Player[params[0]][Admin] = params[1];
	format(String, 128, "You just set %s admin level to %d.", Player[params[0]][Name], params[1]);
	format(String, 128, "Administrator %s set your admin level to %d.", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	mysql_format(g_SQL, query, 145, "UPDATE `players` SET `Admin` = %d WHERE `ID` = %d LIMIT 1", params[1]);
	mysql_tquery(g_SQL, query);
	Log(adminlog, INFO, "Administrator %s set %s admin level to %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:cp(playerid, params[]) return cmd_controlpanel(playerid, params);
CMD:controlpanel(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 1337 || !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to LVL 1337 admins!");
	Dialog_Show(playerid, ControlPanel, DIALOG_STYLE_LIST, "Server control panel", "\
		Change server hostname\n\
		Set servers password\n\
		Change servers 'mode'\n\
		Change servers 'language'\n\
		Restart server", "OK", "Cancel");
	return 1;
}

CMD:add(playerid, params[])
{
    if(Player[playerid][LoggedIn] == false) return 1;
   	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 1337 || !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to LVL 1337 admins!");
   	Dialog_Show(playerid, AddMenu, DIALOG_STYLE_LIST, "Add menu", "\
   		Add house\n\
   		Add bussiness", "OK", "Cancel");
	return 1;
}

CMD:resetmoney(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 1337 || !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to LVL 1337 admins!");
	if(sscanf(params, "u", params[0])) return SendSyntaxMessage(playerid, -1, "/resetmoney [Player's ID/Name]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, -1, PLAYER_NOT_ONLINE);
	ResetMoney(params[0]);
	format(String, 128, "You just reseted %s money!", Player[params[0]][Name]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 128, "Administrator %s just reseted your money!", Player[playerid][Name]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s reseted %s money", Player[playerid][Name], Player[params[0]][Name]);
	return 1;
}

CMD:givemoney(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 1337 || !IsPlayerAdmin(playerid)) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to LVL 1337 admins!");
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/givemoney [Player's ID/Name] [Amount of money]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	if(params[1] < 0 || params[1] > 20000000) return SendErrorMessage(playerid, COLOR_GREY, "Amount of money from 0 to 20'000'000!");
	GiveMoney(params[0], params[1]);
	format(String, 128, "You just gave %s %d dollars!", Player[params[0]], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 256, "Administrator %s just gave you %d dollars!", Player[playerid][Name], params[1]);
	Log(adminlog, INFO, "Administrator %s just gave %s %d dollars", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

// ADMIN COMMANDS

CMD:o(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(isnull(params)) return SendSyntaxMessage(playerid, -1, "/o [Message]");
	format(String, 100, "[A] %s: %s", Player[playerid][Name], params[0]);
	SendClientMessageToAll(-1, String);
	return 1;
}

CMD:kick(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "us[32]", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/kick [Player's ID/Name] [Reason]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	format(String, 128, "Administrator %s kicked %s out of server with reason: %s", Player[playerid][Name], Player[params[0]][Name], params[1]);
	SendClientMessageToAll(COLOR_LIGHTRED, String);
	SendClientMessage(playerid, COLOR_ORANGE, "Please, obey the server rules!");
	SendClientMessage(playerid, COLOR_ORANGE, "After a few kicks you can receive a ban!");
	Kick(params[1]);
	Log(adminlog, INFO, "Administrator %s kicked %s with reason: %s", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:setskin(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/setskin [Player's ID/Name] [Reason]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	if(params[1] < 0 || params[1] > 311) return SendErrorMessage(playerid, COLOR_GREY, "Skin ID from 0 to 311!");
	SetPlayerSkin(params[0], params[1]);
	format(String, 100, "You just set %s skin to ID %d", Player[params[0]][Name], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 100, "Administrator %s set your skin to ID %d", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	mysql_format(g_SQL, query, 145, "UPDATE `players` SET `Skin` = %d WHERE `ID` = %d LIMIT 1", params[1]);
	mysql_tquery(g_SQL, query);
	Log(adminlog, INFO, "Administrator %s set %s skin to ID %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:veh(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(GetPlayerInterior(playerid) > 0) return SendErrorMessage(playerid, COLOR_GREY, "You cannot spawn a vehicle in interior!");
	if(sscanf(params, "iii", params[0], params[1], params[2])) return SendSyntaxMessage(playerid, -1, "/veh [Vehicle's ID] [Color 1] [Color 2]");
	if(params[0] < 400 || params[0] > 611) return SendErrorMessage(playerid, COLOR_GREY, "Vehicle's ID from 400 to 611!");
	if(params[1] < 0 || params[1] > 255) return SendErrorMessage(playerid, COLOR_GREY, "Color 1 from 0 to 255!");
	if(params[2] < 0 || params[2] > 255) return SendErrorMessage(playerid, COLOR_GREY, "Color 2 from 0 to 255!");
	new Float: X, Float: Y, Float: Z;
	GetPlayerPos(playerid, X, Y, Z);
	new vehID = CreateVehicle(params[0], X, Y, Z, 0.0, params[1], params[2], -1);
	SetVehicleVirtualWorld(vehID, GetPlayerVirtualWorld(playerid));
	Iter_Add(admin_vehicle, vehID);
	PutPlayerInVehicle(playerid, vehID, 0);
	Log(adminlog, INFO, "Administrator %s spawned vehicle ID %d. (Model: %d)", Player[playerid][Name], vehID, params[0]);
	return 1;
}

CMD:delveh(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(!IsPlayerInAnyVehicle(playerid)) return SendErrorMessage(playerid, COLOR_GREY, NOT_IN_VEHICLE);
	new vehID = GetPlayerVehicleID(playerid);
	new vehModel = GetVehicleModel(vehID);
	if(!Iter_Contains(admin_vehicle, vehID)) return SendErrorMessage(playerid, COLOR_GREY, "This vehicle wasn't spawned by any admin!");
	if(IsValidVehicle(vehID)) DestroyVehicle(vehID);
	Iter_Remove(admin_vehicle, playerid);
	SendClientMessage(playerid, -1, "Vehicle destroyed!");
	Log(adminlog, INFO, "Administrator %s destroyed admin vehicle ID %d. (Model: %d)", Player[playerid][Name], vehID, vehModel);
	return 1;
}

CMD:delallveh(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(Player[playerid][Admin] < 6) return SendErrorMessage(playerid, COLOR_GREY, "Command available only to 6+ lvl administrators.");
	foreach(new i: admin_vehicle)
	{
	    if(IsValidVehicle(i))
	    {
			DestroyVehicle(i);
		}
	}
	Iter_Clear(admin_vehicle);
	Log(adminlog, INFO, "Administrator %s destroyed all admin vehicles", Player[playerid][Name]);
	return 1;
}

CMD:sethp(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/sethp [Player's ID/Name] [Amount of HP]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	SetHealth(params[0], params[1]);
	format(String, 128, "You just set %s HP to %d.", Player[params[0]], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 256, "Administrator %s just set your HP to %d.", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s set %s HP to %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	

	return 1;
}

CMD:setarmor(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/setarmor [Player's ID/Name] [Amount of HP]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	SetArmor(params[0], params[1]);
	format(String, 128, "You just set %s armor to %d.", Player[params[0]], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 256, "Administrator %s just set your armor to %d.", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s set %s armor to %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:setinterior(playerid, params[]) return cmd_setint(playerid, params);
CMD:setint(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/setint [Player's ID/Name] [Interior]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	if(params[1] < 0 || params[1] > 50) return SendErrorMessage(playerid, COLOR_GREY, "Interior from 0 to 50!");
	SetPlayerInterior(params[0], params[1]);
	format(String, 128, "You set %s interior to %d.", Player[params[0]][Name], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 128, "Administrator %s just set your interior to %d.", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s set %s interior to %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:setvirtualworld(playerid, params[]) return cmd_setvw(playerid, params);
CMD:setvw(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	if(sscanf(params, "ui", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/setvw [Player's ID/Name] [Virtual World]");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	if(params[1] < 0 || params[1] > 50) return SendErrorMessage(playerid, COLOR_GREY, "Virtual World from 0 to 50!");
	SetPlayerVirtualWorld(params[0], params[1]);
	format(String, 128, "You set %s interior to %d.", Player[params[0]][Name], params[1]);
	SendClientMessage(playerid, COLOR_ORANGE, String);
	format(String, 128, "Administrator %s just set your interior to %d.", Player[playerid][Name], params[1]);
	SendClientMessage(params[0], COLOR_ORANGE, String);
	Log(adminlog, INFO, "Administrator %s set %s interior to %d", Player[playerid][Name], Player[params[0]][Name], params[1]);
	return 1;
}

CMD:tp(playerid, params[]) return cmd_teleports(playerid, params);
CMD:teles(playerid, params[]) return cmd_teleports(playerid, params);
CMD:teleport(playerid, params[]) return cmd_teleports(playerid, params);
CMD:teleports(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(Player[playerid][Admin] <= 0) return SendErrorMessage(playerid, COLOR_GREY, CMD_NOT_AVAILABLE);
	Dialog_Show(playerid, Teleports, DIALOG_STYLE_LIST, "Teleports", "\
		Los Santos\n\
		San Fierro\n\
		Las Venturas", "OK", "Cancel");
	return 1;
}

// PLAYER COMMANDS

CMD:b(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(sscanf(params, "s[128]", params[0])) return SendSyntaxMessage(playerid, -1, "/b [Message]");
	format(String, 128, "(( [OOC] %s: %s ))", Player[playerid][Name], params[0]);
	SendLocalMessage(30.0, playerid, COLOR_GREY, String);
	return 1;
}

CMD:me(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(isnull(params)) return SendSyntaxMessage(playerid, -1, "/me [Action]");
	format(String, 128, "* %s %s", Player[playerid][Name], params[0]);
	SendLocalMessage(30.0, playerid, COLOR_PURPLE, String);
	return 1;
}

CMD:do(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(isnull(params)) return SendSyntaxMessage(playerid, -1, "/do [Action]");
	format(String, 128, "* %s (%s)", params[0], Player[playerid][Name]);
	SendLocalMessage(30.0, playerid, COLOR_PURPLE, String);
	return 1;
}

CMD:s(playerid, params[]) return cmd_shout(playerid, params);
CMD:shout(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(isnull(params)) return SendSyntaxMessage(playerid, -1, "/(s)hout [Message]");
	format(String, 128, "%s shouts: %s", Player[playerid][Name], params[0]);
	SendLocalMessage(60.0, playerid, -1, String);
	return 1;
}

CMD:pm(playerid, params[])
{
	if(Player[playerid][LoggedIn] == false) return 1;
	if(sscanf(params, "us[64]", params[0], params[1])) return SendSyntaxMessage(playerid, -1, "/pm [Player's ID/Name] [Message]");
	//if(params[0] == playerid) return SendErrorMessage(playerid, COLOR_GREY, "You cannot send a personal message to yourself!");
	if(!IsPlayerConnected(params[0])) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_ONLINE);
	if(Player[params[0]][LoggedIn] == false) return SendErrorMessage(playerid, COLOR_GREY, PLAYER_NOT_LOGGED);
	format(String, 128, "[PM] To {FF6347}%s {FFFFFF}({FF6347}%d{FFFFFF}): %s", Player[params[0]][Name], params[0], params[1]);
	SendClientMessage(playerid, -1, String);
	format(String, 128, "[PM] From {FF6347}%s {FFFFFF}({FF6347}%d{FFFFFF}): %s", Player[playerid][Name], playerid, params[1]);
	SendClientMessage(params[0], -1, String);
	return 1;
}
