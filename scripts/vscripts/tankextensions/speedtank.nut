TankExt.NewTankType("speedtank*", {
	function OnSpawn()
	{
		local hTracks = []
		for(local hChild = self.FirstMoveChild(); hChild != null; hChild = hChild.NextMovePeer())
			if(hChild.GetModelName().find("track_"))
				hTracks.append(hChild)

		local Params         = split(sTankName, "|")
		local flSpeedInitial = GetPropFloat(self, "m_speed")
		local flSpeedGoal    = Params.len() < 2 ? flSpeedInitial : Params[1].tofloat()
		local iHealthLast    = self.GetHealth()
		function Think()
		{
			local flHealthPercentage = iHealth / iMaxHealth.tofloat()
			if(iHealth != iHealthLast)
			{
				SetPropFloat(self, "m_speed", flHealthPercentage * (flSpeedInitial - flSpeedGoal) + flSpeedGoal)
				iHealthLast = iHealth
			}

			foreach(hTrack in hTracks)
				hTrack.SetPlaybackRate(GetPropFloat(self, "m_speed") / 80.0)
		}
	}
})