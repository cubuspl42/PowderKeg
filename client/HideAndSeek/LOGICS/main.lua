-- package.path = ".\\Custom\\HideAndSeek\\?.lua;" .. package.path

function OnMapLoad()
	local claw = GetClaw()
	claw.DrawFlags.NoDraw = true
	CreateObject {x=claw.X, y=claw.Y, z=9000, logic="CustomLogic", name="NetworkDaemon"}
	BnW()
end
