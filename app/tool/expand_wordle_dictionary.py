"""Rebuild the offline five-letter lexicon using the original Hunspell affixes.

Source: https://github.com/wooorm/dictionaries/tree/main/dictionaries/es
Dictionary license: MPL-1.1 or later (see assets/wordle_dictionary_license.txt).
The generated list is a derivative dictionary, not a new answer pool.
"""
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
AFF_URL = 'https://raw.githubusercontent.com/wooorm/dictionaries/main/dictionaries/es/index.aff'

def normalize(word):
    return word.upper().translate(str.maketrans('ÁÉÍÓÚÜ', 'AEIOUU'))

def build(aff, dictionaries):
    rules = {}
    for line in aff.splitlines():
        bits = line.split()
        if len(bits) < 5 or bits[0] not in ('PFX', 'SFX'):
            continue
        kind, flag, strip, add, condition = bits[:5]
        add, _, continuation = add.partition('/')
        rules.setdefault(flag, []).append((kind, '' if strip == '0' else strip,
            '' if add == '0' else add, continuation,
            re.compile(('^' if kind == 'PFX' else '') + condition + ('$' if kind == 'SFX' else ''))))
    words = set()
    def include(word):
        normalized = normalize(word)
        if re.fullmatch('[A-ZÑ]{5}', normalized):
            words.add(normalized)
    def apply(word, flags, depth, suffix_only=False):
        include(word)
        if depth == 0: return
        for flag in flags:
            for kind, strip, add, continuation, condition in rules.get(flag, []):
                if suffix_only and kind != "SFX": continue
                if not condition.search(word): continue
                if kind == 'PFX':
                    if strip and not word.startswith(strip): continue
                    derived = add + word[len(strip):]
                else:
                    if strip and not word.endswith(strip): continue
                    derived = (word[:-len(strip)] if strip else word) + add
                # Continuation flags encode plural/conjugation chains explicitly.
                apply(derived, continuation, depth - 1)
    for dictionary in dictionaries:
        for line in dictionary.splitlines():
            word, _, flags = line.split()[0].partition('/') if line.strip() else ('', '', '')
            if len(word) <= 14:
                apply(word, flags, 3)
                # Hunspell cross product: prefix + suffix on the same root.
                for flag in flags:
                    for kind, strip, add, continuation, condition in rules.get(flag, []):
                        if kind == 'PFX' and condition.search(word) and (not strip or word.startswith(strip)):
                            apply(add + word[len(strip):], flags + continuation, 2, suffix_only=True)
    return words

if __name__ == '__main__':
    aff = urllib.request.urlopen(AFF_URL).read().decode('utf-8')
    raw = [(ROOT/'assets'/name).read_text('utf-8') for name in ('wordle_es.dic', 'wordle_cl.dic')]
    words = build(aff, raw)
    required = {'CASAS', 'NIÑAS', 'NIÑOS', 'PERAS', 'GATAS', 'GATOS', 'COMES', 'BEBES', 'REZAR'}
    assert required <= words, required - words
    (ROOT/'assets/wordle_expanded.txt').write_text('\n'.join(sorted(words)) + '\n', 'utf-8')
    print(f'{len(words)} five-letter guesses generated from Hunspell rules.')
