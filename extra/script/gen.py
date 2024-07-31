# 本脚本从此项目衍生 https://github.com/maxchang3/rime-chaizi (MIT
"""
pypinyin -> get pinyin
pypinyin_dict -> load custom pinyin data
"""
from datetime import datetime
from pypinyin import pinyin, load_phrases_dict, Style, lazy_pinyin

radical = []
yaml = set()

header = f'''---
name: special
version: "{datetime.now().strftime("%Y.%m.%d")}"
sort: original
...\n\n'''

def is_not_empty(s):
    "pinyin should not be null or empty"
    return s is not None and s.strip() != ''

with open("emoji.txt", 'r', encoding='utf-8' ) as f:
    radical = f.readlines()

for line in radical:
    line = line.strip()

    if len(line) == 0 or line.startswith("#"):
        yaml.add(line)
        continue

    units, chars  = line.split('\t', 1)
    pinyin_str = lazy_pinyin(units, style=Style.NORMAL)
    for char in chars.split('\t'):
        item = f"{char.strip()}\t{"'".join(pinyin_str)}"
        yaml.add(item)

sorted_yaml = sorted(yaml,reverse=True)

with open("dict.yaml","w",encoding='utf-8') as f:
    f.write("\n".join(sorted_yaml) + '\n\n')
