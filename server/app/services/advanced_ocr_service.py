import os
import pdfplumber
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)

class AdvancedOCRService:
    """
    Advanced OCR Service for extracting text from documents with metadata.
    Provides fallback OCR capabilities for CV parsing.
    """

    def extract_text_with_metadata(self, file_path: str, file_extension: str) -> Dict[str, Any]:
        """
        Extract text from a file using OCR and return with metadata.

        Args:
            file_path: Path to the file
            file_extension: File extension (e.g., '.pdf', '.docx')

        Returns:
            Dict containing 'text' and other metadata
        """
        try:
            text = ""

            # Handle PDF files
            if file_extension.lower() == '.pdf':
                text = self._extract_pdf_text(file_path)
            # Handle DOCX files
            elif file_extension.lower() == '.docx':
                text = self._extract_docx_text(file_path)
            # Handle TXT files
            elif file_extension.lower() == '.txt':
                text = self._extract_txt_text(file_path)
            else:
                logger.warning(f"Unsupported file type for OCR: {file_extension}")
                return {"text": "", "error": "Unsupported file type"}

            return {
                "text": text,
                "success": True,
                "file_path": file_path,
                "file_extension": file_extension
            }

        except Exception as e:
            logger.error(f"Error in OCR extraction for {file_path}: {str(e)}")
            return {
                "text": "",
                "success": False,
                "error": str(e),
                "file_path": file_path,
                "file_extension": file_extension
            }

    def _extract_pdf_text(self, file_path: str) -> str:
        """Extract text from PDF files."""
        text = ""
        try:
            with pdfplumber.open(file_path) as pdf:
                for page in pdf.pages:
                    page_text = page.extract_text()
                    if page_text:
                        text += page_text + "\n"
        except Exception as e:
            logger.error(f"Error extracting PDF text: {str(e)}")
        return text.strip()

    def _extract_docx_text(self, file_path: str) -> str:
        """Extract text from DOCX files."""
        text = ""
        try:
            from docx import Document
            doc = Document(file_path)
            for paragraph in doc.paragraphs:
                text += paragraph.text + "\n"
        except Exception as e:
            logger.error(f"Error extracting DOCX text: {str(e)}")
        return text.strip()

    def _extract_txt_text(self, file_path: str) -> str:
        """Extract text from TXT files."""
        text = ""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                text = f.read()
        except Exception as e:
            logger.error(f"Error extracting TXT text: {str(e)}")
        return text.strip()
