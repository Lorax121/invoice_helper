
import sys
import os
import argparse
import logging

logging.basicConfig(level=logging.INFO, stream=sys.stderr, format='%(asctime)s - %(levelname)s - %(message)s')


if getattr(sys, 'frozen', False):
    application_path = os.path.dirname(sys.executable)
else:
    application_path = os.path.dirname(os.path.abspath(__file__))

tesseract_path = os.path.join(application_path, 'tesseract')
if os.path.exists(tesseract_path):
    os.environ['PATH'] += os.pathsep + tesseract_path
    os.environ['TESSDATA_PREFIX'] = os.path.join(tesseract_path, 'tessdata')

poppler_bin_path = None
for item in os.listdir(application_path):
    item_path = os.path.join(application_path, item)
    if os.path.isdir(item_path) and item.startswith("poppler-"):
        potential_path = os.path.join(item_path, 'Library', 'bin')
        if os.path.exists(potential_path):
            poppler_bin_path = potential_path
            break
            
if poppler_bin_path:
    os.environ['PATH'] += os.pathsep + poppler_bin_path
    logging.info(f"Poppler path configured: {poppler_bin_path}")
else:
    logging.warning("Poppler directory not found. PDF processing for both cores may fail.")

os.environ['DEDOC_MODES'] = "['line_classifier', 'paragraph_classifier', 'structure_extractor', 'table_recognizer']"

from cores.dedoc_core import DedocCore
from cores.camelot_core import CamelotCore
from cores.base import AbstractCore

CORE_MAP = {
    "dedoc": DedocCore,
    "camelot": CamelotCore,
}

def main():
    parser = argparse.ArgumentParser(description="Parse tables from documents.")
    parser.add_argument("--file", type=str, required=True, help="Path to the file to parse.")
    parser.add_argument(
        "--core",
        type=str,
        choices=CORE_MAP.keys(),
        default="camelot",
        help="The parsing core to use."
    )
    parser.add_argument(
        "--preprocess-pdf",
        action="store_true",
        help="Enable preprocessing for PDF files to clean table lines (for dedoc core only)."
    )
    args = parser.parse_args()

    if not os.path.exists(args.file):
        print(f"Error: File not found at {args.file}", file=sys.stderr)
        sys.exit(1)

    core_class = CORE_MAP[args.core]
    core_instance: AbstractCore = core_class()
    logging.info(f"Using '{args.core}' core for parsing.")

    try:
        if args.core == "dedoc":
            json_output = core_instance.process(args.file, preprocess_pdf=args.preprocess_pdf)
        else:
            if args.preprocess_pdf:
                logging.warning("--preprocess-pdf is only supported by the 'dedoc' core and will be ignored.")
            json_output = core_instance.process(args.file)
        
        if json_output:
            print(json_output)
            sys.exit(0)
        else:
            print("Error: Could not find or process the required tables with the selected core.", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"Error during processing: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    if sys.stdout.encoding != 'utf-8':
        sys.stdout.reconfigure(encoding='utf-8')
    if sys.stderr.encoding != 'utf-8':
        sys.stderr.reconfigure(encoding='utf-8')
    main()