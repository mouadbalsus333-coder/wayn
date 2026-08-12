import pathlib
import sys

p = pathlib.Path(r"c:\WAYN\wayn\backend\tests\test_security.py")
raw = p.read_text(encoding="utf-8", newline="")
text = raw.replace("\r\n", "\n")

old = (
    'async def test_search_empty_string(client):\n'
    '    resp = await client.get("/api/v1/places/search?q=")\n'
    '    assert resp.status_code == 200\n'
    '    assert isinstance(resp.json(), list)\n'
)

new = (
    'async def test_search_empty_string(client):\n'
    '    """An empty search string must not raise (returns 200).\n'
    '\n'
    '    The list endpoints now return a PaginatedResponse object, so the body\n'
    '    is a dict with an ``items`` list rather than a bare list.\n'
    '    """\n'
    '    resp = await client.get("/api/v1/places/search?q=")\n'
    '    assert resp.status_code == 200\n'
    '    data = resp.json()\n'
    '    assert isinstance(data, dict)\n'
    '    assert "items" in data\n'
    '    assert isinstance(data["items"], list)\n'
)

count = text.count(old)
print("matches:", count)
sys.stdout.flush()
if count != 1:
    print("ERROR: expected exactly 1 match")
    sys.exit(1)

text2 = text.replace(old, new, 1)
p.write_text(text2.replace("\n", "\r\n"), encoding="utf-8", newline="")
print("wrote OK")
