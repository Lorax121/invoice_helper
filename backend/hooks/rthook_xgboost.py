# hooks/rthook_xgboost.py
import os
import sys

if hasattr(sys, '_MEIPASS'):
    # Добавляем путь к XGBoost lib в PATH
    xgboost_lib_path = os.path.join(sys._MEIPASS, 'xgboost', 'lib')
    if os.path.exists(xgboost_lib_path):
        os.environ['PATH'] = xgboost_lib_path + os.pathsep + os.environ.get('PATH', '')
    
    # Создаем VERSION файл если его нет
    version_file = os.path.join(sys._MEIPASS, 'xgboost', 'VERSION')
    if not os.path.exists(version_file):
        # Создаем папку если нужно
        version_dir = os.path.dirname(version_file)
        if not os.path.exists(version_dir):
            os.makedirs(version_dir, exist_ok=True)
        
        # Создаем файл с версией (получаем из самого пакета)
        try:
            import xgboost
            with open(version_file, 'w') as f:
                f.write(xgboost.__version__)
        except:
            # Если не получается, создаем с дефолтной версией
            with open(version_file, 'w') as f:
                f.write('1.7.0')