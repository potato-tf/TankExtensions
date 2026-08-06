local DRILLTANK_WATERMINE_VALUES_TABLE = {
	DRILLTANK_WATERMINE_MODEL                  = "models/bots/boss_bot/drill_tank/drill_tank.mdl"
	DRILLTANK_WATERMINE_MODEL_DAMAGE1          = "models/bots/boss_bot/drill_tank/drill_tank_damage1.mdl"
	DRILLTANK_WATERMINE_MODEL_DAMAGE2          = "models/bots/boss_bot/drill_tank/drill_tank_damage2.mdl"
	DRILLTANK_WATERMINE_MODEL_DAMAGE3          = "models/bots/boss_bot/drill_tank/drill_tank_damage3.mdl"
	DRILLTANK_WATERMINE_DAMAGE                 = 10
	DRILLTANK_WATERMINE_DAMAGE_DELAY           = 0.05
	DRILLTANK_WATERMINE_DAMAGE_SPEED_PENALTY   = 0.3
	DRILLTANK_WATERMINE_DAMAGE_DEBUFF_DURATION = 1
	DRILLTANK_WATERMINE_FRIENDLY_FIRE          = true
	DRILLTANK_WATERMINE_SOUND_SPIN1            = ")ambient/machines/machine_whine1.wav"
	DRILLTANK_WATERMINE_SOUND_SPIN2            = ")ambient/machines/spin_loop.wav"
	DRILLTANK_WATERMINE_HATCH_PARTICLE1        = "rocketbackblastsparks"
	DRILLTANK_WATERMINE_HATCH_PARTICLE2        = "halloween_boss_axe_hit_world"

	DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_L = "models/bots/boss_bot/ubertank/tank_uber_track_l.mdl"
	DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_R = "models/bots/boss_bot/ubertank/tank_uber_track_r.mdl"
	DRILLTANK_WATERMINE_SND_UBER             = "player/invulnerable_on.wav"
	DRILLTANK_WATERMINE_SND_UBER_OFF         = "player/invulnerable_off.wav"
	DRILLTANK_WATERMINE_SKIN_UBER_RED        = 4
	DRILLTANK_WATERMINE_SKIN_UBER_BLUE       = 5
}
foreach(k,v in DRILLTANK_WATERMINE_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(DRILLTANK_WATERMINE_MODEL)
PrecacheModel(DRILLTANK_WATERMINE_MODEL_DAMAGE1)
PrecacheModel(DRILLTANK_WATERMINE_MODEL_DAMAGE2)
PrecacheModel(DRILLTANK_WATERMINE_MODEL_DAMAGE3)
TankExt.PrecacheSound(DRILLTANK_WATERMINE_SOUND_SPIN1)
TankExt.PrecacheSound(DRILLTANK_WATERMINE_SOUND_SPIN2)
PrecacheSound(")ambient/sawblade.wav")
PrecacheSound("ambient/sawblade.wav")
PrecacheSound("physics/metal/canister_scrape_smooth_loop1.wav")

PrecacheModel(DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_L)
PrecacheModel(DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_R)
TankExt.PrecacheSound(DRILLTANK_WATERMINE_SND_UBER)
TankExt.PrecacheSound(DRILLTANK_WATERMINE_SND_UBER_OFF)

::DrillTankWatermineEvents <- {
	function OnGameEvent_recalculate_holidays(_) { if(GetRoundState() == 3) delete ::DrillTankWatermineEvents }
	function OnScriptHook_OnTakeDamage(params)
	{
		local hVictim   = params.const_entity
		local hAttacker = params.attacker
		if(hVictim && hAttacker)
		{
			if(hAttacker.GetClassname() == "tank_boss")
			{
				local DrillScope = TankExt.GetMultiScopeTable(hAttacker.GetScriptScope(), "drilltank_watermine")
				if(DrillScope) params.force_friendly_fire = DRILLTANK_WATERMINE_FRIENDLY_FIRE
			}

			if(hVictim.GetClassname() == "tank_boss" && hAttacker.GetTeam() != hVictim.GetTeam())
			{
				local DrillTankWatermineScope = TankExt.GetMultiScopeTable(hVictim.GetScriptScope(), "drilltank_watermine")
				if(DrillTankWatermineScope && DrillTankWatermineScope.bUbered)
				{
					params.damage = 0
					EmitSoundOn("FX_RicochetSound.Ricochet", hVictim)
				}
			}
		}
	}
}
__CollectGameEventCallbacks(DrillTankWatermineEvents)

TankExt.NewTankType("drilltank_watermine", {
	DisableBomb = 1
	Model = {
		Default = DRILLTANK_WATERMINE_MODEL
		Damage1 = DRILLTANK_WATERMINE_MODEL_DAMAGE1
		Damage2 = DRILLTANK_WATERMINE_MODEL_DAMAGE2
		Damage3 = DRILLTANK_WATERMINE_MODEL_DAMAGE3
	}
	function OnSpawn()
	{
		EmitSoundEx({
			sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN1
			sound_level = 80
			pitch       = 85
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
		})
		EmitSoundEx({
			sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN2
			sound_level = 80
			pitch       = 85
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
		})

		local hTrackL, hTrackR
		for(local hChild = self.FirstMoveChild(); hChild; hChild = hChild.NextMovePeer())
		{
			local sChildModel = hChild.GetModelName().tolower()
			if(sChildModel.find("track_l"))
				hTrackL = hChild
			else if(sChildModel.find("track_r"))
				hTrackR = hChild
		}

		local iSkinLast   = 0
		local bUberFizzle = false
		bUbered <- false
		function ToggleUber()
		{
			if(!bUberFizzle)
				if(!bUbered)
				{
					bUbered = true
					EmitSoundEx({
						sound_name  = DRILLTANK_WATERMINE_SND_UBER
						filter_type = RECIPIENT_FILTER_GLOBAL
					})
					iSkinLast = self.GetSkin()
					local bBlueTeam = self.GetTeam() == TF_TEAM_BLUE
					self.SetSkin(bBlueTeam ? DRILLTANK_WATERMINE_SKIN_UBER_BLUE : DRILLTANK_WATERMINE_SKIN_UBER_RED)
					hTrackL.SetSkin(bBlueTeam ? 1 : 0)
					hTrackR.SetSkin(bBlueTeam ? 1 : 0)
					SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetModelIndex(DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_L), 0)
					SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetModelIndex(DRILLTANK_WATERMINE_MODEL_UBERED_TRACK_R), 0)
				}
				else
				{
					bUberFizzle = true
					EmitSoundEx({
						sound_name  = DRILLTANK_WATERMINE_SND_UBER_OFF
						filter_type = RECIPIENT_FILTER_GLOBAL
					})
					TankExt.DelayFunction(self, this, 1, function()
					{
						bUbered     = false
						bUberFizzle = false
						self.SetSkin(iSkinLast)
						hTrackL.SetSkin(0)
						hTrackR.SetSkin(0)
						SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetPropInt(hTrackL, "m_nModelIndex"), 0)
						SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetPropInt(hTrackR, "m_nModelIndex"), 0)
						self.AcceptInput("Color", "255 255 255", null, null)
						hTrackL.AcceptInput("Color", "255 255 255", null, null)
						hTrackR.AcceptInput("Color", "255 255 255", null, null)
					})
				}
		}
		local DrillTankWatermineScope = this
		self.GetScriptScope().ToggleUber <- @() DrillTankWatermineScope.ToggleUber()

		local bFinalSkin = self.GetSkin() == 1
		local bBlueTeam  = self.GetTeam() == TF_TEAM_BLUE
		self.SetSkin(bBlueTeam ? bFinalSkin ? 3 : 2 : bFinalSkin ? 1 : 0)
		local hDrillHurt = SpawnEntityFromTableSafe("trigger_multiple", {
			origin       = "130 0 90"
			spawnflags   = 1
		})
		hDrillHurt.SetSize(Vector(-42, -64, -64), Vector(42, 64, 64))
		hDrillHurt.SetSolid(SOLID_OBB)
		hDrillHurt.ConnectOutput("OnStartTouch", "StartTouch")
		hDrillHurt.ConnectOutput("OnEndTouch", "EndTouch")
		TankExt.SetParentArray([hDrillHurt], self)

		local hTank     = self
		local hTouching = {}
		hDrillHurt.ValidateScriptScope()
		hDrillHurt.GetScriptScope().StartTouch <- function()
		{
			local iPlayerTeamNum = activator.GetTeam()
			if(DRILLTANK_WATERMINE_FRIENDLY_FIRE || iPlayerTeamNum != hTank.GetTeam())
			{
				if(hTouching.len() == 0)
					EmitSoundEx({
						sound_name  = ")ambient/sawblade.wav"
						sound_level = 85
						pitch       = 90
						entity      = hTank
						filter_type = RECIPIENT_FILTER_GLOBAL
					})

				hTouching[activator] <- iPlayerTeamNum
			}
		}
		hDrillHurt.GetScriptScope().EndTouch <- function()
		{
			if(activator in hTouching)
			{
				delete hTouching[activator]
				if(hTouching.len() == 0)
					EmitSoundEx({
						sound_name  = ")ambient/sawblade.wav"
						entity      = hTank
						filter_type = RECIPIENT_FILTER_GLOBAL
						flags       = SND_STOP
					})
			}
		}

		local bDeploying        = false
		local flTimeDeployStart = 0
		local flTimeSparkLast   = 0
		local flTimeDrillLast   = 0
		local vecDeploy         = Vector()
		function Think()
		{
			if(bUberFizzle)
			{
				local flColor = 127.5 - sin(flTime * 20.95) * 127.5 // 20.95 == PI / 0.3 * 0.5
				local sColor  = format("%i %i %i", flColor, flColor, flColor)
				self.AcceptInput("Color", sColor, null, null)
				hTrackL.AcceptInput("Color", sColor, null, null)
				hTrackR.AcceptInput("Color", sColor, null, null)
			}

			if(flTime >= flTimeDrillLast)
			{
				flTimeDrillLast = flTime + DRILLTANK_WATERMINE_DAMAGE_DELAY
				local bPlayDrillSound = false

				foreach(hPlayer, iPlayerTeamNum in hTouching)
					if(hPlayer.IsValid())
					{
						bPlayDrillSound = true
						hPlayer.TakeDamageEx(self, self, null, Vector(), Vector(), DRILLTANK_WATERMINE_DAMAGE, DMG_CRUSH)
						hPlayer.BleedPlayer(DRILLTANK_WATERMINE_DAMAGE_DEBUFF_DURATION)
						hPlayer.StunPlayer(DRILLTANK_WATERMINE_DAMAGE_DEBUFF_DURATION, 1 - DRILLTANK_WATERMINE_DAMAGE_SPEED_PENALTY, 1, null)
					}
					else delete hTouching[hPlayer]
			}

			if(bDeploying)
			{
				local flTimeDiff = flTime - flTimeDeployStart
				local flPercent = flTimeDiff / 8.0
				if(flPercent < 1 && flTimeDiff >= 4.5)
				{
					EmitSoundEx({
						sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN1
						pitch       = flPercent < 1 ? 170 * flPercent : 100
						entity      = self
						filter_type = RECIPIENT_FILTER_GLOBAL
						flags       = SND_CHANGE_PITCH
					})
					EmitSoundEx({
						sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN2
						pitch       = flPercent < 1 ? 170 * flPercent : 100
						entity      = self
						filter_type = RECIPIENT_FILTER_GLOBAL
						flags       = SND_CHANGE_PITCH
					})
				}
				if(flPercent < 1 && flTimeDiff >= 5)
				{
					EmitSoundEx({
						sound_name  = "ambient/sawblade.wav"
						pitch       = 150 - flPercent * 70
						entity      = self
						filter_type = RECIPIENT_FILTER_GLOBAL
						flags       = flPercent < 1 ? SND_CHANGE_PITCH : SND_STOP
					})

					if(flTime - flTimeSparkLast >= 0.01)
					{
						flTimeSparkLast = flTime
						local vecTowards    = Vector(0.7, 0, 0.7)
						local vecOffset     = Vector(flPercent * 61)
						local flAngleOffset = RandomFloat(0, 360)
						for(local i = 1; i <= 8; i++)
						{
							local Rotate = @(Input) RotatePosition(Vector(), QAngle(0, flAngleOffset + 45 * i), Input)
							DispatchParticleEffect(RandomInt(0, 4) ? DRILLTANK_WATERMINE_HATCH_PARTICLE1 : DRILLTANK_WATERMINE_HATCH_PARTICLE2, vecDeploy + Rotate(vecOffset), Rotate(vecTowards))
						}
					}
				}
			}
		}
		function OnStartDeploy()
		{
			flTimeDeployStart = Time()
			bDeploying        = true
			vecDeploy         = vecOrigin + self.GetForwardVector() * 194

			self.StopSound("MVM.TankDeploy")
			TankExt.DelayFunction(self, this, 1, function() {
				self.EmitSound("MVM.TankDeploy")
			})
			TankExt.DelayFunction(self, this, 2 function() {
				hDrillHurt.SetLocalOrigin(Vector(176, 0, 40))
				hDrillHurt.SetSize(Vector(-64, -64, -40), Vector(64, 64, 40))
			})
			TankExt.DelayFunction(self, this, 4.3, function() {
				self.StopSound("MVM.TankDeploy")
			})
			TankExt.DelayFunction(self, this, 5, function() {
				EmitSoundEx({
					sound_name  = "physics/metal/canister_scrape_smooth_loop1.wav"
					pitch       = 100
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
				})
			})
			TankExt.DelayFunction(self, this, 8, function() {
				EmitSoundEx({
					sound_name  = "physics/metal/canister_scrape_smooth_loop1.wav"
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_STOP
				})
				EmitSoundEx({
					sound_name  = "ambient/sawblade.wav"
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_STOP
				})
				EmitSoundEx({
					sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN1
					pitch       = 100
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_CHANGE_PITCH
				})
				EmitSoundEx({
					sound_name  = DRILLTANK_WATERMINE_SOUND_SPIN2
					pitch       = 100
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_CHANGE_PITCH
				})
			})
		}
	}
	function OnDeath()
	{
		self.StopSound("MVM.TankDeploy")
		EmitSoundEx({
			sound_name  = "misc/null.wav"
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
			flags       = SND_STOP | SND_IGNORE_NAME
		})
	}
})