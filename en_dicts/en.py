import re
import os

def sort_by_length_and_alpha(words):
    # 使用 sorted() 函数对列表进行排序
    unique_words = list(set(words))
    non_empty_words = [word for word in unique_words if word.strip()]
    sorted_words = sorted(non_empty_words, key=lambda x: (len(x), x))
    return sorted_words

if os.path.exists('en.txt'):
    # 定义空列表，用于存储各个单词表
    en_a = []
    en_b = []
    en_c = []
    en_d = []

    header_info = """---
name: main
version: "1.0"
sort: original
...
"""
    with open('main.dict.yaml', 'a+') as f:
        # 将文件指针移动到文件开头
        f.seek(0)
        # 清空文件内容
        f.truncate()

    # 读取文件 en.txt，并按行处理
    with open('en.txt', 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip()  # 去除行尾空格
            en_a.append(word)

    with open('en.txt', 'a+') as f:
        # 将文件指针移动到文件开头
        f.seek(0)
        # 清空文件内容
        f.truncate()

    en_a = sort_by_length_and_alpha(en_a)

    # 遍历 en_a 表，并处理单词
    with open('en.txt', 'w', encoding='utf-8') as f:
        for word in en_a:
            f.write(word + '\n')
            lower_en = word.lower()
            cap_en = word[0].upper() + word[1:]
            upper_en = word.upper()

            # 将单词小写，并加入 en_b 表
            if lower_en != word and lower_en not in en_a and lower_en not in en_b:
                en_b.append(lower_en)

            # 如果单词首字母大写不是单词本身，也不在 en_a 表中
            if cap_en != word and cap_en != lower_en and cap_en not in en_a and cap_en not in en_c:
            # if cap_en != word and cap_en != lower_en:
                # 将单词首字母大写，并加入 en_c 表
                en_c.append(cap_en)

            if upper_en !=word and upper_en != lower_en and upper_en != cap_en and upper_en not in en_a and upper_en not in en_c and upper_en not in en_d:
                # 将单词全大写，并加入 en_d 表
                en_d.append(upper_en)

    with open('main.dict.yaml', 'w', encoding='utf-8') as f:
        f.write(header_info)
        for word in en_a:
            clean_word = re.sub(r'\s+', '', word)
            f.write(word + '\t' + clean_word + '\n')
        f.write('\n\n' + '# word.lower' + '\n\n' )
        for word in en_b:
            clean_word = re.sub(r'\s+', '', word)
            f.write(word + '\t' + clean_word + '\n')
        f.write('\n\n' + '# word.capitalize' + '\n\n' )
        for word in en_c:
            clean_word = re.sub(r'\s+', '', word)
            f.write(word + '\t' + clean_word + '\n')
        f.write('\n\n' + '# word.upper' + '\n\n' )
        for word in en_d:
            clean_word = re.sub(r'\s+', '', word)
            f.write(word + '\t' + clean_word + '\n')

if os.path.exists('term.txt'):
    # 定义空列表，用于存储各个单词表
    en_a = []

    header_info = """---
name: term
version: "1.0"
sort: original
...
"""
    with open('term.dict.yaml', 'a+') as f:
        # 将文件指针移动到文件开头
        f.seek(0)
        # 清空文件内容
        f.truncate()

    # 读取文件 term.txt，并按行处理
    with open('term.txt', 'r', encoding='utf-8') as f:
        for line in f:
            word = line.strip()  # 去除行尾空格
            en_a.append(word)

    with open('term.txt', 'a+') as f:
        # 将文件指针移动到文件开头
        f.seek(0)
        # 清空文件内容
        f.truncate()

    en_a = sort_by_length_and_alpha(en_a)
    
    with open('term.txt', 'w', encoding='utf-8') as f:
        for word in en_a:
            f.write(word + '\n')
    
    with open('term.dict.yaml', 'w', encoding='utf-8') as f:
        f.write(header_info)
        for word in en_a:
            clean_word = re.sub(r'\s+', '', word)
            f.write(word + '\t' + clean_word + '\n')
