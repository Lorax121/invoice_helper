
import os
import json
import re
import logging
from typing import Optional, Dict, Any, List

import pandas as pd
import camelot

from camelot.io import read_pdf
from cores.base import AbstractCore

CELL_NUMBER_PATTERN = re.compile(r"^\s*(\d{1,3}[а-я]?)\s*$")
MIN_SEQUENTIAL_CELLS = 3

def find_numbering_row(df: pd.DataFrame) -> Optional[int]:
    """Ищет индекс строки с нумерацией (1, 2, 3...) в DataFrame."""
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

def _clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Очищает DataFrame: заменяет переносы строк на пробелы и убирает лишние пробелы."""
    return df.map(lambda val: val.replace('\n', ' ').strip() if isinstance(val, str) else val)

class CamelotCore(AbstractCore):
    def process(self, file_path: str) -> Optional[str]:
        """
        Основная функция ядра camelot: ищет, обрабатывает и объединяет таблицы.
        """
        if not file_path.lower().endswith('.pdf'):
            logging.error("Camelot: This core only supports .pdf files.")
            raise ValueError("Ядро Camelot поддерживает только файлы формата PDF.")

        try:
            logging.info("Camelot: Reading tables from all pages...")
            tables = read_pdf(file_path, pages='all', flavor='lattice', line_scale=40)
            logging.info(f"Camelot: Found {len(tables)} table(s) in total.")
        except Exception as e:
            logging.error(f"Camelot: Failed to read PDF file: {e}")
            return None
        
        if not tables:
            logging.error("Camelot: No tables found in the document.")
            return None

        all_dataframes = [_clean_dataframe(table.df) for table in tables]
        
        main_table_dfs = []
        main_table_column_count = 0
        pattern_row: List[str] = []
        column_names: List[str] = []
        
        first_table_found = False
        table_index_after_first_found = 0

        for table_index, df in enumerate(all_dataframes):
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
                logging.info(f"Camelot: Main table found at index {table_index} with {main_table_column_count} columns.")
                break
                
        if not first_table_found:
            logging.warning("Camelot: Could not find the main table with a numbering row.")
            return None

        for df in all_dataframes[table_index_after_first_found:]:
            if len(df.columns) != main_table_column_count:
                continue

            numbering_row_index = find_numbering_row(df)

            if numbering_row_index is not None:
                data_df = df.iloc[numbering_row_index + 1:].copy()
                logging.info("Camelot: Found a continuation table with a repeated header.")
            else:
                data_df = df.copy()
                logging.info("Camelot: Found a continuation table without a header.")

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