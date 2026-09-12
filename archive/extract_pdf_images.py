# Script to extract images from a PDF file using PyMuPDF (fitz library).
# Install the library first if not already installed:
# pip install pymupdf
#
# Usage:
# python extract_pdf_images.py input.pdf output_directory
#
# This script will extract all images from the PDF and save them as PNG files
# in the specified output directory, named like image_pageX_imgY.png

import sys
import os
import fitz  # PyMuPDF

def extract_images(pdf_path, output_dir):
    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Open the PDF
    doc = fitz.open(pdf_path)
    image_count = 0
    
    for page_num in range(len(doc)):
        page = doc.load_page(page_num)
        
        # Get all images on the page
        image_list = page.get_images(full=True)
        
        for img_index, img in enumerate(image_list):
            xref = img[0]  # The xref of the image
            base_image = doc.extract_image(xref)
            image_bytes = base_image["image"]
            image_ext = base_image["ext"]  # Extension like jpeg, png
            
            # Save the image
            image_filename = f"image_page{page_num+1}_img{img_index+1}.{image_ext}"
            image_path = os.path.join(output_dir, image_filename)
            
            with open(image_path, "wb") as img_file:
                img_file.write(image_bytes)
            
            print(f"Saved: {image_path}")
            image_count += 1
    
    doc.close()
    print(f"Total images extracted: {image_count}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python extract_pdf_images.py <input_pdf> <output_directory>")
        sys.exit(1)
    
    pdf_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    if not os.path.isfile(pdf_file):
        print(f"Error: File {pdf_file} does not exist.")
        sys.exit(1)
    
    extract_images(pdf_file, output_dir)