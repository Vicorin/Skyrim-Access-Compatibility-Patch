// Perk-tree lookups for the beast skill trees. See BeastPerks.h.
//
// The werewolf and Vampire Lord perk trees hang off the actor values WerewolfPerks (158) and
// VampirePerks (159); their ActorValueInfo::perkTree is a BGSSkillPerkTreeNode graph exactly like
// the eighteen skills'. Perk points for them are the globals behind the default objects
// WerewolfAvailablePerks (320) and VampireAvailablePerks (321), not the player's perk points.

#include <string>
#include <vector>
#include <set>
#include <algorithm>
#include <cctype>

#include "common/IDebugLog.h"
#include "skse64_common/Relocation.h"
#include "skse64/GameTypes.h"
#include "skse64/GameForms.h"
#include "skse64/GameFormComponents.h"
#include "skse64/GameData.h"
#include "skse64/GameReferences.h"
#include "skse64/GameAPI.h"
#include "skse64/PapyrusVM.h"
#include "skse64/PapyrusNativeFunctions.h"

#include "BeastPerks.h"

namespace
{
	enum : UInt32
	{
		kAV_WerewolfPerks = 158,
		kAV_VampirePerks = 159,

		kDefaultObject_WerewolfAvailablePerks = 320,
		kDefaultObject_VampireAvailablePerks = 321,
		kDefaultObject_Count = 0x15B
	};

	// Same addresses as skse64's GameData.cpp / GameForms.cpp (runtime 1.7.104); those files are
	// not part of this build.
	RelocPtr<ActorValueList*> s_actorValueList(0x0219DEC8);
	RelocPtr<BGSDefaultObjectManager> s_defaultObjects(0x0219D180);

	const UInt32 kBeastTrees[] = { kAV_WerewolfPerks, kAV_VampirePerks };

	ActorValueInfo* GetActorValueInfo(UInt32 id)
	{
		ActorValueList* list = *s_actorValueList;
		if (!list || id >= ActorValueList::kNumActorValues) return nullptr;
		// ActorValueList: UInt32 unk00; UInt32 pad04; ActorValueInfo* actorValues[164];
		ActorValueInfo** values = reinterpret_cast<ActorValueInfo**>(reinterpret_cast<UInt8*>(list) + 8);
		return values[id];
	}

	const char* TreeName(ActorValueInfo* info)
	{
		if (!info) return "";
		const char* name = info->fullName.GetName();
		return name ? name : "";
	}

	const char* PerkName(BGSPerk* perk)
	{
		if (!perk) return "";
		const char* name = perk->fullName.GetName();
		return name ? name : "";
	}

	std::string PerkDescription(BGSPerk* perk)
	{
		if (!perk) return "";
		BSString out;
		// field type is the record tag "DESC" (as the engine reads it, little endian)
		CALL_MEMBER_FN(&perk->description, Get)(&out, perk, 0x43534544);
		const char* s = out.Get();
		return s ? s : "";
	}

	// Available beast perk points for a tree (the global behind the matching default object).
	int PerkPool(UInt32 treeAV)
	{
		UInt32 index = (treeAV == kAV_VampirePerks) ? kDefaultObject_VampireAvailablePerks : kDefaultObject_WerewolfAvailablePerks;
		BGSDefaultObjectManager* dobj = s_defaultObjects;
		if (!dobj || index >= kDefaultObject_Count) return 0;
		TESForm* form = dobj->objects[index];
		if (!form) { _MESSAGE("beast perk pool: default object %u is empty", index); return 0; }
		// TESGlobal: float value at 0x34
		float value = *reinterpret_cast<float*>(reinterpret_cast<UInt8*>(form) + 0x34);
		_MESSAGE("beast perk pool: av=%u default object %u -> form %08X type %u value %.1f", treeAV, index, form->formID, form->formType, value);
		if (form->formType != kFormType_Global) return 0;
		return (int)value;
	}

	bool PlayerHasPerk(BGSPerk* perk)
	{
		PlayerCharacter* player = *g_thePlayer;
		if (!player || !perk) return false;
		return CALL_MEMBER_FN(player, HasPerk)(perk);
	}

	struct Ranks
	{
		int owned = 0;
		int total = 0;
		BGSPerk* current = nullptr;	// the rank whose description the menu shows (next to buy, or the last)
	};

	Ranks GetRanks(BGSPerk* base)
	{
		Ranks r;
		std::vector<BGSPerk*> chain;
		std::set<BGSPerk*> seen;
		for (BGSPerk* p = base; p && !seen.count(p) && chain.size() < 32; p = p->nextPerk)
		{
			seen.insert(p);
			chain.push_back(p);
		}
		r.total = (int)chain.size();
		for (BGSPerk* p : chain)
			if (PlayerHasPerk(p)) r.owned++;
		if (!chain.empty())
			r.current = chain[(size_t)((r.owned < r.total - 1) ? r.owned : r.total - 1)];
		return r;
	}

	// All nodes of a tree in a stable order (depth first from the root), each once.
	void CollectNodes(BGSSkillPerkTreeNode* node, std::vector<BGSSkillPerkTreeNode*>& out, std::set<BGSSkillPerkTreeNode*>& seen)
	{
		if (!node || seen.count(node)) return;
		seen.insert(node);
		out.push_back(node);
		for (UInt32 i = 0; i < node->connections.count; i++)
		{
			BGSSkillPerkTreeNode* child = nullptr;
			if (node->connections.GetNthItem(i, child))
				CollectNodes(child, out, seen);
		}
	}

	std::vector<BGSSkillPerkTreeNode*> TreeNodes(UInt32 treeAV)
	{
		std::vector<BGSSkillPerkTreeNode*> nodes;
		ActorValueInfo* info = GetActorValueInfo(treeAV);
		if (info && info->perkTree)
		{
			std::set<BGSSkillPerkTreeNode*> seen;
			CollectNodes(info->perkTree, nodes, seen);
		}
		return nodes;
	}

	std::string Lower(const std::string& s)
	{
		std::string out = s;
		for (char& c : out) c = (char)tolower((unsigned char)c);
		return out;
	}

	std::string Trim(const std::string& s)
	{
		size_t a = 0, b = s.size();
		while (a < b && isspace((unsigned char)s[a])) a++;
		while (b > a && isspace((unsigned char)s[b - 1])) b--;
		return s.substr(a, b - a);
	}

	// "Bestial Strength (1/4)" -> "Bestial Strength"
	std::string StripRank(const std::string& label)
	{
		std::string s = Trim(label);
		if (!s.empty() && s.back() == ')')
		{
			size_t open = s.rfind(" (");
			if (open != std::string::npos)
			{
				bool ok = true;
				bool slash = false;
				for (size_t i = open + 2; i + 1 < s.size(); i++)
				{
					char c = s[i];
					if (c == '/') { if (slash) ok = false; slash = true; }
					else if (!isdigit((unsigned char)c)) ok = false;
				}
				if (ok && slash) s = Trim(s.substr(0, open));
			}
		}
		return s;
	}

	// At least one connected parent perk owned (or no real parent at all). The root node has no perk.
	bool ParentsSatisfied(BGSSkillPerkTreeNode* node, std::vector<std::string>& parentNames)
	{
		bool anyRealParent = false;
		bool anyOwned = false;
		for (UInt32 i = 0; i < node->connectees.count; i++)
		{
			BGSSkillPerkTreeNode* parent = nullptr;
			if (!node->connectees.GetNthItem(i, parent) || !parent || !parent->perk) continue;
			anyRealParent = true;
			parentNames.push_back(PerkName(parent->perk));
			if (PlayerHasPerk(parent->perk)) anyOwned = true;
		}
		return !anyRealParent || anyOwned;
	}

	std::string Join(const std::vector<std::string>& items)
	{
		std::string out;
		for (size_t i = 0; i < items.size(); i++)
		{
			if (i) out += (i + 1 == items.size()) ? " and " : ", ";
			out += items[i];
		}
		return out;
	}

	BSFixedString Fixed(const std::string& s) { return BSFixedString(s.c_str()); }
	std::string Int(int v) { return std::to_string(v); }

	// Result layout (all strings):
	//  0 "1" found / "0" not found
	//  1 perk name            2 description          3 owned ranks     4 total ranks
	//  5 "1" buyable / "0"    6 why not buyable      7 prerequisites   8 leads to
	//  9 tree name           10 perk points in pool 11 tree actor value id
	// 12 "1" prerequisites met (a connected parent owned, or root)
	VMResultArray<BSFixedString> Papyrus_DescribeBeastPerk(StaticFunctionTag*, BSFixedString label)
	{
		VMResultArray<BSFixedString> result;
		result.resize(13, BSFixedString(""));
		result[0] = BSFixedString("0");

		std::string wanted = Lower(StripRank(label.data ? label.data : ""));
		if (wanted.empty()) return result;

		for (UInt32 treeAV : kBeastTrees)
		{
			ActorValueInfo* info = GetActorValueInfo(treeAV);
			if (!info || !info->perkTree) continue;
			for (BGSSkillPerkTreeNode* node : TreeNodes(treeAV))
			{
				if (!node->perk) continue;
				if (Lower(PerkName(node->perk)) != wanted) continue;

				Ranks ranks = GetRanks(node->perk);
				std::vector<std::string> parents;
				bool parentsOk = ParentsSatisfied(node, parents);
				std::vector<std::string> children;
				for (UInt32 i = 0; i < node->connections.count; i++)
				{
					BGSSkillPerkTreeNode* child = nullptr;
					if (node->connections.GetNthItem(i, child) && child && child->perk)
						children.push_back(PerkName(child->perk));
				}
				int pool = PerkPool(treeAV);

				std::string why;
				bool buyable = true;
				if (ranks.owned >= ranks.total) { buyable = false; why = "Fully learned."; }
				else if (!parentsOk) { buyable = false; why = "Needs " + Join(parents) + " first."; }
				else if (pool <= 0) { buyable = false; why = "No perk points available."; }

				result[0] = BSFixedString("1");
				result[1] = Fixed(PerkName(node->perk));
				result[2] = Fixed(PerkDescription(ranks.current));
				result[3] = Fixed(Int(ranks.owned));
				result[4] = Fixed(Int(ranks.total));
				result[5] = BSFixedString(buyable ? "1" : "0");
				result[6] = Fixed(why);
				result[7] = Fixed(Join(parents));
				result[8] = Fixed(Join(children));
				result[9] = Fixed(TreeName(info));
				result[10] = Fixed(Int(pool));
				result[11] = Fixed(Int((int)treeAV));
				result[12] = BSFixedString(parentsOk ? "1" : "0");
				return result;
			}
		}
		return result;
	}

	// Names of perks in a beast tree. treeAV: 158, 159 or 0 for both. mode: 0 buyable now,
	// 1 owned (any rank), 2 all. Multi-rank perks carry "rank x of y". points: perk points to assume
	// for "buyable" (the menu's counter), or -1 to read the game's pool.
	VMResultArray<BSFixedString> Papyrus_ListBeastPerks(StaticFunctionTag*, SInt32 treeAV, SInt32 mode, SInt32 points)
	{
		VMResultArray<BSFixedString> result;
		for (UInt32 av : kBeastTrees)
		{
			if (treeAV != 0 && (SInt32)av != treeAV) continue;
			int pool = (points >= 0) ? points : PerkPool(av);
			for (BGSSkillPerkTreeNode* node : TreeNodes(av))
			{
				if (!node->perk) continue;
				Ranks ranks = GetRanks(node->perk);
				bool include;
				if (mode == 1)
					include = ranks.owned > 0;
				else if (mode == 0)
				{
					std::vector<std::string> parents;
					include = ranks.owned < ranks.total && ParentsSatisfied(node, parents) && pool > 0;
				}
				else
					include = true;
				if (!include) continue;

				std::string entry = PerkName(node->perk);
				if (ranks.total > 1)
					entry += ", rank " + Int(ranks.owned) + " of " + Int(ranks.total);
				result.push_back(Fixed(entry));
			}
		}
		return result;
	}
}

namespace BeastPerks
{
	void RegisterPapyrus(VMClassRegistry* registry, const char* papyrusClass)
	{
		registry->RegisterFunction(new NativeFunction1<StaticFunctionTag, VMResultArray<BSFixedString>, BSFixedString>("DescribeBeastPerk", papyrusClass, Papyrus_DescribeBeastPerk, registry));
		registry->RegisterFunction(new NativeFunction3<StaticFunctionTag, VMResultArray<BSFixedString>, SInt32, SInt32, SInt32>("ListBeastPerks", papyrusClass, Papyrus_ListBeastPerks, registry));
		_MESSAGE("beast perk tree functions registered on %s", papyrusClass);
	}
}
