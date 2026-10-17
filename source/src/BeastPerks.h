#pragma once

// Perk-tree lookups for the beast skill trees (Werewolf / Vampire Lord), exposed to Papyrus so the
// beast-tree narration can give the same information as the regular perk reader: rank, description,
// prerequisites, what a perk leads to, whether it can be bought, and the buyable / owned lists.
class VMClassRegistry;

namespace BeastPerks
{
	// Registers AccessSpeech.DescribeBeastPerk and AccessSpeech.ListBeastPerks.
	void RegisterPapyrus(VMClassRegistry* registry, const char* papyrusClass);
}
