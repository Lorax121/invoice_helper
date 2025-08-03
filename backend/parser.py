import sys
import os
import argparse
import json
import re
import logging
from typing import Optional, Dict, Any

# Настройка логирования ДО импорта dedoc
logging.basicConfig(level=logging.INFO, stream=sys.stderr, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# Блок для портативного Tesseract
if getattr(sys, 'frozen', False):
    application_path = os.path.dirname(sys.executable)
else:
    application_path = os.path.dirname(os.path.abspath(__file__))

tesseract_path = os.path.join(application_path, 'tesseract')
os.environ['PATH'] += os.pathsep + tesseract_path
os.environ['TESSDATA_PREFIX'] = os.path.join(tesseract_path, 'tessdata')

os.environ['DEDOC_MODES'] = "['line_classifier', 'paragraph_classifier', 'structure_extractor', 'table_recognizer']"

# Импорт после настройки
from dedoc import DedocManager
import pandas as pd
from dedoc.data_structures import Table

# Константы
CELL_NUMBER_PATTERN = re.compile(r"^\s*(\d{1,3}[а-я]?)\s*$")
MIN_SEQUENTIAL_CELLS = 3

def find_numbering_row(df: pd.DataFrame) -> Optional[int]:
    rows_to_check = max(1, len(df) // 2)
    for index, row in df.head(rows_to_check).iterrows():
        current_sequence = 0
        for cell_text in [str(cell).strip() for cell in row.tolist()]:
            if CELL_NUMBER_PATTERN.match(cell_text):
                current_sequence += 1
            elif current_sequence > 0:
                if current_sequence >= MIN_SEQUENTIAL_CELLS: break
                else: current_sequence = 0
        if current_sequence >= MIN_SEQUENTIAL_CELLS: return index
    return None

def convert_dedoc_table_to_df(table: Table) -> pd.DataFrame:
    return pd.DataFrame([[cell.get_text() for cell in row] for row in table.cells])

def find_and_process_tables(file_path: str) -> Optional[str]:
    original_stdout = sys.stdout
    try:
        sys.stdout = sys.stderr
        manager = DedocManager()
        parameters = {"pdf_with_text_layer": "auto_tabby", "pages": ":"}
        result = manager.parse(file_path=file_path, parameters=parameters)
    except Exception as e:
        logging.error(f"Dedoc manager error: {e}")
        return None
    finally:
        sys.stdout = original_stdout

    all_tables = result.content.tables
    if not all_tables: return None

    main_table_dfs = []
    main_table_column_count = 0
    pattern_row = []
    column_names = []
    
    first_table_found = False
    table_index_after_first_found = 0

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
            break
            
    if not first_table_found: return None

    for table in all_tables[table_index_after_first_found:]:
        df = convert_dedoc_table_to_df(table)
        if len(df.columns) == main_table_column_count:
            data_df = df.copy()
            data_df.columns = column_names
            main_table_dfs.append(data_df)

    if not main_table_dfs: return None

    final_df = pd.concat(main_table_dfs, ignore_index=True)
    
    final_json_structure: Dict[str, Any] = {
        "patternRow": pattern_row,
        "columnNames": column_names,
        "dataRows": final_df.to_dict(orient='records')
    }
    
    return json.dumps(final_json_structure, ensure_ascii=False)


def main():
    parser = argparse.ArgumentParser(description="Parse tables from PDF invoices.")
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
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    main()