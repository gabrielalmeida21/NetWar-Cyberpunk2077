"""NET War — converte o README do Nexus (Markdown simples) para BBCode da página de descrição.

Cobre o que o README usa: títulos #/##/###, negrito, links, listas, tabelas (viram listas),
citações, blocos de código, separadores e parágrafos.
Uso: python -I md2bbcode.py nexus/README.md nexus/description.bbcode
"""
import io
import re
import sys


def inline(text):
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'[url=\2]\1[/url]', text)
    text = re.sub(r'\*\*([^*]+)\*\*', r'[b]\1[/b]', text)
    text = re.sub(r'(?<![\w*])\*([^*\n]+)\*(?![\w*])', r'[i]\1[/i]', text)
    text = re.sub(r'`([^`]+)`', r'[font=Courier New]\1[/font]', text)
    return text


def cells(row):
    return [c.strip() for c in row.strip().strip('|').split('|')]


def convert(md):
    out = []
    lines = md.splitlines()
    i = 0
    in_list = False

    def close_list():
        nonlocal in_list
        if in_list:
            out.append('[/list]')
            in_list = False

    while i < len(lines):
        line = lines[i]
        if line.startswith('```'):
            close_list()
            block = []
            i += 1
            while i < len(lines) and not lines[i].startswith('```'):
                block.append(lines[i])
                i += 1
            out.append('[code]' + '\n'.join(block) + '[/code]')
            i += 1
            continue
        if line.startswith('|'):
            close_list()
            header = cells(line)
            i += 2  # pula a linha de separação
            out.append('[list]')
            while i < len(lines) and lines[i].startswith('|'):
                row = cells(lines[i])
                first = inline(row[0])
                rest = ' — '.join(inline(c) for c in row[1:] if c)
                out.append(f'[*][b]{first}[/b]: {rest}' if rest else f'[*]{first}')
                i += 1
            out.append('[/list]')
            continue
        if line.startswith('- '):
            if not in_list:
                out.append('[list]')
                in_list = True
            out.append('[*]' + inline(line[2:]))
            i += 1
            continue
        close_list()
        m = re.match(r'(\d+)\. (.*)', line)
        if m:
            out.append(f'{m.group(1)}. ' + inline(m.group(2)))
        elif line.startswith('### '):
            out.append('[size=4][b]' + inline(line[4:]) + '[/b][/size]')
        elif line.startswith('## '):
            out.append('[size=5][b]' + inline(line[3:]) + '[/b][/size]')
        elif line.startswith('# '):
            out.append('[size=6][b]' + inline(line[2:]) + '[/b][/size]')
        elif line.startswith('> '):
            out.append('[quote]' + inline(line[2:]) + '[/quote]')
        elif line.strip() == '---':
            out.append('[line]')
        else:
            out.append(inline(line))
        i += 1
    close_list()
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    md = io.open(src, encoding='utf-8').read()
    io.open(dst, 'w', encoding='utf-8', newline='\n').write(convert(md))
    print('ok', dst)
