# hooks/hook-xgboost.py
import os
from PyInstaller.utils.hooks import get_package_paths

# Получаем путь к XGBoost
try:
    _, xgboost_path = get_package_paths('xgboost')
    
    # Добавляем только VERSION файл если он существует
    datas = []
    version_file = os.path.join(xgboost_path, 'VERSION')
    if os.path.exists(version_file):
        datas = [(version_file, 'xgboost')]
    
    # Минимальные скрытые импорты
    hiddenimports = [
        'xgboost.core',
        'xgboost.libpath',
    ]
    
    binaries = []
    
except ImportError:
    datas = []
    hiddenimports = []
    binaries = []