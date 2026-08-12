import urllib.request

url = "http://127.0.0.1:8000/api/v1/categories?page=1&limit=100"

with urllib.request.urlopen(url) as response:
    raw = response.read()

print("RAW BYTES:")
print(raw)

print()
print("UTF-8 DECODE:")
print(raw.decode("utf-8"))
