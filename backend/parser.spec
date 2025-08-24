# parser.spec (v7 - Модульная архитектура с ядрами)
# -*- mode: python ; coding: utf-8 -*-

import os
import sys

# ... (ваш код для поиска XGBoost DLL остается без изменений) ...
def find_xgboost_files():
    """Находит только необходимые файлы XGBoost"""
    import xgboost
    xgboost_path = os.path.dirname(xgboost.__file__)
    
    possible_dll_paths = [
        os.path.join(xgboost_path, 'lib', 'xgboost.dll'),
        os.path.join(xgboost_path, '..', '..', 'lib', 'xgboost.dll'),
        os.path.join(xgboost_path, 'windows', 'x64', 'Release', 'xgboost.dll'),
    ]
    
    dll_path = None
    for path in possible_dll_paths:
        path = os.path.normpath(path)
        if os.path.exists(path):
            dll_path = path
            break
    
    if not dll_path:
        raise FileNotFoundError(f"XGBoost DLL not found in: {possible_dll_paths}")
    
    version_file = os.path.join(xgboost_path, 'VERSION')
    if not os.path.exists(version_file):
        version_file = None
    
    return dll_path, version_file, xgboost_path

xgboost_dll, version_file, xgboost_pkg_path = find_xgboost_files()

block_cipher = None

xgboost_datas = []
if version_file:
    xgboost_datas.append((version_file, 'xgboost/'))

a = Analysis(
    ['parser.py'],
    pathex=[],
    binaries=[
        (xgboost_dll, 'xgboost/lib/'),
    ],
    datas=xgboost_datas,
    hiddenimports=[
        'encodings',
        'encodings.utf_8',
        'encodings.cp1251',
        'encodings.ascii',
        'xgboost.core',
        'xgboost.libpath',
        'pkg_resources.py2_warn',
        'camelot',
        'camelot.parsers',
        'camelot.handlers',
        'pandas',
        'cv2',
    ],
    hookspath=['hooks'],
    runtime_hooks=['hooks/rthook_xgboost.py'],
    hooksconfig={},
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True, # Исключаем бинарники из .exe
    name='parser',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

# Новый блок COLLECT, который собирает все в одну папку
coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='parser', # Имя итоговой папки
)