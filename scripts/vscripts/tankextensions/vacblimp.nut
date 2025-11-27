local VACBLIMP_VALUES_TABLE = {
	VACBLIMP_SHIELD_MODEL      = "models/props_mvm/blimp_shield.mdl"
	VACBLIMP_SND_DEPLOY        = "player/invuln_on_vaccinator.wav"
	VACBLIMP_SND_RESIST        = ")player/resistance_medium1.wav"
	VACBLIMP_RESIST_MULT       = 0
	VACBLIMP_COLOR_CYCLE_SPEED = 5
	VACBLIMP_MODEL_DEFAULT = "models/bots/boss_blimp/boss_blimp.mdl"
	VACBLIMP_MODEL_DAMAGE1 = "models/bots/boss_blimp/boss_blimp_damage1.mdl"
	VACBLIMP_MODEL_DAMAGE2 = "models/bots/boss_blimp/boss_blimp_damage2.mdl"
	VACBLIMP_MODEL_DAMAGE3 = "models/bots/boss_blimp/boss_blimp_damage3.mdl"
	VACBLIMP_SOUND_ENGINE = ")ambient/turbine3.wav"
}
foreach(k,v in VACBLIMP_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(VACBLIMP_SHIELD_MODEL)
PrecacheModel(VACBLIMP_MODEL_DEFAULT)
PrecacheModel(VACBLIMP_MODEL_DAMAGE1)
PrecacheModel(VACBLIMP_MODEL_DAMAGE2)
PrecacheModel(VACBLIMP_MODEL_DAMAGE3)
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
	Model =
	{
	Default = VACBLIMP_MODEL_DEFAULT
	Damage1 = VACBLIMP_MODEL_DAMAGE1
	Damage2 = VACBLIMP_MODEL_DAMAGE2
	Damage3 = VACBLIMP_MODEL_DAMAGE3
	}
	DisableChildModels = 1
	NoScreenShake      = 1
	EngineLoopSound    = VACBLIMP_SOUND_ENGINE
	NoDestructionModel = 1
	NoGravity          = 1
	function OnSpawn()
	{
		local sParams = split(sTankName, "|")
		local iParamsLength = sParams.len()

		if(sParams[0].find("_red")) self.SetTeam(TF_TEAM_RED)

		local bParticles = false
		local hParticle1, hParticle2, hParticle3, hParticle4
		if(sParams[0].find("_customparticles"))
		{
			bParticles = true
			hParticle1 = SpawnEntityFromTable("info_particle_system", { angles = QAngle(10, 106, -10), effect_name = "mvm_blimp_smoke", start_active = 1 })
			hParticle2 = SpawnEntityFromTable("info_particle_system", { angles = QAngle(10, 106, -10), effect_name = "mvm_blimp_smoke_exhaust" })
			TankExt.SetParentArray([hParticle1, hParticle2], self, "smoke_attachment")
			hParticle3 = SpawnEntityFromTable("info_particle_system", { angles = QAngle(90, 0, -90), effect_name = "mvm_blimp_propeller_wind", start_active = 1 })
			TankExt.SetParentArray([hParticle3], self, "propeller_l")
			hParticle4 = SpawnEntityFromTable("info_particle_system", { angles = QAngle(90, 0, -90), effect_name = "mvm_blimp_propeller_wind", start_active = 1 })
			TankExt.SetParentArray([hParticle4], self, "propeller_r")
		}

		if(iParamsLength >= 2)
		{
			SetPropInt(self, "m_iTextureFrameIndex", 2)
			self.AcceptInput("Color", sParams[1], null, null)
		}

		local flSpeedLast         = 75.0
		local flHealthPercentLast = 1.0

		local iBombAttachment  = self.LookupAttachment("bomb_pos")
		local iPropAttachmentL = self.LookupAttachment("propeller_l")
		local iPropAttachmentR = self.LookupAttachment("propeller_r")
		local iPropPoseL       = self.LookupPoseParameter("prop_spin_l")
		local iPropPoseR       = self.LookupPoseParameter("prop_spin_r")

		local vecBombLast  = Vector()
		local vecPropLastL = self.GetAttachmentOrigin(iPropAttachmentL)
		local vecPropLastR = self.GetAttachmentOrigin(iPropAttachmentR)
		local flPropDegL   = 0.0
		local flPropDegR   = 0.0
		local flPropSpeed  = 20.0
		local bDeploying   = false
		local bFoundWorld  = false
		function Think()
		{
			if(bParticles)
			{
				local flSpeed = GetPropFloat(self, "m_speed")
				if(flSpeed == 0.0 && flSpeedLast != 0.0)
				{
					hParticle3.AcceptInput("Stop", null, null, null)
					hParticle4.AcceptInput("Stop", null, null, null)
				}
				else if(flSpeed != 0.0 && flSpeedLast == 0.0)
				{
					hParticle3.AcceptInput("Start", null, null, null)
					hParticle4.AcceptInput("Start", null, null, null)
				}
				flSpeedLast = flSpeed

				local flHealthPercent = iHealth / iMaxHealth.tofloat()
				if(flHealthPercent <= 0.5 && flHealthPercentLast > 0.5)
				{
					hParticle1.AcceptInput("Stop", null, null, null)
					hParticle2.AcceptInput("Start", null, null, null)
				}
				else if(flHealthPercent > 0.5 && flHealthPercentLast <= 0.5)
				{
					hParticle1.AcceptInput("Start", null, null, null)
					hParticle2.AcceptInput("Stop", null, null, null)
				}
				flHealthPercentLast = flHealthPercent
			}
			if(!bDeploying)
			{
				local vecPropL = self.GetAttachmentOrigin(iPropAttachmentL)
				local vecPropR = self.GetAttachmentOrigin(iPropAttachmentR)
				local flMath   = flPropSpeed / FrameTime() / 80
				if((flPropDegL += (vecPropL - vecPropLastL).Length2D() * flMath) > 360) flPropDegL -= 360
				if((flPropDegR += (vecPropR - vecPropLastR).Length2D() * flMath) > 360) flPropDegR -= 360
				self.SetPoseParameter(iPropPoseL, flPropDegL)
				self.SetPoseParameter(iPropPoseR, flPropDegR)
				vecPropLastL = vecPropL
				vecPropLastR = vecPropR

				if(self.GetSequenceName(self.GetSequence()) == "deploy")
				{
					bDeploying  = true
					vecBombLast = self.GetAttachmentOrigin(iBombAttachment)
					TankExt.DelayFunction(self, this, 7.5, function() // prevents the sound that plays when the bomb fits through the hole
					{
						self.StopSound("MVM.TankDeploy")
					})
					if(bParticles)
					{
						hParticle3.AcceptInput("Stop", null, null, null)
						hParticle4.AcceptInput("Stop", null, null, null)
					}
				}
			}
			else if(!bFoundWorld)
			{
				local vecBomb = self.GetAttachmentOrigin(iBombAttachment)
				local Trace = {
					start = vecBombLast
					end   = vecBomb
					mask  = CONTENTS_SOLID | CONTENTS_WINDOW | CONTENTS_MOVEABLE
				}
				TraceLineEx(Trace)
				if(Trace.hit)
				{
					bFoundWorld = true
					TankExt.DelayFunction(self, this, 0.35, function()
					{
						self.SetCycle(1.0) // ends deploy sequence
					})
				}
				vecBombLast = vecBomb
			}
		}
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
			hShield.SetModelScale(0.8,0)
		}
		if(sTankName.find("_blast"))
		{
			local hShield = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = 3, disableshadows = 1, rendermode = 1 })
			hShields.append(hShield)
			TankExt.SetParentArray([hShield], self)
			iDamageFilter = iDamageFilter | DMG_BLAST
			hShield.SetModelScale(0.8,0)
		}
		if(sTankName.find("_fire"))
		{
			local hShield = TankExt.SpawnEntityFromTableFast("prop_dynamic", { model = VACBLIMP_SHIELD_MODEL, skin = 4, disableshadows = 1, rendermode = 1 })
			hShields.append(hShield)
			TankExt.SetParentArray([hShield], self)
			iDamageFilter = iDamageFilter | DMG_BURN | DMG_IGNITE
			hShield.SetModelScale(0.8,0)
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
				hShieldFade.SetModelScale(0.8,0)
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
	}
})