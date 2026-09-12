--[[
	If you wish to create a custom theme for your Adonis GUIs, place it in this folder.
	You can find instructions about how to do this at our wiki:
		https://github.com/Epix-Incorporated/Adonis/wiki/Guide:-Creating-a-theme
--]]
return function() end

--[[
	[RETROVERSE] Este arquivo NÃO PODE SER APAGADO.

	O carregador indexa `configFolder.Themes` direto, sem FindFirstChild,
	e a publicação "somente código" só cria pasta que está no caminho de
	algum script. Sem este módulo aqui a pasta Themes não chega ao jogo e
	o Adonis não sobe. Ele devolve `function() end`, então entra na lista
	de temas como um tema que não faz nada — que é como o autor entrega.
--]]
