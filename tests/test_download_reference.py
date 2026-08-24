import hashlib
import tempfile
import unittest
from pathlib import Path

from scripts.download_reference import download_reference, expected_files


class DownloadReferenceTest(unittest.TestCase):
    def test_downloads_and_verifies_tiny_local_release(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            files = expected_files(50, 14)
            checksums = []
            for index, name in enumerate(files, 1):
                content = f"tiny reference {index}\n".encode()
                (source / name).write_bytes(content)
                checksums.append(f"{hashlib.md5(content).hexdigest()}  {name}")
            (source / "MD5SUMS").write_text("\n".join(checksums) + "\n")

            messages = download_reference(target, 50, 14, source.as_uri())

            self.assertEqual(len(messages), 3)
            self.assertEqual([path.read_bytes() for path in map(target.__truediv__, files)], [
                b"tiny reference 1\n", b"tiny reference 2\n", b"tiny reference 3\n"
            ])
            self.assertFalse(list(target.glob("*.part")))

    def test_existing_files_are_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            files = expected_files(50, 14)
            checksums = []
            for name in files:
                content = b"downloaded\n"
                (source / name).write_bytes(content)
                checksums.append(f"{hashlib.md5(content).hexdigest()}  {name}")
            (source / "MD5SUMS").write_text("\n".join(checksums) + "\n")
            target.mkdir()
            (target / files[0]).write_bytes(b"manual\n")

            download_reference(target, 50, 14, source.as_uri())

            self.assertEqual((target / files[0]).read_bytes(), b"manual\n")

    def test_checksum_failure_removes_partial_file(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            target = root / "target"
            source.mkdir()
            files = expected_files(50, 14)
            for name in files:
                (source / name).write_bytes(b"downloaded\n")
            (source / "MD5SUMS").write_text("\n".join(f"{'0' * 32}  {name}" for name in files) + "\n")

            with self.assertRaisesRegex(RuntimeError, "MD5 mismatch"):
                download_reference(target, 50, 14, source.as_uri())

            self.assertFalse(list(target.glob("*.part")))


if __name__ == "__main__":
    unittest.main()
