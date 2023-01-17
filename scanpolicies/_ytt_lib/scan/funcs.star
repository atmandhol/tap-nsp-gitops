def in_list(key, list):
  return hasattr(data.values.tap_values, key) and (data.values.tap_values[key] in list)
end
def get_scanner_for_ns():
  if not hasattr(data.values, "scanner"):
    return "grype"
  return data.values.scanner
end
def is_scanpolicy_lax():
  if hasattr(data.values, "scanpolicy") and data.values.scanpolicy == "lax":
    return True
  return False
end
