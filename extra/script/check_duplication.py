import os
import re

def get_dict_txt(dict_paths, outpath):
    word_set = set()

    with open(outpath, "w" ,encoding='utf-8') as file:
        file.truncate(0)  # This will clear the content of the file

    for dict_path in dict_paths:
        with open(dict_path, 'r', encoding='utf-8') as dict_file:
            for line in dict_file:
                parts = line.strip().split('\t')
                if len(parts) < 1 or parts[0].startswith(('#', '---', '...','- ')) or re.search(r"^\w+: .+$", parts[0]) or parts[0] == '' :
                    continue
                word_set.add(parts[0])

    # Sort and write unique words to temp_dict.txt
    with open(outpath, 'w', encoding='utf-8') as output_file:
        for word in sorted(word_set):
            output_file.write(f"{word}\n")


def process_userdb(userdb_path, match_path, outpath="temp_userdb.txt"):
    # Read content from the provided dictionary path
    with open(match_path, 'r', encoding='utf-8') as dict_file:
        dict_content = {line.strip().lower() for line in dict_file}

    with open(outpath, "w" ,encoding='utf-8') as file:
        file.truncate(0)  # This will clear the content of the file

    with open(userdb_path, 'r', encoding='utf-8') as userdb_file:
        for line in userdb_file:
            parts = line.strip().split('\t')
            if len(parts) < 3:
                continue
            cand_code, cand_text = parts[0].rstrip(), parts[1]
            c_value = parts[2].split('=')[1]
            if c_value.startswith('-'):
                continue
            # Check if cand_text is in the dictionary content
            if cand_text.lower() in dict_content:
                continue
            with open(outpath, 'a', encoding='utf-8') as output_file:
                output_file.write(f"{cand_text}\t{cand_code}\n")

def process_dict(dict_path, match_path, outpath="temp_dict.txt"):
    # Read content from the provided dictionary path
    with open(match_path, 'r', encoding='utf-8') as dict_file:
        dict_content = {line.strip().lower() for line in dict_file}

    with open(outpath, "w" ,encoding='utf-8') as file:
        file.truncate(0)  # This will clear the content of the file

    with open(dict_path, 'r', encoding='utf-8') as dict_file:
        for line in dict_file:
            parts = line.strip().split('\t')
            if len(parts) < 1 or parts[0].startswith(('#', '---', '...','- ')) or re.search(r"^\w+: .+$", parts[0]) or parts[0] == '' :
                continue
            if parts[0] in dict_content:
                continue
            with open(outpath, 'a', encoding='utf-8') as output_file:
                output_file.write(line)


# 生成英文词典的所有词汇
def gen_en ():
    dict_paths = ["en_dicts/main.dict.yaml", "en_dicts/special.dict.yaml","en_user.dict.yaml"]
    get_dict_txt(dict_paths,"temp_en.txt")

## 检查英文词典的独有词汇
def check_en_db():
    userdb_path = "sync/Windows/en.userdb.txt"
    dict_path = "temp_en.txt"
    process_userdb(userdb_path, dict_path, "temp_en_usedb.txt")

## 生成中文词典的所有词
def gen_cn():
    dict_paths = ["cn_dicts/8105.dict.yaml", "cn_dicts/han.dict.yaml","cn_dicts/special.dict.yaml","cn_user.dict.yaml","cn_dicts/base.dict.yaml","cn_dicts/ext.dict.yaml","cn_dicts/tencent.dict.yaml","cn_dicts/others.dict.yaml","cn_dicts/name.dict.yaml", 'cn_dicts/classical.dict.yaml']
    get_dict_txt(dict_paths,"temp_cn.txt")

## 检查中文用户词典的独有词汇
def check_cn_db():
    userdb_path = "sync/Windows/cn.userdb.txt"
    dict_path = "temp_cn.txt"
    process_userdb(userdb_path, dict_path, "temp_cn_usedb.txt")

## 检查导入的词典是否和已有的词典冲突

gen_cn()
gen_en()
check_cn_db()
check_en_db()
# process_dict("dict_cn_name.dict.yaml","temp_cn.txt")


