def metric_name(name: str) -> str:
    METRIC_PREFIX = "aistack:"
    return f"{METRIC_PREFIX}{name}"
