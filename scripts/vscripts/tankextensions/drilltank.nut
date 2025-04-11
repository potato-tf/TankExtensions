local DRILLTANK_VALUES_TABLE = {
	DRILLTANK_MODEL_DRILL            = "models/bots/boss_bot/tank_drill.mdl"
	DRILLTANK_DAMAGE                 = 50
	DRILLTANK_DAMAGE_DELAY           = 0.33
	DRILLTANK_DAMAGE_SPEED_PENALTY   = 0.25
	DRILLTANK_DAMAGE_DEBUFF_DURATION = 1
	DRILLTANK_FRIENDLY_FIRE          = false
	DRILLTANK_SOUND_SPIN             = ")ambient/sawblade.wav"
	DRILLTANK_FUNCTION_SOUND_HURT    = function()
	{
		local sSound = format(")ambient/sawblade_impact%i.wav", RandomInt(1, 2))
		TankExt.PrecacheSound(sSound)
		EmitSoundEx({
			sound_name  = sSound
			sound_level = 85
			pitch       = 90
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
		})
	}
}
foreach(k,v in DRILLTANK_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(DRILLTANK_MODEL_DRILL)
TankExt.PrecacheSound(DRILLTANK_SOUND_SPIN)

::DrillTankEvents <- {
	function OnGameEvent_recalculate_holidays(_) { if(GetRoundState() == 3) delete ::DrillTankEvents }
	function OnScriptHook_OnTakeDamage(params)
	{
		local hVictim   = params.const_entity
		local hAttacker = params.attacker
		if(hVictim && hAttacker && hAttacker.GetClassname() == "tank_boss")
		{
			local DrillScope = TankExt.GetMultiScopeTable(hAttacker, "drilltank")
			if(DrillScope) params.force_friendly_fire = DRILLTANK_FRIENDLY_FIRE
		}
	}
}
__CollectGameEventCallbacks(DrillTankEvents)

TankExt.NewTankType("drilltank", {
	function OnSpawn()
	{
		EmitSoundEx({
			sound_name  = DRILLTANK_SOUND_SPIN
			sound_level = 80
			pitch       = 85
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
		})

		local hBomb
		for(local hChild = self.FirstMoveChild(); hChild; hChild = hChild.NextMovePeer())
			if(hChild.GetModelName().tolower().find("bomb_mechanism"))
				hBomb = hChild

		local bFinalSkin = self.GetSkin() == 1
		local bBlueTeam  = self.GetTeam() == TF_TEAM_BLUE
		local iSkin      = bBlueTeam ? bFinalSkin ? 2 : 0 : bFinalSkin ? 6 : 4
		local hModel     = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = DRILLTANK_MODEL_DRILL, skin = iSkin })
		hModel.AcceptInput("SetAnimation", "drill_spin", null, null)
		local hDrillHurt = SpawnEntityFromTable("trigger_multiple", {
			origin       = "162 0 97"
			spawnflags   = 64
			OnStartTouch = "!selfRunScriptCodeDrill(activator)0-1"
		})
		hDrillHurt.SetSize(Vector(-46, -40, -40), Vector(46, 40, 40))
		hDrillHurt.SetSolid(SOLID_OBB)
		TankExt.SetParentArray([hModel, hDrillHurt], self)
		SetPropEntity(hDrillHurt, "m_pParent", null)

		local hTank = self
		hDrillHurt.ValidateScriptScope()
		hDrillHurt.GetScriptScope().Drill <- function(hEnt)
		{
			if((hEnt.GetClassname() == "player" && (DRILLTANK_FRIENDLY_FIRE || hEnt.GetTeam() != hTank.GetTeam())))
			{
				self.AcceptInput("Disable", null, null, null)
				EntFireByHandle(self, "Enable", null, DRILLTANK_DAMAGE_DELAY, null, null)
				hEnt.TakeDamageEx(hTank, hTank, null, Vector(), Vector(), DRILLTANK_DAMAGE, DMG_CRUSH)
				hEnt.SetAbsVelocity(Vector())
				hEnt.BleedPlayer(DRILLTANK_DAMAGE_DEBUFF_DURATION)
				hEnt.StunPlayer(DRILLTANK_DAMAGE_DEBUFF_DURATION, 1 - DRILLTANK_DAMAGE_SPEED_PENALTY, 1, hTank)
				DRILLTANK_FUNCTION_SOUND_HURT()
			}
		}

		local bDeploying = false
		function Think()
		{
			local iDrillSkin = hModel.GetSkin()
			if(iHealth / iMaxHealth.tofloat() <= 0.5) { if(iDrillSkin != iSkin + 1) hModel.SetSkin(iSkin + 1) }
			else if(iDrillSkin != iSkin) hModel.SetSkin(iSkin)

			if(!bDeploying && hBomb && hBomb.GetSequenceName(hBomb.GetSequence()) == "deploy")
			{
				bDeploying = true
				hModel.AcceptInput("SetAnimation", "drill_deploy", null, null)
				hDrillHurt.Kill()
				EmitSoundEx({
					sound_name  = DRILLTANK_SOUND_SPIN
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_STOP
				})
			}

		}
	}
	function OnDeath()
	{
		EmitSoundEx({
			sound_name  = "misc/null.wav"
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
			flags       = SND_STOP | SND_IGNORE_NAME
		})
	}
})