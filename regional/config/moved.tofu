# Moved Resources
# https://opentofu.org/docs/language/modules/develop/refactoring

moved {
  from = authentik_group.browser["all"]
  to   = authentik_group.all
}
