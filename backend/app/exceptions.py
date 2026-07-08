class UnsupportedMediaTypeError(Exception):
    """Erkannter MIME-Typ (Magic Bytes) ist nicht in den erlaubten Typen."""

    def __init__(self, mime_type: str) -> None:
        self.mime_type = mime_type
        super().__init__(f"Unsupported media type: {mime_type!r}")


class FileTooLargeError(Exception):
    """Datei überschreitet settings.max_file_size_mb (während des Streamings erkannt)."""

    def __init__(self, max_file_size_mb: int) -> None:
        self.max_file_size_mb = max_file_size_mb
        super().__init__(f"File too large: max {max_file_size_mb} MB")
