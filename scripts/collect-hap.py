import hashlib
import json
import re
import os
import shutil
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    source = Path("entry/build/default/outputs/default/entry-default-unsigned.hap")
    if not source.is_file():
        raise SystemExit("Expected unsigned HAP was not produced")
    manifest = Path("AppScope/app.json5").read_text(encoding="utf-8")
    expected_version = re.search(r'"versionName"\s*:\s*"([^"]+)"', manifest)
    expected_code = re.search(r'"versionCode"\s*:\s*(\d+)', manifest)
    expected_bundle = re.search(r'"bundleName"\s*:\s*"([^"]+)"', manifest)
    with ZipFile(source) as archive:
        corrupt = archive.testzip()
        if corrupt:
            raise SystemExit(f"Corrupt HAP member {corrupt}")
        app = json.loads(archive.read("module.json"))["app"]
        bundle = app["bundleName"]
        if not expected_bundle or bundle != expected_bundle[1]:
            raise SystemExit(f"Unexpected HAP bundle name {bundle!r}")
        version = app["versionName"]
        if (not expected_version or version != expected_version[1]
                or not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9.+_-]*", version)):
            raise SystemExit(f"Unexpected HAP version {version!r}")
        if not expected_code or app["versionCode"] != int(expected_code[1]):
            raise SystemExit(f"Unexpected HAP versionCode {app['versionCode']!r}")
        if "ets/modules.abc" not in archive.namelist():
            raise SystemExit("HAP is missing compiled ArkTS")

    output = Path("build/release")
    output.mkdir(parents=True, exist_ok=True)
    stem = f"HarmonyXPlus-v{version.replace('+', '-')}-no-ads-unsigned"
    target = output / f"{stem}.hap"
    zip_target = output / f"{stem}.zip"
    shutil.copyfile(source, target)
    with ZipFile(zip_target, "w", compression=ZIP_DEFLATED) as archive:
        archive.write(target, target.name)
        archive.write("LICENSE", "LICENSE")
    checksums = []
    for asset in (target, zip_target):
        with asset.open("rb") as content:
            digest = hashlib.file_digest(content, "sha256").hexdigest()
        checksums.append(f"{digest}  {asset.name}\n")
    (output / "SHA256SUMS").write_text("".join(checksums), encoding="ascii")
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as github_output:
            github_output.write(f"artifact={stem}\n")
    print(f"Validated {bundle} {version}")
    print("".join(checksums), end="")


if __name__ == "__main__":
    main()
