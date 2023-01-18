load("@ytt:data", "data")

def in_list(key, list):
  return hasattr(data.values.tap_values_config, key) and (data.values.tap_values_config[key] in list)
end

def is_profile(profile_list):
  return in_list('profile', profile_list)
end

def is_supply_chain(sc_list):
  return in_list('supply_chain', sc_list)
end

def get_scanner_for_ns():
  if not hasattr(data.values, "scan") and not hasattr(data.values.scan, "scanner"):
    return "grype"
  end
  return data.values.scan.scanner
end

def is_scanpolicy_lax():
  if hasattr(data.values, "scan") and hasattr(data.values.scan, "policy") and data.values.scan.policy == "lax":
    return True
  end
  return False
end

def get_snyk_values():
  snyk_values = {}
  snyk_values["namespace"] = data.values.name
  snyk_values["targetImagePullSecret"] = "registries-credentials"
  snyk_values["snyk"] = {"tokenSecret": {"name": "snyk-token-secret"}}
  return snyk_values
end
