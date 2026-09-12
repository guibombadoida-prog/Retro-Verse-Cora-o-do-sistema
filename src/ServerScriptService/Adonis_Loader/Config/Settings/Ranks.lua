-------------------------------
-- Scroll down for settings  --
-------------------------------

--[[
	How to add administrators:
		Below are the administrator permission levels/ranks (Mods, Admins, HeadAdmins, Creators, StuffYouAdd, etc)
		Simply place users into the respective "Users" table for whatever level/rank you want to give them.

		Format example:

			Ranks = {
				["Moderators"] = {
					Level = 100;
					Users = {
						"Username"; -- Example: "roblox"
						"Username:UserId"; -- Example: "roblox:1"
						UserId; -- Example: 1
						"Group:GroupId:GroupRank"; -- Example: "Group:123456:50"
						"Group:GroupId"; -- Example: "Group:123456"
						"Item:ItemID"; -- Example: "Item:123456"
						"GamePass:GamePassID"; -- Example: "GamePass:123456"
						"Subscription:SubscriptionId"; -- Example: "Subscription:123456"
					}
				}
			}

		If you use custom ranks, existing custom ranks will be imported with a level of 1.
		Add all new CustomRanks to the table below with the respective level you want them to be.

	NOTE: Changing the level of built-in ranks (Moderators, Admins, HeadAdmins, Creators)
	will also change the permission level for any built-in commands associated with that rank.
--]]

--------------------
-- RANKS SETTINGS --
--------------------

return {
	Ranks = {
		["Moderators"] = {
			Level = 100;
			Users = {
				-- Add users here
			};
		};

		["Admins"] = {
			Level = 200;
			Users = {
				-- Add users here
			};
		};

		["HeadAdmins"] = {
			Level = 300;
			Users = {
				-- Add users here
			};
		};

		["Creators"] = {
			Level = 900; -- Anything 900 or higher will be considered a creator and will bypass all perms & be allowed to edit settings in-game.
			Users = {
				-- [RETROVERSE] O dono do jogo. Mesmo ID que o OWNER_ID de
				-- AdminRegistryServer.server.lua, que é a fonte da verdade
				-- do projeto — não é segredo, é um UserId público da Roblox.
				-- Escrito aqui de propósito: o Adonis também reconhece o
				-- dono da place sozinho, mas se a place um dia passar para
				-- um grupo essa detecção muda de regra. Com o ID na lista,
				-- o acesso não depende de como a place é dona de si.
				1595442496; -- guibombadoida
			};
		};

		--[[
			[RETROVERSE] Os outros ranks ficam VAZIOS de propósito.

			Para dar admin a alguém, use o comando dentro do jogo
			(:admin fulano / :headadmin fulano). Com SaveAdmins = true isso
			persiste no DataStore do Adonis e não exige Studio nem publicação.

			NÃO ligue este arquivo no _G.AdminRegistry do jogo. São duas
			coisas diferentes de propósito:

			  • _G.AdminRegistry  = admin de FUNCIONALIDADE (painéis do jogo,
			                        catálogo de personagem, conquistas).
			  • Adonis            = admin de MODERAÇÃO (:kick, :ban, :shutdown).

			Unir os dois faria um ";addadmin" no painel do jogo entregar
			:ban e :shutdown de brinde. Quem precisa dos dois entra nas
			duas listas, explicitamente.
		--]]
	};
};