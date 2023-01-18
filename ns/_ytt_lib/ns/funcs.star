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

def get_scanner_for_ns(ns):
  if not hasattr(ns, "scan") and not hasattr(ns.scan, "scanner"):
    return "grype"
  end
  return ns.scan.scanner
end

def get_snyk_values(ns):
  snyk_values = {}
  snyk_values["namespace"] = ns.name
  snyk_values["targetImagePullSecret"] = "registries-credentials"
  snyk_values["snyk"] = {"tokenSecret": {"name": "snyk-token-secret"}}
  return snyk_values
end
