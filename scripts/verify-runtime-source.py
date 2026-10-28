import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]);expected=json.load(open(sys.argv[2]))
actual={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in root.rglob('*') if f.is_file() and not f.name.endswith(('.orig','.rej'))}
assert actual==expected, 'Patched source differs from reviewed complete manifest'
