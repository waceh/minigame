"""Package public game pages without server code or local development files."""
from pathlib import Path
from urllib.parse import urlsplit, unquote
import re
import shutil

root = Path(__file__).resolve().parents[1]
output = root / '_site'
output.mkdir(exist_ok=True)
for pattern in ('*.html', '*.js', '*.webmanifest'):
    for source in root.glob(pattern):
        shutil.copy2(source, output / source.name)
for folder in ('css', 'js', 'img'):
    shutil.copytree(root / folder, output / folder, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('*.test.cjs'))
for project in root.iterdir():
    if project.is_dir() and (project / 'project.godot').exists():
        shutil.copytree(project / 'web', output / project.name / 'web', dirs_exist_ok=True)
        for license_file in (project / 'OFL.txt', project / 'fonts' / 'OFL.txt'):
            if license_file.exists():
                destination = output / license_file.relative_to(root)
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(license_file, destination)
(output / '.nojekyll').touch()

missing = []
for page in output.rglob('*.html'):
    for ref in re.findall(r'''(?:src|href)\s*=\s*["']([^"']+)["']''', page.read_text()):
        url = urlsplit(ref)
        if url.scheme or url.netloc or not url.path or url.path.startswith('/'):
            continue
        if not (page.parent / unquote(url.path)).exists():
            missing.append(f'{page.relative_to(output)}: {ref}')
if missing:
    raise SystemExit('Missing site assets:\n' + '\n'.join(missing))
print(f'Packaged {sum(1 for p in output.rglob("*") if p.is_file())} public files.')
