#!/usr/bin/env python3
"""Convert the markdown roadmap document to a styled PDF."""

import markdown
from weasyprint import HTML, CSS
from pathlib import Path

def main():
    docs_dir = Path(__file__).parent
    md_path = docs_dir / "superloop-opportunities-and-roadmap.md"
    pdf_path = docs_dir / "superloop-opportunities-and-roadmap.pdf"

    md_text = md_path.read_text()

    extensions = [
        "tables",
        "fenced_code",
        "toc",
    ]

    html_body = markdown.markdown(md_text, extensions=extensions)

    css_text = """
        @page {
            size: A4;
            margin: 2cm 2.5cm;
            @bottom-center {
                content: "Superloop - Internal";
                font-size: 9px;
                color: #888;
                font-family: 'Liberation Sans', 'DejaVu Sans', sans-serif;
            }
            @bottom-right {
                content: "Page " counter(page) " of " counter(pages);
                font-size: 9px;
                color: #888;
                font-family: 'Liberation Sans', 'DejaVu Sans', sans-serif;
            }
        }

        body {
            font-family: 'Liberation Sans', 'DejaVu Sans', sans-serif;
            font-size: 11px;
            line-height: 1.6;
            color: #1a1a2e;
        }

        h1 {
            font-size: 24px;
            color: #0f3460;
            border-bottom: 3px solid #0f3460;
            padding-bottom: 8px;
            margin-top: 30px;
            break-after: avoid;
        }

        h2 {
            font-size: 18px;
            color: #16213e;
            border-bottom: 1px solid #ccc;
            padding-bottom: 5px;
            margin-top: 25px;
            break-after: avoid;
        }

        h3 {
            font-size: 14px;
            color: #1a1a2e;
            margin-top: 18px;
            break-after: avoid;
        }

        h4 {
            font-size: 12px;
            color: #333;
            margin-top: 14px;
            break-after: avoid;
        }

        p {
            margin: 8px 0;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin: 12px 0;
            font-size: 10px;
            break-inside: avoid;
        }

        th {
            background-color: #0f3460;
            color: white;
            padding: 8px 10px;
            text-align: left;
            font-weight: bold;
        }

        td {
            padding: 6px 10px;
            border-bottom: 1px solid #ddd;
        }

        tr:nth-child(even) td {
            background-color: #f8f9fa;
        }

        code {
            font-family: 'Liberation Mono', 'DejaVu Sans Mono', monospace;
            font-size: 9.5px;
            background-color: #f0f0f5;
            padding: 1px 4px;
            border-radius: 3px;
            color: #c7254e;
        }

        pre {
            background-color: #2b2b3b;
            color: #e0e0e0;
            padding: 14px 16px;
            border-radius: 6px;
            font-size: 8.5px;
            line-height: 1.5;
            white-space: pre;
            overflow-wrap: break-word;
            break-inside: avoid;
            margin: 10px 0;
        }

        pre code {
            background: none;
            color: #e0e0e0;
            padding: 0;
            font-size: 8.5px;
            white-space: pre;
        }

        blockquote {
            border-left: 4px solid #0f3460;
            margin: 12px 0;
            padding: 8px 16px;
            background-color: #f0f4ff;
            color: #333;
        }

        strong {
            color: #0f3460;
        }

        hr {
            border: none;
            border-top: 2px solid #0f3460;
            margin: 20px 0;
        }

        ul, ol {
            margin: 6px 0;
            padding-left: 24px;
        }

        li {
            margin: 3px 0;
        }

        h1:first-of-type {
            font-size: 28px;
            text-align: center;
            border-bottom: 4px solid #0f3460;
            padding-bottom: 12px;
            margin-top: 40px;
            margin-bottom: 20px;
        }
    """

    full_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
</head>
<body>
{html_body}
</body>
</html>"""

    css = CSS(string=css_text)
    HTML(string=full_html).write_pdf(str(pdf_path), stylesheets=[css])
    print(f"PDF generated: {pdf_path}")
    print(f"Size: {pdf_path.stat().st_size / 1024:.1f} KB")


if __name__ == "__main__":
    main()
