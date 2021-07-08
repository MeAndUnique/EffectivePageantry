-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local aEffects = {};
local aFilteredEffects = {};
local nDisplayOffset = 0;
local MAX_DISPLAY_EFFECTS = 50;
local bDelayedChildrenChanged = false;
local bDelayedRebuild = false;
local sFilter = ""

function onInit()
	rebuildList();
	addHandlers();
	Module.onModuleLoad = onModuleLoadAndUnload;
	Module.onModuleUnload = onModuleLoadAndUnload;

	rightanchor.setAnchor("top", "listbottomanchor", "bottom", "absolute", 15);
end

function onClose()
	removeHandlers();
end

function onModuleLoadAndUnload(sModule)
	local nodeRoot = DB.getRoot(sModule);
	if nodeRoot then
		bDelayedRebuild = true;
		onListEffectsChanged(true);
	end
end

function addHandlers()
	local sPath = DB.getPath(getDatabaseNode());
	local sChildPath = sPath .. ".*@*";
	DB.addHandler(sChildPath, "onAdd", onChildAdded);
	DB.addHandler(sChildPath, "onDelete", onChildDeleted);
	DB.addHandler(DB.getPath(sChildPath, "label"), "onUpdate", onChildLabelChange);
	DB.addHandler(DB.getPath(sChildPath, "isgmonly"), "onUpdate", onChildGmOnlyChange);
end

function removeHandlers()
	local sPath = DB.getPath(getDatabaseNode());
	local sChildPath = sPath .. ".*@*";
	DB.removeHandler(sChildPath, "onAdd", onChildAdded);
	DB.removeHandler(sChildPath, "onDelete", onChildDeleted);
	DB.removeHandler(DB.getPath(sChildPath, "label"), "onUpdate", onChildLabelChange);
	DB.removeHandler(DB.getPath(sChildPath, "isgmonly"), "onUpdate", onChildGmOnlyChange);
end

function onChildAdded(nodeEffect)
	addListEffect(nodeEffect);
	onListEffectsChanged(true);
end

function onChildDeleted(nodeEffect)
	if aEffects[nodeEffect] then
		aEffects[nodeEffect] = nil;
		onListEffectsChanged(true);
	end
end

function onChildLabelChange(nodeLabel)
	local nodeEffect = nodeLabel.getParent();
	local rEffect = aEffects[nodeEffect];
	rEffect.sName = nodeLabel.getValue();
	rEffect.sNameLower = rEffect.sName:lower();
	applyListFilter();
end

function onChildGmOnlyChange(nodeGmOnly)
	local nodeEffect = nodeGmOnly.getParent();
	local rEffect = aEffects[nodeEffect];
	rEffect.nGMOnly = nodeGmOnly.getValue();
	applyListFilter();
end

function onListChanged()
	if bDelayedChildrenChanged then
		onListEffectsChanged(false);
	else
		list.update();
	end
end

function onFilterChanged()
	sFilter = filter.getValue():lower();
	applyListFilter();
end

function onSortCompare(w1, w2)
	local rEffect1 = aEffects[w1.getDatabaseNode()];
	local rEffect2 = aEffects[w2.getDatabaseNode()];
	return not applyEffectSort(rEffect1, rEffect2);
end

function onListEffectsChanged(bAllowDelay)
	if bAllowDelay then
		bDelayedChildrenChanged = true;
		list.setDatabaseNode(nil);
	else
		bDelayedChildrenChanged = false;
		if bDelayedRebuild then
			bDelayedRebuild = false;
			rebuildList();
		end
		applyListFilter();
	end
end

function rebuildList()
	aEffects = {};
	for _,nodeEffect in pairs(DB.getChildrenGlobal(getDatabaseNode())) do
		addListEffect(nodeEffect);
	end
	
	nDisplayOffset = 0;
	onListEffectsChanged(false);
end

function addListEffect(nodeEffect)
	local rEffect = EffectManager.getEffect(nodeEffect);
	rEffect.nodeEffect = nodeEffect;
	rEffect.sNameLower = ((rEffect.sName ~= nil) and rEffect.sName:lower()) or "";
	aEffects[nodeEffect] = rEffect;
end

function applyListFilter()
	aFilteredEffects = {};
	for _,vEffect in pairs(aEffects) do
		if applyEffectFilter(vEffect) then
			table.insert(aFilteredEffects, vEffect);
		end
	end
	table.sort(aFilteredEffects, applyEffectSort);
	
	if (nDisplayOffset < 0) or (nDisplayOffset >= #aFilteredEffects) then
		nDisplayOffset = 0;
	end
	
	list.closeAll();
	local nDisplayOffsetMax = nDisplayOffset + MAX_DISPLAY_EFFECTS;
	for index,rEffect in ipairs(aFilteredEffects) do
		if index > nDisplayOffset and index <= nDisplayOffsetMax then
			local w = list.createWindow(rEffect.nodeEffect);
		end
	end

	local nPages = getFilteredResultsPages();
	if nPages > 1 then
		local nCurrentPage = math.max(math.floor(nDisplayOffset / MAX_DISPLAY_EFFECTS) + 1, 1);
		local sPageText = string.format(Interface.getString("label_page_info"), nCurrentPage, nPages)
		page_info.setValue(sPageText);
		page_info.setVisible(true);
		if nCurrentPage == 1 then
			page_start.setVisible(false);
			page_prev.setVisible(false);
		else
			page_start.setVisible(true);
			page_prev.setVisible(true);
		end
		if nCurrentPage >= nPages then
			page_next.setVisible(false);
			page_end.setVisible(false);
		else
			page_next.setVisible(true);
			page_end.setVisible(true);
		end
	else
		page_start.setVisible(false);
		page_prev.setVisible(false);
		page_next.setVisible(false);
		page_end.setVisible(false);
		page_info.setVisible(false);
	end
end

function applyEffectFilter(rEffect)
	if sFilter ~= "" then
		if not string.find(rEffect.sNameLower, sFilter, 0, true) then
			return false;
		end
	end
	if not Session.IsHost and rEffect.nGMOnly == 1 then
		return false;
	end
	return true;
end

function applyEffectSort(vEffectA, vEffectB)
	if vEffectA.sNameLower ~= vEffectB.sNameLower then
		return vEffectA.sNameLower < vEffectB.sNameLower;
	end
	return DB.getPath(vEffectA.nodeEffect) < DB.getPath(vEffectB.nodeEffect);
end

function getFilteredResultsPages()
	local nPages = math.floor(#aFilteredEffects / MAX_DISPLAY_EFFECTS);
	if (#aFilteredEffects % MAX_DISPLAY_EFFECTS) > 0 then
		nPages = nPages + 1;
	end
	return nPages;
end


function handlePageStart()
	nDisplayOffset = 0;
	applyListFilter();
end

function handlePagePrev()
	nDisplayOffset = nDisplayOffset - MAX_DISPLAY_EFFECTS;
	applyListFilter();
end

function handlePageNext()
	nDisplayOffset = nDisplayOffset + MAX_DISPLAY_EFFECTS;
	applyListFilter();
end

function handlePageEnd()
	local nPages = getFilteredResultsPages();
	if nPages > 1 then
		nDisplayOffset = (nPages - 1) * MAX_DISPLAY_EFFECTS;
	else
		nDisplayOffset = 0;
	end
	applyListFilter();
end