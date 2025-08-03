# hooks/hook-parser.py
hiddenimports = [
    # Базовые кодировки
    'encodings',
    'encodings.utf_8', 
    'encodings.cp1251',
    'encodings.ascii',
    
    # Минимум для pandas
    'pandas._libs.tslibs.base',
    'pandas._libs.tslibs.nattype',
    
    # Минимум для dedoc
    'pkg_resources.py2_warn',
    'six.moves',
]