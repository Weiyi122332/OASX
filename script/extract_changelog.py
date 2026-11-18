import os
from pathlib import Path


os.chdir(os.path.join(os.path.dirname(__file__), '../'))
print(os.getcwd())


if __name__ == '__main__':
    change_latest: str = ''
    with open('./CHANGELOG.md', 'r', encoding='utf-8') as file:
        log = file.read()
        start_index = log.find('# v')
        if start_index < 0:
            raise ValueError('CHANGELOG.md 缺少版本标题')
        end_index = log.find('\n# v', start_index + 1)
        section = log[start_index:] if end_index < 0 else log[start_index:end_index]
        change_latest = section.rstrip() + '\n'

    print(change_latest)
    with open('CHANGELATEST.md', 'w', encoding='utf-8', newline='\n') as file:
        file.write(change_latest)
    
