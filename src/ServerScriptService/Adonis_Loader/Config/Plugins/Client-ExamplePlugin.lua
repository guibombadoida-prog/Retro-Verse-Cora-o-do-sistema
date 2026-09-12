--[[
	[RETROVERSE] Renomeado de "Client-Example Plugin" para
	"Client-ExamplePlugin" — só para tirar o espaço do nome do arquivo.
	O carregador casa pelo prefixo (`^client[%-:]`), que continua batendo.

	Mantido porque a pasta Plugins precisa de módulo dentro para existir
	no jogo; ver a explicação em Server-ExamplePlugin.lua. Como veio do
	autor, este plugin não faz nada: todo o corpo é comentário.
--]]

return function(Vargs)
	local client, service = Vargs.Client, Vargs.Service

	--Acts the same as a server plugin but with client functions instead of server.
	--[[
	local window = client.UI.Make("Window",{
		Title = "Changing DataStore";
		Size = {700,300};
		Icon = "rbxassetid://357249130";
	})
	
	window:Add("ImageLabel",{
		Image = "rbxassetid://531490964";
	})
	
	--]]
end
