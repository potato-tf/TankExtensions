local SCALETANK_VALUES_TABLE = {
	SCALETANK_SCALE_TIME = 0.4
}
foreach(k,v in SCALETANK_VALUES_TABLE)
	if(!(k in TankExt.ValueOverrides))
		ROOT[k] <- v

TankExt.NewTankType("scaletank*", {
	UseBetterTracks = 1
	function OnSpawn()
	{
		local Params         = split(sTankName, "|")
		local flScaleInitial = self.GetModelScale()
		local flScaleGoal    = Params.len() < 2 ? flScaleInitial : Params[1].tofloat()
		local iHealthLast    = self.GetHealth()
		function Think()
		{
			local flHealthPercentage = iHealth / iMaxHealth.tofloat()
			if(iHealth != iHealthLast)
			{
				self.SetModelScale(flHealthPercentage * (flScaleInitial - flScaleGoal) + flScaleGoal, SCALETANK_SCALE_TIME)
				iHealthLast = iHealth
			}

			EmitSoundEx({
				sound_name  = "misc/null.wav"
				pitch       = 100 + (1 - self.GetModelScale()) * 15
				entity      = self
				filter_type = RECIPIENT_FILTER_GLOBAL
				flags       = SND_CHANGE_PITCH | SND_IGNORE_NAME
			})
		}
	}
})