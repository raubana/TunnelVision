local DEBUG_PAUSING = CreateConVar("twg_debug_pausing", "0", bit.bor( FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_CHEAT ) )
local PAUSING_DISABLE = CreateConVar("twg_pausing_disable", "0", bit.bor( FCVAR_SERVER_CAN_EXECUTE, FCVAR_NOTIFY, FCVAR_CHEAT ) )




function ENT:FrozenPausingInit()
	self.pausing = false
	self.pausing_wants_to_stop = false
	self.pausing_end = 0
end




function ENT:BeginPausing()
	if DEBUG_PAUSING:GetBool() then
		print( self, "BeginPausing" )
	end

	if PAUSING_DISABLE:GetBool() or not self.pausing_enabled then return end

	if not self.pausing then
		if DEBUG_PAUSING:GetBool() then
			print( self, "Pausing start." )
		end
		self.pausing = true
		self.pausing_wants_to_stop = false
		self.pausing_end = CurTime() + Lerp( math.invlerp( self.unstable_percent, 0.0, 0.5 ), Lerp( math.random(), 30, 60 ), Lerp(math.random(), 0.5, 1) )
	elseif not self.pausing_wants_to_stop then
		self.pausing_end = math.max( self.pausing_end, CurTime() + Lerp( self.unstable_percent, Lerp( math.random(), 1, 3 ), Lerp(math.random(), 0.5, 1) ) )
	end
end




function ENT:FrozenPausingUpdate()
	if self.pausing then
		if ( ( CurTime() >= self.pausing_end or ( ( self.have_target or self.have_old_target ) and CurTime() - self.target_last_seen > 10.0 ) ) 
		or self.is_unstable ) and
		not ( not self.pausing_enabled or PAUSING_DISABLE:GetBool() ) then
			if self.frozen then
				if DEBUG_PAUSING:GetBool() and not self.pausing_wants_to_stop then
					print( self, "I want to unpause but I can't." )
				end
				self.pausing_wants_to_stop = true
			else
				if DEBUG_PAUSING:GetBool() then
					print( self, "Pausing end." )
				end
				self.pausing = false
			end
		end
	end	
end