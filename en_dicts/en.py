import re

# 定义空列表，用于存储各个单词表
en_a = []
en_b = []
en_c = []
en_d = []

header_info = """---
name: main
sort: original
...
"""

with open('en.yaml', 'a+') as f:
    # 将文件指针移动到文件开头
    f.seek(0)
    # 清空文件内容
    f.truncate()

# 读取文件 en.txt，并按行处理
with open('en.txt', 'r', encoding='utf-8') as f:
    for line in f:
        word = line.strip()  # 去除行尾空格
        en_a.append(word)

def sort_by_length_and_alpha(words):
    # 使用 sorted() 函数对列表进行排序
    sorted_words = sorted(words, key=lambda x: (len(x), x))
    return sorted_words

en_a = sort_by_length_and_alpha(en_a)

# 遍历 en_a 表，并处理单词
for word in en_a:
    lower_en = word.lower()
    cap_en = word.capitalize()
    upper_en = word.upper()

    # 将单词小写，并加入 en_b 表
    if lower_en != word:
        en_b.append(lower_en)

    if cap_en != word and cap_en != lower_en:
        # 将单词首字母大写，并加入 en_c 表
        en_c.append(cap_en)

    if upper_en !=word and upper_en != lower_en and upper_en != cap_en:
        # 将单词全大写，并加入 en_d 表
        en_d.append(upper_en)

with open('en.yaml', 'w', encoding='utf-8') as f:
    # f.write(header_info)
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