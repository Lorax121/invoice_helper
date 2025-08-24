# --- Файл: backend/cores/base.py ---

from abc import ABC, abstractmethod
from typing import Optional

class AbstractCore(ABC):
    """
    Абстрактный базовый класс для всех ядер парсинга.
    Гарантирует, что каждое ядро реализует метод process.
    """

    @abstractmethod
    def process(self, file_path: str) -> Optional[str]:
        """
        Основной метод, который принимает путь к файлу и возвращает
        JSON-строку с результатом или None в случае неудачи.
        """
        pass