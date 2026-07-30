from pathlib import Path
from pypdf import PdfReader

pdf_path = Path(r'c:\Users\SMARTECH\Downloads\Buhnyuy_Ronald_Yika_Thesis_Corrected_CivilSalt_Bamenda.pdf')
reader = PdfReader(str(pdf_path))
print('pages', len(reader.pages))
for i, page in enumerate(reader.pages[:8]):
    text = page.extract_text() or ''
    print(f'--- PAGE {i+1} ---')
    print(text[:4000])
    print()
