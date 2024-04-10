def process_line(line):
    try:
        # 尝试分割每一行的字段
        chinese, code, short_code = line.strip().split('\t')
    except ValueError:
        # 分割失败，将这一行输出到 error.txt 文件中
        with open('error.txt', 'a', encoding='utf-8') as error_file:
            error_file.write(line)
        return None
    
    # 特殊情况：简码的最后一个字母是 v，直接挪用编码
    if short_code[-1] == 'v':
        # new_code = code
        with open('one.txt', 'a', encoding='utf-8') as new_one_file:
            new_one_file.write(f"{chinese}\t{code}\n")
        return None
    else:
        # 在编码中找到简码的最后一个字母最后一次出现的地方，在这个字母前加一个空格
        last_index = code.rfind(short_code[-1])
        if last_index == len(code) - 1 and short_code[-1] in ['g', 'n']:
            last_index = code.rfind(short_code[-1], 0, len(code) - 1)
        new_code = f"{code[:last_index]} {code[last_index:]}"

    # 生成新的行内容
    new_line = f"{chinese}\t{new_code}"

    return new_line

def generate_new_file(input_file, output_file):
    # 在每次运行前清空 error.txt 文件
    with open('error.txt', 'w', encoding='utf-8'):
        pass

    with open(input_file, 'r', encoding='utf-8') as infile, open(output_file, 'w', encoding='utf-8') as outfile:
        for line in infile:
            new_line = process_line(line)
            if new_line is not None:
                outfile.write(new_line + '\n')

# 主程序
generate_new_file('full.txt', 'lf.txt')
