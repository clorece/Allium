import re, collections
BP = "/mnt/c/Users/clare/AppData/Roaming/ModrinthApp/profiles/shader dev/shaderpacks/SerieVX/shaders/block.properties"
raw = open(BP, encoding='utf-8').read()

TABLE = [
    ('cut_copper','1'),('copper','1'),('iron','1'),('gold','1'),('netherite','1'),
    ('anvil','1'),('hopper','1'),('cauldron','1'),('grindstone','1'),('chain','1'),
    ('lightning_rod','1'),('bell','1'),('brewing','1'),
    ('raw_iron','2'),('raw_gold','2'),('raw_copper','2'),
    ('polished_blackstone','6'),('blackstone','6'),('polished_deepslate','6'),
    ('deepslate_brick','6'),('deepslate_tile','6'),('deepslate','6'),('obsidian','6'),
    ('nether_brick','6'),('red_nether_brick','6'),
    ('quartz','4'),('diamond','5'),('emerald','5'),('amethyst','5'),('prismarine','7'),
    ('glazed_terracotta','8'),
    ('polished_granite','3'),('polished_diorite','3'),('polished_andesite','3'),
    ('polished_tuff','3'),('tuff_brick','3'),('smooth_stone','3'),('smooth_sandstone','3'),
    ('smooth_red_sandstone','3'),('polished_basalt','3'),('smooth_basalt','3'),
    ('calcite','3'),('dripstone','3'),('purpur','3'),
    ('stone_brick','11'),('mossy_stone_brick','11'),('mud_brick','11'),('brick','11'),
    ('end_stone_brick','11'),('resin_brick','11'),
    ('concrete','9'),('glazed','8'),('terracotta','10'),('wool','16'),('carpet','16'),
    ('cobbled_deepslate','12'),('cobblestone','12'),('mossy_cobblestone','12'),
    ('andesite','12'),('granite','12'),('diorite','12'),('basalt','12'),('tuff','12'),
    ('cut_sandstone','12'),('cut_red_sandstone','12'),('sandstone','12'),('red_sandstone','12'),
    ('end_stone','12'),('stonecutter','12'),
    # easy single-material wins
    ('snow','15'),('ladder','13'),('scaffolding','13'),('composter','13'),
    ('grass_path','14'),('_bed','16'),
    ('flower_pot','10'),('decorated_pot','10'),('potted','10'),
    ('stone','12'),
    ('stripped','13'),('planks','13'),('_log','13'),('_wood','13'),('_stem','13'),
    ('_hyphae','13'),('bamboo','13'),('chest','13'),('lectern','13'),('barrel','13'),
    ('petrified_oak','13'),('wooden','13'),
    ('oak','13'),('spruce','13'),('birch','13'),('jungle','13'),('acacia','13'),
    ('mangrove','13'),('cherry','13'),('crimson','13'),('warped','13'),('pale_oak','13'),
    ('dirt_path','14'),('farmland','14'),('coarse_dirt','14'),('podzol','14'),
    ('mycelium','14'),('rooted_dirt','14'),('mud','14'),('dirt','14'),
    ('red_sand','15'),('gravel','15'),('sand','15'),
]
def classify(tok):
    name = tok.split(':')[0]
    for sub,cls in TABLE:
        if sub in name: return cls
    return None

# match a full (possibly multi-line) block.200xx entry
pat = re.compile(r'^block\.(200\d\d)[ \t]*=[ \t]*((?:[^\n\\]*\\\n)*[^\n]*)\n', re.M)

usage = collections.Counter()   # (class,shape) just to count
genlines_total = 0
def repl(m):
    global genlines_total
    sid = int(m.group(1)) - 20000
    body = m.group(2).replace('\\\n',' ')
    toks = body.split()
    groups = collections.defaultdict(list)
    for t in toks:
        c = classify(t) or 'GEN'
        groups[c].append(t)
    out = []
    # leftover generic tokens stay in the original 20xxx id
    if 'GEN' in groups:
        out.append(f"block.{20000+sid} = " + ' '.join(groups['GEN']))
    # per-material packed ids 30000 + class*100 + shape
    for c in sorted((k for k in groups if k!='GEN'), key=int):
        nid = 30000 + int(c)*100 + sid
        usage[(int(c),sid)] += 1
        out.append(f"block.{nid} = " + ' '.join(groups[c]))
        global_ids.add(nid)
    genlines_total += len(out)
    return '\n'.join(out) + '\n'

global_ids=set()
new = pat.sub(repl, raw)
open("/mnt/c/Users/clare/AppData/Roaming/ModrinthApp/profiles/shader dev/shaderpacks/SerieVX/shaders/block.properties.new",'w',encoding='utf-8').write(new)

classes = sorted({c for c,s in usage})
print("classes used in 30xxx:", classes)
print("total 30xxx ids emitted:", len(global_ids))
print("id range:", min(global_ids), "-", max(global_ids))
print("output lines (gen+packed):", genlines_total)
# sanity: collisions with existing ranges?
bad = [i for i in global_ids if not (30101 <= i <= 31666)]
print("out-of-range ids:", bad)
