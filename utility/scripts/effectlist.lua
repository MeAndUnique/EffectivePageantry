-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local sFocus = "name";

function onInit()
	setDatabaseNode(nil);
	if newfocus then
		sFocus = newfocus[1];
	end
	if Session.IsHost then
		registerMenuItem(Interface.getString("list_menu_createitem"), "insert", 5);
	end
end

function applyFilter()
	window.onFilterChanged();	
end

function addEntry(bFocus)
	local w = createWindow(window.getDatabaseNode().createChild());
	if bFocus then
		w[sFocus].setFocus();
	end
	return w;
end

function onListChanged()
	window.onListChanged();
end

function onSortCompare(w1, w2)
	return window.onSortCompare(w1, w2);
end

function onMenuSelection(selection)
	if selection == 5 then
		window.filter.setValue();
		addEntry();
	end
end

function onFilter(w)
	local sFilter = window.filter.getValue();
	if sFilter ~= "" then
		if not w.label.getValue():upper():find(sFilter:upper(), 1, true) then
			return false;
		end
	end
	if w.isgmonly and not Session.IsHost and w.isgmonly.getValue() == 1 then
		return false;
	end
	return true;
end

function onDrop(x, y, draginfo)
	if Session.IsHost then
		local rEffect = EffectManager.decodeEffectFromDrag(draginfo);
		if rEffect then
			local w = addEntry(true);
			if w then
				EffectManager.setEffect(w.getDatabaseNode(), rEffect);
			end
		end
		return true;
	end
end


function update()
	local sEdit = getName() .. "_iedit";
	if window[sEdit] then
		local bEdit = (window[sEdit].getValue() == 1);
		for _,w in ipairs(getWindows()) do
			w.idelete.setVisibility(bEdit);
		end
	end
end

function onClickDown(button, x, y)
	if not isReadOnly() and window.getDatabaseNode().isOwner() then
		return true;
	end
end

function onClickRelease(button, x, y)
	if not isReadOnly() and window.getDatabaseNode().isOwner() then
		if getWindowCount() == 0 then
			addEntry(true);
		end
		return true;
	end
end
