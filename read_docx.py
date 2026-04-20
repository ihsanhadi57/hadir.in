import zipfile
import xml.etree.ElementTree as ET
import sys

def read_docx(path):
    document = zipfile.ZipFile(path)
    xml_content = document.read('word/document.xml')
    document.close()
    
    tree = ET.fromstring(xml_content)
    # The namespaces used in docx xml
    namespace = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    paragraphs = []
    
    for p in tree.findall('.//w:p', namespace):
        texts = []
        for t in p.findall('.//w:t', namespace):
            if t.text:
                texts.append(t.text)
        if texts:
            paragraphs.append(''.join(texts))
            
    return '\n'.join(paragraphs)

if __name__ == '__main__':
    text = read_docx(sys.argv[1])
    try:
        with open(sys.argv[2], 'w', encoding='utf-8') as f:
            f.write(text)
    except Exception as e:
        print(f"Error: {e}")
