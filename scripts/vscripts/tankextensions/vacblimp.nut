local VACBLIMP_VALUES_TABLE = {
	VACBLIMP_SHIELD_MODEL      = "models/props_mvm/blimp_shield.mdl"
	VACBLIMP_SND_DEPLOY        = "player/invuln_on_vaccinator.wav"
	VACBLIMP_SND_RESIST        = ")player/resistance_medium1.wav"
	VACBLIMP_RESIST_MULT       = 0
	VACBLIMP_COLOR_CYCLE_SPEED = 5
	VACBLIMP_MODEL_DEFAULT = "models/bots/boss_bot/boss_blimp_pure.mdl"
	VACBLIMP_SOUND_ENGINE = ")ambient/turbine3.wav"
	VACBLIMP_SKIN_RED = 0
	VACBLIMP_SKIN_BLUE = 1
}
foreach(k,v in VACBLIMP_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(VACBLIMP_SHIELD_MODEL)
PrecacheModel(VACBLIMP_MODEL_DEFAULT)
TankExt.PrecacheSound(VACBLIMP_SND_DEPLOY)
TankExt.PrecacheSound(VACBLIMP_SOUND_ENGINE)

::VacBlimpEvents <- {
	OnGameEvent_recalculate_holidays = function(_) { if(GetRoundState() == 3) delete ::VacBlimpEvents }
	OnScriptHook_OnTakeDamage = function(params)
	{
		local hVictim = params.const_entity
		local hAttacker = params.attacker
		if(hVictim && hAttacker && hVictim.GetClassname() == "tank_boss" && hAttacker.GetTeam() != hVictim.GetTeam())
		{
			local VacScope = TankExt.GetMultiScopeTable(hVictim.GetScriptScope(), "vacblimp")
			if(VacScope && params.damage_type & VacScope.iDamageFilter)
			{
				params.damage *= VACBLIMP_RESIST_MULT
				VacScope.Resist()
				EmitSoundEx({
					sound_name  = VACBLIMP_SND_RESIST
					sound_level = 90
					entity      = hVictim
					filter_type = RECIPIENT_FILTER_GLOBAL
				})
			}
		}
	}
}
__CollectGameEventCallbacks(VacBlimpEvents)

TankExt.NewTankType("vacblimp*", {
	Model = VACBLIMP_MODEL_DEFAULT
	DisableChildModels = 1
	NoScreenShake      = 1
	EngineLoopSound    = VACBLIMP_SOUND_ENGINE
	NoDestructionModel = 1
	NoGravity          = 1
	function OnSpawn()
	{
		EmitSoundEx({
			sound_name  = VACBLIMP_SND_DEPLOY
			pitch       = 90
			filter_type = RECIPIENT_FILTER_GLOBAL
		})

		iDamageFilter <- 0
		local hShields = []

		if(sTankName.find("_bullet"))
		{
			local hShield = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = 2, disableshadows = 1, rendermode = 1 })
			hShields.append(hShield)
			TankExt.SetParentArray([hShield], self)
			iDamageFilter = iDamageFilter | DMG_BULLET | DMG_BUCKSHOT
		}
		if(sTankName.find("_blast"))
		{
			local hShield = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = 3, disableshadows = 1, rendermode = 1 })
			hShields.append(hShield)
			TankExt.SetParentArray([hShield], self)
			iDamageFilter = iDamageFilter | DMG_BLAST
		}
		if(sTankName.find("_fire"))
		{
			local hShield = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = 4, disableshadows = 1, rendermode = 1 })
			hShields.append(hShield)
			TankExt.SetParentArray([hShield], self)
			iDamageFilter = iDamageFilter | DMG_BURN | DMG_IGNITE
		}

		local iShieldsLength = hShields.len()
		local iCenterOffset  = 16 * (iShieldsLength - 1)
		local iOffset        = 0
		local iTeamNum       = self.GetTeam()
		foreach(hShield in hShields)
		{
			local hParticle = SpawnEntityFromTable("info_particle_system", {
				origin       = Vector(0, iOffset - iCenterOffset, 200)
				effect_name  = format("vaccinator_%s_buff%i", iTeamNum == TF_TEAM_BLUE ? "blue" : "red", hShield.GetSkin() - 1)
				start_active = 1
			})
			TankExt.SetParentArray([hParticle], self)
			iOffset += 32
		}

		function Resist()
		{
			local DeleteArray = []
			for(local hChild = self.FirstMoveChild(); hChild != null; hChild = hChild.NextMovePeer())
				if(GetPropInt(hChild, "m_nRenderFX") == kRenderFxFadeFast)
					DeleteArray.append(hChild)
			foreach(hShield in DeleteArray)
				hShield.Destroy()

			foreach(hShield in hShields)
			{
				local hShieldFade = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = hShield.GetSkin(), disableshadows = 1, renderfx = kRenderFxFadeFast })
				SetPropBool(hShieldFade, "m_bForcePurgeFixedupStrings", true)
				SetPropInt(hShieldFade, "m_clrRender", GetPropInt(hShield, "m_clrRender"))
				TankExt.SetParentArray([hShieldFade], self)
				EntFireByHandle(hShieldFade, "Kill", null, 1, null, null)
			}
		}
		if(iShieldsLength > 1)
		{
			local iAlphas = []
			foreach(k, v in hShields)
				iAlphas.append(k == 0 ? 255 : 0)
			local iColorIndex = 0
			function Think()
			{
				local iNextColorIndex = iColorIndex == iAlphas.len() - 1 ? 0 : iColorIndex + 1
				iAlphas[iColorIndex] -= VACBLIMP_COLOR_CYCLE_SPEED
				iAlphas[iNextColorIndex] += VACBLIMP_COLOR_CYCLE_SPEED
				if(iAlphas[iColorIndex] <= 0)
					iColorIndex = iNextColorIndex

				foreach(k, hShield in hShields)
					TankExt.SetEntityColor(hShield, 255, 255, 255, iAlphas[k])
			}
		}
		self.SetSkin(self.GetTeam() == TF_TEAM_BLUE ? 1 : 0)
	}
})