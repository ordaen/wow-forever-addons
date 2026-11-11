-- The last of LunaType's own files: in the client, the runtime starts and the game's side of `"$game"` is made,
-- before any addon's file loads and reads it. A test that brought a stand-in game has it already.
local R = LunaType
if R.game then
	return
end
-- What `"$game"` has of the runtime's own: waiting a time, and waiting for the next frame.
R.game = { delay = R.sleep, frame = R.frame }
R.start()
R.addon("LunaTypeGame").index.Client.new(nil)
-- The client's tooltips, and what the tooltips read of the client besides: the host's own (tips.lua).
R.tips.install()
R.tips.parts()
