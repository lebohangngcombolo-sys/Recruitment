# app/services/pdf_service.py
from fpdf import FPDF
import tempfile
import cloudinary.uploader
import os


class PDFService:
    @staticmethod
    def generate_offer_pdf(offer) -> str:
        """
        Generate a PDF for the given offer and upload to Cloudinary.
        Returns the public URL of the uploaded PDF.
        """

        # Safe access
        candidate_name = getattr(offer.application.candidate, 'full_name', 'Candidate')
        job_title = getattr(offer.application.requisition, 'title', 'Position')

        pdf = FPDF()
        pdf.add_page()

        pdf.set_font("Arial", "B", 16)
        pdf.cell(0, 10, "Job Offer", ln=True, align="C")
        pdf.ln(10)

        pdf.set_font("Arial", "", 12)
        pdf.cell(0, 10, f"Candidate: {candidate_name}", ln=True)
        pdf.cell(0, 10, f"Position: {job_title}", ln=True)
        pdf.cell(0, 10, f"Base Salary: {offer.base_salary}", ln=True)
        pdf.cell(0, 10, f"Allowances: {offer.allowances}", ln=True)
        pdf.cell(0, 10, f"Bonuses: {offer.bonuses}", ln=True)
        pdf.cell(0, 10, f"Contract Type: {offer.contract_type}", ln=True)
        pdf.cell(0, 10, f"Start Date: {offer.start_date}", ln=True)
        pdf.cell(0, 10, f"Work Location: {offer.work_location}", ln=True)
        pdf.cell(0, 10, f"Reporting Manager ID: {offer.hiring_manager_id}", ln=True)

        pdf.ln(10)
        pdf.multi_cell(0, 10, "Please sign this offer digitally to confirm your acceptance.")

        # Save PDF to temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp_file:
            pdf.output(tmp_file.name)
            tmp_file_path = tmp_file.name

        try:
            upload = cloudinary.uploader.upload(
                tmp_file_path,
                resource_type="raw",
                folder="offers",
                public_id=f"offer_{offer.id}",
                overwrite=True
            )
            return upload["secure_url"]
        finally:
            if os.path.exists(tmp_file_path):
                os.remove(tmp_file_path)
