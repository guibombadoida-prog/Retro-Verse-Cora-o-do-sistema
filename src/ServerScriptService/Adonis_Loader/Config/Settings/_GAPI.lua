---------------------
-- _G API SETTINGS --
---------------------

return {
	-- [RETROVERSE] true -> false. Nenhum script do RetroVerse consome
	-- _G.Adonis; o jogo tem o próprio _G.AdminRegistry. Menor privilégio:
	-- sem isso, o Adonis não publica nada no ambiente global.
	-- Para ligar depois (ex.: checar admin do Adonis no painel do jogo),
	-- volte para true e leia a lista Allowed_API_Calls abaixo.
	G_API = false;
	G_Access = false;				-- If enabled, allows other scripts to access Adonis using _G.Adonis.Access; Scripts will still be able to do things like _G.Adonis.CheckAdmin(player)
	-- [RETROVERSE] Sorteada por defesa em profundidade. Com G_Access = false
	-- ela não é usada, mas um padrão conhecido não deve ficar num repositório
	-- público esperando que alguém ligue o G_Access sem trocar a chave.
	G_Access_Key = "-eof3g19O5KaFkzyNEQyMM6y";
	G_Access_Perms = "Read";		-- Access perms
	Allowed_API_Calls = {
		Client = false;				-- Allow access to the Client (not recommended)
		Settings = false;			-- Allow access to settings (not recommended)
		DataStore = false;			-- Allow access to the DataStore (not recommended)
		Core = false;				-- Allow access to the script's core table (REALLY not recommended)
		Service = false;			-- Allow access to the script's service metatable
		Remote = false;				-- Communication table
		HTTP = false;				-- HTTP-related things like Trello functions
		Anti = false;				-- Anti-Exploit table
		Logs = false;
		UI = false;					-- Client UI table
		Admin = false;				-- Admin related functions
		Functions = false;			-- Functions table (contains functions used by the script that don't have a subcategory)
		Variables = true;			-- Variables table
		API_Specific = true;		-- API Specific functions
	};
};