import sys
import os
import argparse
import json
import re
import logging
from typing import Optional, Dict, Any, List

# ==============================================================================
# НАСТРОЙКА ОКРУЖЕНИЯ ДЛЯ ПОРТАТИВНОЙ СБОРКИ
# ==============================================================================

# Настройка логирования ДО импорта dedoc
logging.basicConfig(level=logging.INFO, stream=sys.stderr, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Определяем базовый путь приложения (работает и для .py, и для .exe)
if getattr(sys, 'frozen', False):
    # Если приложение "заморожено" (скомпилировано в .exe)
    application_path = os.path.dirname(sys.executable)
else:
    # Если запускается как обычный .py скрипт
    application_path = os.path.dirname(os.path.abspath(__file__))

# --- Блок для портативного Tesseract ---
tesseract_path = os.path.join(application_path, 'tesseract')
if os.path.exists(tesseract_path):
    os.environ['PATH'] += os.pathsep + tesseract_path
    os.environ['TESSDATA_PREFIX'] = os.path.join(tesseract_path, 'tessdata')
    logging.info(f"Tesseract path set to: {tesseract_path}")

# --- БЛОК для портативного Poppler ---
poppler_bin_path = None
# Ищем папку, которая начинается с "poppler-"
for item in os.listdir(application_path):
    item_path = os.path.join(application_path, item)
    if os.path.isdir(item_path) and item.startswith("poppler-"):
        potential_path = os.path.join(item_path, 'Library', 'bin')
        if os.path.exists(potential_path):
            poppler_bin_path = potential_path
            break

if poppler_bin_path:
    os.environ['PATH'] += os.pathsep + poppler_bin_path
    logging.info(f"Poppler path set to: {poppler_bin_path}")
else:
    # Эта ветка сработает, если скрипт сборки не скопировал poppler
    logging.warning("Poppler directory not found next to the executable. PDF parsing might fail.")

# Установка переменных для dedoc
os.environ['DEDOC_MODES'] = "['line_classifier', 'paragraph_classifier', 'structure_extractor', 'table_recognizer']"

# Импорт после настройки
from dedoc import DedocManager
from dedoc.data_structures import Table, ParsedDocument
import pandas as pd

# Константы
CELL_NUMBER_PATTERN = re.compile(r"^\s*(\d{1,3}[а-я]?)\s*$")
MIN_SEQUENTIAL_CELLS = 3

# Функции find_numbering_row и convert_dedoc_table_to_df
def find_numbering_row(df: pd.DataFrame) -> Optional[int]:
    """Ищет индекс строки с нумерацией (1, 2, 3...) по всей таблице."""
    for index, row in df.iterrows():
        current_sequence = 0
        for cell_text in [str(cell).strip() for cell in row.tolist()]:
            if CELL_NUMBER_PATTERN.match(cell_text):
                current_sequence += 1
            elif current_sequence > 0:
                if current_sequence >= MIN_SEQUENTIAL_CELLS:
                    break
                else:
                    current_sequence = 0
        if current_sequence >= MIN_SEQUENTIAL_CELLS:
            return index
    return None

def convert_dedoc_table_to_df(table: Table) -> pd.DataFrame:
    """Конвертирует объект Table из dedoc в pandas DataFrame."""
    return pd.DataFrame([[cell.get_text() for cell in row] for row in table.cells])

def _run_dedoc_parse(file_path: str, parameters: Dict[str, str]) -> Optional[ParsedDocument]:
    """
    Вспомогательная функция для запуска парсинга dedoc с заданными параметрами.
    Изолирует логику перенаправления stdout и обработки ошибок.
    """
    original_stdout = sys.stdout
    try:
        sys.stdout = sys.stderr
        manager = DedocManager()
        logging.info(f"Attempting to parse with parameters: {parameters}")
        result = manager.parse(file_path=file_path, parameters=parameters)
        return result
    except Exception as e:
        logging.error(f"Dedoc manager error with params {parameters}: {e}")
        return None
    finally:
        sys.stdout = original_stdout


def find_and_process_tables(file_path: str) -> Optional[str]:
    """
    Основная функция: ищет, обрабатывает и объединяет таблицы из документа,
    используя несколько попыток с разными параметрами dedoc.
    """
    # --- Логика повторных попыток ---
    dedoc_parameter_sets = [
        {"pdf_with_text_layer": "auto_tabby", "pages": ":"},
        {"pdf_with_text_layer": "auto_tabby", "pages": ":", "need_gost_frame_analysis": "true"},
        {"pdf_with_text_layer": "auto_tabby", "pages": ":", "need_gost_frame_analysis": "true", "need_binarization": "true"}
    ]
    
    result = None
    for params in dedoc_parameter_sets:
        parsed_doc = _run_dedoc_parse(file_path, params)
        if parsed_doc and parsed_doc.content and parsed_doc.content.tables:
            # Проверяем, нашлась ли "основная" таблица с этими параметрами
            for table in parsed_doc.content.tables:
                df_check = convert_dedoc_table_to_df(table)
                if find_numbering_row(df_check) is not None:
                    result = parsed_doc
                    logging.info(f"Successfully found a potential main table with params: {params}")
                    break
        if result:
            break

    if not result or not result.content or not result.content.tables:
        logging.error("No tables found in the document after all attempts.")
        return None

    all_tables = result.content.tables

    main_table_dfs = []
    main_table_column_count = 0
    pattern_row: List[str] = []
    column_names: List[str] = []
    
    first_table_found = False
    table_index_after_first_found = 0

    # Поиск первой ("главной") таблицы с якорем
    for table_index, table in enumerate(all_tables):
        df = convert_dedoc_table_to_df(table)
        numbering_row_index = find_numbering_row(df)
        
        if numbering_row_index is not None and numbering_row_index > 0:
            main_table_column_count = len(df.columns)
            
            pattern_row_series = df.iloc[numbering_row_index]
            header_row_series = df.iloc[numbering_row_index - 1]
            
            pattern_row = [str(cell).strip() for cell in pattern_row_series]
            column_names = [str(name).strip().replace("\n", " ") for name in header_row_series]

            if len(pattern_row) > len(column_names):
                pattern_row = pattern_row[:len(column_names)]
            while len(pattern_row) < len(column_names):
                pattern_row.append("")
            
            data_df = df.iloc[numbering_row_index + 1:].copy()
            data_df.columns = column_names
            main_table_dfs.append(data_df)
            
            first_table_found = True
            table_index_after_first_found = table_index + 1
            logging.info(f"Main table found at index {table_index} with {main_table_column_count} columns.")
            break
            
    if not first_table_found:
        logging.warning("Could not find the main table with a numbering row.")
        return None

    # --- логика поиска продолжения таблицы ---
    for table in all_tables[table_index_after_first_found:]:
        df = convert_dedoc_table_to_df(table)
        
        # Фильтруем таблицы, не совпадающие по количеству столбцов
        if len(df.columns) != main_table_column_count:
            continue

        # Проверяем, есть ли в таблице-продолжении свой заголовок (якорная строка)
        numbering_row_index = find_numbering_row(df)

        if numbering_row_index is not None:
            # Если якорь найден, берем данные ПОСЛЕ него
            data_df = df.iloc[numbering_row_index + 1:].copy()
            logging.info("Found a continuation table with a repeated header. Taking data after the header.")
        else:
            # Если якоря нет, берем всю таблицу как есть
            data_df = df.copy()
            logging.info("Found a continuation table without a header. Taking all rows.")

        data_df.columns = column_names
        main_table_dfs.append(data_df)

    if not main_table_dfs:
        return None

    final_df = pd.concat(main_table_dfs, ignore_index=True)
    
    final_json_structure: Dict[str, Any] = {
        "patternRow": pattern_row,
        "columnNames": column_names,
        "dataRows": final_df.to_dict(orient='records')
    }
    
    return json.dumps(final_json_structure, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description="Parse tables from PDF documents.")
    parser.add_argument("--file", type=str, required=True, help="Path to the PDF file to parse.")
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"Error: File not found at {args.file}", file=sys.stderr)
        sys.exit(1)
    
    json_output = find_and_process_tables(args.file)
    
    if json_output:
        print(json_output)
        sys.exit(0)
    else:
        print("Error: Could not find or process the required tables.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    # Устанавливаем кодировку для stdout/stderr для корректного вывода в Windows
    if sys.stdout.encoding != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
    if sys.stderr.encoding != 'utf-8':
        sys.stderr.reconfigure(encoding='utf-8')
    main()