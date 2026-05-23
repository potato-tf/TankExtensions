local PATHMAKER_CONSTANTS = {
	PM_PLACEMENT_DISTANCE = 256

	PM_PAGE_DEFAULT    = 0
	PM_PAGE_VISUALIZER = 1
	PM_PAGE_COUNT      = 2

	PM_VISUALIZER_TYPE_TANK  = 0
	PM_VISUALIZER_TYPE_BLIMP = 1
	PM_VISUALIZER_TYPE_COUNT = 2

	PM_PATH_TRAIL_SPEED      = 350
	PM_PATH_TRAIL_MAX_TRAVEL = 250

	PM_PATH_VISUALIZER_SPEED      = 200
	PM_PATH_VISUALIZER_MAX_TRAVEL = 1000

	PM_PRINT_MODE_NONE     = 0
	PM_PRINT_MODE_DECIDING = 1
	PM_PRINT_MODE_TANKEXT  = 2
	PM_PRINT_MODE_POPEXT   = 3
	PM_PRINT_MODE_RAFMOD   = 4

	PM_SOUND_PLACE    = "buttons/blip1.wav"
	PM_SOUND_REMOVE   = "buttons/button15.wav"
	PM_SOUND_CHANGE   = "buttons/button16.wav"
	PM_SOUND_DECIDE   = "buttons/button18.wav"
	PM_SOUND_COMPLETE = "buttons/button9.wav"
}
foreach(k,v in PATHMAKER_CONSTANTS)
	if(!(k in ROOT))
	{
		CONST[k] <- v
		ROOT[k] <- v
	}

foreach(sSound in [PM_SOUND_PLACE, PM_SOUND_REMOVE, PM_SOUND_CHANGE, PM_SOUND_DECIDE, PM_SOUND_COMPLETE])
	PrecacheSound(sSound)

function TankExt::PathMaker(hPlayer, sPathName = null)
{
	local Delete = []
	for(local hPathMaker; hPathMaker = FindByName(hPathMaker, "tankextpathmaker");)
		Delete.append(hPathMaker)
	foreach(hEntity in Delete)
		hEntity.Kill()

	local hPathMaker = SpawnEntityFromTableSafe("prop_dynamic", {
		targetname     = "tankextpathmaker"
		model          = "models/editor/axis_helper_thick.mdl"
		disableshadows = 1
		rendermode     = 1
		renderfx       = 4
		renderamt      = 150
	})
	hPathMaker.ValidateScriptScope()
	local hPathMaker_scope = hPathMaker.GetScriptScope()

	local PathTrackArray = []
	for(local hPath; hPath = FindByClassname(hPath, "path_track");)
		PathTrackArray.append(hPath)

	local hSelectedPathGlow = SpawnEntityFromTableSafe("tf_glow", {
		glowcolor  = "255 255 0 255"
		target     = "bignet"
	})
	local hPathBeam = SpawnEntityFromTableSafe("env_beam", {
		lightningstart = "bignet"
		lightningend   = "bignet"
		boltwidth      = 1.1
		texture        = "sprites/laserbeam.vmt"
		rendercolor    = "75 75 0"
		spawnflags     = 1
	})
	SetPropEntityArray(hPathBeam, "m_hAttachEntity", hPathBeam, 0)
	SetPropEntityArray(hPathBeam, "m_hAttachEntity", hPathMaker, 1)

	local hGroundBeam = SpawnEntityFromTableSafe("env_beam", {
		lightningstart = "bignet"
		lightningend   = "bignet"
		boltwidth      = 1.1
		texture        = "sprites/laserbeam.vmt"
		rendercolor    = "50 50 50"
		spawnflags     = 1
	})
	SetPropEntityArray(hGroundBeam, "m_hAttachEntity", hGroundBeam, 0)
	SetPropEntityArray(hGroundBeam, "m_hAttachEntity", hPathMaker, 1)

	local hPathTrackVisual = SpawnEntityFromTableSafe("prop_dynamic", {
		model          = "models/editor/cone_helper.mdl"
		disableshadows = 1
	})
	local hWorldText = SpawnEntityFromTableSafe("point_worldtext", {
		origin      = Vector(0, 0, 12)
		color       = "0 255 255 255"
		font        = 3
		orientation = 1
		textsize    = 6
	})
	TankExt.SetParentArray([hWorldText], hPathTrackVisual)

	local hPathHatchVisual = SpawnEntityFromTableSafe("prop_dynamic", {
		model          = "models/editor/cone_helper.mdl"
		rendercolor    = "255 0 255"
		disableshadows = 1
	})

	local hText = SpawnEntityFromTableSafe("game_text", {
		message    = ""
		channel    = 0
		holdtime   = 0.3
		x          = 0.05625
		y          = 0.1
	})

	local hPlacementVisual = SpawnEntityFromTableSafe("prop_dynamic", {
		model          = "models/empty.mdl"
		disableshadows = 1
		rendermode     = 1
		renderamt      = 100
		teamnum        = TF_TEAM_BLUE
	})

	local iPathMakerArrayLength = 0
	local PathMakerArray        = []
	local function AddToPathMakerArray(vecPath)
	{
		local hPath = SpawnEntityFromTableSafe("prop_dynamic", {
			origin         = vecPath
			model          = "models/editor/axis_helper_thick.mdl"
			disableshadows = 1
		})
		PathMakerArray.append([vecPath, hPath])
		iPathMakerArrayLength++
	}
	if(sPathName)
	{
		local hPath = FindByName(null, sPathName)
		if(hPath)
		{
			local hStartPath
			for(local i = 1; i < 256; i++)
			{
				local hPreviousPath = GetPropEntity(hPath, "m_pprevious")

				if(!hPreviousPath)
				{
					hStartPath = hPath
					break
				}

				hPath = hPreviousPath
			}

			if(hStartPath)
			{
				AddToPathMakerArray(hStartPath.GetOrigin())
				local hPath = hStartPath
				for(local i = 1; i < 256; i++)
				{
					local hNextPath = GetPropEntity(hPath, "m_pnext")
					if(hNextPath)
					{
						AddToPathMakerArray(hNextPath.GetOrigin())
						hPath = hNextPath
					}
					else break
				}
			}
		}
	}

	local iVisualizerEntitiesLength = 0
	local VisualizerEntities        = []
	local function ClearVisualizerModels()
	{
		foreach(hEntity in VisualizerEntities)
			if(hEntity.IsValid())
				hEntity.Kill()
		VisualizerEntities.clear()
		iVisualizerEntitiesLength = 0
	}
	TankExt.SetDestroyCallback(hPathMaker, function()
	{
		foreach(Array in PathMakerArray)
			if(Array[1].IsValid())
				Array[1].Kill()

		foreach(hEntity in [hSelectedPathGlow, hPathBeam, hGroundBeam, hPathTrackVisual, hPathHatchVisual, hText, hPlacementVisual])
			if(hEntity.IsValid())
				hEntity.Kill()

		ClearVisualizerModels()
	})

	local iGridSize    = 32
	local iButtonsLast = 0
	local iPrintMode   = PM_PRINT_MODE_NONE
	local iPage        = PM_PAGE_DEFAULT

	local bLockSelection  = true
	local iSelectionIndex = iPathMakerArrayLength - 1
	local PathSelection   = iSelectionIndex != -1 ? PathMakerArray[iSelectionIndex] : null

	local flTimeVisualizer           = Time()
	local flCurrentTrailTravelLength = 0

	local iVisualizerType                 = PM_VISUALIZER_TYPE_TANK
	local bShowPlacementVisualizer        = false
	local bShowPathVisualizer             = false
	local flCurrentVisualizerTravelLength = 0

	local function RefreshPlacementVisuals()
	{
		if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
			hPlacementVisual.SetModel("models/bots/boss_blimp/boss_blimp.mdl")
		else
			hPlacementVisual.SetModel("models/bots/boss_bot/boss_tank.mdl")
	}

	local function FollowEntity(hEntity, hParent)
	{
		hEntity.AcceptInput("SetParent", "!activator", hParent, null)
		hEntity.SetMoveType(MOVETYPE_NONE, MOVECOLLIDE_DEFAULT)
		SetPropInt(hEntity, "m_fEffects", GetPropInt(hEntity, "m_fEffects") | EF_BONEMERGE)
		SetPropEntity(hEntity, "m_hLightingOrigin", hParent)
		hEntity.AddSolidFlags(FSOLID_NOT_SOLID)
		hEntity.SetLocalOrigin(Vector())
		hEntity.SetLocalAngles(QAngle())
	}
	PrecacheModel("models/bots/boss_bot/boss_tank.mdl")
	PrecacheModel("models/bots/boss_bot/tank_track_l.mdl")
	PrecacheModel("models/bots/boss_bot/tank_track_r.mdl")
	local function CreateTankVisualizer(bReturnEntity = false)
	{
		local hTank = CreateByClassnameSafe("prop_dynamic")
		hTank.SetModel("models/bots/boss_bot/boss_tank.mdl")
		hTank.SetTeam(TF_TEAM_BLUE)
		hTank.DispatchSpawn()
		hTank.AcceptInput("SetAnimation", "movement", null, null)

		local hTrackR = CreateByClassnameSafe("prop_dynamic")
		hTrackR.SetModel("models/bots/boss_bot/tank_track_r.mdl")
		hTrackR.DispatchSpawn()
		hTrackR.AcceptInput("SetAnimation", "forward", null, null)
		hTrackR.SetPlaybackRate(PM_PATH_VISUALIZER_SPEED / 80.0)
		FollowEntity(hTrackR, hTank)

		local hTrackL = CreateByClassnameSafe("prop_dynamic")
		hTrackL.SetModel("models/bots/boss_bot/tank_track_l.mdl")
		hTrackL.DispatchSpawn()
		hTrackL.AcceptInput("SetAnimation", "forward", null, null)
		hTrackL.SetPlaybackRate(PM_PATH_VISUALIZER_SPEED / 80.0)
		FollowEntity(hTrackL, hTank)

		if(bReturnEntity)
			return hTank
		else
		{
			iVisualizerEntitiesLength++
			VisualizerEntities.insert(0, hTank)
		}
	}
	PrecacheModel("models/bots/boss_blimp/boss_blimp.mdl")
	local function CreateBlimpVisualizer(bReturnEntity = false)
	{
		local hBlimp = CreateByClassnameSafe("prop_dynamic")
		hBlimp.SetModel("models/bots/boss_blimp/boss_blimp.mdl")
		hBlimp.SetTeam(TF_TEAM_BLUE)
		hBlimp.DispatchSpawn()
		hBlimp.AcceptInput("SetAnimation", "movement", null, null)

		if(bReturnEntity)
			return hBlimp
		else
		{
			iVisualizerEntitiesLength++
			VisualizerEntities.insert(0, hBlimp)
		}
	}

	local function RecalculateTextColor()
	{
		if(iPrintMode > PM_PRINT_MODE_NONE)
			hText.KeyValueFromString("color", "255 255 255")
		else if(iPage == PM_PAGE_DEFAULT)
			hText.KeyValueFromString("color", bLockSelection ? "255 255 0" : "0 255 255")
		else if(iPage == PM_PAGE_VISUALIZER)
			hText.KeyValueFromString("color", "255 255 255")
	}
	RecalculateTextColor()

	local function GridMath(value) return floor(value / iGridSize + 0.5) * iGridSize
	local function PathMakerThink()
	{
		if(!hPlayer.IsValid())
		{
			self.Kill()
			return
		}

		foreach(hEntity in [hSelectedPathGlow, hPathBeam, hGroundBeam, hPathTrackVisual, hPathHatchVisual, hText, hPlacementVisual])
			if(!hEntity.IsValid())
			{
				self.Kill()
				return
			}

		local iButtons         = GetPropInt(hPlayer, "m_nButtons")
		local iButtonsChanged  = iButtonsLast ^ iButtons
		local iButtonsPressed  = iButtonsChanged & iButtons
		local iButtonsReleased = iButtonsChanged & (~iButtons)
		iButtonsLast = iButtons

		local flTime  = Time()
		local hWeapon = hPlayer.GetActiveWeapon()
		if(hWeapon)
		{
			SetPropFloat(hPlayer, "m_Shared.m_flStealthNoAttackExpire", flTime + 0.2)
			if(hWeapon.GetAttribute("auto fires full clip", 0))
				SetPropFloat(hWeapon, "m_flNextPrimaryAttack", flTime + 0.2)
		}

		local vecEye = hPlayer.EyePosition()
		local angEye = hPlayer.EyeAngles()

		local TargetTrace = {
			start   = vecEye
			end     = vecEye + angEye.Forward() * PM_PLACEMENT_DISTANCE
			hullmin = Vector(-8, -8, -32)
			hullmax = Vector(8, 8, 8)
			mask    = CONTENTS_SOLID
		}
		TraceHull(TargetTrace)
		local vecTarget = TargetTrace.endpos
		vecTarget.x = GridMath(vecTarget.x)
		vecTarget.y = GridMath(vecTarget.y)
		vecTarget.z = GridMath(vecTarget.z)
		hPathMaker.SetAbsOrigin(vecTarget)

		TargetTrace.start = vecTarget
		TargetTrace.end   = vecTarget + Vector(0, 0, -8192)
		TraceLineEx(TargetTrace)
		hGroundBeam.SetAbsOrigin(TargetTrace.endpos)

		local hNearestPathTrack
		local flDistSqr = FLT_MAX
		foreach(hPath in PathTrackArray)
		{
			if(!hPath.IsValid())
				continue

			local flDistNew = (vecTarget - hPath.GetOrigin()).LengthSqr()
			if(flDistNew < flDistSqr)
			{
				hNearestPathTrack = hPath
				flDistSqr         = flDistNew
			}
		}

		if(hNearestPathTrack)
		{
			local vecPathTrack   = hNearestPathTrack.GetOrigin()
			local hPathTrackNext = GetPropEntity(hNearestPathTrack, "m_pnext")
			local vecDirection   = hPathTrackNext ? hPathTrackNext.GetOrigin() - vecPathTrack : Vector(0, 0, -1)
			vecDirection.Norm()
			hPathTrackVisual.SetAbsOrigin(vecPathTrack)
			hPathTrackVisual.SetForwardVector(vecDirection)
			hPathTrackVisual.FirstMoveChild().AcceptInput("SetText", hNearestPathTrack.GetName(), null, null)
		}
		else
			hPathTrackVisual.SetAbsOrigin(Vector(9999, 9999, 9999))

		if(!bLockSelection)
		{
			local flDistSqr = FLT_MAX
			foreach(iIndex, Array in PathMakerArray)
			{
				local hPath     = Array[1]
				local flDistNew = (vecTarget - Array[0]).LengthSqr()
				if(flDistNew < flDistSqr)
				{
					iSelectionIndex = iIndex
					PathSelection   = Array
					flDistSqr       = flDistNew
				}
			}
		}

		local sText
		if(iPrintMode != PM_PRINT_MODE_NONE)
			sText = "[Export Method]\nMouse1: TankExt\nMouse2: PopExt+\nMouse3: Rafmod\n\nR + Mouse3: Cancel"
		else if(iPage == PM_PAGE_DEFAULT)
			sText = format("[Grid Size: %i]\nR + Mouse1: Add Hatch Node\nR + Mouse2: Cycle Grid Size\nMouse1: Add To Selection\nMouse2: Delete Selection\nMouse3: %s Selection\n\nCrouch: Visualizers\nR + Mouse3: Print Path", iGridSize, bLockSelection ? "Unlock" : "Lock")
		else if(iPage == PM_PAGE_VISUALIZER)
		{
			local sType
			if(iVisualizerType == PM_VISUALIZER_TYPE_TANK)
				sType = "Tank"
			else if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
				sType = "Blimp"

			sText = format("[Visualizer: %s]\nMouse1: %s For Placements\nMouse2: %s For Paths\nMouse3: Cycle Visualizer Type\n\nCrouch: Nodes\nR + Mouse3: Print Path", sType, bShowPlacementVisualizer ? "Hide" : "Show", bShowPathVisualizer ? "Hide" : "Show")
		}

		hText.KeyValueFromString("message", sText)
		hText.AcceptInput("Display", null, hPlayer, null)

		local hSelectedPath = PathSelection ? PathSelection[1] : null
		SetPropEntity(hSelectedPathGlow, "m_hTarget", hSelectedPath)
		hPathBeam.SetAbsOrigin(hSelectedPath ? hSelectedPath.GetOrigin() : vecTarget)

		if(bShowPlacementVisualizer && PathSelection)
		{
			if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
				hPlacementVisual.SetAbsOrigin(vecTarget)
			else
				hPlacementVisual.SetAbsOrigin(TargetTrace.endpos)

			local vecForward = vecTarget - PathSelection[1].GetOrigin()
			if(vecForward.Norm() > 1e-5)
			{
				local vecLeft    = Vector(-vecForward.y, vecForward.x, 0.0)
				local vecForward = vecLeft.Cross(TargetTrace.plane_normal)
				vecForward.Norm()

				hPlacementVisual.SetForwardVector(vecForward)
			}
		}
		else
			hPlacementVisual.SetAbsOrigin(Vector(9999, 9999, 9999))

		local vecHatchNode
		if(iPathMakerArrayLength > 0)
		{
			local vecLastPath   = PathMakerArray.top()[0]
			local vecHatch      = FindByClassname(null, "func_capturezone").GetCenter()
			local vecLastPathXY = Vector(vecLastPath.x, vecLastPath.y, 0)
			local vecHatchXY    = Vector(vecHatch.x, vecHatch.y, 0)
			local vecDirection  = vecLastPathXY - vecHatchXY
			vecDirection.Norm()
			hPathHatchVisual.SetAbsOrigin(vecHatchNode = Vector(vecHatch.x, vecHatch.y, vecTarget.z) + vecDirection * 176)
			hPathHatchVisual.SetForwardVector(vecDirection * -1)
		}
		else
			hPathHatchVisual.SetAbsOrigin(Vector(9999, 9999, 9999))

		if(iPrintMode > PM_PRINT_MODE_NONE)
		{
			if(iPrintMode > PM_PRINT_MODE_DECIDING)
			{
				EmitSoundEx({
					sound_name  = PM_SOUND_COMPLETE
					entity      = hPlayer
					filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
				})
				ClientPrint(hPlayer, HUD_PRINTCENTER, "Path printed to console")

				local TextArray = []
				if(iPrintMode == PM_PRINT_MODE_TANKEXT)
				{
					TextArray.append("tank_path = [")
					foreach(k, array in PathMakerArray)
						TextArray.append(format("\tVector(%i, %i, %i)    // tank_path_%i", array[0].x, array[0].y, array[0].z, k + 1))
					TextArray.append("]")
				}
				else if(iPrintMode == PM_PRINT_MODE_POPEXT)
				{
					TextArray.append("\"ExtraTankPath\" : [\n\t[")
					foreach(k, array in PathMakerArray)
						TextArray.append(format("\t\t\"%i %i %i\"    // extratankpath1_%i", array[0].x, array[0].y, array[0].z, k + 1))
					TextArray.append("\t]\n]")
				}
				else if(iPrintMode == PM_PRINT_MODE_RAFMOD)
				{
					TextArray.append("ExtraTankPath\n{\n\tName \"tank_path\"")
					foreach(k, array in PathMakerArray)
						TextArray.append(format("\tNode \"%i %i %i\"    // tank_path_%i", array[0].x, array[0].y, array[0].z, k + 1))
					TextArray.append("}")
				}

				local flDelay = 0
				foreach(sText in TextArray)
				{
					local sPrint = sText
					TankExt.DelayFunction(null, null, flDelay += 0.03, function() { ClientPrint(null, HUD_PRINTCONSOLE, sPrint) })
				}

				self.Kill()
				return
			}

			if(iButtons & IN_RELOAD && iButtonsPressed & IN_ATTACK3)
			{
				iPrintMode = PM_PRINT_MODE_NONE
				RecalculateTextColor()
			}
			else if(iButtonsPressed & IN_ATTACK)
				iPrintMode = PM_PRINT_MODE_TANKEXT
			else if(iButtonsPressed & IN_ATTACK2)
				iPrintMode = PM_PRINT_MODE_POPEXT
			else if(iButtonsPressed & IN_ATTACK3)
				iPrintMode = PM_PRINT_MODE_RAFMOD
		}
		else
		{
			if(iButtonsPressed & IN_DUCK)
			{
				EmitSoundEx({
					sound_name  = PM_SOUND_CHANGE
					entity      = hPlayer
					filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
				})
				iPage++
				if(iPage == PM_PAGE_COUNT)
					iPage = 0

				RecalculateTextColor()
			}
			else if(iButtons & IN_RELOAD && iButtonsPressed & IN_ATTACK3)
			{
				EmitSoundEx({
					sound_name  = PM_SOUND_DECIDE
					entity      = hPlayer
					filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
				})
				iPrintMode = PM_PRINT_MODE_DECIDING
				RecalculateTextColor()
			}

			if(iPage == PM_PAGE_DEFAULT)
			{
				if(iButtons & IN_RELOAD)
				{
					if(iButtonsPressed & IN_ATTACK && vecHatchNode && (PathMakerArray.top()[0] - vecHatchNode).LengthSqr() > 1e-5)
					{
						EmitSoundEx({
							sound_name  = PM_SOUND_PLACE
							pitch       = 110
							entity      = hPlayer
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						})

						local hPath = SpawnEntityFromTableSafe("prop_dynamic", {
							origin         = vecHatchNode
							model          = "models/editor/axis_helper_thick.mdl"
							disableshadows = 1
						})
						PathMakerArray.append([vecHatchNode, hPath])
						iPathMakerArrayLength++

						if(bLockSelection && iSelectionIndex == iPathMakerArrayLength - 2)
						{
							iSelectionIndex++
							PathSelection = PathMakerArray[iSelectionIndex]
						}
					}
					else if(iButtonsPressed & IN_ATTACK2)
					{
						EmitSoundEx({
							sound_name  = PM_SOUND_CHANGE
							entity      = hPlayer
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						})
						iGridSize *= 2
						if(iGridSize > 128)
							iGridSize = 4
					}
				}
				else
				{
					if(iButtonsPressed & IN_ATTACK)
					{
						EmitSoundEx({
							sound_name  = PM_SOUND_PLACE
							entity      = hPlayer
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						})

						local hPath = SpawnEntityFromTableSafe("prop_dynamic", {
							origin         = vecTarget
							model          = "models/editor/axis_helper_thick.mdl"
							disableshadows = 1
						})
						PathMakerArray.insert(iSelectionIndex + 1, [vecTarget, hPath])
						iPathMakerArrayLength++

						if(bLockSelection)
						{
							iSelectionIndex++
							PathSelection = PathMakerArray[iSelectionIndex]
						}
					}
					else if(iButtonsPressed & IN_ATTACK2 && PathSelection)
					{
						EmitSoundEx({
							sound_name  = PM_SOUND_REMOVE
							entity      = hPlayer
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						})
						PathSelection[1].Kill()
						PathMakerArray.remove(iSelectionIndex)
						iPathMakerArrayLength--

						if(bLockSelection)
						{
							if(iSelectionIndex - 1 in PathMakerArray)
								iSelectionIndex--
							else if(!(iSelectionIndex in PathMakerArray))
							{
								iSelectionIndex = -1
								PathSelection   = null
							}
							PathSelection = iSelectionIndex != -1 ? PathMakerArray[iSelectionIndex] : null
						}
						else if(iPathMakerArrayLength == 0)
						{
							iSelectionIndex = -1
							PathSelection   = null
						}
					}
					else if(iButtonsPressed & IN_ATTACK3)
					{
						EmitSoundEx({
							sound_name  = PM_SOUND_CHANGE
							entity      = hPlayer
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						})
						bLockSelection = !bLockSelection
						hSelectedPathGlow.AcceptInput("SetGlowColor", bLockSelection ? "255 255 0" : "0 255 255", null, null)
						hPathBeam.AcceptInput("Color", bLockSelection ? "75 75 0" : "0 75 75", null, null)
						RecalculateTextColor()
					}
				}
			}
			else if(iPage == PM_PAGE_VISUALIZER)
			{
				if(iButtonsPressed & IN_ATTACK)
				{
					EmitSoundEx({
						sound_name  = PM_SOUND_CHANGE
						pitch       = 90
						entity      = hPlayer
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
					})
					if(bShowPlacementVisualizer = !bShowPlacementVisualizer)
						RefreshPlacementVisuals()
					else
						hPlacementVisual.SetModel("models/empty.mdl")

				}
				else if(iButtonsPressed & IN_ATTACK2)
				{
					EmitSoundEx({
						sound_name  = PM_SOUND_CHANGE
						pitch       = 90
						entity      = hPlayer
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
					})

					if(!(bShowPathVisualizer = !bShowPathVisualizer))
						ClearVisualizerModels()
				}
				else if(iButtonsPressed & IN_ATTACK3)
				{
					EmitSoundEx({
						sound_name  = PM_SOUND_CHANGE
						entity      = hPlayer
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
					})
					iVisualizerType++
					if(iVisualizerType == PM_VISUALIZER_TYPE_COUNT)
						iVisualizerType = 0

					ClearVisualizerModels()
					RefreshPlacementVisuals()
				}
			}

			local flFrameTime = FrameTime()
			flCurrentTrailTravelLength      = (flCurrentTrailTravelLength + PM_PATH_TRAIL_SPEED * flFrameTime) % PM_PATH_TRAIL_MAX_TRAVEL
			flCurrentVisualizerTravelLength = (flCurrentVisualizerTravelLength + PM_PATH_VISUALIZER_SPEED * flFrameTime) % PM_PATH_VISUALIZER_MAX_TRAVEL
			if(flTime >= flTimeVisualizer)
			{
				flTimeVisualizer += 0.03

				local ParticleSpawns        = []
				local iParticleSpawnsLength = 0
				local flParticleOvershoot   = 0

				local VisualizerSpawns        = []
				local iVisualizerSpawnsLength = 0
				local flVisualizerOvershoot   = 0

				for(local iIndex = 0; iIndex < iPathMakerArrayLength - 1; iIndex++)
				{
					local vecOrigin  = PathMakerArray[iIndex][0]
					local vecTarget  = PathMakerArray[iIndex + 1][0]
					local vecTowards = vecTarget - vecOrigin

					local flLengthMax = vecTowards.Norm()

					local flParticleLength = flParticleOvershoot || flCurrentTrailTravelLength
					while((flParticleOvershoot = (flParticleLength > flLengthMax ? flParticleLength - flLengthMax : 0)) == 0)
					{
						local vecParticle = vecOrigin + vecTowards * flParticleLength
						flParticleLength += PM_PATH_TRAIL_MAX_TRAVEL

						iParticleSpawnsLength++
						ParticleSpawns.append({
							origin = vecParticle
							length = (vecParticle - vecEye).LengthSqr()
						})
					}

					if(bShowPathVisualizer)
					{
						local flVisualizerLength = flVisualizerOvershoot || flCurrentVisualizerTravelLength
						while((flVisualizerOvershoot = (flVisualizerLength > flLengthMax ? flVisualizerLength - flLengthMax : 0)) == 0)
						{
							local vecModel = vecOrigin + vecTowards * flVisualizerLength
							local vecForward

							if(iVisualizerType == PM_VISUALIZER_TYPE_TANK)
							{
								local GroundTrace = {
									start = vecModel
									end   = vecModel + Vector(0, 0, -8192)
									mask  = CONTENTS_SOLID
								}
								TraceLineEx(GroundTrace)
								vecModel = GroundTrace.endpos

								local vecLeft = Vector(-vecTowards.y, vecTowards.x, 0.0)
								vecForward = vecLeft.Cross(GroundTrace.plane_normal)
								vecForward.Norm()
							}
							else if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
							{
								vecForward = Vector(vecTowards.x, vecTowards.y, 0)
								vecForward.Norm()
							}
							flVisualizerLength += PM_PATH_VISUALIZER_MAX_TRAVEL

							iVisualizerSpawnsLength++
							VisualizerSpawns.append({
								origin  = vecModel
								forward = vecForward
							})
						}
					}
				}

				if(iParticleSpawnsLength != 0)
				{
					if(iParticleSpawnsLength > 64)
						ParticleSpawns.sort(function(First, Second)
						{
							local iLengthFirst  = First.length
							local iLengthSecond = Second.length

							if(iLengthFirst > iLengthSecond)
								return 1
							else if(iLengthFirst < iLengthSecond)
								return -1
							return 0
						})

					local iSpawnedParticles = 0
					local SpawnParticles
					SpawnParticles = function()
					{
						foreach(Table in ParticleSpawns)
						{
							iSpawnedParticles++

							if(iSpawnedParticles == 65)
							{
								ParticleSpawns = ParticleSpawns.slice(iSpawnedParticles - 1)
								TankExt.DelayFunction(null, null, 0.001, @() SpawnParticles())
								return
							}
							else if(iSpawnedParticles == 129)
								return

							DispatchParticleEffect("drg_3rd_impact", Table.origin, Vector(1))
						}
					}
					SpawnParticles()
				}

				if(bShowPathVisualizer)
				{
					while(iVisualizerSpawnsLength > iVisualizerEntitiesLength)
						if(iVisualizerType == PM_VISUALIZER_TYPE_TANK)
							CreateTankVisualizer()
						else if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
							CreateBlimpVisualizer()

					while(iVisualizerSpawnsLength < iVisualizerEntitiesLength)
					{
						local hEntity = VisualizerEntities[iVisualizerSpawnsLength]
						if(hEntity.IsValid())
							hEntity.Kill()

						iVisualizerEntitiesLength--
						VisualizerEntities.remove(iVisualizerSpawnsLength)
					}

					foreach(iIndex, Table in VisualizerSpawns)
					{
						local hEntity = VisualizerEntities[iIndex]
						if(!hEntity.IsValid())
						{
							if(iVisualizerType == PM_VISUALIZER_TYPE_TANK)
								hEntity = CreateTankVisualizer(true)
							else if(iVisualizerType == PM_VISUALIZER_TYPE_BLIMP)
								hEntity = CreateBlimpVisualizer(true)
							VisualizerEntities[iIndex] = hEntity
						}

						hEntity.SetAbsOrigin(Table.origin)
						hEntity.SetForwardVector(Table.forward)
					}
				}
			}
		}

		return -1
	}
	hPathMaker_scope.PathMakerThink <- PathMakerThink
	TankExt.AddThinkToEnt(hPathMaker, "PathMakerThink")
}