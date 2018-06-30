AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName		= "Tunnel Vision: Fly"
ENT.Author			= "raubana"
ENT.Information		= "Hello, my name is..."
ENT.Category		= "Tunnel Vision"

ENT.Editable		= false
ENT.Spawnable		= true
ENT.AdminOnly		= true
ENT.RenderGroup		= RENDERGROUP_OPAQUE




local COUNTER = 1
local TOTAL = 10




function ENT:Initialize()
	self:SetModel("models/props_junk/watermelon01.mdl")
	self:SetModelScale( 0.1 )
	self:DrawShadow( false )
	
	if SERVER then
		self.sound_pitch = Lerp( math.random(), 75, 125 )
	
		self:PhysicsInitSphere( 0.1, "default_silent" )
		self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
		
		self:GetPhysicsObject():SetMass( 1 )
		
		-- states:
		-- 0 = Standing on a surface.
		-- 1 = Flying.
		-- 2 = Flying but wants to land.
		
		self.stage = 0
		self.next_stage_change = 0
		
		self.spooked = false
		self.spooked_end = 0
		self.spook_sensitivity_update_freq = 1.0
		self.spook_sensitivity_next_update = 1.0
		self.spook_sensitivity_reduce_rate = 0.01
		self.spook_sensitivity = 0.75
		
		self.tired = false
		self.tired_end = 0
		
		self.target_next_update = 0
		self.target_update_freq = 1.0
		self.target = nil
		
		self.future_weld_data = nil
		self.weld = nil
		
		self.flight_target_pos = self:GetPos() + Vector(0,0,10)
		self.flight_force = Vector(0,0,0)
		self.flight_update_freq = 0.33
		self.flight_next_update = 0
	end
end




if SERVER then

	function ENT:StartFlyingSound()
		if not self.sound then
			local filter = RecipientFilter()
			filter:AddAllPlayers()
			self.sound = CreateSound(self, "npc/sent_tv_fly/fly_loop"..tostring(COUNTER)..".wav", filter)
			self.sound:SetSoundLevel( 50 )
			
			COUNTER = COUNTER + 1
			if COUNTER > TOTAL then
				COUNTER = 1
			end
			
			self.sound:PlayEx(1.0, self.sound_pitch)
		end
	end
	
	
	
	
	function ENT:StopFlyingSound()
		if self.sound then
			self.sound:Stop()
			self.sound = nil
		end
	end
	
	
	
	
	function ENT:OnRemove()
		self:StopFlyingSound()
		self:RemoveWeld()
	end
	
	
	
	
	function ENT:OnTakeDamage( dmg )
		SafeRemoveEntity( self )
	end
	
	
	
	
	function ENT:Spook( intensity )
		-- print( self, "Spook", intensity )
	
		if self.stage == 0 and not self.spooked and intensity > self.spook_sensitivity then
			self.stage = 0
			self.target = nil
			self.next_stage_change = CurTime()
			self.spooked = true
			self.spooked_end = CurTime() + 5
			self.spook_sensitivity = Lerp( 0.25, self.spook_sensitivity, intensity )
		end
	end
	
	
	
	
	function ENT:CreateWeld( ent, bone )
		--print( self, "CreateWeld" )
	
		if not self.weld or not IsValid( self.weld ) then
			self.weld = constraint.Weld(
				ent,
				self,
				bone,
				0,
				250,
				true,
				false
			)
		--else
			--print( self, "Couldn't make weld because it already exists", self.weld )
		end
	end
	
	
	
	
	function ENT:RemoveWeld( )
		--print( self, "CreateWeld" )
	
		if self.weld then
			constraint.RemoveConstraints( self, "Weld" )
			SafeRemoveEntity( self.weld )
			self.weld = nil
		--else
			--print( self, "Couldn't remove weld because it doesn't exist or something.", self.weld )
		end
	end
	
	
	
	
	function ENT:Think()
		if self.future_weld_data != nil then
			self:CreateWeld( self.future_weld_data[1], self.future_weld_data[2] )
			self.future_weld_data = nil
		end
	
		if self.spooked then
			if CurTime() >= self.spooked_end then
				self.spooked = false
			end
		else
			if CurTime() >= self.spook_sensitivity_next_update then
				self.spook_sensitivity_next_update = CurTime() + self.spook_sensitivity_update_freq
				self.spook_sensitivity = math.max( 0, self.spook_sensitivity - self.spook_sensitivity_reduce_rate )
				
				-- print( self.spook_sensitivity )
			end
		end
		
		if self.stage == 0 and self.tired and CurTime() >= self.tired_end then
			self.tired = false
		end
		
		if self.stage == 1 or self.stage == 2 then
			local phys_obj = self:GetPhysicsObject()
			
			if CurTime() >= self.target_next_update then
				self.target_next_update = CurTime() + self.target_update_freq + (math.random()*0.1)
				
				local change_target
				
				if self.target != nil and IsValid(self.target) then
					if self.target:GetPos():Distance( self:GetPos() ) > 1000 then
						self.target = nil
					end
				end
					
				if self.target != nil and IsValid(self.target) then
					change_target = math.random() > 0.75
				else
					change_target = math.random() > 0.25
				end
				
				
				if change_target then
					self.target = nil
				
					local tr = util.TraceLine({
						start = self:GetPos(),
						endpos = self:GetPos() + (VectorRand() * 500),
						filter = self,
						mask = MASK_SOLID
					})
					
					-- debugoverlay.Cross( tr.HitPos, 1, self.target_update_freq, color_white, true )
					
					if tr.Hit and tr.Entity and IsValid(tr.Entity) then
					
						if not tr.Entity:IsWorld() then
							if tr.MatType == MAT_ALIENFLESH or tr.MatType == MAT_BLOODYFLESH or tr.MatType == MAT_FLESH then
								self.target = tr.Entity
							end
						end
						
					else
					
						if self.stage == 2 then
							self.flight_target_pos = tr.HitPos
						else
							self.flight_target_pos = LerpVector( math.random(), tr.HitPos, tr.StartPos )
						end
						
					end
				end
			end
		
			if CurTime() >= self.flight_next_update then
				self.flight_next_update = CurTime() + self.flight_update_freq + (math.random()*0.1)
			
				if self.target != nil and IsValid( self.target ) then
					if self.target:IsPlayer() then
						self.flight_target_pos = self.target:GetShootPos()
					else
					
						local pos = self.target:GetPos()
						local mins = self.target:OBBMins() + pos
						local maxs = self.target:OBBMaxs() + pos
					
						self.flight_target_pos = Vector(
							Lerp( math.random(), mins.x, maxs.x),
							Lerp( math.random(), mins.y, maxs.y),
							Lerp( math.random(), mins.z, maxs.z)
						)
					end
				end
				
				-- debugoverlay.Cross( self.flight_target_pos, 10, self.flight_update_freq, color_white, true )
				
				local gravity_comp = -physenv.GetGravity() * Lerp(math.random(), 0.95, 1.05 )
				
				local vel_comp
				if self.spooked then
					vel_comp = vector_origin
				else
					vel_comp = (-self:GetVelocity() / self.flight_update_freq) * Lerp(math.random(), 0.75, 1.25 )
				end
				
				local scale = 15
				if self.spooked then
					scale = 100
				end
				
				local offset_comp = (self.flight_target_pos - self:GetPos()) * scale
				local offset_comp_magn = offset_comp:Length()
				
				if offset_comp_magn > 250 then
					offset_comp = 250*offset_comp/offset_comp_magn
				end
				
				local force = gravity_comp + vel_comp + offset_comp
				local force_magn = force:Length()
				force = force + ( (VectorRand() * force_magn * 0.025) / self.flight_update_freq)
				
				self.flight_force = force * phys_obj:GetMass() * engine.TickInterval()
			end
			
			phys_obj:ApplyForceCenter( self.flight_force )
		end
		
		if CurTime() >= self.next_stage_change then
			if self.stage == 0 then
				self.stage = 1
				self:RemoveWeld()
				self:StartFlyingSound()
				if not self.tired then
					self.next_stage_change = CurTime() + Lerp(math.random(), 3, 15)
				else
					self.next_stage_change = CurTime() + Lerp(math.random(), 0.5, 1.0 )
				end
			elseif self.stage == 1 then
				self.stage = 2
				self.tired = true
			end
		end
		
		self:NextThink( CurTime())
		return true
	end
	
	
	
	
	function ENT:PhysicsCollide( colData, collider )
		if self.stage == 2 and isvector( colData.HitPos ) then
			local dist = colData.HitPos:Distance(self:GetPos())
			
			if dist < 10 then
				local bone = 0
				if not colData.HitEntity:IsWorld() then
					if colData.HitEntity.GetModelPhysBoneCount != nil then
						local num_physbones = colData.HitEntity:GetModelPhysBoneCount()
						
						for i = 0, num_physbones-1 do
							if colData.HitEntity:PhysicsObjectNum( i ) == colData.HitObject then
								bone = colData.HitEntity:TranslatePhysBoneToBone( i )
								break
							end
						end
					end
				end
			
				self.stage = 0
				self:StopFlyingSound()
				self.future_weld_data = { colData.HitEntity, bone }
				
				self.tired_end = CurTime() + Lerp(math.random(), 2, 5)
				self.next_stage_change = math.max( self.tired_end+1, CurTime() + Lerp( math.pow(math.random(), 2), 1, 20 ) )
			end
		end
	end
	
	

	
	hook.Add( "EntityEmitSound", "sent_tv_fly_EntityEmitSound", function( data )
		if isentity( data.Entity ) and IsValid( data.Entity ) and data.Entity:GetClass() == "sent_tv_fly" then return end
	
		local pos = data.Pos
		
		if not isvector( pos ) then
			if isentity( data.Entity ) and IsValid( data.Entity ) then
				pos = data.Entity:GetPos()
			end
		end
		
		if isvector( pos ) then
			local radius = util.DBToRadius( data.SoundLevel, data.Volume )
			local radius_sqr = radius * radius
			
			local ent_list = ents.FindByClass( "sent_tv_fly" )
			
			for i, ent in ipairs( ent_list ) do
				if IsValid(ent) and ent.stage == 0 then
					local dist_sqr = ent:GetPos():DistToSqr( pos )
					
					if dist_sqr <= radius_sqr then
						ent:Spook( math.pow( 1 - (math.sqrt(dist_sqr) / radius), 2 ) )
					end
				end
			end
		end
	end )
	
end




if CLIENT then

	local matFlySprite = Material( "sprites/tunnelvision/fly" )
	local SIZE = 1

	function ENT:Draw()
		local light = render.GetLightColor( self:GetPos() ) * 255 * 2
		
		local color = Color(
								math.min( light.x, 255),
								math.min( light.y, 255),
								math.min( light.z, 255)
							)
	
		render.SetMaterial( matFlySprite )
		render.DrawSprite( self:GetPos(), SIZE, SIZE, color )
	end
	
end