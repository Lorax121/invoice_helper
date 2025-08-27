
import os
import tempfile
import logging
from typing import Optional

import fitz  
from camelot.handlers import PDFHandler
from camelot.parsers import Lattice
from camelot.utils import TemporaryDirectory

TOLERANCE = 2.0
MIN_INTERSECTIONS = 2
LINE_SCALE = 40

def preprocess_pdf_for_dedoc(input_path: str) -> Optional[str]:
    """
    Обрезает "торчащие" хвосты вертикальных линий в таблицах PDF.

    Алгоритм находит все вертикальные и горизонтальные линии с помощью Camelot.
    Для каждой вертикальной линии он определяет её фактические верхнюю и нижнюю
    границы на основе пересечений с горизонтальными линиями. Части вертикальной
    линии, выходящие за эти границы, закрашиваются белым цветом.

    Args:
        input_path: Путь к исходному PDF файлу.

    Returns:
        Путь к временному файлу с обработанным PDF или None в случае ошибки.
    """
    try:
        doc = fitz.open(input_path)
    except Exception as e:
        logging.error(f"PDF Preprocessing: Failed to open file {input_path} with PyMuPDF. Error: {e}")
        return None

    for page_num, page in enumerate(doc):
        try:
            handler = PDFHandler(input_path, pages=str(page_num + 1))
            with TemporaryDirectory() as tempdir:
                layout, dim, _, _, h_text, v_text = handler._save_page(
                    filepath=handler.filepath, page=page_num + 1, temp=tempdir
                )
                temp_pdf_path = os.path.join(tempdir, f"page-{page_num + 1}.pdf")
                parser = Lattice(line_scale=LINE_SCALE)
                parser.prepare_page_parse(
                    filename=temp_pdf_path, layout=layout, dimensions=dim,
                    page_idx=page_num + 1, images=[],
                    horizontal_text=h_text, vertical_text=v_text, layout_kwargs={}
                )
                
                parser.extract_tables()

                vertical_lines = parser.vertical_segments
                horizontal_lines = parser.horizontal_segments

        except Exception as e:
            logging.warning(f"PDF Preprocessing: Could not analyze page {page_num + 1} with Camelot. Skipping. Error: {e}")
            continue

        page_height = dim[1]
        cropped_areas = []

        for v_x1, v_y1, v_x2, v_y2 in vertical_lines:
            v_left, v_right = min(v_x1, v_x2), max(v_x1, v_x2)
            v_bottom, v_top = min(v_y1, v_y2), max(v_y1, v_y2)
            v_center_x = (v_left + v_right) / 2

            through_intersections = []
            for h_x1, h_y1, h_x2, h_y2 in horizontal_lines:
                h_left, h_right = min(h_x1, h_x2), max(h_x1, h_x2)
                h_y = h_y1
                h_thickness = abs(h_y2 - h_y1) if abs(h_y2 - h_y1) > 0.1 else 1.0

                if not (v_bottom <= h_y <= v_top):
                    continue

                if h_left < v_center_x - TOLERANCE and h_right > v_center_x + TOLERANCE:
                    through_intersections.append((h_y, h_thickness))

            if len(through_intersections) >= MIN_INTERSECTIONS:
                top_intersection = max(through_intersections, key=lambda x: x[0])
                bottom_intersection = min(through_intersections, key=lambda x: x[0])
                table_top_y, top_thickness = top_intersection
                table_bottom_y, bottom_thickness = bottom_intersection

                top_line_upper_edge = table_top_y + top_thickness / 2
                bottom_line_lower_edge = table_bottom_y - bottom_thickness / 2

                if v_top > top_line_upper_edge + TOLERANCE:
                    logging.info(f"PDF Preprocessing: Верхний край для обрезки найден на стр. {page_num + 1}.")
                    pymupdf_top = page_height - v_top
                    pymupdf_boundary = page_height - top_line_upper_edge
                    crop_rect = fitz.Rect(v_left - 2, pymupdf_top - 1, v_right + 2, pymupdf_boundary)
                    cropped_areas.append(crop_rect)

                if v_bottom < bottom_line_lower_edge - TOLERANCE:
                    logging.info(f"PDF Preprocessing: Нижний край для обрезки найден на стр. {page_num + 1}.")
                    pymupdf_bottom = page_height - v_bottom
                    pymupdf_boundary = page_height - bottom_line_lower_edge
                    crop_rect = fitz.Rect(v_left - 2, pymupdf_boundary, v_right + 2, pymupdf_bottom + 1)
                    cropped_areas.append(crop_rect)

        for rect in cropped_areas:
            page.draw_rect(rect, color=(1, 1, 1), fill=(1, 1, 1), width=0)

    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf", prefix="preprocessed_") as temp_file:
            output_path = temp_file.name
        
        doc.save(output_path, garbage=4, deflate=True, clean=True)
        doc.close()
        return output_path
    except Exception as e:
        logging.error(f"PDF Preprocessing: Failed to save temporary file. Error: {e}")
        if 'doc' in locals() and not doc.is_closed:
            doc.close()
        return None