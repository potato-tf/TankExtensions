local BLIMP_VALUES_TABLE = {
	BLIMP_MODEL         = "models/bots/boss_blimp/boss_blimp.mdl"
	BLIMP_MODEL_DAMAGE1 = "models/bots/boss_blimp/boss_blimp_damage1.mdl"
	BLIMP_MODEL_DAMAGE2 = "models/bots/boss_blimp/boss_blimp_damage2.mdl"
	BLIMP_MODEL_DAMAGE3 = "models/bots/boss_blimp/boss_blimp_damage3.mdl"
	BLIMP_SOUND_ENGINE  = ")ambient/turbine3.wav"
}
foreach(k,v in BLIMP_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

PrecacheModel(BLIMP_MODEL)
PrecacheModel(BLIMP_MODEL_DAMAGE1)
PrecacheModel(BLIMP_MODEL_DAMAGE2)
PrecacheModel(BLIMP_MODEL_DAMAGE3)
TankExt.PrecacheSound(BLIMP_SOUND_ENGINE)

TankExt.NewTankType("blimp*", {
	Model = {
		Default = BLIMP_MODEL
		Damage1 = BLIMP_MODEL_DAMAGE1
		Damage2 = BLIMP_MODEL_DAMAGE2
		Damage3 = BLIMP_MODEL_DAMAGE3
	}
	DisableChildModels = 1
	NoScreenShake      = 1
	EngineLoopSound    = BLIMP_SOUND_ENGINE
	NoDestructionModel = 1
	NoGravity          = 1
	DisableSmokestack  = 1
	function OnSpawn()
	{
		local sParams = split(sTankName, "|")
		local iParamsLength = sParams.len()
		if(sParams[0].find("_red")) self.SetTeam(TF_TEAM_RED)
		if(iParamsLength >= 2)
		{
			SetPropInt(self, "m_iTextureFrameIndex", 2)
			self.AcceptInput("Color", sParams[1], null, null)
		}

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
	}
})