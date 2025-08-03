# parser.spec (v6 - Оптимизированная версия)
# -*- mode: python ; coding: utf-8 -*-

import os
import sys

# Поиск XGBoost DLL и необходимых файлов
def find_xgboost_files():
    """Находит только необходимые файлы XGBoost"""
    import xgboost
    xgboost_path = os.path.dirname(xgboost.__file__)
    
    # Ищем DLL
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
    
    # Ищем VERSION файл
    version_file = os.path.join(xgboost_path, 'VERSION')
    if not os.path.exists(version_file):
        # Создаем временный VERSION файл
        version_file = None
    
    return dll_path, version_file, xgboost_path

xgboost_dll, version_file, xgboost_pkg_path = find_xgboost_files()

block_cipher = None

# Подготавливаем данные для XGBoost
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
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='parser',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)