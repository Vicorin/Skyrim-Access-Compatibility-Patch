# Generates plugins/BeastPerkTrees/SACP_BeastPerks.esp: a light (ESL-flagged) plugin holding one
# start-game-enabled quest with a player alias that carries the SACP_BeastPerkTree script.
# Layout copied from a Creation Kit-made quest-only plugin (SkyInteract.esp).
import struct, os, sys

AUTHOR = b"Josh"
QUEST_EDID = b"SACP_BeastPerkTreeQuest"
QUEST_FULL = b"Skyrim Access Compatibility Patches: beast perk trees"
ALIAS_SCRIPT = b"SACP_BeastPerkTree"
QUEST_FORMID = 0x01000800   # 01 = this file (one master), 0x800 = first id allowed in a light plugin
RECORD_VERSION = 44


def sub(tag, body):
    return tag + struct.pack('<H', len(body)) + body


def zstr(s):
    return s + b'\0'


def wstr(s):
    return struct.pack('<H', len(s)) + s


def record(tag, flags, formid, body):
    return tag + struct.pack('<IIIHHHH', len(body), flags, formid, 0, 0, RECORD_VERSION, 0) + body


def vmad():
    # version 5, object format 2, no quest-level scripts
    v = struct.pack('<hhH', 5, 2, 0)
    # fragment section: unknown (always 2), fragment file name, fragment count
    v += bytes([2]) + wstr(b'') + struct.pack('<H', 0)
    # one alias with one script, no properties
    v += struct.pack('<H', 1)
    v += struct.pack('<HHI', 0, 0, QUEST_FORMID)      # object: unused, alias id 0, quest form id
    v += struct.pack('<hhH', 5, 2, 1)
    v += wstr(ALIAS_SCRIPT) + bytes([0]) + struct.pack('<H', 0)
    return v


def quest():
    body = sub(b'EDID', zstr(QUEST_EDID))
    body += sub(b'VMAD', vmad())
    body += sub(b'FULL', zstr(QUEST_FULL))
    # flags 0x0111 = Start Game Enabled | Allow repeated stages | Run Once; priority 0; type 0
    body += sub(b'DNAM', struct.pack('<HBBII', 0x0111, 0, 0xFF, 0, 0))
    body += sub(b'NEXT', b'')
    body += sub(b'ANAM', struct.pack('<I', 1))          # next alias id
    body += sub(b'ALST', struct.pack('<I', 0))          # alias 0
    body += sub(b'ALID', zstr(b'PlayerRef'))
    body += sub(b'FNAM', struct.pack('<I', 0))          # alias flags
    body += sub(b'ALFR', struct.pack('<I', 0x14))       # forced reference: PlayerRef
    body += sub(b'VTCK', struct.pack('<I', 0))
    body += sub(b'ALED', b'')
    return record(b'QUST', 0, QUEST_FORMID, body)


def main(out):
    q = quest()
    grup = b'GRUP' + struct.pack('<IIIHHHH', 24 + len(q), 0, 0, 0, 0, 0, 0)
    grup = b'GRUP' + struct.pack('<I', 24 + len(q)) + b'QUST' + struct.pack('<IHHHH', 0, 0, 0, 0, 0) + q
    hdr = sub(b'HEDR', struct.pack('<fII', 1.71, 2, 0x801))
    hdr += sub(b'CNAM', zstr(AUTHOR))
    hdr += sub(b'MAST', zstr(b'Skyrim.esm')) + sub(b'DATA', struct.pack('<Q', 0))
    hdr += sub(b'INTV', struct.pack('<I', 1))
    tes4 = record(b'TES4', 0x200, 0, hdr)             # 0x200 = light plugin (ESL flag)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'wb') as f:
        f.write(tes4 + grup)
    print('wrote', out, len(tes4 + grup), 'bytes')


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, '..', 'plugins', 'BeastPerkTrees', 'SACP_BeastPerks.esp'))
