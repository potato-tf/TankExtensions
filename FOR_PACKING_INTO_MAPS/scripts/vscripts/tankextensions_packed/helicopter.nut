local HELICOPTER_VALUES_TABLE = {
	HELICOPTER_MODEL        = "models/props_frontline/helicopter_windows.mdl"
	HELICOPTER_TURRET_MODEL = "models/props_frontline/tank_turret.mdl"
	HELICOPTER_SOUND_ENGINE = "^npc/attack_helicopter/aheli_rotor_loop1.wav"
	HELICOPTER_MAX_RANGE    = 2000

	HELICOPTER_ROCKET_SND_FIRE        = "Weapon_Airstrike.AltFire"
	HELICOPTER_ROCKET_SND_FIRE_CRIT   = "Weapon_Airstrike.CritFire"
	HELICOPTER_ROCKET_SPLASH          = 146
	HELICOPTER_ROCKET_SPEED           = 600
	HELICOPTER_ROCKET_DAMAGE          = 100
	HELICOPTER_ROCKET_MODEL           = "models/weapons/w_models/w_rocket_airstrike/w_rocket_airstrike.mdl"
	HELICOPTER_ROCKET_HOMING_POWER    = 0.05
	HELICOPTER_ROCKET_HOMING_DURATION = 0.75
	HELICOPTER_ROCKET_COOLDOWN        = 1
	HELICOPTER_ROCKET_PARTICLE_TRAIL  = "rockettrail_airstrike"

	HELICOPTER_STICKY_SND_FIRE       = ")weapons/stickybomblauncher_shoot.wav"
	HELICOPTER_STICKY_SND_FIRE_CRIT  = ")weapons/stickybomblauncher_shoot_crit.wav"
	HELICOPTER_STICKY_MODEL          = "models/weapons/w_models/w_stickybomb.mdl"
	HELICOPTER_STICKY_SPREAD         = 30
	HELICOPTER_STICKY_SPLASH_RADIUS  = 189
	HELICOPTER_STICKY_SPEED_MIN      = 100
	HELICOPTER_STICKY_SPEED_MAX      = 1000
	HELICOPTER_STICKY_DAMAGE         = 100
	HELICOPTER_STICKY_COOLDOWN       = 15
	HELICOPTER_STICKY_SHOT_AMOUNT    = 16
	HELICOPTER_STICKY_DETONATE_DELAY = 5
}
foreach(k,v in HELICOPTER_VALUES_TABLE)
	if(!(k in TankExtPacked.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(HELICOPTER_MODEL)
PrecacheModel(HELICOPTER_TURRET_MODEL)
PrecacheModel(HELICOPTER_ROCKET_MODEL)
PrecacheModel(HELICOPTER_STICKY_MODEL)
TankExtPacked.PrecacheSound(HELICOPTER_SOUND_ENGINE)
TankExtPacked.PrecacheSound(HELICOPTER_ROCKET_SND_FIRE)
TankExtPacked.PrecacheSound(HELICOPTER_ROCKET_SND_FIRE_CRIT)
TankExtPacked.PrecacheSound(HELICOPTER_STICKY_SND_FIRE)
TankExtPacked.PrecacheSound(HELICOPTER_STICKY_SND_FIRE_CRIT)

TankExtPacked.NewTankType("helicopter*", {
	DisableChildModels = 1
	DisableSmokestack  = 1
	EngineLoopSound    = "misc/null.wav"
	PingSound          = "misc/null.wav"
	NoDestructionModel = 1
	NoGravity          = 1
	Scale              = 0.75
	Model              = {
		Visual = "models/empty.mdl"
	}
	function OnSpawn()
	{
		EmitSoundEx({
			sound_name  = HELICOPTER_SOUND_ENGINE
			channel     = CHAN_STATIC
			sound_level = 150
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
		})

		local bCrit     = sTankName.find("_crit") ? true : false
		local bBlueTeam = self.GetTeam() == TF_TEAM_BLUE
		local hModel    = TankExtPacked.SpawnEntityFromTableFast("prop_dynamic", { model = HELICOPTER_MODEL, defaultanim = "Hover_idle", skin = (bBlueTeam ? 1 : 0) })
		hModel.AcceptInput("SetAnimation", "Lift_to_hover", null, null)
		TankExtPacked.SetParentArray([hModel], self)

		local hTurret = CreateByClassname("obj_teleporter")
		hTurret.SetAbsOrigin(Vector(6, 0, 102))
		hTurret.SetAbsAngles(QAngle(0, 0, -180))
		hTurret.DispatchSpawn()
		hTurret.SetModelScale(0.5, 0)
		hTurret.SetModel(HELICOPTER_TURRET_MODEL)
		hTurret.AddEFlags(EFL_NO_THINK_FUNCTION)
		hTurret.SetSolid(SOLID_NONE)
		hTurret.SetTeam(bBlueTeam ? TF_TEAM_BLUE : TF_TEAM_RED)
		hTurret.SetSkin(bBlueTeam ? 2 : 0)
		hTurret.AcceptInput("Color", bBlueTeam ? "220 240 250" : "150 150 150", null, null)
		SetPropBool(hTurret, "m_bGlowEnabled", true)

		local hMimicRocket = SpawnEntityFromTable("tf_point_weapon_mimic", {
			origin        = "70 0 40"
			damage        = HELICOPTER_ROCKET_DAMAGE
			modeloverride = HELICOPTER_ROCKET_MODEL
			modelscale    = 1
			speedmin      = HELICOPTER_ROCKET_SPEED
			speedmax      = HELICOPTER_ROCKET_SPEED
			splashradius  = HELICOPTER_ROCKET_SPLASH
			weapontype    = 0
		})
		local hMimicSticky = SpawnEntityFromTable("tf_point_weapon_mimic", {
			origin        = "70 0 40"
			damage        = HELICOPTER_STICKY_DAMAGE
			modeloverride = HELICOPTER_STICKY_MODEL
			modelscale    = 1
			speedmin      = HELICOPTER_STICKY_SPEED_MIN
			speedmax      = HELICOPTER_STICKY_SPEED_MAX
			splashradius  = HELICOPTER_STICKY_SPLASH_RADIUS
			spreadangle   = HELICOPTER_STICKY_SPREAD
			weapontype    = 3
		})

		PrecacheScriptSound("SawMill.BladeImpact")
		local hHurt = SpawnEntityFromTable("trigger_multiple", {
			origin        = "-40 0 144"
			startdisabled = 1
			spawnflags    = 1
			OnStartTouch  = "bignetRunScriptCodeactivator.TakeDamageEx(caller, caller.GetMoveParent(), null, Vector(), Vector(), 1000, DMG_CRUSH); caller.EmitSound(`SawMill.BladeImpact`)0-1"
		})
		hHurt.SetSize(Vector(-160, -160, -8), Vector(160, 160, 8))
		hHurt.SetSolid(SOLID_BBOX)
		hHurt.KeyValueFromString("classname", "helicopter")
		TankExtPacked.SetParentArray([hTurret, hMimicRocket, hMimicSticky, hHurt], hModel)

		local flSpeed = GetPropFloat(self, "m_speed")
		SetPropFloat(self, "m_speed", 0.0)

		local hTank_scope = self.GetScriptScope()
		hTank_scope.bNoGravity = false

		local vecOrigin = self.GetOrigin()
		local Trace = {
			start  = vecOrigin
			end    = vecOrigin + Vector(0, 0, -8192)
			mask   = CONTENTS_SOLID
			ignore = self
		}
		TraceLineEx(Trace)
		if(Trace.hit) self.SetAbsOrigin(Trace.endpos)

		local flTimeToLaunch = Time() + 5.4
		local bLaunched      = false

		local vecOriginLast = self.GetOrigin()
		local angCurrent    = QAngle()
		local angGoal       = QAngle()
		local flYawCurrent  = 0.0

		local flTimeRocket = 0
		local flTimeSticky = 0
		hStickies <- []

		local bDeploying = false

		function Think()
		{
			if(!bLaunched)
			{
				local flLaunchPercent = (5.4 - flTimeToLaunch + flTime) / 5.4
				hTurret.SetLocalOrigin(Vector(pow(flLaunchPercent, 8) * 32 - 26, 0, 102)) // omega lazy
				EmitSoundEx({
					sound_name  = HELICOPTER_SOUND_ENGINE
					pitch       = 100 * flLaunchPercent
					channel     = CHAN_STATIC
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
					flags       = SND_CHANGE_PITCH
				})
				if(flTime >= flTimeToLaunch)
				{
					bLaunched = true
					hModel.AcceptInput("SetAnimation", "Hover_idle", null, null)
					hHurt.AcceptInput("Enable", null, null, null)
					SetPropFloat(self, "m_speed", flSpeed)
					hTank_scope.bNoGravity = true

					local angRotation = self.GetAbsAngles()
					angCurrent = angRotation
					flYawCurrent = angRotation.y

					flTimeRocket = flTime + HELICOPTER_ROCKET_COOLDOWN
					flTimeSticky = flTime + HELICOPTER_STICKY_COOLDOWN
				}
			}
			else
			{
				local vecOrigin     = self.GetOrigin()
				local vecVelocity   = (vecOrigin - vecOriginLast) * (1 / FrameTime())
				local flVelocitySqr = vecVelocity.Length2DSqr()
				if(flVelocitySqr != 0)
				{
					angGoal   = TankExtPacked.VectorAngles(vecVelocity)
					angGoal.x = sqrt(flVelocitySqr) * 0.1
				}
				else angGoal.x = 0
				vecOriginLast = vecOrigin

				local flRotateSpeed = 0.6
				if(angCurrent.x != angGoal.x)
				{
					local iDir = angCurrent.x < angGoal.x ? 0.5 : -0.5
					angCurrent.x += flRotateSpeed * iDir

					if(iDir == 0.5 ? angCurrent.x > angGoal.x : angCurrent.x < angGoal.x)
						angCurrent.x = angGoal.x
				}
				local RotateYaw = function(YawCurrent, YawGoal)
				{
					local iDir = YawCurrent < YawGoal ? 1 : -1
					local bReversed = false
					if(fabs(YawGoal - YawCurrent) > 180)
					{
						iDir = -iDir
						bReversed = true
					}

					YawCurrent += flRotateSpeed * iDir

					if(iDir == 1 ? bReversed ? YawCurrent < YawGoal : YawCurrent > YawGoal : bReversed ? YawCurrent > YawGoal : YawCurrent < YawGoal)
						YawCurrent = YawGoal

					if(YawCurrent < 0)
						YawCurrent += 360
					else if(YawCurrent >= 360)
						YawCurrent -= 360

					return YawCurrent
				}

				if(angCurrent.y != angGoal.y) angCurrent.y = RotateYaw(angCurrent.y, angGoal.y)
				self.SetAbsAngles(angCurrent)

				local hTarget
				local vecTarget
				foreach(sClassname in [ "player", "obj_sentrygun", "obj_dispenser", "obj_teleporter", "tank_boss", "merasmus", "headless_hatman", "eyeball_boss", "tf_zombie" ])
				{
					for(local hEnt, flDist = HELICOPTER_MAX_RANGE; hEnt = FindByClassnameWithin(hEnt, sClassname, vecOrigin, flDist);)
					{
						local vecEntCenter = hEnt.GetCenter()
						local vecEntTrace  = "EyePosition" in hEnt ? hEnt.EyePosition() : vecEntCenter
						local bTrace       = TraceLine(vecEntTrace, vecOrigin, self) == 1
						if
						(
							bTrace &&
							hEnt.IsAlive() &&
							hEnt.GetTeam() != iTeamNum &&
							!(hEnt.GetFlags() & FL_NOTARGET) &&
							!TankExtPacked.IsPlayerStealthedOrDisguised(hEnt)
						)
						{
							hTarget   = hEnt
							vecTarget = vecEntCenter
							flDist    = (vecEntCenter - vecOrigin).Length()
						}
					}
					if(hTarget) break
				}

				local flYawGoal = hTarget && !bDeploying ? TankExtPacked.VectorAngles(vecTarget - vecOrigin).y : angCurrent.y
				if(flYawCurrent != flYawGoal) flYawCurrent = RotateYaw(flYawCurrent, flYawGoal)
				hModel.SetLocalAngles(QAngle(0, flYawCurrent - angCurrent.y, 0))

				if(!bDeploying)
				{
					if(self.GetSequenceName(self.GetSequence()) == "deploy")
					{
						bDeploying = true
						self.StopSound("MVM.TankDeploy")

						PrecacheSound("ambient/alarms/doomsday_lift_alarm.wav")
						PrecacheSound("weapons/stickybomblauncher_charge_up.wav")
						PrecacheSound("mvm/giant_demoman/giant_demoman_grenade_shoot.wav")
						PrecacheSound("misc/grenade_jump_fall_01.wav")

						self.EmitSound("ambient/alarms/doomsday_lift_alarm.wav")
						EmitSoundEx({
							sound_name  = "weapons/stickybomblauncher_charge_up.wav"
							pitch       = 80
							filter_type = RECIPIENT_FILTER_GLOBAL
							entity      = self
						})
						TankExtPacked.DelayFunction(self, this, 5, function()
						{
							self.EmitSound("mvm/giant_demoman/giant_demoman_grenade_shoot.wav")

							local vecFakeOrigin = self.GetOrigin() + angGoal.Forward() * 70 + angGoal.Up() * 38
							local vecVelocity   = angGoal.Forward() * 128

							DispatchParticleEffect("rocketbackblast", vecFakeOrigin, vecVelocity)
							hBomb <- CreateByClassname("obj_teleporter")
							hBomb.SetAbsOrigin(vecFakeOrigin)
							hBomb.SetAbsAngles(QAngle(angGoal.z, angGoal.y + 90, angGoal.x))
							hBomb.KeyValueFromFloat("modelscale", 0.3)
							hBomb.DispatchSpawn()
							hBomb.SetModelScale(1, 0.25)
							hBomb.SetModel("models/props_td/atom_bomb.mdl")
							hBomb.AddEFlags(EFL_NO_THINK_FUNCTION)
							hBomb.SetSolid(SOLID_NONE)
							hBomb.SetTeam(self.GetTeam() == TF_TEAM_BLUE ? TF_TEAM_BLUE : TF_TEAM_RED)
							SetPropBool(hBomb, "m_bGlowEnabled", true)

							local hEdict = SpawnEntityFromTable("info_target", { spawnflags = 0x01 })
							hEdict.AddEFlags(EFL_IN_SKYBOX | EFL_FORCE_CHECK_TRANSMIT)
							hEdict.AcceptInput("SetParent", "!activator", hBomb, null)

							hBomb.ValidateScriptScope()
							hBomb.GetScriptScope().Think <- function()
							{
								if(!self.IsValid()) return
								local flFrameTime = FrameTime()
								self.SetAbsOrigin(vecFakeOrigin += vecVelocity * flFrameTime)
								local angRotation = TankExtPacked.VectorAngles(vecVelocity)
								self.SetAbsAngles(QAngle(angRotation.z, angRotation.y + 90, angRotation.x))
								vecVelocity.x *= 0.98
								vecVelocity.y *= 0.98
								vecVelocity.z -= 190 * flFrameTime
								return -1
							}
							AddThinkToEnt(hBomb, "Think")
						})
						TankExtPacked.DelayFunction(self, this, 5.8, function() { self.EmitSound("misc/grenade_jump_fall_01.wav") })
						TankExtPacked.DelayFunction(self, this, 8.167, function() { hBomb.Kill() })
					}
					if(hTarget)
					{
						if(flTime >= flTimeRocket)
						{
							flTimeRocket = flTime + HELICOPTER_ROCKET_COOLDOWN
							hMimicRocket.AcceptInput("FireOnce", null, null, null)
							EmitSoundEx({
								sound_name  = bCrit ? HELICOPTER_ROCKET_SND_FIRE_CRIT : HELICOPTER_ROCKET_SND_FIRE
								sound_level = 90
								entity      = self
								filter_type = RECIPIENT_FILTER_GLOBAL
							})

							for(local hRocket; hRocket = FindByClassnameWithin(hRocket, "tf_projectile_rocket", hMimicRocket.GetOrigin(), 1);)
								if(hRocket.GetOwner() == hMimicRocket)
								{
									TankExtPacked.MarkForPurge(hRocket)
									hRocket.SetSize(Vector(), Vector())
									hRocket.SetSolid(SOLID_BSP)
									hRocket.SetSequence(1)
									hRocket.SetSkin(iTeamNum == TF_TEAM_BLUE ? 1 : 0)
									hRocket.SetTeam(iTeamNum)
									hRocket.SetOwner(self)
									if(bCrit) SetPropBool(hRocket, "m_bCritical", true)

									hRocket.ValidateScriptScope()
									local hRocket_scope = hRocket.GetScriptScope()
									local bSolid = false
									local hTank = self
									hRocket_scope.RocketThink <- function()
									{
										if(!self.IsValid()) return
										local vecOrigin = self.GetOrigin()
										if(!bSolid && (!hTank.IsValid() || !TankExtPacked.IntersectionBoxBox(vecOrigin, self.GetBoundingMins(), self.GetBoundingMaxs(), hTank.GetOrigin(), hTank.GetBoundingMins(), hTank.GetBoundingMaxs())))
											{ bSolid = true; self.SetSolid(SOLID_BBOX) }
										HomingThink()
										return -1
									}
									hRocket_scope.HomingParams <- {
										Target      = hTarget
										TurnPower   = HELICOPTER_ROCKET_HOMING_POWER
										AimTime     = HELICOPTER_ROCKET_HOMING_DURATION
										MaxAimError = -1
									}
									IncludeScript("tankextensions_packed/misc/homingrocket", hRocket_scope)
									TankExtPacked.AddThinkToEnt(hRocket, "RocketThink")

									if(HELICOPTER_ROCKET_PARTICLE_TRAIL != "rockettrail")
									{
										hRocket.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
										local hTrail = TankExtPacked.CreateByClassnameSafe("trigger_particle")
										hTrail.KeyValueFromString("particle_name", HELICOPTER_ROCKET_PARTICLE_TRAIL)
										hTrail.KeyValueFromString("attachment_name", "trail")
										hTrail.KeyValueFromInt("attachment_type", 4)
										hTrail.KeyValueFromInt("spawnflags", 64)
										hTrail.DispatchSpawn()
										hTrail.AcceptInput("StartTouch", null, hRocket, hRocket)
										if(bCrit)
										{
											hTrail.KeyValueFromString("particle_name", iTeamNum == TF_TEAM_BLUE ? "critical_rocket_blue" : "critical_rocket_red")
											hTrail.AcceptInput("StartTouch", null, hRocket, hRocket)
										}
										hTrail.Kill()
									}
								}
						}
						if(flTime >= flTimeSticky)
						{
							flTimeSticky = flTime + HELICOPTER_STICKY_COOLDOWN
							hMimicSticky.AcceptInput("FireMultiple", format("%i", HELICOPTER_STICKY_SHOT_AMOUNT), null, null)
							TankExtPacked.DelayFunction(self, this, HELICOPTER_STICKY_DETONATE_DELAY, function()
							{
								hMimicSticky.AcceptInput("DetonateStickies", null, null, null)
							})
							EmitSoundEx({
								sound_name  = bCrit ? HELICOPTER_STICKY_SND_FIRE_CRIT : HELICOPTER_STICKY_SND_FIRE
								sound_level = 90
								pitch       = 95
								entity      = self
								filter_type = RECIPIENT_FILTER_GLOBAL
							})
							for(local hSticky; hSticky = FindByClassnameWithin(hSticky, "tf_projectile_pipe", hMimicSticky.GetOrigin(), 1);)
								if(!GetPropEntity(hSticky, "m_hThrower"))
								{
									SetPropEntity(hSticky, "m_hThrower", self)
									hSticky.SetOwner(self)
									hSticky.SetTeam(iTeamNum)
									hSticky.SetSkin(iTeamNum == TF_TEAM_BLUE ? 1 : 0)
									if(bCrit) SetPropBool(hSticky, "m_bCritical", true)
									hStickies.append(hSticky)
								}
						}
					}
				}
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
		if("hBomb" in this && hBomb.IsValid()) hBomb.Kill()
		foreach(hSticky in hStickies)
			if(hSticky.IsValid())
				hSticky.Kill()
	}
})