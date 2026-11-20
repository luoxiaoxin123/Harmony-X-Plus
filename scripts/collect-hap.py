import hashlib
import json
import re
import shutil
from pathlib import Path
from zipfile import ZipFile


def main():
    source = Path("entry/build/default/outputs/default/entry-default-unsigned.hap")
    if not source.is_file():
        raise SystemExit("Expected unsigned HAP was not produced")
    manifest = Path("AppScope/app.json5").read_text(encoding="utf-8")
    expected = re.search(r'"versionName"\s*:\s*"([^"]+)"', manifest)
    with ZipFile(source) as archive:
        corrupt = archive.testzip()
        if corrupt:
            raise SystemExit(f"Corrupt HAP member {corrupt}")
        version = json.loads(archive.read("module.json"))["app"]["versionName"]
        if not expected or version != expected[1] or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._-]*", version):
            raise SystemExit(f"Unexpected HAP version {version!r}")
        if "ets/modules.abc" not in archive.namelist():
            raise SystemExit("HAP is missing compiled ArkTS")

    output = Path("build/release")
    output.mkdir(parents=True, exist_ok=True)
    name = f"HarmonyX-v{version}-no-ads-unsigned.hap"
    target = output / name
    shutil.copyfile(source, target)
    with target.open("rb") as content:
        digest = hashlib.file_digest(content, "sha256").hexdigest()
    (output / "SHA256SUMS").write_text(f"{digest}  {name}\n", encoding="ascii")
    print(f"{digest}  {target}")


if __name__ == "__main__":
    main()
