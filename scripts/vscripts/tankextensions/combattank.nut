local COMBATTANK_VALUES_TABLE = {
	COMBATTANK_SND_ROTATE           = ")plats/tram_move.wav"
	COMBATTANK_SND_UBER             = "player/invulnerable_on.wav"
	COMBATTANK_SND_UBER_OFF         = "player/invulnerable_off.wav"
	COMBATTANK_ROTATE_SPEED_DEFAULT = 0.8
	COMBATTANK_POSE_YAW             = 2
	COMBATTANK_POSE_PITCH           = 1
	COMBATTANK_MODEL                = "models/bots/boss_bot/combat_tank_mk2/mk2_combat_tank_chassis.mdl"
	COMBATTANK_MODEL_UBERED_TRACK_L = "models/bots/boss_bot/ubertank/tank_uber_track_l.mdl"
	COMBATTANK_MODEL_UBERED_TRACK_R = "models/bots/boss_bot/ubertank/tank_uber_track_r.mdl"
	COMBATTANK_TRACK_L_RED          = "models/bots/boss_bot/tankred_track_l.mdl"
	COMBATTANK_TRACK_R_RED          = "models/bots/boss_bot/tankred_track_r.mdl"
	COMBATTANK_MAX_RANGE            = 1800
}
foreach(k,v in COMBATTANK_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(COMBATTANK_MODEL)
PrecacheModel(COMBATTANK_TRACK_L_RED)
PrecacheModel(COMBATTANK_TRACK_R_RED)
PrecacheModel(COMBATTANK_MODEL_UBERED_TRACK_L)
PrecacheModel(COMBATTANK_MODEL_UBERED_TRACK_R)
TankExt.PrecacheSound(COMBATTANK_SND_ROTATE)
TankExt.PrecacheSound(COMBATTANK_SND_UBER)
TankExt.PrecacheSound(COMBATTANK_SND_UBER_OFF)

::CombatTankEvents <- {
	function OnGameEvent_recalculate_holidays(_) { if(GetRoundState() == 3) delete ::CombatTankEvents }
	function OnScriptHook_OnTakeDamage(params)
	{
		local hAttacker = params.attacker
		local hVictim   = params.const_entity
		if(hAttacker && hVictim && hVictim.GetClassname() == "tank_boss" && hAttacker.GetTeam() != hVictim.GetTeam())
		{
			local CombatScope = TankExt.GetMultiScopeTable(hVictim.GetScriptScope(), "combattank")
			if(CombatScope && CombatScope.bUbered)
			{
				params.damage = 0
				EmitSoundOn("FX_RicochetSound.Ricochet", hVictim)
			}
		}
	}
}
__CollectGameEventCallbacks(CombatTankEvents)

TankExt.CombatTankWeapons <- {}

TankExt.NewTankType("combattank*", {
	Model       = COMBATTANK_MODEL
	DisableBomb = 1
	function OnSpawn()
	{
		local SoundQueue = {}
		function AddToSoundQueue(Table)
		{
			local TableStop = clone Table
			TableStop.flags <- SND_STOP
			EmitSoundEx(TableStop)
			SoundQueue[Table.sound_name] <- Table
		}

		local angGoalIdle = QAngle()
		angCurrent <- QAngle()
		angGoal    <- QAngle()

		local hTargetLast   = null
		local flRotateSpeed = COMBATTANK_ROTATE_SPEED_DEFAULT
		local iLaser        = self.LookupAttachment("laser_origin")
		vecMountOffset <- Vector(0, 0, 55)
		vecMount       <- null
		vecTarget      <- null
		hTarget        <- null
		flDist         <- COMBATTANK_MAX_RANGE
		flAngleDot     <- -1

		bAimAtFeet <- false
		LaserTrace <- {}

		EmitSoundEx({
			sound_name  = COMBATTANK_SND_ROTATE
			sound_level = 85
			entity      = self
			filter_type = RECIPIENT_FILTER_GLOBAL
			pitch       = 90
		})

		local sParams = split(sTankName, "|")
		local iParamsLength = sParams.len()
		if(iParamsLength < 2) sParams.append("minigun")
		if(iParamsLength < 3) sParams.append(sParams[1])

		if(sParams[0].find("_red")) self.SetTeam(TF_TEAM_RED) // legacy, can append $teamnum|2 to the tank name instead
		self.SetBodygroup(self.FindBodygroupByName("bomb"), sParams[0].find("_bomb") ? 0 : 1)

		local bBlueTeam  = self.GetTeam() == TF_TEAM_BLUE
		local bFinalSkin = self.GetSkin() == 1

		hBeam    <- null
		hBeamEnd <- null
		if(sParams[0].find("_nolaser") == null)
		{
			hBeam    = SpawnEntityFromTableSafe("env_beam", { lightningstart = "bignet", lightningend = "bignet", boltwidth = 0.75, texture = "sprites/laserbeam.vmt", rendercolor = bBlueTeam ? "20 70 120" : "135 10 10" })
			hBeamEnd = SpawnEntityFromTableSafe("env_glow", { model = "sprites/glow1.vmt", rendermode = 5, rendercolor = bBlueTeam ? "20 70 120" : "135 10 10" })
			SetPropEntityArray(hBeam, "m_hAttachEntity", hBeam, 0)
			SetPropEntityArray(hBeam, "m_hAttachEntity", hBeamEnd, 1)
		}

		if(!bBlueTeam) TankExt.SetTankModel(self, {
			LeftTrack  = COMBATTANK_TRACK_L_RED
			RightTrack = COMBATTANK_TRACK_R_RED
		})
		self.SetSkin(bBlueTeam ? bFinalSkin ? 3 : 2 : bFinalSkin ? 1 : 0)
		local bHasTurretReplacement = false
		for(local i = 1; i <= 2; i++)
			if(sParams[i] in TankExt.CombatTankWeapons)
			{
				local WeaponTable = TankExt.CombatTankWeapons[sParams[i]]
				local hWeapon

				local bTurretReplacement = "TurretReplacement" in WeaponTable && WeaponTable.TurretReplacement

				if("Model" in WeaponTable)
				{
					hWeapon = SpawnEntityFromTableSafe("prop_dynamic", { model = WeaponTable.Model, angles = "0 90 0", defaultanim = ("DefaultAnim" in WeaponTable) ? WeaponTable.DefaultAnim : "" })
					hWeapon.SetSkin(bBlueTeam ? 1 : 0)
					TankExt.SetParentArray([hWeapon], self, bTurretReplacement ? "turret" : i == 1 ? "weapon_r" : "weapon_l")
				}
				else if("SpawnModel" in WeaponTable)
				{
					hWeapon = WeaponTable.SpawnModel()
					hWeapon.SetSkin(bBlueTeam ? 1 : 0)
					TankExt.SetParentArray([hWeapon], self, bTurretReplacement ? "turret" : i == 1 ? "weapon_r" : "weapon_l")
				}
				hWeapon.SetModelScale(self.GetModelScale(), 0)

				if("OnSpawn" in WeaponTable)
				{
					hWeapon.ValidateScriptScope()
					local hWeapon_scope = hWeapon.GetScriptScope()
					hWeapon_scope.hTank <- self
					hWeapon_scope.hTank_scope <- this
					WeaponTable.OnSpawn.call(hWeapon_scope)
				}

				if("OnDeath" in WeaponTable)
					TankExt.SetDestroyCallback(hWeapon, WeaponTable.OnDeath)

				if(bTurretReplacement)
				{
					if(i > 1)
						ClientPrint(null, HUD_PRINTTALK, format("\x07FFFF00CombatTank weapon \"%s\" does not support additional weapons", sParams[i]))

					self.SetBodygroup(self.FindBodygroupByName("turret"), 1)
					self.SetBodygroup(self.FindBodygroupByName("turret_radio"), 1)
					bHasTurretReplacement = true
					break
				}
			}
			else ClientPrint(null, HUD_PRINTTALK, format("\x07FFFF00CombatTank weapon \"%s\" is invalid, weapon is not loaded or does not exist", sParams[i]))

		if(bHasTurretReplacement && hBeam)
		{
			hBeam    = hBeam.Kill()
			hBeamEnd = hBeamEnd.Kill()
		}

		local hTrackL, hTrackR
		for(local hChild = self.FirstMoveChild(); hChild; hChild = hChild.NextMovePeer())
		{
			local sChildModel = hChild.GetModelName().tolower()
			if(sChildModel.find("track_l"))
				hTrackL = hChild
			else if(sChildModel.find("track_r"))
				hTrackR = hChild
		}

		local LastSkins   = {}
		local bUberFizzle = false
		bUbered <- false
		function ToggleUber()
		{
			if(!bUberFizzle)
				if(!bUbered)
				{
					bUbered = true
					EmitSoundEx({
						sound_name  = COMBATTANK_SND_UBER
						filter_type = RECIPIENT_FILTER_GLOBAL
					})
					LastSkins.clear()
					LastSkins[self] <- self.GetSkin()
					self.SetSkin(bBlueTeam ? 5 : 4)
					for(local hChild = self.FirstMoveChild(); hChild; hChild = hChild.NextMovePeer())
						if(hChild.GetModelName().tolower().find("/combat_tank_mk2/"))
						{
							LastSkins[hChild] <- hChild.GetSkin()
							hChild.SetSkin(bBlueTeam ? 3 : 2)
						}

					SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetModelIndex(COMBATTANK_MODEL_UBERED_TRACK_L), 0)
					SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetModelIndex(COMBATTANK_MODEL_UBERED_TRACK_L), 3)
					SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetModelIndex(COMBATTANK_MODEL_UBERED_TRACK_R), 0)
					SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetModelIndex(COMBATTANK_MODEL_UBERED_TRACK_R), 3)
					hTrackL.SetSkin(bBlueTeam ? 1 : 0)
					hTrackR.SetSkin(bBlueTeam ? 1 : 0)
				}
				else
				{
					bUberFizzle = true
					EmitSoundEx({
						sound_name  = COMBATTANK_SND_UBER_OFF
						filter_type = RECIPIENT_FILTER_GLOBAL
					})
					TankExt.DelayFunction(self, this, 1, function()
					{
						bUbered     = false
						bUberFizzle = false
						foreach(hEnt, iSkin in LastSkins)
							if(hEnt.IsValid())
							{
								hEnt.SetSkin(iSkin)
								hEnt.AcceptInput("Color", "255 255 255", null, null)
							}

						SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetPropInt(hTrackL, "m_nModelIndex"), 0)
						SetPropIntArray(hTrackL, "m_nModelIndexOverrides", GetPropInt(hTrackL, "m_nModelIndex"), 3)
						SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetPropInt(hTrackR, "m_nModelIndex"), 0)
						SetPropIntArray(hTrackR, "m_nModelIndexOverrides", GetPropInt(hTrackR, "m_nModelIndex"), 3)
						hTrackL.SetSkin(0)
						hTrackR.SetSkin(0)
					})
				}
		}
		local CombatScope = this
		self.GetScriptScope().ToggleUber <- @() CombatScope.ToggleUber()

		local iAttachTurret = self.LookupAttachment("turret")
		local function SetNewTarget(hNewTarget, vecNewTarget)
		{
			hTarget   = hNewTarget
			vecTarget = vecNewTarget
			flDist    = (vecNewTarget - vecMount).Length()
		}
		function Think()
		{
			foreach(sSound, Table in SoundQueue)
				EmitSoundEx(Table)
			SoundQueue.clear()

			if(bUberFizzle)
			{
				local flColor = 127.5 - sin(flTime * 20.95) * 127.5 // 20.95 == PI / 0.3 * 0.5
				local sColor  = format("%i %i %i", flColor, flColor, flColor)
				foreach(hEnt, iSkin in LastSkins) if(hEnt.IsValid()) hEnt.AcceptInput("Color", sColor, null, null)
			}

			local vecMountOffsetScaled = vecMountOffset * self.GetModelScale()
			local angTurretAngles      = self.GetAttachmentAngles(iAttachTurret)
			vecMount  = self.GetAttachmentOrigin(iAttachTurret) + angTurretAngles.Forward() * vecMountOffsetScaled.x + angTurretAngles.Up() * vecMountOffsetScaled.z
			hTarget   = null
			vecTarget = null
			flDist    = COMBATTANK_MAX_RANGE

			local hForceTarget = FindByNameNearest("combattank_target", vecMount, flDist)
			if(hForceTarget)
				SetNewTarget(hForceTarget, hForceTarget.GetCenter())
			else foreach(i, sClassname in [ "player", "obj_sentrygun", "obj_dispenser", "obj_teleporter", "tank_boss", "merasmus", "headless_hatman", "eyeball_boss", "tf_zombie" ])
			{
				local bPlayer = i == 0 // lol
				for(local hEnt; hEnt = FindByClassnameWithin(hEnt, sClassname, vecMount, flDist);)
				{
					local iEntityFlags = 0
					if(!hEnt.IsAlive() || hEnt.GetTeam() == iTeamNum || (iEntityFlags = hEnt.GetFlags()) & FL_NOTARGET || (TankExt.IsPlayerStealthedOrDisguised(hEnt) && hEnt.GetDisguiseTeam() == iTeamNum))
						continue

					local bDoFeetTrace = bAimAtFeet && iEntityFlags & FL_ONGROUND
					local Trace = {
						start  = vecMount
						end    = bDoFeetTrace ? hEnt.GetOrigin() : hEnt.GetCenter()
						mask   = MASK_SHOT_HULL | CONTENTS_GRATE
						ignore = self
						enthit = null
					}
					TraceLineEx(Trace)

					if(bDoFeetTrace)
					{
						if(Trace.enthit == hEnt)
						{
							SetNewTarget(hEnt, Trace.end)
							continue
						}
						else // didnt hit the feet, check if it hits the center
						{
							Trace.end = hEnt.GetCenter()
							TraceLineEx(Trace)
						}
					}

					if(Trace.enthit == hEnt)
					{
						SetNewTarget(hEnt, Trace.end)
						continue
					}
					else if(bPlayer) // didnt hit the center, check if it hits the eye (if any)
					{
						Trace.end = hEnt.EyePosition()
						TraceLineEx(Trace)
						if(Trace.enthit == hEnt)
						{
							SetNewTarget(hEnt, Trace.end)
							continue
						}
					}
				}
				if(hTarget) break
			}

			if(hTarget != hTargetLast)
			{
				hTargetLast = hTarget
				if(hTarget)
				{
					local Sound = @(hEnt, sSound, iFlags) EmitSoundEx({
						sound_name  = sSound
						volume      = hEnt == self ? 1.0 : 0.5
						sound_level = 88
						flags       = iFlags
						pitch       = 95
						entity      = hEnt
						filter_type = hEnt == self ? RECIPIENT_FILTER_GLOBAL : RECIPIENT_FILTER_SINGLE_PLAYER
					})
					Sound(self, "weapons/sentry_spot.wav", SND_STOP)
					Sound(self, "weapons/sentry_spot.wav", SND_NOFLAGS)
					Sound(hTarget, "weapons/sentry_spot_client.wav", SND_STOP)
					Sound(hTarget, "weapons/sentry_spot_client.wav", SND_NOFLAGS)
				}
			}

			LaserTrace = {
				start  = vecMount
				end    = vecMount + RotatePosition(Vector(), angRotation, (angCurrent * -1).Forward()) * 8192
				ignore = self
				mask   = MASK_SHOT_HULL
			}
			TraceLineEx(LaserTrace)

			if(hTarget)
			{
				// oddly cannot use one RotatePosition as the vector breaks when the tank is angled in two axis of rotation, have to use two RotatePosition
				local vecTowardsTarget = vecTarget - vecMount
				vecTowardsTarget = RotatePosition(Vector(), QAngle(0, angRotation.y * -1, 0), vecTowardsTarget)
				vecTowardsTarget = RotatePosition(Vector(), QAngle(angRotation.x * -1, 0, 0), vecTowardsTarget)
				local angToTarget = TankExt.VectorAngles(vecTowardsTarget)

				flRotateSpeed = COMBATTANK_ROTATE_SPEED_DEFAULT
				angToTarget.y = 360.0 - angToTarget.y
				angToTarget.x = -TankExt.Clamp(angToTarget.x - (angToTarget.x > 180 ? 360 : 0), -55, 35)
				angGoal = angToTarget
				if("enthit" in LaserTrace && LaserTrace.enthit == hTarget)
				{
					LaserTrace.end = vecTarget
					TraceLineEx(LaserTrace)
				}
				if(hBeam)
				{
					hBeam.SetAbsOrigin(self.GetAttachmentOrigin(iLaser))
					hBeam.AcceptInput("TurnOn", null, null, null)
				}
				if(hBeamEnd)
				{
					hBeamEnd.SetAbsOrigin(LaserTrace.endpos)
					hBeamEnd.AcceptInput("ShowSprite", null, null, null)
				}
			}
			else
			{
				if(hBeam) hBeam.AcceptInput("TurnOff", null, null, null)
				if(hBeamEnd) hBeamEnd.AcceptInput("HideSprite", null, null, null)
				if(angCurrent.x == angGoal.x && angCurrent.y == angGoal.y)
				{
					flRotateSpeed = COMBATTANK_ROTATE_SPEED_DEFAULT * 0.5
					angGoal.x = RandomFloat(-10, 10)
					angGoal.y = angGoal.y < 180 ? 315 : 45
				}
			}

			////////// RotateMount //////////

			if(angCurrent.x != angGoal.x)
			{
				local iDir = angCurrent.x < angGoal.x ? 1 : -1
				angCurrent.x += flRotateSpeed * iDir * 0.5

				if(iDir == 1 ? angCurrent.x > angGoal.x : angCurrent.x < angGoal.x)
					angCurrent.x = angGoal.x
			}
			self.SetPoseParameter(COMBATTANK_POSE_PITCH, TankExt.Clamp(angCurrent.x, -14, 14))

			if(angCurrent.y != angGoal.y)
			{
				local iDir = angCurrent.y < angGoal.y ? 1 : -1
				local bReversed = false
				if(fabs(angGoal.y - angCurrent.y) > 180)
				{
					iDir = -iDir
					bReversed = true
				}

				angCurrent.y += flRotateSpeed * iDir

				if(iDir == 1 ? bReversed ? angCurrent.y < angGoal.y : angCurrent.y > angGoal.y : bReversed ? angCurrent.y > angGoal.y : angCurrent.y < angGoal.y)
					angCurrent.y = angGoal.y

				if(angCurrent.y < 0)
					angCurrent.y += 360
				else if(angCurrent.y >= 360)
					angCurrent.y -= 360
			}
			self.SetPoseParameter(COMBATTANK_POSE_YAW, angCurrent.y)

			flAngleDot = (hTarget ? angCurrent.Forward().Dot(angGoal.Forward()) : -1)
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
		if(hBeam && hBeam.IsValid()) hBeam.Kill()
		if(hBeamEnd && hBeamEnd.IsValid()) hBeamEnd.Kill()
	}
})