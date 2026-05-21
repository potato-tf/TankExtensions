local JUMPTANK_VALUES_TABLE = {
	JUMPTANK_JUMP_COOLDOWN        = 8
	JUMPTANK_USE_SPECIAL_DEPLOY   = false
	JUMPTANK_SPECIAL_DEPLOY_RELAY = "boss_deploy_relay"
}
foreach(k,v in JUMPTANK_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

TankExt.PrecacheSound(")misc/halloween/strongman_fast_impact_01.wav")
TankExt.PrecacheSound(")ambient/explosions/explode_1.wav")
TankExt.PrecacheSound(")player/fall_damage_indicator.wav")
TankExt.PrecacheSound(")weapons/rocket_pack_boosters_fire.wav")
TankExt.PrecacheSound(")weapons/rocket_pack_boosters_charge.wav")

::JumpTankEvents <- {
	function OnGameEvent_recalculate_holidays(_) { if(GetRoundState() == 3) delete ::JumpTankEvents }
	function OnScriptHook_OnTakeDamage(params)
	{
		local hVictim   = params.const_entity
		local hAttacker = params.attacker
		if(hVictim && GetPropInt(hVictim, "m_takedamage") == DAMAGE_YES && hAttacker && hAttacker.GetClassname() == "tank_boss")
		{
			local JumpScope = TankExt.GetMultiScopeTable(hAttacker.GetScriptScope(), "jumptank")
			if(JumpScope && JumpScope.bFalling)
			{
				params.damage_stats = TF_DMG_CUSTOM_BOOTS_STOMP

				hAttacker.EmitSound("Weapon_Mantreads.Impact")
				hAttacker.EmitSound("Player.FallDamageDealt")
			}
		}
	}
}
__CollectGameEventCallbacks(JumpTankEvents)

TankExt.NewTankType("jumptank", {
	UseCustomLocomotion = 1
	UseBetterTracks     = 1
	function OnSpawn()
	{
		local hParticle = SpawnEntityFromTableSafe("info_particle_system", {
			origin      = Vector(0, 0, 64)
			angles      = QAngle(-90, 0, 0)
			effect_name = "rockettrail_burst_doomsday"
		})
		TankExt.SetParentArray([hParticle], self)

		local angFakeRotation  = QAngle()
		local flStepHeightLast = 0
		local flTimeNext       = Time() + JUMPTANK_JUMP_COOLDOWN
		local bPreparing       = false
		local bJumping         = false

		bFalling <- false

		local JumpScope   = this
		local hTank_scope = self.GetScriptScope()
		local function Jump()
		{
			if(bPreparing) return
			local vecOrigin = self.GetOrigin()
			local Trace = {
				start  = vecOrigin
				end    = vecOrigin + Vector(0, 0, 850)
				mask   = CONTENTS_SOLID
				ignore = self
			}
			TraceLineEx(Trace)
			if(Trace.fraction >= 0.4)
			{
				bPreparing = true
				EmitSoundEx({
					sound_name  = ")weapons/rocket_pack_boosters_charge.wav"
					pitch       = 85
					sound_level = 100
					entity      = self
					filter_type = RECIPIENT_FILTER_GLOBAL
				})
				TankExt.DelayFunction(self, JumpScope, 0.75, function()
				{
					bJumping                  = true
					hTank_scope.vecVelocity.z = 1024 * pow(Trace.fraction, 0.65)
					flStepHeightLast          = self.GetLocomotionInterface().GetStepHeight()
					angFakeRotation           = self.GetAbsAngles()
					self.AcceptInput("SetStepHeight", "0", null, null)

					EmitSoundEx({
						sound_name  = ")weapons/rocket_pack_boosters_fire.wav"
						pitch       = 85
						sound_level = 100
						entity      = self
						filter_type = RECIPIENT_FILTER_GLOBAL
					})
					hParticle.AcceptInput("Start", null, null, null)
					EntFireByHandle(hParticle, "Stop", null, 0.4, null, null)
				})
			}
		}
		hTank_scope.Jump <- Jump

		function Think()
		{
			if(!bPreparing && !bDeploying && JUMPTANK_JUMP_COOLDOWN >= 0 && flTime >= flTimeNext) Jump()
			if(bJumping)
			{
				if(bDeploying && JUMPTANK_USE_SPECIAL_DEPLOY)
				{
					if(!("flSpin" in this)) flSpin <- 0
					local flUpCenter = 88.1 * self.GetModelScale()
					local vecCenter  = vecOrigin + angFakeRotation.Up() * flUpCenter
					self.SetAbsAngles(angFakeRotation += QAngle((flSpin += 0.015) * 16))
					self.SetAbsOrigin(vecOrigin + vecCenter - (vecOrigin + angFakeRotation.Up() * flUpCenter))
					vecOrigin = vecCenter
				}

				local flFrameTime = FrameTime()
				local Trace = {
					start      = vecOrigin
					end        = vecOrigin + hTank_scope.vecVelocity * flFrameTime * 2
					mask       = CONTENTS_SOLID // tf_tank_boss_body GetSolidMask
					startsolid = false
				}
				TraceLineEx(Trace)
				if(!Trace.startsolid && Trace.hit)
				{
					local vecNormal = Trace.plane_normal
					if(TankExt.NormalizeAngle(TankExt.VectorAngles(vecNormal).x) > -45)
					{
						hTank_scope.vecVelocity -= (vecNormal * hTank_scope.vecVelocity.Dot(vecNormal) * 2)
						self.SetAbsOrigin(Trace.endpos)
						local sSound = format(")physics/metal/metal_canister_impact_hard%i.wav", RandomInt(1, 3))
						TankExt.PrecacheSound(sSound)
						EmitSoundEx({
							sound_name  = sSound
							sound_level = 95
							entity      = self
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
					}
					else if(bFalling)
					{
						flTimeNext = flTime + JUMPTANK_JUMP_COOLDOWN
						bPreparing = false
						bJumping   = false
						bFalling   = false
						self.AcceptInput("SetStepHeight", format("%f", flStepHeightLast), null, null)

						if(bDeploying && JUMPTANK_USE_SPECIAL_DEPLOY)
						{
							SpawnEntityFromTableSafe("info_particle_system", {
								origin       = vecOrigin
								angles       = QAngle(-90, 0, 0)
								effect_name  = "fireSmoke_collumnP"
								start_active = 1
							})
							self.AcceptInput("RemoveHealth", format("%i", iMaxHealth), null, null)
							EntFire(JUMPTANK_SPECIAL_DEPLOY_RELAY, "Trigger")
							return
						}

						for(local hPlayer; hPlayer = FindByClassnameWithin(hPlayer, "player", vecOrigin, 384);)
							if(hPlayer.IsAlive() && hPlayer.GetTeam() != iTeamNum)
							{
								local vecTowards = hPlayer.GetOrigin() - vecOrigin
								vecTowards.z = 0
								vecTowards.Norm()
								hPlayer.ApplyAbsVelocityImpulse(vecTowards * 600 + Vector(0, 0, 500))
								hPlayer.StunPlayer(0.3, 1, TF_STUN_MOVEMENT, null)
							}

						DispatchParticleEffect("hammer_impact_button", vecOrigin + Vector(0, 0, 2), Vector(1))
						ScreenShake(vecOrigin, 9, 2.5, 3, 1500, 0, true)
						EmitSoundEx({
							sound_name  = ")player/fall_damage_indicator.wav"
							entity      = self
							flags       = SND_STOP
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
						EmitSoundEx({
							sound_name  = ")weapons/rocket_pack_boosters_fire.wav"
							entity      = self
							flags       = SND_STOP
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
						EmitSoundEx({
							sound_name  = ")ambient/explosions/explode_1.wav"
							sound_level = 100
							entity      = self
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
						EmitSoundEx({
							sound_name  = ")misc/halloween/strongman_fast_impact_01.wav"
							sound_level = 100
							entity      = self
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
					}
				}

				if(bJumping)
				{
					if(!bFalling && hTank_scope.vecVelocity.z <= -200)
					{
						bFalling = true
						EmitSoundEx({
							sound_name  = ")player/fall_damage_indicator.wav"
							sound_level = 100
							entity      = self
							filter_type = RECIPIENT_FILTER_GLOBAL
						})
					}
				}
			}
		}
		function OnStartDeploy()
		{
			bDeploying = true
			if(JUMPTANK_USE_SPECIAL_DEPLOY) TankExt.DelayFunction(self, this, 3.5, Jump)
			else if(bJumping)
			{
				local vecVelocity = self.GetScriptScope().vecVelocity
				vecVelocity.x = 0
				vecVelocity.y = 0
			}
		}
	}
})