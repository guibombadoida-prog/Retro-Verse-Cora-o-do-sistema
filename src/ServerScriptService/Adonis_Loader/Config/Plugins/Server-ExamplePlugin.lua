--[[
	SERVER PLUGINS' NAMES MUST START WITH "Server:" OR "Server-"
	CLIENT PLUGINS' NAMES MUST START WITH "Client:" OR "Client-"

	Plugins have full access to the server/client tables and most variables.

	You can use the MakePluginEvent to use the script instead of setting up an event.
	PlayerJoined will fire after the player finishes initial loading
	CharacterAdded will also fire after the player is loaded, it does not use the CharacterAdded event.

	service.Events.PlayerAdded:Connect(function(p)
		print(`{p.Name} Joined! Example Plugin`)
	end)

	service.Events.CharacterAdded:Connect(function(p)
		server.RunCommand('name', plr.Name, 'BobTest Example Plugin')
	end)

--]]

--[[
	[RETROVERSE] Este arquivo NÃO PODE SER APAGADO.

	O carregador do Adonis indexa `configFolder.Plugins` direto, sem
	FindFirstChild — pasta ausente é erro na hora de subir. E a publicação
	"somente código" só cria pasta que está no caminho de um script
	(resolveParent, em tasks/apply_code_payload.luau). Logo: pasta sem
	nenhum módulo dentro simplesmente não chega ao jogo, e o Adonis quebra.
	Este plugin vazio é o que mantém a pasta Plugins existindo.

	[RETROVERSE] O comando de exemplo do autor foi COMENTADO.

	Como vinha, ele registrava o comando :example com
	AdminLevel = "Players" — ou seja, qualquer jogador podia rodar, e cada
	uso imprimia duas linhas no Output do servidor. Isso é uma torneira de
	log aberta para qualquer um. O código segue aqui embaixo, intacto,
	como modelo de como se escreve um comando novo.

	server.Commands.ExampleCommand = {
		Prefix = server.Settings.Prefix;	-- Prefix to use for command
		Commands = {"example"};	-- Commands
		Args = {"arg1"};	-- Command arguments
		Description = "Example command";	-- Command Description
		Hidden = true; -- Is it hidden from the command list?
		Fun = false;	-- Is it fun?
		AdminLevel = "Players";	    -- Admin level; If using settings.CustomRanks set this to the custom rank name (eg. "Baristas")
		Function = function(plr,args)    -- Function to run for command
			print("HELLO WORLD FROM AN EXAMPLE COMMAND :)")
			print(`Player supplied args[1] {args[1]}`)
		end
	}
--]]

return function(Vargs)
	local server, service = Vargs.Server, Vargs.Service
end
