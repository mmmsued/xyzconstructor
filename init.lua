
-- Copyright (C) 2021 Norbert Thien, multimediamobil - Region Süd, Lizenz: Creative Commons BY-SA 4.0
-- Kein Rezept, nur im Creative Modus verwendbar oder mit give <playername> xyzconstructor:constructor_block
-- Privileg xyzconstructor erforderlich
-- Missing: prüfen, ob frei - prüfen, ob geschützter Block - prüfen, ob protected area - param2-Wert setzen

local not_in_creative_inventory = 0 -- 0 = wird im Creative Mode angezeigt, 1 = wird nicht angezeigt, dann nur mit give(me) erreichbar
local pass_pos_value = {}
local max_blocks_to_set = 100 -- maximale Anzahl an Blöcken, die pro Durchgang gesetzt werden können
local xyz_axis_index = 1
local xyz_axis = "+X (East),-X (West),+Y (Up),-Y (Down),+Z (North),-Z (South)"
local xyz_axis_list = {"+X (East)","-X (West)","+Y (Up)","-Y (Down)","+Z (North)","-Z (South)"}


local initialize_data = function(meta)
	local owner = meta:get_string("owner")

	if not minetest.check_player_privs(owner,{xyzconstructor = true}) then --bei fehlendem Recht Formspec gar nicht erst öffnen
		minetest.chat_send_player(owner, "xyzconstructor -!- You need the xyzconstructor-privileg for construction.")
		return
	end

	local pos = meta:get_string("pos") or ""
	local choice_of_axis = meta:get_string("choice_of_axis") or "+X (East)"
	local blocks_to_set = minetest.formspec_escape(meta:get_string("blocks_to_set")) or 1
	local interval_to_set = minetest.formspec_escape(meta:get_string("interval_to_set")) or 1

	if pos == "" then
		meta:set_string("infotext", "Open formspec of xyzconstructor\nto select construction start point")
	else
		meta:set_string("infotext", "construction start point set to " .. pos)
	end

	for i=1, #xyz_axis_list do -- Index für formspec Dropdown-Element
		if xyz_axis_list[i] == choice_of_axis then
			xyz_axis_index = i
		end
	end

	meta:set_string("formspec", "size[8.0,11.0;]" ..
		"button_exit[0.1,0.3;3.0,1.0;setstartpos;1. Set start point]" ..

		"label[0.25,2.0;2. Drag item from inventory]" ..
		"label[4.7,2.0;otherwise \"air\" will be used]" ..
		"list[context;main;3.5,1.5;1.0,1.0;]" ..
		"list[current_player;main;0.0,3.0;8.0,4.0;]" ..

		"label[0.25,7.5;3. Direction to build (x, y, z)]" ..
		"dropdown[0.5,8.0;3.0,1.0;choice_of_axis;" .. xyz_axis .. ";" .. xyz_axis_index .. "]" ..
		"label[4.0,7.5;4. Blocks to build (max. " .. max_blocks_to_set .. ")]" ..
		"field[4.7,8.2;3.0,1.0;blocks_to_set;;" .. blocks_to_set .. "]" ..
		"label[0.25,9.0;5. Interval to build]" ..
		"field[0.75,9.8;3.0,1.0;interval_to_set;;" .. interval_to_set .. "]" ..
		"button_exit[4.4,9.49;3.0,1.0;startsetitems;6. Start construction]"
		-- "listring[]"
	)
end


local function set_items(pos, meta)
	local target_pos = minetest.string_to_pos(meta:get_string("pos"))
	local owner = meta:get_string("owner")
	local blocks_to_set = tonumber(meta:get_string("blocks_to_set")) or 1
	local choice_of_axis = meta:get_string("choice_of_axis") or "+X (East)"
	local interval_to_set = tonumber(meta:get_string("interval_to_set")) or 1

	blocks_to_set = blocks_to_set - blocks_to_set % 1 -- eventuelle Nachkommastellen abschneiden
	interval_to_set = interval_to_set - interval_to_set % 1

	if not target_pos then
		minetest.chat_send_player(owner, "xyzconstructor -!- You have to set a start position.")
		return nil
	end

	if minetest.is_protected(target_pos, owner) then
		return
	end

	if type(blocks_to_set) == "string" then -- funktioniert nicht, falsche String-Eingabe hat aber auch keine negativen Folgen bzw. wird oben schon durch "or 1" abgefangen
		minetest.chat_send_player(owner, "xyzconstructor -!- Only numbers allowed (must between 0 - " .. max_blocks_to_set ..").")
	end

	if blocks_to_set > max_blocks_to_set or blocks_to_set < 1 then
		blocks_to_set = 1
		minetest.chat_send_player(owner, "xyzconstructor -!- You try to set to much or to less blocks (must between 0 - " .. max_blocks_to_set ..").")
	end

	local inv = meta:get_inventory()
	local stack = inv:get_stack("main", 1)
	local node_name = stack:get_name()

	if not minetest.registered_nodes[node_name] and not (node_name == "ignore" or node_name == "") then -- Türen etc. ausschließen, da der Inventarname vom Platzierungsnamen abweicht
		minetest.chat_send_player(owner, "xyzconstructor -!- Sorry, you can't use the item \"" .. node_name .. "\" with xyzconstructor.")
		return nil
	end

	if node_name == "ignore" or node_name == "" then
		node_name = "air"
	end

	if choice_of_axis == "-X (West)" then -- X-Richtung negativ (Westen)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x-i, y = target_pos.y, z = target_pos.z}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x-blocks_to_set+1, y = target_pos.y, z = target_pos.z}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall

	elseif choice_of_axis == "+Y (Up)" then -- Y-Richtung positiv (nach oben)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x, y = target_pos.y+i, z = target_pos.z}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x, y = target_pos.y+blocks_to_set-1, z = target_pos.z}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall

	elseif choice_of_axis == "-Y (Down)" then -- Y-Richtung negativ (nach unten)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x, y = target_pos.y-i, z = target_pos.z}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x, y = target_pos.y-blocks_to_set+1, z = target_pos.z}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall

	elseif choice_of_axis == "+Z (North)" then -- Z-Richtung positiv (Norden)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x, y = target_pos.y, z = target_pos.z+i}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x, y = target_pos.y, z = target_pos.z+blocks_to_set-1}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall

	elseif choice_of_axis == "-Z (South)" then -- Z-Richtung negativ (Süden)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x, y = target_pos.y, z = target_pos.z-i}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x, y = target_pos.y, z = target_pos.z-blocks_to_set+1}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall

	else -- X-Richtung positiv (Osten)
		for i = 0, blocks_to_set-1, interval_to_set do
			minetest.add_node({x = target_pos.x+i, y = target_pos.y, z = target_pos.z}, {name = node_name})
		end
		minetest.add_node({x = target_pos.x+blocks_to_set-1, y = target_pos.y, z = target_pos.z}, {name = node_name}) -- letzten Block setzen, unabhängig vom Intervall
	end
	return
end


local function construct(pos)
	local meta = minetest.get_meta(pos)

	meta:set_string("owner", "")
	meta:set_string("pos", "")
	meta:set_string("choice_of_axis","+X (East)")
	meta:set_string("blocks_to_set","1")
	meta:set_string("interval_to_set","1")

	initialize_data(meta)
end


local function after_place(pos, placer)
	local meta = minetest.get_meta(pos)
	meta:set_string("owner", placer:get_player_name())

	local inv = meta:get_inventory()
	inv:set_size("main", 1)

	initialize_data(meta, pos)
end


local function receive_fields(pos, _, fields, sender)
	if not sender or minetest.is_protected(pos, sender:get_player_name()) then
		return -- bei fehlenden Rechten abbrechen
	end

	local meta = minetest.get_meta(pos)

	if fields.setstartpos then
		minetest.chat_send_player(sender:get_player_name(), "xyzconstructor -!- Please punch the desired start point")
		pass_pos_value = pos -- pos und damit meta-Daten für minetest.register_on_punchnode bereitstellen
	end

	if fields.startsetitems then
		meta:set_string("choice_of_axis",fields.choice_of_axis)
		meta:set_string("blocks_to_set", fields.blocks_to_set)
		meta:set_string("interval_to_set", fields.interval_to_set)

		initialize_data(meta) -- Daten des Formspecs sichern
		set_items(pos, meta) -- Konstruktion starten
	end
end


minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing) -- Funktion zum Setzen des Startpunktes
	local playername = puncher:get_player_name()
	local passed_pos = pass_pos_value

	if passed_pos then
		-- if pointed_thing.type == "node" then oder  if pointed_thing.type == "nothing" then -- eventuell noch einarbeiten
		if minetest.is_protected(pos, playername) then
			-- and not minetest.check_player_privs(playername, {xyzconstructor = true}) then
			minetest.chat_send_player(playername, "xyzconstructor -!- Selected start point is protected, aborting selection")
			return
		else
			local meta = minetest.get_meta(passed_pos)
			local pos_str = minetest.pos_to_string(pos)
			meta:set_string("pos", pos_str)
			minetest.chat_send_player(playername, "xyzconstructor -!- Start point set to " .. pos_str .. ". Open formspec of Constructor-Block again for next steps.")
			meta:set_string("infotext", "start point set to: pos = " .. pos_str)

			initialize_data(meta)
		end
		pass_pos_value = nil
	end
end)


minetest.register_node("xyzconstructor:constructor_block", {
	description = "XYZ Constructor Block set blocks by value",
	tiles = {"xyzconstructor_top.png","xyzconstructor_bottom.png","xyzconstructor_right.png","xyzconstructor_left.png","xyzconstructor_back.png","xyzconstructor_front.png"},
	groups = {cracky = 3, oddly_breakable_by_hand = 3, not_in_creative_inventory = not_in_creative_inventory},
	on_construct = construct,
	after_place_node = after_place,
	on_receive_fields = receive_fields,
	mesecons = {
			effector = {
	    	action_on = function (pos)
					local meta = minetest.get_meta(pos)

					set_items(pos, meta)
				end
	  	}
	}
})


minetest.register_privilege( -- formspec des Constructor-Blocks ist nur mit entsprechendem privilege aufrufbar
    'xyzconstructor',
    {
        description = (
            "Gives player privilege for use of xyzconstructor"
        ),
        give_to_singleplayer = true,
        give_to_admin = true,
    }
)


minetest.register_on_leaveplayer(function(player)
	local playername = player:get_player_name()
	pass_pos_value = nil
end)
