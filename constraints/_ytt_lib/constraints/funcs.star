load("@ytt:data", "data")

def in_list(key, list):
  return hasattr(data.values.tap_values, key) and (data.values.tap_values[key] in list)
end

def is_profile(profile_list):
  return in_list('profile', profile_list)
end
