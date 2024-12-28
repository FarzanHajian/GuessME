# GuessME
#
#
# This file is a part of the GuessME 1.0 source code and is published under BSD 3-Clause License.
# Visit https://github.com/FarzanHajian/GuessME/blob/main/LICENSE for details.


result = ''
with open('./ascii.txt', mode='rt') as f:
    while (line := f.readline()) != '':
        if line == '':
            break
        lst = [(hex(ord('\r'))+', ' if c == '\n' else '') +
               hex(ord(c)) for c in line]
        result += ', \ndb ' + ', '.join(lst)

result = result.replace(', \n', '', 1)
with open ('./ascii_result.txt', mode='tw') as f:
    f.write(result)

