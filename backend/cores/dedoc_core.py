
import sys
import json
import re
import logging
import os 
from typing import Optional, Dict, Any, List

import pandas as pd
from dedoc import DedocManager
from dedoc.data_structures import Table, ParsedDocument

from cores.base import AbstractCore
from .dedoc_pdf_prepare import preprocess_pdf_for_dedoc 

CELL_NUMBER_PATTERN = re.compile(r"^\s*(\d{1,3}[а-я]?)\s*$")
MIN_SEQUENTIAL_CELLS = 3

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
    """Вспомогательная функция для запуска парсинга dedoc."""
    original_stdout = sys.stdout
    try:
        sys.stdout = sys.stderr
        manager = DedocManager()
        logging.info(f"Dedoc: Attempting to parse with parameters: {parameters}")
        result = manager.parse(file_path=file_path, parameters=parameters)
        return result
    except Exception as e:
        logging.error(f"Dedoc manager error with params {parameters}: {e}")
        return None
    finally:
        sys.stdout = original_stdout


class DedocCore(AbstractCore):
    def process(self, file_path: str, preprocess_pdf: bool = False) -> Optional[str]:
        """
        Основная функция ядра dedoc: ищет, обрабатывает и объединяет таблицы.
        """
        path_to_process = file_path
        temp_file_to_clean = None

        if preprocess_pdf and file_path.lower().endswith(".pdf"):
            logging.info("Preprocessing PDF enabled. Starting line cleaning process...")
            try:
                temp_file_to_clean = preprocess_pdf_for_dedoc(file_path)
                if temp_file_to_clean:
                    path_to_process = temp_file_to_clean
                    logging.info(f"PDF preprocessed and saved to temporary file: {path_to_process}")
                else:
                    logging.warning("PDF preprocessing returned no file. Falling back to original.")
            except Exception as e:
                logging.error(f"Error during PDF preprocessing: {e}. Falling back to original file.")
        
        try: 
            dedoc_parameter_sets = [
                {"pdf_with_text_layer": "auto_tabby", "pages": ":"},
                {"pdf_with_text_layer": "auto_tabby", "pages": ":", "need_gost_frame_analysis": "true"},
            ]
            
            result = None
            for params in dedoc_parameter_sets:
                parsed_doc = _run_dedoc_parse(path_to_process, params)
                if parsed_doc and parsed_doc.content and parsed_doc.content.tables:
                    for table in parsed_doc.content.tables:
                        df_check = convert_dedoc_table_to_df(table)
                        if find_numbering_row(df_check) is not None:
                            result = parsed_doc
                            logging.info(f"Dedoc: Successfully found a potential main table with params: {params}")
                            break
                if result:
                    break

            if not result or not result.content or not result.content.tables:
                logging.error("Dedoc: No tables found in the document after all attempts.")
                return None
        

            all_tables = result.content.tables

            main_table_dfs = []
            main_table_column_count = 0
            pattern_row: List[str] = []
            column_names: List[str] = []
            
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
                    logging.info(f"Dedoc: Main table found at index {table_index} with {main_table_column_count} columns.")
                    break
                    
            if not first_table_found:
                logging.warning("Dedoc: Could not find the main table with a numbering row.")
                return None

            for table in all_tables[table_index_after_first_found:]:
                df = convert_dedoc_table_to_df(table)
                
                if len(df.columns) != main_table_column_count:
                    continue

                numbering_row_index = find_numbering_row(df)

                if numbering_row_index is not None:
                    data_df = df.iloc[numbering_row_index + 1:].copy()
                    logging.info("Dedoc: Found a continuation table with a repeated header.")
                else:
                    data_df = df.copy()
                    logging.info("Dedoc: Found a continuation table without a header.")

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

        finally:
            if temp_file_to_clean and os.path.exists(temp_file_to_clean):
                try:
                    os.remove(temp_file_to_clean)
                    logging.info(f"Cleaned up temporary file: {temp_file_to_clean}")
                except OSError as e:
                    logging.error(f"Error removing temporary file {temp_file_to_clean}: {e}")