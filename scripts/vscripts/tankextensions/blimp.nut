local BLIMP_VALUES_TABLE = {
	BLIMP_MODEL        = "models/bots/boss_bot/boss_blimp_pure.mdl"
	BLIMP_MODEL_DAMAGE1 = "models/bots/boss_bot/boss_blimp_main_damage1.mdl"
	BLIMP_MODEL_DAMAGE2 = "models/bots/boss_bot/boss_blimp_main_damage2.mdl"
	BLIMP_MODEL_DAMAGE3 = "models/bots/boss_bot/boss_blimp_main_damage3.mdl"
	BLIMP_SOUND_ENGINE = ")ambient/turbine3.wav"
}
foreach(k,v in BLIMP_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(BLIMP_MODEL)
TankExt.PrecacheSound(BLIMP_SOUND_ENGINE)

TankExt.NewTankType("blimp", {
	Model =
	{
	Default = VACBLIMP_MODEL_DEFAULT
	Damage1 = VACBLIMP_MODEL_DAMAGE1
	Damage2 = VACBLIMP_MODEL_DAMAGE2
	Damage3 = VACBLIMP_MODEL_DAMAGE3
	}
	DisableChildModels = 1
	NoScreenShake      = 1
	EngineLoopSound    = BLIMP_SOUND_ENGINE
	NoDestructionModel = 1
	NoGravity          = 1
	function OnSpawn()
	{
		self.SetSkin(self.GetTeam() == TF_TEAM_BLUE ? 1 : 0)
	}
})

local BlimpRedTable = clone TankExt.TankScripts.blimp
BlimpRedTable.TeamNum <- 2
TankExt.NewTankType("blimp_red", BlimpRedTable)