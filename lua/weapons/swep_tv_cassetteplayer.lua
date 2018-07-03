AddCSLuaFile()




SWEP.Base = "weapon_base"

SWEP.PrintName 				= "Cassette Player"
SWEP.Category				= "Tunnel Vision"
SWEP.Purpose				= ""
SWEP.Instructions			= ""
SWEP.Spawnable				= true
SWEP.AdminSpawnable			= true

if CLIENT then
	SWEP.BounceWeaponIcon	= false
	SWEP.WepSelectIcon		= surface.GetTextureID( "" )
end

SWEP.Slot 					= 2
SWEP.SlotPos				= 0

SWEP.ViewModelFOV			= 62
SWEP.ViewModelFlip			= false
SWEP.ViewModel				= "models/weapons/v_slam.mdl"
SWEP.WorldModel				= "models/weapons/w_slam.mdl"
SWEP.HoldType				= "slam"
SWEP.UseHands				= true
SWEP.DrawCrosshair			= false

SWEP.DeploySpeed 			= 5.0

SWEP.Primary.Delay 			= 1
SWEP.Primary.ClipSize		= -1
SWEP.Primary.DefaultClip	= -1
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo			= "none"

SWEP.Secondary.Delay 		= 1
SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo			= "none"

SWEP.DrawAmmo				= false





local MESSAGE_LOAD = 0
local MESSAGE_TOGGLEPLAYBACK = 1
local MESSAGE_TOGGLEFASTFORWARD = 2
local MESSAGE_REWIND = 3




function SWEP:Deploy()
	self:SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
end




if SERVER then

	hook.Add( "Initialize", "swep_tv_cassetteplayer_Initialize", function()
		util.AddNetworkString( "TV_CassettePlayer" )
	end )
	
	


	function SWEP:Initialize()
		self.last_reload = 0
	end
	
	
	
	
	function SWEP:Deploy()
		net.Start( "TV_CassettePlayer" )
		net.WriteInt( MESSAGE_LOAD, 3 )
		net.Send( self.Owner )
	end




	function SWEP:PrimaryAttack()
		if not self:CanPrimaryAttack() then return end
		
		self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
		self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
		
		net.Start( "TV_CassettePlayer" )
		net.WriteInt( MESSAGE_TOGGLEPLAYBACK, 3 )
		net.Send( self.Owner )
	end




	function SWEP:CanPrimaryAttack()
	   if not IsValid(self.Owner) then return end
	   
	   return true
	end




	function SWEP:SecondaryAttack()
		if not self:CanSecondaryAttack() then return end
		
		net.Start( "TV_CassettePlayer" )
		net.WriteInt( MESSAGE_TOGGLEFASTFORWARD, 3 )
		net.Send( self.Owner )
	end




	function SWEP:CanSecondaryAttack()
	   if not IsValid(self.Owner) then return end
	   
	   return true
	end




	function SWEP:Reload()
		local dif = CurTime() - self.last_reload
		self.last_reload = CurTime()
		
		if dif >= 1.0 then
			net.Start( "TV_CassettePlayer" )
			net.WriteInt( MESSAGE_REWIND, 3 )
			net.Send( self.Owner )
		end
	end
	
end





if CLIENT then
	local CassetteName = CassetteName or "sound/music/tunnelvision/cassettes/tape1.mp3"
	local Playing = Playing or false
	local IsAtEnd = IsAtEnd or false
	local FastForwarding = FastForwarding or false
	local Channel = Channel or nil
	local ChannelReady = ChannelReady or false
	
	
	
	
	function LoadSong()
		if Channel != nil or IsValid( Channel ) then return end
	
		sound.PlayFile( CassetteName, "mono noblock noplay", function( channel, errorID, errorName )
			Channel = channel
			ChannelReady = true
			Channel:SetVolume( 0.4 )
			
			print( channel, errorID, errorName )
		end )
	end
	
	
	
	
	function ToggleFastForward()
		if not ChannelReady then return end
		if not Playing then return end
		if IsAtEnd then return end
		
		FastForwarding = not FastForwarding
		if FastForwarding then
			Channel:SetPlaybackRate( 4.0 )
			return "fastforwarding"
		else
			Channel:SetPlaybackRate( 1.0 )
			return "unfastforwarding"
		end
	end
	
	
	
	
	function TogglePlayback()
		if not ChannelReady then return end
		if IsAtEnd then return end
		
		if FastForwarding then
			ToggleFastForward()
		end
		
		Playing = not Playing
		if Playing then
			Channel:Play()
			return "playing"
		else
			Channel:Pause()
			return "pausing"
		end
	end
	
	
	
	
	function Rewind()
		if not ChannelReady then return end
		
		if Playing then
			TogglePlayback()
		end
		
		if FastForwarding then
			ToggleFastForward()
		end
		
		Channel:SetTime( 0 )
		IsAtEnd = false
		
		return "rewound"
	end
	
	
	
	
	net.Receive( "TV_CassettePlayer", function( len )
		local message = net.ReadInt( 3 )
		
		local result
		local msg
		local snd
		
		if message == MESSAGE_TOGGLEPLAYBACK then
			result = TogglePlayback()
			if result == "playing" then
				msg = "You press the play button."
				snd = "play"
			elseif result == "pausing" then
				msg = "You press the stop button."
				snd = "stop"
			end
		elseif message == MESSAGE_TOGGLEFASTFORWARD then
			result = ToggleFastForward()
			if result == "fastforwarding" then
				msg = "You press the fast-forward button."
				snd = "fastforward"
			elseif result == "unfastforwarding" then
				msg = "You stopped fast-forwarding."
				if Playing then
					snd = "play"
				else
					snd = "stop"
				end
			end
		elseif message == MESSAGE_REWIND then
			result = Rewind()
			if result == "rewound" then
				msg = "You rewound the cassette."
				snd = "stop"
			end
		elseif message == MESSAGE_LOAD then
			LoadSong()
		end
		
		if msg then
			LocalPlayer():PrintMessage( HUD_PRINTTALK, msg )
		end
		
		if snd then
			LocalPlayer():EmitSound( "weapons/swep_tv_cassetteplayer/"..snd..".wav" )
		end
	end)

	
	
	
	function SWEP:OnRemove()
		if not ChannelReady then return end
		Channel:Stop()
		
		Playing = false
		IsAtEnd = false
		FastForwarding = false
		Channel = nil
		ChannelReady = false
	end
	
	
	
	
	hook.Add( "Tick", "swep_tv_cassetteplayer_Tick", function()
		-- print( Playing, IsAtEnd, FastForwarding, ChannelReady )
	
		if Playing then
			if Channel:GetTime() >= Channel:GetLength() then
				IsAtEnd = true
				Playing = false
				
				LocalPlayer():PrintMessage( HUD_PRINTTALK, "The cassette player is at the end of the tape." )
			end
		end
	end )
end
