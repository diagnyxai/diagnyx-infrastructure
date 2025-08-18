# Cost Management Configuration
environment = "master"
budget_alert_email = "admin@diagnyx.com"

# Account IDs from organizations output
account_ids = {
  development = "215726089610"
  staging     = "435455014599"
  uat         = "318265006643"
  production  = "921205606542"
  shared      = "008341391284"
}

# Budget limits
budget_limits = {
  development = 25
  staging     = 25
  uat         = 25
  production  = 50
  shared      = 25
}